--[[
    vava_crafting/client/props.lua
    Rôle : les stations d'artisanat dans le monde, vues du joueur : seulement celles que le serveur lui envoie, par les
           abonnements de zone du core (une zone par station, vAvA_core 0.11.0) — dessin (type et son nom, réserve,
           nom, position, modèle) et état (combustible, occupée) —, tenues dans un carnet (shared/stationzone.lua) ;
           props LOCAUX (jamais réseau) créés pour les stations à portée, station la plus proche à distance
           d'interaction. Une seule boucle
           lente, active seulement quand un personnage est en jeu ET qu'une station est connue (aucune boucle loin de
           toute station) : elle mesure d'abord les groupes de stations (par case de streaming.groupCell), ne parcourt
           que les stations d'un groupe à portée, passe toutes les streaming.pollMs près d'un groupe et toutes les
           streaming.idlePollMs loin de tous ; une station reçue, déplacée ou oubliée fait aussitôt un passage ; elle
           s'arrête d'elle-même à la sélection, au déchargement et quand la dernière station connue est oubliée, et
           retire alors tous les props. Le menu ouvert sur une station oubliée se ferme (props.onForget).
    Dépendances : shared/constants.lua, config_client.lua, shared/proximity.lua, shared/stationzone.lua, client/core.lua
                  (core.zones : vAvA_core 0.11.0)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local sqrt, max, huge = math.sqrt, math.max, math.huge
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly

local core = VavaCrafting.core
if not core then return end

local cfg = VavaCrafting.config
local streaming = cfg.streaming
local proximity = VavaCrafting.proximity
local stationzone = VavaCrafting.stationzone
local RESOURCE = VavaCrafting.resource
local LOAD_POLL_MS = 50

local props = {}
VavaCrafting.props = props

-- stations connues : celles des zones suivies (le serveur décide lesquelles, d'après la position du joueur)
local book = stationzone.book()
-- stations groupées par case de grille, refaites au passage qui suit un changement de lieu
local groups, regroup = {}, false
-- props affichés : id de station → { entity, model, loading }
local shown = {}
-- une station est mesurée si son groupe peut en avoir une à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

local running, playing = false, false
local nearestId, nearestDistance = nil, nil
---@type fun(stationId: string|nil)|nil
local onNearest = nil
---@type fun(stationId: string, status: { fuel: number, busy: boolean })|nil
local onStatus = nil
---@type fun(stationId: string)|nil
local onForget = nil

---@param station table
---@return string
local function cellOf(station)
    return proximity.cell(station.x, station.y, streaming.groupCell)
end

---@return number
local function distance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz)
end

---@param id string
---@return table|nil
function props.station(id)
    return book:station(id)
end

--- État d'une station (vide et libre tant que le serveur n'a rien envoyé).
---@param stationId string
---@return { fuel: number, busy: boolean }
function props.state(stationId)
    return book:status(stationId)
end

---@param id string
local function remove(id)
    local entry = shown[id]
    if not entry then return end
    shown[id] = nil
    if entry.entity and DeleteObject and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end
props.remove = remove

--- Crée le prop d'une station (modèle chargé avec une attente bornée), dans son propre thread.
---@param station table
---@param model string
local function spawn(station, model)
    local entry = { entity = nil, model = model, loading = true }
    shown[station.id] = entry
    CreateThread(function()
        local hash = GetHashKey(model)
        if not IsModelValid(hash) then
            core.log.warn("station %s : modèle inconnu '%s'", station.id, model)
            entry.loading = false
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + streaming.modelTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        -- la station a pu sortir de portée (ou bouger) pendant le chargement
        if shown[station.id] ~= entry or not HasModelLoaded(hash) then
            if shown[station.id] == entry then shown[station.id] = nil end
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, station.x, station.y, station.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if entity == 0 then
            shown[station.id] = nil
            return
        end
        SetEntityHeading(entity, station.heading or 0.0)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met le prop d'une station en accord avec sa distance.
---@param station table
---@param far number
local function reconcile(station, far)
    local entry = shown[station.id]
    if far > streaming.radius then
        if entry then remove(station.id) end
        return
    end
    if entry then return end
    -- modèle de la station, sinon de son type : résolu par le serveur dans le dessin
    if station.prop then spawn(station, station.prop) end
end

--- Groupes refaits depuis le carnet ; un groupe naît « actif » pour que le premier passage retire ce qui serait hors
--- de portée.
local function rebuildGroups()
    regroup = false
    groups = proximity.group(book:list(), cellOf)
    for _, group in ipairs(groups) do group.active = true end
end

--- Un passage : une distance par groupe de stations, puis une par station des seuls groupes à portée ; un groupe qui
--- sort de portée retire ses props une fois. Ne cède jamais la main. Rend l'intervalle du prochain passage :
--- streaming.pollMs près d'un groupe, streaming.idlePollMs quand aucune station ne peut être à moins de radius +
--- idleMargin.
---@return integer
local function step()
    if regroup then rebuildGroups() end
    local coords = GetEntityCoords(PlayerPedId())
    local px, py, pz = coords.x, coords.y, coords.z
    local bestId, bestDistance = nil, cfg.interact.distance
    local closest = huge
    for _, group in ipairs(groups) do
        local reachable, gap = proximity.reachable(group, px, py, pz, REACH)
        if gap < closest then closest = gap end
        if reachable then
            group.active = true
            for _, station in ipairs(group.targets) do
                local far = distance(px, py, pz, station.x, station.y, station.z)
                reconcile(station, far)
                if far <= bestDistance then bestId, bestDistance = station.id, far end
            end
        elseif group.active then
            group.active = false
            for _, station in ipairs(group.targets) do remove(station.id) end
        end
    end
    nearestId, nearestDistance = bestId, bestDistance
    if onNearest then onNearest(bestId) end
    return proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs)
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu et qu'une station est connue (voir step). Une
--- station reçue, déplacée ou oubliée fait aussitôt un passage hors de la boucle (onZone) : son prop n'attend pas la
--- fin d'un intervalle lent quand la boucle tourne déjà pour une autre station.
local function loop()
    while playing and book:size() > 0 do
        Wait(step())
    end
    for id in pairs(shown) do remove(id) end
    nearestId, nearestDistance = nil, nil
    if onNearest then onNearest(nil) end
    running = false
