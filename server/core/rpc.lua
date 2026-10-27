--[[
    server/core/rpc.lua
    Rôle : callbacks client → serveur (call et emit) et serveur → client, sur deux paires de net events.
    Chaîne de contrôle d'une requête entrante, de la moins coûteuse à la plus coûteuse :
      source réseau valide → bucket global du joueur → forme du message → RPC enregistré → bucket du RPC
      → requêtes simultanées du joueur → schéma des arguments → handler isolé (xpcall).
    Le client ne reçoit jamais de détail d'erreur interne : uniquement un code.
    Format réseau : toute liste de valeurs voyage en (nombre, liste). msgpack sérialise une table ayant une partie
    liste comme une liste pure (le champ n de table.pack est perdu) et une liste à trous n'a pas de longueur fiable.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/string.lua, shared/lib/schema.lua,
                  shared/lib/pending.lua, shared/core/logger.lua, server/core/ratelimit.lua
]]

local type, tonumber, tostring, pairs, xpcall, select, getmetatable = type, tonumber, tostring, pairs, xpcall, select, getmetatable
local traceback = debug.traceback
local mathType, tointeger = math.type, math.tointeger
local format = string.format
local unpack = table.unpack
local RegisterNetEvent, TriggerClientEvent, DoesPlayerExist = RegisterNetEvent, TriggerClientEvent, DoesPlayerExist

local EVENTS = vAvA.EVENTS
local MAX_ID = vAvA.RPC_MAX_ID
local str = vAvA.lib.string
local schema = vAvA.lib.schema
local pending = vAvA.lib.pending
local logger = vAvA.logger
local ratelimit = vAvA.ratelimit
local cfg = vAvA.config.server.rpc
local rateCfg = vAvA.config.server.rateLimit
local schemaCfg = vAvA.config.server.schema
local log = logger.create('rpc')

-- Clé du bucket global : '<' et '>' sont hors du motif d'identifiant, aucune collision possible avec un RPC.
local GLOBAL_KEY = '<global>'

local NET_SCHEMA = {
    net = true,
    maxStringLength = schemaCfg.maxStringLength,
    maxArrayLength = schemaCfg.maxArrayLength,
    maxMapEntries = schemaCfg.maxMapEntries,
}

local rpc = {}
vAvA.rpc = rpc

---@class vAvA.RpcHandler
---@field owner string
---@field name string
---@field handler function
---@field args table[]   schémas compilés
---@field rule vAvA.NormalizedRateRule

---@type table<string, vAvA.RpcHandler>
local handlers = {}
-- source → { inFlight = integer } (+ état de limitation des logs du joueur)
local playerStates = {}
local outgoing = pending.create(cfg.maxPending, MAX_ID)

---@type vAvA.NormalizedRateRule
local globalRule
---@type vAvA.NormalizedRateRule
local defaultRule

---@param src integer
local function getPlayerState(src)
    local state = playerStates[src]
    if not state then
        state = { inFlight = 0 }
        playerStates[src] = state
    end
    return state
end

--- Avertissement limité à un par intervalle et par joueur, quel que soit le motif.
---@param src integer
---@param reason string
---@param detail any
local function warnPlayer(src, reason, detail)
    local allowed, suppressed = logger.throttle(getPlayerState(src))
    if allowed then
        log.warn('joueur %d : %s (%s)%s', src, reason, tostring(detail), logger.suppressedNote(suppressed))
    end
end

--- Capture le résultat d'un xpcall sous la forme du protocole réseau : (ok, nombre de valeurs, valeurs).
---@param ok boolean
---@return boolean ok
---@return integer count
---@return table values
local function capture(ok, ...)
    return ok, select('#', ...), { ... }
end

--- Réponse à un appel client. Succès : (id, true, count, values) · échec : (id, false, code).
---@param src integer
---@param id integer
local function reply(src, id, ok, ...)
    -- id 0 : emit, l'appelant n'attend aucune réponse
    if id ~= 0 then
        TriggerClientEvent(EVENTS.RPC_RESPONSE, src, id, ok, ...)
    end
end

