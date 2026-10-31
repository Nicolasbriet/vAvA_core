--[[
    vava_gathering/client/props.lua
    Rôle : les nœuds de récolte dans le monde, vus du joueur : état des zones et des nœuds (bande de vitalité,
           cicatrice, charges) reçu des seules zones proches, par les abonnements de zone du core (core.zones.watch,
           1.6.0) ; props LOCAUX (jamais réseau) créés pour les nœuds à portée et remplacés par leur modèle « épuisé »
           quand la zone l'est, nœud le plus proche à distance d'interaction.
           Une seule boucle lente, active seulement quand un personnage est en jeu et suit au moins une zone : elle ne
           mesure que les zones suivies (centre et étendue de leurs nœuds), ne parcourt que les nœuds d'une zone à
           portée, passe toutes les streaming.pollMs près d'une zone et toutes les streaming.idlePollMs loin de
           toutes ; une zone reçue, changée ou quittée fait aussitôt un passage (props et invite à jour sans attendre),
           la première reçue relance la boucle ; elle s'arrête d'elle-même quand plus aucune zone n'est suivie, à la
           sélection et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config_client.lua, shared/geometry.lua, shared/proximity.lua, shared/zonestate.lua,
                  client/core.lua (core.zones, vAvA_core 0.11.0)
]]

local type, pairs, ipairs, next, huge, max, tostring = type, pairs, ipairs, next, math.huge, math.max, tostring
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local streaming = cfg.streaming
local geometry = VavaGathering.geometry
local proximity = VavaGathering.proximity
local zonestate = VavaGathering.zonestate
local BANDS = VavaGathering.BANDS
local RESOURCE = VavaGathering.resource
local LOAD_POLL_MS = 50

local props = {}
VavaGathering.props = props

-- index de la config
local zonesById, nodesById = {}, {}
for _, zone in ipairs(cfg.zones) do zonesById[zone.id] = zone end
for _, node in ipairs(cfg.nodes) do nodesById[node.id] = node end
-- nœuds regroupés par zone (la config ne change pas en jeu) ; un groupe naît « actif » pour que le premier passage
-- retire ce qui serait hors de portée
local groups = proximity.group(cfg.nodes, function(node) return node.zone or ('node:' .. node.id) end)
for _, group in ipairs(groups) do group.active = true end
-- un nœud est mesuré si sa zone peut en avoir un à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

-- zones suivies, reçues du serveur : id de zone → { zone = { band, scarred } | nil, charges = { [nœud] = charges } }
---@type table<string, vAvA.GatheringZoneRecord>
local followed = {}
-- props affichés : id de nœud → { entity, model, loading }
local shown = {}
local running, playing = false, false
local nearestId, nearestDistance = nil, nil
---@type fun(nodeId: string|nil)|nil
local onNearest = nil

local DEFAULT_ZONE = { band = BANDS.NORMAL, scarred = false }

---@param id string
---@return table|nil
function props.node(id)
    return nodesById[id]
end

---@param id string
---@return table|nil
function props.zone(id)
    return zonesById[id]
end

---@param node table
---@return table|nil
function props.resource(node)
    return cfg.resources[node.resource]
end

--- État d'une zone (pleine, sans cicatrice, tant que le serveur ne l'a pas envoyée).
---@param zoneId string
---@return { band: string, scarred: boolean }
function props.zoneState(zoneId)
    local record = followed[zoneId]
    return record and record.zone or DEFAULT_ZONE
end

---@param zoneId string
---@return boolean
function props.isDepleted(zoneId)
    local state = props.zoneState(zoneId)
    return state.band == BANDS.DEPLETED or state.scarred == true
end

--- Charges d'un nœud (celles de la config tant que le serveur ne les a pas envoyées).
---@param node table
---@return integer
function props.charges(node)
    local record = followed[node.zone]
    local charges = record and record.charges[node.id]
    if type(charges) == 'number' then return charges end
    return node.charges
end

---@param node table
---@return string
local function modelFor(node)
    return props.isDepleted(node.zone) and node.prop.depleted or node.prop.model
end

---@param id string
local function remove(id)
    local entry = shown[id]
    if not entry then return end
    shown[id] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

--- Crée le prop d'un nœud (modèle chargé avec une attente bornée), dans son propre thread.
---@param node table
---@param model string
local function spawn(node, model)
    local entry = { entity = nil, model = model, loading = true }
    shown[node.id] = entry
    CreateThread(function()
        local hash = GetHashKey(model)
        if not IsModelValid(hash) then
            core.log.warn("nœud %s : modèle inconnu '%s'", node.id, model)
            entry.loading = false
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + streaming.modelTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        -- le nœud a pu sortir de portée ou changer de modèle pendant le chargement
        if shown[node.id] ~= entry or not HasModelLoaded(hash) then
            if shown[node.id] == entry then shown[node.id] = nil end
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, node.x, node.y, node.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if entity == 0 then
            shown[node.id] = nil
            return
        end
        SetEntityHeading(entity, node.heading or 0.0)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met le prop d'un nœud en accord avec sa distance et l'état de sa zone.
---@param node table
---@param distance number
local function reconcile(node, distance)
    local entry = shown[node.id]
    if distance > streaming.radius then
        if entry then remove(node.id) end
        return
    end
    local model = modelFor(node)
    if entry then
        if entry.loading or entry.model == model then return end
        remove(node.id)
    end
    spawn(node, model)
end

--- Retire une fois les props d'un groupe sorti de portée (ou dont la zone n'est plus suivie).
---@param group table
local function deactivate(group)
    group.active = false
    for _, node in ipairs(group.targets) do remove(node.id) end