end

--- Démarre la boucle si un personnage est en jeu, qu'une station est connue et qu'elle ne tourne pas déjà.
local function wake()
    if playing and not running and book:size() > 0 then
        running = true
        CreateThread(loop)
    end
end

--- Personnage en jeu ou non : la boucle démarre (si une station est connue) ou s'éteint.
---@param flag boolean
function props.setPlaying(flag)
    playing = flag
    wake()
end

--- Station la plus proche à distance d'interaction (et sa distance), ou nil.
---@return string|nil stationId
---@return number|nil distance
function props.nearest()
    return nearestId, nearestDistance
end

--- Appelé à chaque passage de la boucle avec la station la plus proche (ou nil).
---@param fn fun(stationId: string|nil)
function props.onNearest(fn)
    onNearest = fn
end

--- Appelé quand le combustible ou l'occupation d'une station connue change (menu ouvert sur elle).
---@param fn fun(stationId: string, status: { fuel: number, busy: boolean })
function props.onStatus(fn)
    onStatus = fn
end

--- Appelé quand une station est oubliée (le joueur s'en éloigne, elle est retirée) : le menu ouvert sur elle se ferme.
---@param fn fun(stationId: string)
function props.onForget(fn)
    onForget = fn
end

--- Zones des stations, envoyées par le core (nom local = identifiant de la station, état { def, s }) : le carnet suit,
--- le prop d'une station qui a bougé ou disparu est retiré (la boucle le recrée à portée) ; un nom ou une réserve
--- changés ne touchent que l'invite ; l'invite et le menu ouvert suivent l'état.
---@param kind string  'enter' | 'change' | 'leave'
---@param id string
---@param a any  état entier (enter) ou valeurs changées (change)
---@param b any  clés retirées (change)
local function onZone(kind, id, a, b)
    local placed, statusChanged, relabeled
    if kind == 'enter' then
        placed, statusChanged, relabeled = book:enter(id, a)
    elseif kind == 'change' then
        placed, statusChanged, relabeled = book:change(id, a, b)
    elseif kind == 'leave' then
        placed, statusChanged, relabeled = book:leave(id)
    else
        return
    end
    if placed then
        remove(id)
        regroup = true
        if not book:station(id) then
            if id == nearestId then
                nearestId, nearestDistance = nil, nil
                if onNearest then onNearest(nil) end
            end
            if onForget then onForget(id) end
        end
        -- passage immédiat si la boucle tourne déjà (une autre station est connue), sinon elle démarre
        if running and playing then step() end
        wake()
    end
    -- l'invite montre les noms, la réserve, le combustible et l'occupation : elle les suit
    if (statusChanged or relabeled) and onNearest and id == nearestId then onNearest(nearestId) end
    if statusChanged and onStatus then onStatus(id, book:status(id)) end
end

--- Suit les zones des stations et le personnage. Appelé par client/main.lua.
function props.start()
    if core.zones then
        local watched, watchErr = core.zones.watch(onZone)
        if not watched then core.log.error('stations non suivies : %s', tostring(watchErr)) end
    else
        core.log.error('stations indisponibles : vAvA_core 0.11.0 au moins est requis')
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
