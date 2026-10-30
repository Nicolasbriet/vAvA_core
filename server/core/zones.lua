--[[
    server/core/zones.lua
    Rôle : abonnements de zone (core.zones). Un module déclare des zones (cercle au sol, marge) et tient leur état dans
           le core (paires clé → valeur, révision). À chaque passage (zones.passMs), le serveur lit une fois la position
           de chaque personnage présent, cherche dans la grille les zones proches, abonne les joueurs qui entrent dans le
           cercle d'intérêt (instantané, une seule sérialisation pour tous les entrants d'une zone) et désabonne ceux qui
           en sortent au-delà de la marge de sortie. Les changements d'un tour partent regroupés en une différence, en
           fiable, aux seuls abonnés à jour. Le client ne demande jamais d'entrer dans une zone : son seul RPC redemande
           l'instantané d'une zone qu'il suit déjà (core:zones:resync).
    Envois : tous par core.net (comptés, jamais -1) : état, préavis et différences sous la ressource de la zone, sorties
             sous vAvA_core.
    Dépendances : shared/init.lua, config/server.lua, shared/core/logger.lua,
                  server/core/net.lua, server/core/rpc.lua, server/core/zonegrid.lua, server/core/zonestate.lua ;
                  vAvA.characters et vAvA.sync sont lus à l'appel (chargés plus tard), jamais au chargement.
]]

local type, pairs, tostring, xpcall = type, pairs, tostring, xpcall
local traceback = debug.traceback
local mathType, huge, ceil, max = math.type, math.huge, math.ceil, math.max
local sort = table.sort
local clock = os.clock
local GetGameTimer, SetTimeout, GetPlayerRoutingBucket = GetGameTimer, SetTimeout, GetPlayerRoutingBucket

local EVENTS = vAvA.EVENTS
local MAX_HANDLE = vAvA.RPC_MAX_ID
local CORE_OWNER = vAvA.CORE_OWNER
local CORE_RESOURCE = vAvA.resourceName
local logger = vAvA.logger
local net = vAvA.net
local rpc = vAvA.rpc
local zonegrid = vAvA.zonegrid
local zonestate = vAvA.zonestate
local cfg = vAvA.config.server.zones
local log = logger.create('zones')

local zones = {}
vAvA.zones = zones

local READY, PENDING = 1, 2
local AREA_KEYS = { x = true, y = true, z = true, radius = true, margin = true, bucket = true }
local ID_PATTERN = '^[%w_%-%.:]+$'
local WARN_EVERY_MS = 60000
local MIN_PASS_MS = 100

local LIMITS = {
    maxKeys = cfg.maxKeys, keyMaxLength = cfg.keyMaxLength, maxChanges = cfg.maxChanges,
    maxValueBytes = cfg.maxValueBytes, maxStateBytes = cfg.maxStateBytes,
}

---@class vAvA.Zone
---@field handle integer
---@field owner string
---@field id string        identifiant local (sans le préfixe)
---@field name string      <ressource>:<id>
---@field x number
---@field y number
---@field radius number
---@field margin number
---@field bucket integer|nil
---@field enter2 number    (rayon + marge)²
---@field exit2 number     (rayon + marge + exitMargin)²
---@field data vAvA.ZoneState
---@field subs table<integer, integer>  joueur → READY | PENDING
---@field subCount integer

---@type table<integer, vAvA.Zone>
local byHandle = {}
---@type table<string, { zones: table<string, vAvA.Zone>, count: integer }>
local byOwner = {}
---@type table<integer, { zones: table<integer, true>, count: integer, pending: integer }>
local players = {}
local zoneCount, subscriptionCount, lastHandle = 0, 0, 0
local grid = zonegrid.new(cfg.cellSize)
local budget = zonestate.budget(cfg.maxTotalStateBytes)
-- zones dont des changements attendent la fin du tour
local dirty = {}
local flushScheduled = false
-- joueur → dernière alerte « trop de zones suivies »
local warnedAt = {}
-- durées des derniers passages (ms), une case par passage sur une minute
local passMs = cfg.passMs
local durations, durationIndex, lastDuration = {}, 0, nil
local durationSlots = 60
local started = false
local passLogState = {}

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

