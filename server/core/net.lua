--[[
    server/core/net.lua
    Rôle : tous les envois serveur → client du core et ceux des modules qui passent par core.net. Pour chaque envoi :
           cible validée (jamais -1, jamais 0 : un joueur, une liste, ou les joueurs proches calculés ici), taille
           mesurée (exacte : la seule sérialisation, celle qui part ; sinon estimée par netsize), envoi fiable, ou
           latent à débit borné au-delà du seuil, volume latent en vol borné par joueur, compteur par ressource et
           par évènement (netstats). Aucune fonction ne lève d'erreur : true, envoyés, octets, latent | false, code.
    Ordre : deux messages fiables vers un même joueur arrivent dans l'ordre d'envoi ; un latent peut être dépassé par
           tout message envoyé après lui. Ce qui doit garder l'ordre (personnage, apparition) part en 'never'.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/string.lua, shared/core/logger.lua,
                  server/core/netsize.lua, server/core/netstats.lua ; vAvA.characters et vAvA.sync sont lus à l'appel
                  (chargés plus tard), jamais au chargement.
]]

local type, tostring, select, next, pairs, pcall, rawlen, rawget = type, tostring, select, next, pairs, pcall, rawlen, rawget
local mathType, huge, min = math.type, math.huge, math.min
local pack, unpack, concat = table.pack, table.unpack, table.concat
local format = string.format
local TriggerClientEvent, TriggerLatentClientEvent = TriggerClientEvent, TriggerLatentClientEvent
local DoesPlayerExist, GetPlayerPed, DoesEntityExist, GetEntityCoords, GetPlayerRoutingBucket =
    DoesPlayerExist, GetPlayerPed, DoesEntityExist, GetEntityCoords, GetPlayerRoutingBucket
local GetGameTimer, SetTimeout = GetGameTimer, SetTimeout

local str = vAvA.lib.string
local logger = vAvA.logger
local netsize = vAvA.netsize
local netstats = vAvA.netstats
local cfg = vAvA.config.server.net
local log = logger.create('net')

local RATE = cfg.latent.bytesPerSecond
local THRESHOLD = cfg.latent.threshold
local WINDOW_MS = cfg.counter.bucketMs * cfg.counter.buckets
-- Préfixes que seul le core envoie : un module ne peut pas les prendre, même sous un nom de ressource qui y ressemble.
local RESERVED_PREFIXES = { 'vAvA:', 'core:' }
local STATS_LIMIT_MAX = 50
local RESOURCE_PATTERN = '^[%w_%-%.]+$'
local RESOURCE_MAX = 48

local net = {}
vAvA.net = net