---@param src integer
---@param id any
---@param name any
---@param count any
---@param args any
local function handleRequest(src, id, name, count, args)
    if mathType(id) ~= 'integer' or id < 0 or id > MAX_ID or type(name) ~= 'string' then
        warnPlayer(src, 'requête RPC malformée', 'identifiant ou nom invalide')
        return
    end

    local entry = handlers[name]
    if not entry then
        warnPlayer(src, 'RPC inconnu', str.sanitize(name, cfg.logNameMaxLength))
        reply(src, id, false, 'unknown_rpc')
        return
    end

    if not ratelimit.consume(src, name, entry.rule) then
        reply(src, id, false, 'rate_limited')
        return
    end

    local state = getPlayerState(src)
    if state.inFlight >= cfg.maxInFlightPerPlayer then
        reply(src, id, false, 'busy')
        return
    end

    local valid, err = schema.validateList(entry.args, args, count)
    if not valid then
        warnPlayer(src, format("arguments refusés pour '%s'", name), str.sanitize(err, cfg.logNameMaxLength))
        reply(src, id, false, 'invalid_args')
        return
    end
    -- un entier peut arriver en flottant (JSON d'une interface NUI) : le handler reçoit un vrai entier
    local schemas = entry.args
    for i = 1, count do
        if schemas[i].type == 'integer' and mathType(args[i]) == 'float' then args[i] = tointeger(args[i]) end
    end

    state.inFlight = state.inFlight + 1
    local ok, resultCount, results = capture(xpcall(entry.handler, traceback, src, unpack(args, 1, count)))
    -- le joueur a pu se déconnecter pendant que le handler attendait (DB…) : son état a alors été purgé
    if playerStates[src] == state then
        state.inFlight = state.inFlight - 1
    end

    if not ok then
        local allowed, suppressed = logger.throttle(entry)
        if allowed then
            log.error("handler RPC '%s' (ressource %s) en erreur%s : %s",
                name, entry.owner, logger.suppressedNote(suppressed), tostring(results[1]))
        end
        reply(src, id, false, 'server_error')
        return
    end
    reply(src, id, true, resultCount, results)
end

---@param src integer
---@param id any
---@param ok any
---@param count any
---@param results any
local function handleClientResponse(src, id, ok, count, results)
    if mathType(id) ~= 'integer' then
        warnPlayer(src, 'réponse RPC malformée', 'identifiant invalide')
        return
    end
    local entry = outgoing:get(id)
    -- comparer la source empêche un client de répondre à la place d'un autre
    if not entry or entry.meta.source ~= src then
        warnPlayer(src, 'réponse RPC non sollicitée', id)
        return
    end
    if ok ~= true then
        outgoing:settle(id, false, 'client_error')
        return
    end
    if mathType(count) ~= 'integer' or count < 0 or count > cfg.maxReturns
        or type(results) ~= 'table' or getmetatable(results) ~= nil then
        warnPlayer(src, 'réponse RPC invalide', 'valeurs de retour mal formées')
        outgoing:settle(id, false, 'invalid_response')
        return
    end
    local returns = entry.meta.returns
    if returns then
        local valid, err = schema.validateList(returns, results, count)
        if not valid then
            warnPlayer(src, 'réponse RPC invalide', str.sanitize(err, cfg.logNameMaxLength))
            outgoing:settle(id, false, 'invalid_response')
            return
        end
    end
    outgoing:settle(id, true, unpack(results, 1, count))
end

---@class vAvA.RpcOptions
---@field args vAvA.SchemaDefinition[]  schéma de chaque argument, dans l'ordre ({} si aucun)
---@field rateLimit? vAvA.RateRule       défaut : config rateLimit.rpcDefault

--- Enregistre un RPC appelable par les clients. Le nom doit être préfixé par "<owner>:".
---@param owner string
---@param name string
---@param options vAvA.RpcOptions
---@param handler fun(source: integer, ...: any): ...
---@return boolean ok
---@return string|nil err
function rpc.register(owner, name, options, handler)
    if not str.isIdentifier(name) or not str.hasPrefix(name, owner .. ':') then
        return false, format("nom de RPC invalide '%s' (attendu : '%s:<action>')", tostring(name), owner)
    end
    if handlers[name] then
        return false, format("RPC '%s' déjà enregistré par '%s'", name, handlers[name].owner)
    end
    if type(options) ~= 'table' then
        return false, 'options requises : { args = { ... } }'
    end
    if not schema.isCallable(handler) then
        return false, 'handler non appelable'
    end

    local args, argsErr = schema.compileList(options.args, NET_SCHEMA, 'args')
    if not args then return false, argsErr end
    if #args > cfg.maxArgs then
        return false, format('%d arguments déclarés, maximum %d', #args, cfg.maxArgs)
    end

    local rule = defaultRule
    if options.rateLimit ~= nil then
        local ruleErr
        rule, ruleErr = ratelimit.normalizeRule(options.rateLimit)
        if not rule then return false, 'rateLimit : ' .. ruleErr end
    end

    handlers[name] = { owner = owner, name = name, handler = handler, args = args, rule = rule }
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
    ratelimit.purgeKey(name)
    return true
end

---@class vAvA.ClientCallOptions
---@field timeout? integer                   ms, borné par la config
---@field returns? vAvA.SchemaDefinition[]   schéma des valeurs attendues (fortement recommandé)

--- Appelle un handler enregistré sur un client et attend sa réponse. Bloque le thread courant.
--- Ce que renvoie le client est une déclaration non fiable : à valider (returns) et à ne jamais croire aveuglément.
---@param owner string
---@param options vAvA.ClientCallOptions|nil
---@param target integer
---@param name string
---@return boolean ok
---@return any ...  valeurs du client, ou code d'erreur si ok est false
function rpc.callClient(owner, options, target, name, ...)
    if mathType(target) ~= 'integer' or target <= 0 or not DoesPlayerExist(target) then
        return false, 'invalid_target'
    end
    if not str.isIdentifier(name) then
        return false, 'invalid_name'
    end

    local timeout, returns = cfg.defaultTimeoutMs, nil
    if options ~= nil then
        if type(options) ~= 'table' then return false, 'invalid_options' end
        if options.timeout ~= nil then
            if mathType(options.timeout) ~= 'integer' or options.timeout < cfg.minTimeoutMs or options.timeout > cfg.maxTimeoutMs then
                log.error('[%s] callClient %s : timeout hors bornes (%d à %d ms)', owner, name, cfg.minTimeoutMs, cfg.maxTimeoutMs)
                return false, 'invalid_options'
            end
            timeout = options.timeout
        end
        if options.returns ~= nil then
            local err
            returns, err = schema.compileList(options.returns, NET_SCHEMA, 'returns')
            if not returns then
                log.error('[%s] callClient %s : %s', owner, name, err)
                return false, 'invalid_options'
            end
        end
    end

    local id, entry = outgoing:add({ source = target, owner = owner, returns = returns }, timeout)
    if not id then
        log.warn('[%s] callClient %s refusé : %d appels serveur → client déjà en attente', owner, name, cfg.maxPending)
        return false, 'saturated'
    end
    TriggerClientEvent(EVENTS.CLIENT_REQUEST, target, id, name, select('#', ...), { ... })
    return pending.await(entry)
end

--- Retire les RPC d'un propriétaire et libère ses appels serveur → client en attente.
---@param owner string
function rpc.purgeOwner(owner)
    for name, entry in pairs(handlers) do
        if entry.owner == owner then
            handlers[name] = nil
            ratelimit.purgeKey(name)
        end
    end
    outgoing:settleWhere(function(meta) return meta.owner == owner end, false, 'owner_stopped')
end

--- Libère l'état d'un joueur déconnecté et rejette immédiatement les appels qui lui étaient adressés.
---@param src integer
function rpc.purgePlayer(src)
    playerStates[src] = nil
    outgoing:settleWhere(function(meta) return meta.source == src end, false, 'dropped')
end

--- Valide la configuration du rate limiting. À appeler avant start().
---@return boolean ok
---@return string|nil err
function rpc.init()
    local err
    globalRule, err = ratelimit.normalizeRule(rateCfg.global)
    if not globalRule then return false, 'config rateLimit.global : ' .. err end
    defaultRule, err = ratelimit.normalizeRule(rateCfg.rpcDefault)
    if not defaultRule then return false, 'config rateLimit.rpcDefault : ' .. err end
    return true
end

--- Enregistre les net events. Appelé par init.lua.
function rpc.start()
    RegisterNetEvent(EVENTS.RPC_REQUEST, function(id, name, count, args)
        local src = tonumber(source)
        -- déclenchement local (TriggerEvent depuis une ressource serveur) : pas de source réseau, ignoré
        if not src or src <= 0 then return end
        -- le bucket global passe avant tout le reste : un flood coûte une recherche de table par message
        if not ratelimit.consume(src, GLOBAL_KEY, globalRule) then return end
        handleRequest(src, id, name, count, args)
    end)

    RegisterNetEvent(EVENTS.CLIENT_RESPONSE, function(id, ok, count, results)
        local src = tonumber(source)
        if not src or src <= 0 then return end
        if not ratelimit.consume(src, GLOBAL_KEY, globalRule) then return end
        handleClientResponse(src, id, ok, count, results)
    end)
end