---@param id any
---@return boolean
local function validId(id)
    return type(id) == 'string' and #id > 0 and #id <= cfg.keyMaxLength and id:find(ID_PATTERN) ~= nil
end

--- Lieu d'une zone : table à clés connues, nombres finis et bornés. z accepté et ignoré (distance au sol).
---@param area any
---@return table|nil  { x, y, radius, margin, bucket }
local function readArea(area)
    if type(area) ~= 'table' then return nil end
    for key in pairs(area) do
        if not AREA_KEYS[key] then return nil end
    end
    local x, y, z, radius, margin, bucket = area.x, area.y, area.z, area.radius, area.margin, area.bucket
    if not finite(x) or not finite(y) or x > cfg.coordLimit or x < -cfg.coordLimit
        or y > cfg.coordLimit or y < -cfg.coordLimit then
        return nil
    end
    if z ~= nil and not finite(z) then return nil end
    if not finite(radius) or radius <= 0 or radius > cfg.maxRadius then return nil end
    if margin == nil then margin = cfg.defaultMargin end
    if not finite(margin) or margin < 0 or margin > cfg.maxMargin then return nil end
    if bucket ~= nil and (mathType(bucket) ~= 'integer' or bucket < 0) then return nil end
    return { x = x, y = y, radius = radius, margin = margin, bucket = bucket }
end

---@param zone vAvA.Zone
---@param area table
local function place(zone, area)
    zone.x, zone.y, zone.radius, zone.margin, zone.bucket = area.x, area.y, area.radius, area.margin, area.bucket
    local reach = area.radius + area.margin
    local exit = reach + cfg.exitMargin
    zone.enter2, zone.exit2 = reach * reach, exit * exit
    grid:insert(zone.handle, area.x, area.y, reach)
end

---@param owner string
---@param id any
---@return vAvA.Zone|nil
local function find(owner, id)
    local entry = byOwner[owner]
    return entry and type(id) == 'string' and entry.zones[id] or nil
end

---@param src integer
---@return { zones: table<integer, true>, count: integer, pending: integer }
local function playerEntry(src)
    local entry = players[src]
    if not entry then
        entry = { zones = {}, count = 0, pending = 0 }
        players[src] = entry
    end
    return entry
end

--- Change l'état d'abonnement d'un joueur à une zone (nil : désabonné), compteurs tenus à jour.
---@param zone vAvA.Zone
---@param src integer
---@param status integer|nil
local function setStatus(zone, src, status)
    local old = zone.subs[src]
    if old == status then return end
    local entry = playerEntry(src)
    if old == nil then
        zone.subCount = zone.subCount + 1
        subscriptionCount = subscriptionCount + 1
        entry.zones[zone.handle] = true
        entry.count = entry.count + 1
    elseif status == nil then
        zone.subCount = zone.subCount - 1
        subscriptionCount = subscriptionCount - 1
        entry.zones[zone.handle] = nil
        entry.count = entry.count - 1
    end
    if old == PENDING then entry.pending = entry.pending - 1 end
    if status == PENDING then entry.pending = entry.pending + 1 end
    zone.subs[src] = status
    if entry.count == 0 then players[src] = nil end
end

