--[[
    vava_gathering/client/props.lua
    Rôle : les nœuds de récolte dans le monde, vus du joueur : zones reçues des seuls serveurs proches, par les
           abonnements de zone du core (core.zones.watch, 1.6.0) ; depuis 1.8.0 (T-102), chaque zone porte aussi son nom,
           son type et son lieu (`def`) et ses points (`p:<nœud>` : ressource, lieu, cap) — rien ne vient plus de la
           config : une zone ou un point publiés dans l'Atelier paraissent sans redémarrage. Props LOCAUX (jamais
           réseau) créés pour les nœuds à portée (modèle de leur ressource, `resources[…].prop`) et remplacés par leur
           modèle « épuisé » quand la zone l'est ; nœud le plus proche à distance d'interaction.
           Essai de l'Atelier (au seul auteur) : la zone essayée remplace l'affichage de la zone du même nom (ses points,
           leurs charges d'essai) et compte comme une zone suivie ; sa fin rend l'état publié.
           Une seule boucle lente, active seulement quand un personnage est en jeu et suit au moins une zone : elle ne
           mesure que les zones suivies (centre et étendue de leurs nœuds), ne parcourt que les nœuds d'une zone à
           portée, passe toutes les streaming.pollMs près d'une zone et toutes les streaming.idlePollMs loin de
           toutes ; les nœuds d'une zone ne sont regroupés de nouveau que quand cette zone entre, change ou sort, et
           elle fait aussitôt un passage ; la boucle s'arrête d'elle-même quand plus aucune zone n'est suivie, à la
           sélection et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config_client.lua, shared/geometry.lua, shared/proximity.lua, shared/zonestate.lua,
                  client/core.lua (core.zones, vAvA_core 0.11.0)
]]

local type, pairs, ipairs, next, huge, max, tostring = type, pairs, ipairs, next, math.huge, math.max, tostring
local sort = table.sort
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local streaming = cfg.streaming
local resources = cfg.resources
local geometry = VavaGathering.geometry
local proximity = VavaGathering.proximity
local zonestate = VavaGathering.zonestate
local BANDS = VavaGathering.BANDS
local RESOURCE = VavaGathering.resource
local LOAD_POLL_MS = 50
-- charges montrées d'un nœud dont le serveur n'a pas encore envoyé les siennes
local UNKNOWN_CHARGES = 1

local props = {}
VavaGathering.props = props

-- un nœud est mesuré si sa zone peut en avoir un à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

-- zones suivies, reçues du serveur : id de zone → enregistrement (shared/zonestate.lua › decode)
---@type table<string, vAvA.GatheringZoneRecord>
local followed = {}
-- essais de l'Atelier reçus (auteur seul) : id de zone → enregistrement (shared/zonestate.lua › trial)
---@type table<string, vAvA.GatheringTrialRecord>
local trials = {}
-- nœuds regroupés par zone (reconstruits pour la seule zone qui entre, change ou sort) : id de zone → groupe
local groups = {}
-- nœuds montrés, par identifiant : { id, zone, resource, x, y, z, heading }
local nodesById = {}
-- props affichés : id de nœud → { entity, model, loading }
local shown = {}
local running, playing = false, false
local nearestId, nearestDistance = nil, nil
---@type fun(nodeId: string|nil)|nil
local onNearest = nil
---@type fun(zoneId: string, def: table|nil)|nil
local onDef = nil

local DEFAULT_ZONE = { band = BANDS.NORMAL, scarred = false }

--- Ce qui est montré d'une zone : l'essai de l'auteur s'il y en a un, sinon l'état publié reçu.
local function viewOf(zoneId)
    return trials[zoneId] or followed[zoneId]
end

---@param id string
---@return table|nil
function props.node(id)
    return nodesById[id]
end

--- Nom, type et lieu d'une zone montrée ({ label, kind, x, y, z, radius }), ou nil.
---@param zoneId string
---@return table|nil
function props.zone(zoneId)
    local view = viewOf(zoneId)
    return view and view.def or nil
end

---@param node table
---@return table|nil
function props.resource(node)
    return resources[node.resource]
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

--- Zone d'eau (type de lieu dans config.waterKinds) ?
---@param zoneId string
---@return boolean
function props.isWater(zoneId)
    local def = props.zone(zoneId)
    return def ~= nil and type(cfg.waterKinds) == 'table' and cfg.waterKinds[def.kind] == true
end

--- La zone est-elle montrée en essai (auteur seul) ?
---@param zoneId string
---@return boolean
function props.isTrial(zoneId)
    return trials[zoneId] ~= nil
end

--- Charges d'un nœud : celles de l'essai, sinon celles reçues du serveur.
---@param node table
---@return integer
function props.charges(node)
    local trial = trials[node.zone]
    if trial then
        local item = trial.nodes[node.id]
        return item and item.charges or 0
    end
    local record = followed[node.zone]
    local charges = record and record.charges[node.id]
    if type(charges) == 'number' then return charges end
    return UNKNOWN_CHARGES
end

