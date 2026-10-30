--[[
    server/core/net.lua
    Rôle : tous les envois serveur → client du core et ceux des modules qui passent par core.net. Pour chaque envoi :
           cible validée (jamais -1, jamais 0 : un joueur, une liste, ou les joueurs proches calculés ici), taille
           mesurée (exacte : la seule sérialisation, celle qui part ; sinon estimée par netsize), envoi fiable, ou
           latent à débit borné au-delà du seuil, volume latent en vol borné par joueur et en tout (0.11.0), compteur
           par ressource et par évènement (netstats). Aucune fonction ne lève d'erreur : true, envoyés, octets, latent
           (+ joueurs sautés pour une liste ou un rayon) | false, code. Un module peut aussi envoyer une charge déjà
           sérialisée chez lui (sendPacked) : une seule chaîne traverse l'export, le core l'envoie telle quelle.
    Ordre : deux messages fiables vers un même joueur arrivent dans l'ordre d'envoi ; un latent peut être dépassé par
           tout message envoyé après lui. Ce qui doit garder l'ordre (personnage, apparition) part en 'never'.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/string.lua, shared/core/logger.lua,
                  server/core/netsize.lua, server/core/netstats.lua ; vAvA.characters et vAvA.sync sont lus à l'appel
                  (chargés plus tard), jamais au chargement.
]]

local type, tostring, tonumber, select, next, pairs, pcall, rawlen, rawget =
    type, tostring, tonumber, select, next, pairs, pcall, rawlen, rawget
