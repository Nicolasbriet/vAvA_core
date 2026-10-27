--[[
    server/core/migrations.lua
    Rôle : migrations SQL versionnées du core et des modules.
      - Déclaration dans le fxmanifest de chaque ressource : vava_migration 'sql/0001_description.sql'
        (Lua FiveM n'offre aucun moyen portable de lister un dossier).
      - Suivi dans la table vava_migrations, chargée une seule fois en cache au démarrage.
      - Une migration appliquée n'est jamais rejouée ; si son fichier change, le propriétaire refuse de démarrer.
      - Applications sérialisées (jamais deux DDL en parallèle).
    Limite MySQL/MariaDB : tout DDL provoque un commit implicite, une migration ne peut donc pas être annulée
    à moitié. Elle n'est enregistrée qu'après la réussite de toutes ses instructions.
    Dépendances : shared/lib/string.lua, shared/core/logger.lua, server/core/database.lua
]]

local type, tostring, tonumber, pcall, pairs = type, tostring, tonumber, pcall, pairs
local tointeger = math.tointeger
local byte, sub, find, match, upper, gsub, format = string.byte, string.sub, string.find, string.match, string.upper, string.gsub, string.format
local concat, sort = table.concat, table.sort
local newPromise, await = promise.new, Citizen.Await
local GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile = GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile

local str = vAvA.lib.string
local database = vAvA.database
local log = vAvA.logger.create('migrations')

local METADATA_KEY = 'vava_migration'
local FILE_PATTERN = '^(%d+)_[%w_%-]+%.sql$'
local MAX_VERSION = 0xFFFFFFFF -- INT UNSIGNED

-- Seule exception au versionnage : la table de suivi doit exister avant de pouvoir lire l'historique.
local BOOTSTRAP_SQL = [[
CREATE TABLE IF NOT EXISTS `vava_migrations` (
    `owner` VARCHAR(64) NOT NULL,
    `version` INT UNSIGNED NOT NULL,
    `name` VARCHAR(255) NOT NULL,
    `checksum` INT UNSIGNED NOT NULL,
    `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`owner`, `version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]]
local SELECT_APPLIED_SQL = 'SELECT `owner`, `version`, `name`, `checksum` FROM `vava_migrations`'
local INSERT_APPLIED_SQL = 'INSERT INTO `vava_migrations` (`owner`, `version`, `name`, `checksum`) VALUES (?, ?, ?, ?)'

local BYTE_QUOTE, BYTE_DOUBLE_QUOTE, BYTE_BACKTICK = byte("'"), byte('"'), byte('`')
local BYTE_BACKSLASH, BYTE_SEMICOLON, BYTE_HASH = byte('\\'), byte(';'), byte('#')
local BYTE_DASH, BYTE_SLASH, BYTE_STAR, BYTE_BANG = byte('-'), byte('/'), byte('*'), byte('!')
local BYTE_SPACE, BYTE_TAB, BYTE_NEWLINE, BYTE_RETURN = byte(' '), byte('\t'), byte('\n'), byte('\r')

local migrations = {}
vAvA.migrations = migrations

---@type table<string, table<integer, { name: string, checksum: integer }>>
local applied = {}
local bootstrapped = false
-- promesse de la dernière application en file : chaque application attend la précédente
local queueTail = nil

---@param b integer|nil
---@return boolean
local function isSpaceOrEnd(b)
    return b == nil or b == BYTE_SPACE or b == BYTE_TAB or b == BYTE_NEWLINE or b == BYTE_RETURN
end

--- Découpe un fichier SQL en instructions, en respectant chaînes, identifiants et commentaires.
--- Les commentaires ordinaires sont retirés ; les commentaires exécutables /*! … */ sont conservés.
---@param sql string
---@return string[]|nil statements
---@return string|nil err
local function splitStatements(sql)
    local statements, pieces = {}, {}
    local length, i, segmentStart = #sql, 1, 1
    local quote = nil

    local function flushStatement(stopAt)
        pieces[#pieces + 1] = sub(sql, segmentStart, stopAt)
        local statement = str.trim(concat(pieces))
        if statement ~= '' then statements[#statements + 1] = statement end
        pieces = {}
    end

    while i <= length do
        local c = byte(sql, i)
        if quote then
            if c == BYTE_BACKSLASH and quote ~= BYTE_BACKTICK then
                i = i + 2
            else
                if c == quote then quote = nil end
                i = i + 1
            end
        elseif c == BYTE_QUOTE or c == BYTE_DOUBLE_QUOTE or c == BYTE_BACKTICK then
            quote = c
            i = i + 1
        elseif c == BYTE_HASH or (c == BYTE_DASH and byte(sql, i + 1) == BYTE_DASH and isSpaceOrEnd(byte(sql, i + 2))) then
            pieces[#pieces + 1] = sub(sql, segmentStart, i - 1)
            local lineEnd = find(sql, '\n', i, true)
            i = lineEnd or length + 1
            segmentStart = i
        elseif c == BYTE_SLASH and byte(sql, i + 1) == BYTE_STAR and byte(sql, i + 2) ~= BYTE_BANG then
            pieces[#pieces + 1] = sub(sql, segmentStart, i - 1)
            local close = find(sql, '*/', i + 2, true)
            if not close then return nil, 'commentaire /* non fermé' end
            pieces[#pieces + 1] = ' '
            i = close + 2
            segmentStart = i
        elseif c == BYTE_SEMICOLON then
            flushStatement(i - 1)
            i = i + 1
            segmentStart = i
        else
            i = i + 1
        end
    end

    if quote then return nil, 'chaîne ou identifiant non fermé' end
    flushStatement(length)

    for index = 1, #statements do
        if find(upper(sub(statements[index], 1, 9)), '^DELIMITER') then
            return nil, format("instruction %d : DELIMITER n'est pas supporté (procédures et triggers interdits en migration)", index)
        end
    end
    return statements
end

---@class vAvA.MigrationFile
---@field version integer
---@field name string
---@field path string
---@field content string

--- Lit les migrations déclarées dans le fxmanifest d'une ressource, triées par version.
---@param resource string
---@return vAvA.MigrationFile[]|nil list
---@return string|nil err
local function collect(resource)
    local list, seen = {}, {}
    for index = 0, GetNumResourceMetadata(resource, METADATA_KEY) - 1 do
        local path = GetResourceMetadata(resource, METADATA_KEY, index)
        local fileName = type(path) == 'string' and match(path, '([^/\\]+)$') or nil
        local digits = fileName and match(fileName, FILE_PATTERN)
        local version = digits and tointeger(tonumber(digits))
        if not version or version < 1 or version > MAX_VERSION then
            return nil, format("nom de migration invalide '%s' (attendu : 0001_description.sql)", tostring(path))
        end
        if seen[version] then
            return nil, format('version %d déclarée deux fois (%s et %s)', version, seen[version], path)
        end
        local content = LoadResourceFile(resource, path)
        if not content then
            return nil, format('fichier de migration introuvable : %s', path)
        end
        seen[version] = path
        -- fins de ligne normalisées : un checkout Windows (CRLF) et Linux (LF) donnent la même empreinte
        list[#list + 1] = { version = version, name = fileName, path = path, content = (gsub(content, '\r\n', '\n')) }
    end
    sort(list, function(a, b) return a.version < b.version end)
    return list
end

---@param owner string
---@param migration vAvA.MigrationFile
---@param checksum integer
---@return boolean ok
---@return string|nil err
local function applyOne(owner, migration, checksum)
    local statements, splitErr = splitStatements(migration.content)
    if not statements then return false, format('%s : %s', migration.name, splitErr) end
    if #statements == 0 then return false, format('%s : aucune instruction SQL', migration.name) end

    for index = 1, #statements do
        local _, err = database.query(owner, statements[index], {})
        if err then
            return false, format('%s, instruction %d/%d en échec : %s', migration.name, index, #statements, err)
        end
    end

    local _, insertErr = database.insert(owner, INSERT_APPLIED_SQL, { owner, migration.version, migration.name, checksum })
    if insertErr then
        return false, format('%s appliquée mais non enregistrée : %s', migration.name, insertErr)
    end

    local history = applied[owner]
    if not history then
        history = {}
        applied[owner] = history
    end
    history[migration.version] = { name = migration.name, checksum = checksum }
    log.info('[%s] migration %s appliquée (%d instruction(s))', owner, migration.name, #statements)
    return true
end

---@param owner string
---@param resource string
---@return boolean ok
---@return string|nil err
local function applyAll(owner, resource)
    local list, collectErr = collect(resource)
    if not list then return false, collectErr end

    local history = applied[owner] or {}
    local highest = 0
    for version in pairs(history) do
        if version > highest then highest = version end
    end

    local declared, appliedCount = {}, 0
    for index = 1, #list do
        local migration = list[index]
        declared[migration.version] = true
        local checksum = str.fnv1a(migration.content)
        local record = history[migration.version]
        if record then
            if record.checksum ~= checksum then
                return false, format(
                    '%s a été modifiée après application (empreinte %d en base, %d sur disque). '
                    .. 'Ne modifiez jamais une migration appliquée : ajoutez-en une nouvelle.',
                    migration.name, record.checksum, checksum)
            end
        else
            if migration.version < highest then
                log.warn('[%s] %s appliquée hors ordre (version %d déjà appliquée)', owner, migration.name, highest)
            end
            local ok, err = applyOne(owner, migration, checksum)
            if not ok then return false, err end
            appliedCount = appliedCount + 1
        end
    end

    for version, record in pairs(history) do
        if not declared[version] then
            log.warn('[%s] migration %d (%s) présente en base mais absente du fxmanifest', owner, version, record.name)
        end
    end
    if appliedCount > 0 then
        log.info('[%s] %d migration(s) appliquée(s)', owner, appliedCount)
    end
    return true
end

--- Crée la table de suivi si besoin et charge tout l'historique en cache (une seule requête).
---@return boolean ok
---@return string|nil err
function migrations.bootstrap()
    local _, createErr = database.query(vAvA.CORE_OWNER, BOOTSTRAP_SQL, {})
    if createErr then
        return false, 'création de la table de suivi impossible : ' .. createErr
    end
    local rows, selectErr = database.query(vAvA.CORE_OWNER, SELECT_APPLIED_SQL, {})
    if selectErr then
        return false, "lecture de l'historique impossible : " .. selectErr
    end
    for index = 1, #rows do
        local row = rows[index]
        local history = applied[row.owner]
        if not history then
            history = {}
            applied[row.owner] = history
        end
        history[row.version] = { name = row.name, checksum = row.checksum }
    end
    bootstrapped = true
    return true
end

--- Applique les migrations en attente déclarées par une ressource. Bloque le thread courant.
---@param owner string     propriétaire dans la table de suivi ('core' ou nom du module)
---@param resource string  ressource dont le fxmanifest déclare les migrations
---@return boolean ok
---@return string|nil err
function migrations.apply(owner, resource)
    if not bootstrapped then return false, 'table de suivi non initialisée' end

    local previous = queueTail
    local done = newPromise()
    queueTail = done
    if previous then await(previous) end

    local called, ok, err = pcall(applyAll, owner, resource)
    if not called then
        ok, err = false, 'erreur interne : ' .. tostring(ok)
    end

    done:resolve(true)
    if queueTail == done then queueTail = nil end
    return ok, err
end
