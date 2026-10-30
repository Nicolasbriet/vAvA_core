--[[
    vava_crafting/client/props.lua
    Rôle : les stations d'artisanat dans le monde, vues du joueur : liste des stations publiée par le serveur (config
           et stations ajoutées par d'autres modules, la config ne servant qu'avant la première publication), état
           publié par le serveur (combustible, occupée) lu dans les state bags globaux, props LOCAUX (jamais réseau)
           créés pour les stations à portée, station la plus proche à distance d'interaction. Une seule boucle lente,
           active seulement quand un personnage est en jeu : elle mesure d'abord les groupes de stations (par case de
           streaming.groupCell), ne parcourt que les stations d'un groupe à portée, passe toutes les streaming.pollMs
           près d'un groupe et toutes les streaming.idlePollMs loin de tous ; elle s'arrête d'elle-même à la sélection
           et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config.lua, shared/proximity.lua, client/core.lua
]]

local type, pairs, ipairs = type, pairs, ipairs
local sub, sqrt, max, huge = string.sub, math.sqrt, math.max, math.huge
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly
local AddStateBagChangeHandler = AddStateBagChangeHandler

local core = VavaCrafting.core
if not core then return end

local cfg = VavaCrafting.config
local streaming = cfg.streaming
local proximity = VavaCrafting.proximity
local STATE_STATION, STATE_STATIONS = VavaCrafting.STATE_STATION, VavaCrafting.STATE_STATIONS
local RESOURCE = VavaCrafting.resource
local LOAD_POLL_MS = 50

local props = {}
VavaCrafting.props = props

-- stations connues : la config d'abord, puis la liste publiée par le serveur (qui comprend celles des autres modules)
local known, stationsById = {}, {}
-- stations groupées par case de grille, refaites à chaque liste adoptée
local groups = {}
-- props affichés : id de station → { entity, model, loading }
local shown = {}
-- une station est mesurée si son groupe peut en avoir une à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

---@param station table
---@return string
local function cellOf(station)
    return proximity.cell(station.x, station.y, streaming.groupCell)
end

---@param list table
local function adoptList(list)
    known, stationsById = {}, {}
    for _, station in ipairs(list) do
        if type(station) == 'table' and type(station.id) == 'string' then
            known[#known + 1] = station
            stationsById[station.id] = station
        end
    end
    -- un groupe naît « actif » pour que le premier passage retire ce qui serait hors de portée
    groups = proximity.group(known, cellOf)
    for _, group in ipairs(groups) do group.active = true end
    -- une station disparue n'a plus de prop
    for id in pairs(shown) do
        if not stationsById[id] then props.remove(id) end
    end
end

-- état connu du serveur : station → { fuel, busy }
local states = {}
local running, playing = false, false
local nearestId, nearestDistance = nil, nil
---@type fun(stationId: string|nil)|nil
local onNearest = nil

local DEFAULT_STATE = { fuel = 0, busy = false }

---@return number
local function distance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz)
end

---@param id string
---@return table|nil
function props.station(id)
    return stationsById[id]
end

--- Type d'une station (compétences, combustible, animation, prop).
---@param station table
---@return table|nil
function props.type(station)
    return cfg.stationTypes[station.type]
end

--- État d'une station (vide et libre tant que le serveur n'a rien publié).
---@param stationId string
---@return { fuel: integer, busy: boolean }
function props.state(stationId)
    return states[stationId] or DEFAULT_STATE
end

---@param station table
---@return string|nil
local function modelFor(station)
    local kind = props.type(station)
    return station.prop or (kind and kind.prop) or nil
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
        -- la station a pu sortir de portée pendant le chargement
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
    local model = modelFor(station)
    if model then spawn(station, model) end
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu : une distance par groupe de stations, puis une
--- par station des seuls groupes à portée ; un groupe qui sort de portée retire ses props une fois. Intervalle :
--- streaming.pollMs près d'un groupe, streaming.idlePollMs quand aucune station ne peut être à moins de
--- radius + idleMargin.
local function loop()
    while playing do
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
        Wait(proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs))
    end
    for id in pairs(shown) do remove(id) end
    nearestId, nearestDistance = nil, nil
    if onNearest then onNearest(nil) end
    running = false
end

--- Personnage en jeu ou non : la boucle démarre ou s'éteint.
---@param flag boolean
function props.setPlaying(flag)
    playing = flag
    if flag and not running then
        running = true
        CreateThread(loop)
    end
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

---@param key string
---@param value any
local function applyState(key, value)
    if key == STATE_STATIONS then
        if type(value) == 'table' then adoptList(value) end
        return
    end
    if sub(key, 1, #STATE_STATION) ~= STATE_STATION then return end
    local stationId = sub(key, #STATE_STATION + 1)
    if type(value) == 'table' then
        states[stationId] = { fuel = type(value.fuel) == 'number' and value.fuel or 0, busy = value.busy == true }
    else
        states[stationId] = nil
    end
    -- l'invite montre le combustible et l'occupation : elle suit l'état
    if onNearest and stationId == nearestId then onNearest(nearestId) end
end

--- Suit les state bags globaux et reprend l'état déjà publié. Appelé par client/main.lua.
function props.start()
    adoptList(cfg.stations)
    AddStateBagChangeHandler(nil, 'global', function(_, key, value)
        if type(key) == 'string' then applyState(key, value) end
    end)
    local published = GlobalState[STATE_STATIONS]
    if type(published) == 'table' then adoptList(published) end
    for _, station in ipairs(known) do applyState(STATE_STATION .. station.id, GlobalState[STATE_STATION .. station.id]) end

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
