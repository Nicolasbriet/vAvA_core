--[[
    server/players/persistence.lua
    Rôle : sauvegarde des personnages. Chaque modification incrémente character.revision ; seuls les personnages
           dont la révision a changé sont écrits.
      - cycle périodique : une seule transaction pour tous les personnages modifiés ;
      - déchargement : écriture immédiate du personnage ;
      - échec d'écriture : le personnage est gardé et retenté à chaque cycle, et réutilisé s'il est resélectionné
        (ses données, plus récentes que la base, ne sont jamais perdues).
    FiveM n'attend pas les écritures en cours à l'arrêt du serveur : lancer vava_saveall avant quit.
    Dépendances : config/server.lua, shared/core/logger.lua, server/core/database.lua
]]

local pcall, xpcall, pairs, tostring = pcall, xpcall, pairs, tostring
local traceback = debug.traceback
local encodeJson = json.encode
local CreateThread, Wait, RegisterCommand = CreateThread, Wait, RegisterCommand

local database = vAvA.database
local cfg = vAvA.config.server.persistence
local log = vAvA.logger.create('persistence')

local CORE = vAvA.CORE_OWNER
local SAVE_COMMAND = 'vava_saveall'

local UPDATE_FULL_SQL = 'UPDATE `vava_characters` SET `position_x` = ?, `position_y` = ?, `position_z` = ?, `heading` = ?, `data` = ? WHERE `id` = ?'
-- sans position connue (personnage jamais apparu) : aucune valeur nulle dans la liste des paramètres
local UPDATE_DATA_SQL = 'UPDATE `vava_characters` SET `data` = ? WHERE `id` = ?'

local persistence = {}
vAvA.persistence = persistence

---@type table<integer, vAvA.Character>
local retry = {}
---@type fun(fn: fun(character: vAvA.Character))
local forEachActive = function() end

---@param character vAvA.Character
---@return boolean
local function isDirty(character)
    return character.revision ~= character.savedRevision
end

---@param character vAvA.Character
---@return vAvA.TransactionQuery|nil
local function buildQuery(character)
    local ok, encoded = pcall(encodeJson, character.data)
    if not ok then
        log.error('personnage #%d : données non sérialisables, non sauvegardé : %s', character.id, tostring(encoded))
        return nil
    end
    local p = character.position
    if p then
        return { query = UPDATE_FULL_SQL, values = { p.x, p.y, p.z, p.heading, encoded, character.id } }
    end
    return { query = UPDATE_DATA_SQL, values = { encoded, character.id } }
end

--- Écrit immédiatement un personnage (déchargement). En cas d'échec, il est gardé pour être retenté.
--- Bloque le thread courant.
---@param character vAvA.Character
---@return boolean saved
function persistence.saveCharacter(character)
    if not isDirty(character) then return true end
    local query = buildQuery(character)
    if not query then return false end
    local revision = character.revision
    local _, err = database.update(CORE, query.query, query.values)
    if err then
        retry[character.id] = character
        log.error('personnage #%d non sauvegardé, nouvel essai au prochain cycle : %s', character.id, err)
        return false
    end
    character.savedRevision = revision
    if not isDirty(character) then retry[character.id] = nil end
    return true
end

--- Sauvegarde groupée de tous les personnages modifiés (actifs et en attente de nouvel essai).
--- Bloque le thread courant.
---@return boolean ok
---@return integer|string countOrErr
function persistence.saveAll()
    local queries, saved = {}, {}
    local function consider(character)
        if not isDirty(character) then return end
        local query = buildQuery(character)
        if query then
            queries[#queries + 1] = query
            saved[#saved + 1] = { character = character, revision = character.revision }
        end
    end
    forEachActive(consider)
    for _, character in pairs(retry) do consider(character) end
    if #queries == 0 then return true, 0 end

    local ok, err = database.transaction(CORE, queries)
    if not ok then
        log.error('sauvegarde groupée en échec (%d personnage(s)), nouvel essai au prochain cycle : %s', #queries, tostring(err))
        return false, tostring(err)
    end
    for i = 1, #saved do
        local entry = saved[i]
        local character = entry.character
        -- une modification survenue pendant l'écriture laisse le personnage à sauvegarder
        character.savedRevision = entry.revision
        if retry[character.id] == character and not isDirty(character) then retry[character.id] = nil end
    end
    return true, #queries
end

--- Récupère un personnage déchargé mais non sauvegardé : ses données priment sur la base.
---@param characterId integer
---@return vAvA.Character|nil
function persistence.takeRetry(characterId)
    local character = retry[characterId]
    retry[characterId] = nil
    return character
end

--- Nombre de personnages dont des modifications ne sont pas encore écrites.
---@return integer
function persistence.pendingCount()
    local count = 0
    forEachActive(function(character)
        if isDirty(character) then count = count + 1 end
    end)
    for _ in pairs(retry) do count = count + 1 end
    return count
end

--- Lance le cycle de sauvegarde et la commande console. Appelé par init.lua.
---@param iterate fun(fn: fun(character: vAvA.Character))  parcours des personnages actifs
function persistence.start(iterate)
    forEachActive = iterate
    CreateThread(function()
        -- boucle lente justifiée : une itération toutes les saveIntervalMs, une transaction au plus
        while true do
            Wait(cfg.saveIntervalMs)
            local called, crash = xpcall(persistence.saveAll, traceback)
            if not called then log.error('cycle de sauvegarde : %s', tostring(crash)) end
        end
    end)
    RegisterCommand(SAVE_COMMAND, function()
        CreateThread(function()
            local ok, result = persistence.saveAll()
            if ok then
                log.info('%s : %d personnage(s) sauvegardé(s)', SAVE_COMMAND, result)
            else
                log.error('%s : échec (%s)', SAVE_COMMAND, tostring(result))
            end
        end)
    end, true)
end