---@param zone vAvA.Zone
---@param status integer|nil  nil : tous les abonnés
---@return integer[]
local function subscribersOf(zone, status)
    local list = {}
    for src, current in pairs(zone.subs) do
        if status == nil or current == status then list[#list + 1] = src end
    end
    sort(list)
    return list
end

--- Préavis d'un instantané latent : lit le numéro et la révision dans le paquet (aucune fermeture par envoi).
---@param target integer
---@param packet vAvA.NetPacket
---@param delayMs integer
local function noticeSnapshot(target, packet, delayMs)
    local args = packet.args
    net.dispatch(packet.zoneOwner, EVENTS.ZONE_PENDING, target, net.NEVER, EVENTS.ZONE_PENDING, args[1], args[3], delayMs)
end

--- Instantané de la zone à une liste de joueurs : une sérialisation ; servis → à jour, sautés → en attente.
---@param zone vAvA.Zone
---@param list integer[]
local function sendSnapshot(zone, list)
    local data = zone.data
    local packet, code = net.prepare(zone.owner, EVENTS.ZONE_STATE, EVENTS.ZONE_STATE, zone.handle, zone.name,
        data.revision, data.state)
    if not packet then
        log.error('zone %s : instantané impossible à envoyer (%s)', zone.name, tostring(code))
        for i = 1, #list do
            if zone.subs[list[i]] then setStatus(zone, list[i], PENDING) end
        end
        return
    end
    packet.zoneOwner = zone.owner
    local _, served, skipped = net.deliverList(zone.owner, EVENTS.ZONE_STATE, list, net.AUTO, packet, noticeSnapshot)
    for i = 1, #served do setStatus(zone, served[i], READY) end
    for i = 1, #skipped do setStatus(zone, skipped[i], PENDING) end
end

--- Envoie les changements en attente d'une zone à ses abonnés à jour (différence, ou instantané si trop grosse).
---@param zone vAvA.Zone
local function flushZone(zone)
    dirty[zone.handle] = nil
    local diff = zone.data:flush()
    if not diff then return end
    local ready = subscribersOf(zone, READY)
    if #ready == 0 then return end
    if diff.bytes > cfg.maxDiffBytes then
        sendSnapshot(zone, ready)
        return
    end
    local ok, code = net.dispatch(zone.owner, EVENTS.ZONE_DIFF, ready, net.NEVER, EVENTS.ZONE_DIFF, zone.handle,
        diff.revision, diff.set, diff.removed)
    if not ok then
        -- impossible d'ordinaire (valeurs vérifiées à l'écriture) : les abonnés redemanderont l'instantané au trou
        log.error('zone %s : différence non envoyée (%s)', zone.name, tostring(code))
    end
end

local function flushAll()
    flushScheduled = false
    for handle in pairs(dirty) do
        local zone = byHandle[handle]
        if zone then flushZone(zone) else dirty[handle] = nil end
    end
end

---@param zone vAvA.Zone
local function markDirty(zone)
    dirty[zone.handle] = true
    if not flushScheduled then
        flushScheduled = true
        SetTimeout(0, flushAll)
    end
end

--- Oublie une zone (grille, mémoire, abonnements), sans rien envoyer.
---@param zone vAvA.Zone
local function forget(zone)
    for src in pairs(zone.subs) do setStatus(zone, src, nil) end
    grid:remove(zone.handle)
    zone.data:release()
    byHandle[zone.handle] = nil
    dirty[zone.handle] = nil
    local entry = byOwner[zone.owner]
    entry.zones[zone.id] = nil
    entry.count = entry.count - 1
    if entry.count == 0 then byOwner[zone.owner] = nil end
    zoneCount = zoneCount - 1
end

-- Passage ---------------------------------------------------------------------------------------------------------

-- État d'un passage : instantanés à envoyer, zone → liste des joueurs retenus.
local groups = nil

