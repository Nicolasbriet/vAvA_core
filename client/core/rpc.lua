--[[
    client/core/rpc.lua
    Rôle : côté client du RPC. Appels vers le serveur (call avec réponse, emit sans réponse) et exécution des
           handlers que le serveur appelle (callClient). Le client exprime des intentions, le serveur décide.
    Dépendances : shared/init.lua, config/shared.lua, shared/lib/string.lua, shared/lib/schema.lua,
                  shared/lib/pending.lua, shared/core/logger.lua
]]

local type, tostring, pairs, xpcall, select = type, tostring, pairs, xpcall, select
local traceback = debug.traceback
local mathType = math.type
local format = string.format
local unpack = table.unpack
local RegisterNetEvent, TriggerServerEvent = RegisterNetEvent, TriggerServerEvent

local EVENTS = vAvA.EVENTS
local str = vAvA.lib.string
local schema = vAvA.lib.schema
local pending = vAvA.lib.pending
local logger = vAvA.logger
local cfg = vAvA.config.shared.rpc
local identifierMaxLength = vAvA.config.shared.identifiers.maxLength
local log = logger.create('rpc')

local rpc = {}
vAvA.rpc = rpc

local outgoing = pending.create(cfg.maxPending, vAvA.RPC_MAX_ID)
---@type table<string, { owner: string, handler: function }>
local handlers = {}

--- Capture le résultat d'un xpcall sous la forme du protocole réseau : (ok, nombre de valeurs, valeurs).
---@param ok boolean
---@return boolean ok
---@return integer count
---@return table values
local function capture(ok, ...)
    return ok, select('#', ...), { ... }
end

---@class vAvA.ServerCallOptions
---@field timeout? integer  ms, borné par la config

--- Appelle un RPC serveur et attend sa réponse. Bloque le thread courant.
---@param options vAvA.ServerCallOptions|nil
---@param name string
---@return boolean ok   false : échec de transport (timeout, rate_limited, invalid_args…)
---@return any ...      valeurs du handler serveur, ou code d'erreur
function rpc.call(options, name, ...)
    if not str.isIdentifier(name) then return false, 'invalid_name' end
    local timeout = cfg.defaultTimeoutMs
    if options ~= nil then
        if type(options) ~= 'table' then return false, 'invalid_options' end
        if options.timeout ~= nil then
            if mathType(options.timeout) ~= 'integer' or options.timeout < cfg.minTimeoutMs or options.timeout > cfg.maxTimeoutMs then
                return false, 'invalid_options'
            end
            timeout = options.timeout
        end
    end
    local id, entry = outgoing:add(nil, timeout)
    if not id then
        log.warn("appel '%s' refusé : %d appels déjà en attente", name, cfg.maxPending)
        return false, 'saturated'
    end
    TriggerServerEvent(EVENTS.RPC_REQUEST, id, name, select('#', ...), { ... })
    return pending.await(entry)
end

--- Envoie une intention sans attendre de réponse. Mêmes contrôles côté serveur qu'un call.
---@param name string
---@return boolean ok
---@return string|nil err
function rpc.emit(name, ...)
    if not str.isIdentifier(name) then return false, 'invalid_name' end
    TriggerServerEvent(EVENTS.RPC_REQUEST, 0, name, select('#', ...), { ... })
    return true
end

--- Enregistre un handler appelable par le serveur. Le nom doit être préfixé par "<owner>:".
---@param owner string
---@param name string
---@param handler fun(...: any): ...
---@return boolean ok
---@return string|nil err
function rpc.register(owner, name, handler)
    if not str.isIdentifier(name) or not str.hasPrefix(name, owner .. ':') then
        return false, format("nom de RPC invalide '%s' (attendu : '%s:<action>')", tostring(name), owner)
    end
    if handlers[name] then
        return false, format("RPC client '%s' déjà enregistré par '%s'", name, handlers[name].owner)
    end
    if not schema.isCallable(handler) then
        return false, 'handler non appelable'
    end
    handlers[name] = { owner = owner, handler = handler }
    return true
end

---@param owner string
---@param name string
---@return boolean ok
---@return string|nil err
function rpc.unregister(owner, name)
    local entry = handlers[name]
    if not entry then return false, 'RPC inconnu' end
    if entry.owner ~= owner then return false, 'ce RPC appartient à une autre ressource' end
    handlers[name] = nil
    return true
end

---@param owner string
function rpc.purgeOwner(owner)
    for name, entry in pairs(handlers) do
        if entry.owner == owner then handlers[name] = nil end
    end
end

--- Enregistre les net events. Appelé par client/init.lua.
function rpc.start()
    -- succès : (id, true, count, values) · échec : (id, false, code)
    RegisterNetEvent(EVENTS.RPC_RESPONSE, function(id, ok, countOrCode, values)
        if mathType(id) ~= 'integer' then return end
        if ok == true and mathType(countOrCode) == 'integer' and countOrCode >= 0 and type(values) == 'table' then
            outgoing:settle(id, true, unpack(values, 1, countOrCode))
        else
            outgoing:settle(id, false, type(countOrCode) == 'string' and countOrCode or 'server_error')
        end
    end)

    RegisterNetEvent(EVENTS.CLIENT_REQUEST, function(id, name, count, args)
        if mathType(id) ~= 'integer' or type(name) ~= 'string' or mathType(count) ~= 'integer' or count < 0 or type(args) ~= 'table' then
            return
        end
        local entry = handlers[name]
        if not entry then
            log.warn("RPC client inconnu '%s' demandé par le serveur", str.sanitize(name, identifierMaxLength))
            TriggerServerEvent(EVENTS.CLIENT_RESPONSE, id, false)
            return
        end
        local ok, resultCount, results = capture(xpcall(entry.handler, traceback, unpack(args, 1, count)))
        if not ok then
            log.error("handler RPC client '%s' (ressource %s) en erreur : %s", name, entry.owner, tostring(results[1]))
            TriggerServerEvent(EVENTS.CLIENT_RESPONSE, id, false)
            return
        end
        TriggerServerEvent(EVENTS.CLIENT_RESPONSE, id, true, resultCount, results)
    end)
end