local mathType, huge, min, ceil, floor = math.type, math.huge, math.min, math.ceil, math.floor
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
local MAX_TOTAL_IN_FLIGHT = cfg.latent.maxTotalInFlightBytes
local WINDOW_MS = cfg.counter.bucketMs * cfg.counter.buckets
-- Préfixes que seul le core envoie : un module ne peut pas les prendre, même sous un nom de ressource qui y ressemble.
local RESERVED_PREFIXES = { 'vAvA:', 'core:' }
local STATS_LIMIT_MAX = 50
-- joueurs rendus au plus par stats({ players = true }) (les plus chargés d'abord)
local STATS_PLAYERS_MAX = 128
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
local NEAR_KEYS = { latent = true, exclude = true, bucket = true, from = true }
local PLAYERS_KEYS = { exclude = true, bucket = true, from = true }
local STATS_KEYS = { limit = true, resource = true, target = true, players = true }

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
-- positions des peds lues récemment (vidées near.positionCacheMs après le premier remplissage) : un passage des zones
-- et les sendNear qui le suivent ne relisent rien
local positionCache, positionTime = {}, nil
local POSITION_CACHE_MS = cfg.near.positionCacheMs

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
    local from = options.from
    if from ~= nil and (mathType(from) ~= 'integer' or from <= 0 or not DoesPlayerExist(from)) then return nil end
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

--- Position du ped d'un joueur, lue côté serveur (false : pas de ped). Gardée near.positionCacheMs (50 ms : 0,5 m
--- d'écart au plus à 10 m/s) après le premier remplissage du cache : un passage des zones lit chaque joueur une fois,
--- et les envois de proximité qui le suivent en profitent.
---@param src integer
---@return vector3|table|false
local function pedPosition(src)
    local now = GetGameTimer()
    if positionTime == nil or now - positionTime >= POSITION_CACHE_MS or now < positionTime then
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
--- `from` (joueur d'origine) : sauté, et seul son routing bucket compte, sauf `exclude` ou `bucket` donnés.
---@return integer[] list
---@return integer count
local function collectNear(x, y, z, radius, options)
    local list = {}
    local from, bucket = options.from, options.bucket
    if bucket == nil and from then bucket = GetPlayerRoutingBucket(from) end
    near.x, near.y, near.z, near.r2 = x, y, z, radius * radius
    near.exclude, near.bucket, near.list, near.count = options.exclude or from, bucket, list, 0
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

--- Envoie un paquet à une cible. false : charge déjà sérialisée par un module (sendPacked) dont l'envoi interne a
--- échoué : sans ses valeurs, elle ne peut pas être rejouée (la cible est comptée comme sautée).
---@param packet vAvA.NetPacket
---@param target integer
---@param latent boolean
---@return boolean sent
local function sendOne(packet, target, latent)
    local payload = packet.payload
    if payload and mode == 'exact' then
        local ok, err
        if latent then
            ok, err = pcall(sendLatentInternal, packet.event, tostring(target), payload, #payload, RATE)
        else
            ok, err = pcall(sendInternal, packet.event, tostring(target), payload, #payload)
        end
        if ok then return true end
        fallBack(err)
    end
    local args = packet.args
    if not args then
        log.error('%s : charge déjà sérialisée impossible à envoyer au joueur %d (mesure exacte indisponible)',
            packet.event, target)
        return false
    end
    if latent then
        TriggerLatentClientEvent(packet.event, target, RATE, unpack(args, 1, args.n))
    else
        TriggerClientEvent(packet.event, target, unpack(args, 1, args.n))
    end
    return true
end

--- Volume latent encore en route vers tous les joueurs (estimé au débit configuré).
---@param now integer
---@return number
local function totalInFlight(now)
    local total = 0
    for _, drain in pairs(drainAt) do
        if drain > now then total = total + (drain - now) * RATE / 1000 end
    end
    return total
end

--- Réserve la place d'un envoi latent vers un joueur ; false si le volume en route vers lui, ou vers tous les joueurs
--- (`total`, calculé une fois par envoi), dépasserait sa borne. Le premier envoi latent vers un joueur qui n'a rien en
--- route passe toujours le plafond global : un joueur n'est jamais privé de tout gros envoi par les autres.
---@param target integer
---@param bytes integer
---@param now integer
---@param total number  volume en route, tous joueurs confondus
---@return integer|false delayMs  délai au bout duquel ce message sera arrivé, latents déjà en route compris
---@return string|nil why         'player' | 'global'
local function reserve(target, bytes, now, total)
    local drain = drainAt[target] or 0
    local inFlight = drain > now and (drain - now) * RATE / 1000 or 0
    if inFlight + bytes > cfg.latent.maxInFlightBytes then return false, 'player' end
    if inFlight > 0 and total + bytes > MAX_TOTAL_IN_FLIGHT then return false, 'global' end
    drain = (drain > now and drain or now) + bytes * 1000 / RATE
    drainAt[target] = drain
    return ceil(drain - now)
end

---@param owner string
---@param label string
---@param target integer
---@param why string
---@param total number
local function refuseLatent(owner, label, target, why, total)
    if why == 'global' then
        ownerError(owner, '%s : envoi latent refusé vers le joueur %d : plafond global du latent atteint (%d octets en route)',
            label, target, floor(total))
    else
        ownerError(owner, '%s : envoi latent refusé vers le joueur %d (plus de %d octets déjà en route)',
            label, target, cfg.latent.maxInFlightBytes)
    end
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

---@alias vAvA.NetNotice fun(target: integer, packet: vAvA.NetPacket, delayMs: integer)  délai jusqu'à l'arrivée

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
---@return integer[]|nil skipped  liste : joueurs sautés (latent refusé, charge impossible à envoyer), nil si aucun
local function deliverTo(owner, label, targets, count, options, packet, notice)
    local bytes = packet.bytes
    local latent = wantsLatent(options, bytes)
    local now = GetGameTimer()
    if not latent and options.warnLarge and bytes > THRESHOLD then warnLarge(label, bytes, now) end
    -- volume latent en route, tous joueurs confondus : calculé une fois par envoi, augmenté de chaque cible acceptée
    local total = latent and totalInFlight(now) or 0
    if type(targets) == 'number' then
        if latent then
            local delay, why = reserve(targets, bytes, now, total)
            if not delay then
                refuseLatent(owner, label, targets, why, total)
                return false, 'saturated'
            end
            if notice then notice(targets, packet, delay) end
        end
        if not sendOne(packet, targets, latent) then return false, 'unsupported' end
        counter:record(now, owner, label, bytes, latent, targets)
        return true, 1, bytes, latent
    end
    -- liste : propre au core (copie de resolveTargets ou de collectNear), compactée sur place aux cibles servies
    local sent, skipped = 0, nil
    for i = 1, count do
        local target = targets[i]
        local served = true
        if latent then
            local delay, why = reserve(target, bytes, now, total)
            if delay then
                total = total + bytes
                if notice then notice(target, packet, delay) end
            else
                refuseLatent(owner, label, target, why, total)
                served = false
            end
        end
        if served then served = sendOne(packet, target, latent) end
        if served then
            sent = sent + 1
            targets[sent] = target
        else
            skipped = skipped or {}
            skipped[#skipped + 1] = target
        end
    end
    for i = sent + 1, count do targets[i] = nil end
    counter:record(now, owner, label, bytes, latent, targets, sent)
    return true, sent, bytes, latent, skipped
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
---@return integer[]|nil skipped  liste ou rayon : joueurs sautés, nil si aucun
function net.deliver(owner, label, target, options, packet, notice)
    local targets, count, everyone = resolveTargets(target)
    if not targets then
        if everyone then refuseEveryone(owner, packet.event) end
        return false, count
    end
    if count == 0 then return true, 0, 0, false end
    return deliverTo(owner, label, targets, count, options or net.AUTO, packet, notice)
end

--- Envoi d'un paquet déjà mesuré à une liste tenue par le core (abonnés d'une zone) : la liste donnée n'est pas
--- modifiée ; un joueur parti entre-temps est oublié (ni servi ni sauté).
---@param owner string
---@param label string
---@param list integer[]
---@param options table|nil
---@param packet vAvA.NetPacket
---@param notice? vAvA.NetNotice
---@return boolean ok
---@return integer[] served   nouvelle liste : joueurs servis
---@return integer[] skipped  nouvelle liste : joueurs sautés (latent refusé, charge impossible à envoyer)
---@return integer bytes
---@return boolean latent
function net.deliverList(owner, label, list, options, packet, notice)
    local targets, count = {}, 0
    for i = 1, #list do
        local src = list[i]
        if mathType(src) == 'integer' and src > 0 and DoesPlayerExist(src) then
            count = count + 1
            targets[count] = src
        end
    end
    if count == 0 then return true, targets, {}, 0, false end
    local _, _, bytes, latent, skipped = deliverTo(owner, label, targets, count, options or net.AUTO, packet, notice)
    return true, targets, skipped or {}, bytes, latent
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
---@return integer[]|nil skipped  liste : joueurs sautés (latent refusé), nil si aucun
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
---@return integer[]|nil skipped  joueurs sautés (latent refusé), nil si aucun
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
---@return integer[]|nil skipped  liste : joueurs sautés (latent refusé), nil si aucun
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
---@return integer[]|nil skipped  joueurs sautés (latent refusé), nil si aucun
function net.sendNear(owner, options, coords, radius, event, ...)
    local checked = checkOptions(options, NEAR_KEYS)
    if not checked then return false, 'invalid_options' end
    if not validEvent(owner, event) then return false, 'invalid_event' end
    return net.dispatchNear(owner, event, checked, coords, radius, event, ...)
end

--- Charge déjà sérialisée par un module (msgpack.pack_args) : non vide, message de maxBytes au plus.
---@param owner string
---@param event string
---@param payload any
---@return vAvA.NetPacket|nil packet  sans valeurs : impossible à rejouer par TriggerClientEvent
---@return string|nil code
local function packedPacket(owner, event, payload)
    if type(payload) ~= 'string' or #payload == 0 then return nil, 'invalid_args' end
    local bytes = #payload + #event
    if bytes > cfg.maxBytes then
        ownerError(owner, '%s : message de %d octets refusé (maximum %d)', event, bytes, cfg.maxBytes)
        return nil, 'too_large'
    end
    return { event = event, bytes = bytes, payload = payload }
end

--- Surface des modules : charge sérialisée par le module lui-même (une chaîne traverse l'export, sans parcours),
--- envoyée telle quelle à un joueur ou à une liste. Mêmes contrôles que send ; en estimation : 'unsupported', rien
--- n'est envoyé (le module renvoie alors par send).
---@param owner string
---@param options any
---@param target any
---@param event any
---@param payload any  chaîne produite par msgpack.pack_args(...)
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
---@return integer[]|nil skipped
function net.sendPacked(owner, options, target, event, payload)
    local checked = checkOptions(options, SEND_KEYS)
    if not checked then return false, 'invalid_options' end
    if not validEvent(owner, event) then return false, 'invalid_event' end
    local packet, code = packedPacket(owner, event, payload)
    if not packet then return false, code end
    local targets, count, everyone = resolveTargets(target)
    if not targets then
        if everyone then refuseEveryone(owner, event) end
        return false, count
    end
    if mode ~= 'exact' then return false, 'unsupported' end
    if count == 0 then return true, 0, 0, false end
    return deliverTo(owner, event, targets, count, checked, packet)
end

--- Surface des modules : charge sérialisée par le module, envoyée aux joueurs proches d'un point (règles de sendNear).
---@param owner string
---@param options any
---@param coords any
---@param radius any
---@param event any
---@param payload any
---@return boolean ok
---@return integer|string sent
---@return integer|nil bytes
---@return boolean|nil latent
---@return integer[]|nil skipped
function net.sendNearPacked(owner, options, coords, radius, event, payload)
    local checked = checkOptions(options, NEAR_KEYS)
    if not checked then return false, 'invalid_options' end
    if not validEvent(owner, event) then return false, 'invalid_event' end
    local packet, code = packedPacket(owner, event, payload)
    if not packet then return false, code end
    local x, y, z = readCoords(coords)
    if not x then return false, 'invalid_coords' end
    if not validRadius(radius) then return false, 'invalid_radius' end
    if mode ~= 'exact' then return false, 'unsupported' end
    local list, count = collectNear(x, y, z, radius, checked)
    if count == 0 then return true, 0, 0, false end
    return deliverTo(owner, event, list, count, checked, packet)
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

--- Vrai si un envoi latent de `bytes` octets vers ce joueur serait refusé (saturated : plafond du joueur ou plafond
--- global), sans rien réserver.
---@param target integer
---@param bytes integer
---@return boolean
function net.wouldSaturate(target, bytes)
    local now = GetGameTimer()
    local drain = drainAt[target] or 0
    local inFlight = drain > now and (drain - now) * RATE / 1000 or 0
    if inFlight + bytes > cfg.latent.maxInFlightBytes then return true end
    return inFlight > 0 and totalInFlight(now) + bytes > MAX_TOTAL_IN_FLIGHT
end

--- Oublie la position gardée d'un joueur : la prochaine lecture interroge son ped (apparition, téléportation).
---@param src integer
function net.forgetPosition(src)
    positionCache[src] = nil
end

---@class vAvA.NetStatsOptions
---@field limit? integer     1 à 50 (défaut : command.lines)
---@field resource? string   seulement cette ressource
---@field target? integer    ce que reçoit ce joueur
---@field players? boolean   aussi la liste des joueurs connectés (ni resource ni target)

--- Nom du personnage actif d'un joueur, ou nil (sans personnage).
---@param src integer
---@return string|nil
local function characterName(src)
    local characters = vAvA.characters
    local info = characters and characters.describeActive and characters.describeActive(src)
    if type(info) ~= 'table' or type(info.firstName) ~= 'string' or type(info.lastName) ~= 'string' then return nil end
    return info.firstName .. ' ' .. info.lastName
end

--- Joueurs connectés (numéros entiers), lus au runtime à l'appel ; nil si le runtime n'offre pas GetPlayers.
---@return integer[]|nil
local function connectedPlayers()
    local list = {}
    local getPlayers = GetPlayers
    if type(getPlayers) ~= 'function' then return nil end
    local players = getPlayers()
    if type(players) ~= 'table' then return nil end
    for i = 1, #players do
        local src = tonumber(players[i])
        if src and src > 0 then list[#list + 1] = floor(src) end
    end
    return list
end

--- Lecture du compteur sur la dernière minute.
---@param options vAvA.NetStatsOptions|nil
---@return table|nil stats  { mode, windowMs, total, events } (+ players, playerCount avec players ; + name avec target)
---@return string|nil code
function net.stats(options)
    local limit, resource, target, players = min(cfg.command.lines, STATS_LIMIT_MAX), nil, nil, false
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
        if options.players ~= nil then
            if type(options.players) ~= 'boolean' then return nil, 'invalid_options' end
            players = options.players
            if players and (resource or target) then return nil, 'invalid_options' end
        end
    end
    local now = GetGameTimer()
    if players then
        -- liste des joueurs : seul le total du royaume l'accompagne (aucun évènement construit ni trié)
        local sources = connectedPlayers()
        if not sources then return nil, 'unsupported' end
        local list = counter:listPlayers(now, sources, STATS_PLAYERS_MAX)
        for i = 1, #list do list[i].name = characterName(list[i].source) end
        return {
            mode = mode, windowMs = WINDOW_MS, total = counter:total(now), events = {},
            players = list, playerCount = #sources,
        }
    end
    local result = counter:read(now, { limit = limit, resource = resource, target = target })
    result.mode = mode
    if target then result.name = characterName(target) end
    return result
end

---@return 'exact'|'estimate'
function net.mode()
    return mode
end

--- Oublie un joueur parti : volume latent en route, totaux et détail (son numéro peut être redonné).
---@param src integer
function net.purgePlayer(src)
    drainAt[src] = nil
    positionCache[src] = nil
    counter:forget(src)
end

--- Oublie de nouveau le compteur d'un joueur parti, après son déchargement : ce qui lui a été envoyé pendant la
--- sauvegarde (hooks de déchargement) avait recréé son entrée.
---@param src integer
function net.forgetCounter(src)
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