-- Options internes du core, jamais acceptées d'un module.
net.AUTO = { latent = 'auto' }
net.NEVER = { latent = 'never' }
net.ALWAYS = { latent = 'always' }
-- Toujours fiable (l'ordre compte), mais signalé en console au-delà du seuil, une fois par minute et par évènement.
net.RELIABLE = { latent = 'never', warnLarge = true }

local LATENT_CHOICES = { auto = true, never = true, always = true }
local SEND_KEYS = { latent = true }
local NEAR_KEYS = { latent = true, exclude = true, bucket = true }
local PLAYERS_KEYS = { exclude = true, bucket = true }
local STATS_KEYS = { limit = true, resource = true, target = true }

-- 'exact' : msgpack.pack_args et les envois internes du runtime (une sérialisation par envoi, quel que soit le nombre
-- de cibles) ; 'estimate' : netsize, puis TriggerClientEvent par cible. Choisi par start().
local mode = 'estimate'
local packArgs, sendInternal, sendLatentInternal

local counter = netstats.create(cfg.counter)
-- joueur → échéance (ms) à laquelle ses envois latents en route seront arrivés (estimée au débit configuré)
local drainAt = {}
-- ressource → état de limitation de ses erreurs en console
local logStates = {}
-- évènement → dernière alerte « gros envoi fiable »
local largeWarnAt = {}
-- positions des peds lues pendant ce tour du serveur (vidées quand GetGameTimer change)
local positionCache, positionTime = {}, nil

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Erreur d'une ressource, limitée à une par intervalle et par ressource.
---@param owner string
---@param message string  format
local function ownerError(owner, message, ...)
    local state = logStates[owner]
    if not state then
        state = {}
        logStates[owner] = state
    end
    local allowed, suppressed = logger.throttle(state)
    if allowed then
        log.error('[%s] %s%s', owner, format(message, ...), logger.suppressedNote(suppressed))
    end
end

--- Cible d'un envoi : un joueur qui existe, ou une liste pure d'entiers > 0 (doublons retirés, joueurs partis sautés).
---@param target any
---@return integer|integer[]|nil targets  le joueur, ou une nouvelle liste
---@return integer|string count            nombre de cibles, ou code d'erreur
---@return boolean|nil everyone            -1 demandé
local function resolveTargets(target)
    if mathType(target) == 'integer' then
        if target == -1 then return nil, 'invalid_target', true end
        if target <= 0 or not DoesPlayerExist(target) then return nil, 'invalid_target' end
        return target, 1
    end
    if type(target) ~= 'table' then return nil, 'invalid_target' end
    local length = rawlen(target)
    if length == 0 or length > cfg.maxTargets then return nil, 'invalid_target' end
    -- liste pure : exactement les clés 1..length (une table mixte ou à trous est refusée)
    local keys = 0
    for key in next, target do
        keys = keys + 1
        if keys > length or mathType(key) ~= 'integer' then return nil, 'invalid_target' end
    end
    if keys ~= length then return nil, 'invalid_target' end
    local list, seen, count = {}, {}, 0
    for i = 1, length do
        local src = rawget(target, i)
        if mathType(src) ~= 'integer' then return nil, 'invalid_target' end
        if src == -1 then return nil, 'invalid_target', true end
        if src <= 0 then return nil, 'invalid_target' end
        if not seen[src] then
            seen[src] = true
            if DoesPlayerExist(src) then
                count = count + 1
                list[count] = src
            end
        end
    end
    return list, count
end

---@param owner string
---@param event any
local function refuseEveryone(owner, event)
    ownerError(owner, '%s : envoi à tous refusé : une liste, sendNear ou les abonnements de zone', tostring(event))
end

--- Nom d'évènement d'un module : identifiant préfixé par sa ressource, jamais un préfixe réservé au core.
---@param owner string
---@param event any
---@return boolean
local function validEvent(owner, event)
    if not str.isIdentifier(event) or not str.hasPrefix(event, owner .. ':') then return false end
    for i = 1, #RESERVED_PREFIXES do
        if str.hasPrefix(event, RESERVED_PREFIXES[i]) then return false end
    end
    return true
end

--- Options d'un module : table à clés connues, valeurs bornées.
---@param options any
---@param allowed table<string, boolean>
---@return table|nil
local function checkOptions(options, allowed)
    if options == nil then return net.AUTO end
    if type(options) ~= 'table' then return nil end
    for key in pairs(options) do
        if not allowed[key] then return nil end
    end
    if options.latent ~= nil and not LATENT_CHOICES[options.latent] then return nil end
    local exclude, bucket = options.exclude, options.bucket
    if exclude ~= nil and (mathType(exclude) ~= 'integer' or exclude <= 0) then return nil end
    if bucket ~= nil and (mathType(bucket) ~= 'integer' or bucket < 0) then return nil end
    return options
end

---@param coords any
---@return number|nil x
---@return number|nil y
---@return number|nil z
local function readCoords(coords)
    local kind = type(coords)
    if kind ~= 'table' and kind ~= 'vector3' then return nil end
    local x, y, z = coords.x, coords.y, coords.z
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return x, y, z
end

---@param radius any
---@return boolean
local function validRadius(radius)
    return finite(radius) and radius > 0 and radius <= cfg.near.maxRadius
end

--- Position du ped d'un joueur, lue côté serveur au plus une fois par tour (false : pas de ped).
---@param src integer
---@return vector3|table|false
local function pedPosition(src)
    local now = GetGameTimer()
    if now ~= positionTime then
        positionTime = now
        for key in pairs(positionCache) do positionCache[key] = nil end
    end
    local cached = positionCache[src]
    if cached == nil then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            cached = GetEntityCoords(ped)
        else
            cached = false
        end
        positionCache[src] = cached
    end
    return cached
end

-- Recherche des joueurs proches : état posé avant le parcours (aucune fermeture créée par appel).
local near = { x = 0.0, y = 0.0, z = 0.0, r2 = 0.0, exclude = nil, bucket = nil, list = nil, count = 0, sync = nil }

---@param character vAvA.Character
local function visitNear(character)
    if not character.spawned then return end
    -- personnage qui n'est plus celui de son joueur (joueur parti pendant la sauvegarde, numéro redonné) : ignoré
    if not near.sync.isCurrent(character) then return end
    local src = character.source
    if src == near.exclude then return end
    if near.bucket and GetPlayerRoutingBucket(src) ~= near.bucket then return end
    local position = pedPosition(src)
    if not position then return end
    local dx, dy, dz = position.x - near.x, position.y - near.y, position.z - near.z
    if dx * dx + dy * dy + dz * dz <= near.r2 then
        local count = near.count + 1
        near.count = count
        near.list[count] = src
    end
end

--- Joueurs dont le personnage est apparu, à moins de `radius` (3D) du point, positions lues côté serveur.
---@return integer[] list
---@return integer count
local function collectNear(x, y, z, radius, options)
    local list = {}
    near.x, near.y, near.z, near.r2 = x, y, z, radius * radius
    near.exclude, near.bucket, near.list, near.count = options.exclude, options.bucket, list, 0
    near.sync = vAvA.sync
    vAvA.characters.forEachActive(visitNear)
    local count = near.count
    near.list, near.sync = nil, nil
    return list, count
end

---@class vAvA.NetPacket
---@field event string
---@field bytes integer     taille d'un message (charge + nom de l'évènement)
---@field payload? string   charge sérialisée (mesure exacte)
---@field args table        valeurs (table.pack) : repli et lecture par le core (préavis)

