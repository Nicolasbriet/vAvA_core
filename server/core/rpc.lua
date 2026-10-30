--[[
    server/core/rpc.lua
    Rôle : callbacks client → serveur (call et emit) et serveur → client, sur deux paires de net events.
    Chaîne de contrôle d'une requête entrante, de la moins coûteuse à la plus coûteuse :
      source réseau valide → bucket global du joueur → forme du message → RPC enregistré → bucket du RPC
      → requêtes simultanées du joueur → schéma des arguments → handler isolé (xpcall).
    Le client ne reçoit jamais de détail d'erreur interne : uniquement un code.
    Format réseau : toute liste de valeurs voyage en (nombre, liste). msgpack sérialise une table ayant une partie
    liste comme une liste pure (le champ n de table.pack est perdu) et une liste à trous n'a pas de longueur fiable.
    Envois vers les clients par core.net (mesurés et comptés) : une réponse ou une demande au-delà du seuil part en
    latent ; la réponse latente est annoncée au client (préavis : id, octets, débit) qui repousse son attente, et le
    serveur repousse la sienne pour une demande latente.
    Dépendances : shared/init.lua, config/shared.lua, config/server.lua, shared/lib/string.lua, shared/lib/schema.lua,
                  shared/lib/pending.lua, shared/core/logger.lua, server/core/ratelimit.lua, server/core/net.lua
]]

local type, tonumber, tostring, pairs, xpcall, select, getmetatable = type, tonumber, tostring, pairs, xpcall, select, getmetatable
local traceback = debug.traceback
local mathType, ceil, min = math.type, math.ceil, math.min
local format = string.format
local unpack = table.unpack
local RegisterNetEvent, DoesPlayerExist = RegisterNetEvent, DoesPlayerExist

local EVENTS = vAvA.EVENTS
local MAX_ID = vAvA.RPC_MAX_ID
local str = vAvA.lib.string
local schema = vAvA.lib.schema
local pending = vAvA.lib.pending
local logger = vAvA.logger
local ratelimit = vAvA.ratelimit
local net = vAvA.net
local cfg = vAvA.config.server.rpc
local sharedCfg = vAvA.config.shared.rpc
local rateCfg = vAvA.config.server.rateLimit
local schemaCfg = vAvA.config.server.schema
local latentRate = vAvA.config.server.net.latent.bytesPerSecond
local log = logger.create('rpc')

-- Clé du bucket global : '<' et '>' sont hors du motif d'identifiant, aucune collision possible avec un RPC.
local GLOBAL_KEY = '<global>'

-- Réponses comptées sous le RPC enregistré (jamais sous un nom venu du client) : un RPC inconnu a sa clé fixe.
local UNKNOWN_ENTRY = { owner = vAvA.resourceName, label = 'rpc <inconnu>', sendOptions = net.NEVER }
local NOTICE_LABEL = 'rpc préavis'
local SEND_OPTIONS = { auto = net.AUTO, never = net.NEVER }

local NET_SCHEMA = {
    net = true,
    maxStringLength = schemaCfg.maxStringLength,
    maxArrayLength = schemaCfg.maxArrayLength,
    maxMapEntries = schemaCfg.maxMapEntries,
}

-- Retours d'un appel sans options (callClient) : aucune valeur acceptée, le client ne fait qu'acquitter.
local NO_RETURNS = assert(schema.compileList({}, NET_SCHEMA, 'returns'))

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

--- Allongement d'une attente pour un message latent de `bytes` octets : temps de transfert au débit configuré, plus la
--- marge, au plus maxLatentExtendMs (même règle côté client).
---@param bytes integer
---@return integer ms
local function latentExtension(bytes)
    return min(ceil(bytes * 1000 / latentRate) + sharedCfg.latentMarginMs, sharedCfg.maxLatentExtendMs)
end

