--[[
    vava_farming/client/props.lua
    Rôle : les parcelles, puits et greniers dans le monde, vus du joueur : état des emplacements publié par le serveur
           (culture, stade, état) lu dans les state bags globaux, props LOCAUX (jamais réseau) créés pour les plantes,
           puits et greniers à portée — une plante change de prop avec son stade ou son état, un emplacement vide n'en a
           pas —, cible la plus proche à distance d'interaction (emplacement, puits ou grenier). Une seule boucle lente
           (streaming.pollMs), active seulement quand un personnage est en jeu : elle s'arrête d'elle-même à la sélection
           et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config.lua, shared/geometry.lua, client/core.lua
]]

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local sub, floor, max = string.sub, math.floor, math.max
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly
local AddStateBagChangeHandler = AddStateBagChangeHandler

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local geometry = VavaFarming.geometry
local streaming = cfg.streaming
local STATE_PARCEL = VavaFarming.STATE_PARCEL
local STATES = VavaFarming.STATES
local RESOURCE = VavaFarming.resource
local LOAD_POLL_MS = 50

local props = {}
VavaFarming.props = props

-- index de la config
local parcelsById, wellsById = {}, {}
for _, parcel in ipairs(cfg.parcels) do parcelsById[parcel.id] = parcel end
for _, well in ipairs(cfg.wells) do wellsById[well.id] = well end

---@class vAvA.SlotView
---@field crop string|nil
---@field stage integer
---@field state string|nil

-- état connu du serveur : parcelle → { [index] = vAvA.SlotView }
local states = {}
-- props affichés : clé → { entity, model, loading } ; clés : slot:<parcelle>:<index>, well:<id>, granary:<parcelle>
local shown = {}
local running, playing = false, false
---@type table|nil  { kind = 'slot'|'well'|'granary', parcel?, index?, well?, distance }
local nearest = nil
---@type fun(target: table|nil)|nil
local onNearest = nil

local EMPTY_SLOT = { crop = nil, stage = 0, state = nil }

---@param id string
---@return table|nil
function props.parcel(id)
    return parcelsById[id]
end

---@param id string
---@return table|nil
function props.well(id)
    return wellsById[id]
end

---@param cropId string|nil
---@return table|nil
function props.crop(cropId)
    return cropId and cfg.crops[cropId] or nil
end

--- État d'un emplacement (vide tant que le serveur n'a rien publié).
---@param parcelId string
---@param index integer
---@return vAvA.SlotView
function props.slot(parcelId, index)
    local parcel = states[parcelId]
    return parcel and parcel[index] or EMPTY_SLOT
end

--- Modèle de la plante d'un emplacement selon son stade et son état, ou nil s'il est vide.
---@param slot vAvA.SlotView
---@return string|nil
local function modelFor(slot)
    local crop = props.crop(slot.crop)
    if not crop then return nil end
    if slot.state == STATES.DEAD then return crop.dead end
    if slot.state == STATES.WILTED then return crop.wilted end
    local count = #crop.stages
    if count == 0 then return nil end
    local stage = slot.stage or 1
    if stage < 1 then stage = 1 elseif stage > count then stage = count end
    return crop.stages[stage]
end

---@param key string
local function remove(key)
    local entry = shown[key]
    if not entry then return end
    shown[key] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

--- Crée un prop (modèle chargé avec une attente bornée), dans son propre thread.
---@param key string
---@param model string
---@param x number
---@param y number
---@param z number
---@param heading number
local function spawn(key, model, x, y, z, heading)
    local entry = { entity = nil, model = model, loading = true }
    shown[key] = entry
    CreateThread(function()
        local hash = GetHashKey(model)
        if not IsModelValid(hash) then
            core.log.warn("%s : modèle inconnu '%s'", key, model)
            entry.loading = false
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + streaming.modelTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        -- la cible a pu sortir de portée ou changer de modèle pendant le chargement
        if shown[key] ~= entry or not HasModelLoaded(hash) then
            if shown[key] == entry then shown[key] = nil end
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, x, y, z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if entity == 0 then
            shown[key] = nil
            return
        end
        SetEntityHeading(entity, heading or 0.0)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        entry.entity, entry.loading = entity, false
    end)
end

--- Met un prop en accord avec sa distance et le modèle voulu (nil : aucun prop).
---@param key string
---@param model string|nil
---@param far number
local function reconcile(key, model, far, x, y, z, heading)
    local entry = shown[key]
    if far > streaming.radius or not model then
        if entry then remove(key) end
        return
    end
    if entry then
        if entry.model == model then return end
        remove(key)
    end
    spawn(key, model, x, y, z, heading)