end

--- Un passage : une distance par zone suivie, puis une par nœud des seules zones à portée ; une zone qui sort de
--- portée ou n'est plus suivie retire ses props une fois. Ne cède jamais la main. Rend l'intervalle du prochain
--- passage : streaming.pollMs près d'une zone, streaming.idlePollMs quand aucun nœud ne peut être à moins de radius +
--- idleMargin (aucune zone suivie : la boucle s'arrête, et la prochaine zone reçue fait aussitôt un passage).
---@return integer
local function step()
    local coords = GetEntityCoords(PlayerPedId())
    local px, py, pz = coords.x, coords.y, coords.z
    local bestId, bestDistance = nil, cfg.interact.distance
    local closest = huge
    for _, group in ipairs(groups) do
        if followed[group.key] then
            local reachable, gap = proximity.reachable(group, px, py, pz, REACH)
            if gap < closest then closest = gap end
            if reachable then
                group.active = true
                for _, node in ipairs(group.targets) do
                    local distance = geometry.distance(px, py, pz, node.x, node.y, node.z)
                    reconcile(node, distance)
                    if distance <= bestDistance then bestId, bestDistance = node.id, distance end
                end
            elseif group.active then
                deactivate(group)
            end
        elseif group.active then
            deactivate(group)
        end
    end
    nearestId, nearestDistance = bestId, bestDistance
    if onNearest then onNearest(bestId) end
    return proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs)
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu et suit au moins une zone (voir step) : loin de
--- toute zone de récolte, elle ne tourne pas ; la première zone reçue la relance.
local function loop()
    while playing and next(followed) ~= nil do
        Wait(step())
    end
    for id in pairs(shown) do remove(id) end
    nearestId, nearestDistance = nil, nil
    if onNearest then onNearest(nil) end
    running = false
end

--- Lance la boucle si elle doit tourner et ne tourne pas.
local function wake()
    if playing and not running and next(followed) ~= nil then
        running = true
        CreateThread(loop)
    end
end

--- Personnage en jeu ou non : la boucle démarre (s'il suit une zone) ou s'éteint.
---@param flag boolean
function props.setPlaying(flag)
    playing = flag
    wake()
end

--- Nœud le plus proche à distance d'interaction (et sa distance), ou nil.
---@return string|nil nodeId
---@return number|nil distance
function props.nearest()
    return nearestId, nearestDistance
end

--- Appelé à chaque passage de la boucle avec le nœud le plus proche (ou nil).
---@param fn fun(nodeId: string|nil)
function props.onNearest(fn)
    onNearest = fn
end

--- Zones de récolte proches, envoyées par le core aux seuls joueurs à portée (nom local = id de la zone ; état
--- `zone` → { band, scarred }, `n:<nœud>` → charges) : entrée (état entier, ou de nouveau entier après un trou),
--- changement (clés changées, clés retirées), sortie (valeurs par défaut). Le monde suit aussitôt.
---@param kind string  'enter' | 'change' | 'leave'
---@param id any
---@param data any   état (enter) ou clés changées (change)
---@param removed any clés retirées (change)
local function onZone(kind, id, data, removed)
    if type(id) ~= 'string' then return end
    if kind == 'enter' then
        followed[id] = zonestate.decode(data)
    elseif kind == 'change' then
        local record = followed[id]
        if not record then return end
        zonestate.patch(record, data, removed)
    elseif kind == 'leave' then
        followed[id] = nil
    else
        return
    end
    if playing then
        step()
        wake()
    end
end

--- Suit les zones de récolte proches (abonnements de zone du core) et la vie du personnage. Appelé par client/main.lua.
function props.start()
    if core.zones then
        local watched, watchErr = core.zones.watch(onZone)
        if not watched then core.log.error('zones de récolte non suivies : %s', tostring(watchErr)) end
    else
        core.log.error('zones de récolte indisponibles : vAvA_core 0.11.0 au moins est requis')
    end

    core.hooks.after('core:character:spawning', function() props.setPlaying(true) end)
    core.hooks.after('core:character:selection', function() props.setPlaying(false) end)
    core.hooks.after('core:character:unloaded', function() props.setPlaying(false) end)
    if core.characters.current() and not core.characters.awaitingSelection() then props.setPlaying(true) end
end

-- arrêt du module : aucun prop ne doit rester dans le monde
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    playing = false
    for id in pairs(shown) do remove(id) end
end)