--- Préavis d'une réponse latente, envoyé juste avant elle (fiable) : (id, octets, débit).
---@param target integer
---@param packet vAvA.NetPacket  args[1] : identifiant de la requête
local function noticeLatentReply(target, packet)
    net.dispatch(vAvA.resourceName, NOTICE_LABEL, target, net.NEVER, EVENTS.RPC_LATENT, packet.args[1], packet.bytes, latentRate)
end

--- Réponse à un appel client. Succès : (id, true, count, values) · échec : (id, false, code).
--- Une réponse impossible à envoyer (trop grosse, joueur saturé de latents, valeurs non sérialisables) part en échec
--- court : (id, false, too_large | saturated | server_error).
---@param src integer
---@param id integer
---@param entry { owner: string, label: string, sendOptions: table }  RPC enregistré, ou UNKNOWN_ENTRY
local function reply(src, id, entry, ok, ...)
    -- id 0 : emit, l'appelant n'attend aucune réponse
    if id == 0 then return end
    local owner, label = entry.owner, entry.label
    local packet, code = net.prepare(owner, label, EVENTS.RPC_RESPONSE, id, ok, ...)
    if packet then
        local sent
        sent, code = net.deliver(owner, label, src, entry.sendOptions, packet, noticeLatentReply)
        if sent then return end
    end
    -- joueur parti : personne à prévenir
    if code == 'invalid_target' then return end
    if code ~= 'too_large' and code ~= 'saturated' then code = 'server_error' end
    net.dispatch(owner, label, src, net.NEVER, EVENTS.RPC_RESPONSE, id, false, code)
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
        reply(src, id, UNKNOWN_ENTRY, false, 'unknown_rpc')
        return
    end

    if not ratelimit.consume(src, name, entry.rule) then
        reply(src, id, entry, false, 'rate_limited')
        return
    end

    local state = getPlayerState(src)
    if state.inFlight >= cfg.maxInFlightPerPlayer then
        reply(src, id, entry, false, 'busy')
        return
    end

    local valid, err = schema.validateList(entry.args, args, count)
    if not valid then
        warnPlayer(src, format("arguments refusés pour '%s'", name), str.sanitize(err, cfg.logNameMaxLength))
        reply(src, id, entry, false, 'invalid_args')
        return
    end
    -- un entier peut arriver en flottant (JSON d'une interface NUI) : le handler reçoit un vrai entier, aussi dans
    -- les champs de table, les listes et les maps
    schema.normalizeList(entry.args, args, count)

    state.inFlight = state.inFlight + 1
    local ok, resultCount, results = capture(xpcall(entry.handler, traceback, src, unpack(args, 1, count)))
    -- le joueur a pu se déconnecter pendant que le handler attendait (DB…) : son état a alors été purgé, et son
    -- numéro a pu être redonné à un nouveau venu dont les appels comptent eux aussi à partir de 1. La réponse
    -- n'appartient qu'au joueur qui a fait la demande : elle ne part que si son état est toujours le même.
    local current = playerStates[src] == state
    if current then
        state.inFlight = state.inFlight - 1
    end

    if not ok then
        local allowed, suppressed = logger.throttle(entry)
        if allowed then
            log.error("handler RPC '%s' (ressource %s) en erreur%s : %s",
                name, entry.owner, logger.suppressedNote(suppressed), tostring(results[1]))
        end
        if current then reply(src, id, entry, false, 'server_error') end
        return
    end
    if current then reply(src, id, entry, true, resultCount, results) end
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
    -- toujours un schéma : celui de l'appelant, ou aucune valeur (callClient sans options)
    local returns = entry.meta.returns
    local valid, err = schema.validateList(returns, results, count)
    if not valid then
        warnPlayer(src, 'réponse RPC invalide', str.sanitize(err, cfg.logNameMaxLength))
        outgoing:settle(id, false, 'invalid_response')
        return
    end
    schema.normalizeList(returns, results, count)
    outgoing:settle(id, true, unpack(results, 1, count))
end

---@class vAvA.RpcOptions
---@field args vAvA.SchemaDefinition[]  schéma de chaque argument, dans l'ordre ({} si aucun)
---@field rateLimit? vAvA.RateRule       défaut : config rateLimit.rpcDefault
---@field latent? 'auto'|'never'         réponse latente au-delà du seuil (auto, défaut) ou toujours fiable

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

    -- réponse latente au-delà du seuil (auto), ou toujours fiable (never : un état que des différences suivront)
    local sendOptions = SEND_OPTIONS[options.latent == nil and 'auto' or options.latent]
    if not sendOptions then return false, "latent : 'auto' ou 'never'" end

    handlers[name] = {
        owner = owner, name = name, handler = handler, args = args, rule = rule,
        label = 'rpc ' .. name, sendOptions = sendOptions,
    }
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

--- Demande serveur → client partie en latent : l'attente du serveur est allongée du temps de transfert (même règle que
--- le client pour une réponse latente).
---@param _ integer  joueur visé
---@param packet vAvA.NetPacket  args[1] : identifiant de l'appel
local function extendLatentRequest(_, packet)
    local id = packet.args[1]
    local entry = outgoing:get(id)
    if entry then outgoing:extend(id, entry.meta.timeout + latentExtension(packet.bytes)) end