end

--- Boucle lente justifiée : une distance par cible toutes les pollMs, seulement quand un personnage est en jeu. Les
--- emplacements d'une parcelle ne sont parcourus que si la parcelle elle-même est à portée.
local function loop()
    while playing do
        local coords = GetEntityCoords(PlayerPedId())
        local px, py, pz = coords.x, coords.y, coords.z
        local best, bestDistance = nil, cfg.interact.distance
        for _, parcel in ipairs(cfg.parcels) do
            local extent = max(parcel.rows, parcel.cols) * parcel.spacing
            local center = geometry.distance(px, py, pz, parcel.x, parcel.y, parcel.z)
            local inRange = center <= streaming.radius + extent
            for index = 1, geometry.slotCount(parcel) do
                local key = 'slot:' .. parcel.id .. ':' .. index
                local x, y, z = geometry.slotPosition(parcel, index)
                local far = inRange and geometry.distance(px, py, pz, x, y, z) or (streaming.radius + 1)
                reconcile(key, inRange and modelFor(props.slot(parcel.id, index)) or nil, far, x, y, z, parcel.heading)
                if far <= bestDistance then
                    best, bestDistance = { kind = 'slot', parcel = parcel.id, index = index, distance = far }, far
                end
            end
            if parcel.granary then
                local g = parcel.granary
                local far = geometry.distance(px, py, pz, g.x, g.y, g.z)
                reconcile('granary:' .. parcel.id, g.prop, far, g.x, g.y, g.z, g.heading or parcel.heading)
                if far <= bestDistance then best, bestDistance = { kind = 'granary', parcel = parcel.id, distance = far }, far end
            end
        end
        for _, well in ipairs(cfg.wells) do
            local far = geometry.distance(px, py, pz, well.x, well.y, well.z)
            reconcile('well:' .. well.id, well.prop, far, well.x, well.y, well.z, well.heading)
            if far <= bestDistance then best, bestDistance = { kind = 'well', well = well.id, distance = far }, far end
        end
        nearest = best
        if onNearest then onNearest(best) end
        Wait(streaming.pollMs)
    end
    for key in pairs(shown) do remove(key) end
    nearest = nil
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

--- Cible la plus proche à distance d'interaction, ou nil.
---@return table|nil
function props.nearest()
    return nearest
end

--- Appelé à chaque passage de la boucle avec la cible la plus proche (ou nil), et quand l'état publié change.
---@param fn fun(target: table|nil)
function props.onNearest(fn)
    onNearest = fn
end

---@param key string
---@param value any
local function applyState(key, value)
    if sub(key, 1, #STATE_PARCEL) ~= STATE_PARCEL then return end
    local parcelId = sub(key, #STATE_PARCEL + 1)
    if not parcelsById[parcelId] then return end
    if type(value) == 'table' and type(value.slots) == 'table' then
        local slots = {}
        for index, slot in pairs(value.slots) do
            local i = tonumber(index)
            if i and type(slot) == 'table' then
                local crop = type(slot.crop) == 'string' and slot.crop ~= '' and slot.crop or nil
                local state = type(slot.state) == 'string' and slot.state ~= '' and slot.state or nil
                slots[floor(i)] = { crop = crop, stage = type(slot.stage) == 'number' and floor(slot.stage) or 0, state = crop and state or nil }
            end
        end
        states[parcelId] = slots
    else
        states[parcelId] = nil
    end
    -- l'invite montre la culture et son état : elle suit l'état publié
    if onNearest and nearest and nearest.kind == 'slot' and nearest.parcel == parcelId then onNearest(nearest) end
end

--- Suit les state bags globaux et reprend l'état déjà publié. Appelé par client/main.lua.
function props.start()
    AddStateBagChangeHandler(nil, 'global', function(_, key, value)
        if type(key) == 'string' then applyState(key, value) end
    end)
    for _, parcel in ipairs(cfg.parcels) do applyState(STATE_PARCEL .. parcel.id, GlobalState[STATE_PARCEL .. parcel.id]) end

    core.hooks.after('core:character:spawning', function() props.setPlaying(true) end)
    core.hooks.after('core:character:selection', function() props.setPlaying(false) end)
    core.hooks.after('core:character:unloaded', function() props.setPlaying(false) end)
    if core.characters.current() and not core.characters.awaitingSelection() then props.setPlaying(true) end
end

-- arrêt du module : aucun prop ne doit rester dans le monde
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    playing = false
    for key in pairs(shown) do remove(key) end
end)