---@param zone vAvA.Zone
---@param src integer
local function retain(zone, src)
    groups = groups or {}
    local list = groups[zone]
    if not list then
        list = {}
        groups[zone] = list
    end
    list[#list + 1] = src
end

---@param src integer
---@param now integer
local function warnFull(src, now)
    local last = warnedAt[src]
    if last and now - last < WARN_EVERY_MS then return end
    warnedAt[src] = now
    log.warn('joueur %d : %d zones suivies, les plus lointaines attendent (zones.maxSubscriptionsPerPlayer)', src,
        cfg.maxSubscriptionsPerPlayer)
end

local function byDistance(a, b)
    return a[2] < b[2] or (a[2] == b[2] and a[1].handle < b[1].handle)
end

--- Sorties, entrées et instantanés retenus d'un personnage présent.
---@param character vAvA.Character
local function visit(character)
    if not vAvA.sync.isCurrent(character) then return end
    local src = character.source
    local position = net.positionOf(src)
    if not position then return end
    local px, py = position.x, position.y
    local bucket = GetPlayerRoutingBucket(src)
    local entry = players[src]
    -- sorties
    local leaving = nil
    if entry then
        for handle in pairs(entry.zones) do
            local zone = byHandle[handle]
            local dx, dy = px - zone.x, py - zone.y
            if dx * dx + dy * dy > zone.exit2 or (zone.bucket ~= nil and zone.bucket ~= bucket) then
                setStatus(zone, src, nil)
                leaving = leaving or {}
                leaving[#leaving + 1] = handle
            end
        end
        entry = players[src]
    end
    if leaving then
        sort(leaving)
        net.dispatch(CORE_RESOURCE, EVENTS.ZONE_LEAVE, src, net.NEVER, EVENTS.ZONE_LEAVE, leaving)
    end
    -- entrées : seulement un personnage apparu
    if character.spawned then
        local entering = nil
        local followed = entry and entry.zones
        for handle in pairs(grid:candidates(px, py)) do
            if not (followed and followed[handle]) then
                local zone = byHandle[handle]
                if zone.bucket == nil or zone.bucket == bucket then
                    local dx, dy = px - zone.x, py - zone.y
                    local distance2 = dx * dx + dy * dy
                    if distance2 <= zone.enter2 then
                        entering = entering or {}
                        entering[#entering + 1] = { zone, distance2 }
                    end
                end
            end
        end
        if entering then
            sort(entering, byDistance)
            local room = cfg.maxSubscriptionsPerPlayer - (entry and entry.count or 0)
            for i = 1, #entering do
                if i > room then
                    warnFull(src, GetGameTimer())
                    break
                end
                setStatus(entering[i][1], src, PENDING)
            end
            entry = players[src]
        end
    end
    -- instantanés en attente : les plus proches d'abord, dans le budget du passage (le premier toujours)
    if entry and entry.pending > 0 then
        local waiting = {}
        for handle in pairs(entry.zones) do
            local zone = byHandle[handle]
            if zone.subs[src] == PENDING then
                local dx, dy = px - zone.x, py - zone.y
                waiting[#waiting + 1] = { zone, dx * dx + dy * dy }
            end
        end
        sort(waiting, byDistance)
        local spent = 0
        for i = 1, #waiting do
            local zone = waiting[i][1]
            local bytes = zone.data:snapshotBytes()
            if i > 1 and spent + bytes > cfg.snapshotBudgetBytes then break end
            spent = spent + bytes
            retain(zone, src)
        end
    end
end

--- Envoie les instantanés retenus pendant le passage : une préparation par zone.
local function sendGroups()
    local retained = groups
    groups = nil
    if not retained then return end
    for zone, list in pairs(retained) do
        if byHandle[zone.handle] == zone then sendSnapshot(zone, list) end
    end
end

---@param ms number
local function recordDuration(ms)
    durationIndex = durationIndex % durationSlots + 1
    durations[durationIndex] = ms
    lastDuration = ms
end

local function runPass()
    local startedAt = clock()
    flushAll()
    vAvA.characters.forEachActive(visit)
    sendGroups()
    recordDuration((clock() - startedAt) * 1000)
end

local function pass()
    local ok, err = xpcall(runPass, traceback)
    groups = nil
    if not ok then
        local allowed, suppressed = logger.throttle(passLogState)
        if allowed then log.error('passage en erreur : %s%s', tostring(err), logger.suppressedNote(suppressed)) end
    end
    SetTimeout(passMs, pass)
end

-- Surface des modules ------------------------------------------------------------------------------------------------

--- Déclare une zone du module.
---@param owner string
---@param id any
---@param area any
---@param state any
---@return boolean ok
---@return integer|string handleOrCode
function zones.define(owner, id, area, state)
    if not validId(id) then return false, 'invalid_id' end
    if find(owner, id) then return false, 'exists' end
    local placeAt = readArea(area)
    if not placeAt then return false, 'invalid_area' end
    local entry = byOwner[owner]
    if zoneCount >= cfg.maxZones or (entry and entry.count >= cfg.maxZonesPerOwner) or lastHandle >= MAX_HANDLE then
        return false, 'full'
    end
    local data = zonestate.new(LIMITS, budget)
    local ok, code = data:load(state)
    if not ok then return false, code end
    lastHandle = lastHandle + 1
    local zone = {
        handle = lastHandle, owner = owner, id = id, name = owner .. ':' .. id, data = data, subs = {}, subCount = 0,
    }
    place(zone, placeAt)
    byHandle[zone.handle] = zone
    if not entry then
        entry = { zones = {}, count = 0 }
        byOwner[owner] = entry
    end
    entry.zones[id] = zone
    entry.count = entry.count + 1
    zoneCount = zoneCount + 1
    return true, zone.handle
end

--- Déplace une zone (centre, rayon, marge, instance) ; abonnés réévalués au passage suivant.
---@return boolean ok
---@return string|nil code
function zones.move(owner, id, area)
    local zone = find(owner, id)
    if not zone then return false, 'unknown_zone' end
    local placeAt = readArea(area)
    if not placeAt then return false, 'invalid_area' end
    place(zone, placeAt)
    return true
end

--- Change des clés de l'état ; envoyé aux abonnés à jour en fin de tour, regroupé.
---@return boolean ok
---@return string|nil code
function zones.set(owner, id, changes, removed)
    local zone = find(owner, id)
    if not zone then return false, 'unknown_zone' end
    local ok, code, pending = zone.data:set(changes, removed)
    if not ok then return false, code end
    if pending then markDirty(zone) end
    return true
end

--- Remplace tout l'état : instantané aux abonnés à jour.
---@return boolean ok
---@return string|nil code
function zones.replace(owner, id, state)
    local zone = find(owner, id)
    if not zone then return false, 'unknown_zone' end
    local ok, code = zone.data:replace(state)
    if not ok then return false, code end
    dirty[zone.handle] = nil
    local ready = subscribersOf(zone, READY)
    if #ready > 0 then sendSnapshot(zone, ready) end
    return true
end

--- Retire une zone : ses abonnés (à jour et en attente) reçoivent la sortie.
---@return boolean ok
---@return string|nil code
function zones.remove(owner, id)
    local zone = find(owner, id)
    if not zone then return false, 'unknown_zone' end
    local list = subscribersOf(zone, nil)
    if #list > 0 then
        net.dispatch(CORE_RESOURCE, EVENTS.ZONE_LEAVE, list, net.NEVER, EVENTS.ZONE_LEAVE, { zone.handle })
    end
    forget(zone)
    return true
end

--- Joueurs abonnés (à jour ou en attente), liste triée.
---@return integer[]|nil list
---@return string|nil code
function zones.subscribers(owner, id)
    local zone = find(owner, id)
    if not zone then return nil, 'unknown_zone' end
    return subscribersOf(zone, nil)
end

---@return table|nil info  { handle, revision, subscribers, keys, bytes }
---@return string|nil code
function zones.info(owner, id)
    local zone = find(owner, id)
    if not zone then return nil, 'unknown_zone' end
    local data = zone.data
    return { handle = zone.handle, revision = data.revision, subscribers = zone.subCount, keys = data.keys, bytes = data.bytes }
end

--- Identifiants locaux des zones du module, triés.
---@param owner string
---@return string[]
function zones.list(owner)
    local list = {}
    local entry = byOwner[owner]
    if entry then
        for id in pairs(entry.zones) do list[#list + 1] = id end
        sort(list)
    end
    return list
end

-- Service du core ---------------------------------------------------------------------------------------------------

--- Passage pour ce seul joueur (apparition confirmée) : ses zones proches lui arrivent sans attendre le passage.
---@param src integer
function zones.refreshPlayer(src)
    if not started then return end
    local found = nil
    vAvA.characters.forEachActive(function(character)
        if character.source == src then found = character end
    end)
    if not found then return end
    local ok, err = xpcall(function()
        flushAll()
        visit(found)
        sendGroups()
    end, traceback)
    groups = nil
    if not ok then log.error('passage du joueur %d en erreur : %s', src, tostring(err)) end
end

--- Oublie les abonnements d'un joueur, sans rien envoyer (déchargement, départ : le client nettoie de lui-même).
---@param src integer
function zones.purgePlayer(src)
    local entry = players[src]
    if entry then
        for handle in pairs(entry.zones) do
            local zone = byHandle[handle]
            if zone then setStatus(zone, src, nil) end
        end
    end
    players[src] = nil
    warnedAt[src] = nil
end

--- Oublie les zones d'un module arrêté, sans rien envoyer (le client oublie de lui-même les zones du module).
---@param owner string
function zones.purgeOwner(owner)
    local entry = byOwner[owner]
    if not entry then return end
    local list = {}
    for _, zone in pairs(entry.zones) do list[#list + 1] = zone end
    for i = 1, #list do forget(list[i]) end
end

--- Redemande d'instantané d'un joueur : zone déjà suivie seulement.
---@param src integer
---@param handle integer
---@return boolean ok
---@return string|nil code
local function resync(src, handle)
    local zone = byHandle[handle]
    local status = zone and zone.subs[src]
    if not status then return false, 'not_subscribed' end
    if status == PENDING then return true end
    if dirty[handle] then flushZone(zone) end
    -- la différence regroupée a pu partir en instantané (et le laisser en attente)
    if zone.subs[src] ~= READY then return true end
    sendSnapshot(zone, { src })
    return true
end

--- Enregistre core:zones:resync. Appelé par init.lua avec les RPC des personnages, avant rpc.start.
---@return boolean ok
---@return string|nil err
function zones.registerRpc()
    local ok, err = rpc.register(CORE_OWNER, vAvA.ZONE_RPC.RESYNC, {
        args = { { type = 'integer', min = 1, max = MAX_HANDLE } },
        rateLimit = cfg.rateLimit,
    }, resync)
    if not ok then return false, vAvA.ZONE_RPC.RESYNC .. ' : ' .. tostring(err) end
    return true
end

--- Lance les passages. Appelé par init.lua, core prêt.
function zones.start()
    if started then return end
    started = true
    if mathType(passMs) ~= 'integer' or passMs < MIN_PASS_MS then
        log.warn('zones.passMs invalide (%s) : 1000 ms', tostring(passMs))
        passMs = 1000
    end
    durationSlots = max(1, ceil(60000 / passMs))
    log.info('[zones] passage toutes les %d ms, cases de %d m', passMs, cfg.cellSize)
    SetTimeout(passMs, pass)
end

--- Lecture pour /vava_reseau zones.
---@return table  { zones, owners = { { owner, count } } triés, subscriptions, lastPassMs, maxPassMs, passMs }
function zones.stats()
    local owners = {}
    for owner, entry in pairs(byOwner) do owners[#owners + 1] = { owner = owner, count = entry.count } end
    sort(owners, function(a, b) return a.count > b.count or (a.count == b.count and a.owner < b.owner) end)
    local longest = nil
    for i = 1, durationSlots do
        local ms = durations[i]
        if ms and (not longest or ms > longest) then longest = ms end
    end
    return {
        zones = zoneCount, owners = owners, subscriptions = subscriptionCount,
        lastPassMs = lastDuration, maxPassMs = longest, passMs = passMs,
    }
end

--- Noms des zones suivies par un joueur, triés.
---@param src integer
---@return string[]
function zones.ofPlayer(src)
    local names = {}
    local entry = players[src]
    if entry then
        for handle in pairs(entry.zones) do names[#names + 1] = byHandle[handle].name end
        sort(names)
    end
    return names
end

--- Octets estimés de tous les états (budget commun), pour les tests et le suivi.
---@return integer
function zones.stateBytes()
    return budget.used
end