end

---@class vAvA.ClientCallOptions
---@field timeout? integer                  ms, borné par la config
---@field returns vAvA.SchemaDefinition[]   obligatoire : schéma de chaque valeur attendue, dans l'ordre ({} si aucune)

--- Appelle un handler enregistré sur un client et attend sa réponse. Bloque le thread courant.
--- Ce que renvoie le client est une déclaration non fiable : toujours validée par un schéma, jamais crue aveuglément.
--- Sans options (callClient), aucune valeur n'est attendue : une réponse qui en porte est refusée (invalid_response).
--- Avec options (callClientWith), returns est obligatoire, comme args pour un RPC ; {} : aucune valeur attendue.
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

    local timeout, returns = cfg.defaultTimeoutMs, NO_RETURNS
    if options ~= nil then
        if type(options) ~= 'table' then return false, 'invalid_options' end
        if options.timeout ~= nil then
            if mathType(options.timeout) ~= 'integer' or options.timeout < cfg.minTimeoutMs or options.timeout > cfg.maxTimeoutMs then
                log.error('[%s] callClient %s : timeout hors bornes (%d à %d ms)', owner, name, cfg.minTimeoutMs, cfg.maxTimeoutMs)
                return false, 'invalid_options'
            end
            timeout = options.timeout
        end
        -- comme args pour un RPC : aucune valeur non décrite ne remonte d'un client
        if options.returns == nil then
            log.error('[%s] callClient %s : returns requis ({} si aucune valeur attendue)', owner, name)
            return false, 'invalid_options'
        end
        local err
        returns, err = schema.compileList(options.returns, NET_SCHEMA, 'returns')
        if not returns then
            log.error('[%s] callClient %s : %s', owner, name, err)
            return false, 'invalid_options'
        end
        -- au-delà, aucune réponse ne pourrait passer (count borné par maxReturns) : erreur du module, dite tout de suite
        if #returns > cfg.maxReturns then
            log.error('[%s] callClient %s : %d valeurs déclarées, maximum %d', owner, name, #returns, cfg.maxReturns)
            return false, 'invalid_options'
        end
    end

    local id, entry = outgoing:add({ source = target, owner = owner, returns = returns, timeout = timeout }, timeout)
    if not id then
        log.warn('[%s] callClient %s refusé : %d appels serveur → client déjà en attente', owner, name, cfg.maxPending)
        return false, 'saturated'
    end
    local label = 'callClient ' .. name
    local packet, code = net.prepare(owner, label, EVENTS.CLIENT_REQUEST, id, name, select('#', ...), { ... })
    if packet then
        local sent
        sent, code = net.deliver(owner, label, target, net.AUTO, packet, extendLatentRequest)
        if sent then return pending.await(entry) end
    end
    -- trop gros, joueur saturé de latents, valeurs non sérialisables, joueur parti : rien n'est parti
    outgoing:settle(id, false, code)
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