---@param node table
---@return string|nil
local function modelFor(node)
    local resource = resources[node.resource]
    if not resource or type(resource.prop) ~= 'table' then return nil end
    return props.isDepleted(node.zone) and resource.prop.depleted or resource.prop.model
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
    local model = distance <= streaming.radius and modelFor(node) or nil
    if not model then
        if entry then remove(node.id) end
        return
    end
    if entry then
        if entry.loading or entry.model == model then return end
        remove(node.id)
    end
    spawn(node, model)
end

--- Nœuds montrés d'une zone, triés par identifiant (ressource connue du client seulement).
local function nodesOfView(zoneId, view)
    local list = {}
    for id, place in pairs(view.nodes) do
        if resources[place.resource] then
            list[#list + 1] = { id = id, zone = zoneId, resource = place.resource, x = place.x, y = place.y,
                z = place.z, heading = place.heading or 0.0 }
        end
    end
    sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function sameNode(a, b)
    return a.x == b.x and a.y == b.y and a.z == b.z and a.heading == b.heading and a.resource == b.resource
end

--- Regroupe de nouveau les nœuds d'une seule zone (entrée, changement, sortie, essai) : un nœud disparu ou changé perd
--- son prop (recréé au passage suivant s'il est à portée).
---@param zoneId string
local function rebuild(zoneId)
    local old = groups[zoneId]
    local view = viewOf(zoneId)
    local list = view and nodesOfView(zoneId, view) or {}
    local byId = {}
    for _, node in ipairs(list) do byId[node.id] = node end
    for _, node in ipairs(old and old.targets or {}) do
        local newer = byId[node.id]
        if not newer or not sameNode(node, newer) then remove(node.id) end
        if not newer and nodesById[node.id] == node then nodesById[node.id] = nil end
    end
    for _, node in ipairs(list) do nodesById[node.id] = node end
    local group = #list > 0 and proximity.group(list, function() return zoneId end)[1] or nil
    if group then group.active = true end
    groups[zoneId] = group
end

--- Retire une fois les props d'un groupe sorti de portée.
---@param group table
local function deactivate(group)
    group.active = false
    for _, node in ipairs(group.targets) do remove(node.id) end
end

--- Un passage : une distance par zone montrée, puis une par nœud des seules zones à portée ; une zone qui sort de
--- portée retire ses props une fois. Ne cède jamais la main. Rend l'intervalle du prochain passage.
---@return integer
local function step()
    local coords = GetEntityCoords(PlayerPedId())
    local px, py, pz = coords.x, coords.y, coords.z
    local bestId, bestDistance = nil, cfg.interact.distance
    local closest = huge
    for _, group in pairs(groups) do
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
    end
    nearestId, nearestDistance = bestId, bestDistance
    if onNearest then onNearest(bestId) end
    return proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs)
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu et suit au moins une zone (voir step).
local function loop()
    while playing and next(groups) ~= nil do
        Wait(step())
    end
    for id in pairs(shown) do remove(id) end
    nearestId, nearestDistance = nil, nil
    if onNearest then onNearest(nil) end
    running = false
end

--- Lance la boucle si elle doit tourner et ne tourne pas.
local function wake()
    if playing and not running and next(groups) ~= nil then
        running = true
        CreateThread(loop)
    end
end

--- Une zone a changé : regroupée, passage aussitôt (props et invite à jour sans attendre).
local function changed(zoneId)
    rebuild(zoneId)
    if playing then
        step()
        wake()
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

--- Appelé quand une zone suivie porte (ou change) son nom, son type et son lieu : blip corrigé (client/blips.lua).
---@param fn fun(zoneId: string, def: table|nil)
function props.onDef(fn)
    onDef = fn
end

--- Zones de récolte proches, envoyées par le core aux seuls joueurs à portée (nom local = id de la zone) : entrée
--- (état entier, ou de nouveau entier après un trou), changement (clés changées, clés retirées), sortie.
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
    local record = followed[id]
    if record and record.def and onDef then onDef(id, record.def) end
    changed(id)
end

--- Essai de l'Atelier reçu (auteur seul) : entier ou différence.
---@param payload any
function props.trial(payload)
    local zoneId = zonestate.trialZone(payload)
    if not zoneId then return end
    local record = zonestate.trial(trials[zoneId], payload)
    if not record then return end
    trials[zoneId] = record
    changed(zoneId)
end

--- Fin de l'essai d'une zone : l'état publié est rendu.
---@param zoneId any
function props.trialEnd(zoneId)
    zoneId = zonestate.trialZone(zoneId)
    if not zoneId or not trials[zoneId] then return end
    trials[zoneId] = nil
    changed(zoneId)
end

--- Personnage déchargé ou retour à la sélection : les essais montrés sont oubliés.
local function forgetTrials()
    for zoneId in pairs(trials) do
        trials[zoneId] = nil
        rebuild(zoneId)
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
    core.hooks.after('core:character:selection', function()
        forgetTrials()
        props.setPlaying(false)
    end)
    core.hooks.after('core:character:unloaded', function()
        forgetTrials()
        props.setPlaying(false)
    end)
    if core.characters.current() and not core.characters.awaitingSelection() then props.setPlaying(true) end
end

-- arrêt du module : aucun prop ne doit rester dans le monde
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    playing = false
    for id in pairs(shown) do remove(id) end
end)
