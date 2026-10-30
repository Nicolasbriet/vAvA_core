--[[
    vava_farming/client/props.lua
    Rôle : les parcelles, puits et greniers dans le monde, vus du joueur : état des emplacements publié par le serveur
           (culture, stade, état) lu dans les state bags globaux, props LOCAUX (jamais réseau) créés pour les plantes,
           puits et greniers à portée — une plante change de prop avec son stade ou son état, un emplacement vide n'en a
           pas —, cible la plus proche à distance d'interaction (emplacement, puits ou grenier). Une seule boucle lente,
           active seulement quand un personnage est en jeu : elle mesure d'abord les groupes (une parcelle avec son
           grenier, les puits par case de streaming.groupCell), ne parcourt que les cibles d'un groupe à portée, passe
           toutes les streaming.pollMs près d'un groupe et toutes les streaming.idlePollMs loin de tous ; elle s'arrête
           d'elle-même à la sélection et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config.lua, shared/geometry.lua, shared/proximity.lua, client/core.lua
]]

local type, pairs, ipairs, tonumber = type, pairs, ipairs, tonumber
local sub, floor, max, huge = string.sub, math.floor, math.max, math.huge
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly
local AddStateBagChangeHandler = AddStateBagChangeHandler

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local geometry = VavaFarming.geometry
local proximity = VavaFarming.proximity
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
-- cibles calculées une fois (la config ne change pas en jeu) : clé du prop, position, cap ; `model` fixe pour un puits
-- ou un grenier, lu dans l'état publié pour un emplacement. Une parcelle et son grenier forment un groupe, les puits
-- sont groupés par case de grille.
local targets = {}
for _, parcel in ipairs(cfg.parcels) do
    local group = 'parcel:' .. parcel.id
    for index = 1, geometry.slotCount(parcel) do
        local x, y, z = geometry.slotPosition(parcel, index)
        targets[#targets + 1] = { kind = 'slot', key = 'slot:' .. parcel.id .. ':' .. index, group = group,
            parcel = parcel.id, index = index, x = x, y = y, z = z, heading = parcel.heading }
    end
    local g = parcel.granary
    if g then
        targets[#targets + 1] = { kind = 'granary', key = 'granary:' .. parcel.id, group = group, parcel = parcel.id,
            model = g.prop, x = g.x, y = g.y, z = g.z, heading = g.heading or parcel.heading }
    end
end
for _, well in ipairs(cfg.wells) do
    targets[#targets + 1] = { kind = 'well', key = 'well:' .. well.id, well = well.id, model = well.prop,
        x = well.x, y = well.y, z = well.z, heading = well.heading,
        group = 'wells:' .. proximity.cell(well.x, well.y, streaming.groupCell) }
end
-- un groupe naît « actif » pour que le premier passage retire ce qui serait hors de portée
local groups = proximity.group(targets, function(target) return target.group end)
for _, group in ipairs(groups) do group.active = true end
-- une cible est mesurée si son groupe peut en avoir une à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

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

--- Cible la plus proche, au format de props.nearest().
---@param target table
---@param far number
---@return table
local function nearestOf(target, far)
    if target.kind == 'slot' then return { kind = 'slot', parcel = target.parcel, index = target.index, distance = far } end
    if target.kind == 'granary' then return { kind = 'granary', parcel = target.parcel, distance = far } end
    return { kind = 'well', well = target.well, distance = far }
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu : une distance par groupe (parcelle et grenier,
--- puits d'une case), puis une par cible des seuls groupes à portée ; un groupe qui sort de portée retire ses props
--- une fois. Intervalle : streaming.pollMs près d'un groupe, streaming.idlePollMs quand aucune cible ne peut être à
--- moins de radius + idleMargin.
local function loop()
    while playing do
        local coords = GetEntityCoords(PlayerPedId())
        local px, py, pz = coords.x, coords.y, coords.z
        local best, bestTarget, bestDistance = nil, nil, cfg.interact.distance
        local closest = huge
        for _, group in ipairs(groups) do
            local reachable, gap = proximity.reachable(group, px, py, pz, REACH)
            if gap < closest then closest = gap end
            if reachable then
                group.active = true
                for _, target in ipairs(group.targets) do
                    local far = geometry.distance(px, py, pz, target.x, target.y, target.z)
                    local model = target.model
                    if target.kind == 'slot' then model = modelFor(props.slot(target.parcel, target.index)) end
                    reconcile(target.key, model, far, target.x, target.y, target.z, target.heading)
                    if far <= bestDistance then bestTarget, bestDistance = target, far end
                end
            elseif group.active then
                group.active = false
                for _, target in ipairs(group.targets) do remove(target.key) end
            end
        end
        if bestTarget then best = nearestOf(bestTarget, bestDistance) end
        nearest = best
        if onNearest then onNearest(best) end
        Wait(proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs))
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
