--[[
    server/core/database.lua
    Rôle : unique point d'accès à oxmysql. Requêtes paramétrées obligatoires, erreurs capturées et journalisées
           avec leur propriétaire, jamais propagées sous forme d'exception.
    Dépendances : @oxmysql/lib/MySQL.lua (globale MySQL, utilisée uniquement dans ce fichier), config/server.lua,
                  shared/lib/string.lua, shared/core/logger.lua
]]

local MySQL = MySQL
local type, pcall, tostring, ipairs = type, pcall, tostring, ipairs
local GetGameTimer = GetGameTimer
local newPromise, await = promise.new, Citizen.Await
local encodeJson = json.encode

local str = vAvA.lib.string
local logger = vAvA.logger
local cfg = vAvA.config.server.database
local log = logger.create('database')

local queryAwait = MySQL.query.await
local singleAwait = MySQL.single.await
local scalarAwait = MySQL.scalar.await
local insertAwait = MySQL.insert.await
local updateAwait = MySQL.update.await
local transactionAwait = MySQL.transaction.await

local database = {}
vAvA.database = database

---@param sql string
---@return string
local function preview(sql)
    return str.sanitize(sql, cfg.logSqlMaxLength)
end

---@param owner string
---@param err any
---@param sql string
---@param params any
local function reportFailure(owner, err, sql, params)
    log.error('[%s] requête en échec : %s | SQL : %s', owner, tostring(err), preview(sql))
    -- les paramètres peuvent contenir des données privées : uniquement en debug
    if logger.isEnabled('debug') then
        local ok, encoded = pcall(encodeJson, params)
        log.debug('[%s] paramètres : %s', owner, ok and encoded or '<non sérialisables>')
    end
end

---@param method function
---@param owner string
---@param sql any
---@param params any
---@return any result
---@return string|nil err
local function execute(method, owner, sql, params)
    if type(sql) ~= 'string' or sql == '' then
        log.error('[%s] requête refusée : SQL vide ou invalide', owner)
        return nil, 'invalid_query'
    end
    -- rendre les paramètres obligatoires force la requête paramétrée : aucune valeur n'a de raison d'être concaténée
    if type(params) ~= 'table' then
        log.error('[%s] requête refusée : params doit être une table ({} si aucun paramètre) | SQL : %s', owner, preview(sql))
        return nil, 'invalid_params'
    end

    local startedAt = GetGameTimer()
    local ok, result = pcall(method, sql, params)
    local elapsed = GetGameTimer() - startedAt

    if not ok then
        reportFailure(owner, result, sql, params)
        return nil, tostring(result)
    end
    if elapsed >= cfg.slowQueryMs then
        log.warn('[%s] requête lente (%d ms) : %s', owner, elapsed, preview(sql))
    end
    return result
end

--- Lignes de résultat (SELECT) ou en-tête de résultat (autres requêtes).
---@param owner string
---@param sql string
---@param params table
---@return table|nil rows
---@return string|nil err
function database.query(owner, sql, params)
    return execute(queryAwait, owner, sql, params)
end

--- Première ligne, ou nil s'il n'y en a aucune (err reste nil dans ce cas).
---@param owner string
---@param sql string
---@param params table
---@return table|nil row
---@return string|nil err
function database.single(owner, sql, params)
    return execute(singleAwait, owner, sql, params)
end

--- Première colonne de la première ligne, ou nil.
---@param owner string
---@param sql string
---@param params table
---@return any value
---@return string|nil err
function database.scalar(owner, sql, params)
    return execute(scalarAwait, owner, sql, params)
end

--- Identifiant auto-incrémenté de la ligne insérée (0 si la table n'en a pas).
---@param owner string
---@param sql string
---@param params table
---@return integer|nil insertId
---@return string|nil err
function database.insert(owner, sql, params)
    return execute(insertAwait, owner, sql, params)
end

--- Nombre de lignes affectées.
---@param owner string
---@param sql string
---@param params table
---@return integer|nil affectedRows
---@return string|nil err
function database.update(owner, sql, params)
    return execute(updateAwait, owner, sql, params)
end

---@class vAvA.TransactionQuery
---@field query string
---@field values table

--- Exécute plusieurs requêtes dans une transaction : tout est validé ou tout est annulé.
---@param owner string
---@param queries vAvA.TransactionQuery[]
---@return boolean|nil ok
---@return string|nil err
function database.transaction(owner, queries)
    if type(queries) ~= 'table' or #queries == 0 then
        log.error('[%s] transaction refusée : liste de requêtes vide ou invalide', owner)
        return nil, 'invalid_query'
    end
    for index, entry in ipairs(queries) do
        if type(entry) ~= 'table' or type(entry.query) ~= 'string' or entry.query == '' or type(entry.values) ~= 'table' then
            log.error('[%s] transaction refusée : requête #%d invalide (attendu { query = string, values = table })', owner, index)
            return nil, 'invalid_query'
        end
    end

    local startedAt = GetGameTimer()
    local ok, result = pcall(transactionAwait, queries)
    local elapsed = GetGameTimer() - startedAt

    if not ok or result ~= true then
        local err = ok and 'transaction annulée' or tostring(result)
        log.error('[%s] transaction en échec (%d requêtes) : %s | première requête : %s', owner, #queries, err, preview(queries[1].query))
        return nil, err
    end
    if elapsed >= cfg.slowQueryMs then
        log.warn('[%s] transaction lente (%d ms, %d requêtes)', owner, elapsed, #queries)
    end
    return true
end

--- Bloque le thread courant jusqu'à ce qu'oxmysql soit connecté.
function database.awaitReady()
    local ready = newPromise()
    MySQL.ready(function() ready:resolve(true) end)
    await(ready)
end