--- Mesure (et sérialise, en mesure exacte) un envoi. Erreurs écrites en console, au nom de la ressource.
---@param owner string
---@param label string  clé du compteur (pour le message d'erreur)
---@param event string
---@return vAvA.NetPacket|nil packet
---@return string|nil code  'invalid_args' | 'unserializable' | 'too_large'
function net.prepare(owner, label, event, ...)
    local count = select('#', ...)
    if count > cfg.maxArgs then
        ownerError(owner, '%s : %d valeurs, maximum %d', label, count, cfg.maxArgs)
        return nil, 'invalid_args'
    end
    local args = pack(...)
    if mode == 'exact' then
        local ok, payload = pcall(packArgs, ...)
        if not ok or type(payload) ~= 'string' then
            ownerError(owner, '%s : valeurs impossibles à envoyer (%s)', label, tostring(payload))
            return nil, 'unserializable'
        end
        local bytes = #payload + #event
        if bytes > cfg.maxBytes then
            ownerError(owner, '%s : message de %d octets refusé (maximum %d)', label, bytes, cfg.maxBytes)
            return nil, 'too_large'
        end
        return { event = event, bytes = bytes, payload = payload, args = args }
    end
    local size, err = netsize.args(cfg.maxBytes - #event, ...)
    if not size then
        if err == 'too_large' then
            ownerError(owner, '%s : message de plus de %d octets refusé', label, cfg.maxBytes)
            return nil, 'too_large'
        end
        ownerError(owner, '%s : valeurs impossibles à envoyer (%s)', label, err)
        return nil, 'unserializable'
    end
    return { event = event, bytes = size + #event, args = args }
end

--- Repli définitif sur l'estimation : un envoi interne du runtime a échoué.
---@param err any
local function fallBack(err)
    if mode ~= 'exact' then return end
    mode = 'estimate'
    log.error('[net] envoi interne du runtime en échec (%s) : estimation à partir de maintenant', tostring(err))
end

---@param packet vAvA.NetPacket
---@param target integer
---@param latent boolean
local function sendOne(packet, target, latent)
    local payload = packet.payload
    if payload and mode == 'exact' then
        local ok, err
        if latent then
            ok, err = pcall(sendLatentInternal, packet.event, tostring(target), payload, #payload, RATE)
        else
            ok, err = pcall(sendInternal, packet.event, tostring(target), payload, #payload)
        end
        if ok then return end
        fallBack(err)
    end
    local args = packet.args
    if latent then
        TriggerLatentClientEvent(packet.event, target, RATE, unpack(args, 1, args.n))
    else
        TriggerClientEvent(packet.event, target, unpack(args, 1, args.n))
    end
end

--- Réserve la place d'un envoi latent vers un joueur ; false si le volume en route dépasserait la borne.
---@param target integer
---@param bytes integer
---@param now integer
---@return boolean
local function reserve(target, bytes, now)
    local drain = drainAt[target] or 0
    local inFlight = drain > now and (drain - now) * RATE / 1000 or 0
    if inFlight + bytes > cfg.latent.maxInFlightBytes then return false end
    drainAt[target] = (drain > now and drain or now) + bytes * 1000 / RATE
    return true
end

---@param options table
---@param bytes integer
---@return boolean
local function wantsLatent(options, bytes)
    local choice = options.latent
    if choice == 'always' then return true end
    if choice == 'never' then return false end
    return bytes > THRESHOLD
end

---@param label string
---@param bytes integer
---@param now integer
local function warnLarge(label, bytes, now)
    local last = largeWarnAt[label]
    if last and now - last < WINDOW_MS then return end
    largeWarnAt[label] = now
    log.warn('%s : %d octets envoyés en fiable (seuil du latent : %d) ; l\'ordre passe avant', label, bytes, THRESHOLD)
end

---@alias vAvA.NetNotice fun(target: integer, packet: vAvA.NetPacket)

--- Envoi d'un paquet mesuré à des cibles déjà validées.
---@param owner string
---@param label string
---@param targets integer|integer[]
---@param count integer
---@param options table
---@param packet vAvA.NetPacket
---@param notice? vAvA.NetNotice  appelé juste avant chaque envoi latent (préavis du RPC)
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
local function deliverTo(owner, label, targets, count, options, packet, notice)
    local bytes = packet.bytes
    local latent = wantsLatent(options, bytes)
    local now = GetGameTimer()
    if not latent and options.warnLarge and bytes > THRESHOLD then warnLarge(label, bytes, now) end
    if type(targets) == 'number' then
        if latent and not reserve(targets, bytes, now) then
            ownerError(owner, '%s : envoi latent refusé vers le joueur %d (plus de %d octets déjà en route)',
                label, targets, cfg.latent.maxInFlightBytes)
            return false, 'saturated'
        end
        if latent and notice then notice(targets, packet) end
        sendOne(packet, targets, latent)
        counter:record(now, owner, label, bytes, latent, targets)
        return true, 1, bytes, latent
    end
    -- liste : propre au core (copie de resolveTargets ou de collectNear), compactée sur place aux cibles servies
    local sent = 0
    for i = 1, count do
        local target = targets[i]
        if latent and not reserve(target, bytes, now) then
            ownerError(owner, '%s : envoi latent refusé vers le joueur %d (plus de %d octets déjà en route)',
                label, target, cfg.latent.maxInFlightBytes)
        else
            if latent and notice then notice(target, packet) end
            sendOne(packet, target, latent)
            sent = sent + 1
            targets[sent] = target
        end
    end
    counter:record(now, owner, label, bytes, latent, targets, sent)
    return true, sent, bytes, latent
end

--- Envoi d'un paquet déjà mesuré (réponses RPC : préavis avant l'envoi latent).
---@param owner string
---@param label string
---@param target integer|integer[]
---@param options table
---@param packet vAvA.NetPacket
---@param notice? vAvA.NetNotice
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
function net.deliver(owner, label, target, options, packet, notice)
    local targets, count, everyone = resolveTargets(target)
    if not targets then
        if everyone then refuseEveryone(owner, packet.event) end
        return false, count
    end
    if count == 0 then return true, 0, 0, false end
    return deliverTo(owner, label, targets, count, options or net.AUTO, packet, notice)
end

--- Cœur de tous les envois du core : sans contrôle de préfixe, mêmes contrôles de cible, de taille et de débit.
---@param owner string   ressource comptée
---@param label string   clé du compteur (évènement, « rpc <nom> »…)
---@param target integer|integer[]
---@param options table|nil  latent ('auto' | 'never' | 'always'), warnLarge
---@param event string
---@return boolean ok
---@return integer|string sent  joueurs servis, ou code d'erreur
---@return integer|nil bytes    taille d'un message
---@return boolean|nil latent
function net.dispatch(owner, label, target, options, event, ...)
    local targets, count, everyone = resolveTargets(target)
    if not targets then
        if everyone then refuseEveryone(owner, event) end
        return false, count
    end
    if select('#', ...) > cfg.maxArgs then return false, 'invalid_args' end
    if count == 0 then return true, 0, 0, false end
    local packet, code = net.prepare(owner, label, event, ...)
    if not packet then return false, code end
    return deliverTo(owner, label, targets, count, options or net.AUTO, packet)
end

--- Envoi aux joueurs proches d'un point (positions lues côté serveur), sans contrôle de préfixe.
---@param owner string
---@param label string
---@param options table|nil  latent, exclude, bucket
---@param coords vector3|table
---@param radius number
---@param event string
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
function net.dispatchNear(owner, label, options, coords, radius, event, ...)
    options = options or net.AUTO
    local x, y, z = readCoords(coords)
    if not x then return false, 'invalid_coords' end
    if not validRadius(radius) then return false, 'invalid_radius' end
    if select('#', ...) > cfg.maxArgs then return false, 'invalid_args' end
    local list, count = collectNear(x, y, z, radius, options)
    -- personne à portée : rien n'est sérialisé
    if count == 0 then return true, 0, 0, false end
    local packet, code = net.prepare(owner, label, event, ...)
    if not packet then return false, code end
    return deliverTo(owner, label, list, count, options, packet)
end

--- Surface des modules : un joueur ou une liste. Évènement préfixé par la ressource.
---@param owner string
---@param options any
---@param target any
---@param event any
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
function net.send(owner, options, target, event, ...)
    local checked = checkOptions(options, SEND_KEYS)
    if not checked then return false, 'invalid_options' end
    if not validEvent(owner, event) then return false, 'invalid_event' end
    return net.dispatch(owner, event, target, checked, event, ...)
end

--- Surface des modules : joueurs proches d'un point. Évènement préfixé par la ressource.
---@param owner string
---@param options any
---@param coords any
---@param radius any
---@param event any
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
function net.sendNear(owner, options, coords, radius, event, ...)
    local checked = checkOptions(options, NEAR_KEYS)
    if not checked then return false, 'invalid_options' end
    if not validEvent(owner, event) then return false, 'invalid_event' end
    return net.dispatchNear(owner, event, checked, coords, radius, event, ...)
end

--- Joueurs proches d'un point (même règle que sendNear), dans une nouvelle liste.
---@param coords any
---@param radius any
---@param options any  exclude, bucket
---@return integer[]|nil list
---@return string|nil code
function net.playersNear(coords, radius, options)
    local checked = checkOptions(options, PLAYERS_KEYS)
    if not checked then return nil, 'invalid_options' end
    local x, y, z = readCoords(coords)
    if not x then return nil, 'invalid_coords' end
    if not validRadius(radius) then return nil, 'invalid_radius' end
    return (collectNear(x, y, z, radius, checked))
end

--- Position du ped d'un joueur, lue côté serveur (essai réseau).
---@param src integer
---@return vector3|table|nil
function net.positionOf(src)
    return pedPosition(src) or nil
end

--- Vrai si un envoi latent de `bytes` octets vers ce joueur serait refusé (saturated), sans rien réserver.
---@param target integer
---@param bytes integer
---@return boolean
function net.wouldSaturate(target, bytes)
    local now = GetGameTimer()
    local drain = drainAt[target] or 0
    local inFlight = drain > now and (drain - now) * RATE / 1000 or 0
    return inFlight + bytes > cfg.latent.maxInFlightBytes
end

---@class vAvA.NetStatsOptions
---@field limit? integer     1 à 50 (défaut : command.lines)
---@field resource? string   seulement cette ressource
---@field target? integer    ce que reçoit ce joueur

--- Lecture du compteur sur la dernière minute.
---@param options vAvA.NetStatsOptions|nil
---@return table|nil stats  { mode, windowMs, total, events } (+ watched avec target)
---@return string|nil code
function net.stats(options)
    local limit, resource, target = min(cfg.command.lines, STATS_LIMIT_MAX), nil, nil
    if options ~= nil then
        if type(options) ~= 'table' then return nil, 'invalid_options' end
        for key in pairs(options) do
            if not STATS_KEYS[key] then return nil, 'invalid_options' end
        end
        if options.limit ~= nil then
            limit = options.limit
            if mathType(limit) ~= 'integer' or limit < 1 or limit > STATS_LIMIT_MAX then return nil, 'invalid_options' end
        end
        if options.resource ~= nil then
            resource = options.resource
            if type(resource) ~= 'string' or #resource > RESOURCE_MAX or not resource:match(RESOURCE_PATTERN) then
                return nil, 'invalid_options'
            end
        end
        if options.target ~= nil then
            target = options.target
            if mathType(target) ~= 'integer' or target <= 0 then return nil, 'invalid_options' end
        end
    end
    local result = counter:read(GetGameTimer(), { limit = limit, resource = resource, target = target })
    result.mode = mode
    return result
end

--- Commence le suivi d'un joueur, évènement par évènement, pour counter.watchMs.
---@param src integer
---@return boolean ok
---@return string state  'started' | 'already' | 'full'
function net.watch(src)
    return counter:watch(GetGameTimer(), src)
end

---@return 'exact'|'estimate'
function net.mode()
    return mode
end

--- Oublie un joueur parti : volume latent en route, totaux et suivi (son numéro peut être redonné).
---@param src integer
function net.purgePlayer(src)
    drainAt[src] = nil
    positionCache[src] = nil
    counter:forget(src)
end

--- Oublie l'état de limitation des erreurs d'une ressource arrêtée.
---@param owner string
function net.purgeOwner(owner)
    logStates[owner] = nil
end

--- Ménage périodique : clés du compteur sans envoi depuis une minute, échéances latentes passées.
local function sweep()
    local now = GetGameTimer()
    counter:sweep(now)
    for target, drain in pairs(drainAt) do
        if drain <= now then drainAt[target] = nil end
    end
    SetTimeout(cfg.counter.sweepMs, sweep)
end

--- Choisit le mode de mesure et lance le ménage du compteur. Appelé par init.lua, avant tout envoi.
function net.start()
    local missing = {}
    local packer = type(msgpack) == 'table' and msgpack.pack_args or nil
    if type(packer) ~= 'function' then missing[#missing + 1] = 'msgpack.pack_args' end
    if type(TriggerClientEventInternal) ~= 'function' then missing[#missing + 1] = 'TriggerClientEventInternal' end
    if type(TriggerLatentClientEventInternal) ~= 'function' then
        missing[#missing + 1] = 'TriggerLatentClientEventInternal'
    end
    if cfg.mode == 'estimate' then
        mode = 'estimate'
        log.info('[net] estimation (forcée par la config : net.mode = estimate)')
    elseif #missing > 0 then
        mode = 'estimate'
        log.warn('[net] estimation (fonctions du runtime absentes : %s)', concat(missing, ', '))
    else
        mode = 'exact'
        packArgs, sendInternal, sendLatentInternal = packer, TriggerClientEventInternal, TriggerLatentClientEventInternal
        log.info('[net] mesure exacte')
    end
    SetTimeout(cfg.counter.sweepMs, sweep)
end
