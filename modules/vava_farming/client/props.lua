--[[
    vava_farming/client/props.lua
    Rôle : les parcelles, puits et greniers dans le monde, vus du joueur : parcelles proches reçues par les abonnements
           de zone du core (core.zones.watch, 1.7.0 : définition et état des emplacements — culture, stade, état — à
           l'arrivée, puis les seuls emplacements changés ; oubliées en s'éloignant ; une parcelle créée ou déplacée en
           jeu arrive de même), puits de la config ; props LOCAUX (jamais réseau) créés pour les plantes, puits et
           greniers à portée — une plante change de prop avec son stade ou son état, un emplacement vide n'en a pas —,
           cible la plus proche à distance d'interaction (emplacement, puits ou grenier). Une seule boucle lente,
           active seulement quand un personnage est en jeu : elle mesure d'abord les groupes (une parcelle avec son
           grenier, les puits par case de streaming.groupCell), ne parcourt que les cibles d'un groupe à portée, passe
           toutes les streaming.pollMs près d'un groupe et toutes les streaming.idlePollMs loin de tous ; une parcelle
           reçue, changée ou quittée fait aussitôt un passage (props et invite à jour sans attendre) ; elle s'arrête
           d'elle-même à la sélection et au déchargement, et retire alors tous les props.
    Dépendances : shared/constants.lua, config_client.lua, shared/geometry.lua, shared/parcelzone.lua, shared/proximity.lua,
                  client/core.lua (core.zones, vAvA_core 0.11.0)
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local max, huge = math.max, math.huge
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local geometry = VavaFarming.geometry
local parcelzone = VavaFarming.parcelzone
local proximity = VavaFarming.proximity
local streaming = cfg.streaming
local STATES = VavaFarming.STATES
local RESOURCE = VavaFarming.resource
local DEF = parcelzone.DEF
local LOAD_POLL_MS = 50

local props = {}
VavaFarming.props = props

-- puits : fixes (config), groupés par case de grille, cibles calculées une fois (clé du prop, position, cap, modèle)
local wellsById = {}
for _, well in ipairs(cfg.wells) do wellsById[well.id] = well end
local wellTargets = {}
for _, well in ipairs(cfg.wells) do
    wellTargets[#wellTargets + 1] = { kind = 'well', key = 'well:' .. well.id, well = well.id, model = well.prop,
        x = well.x, y = well.y, z = well.z, heading = well.heading,
        group = 'wells:' .. proximity.cell(well.x, well.y, streaming.groupCell) }
end
-- un groupe naît « actif » pour que le premier passage retire ce qui serait hors de portée
local wellGroups = proximity.group(wellTargets, function(target) return target.group end)
for _, group in ipairs(wellGroups) do group.active = true end

-- parcelles proches, reçues du serveur : id → { def (parcelzone.readDefinition), signature, group } ; une parcelle et
-- son grenier forment un groupe, cibles calculées à l'arrivée de la parcelle (ou quand sa définition change)
local parcels = {}
-- groupes mesurés par la boucle : puits, puis parcelles connues (refait quand une parcelle arrive, change ou part)
local groups = wellGroups
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

--- Définition d'une parcelle proche (label, centre, grille, grenier), ou nil si le joueur n'en est pas assez près.
---@param id string
---@return table|nil
function props.parcel(id)
    local entry = parcels[id]
    return entry and entry.def or nil
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

--- Un passage : une distance par groupe (parcelle et grenier, puits d'une case), puis une par cible des seuls groupes
--- à portée ; un groupe qui sort de portée retire ses props une fois. Ne cède jamais la main. Rend l'intervalle du
--- prochain passage : streaming.pollMs près d'un groupe, streaming.idlePollMs quand aucune cible ne peut être à moins
--- de radius + idleMargin.
---@return integer
local function step()
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
    return proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs)
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu (voir step). Une parcelle reçue, changée ou
--- quittée fait aussitôt un passage hors de la boucle (onZone) : ses props n'attendent pas la fin d'un intervalle lent.
local function loop()
    while playing do
        Wait(step())
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

-- Parcelles proches (abonnements de zone du core) ----------------------------------------------------------------------

--- Groupes mesurés par la boucle : puits, puis parcelles connues. Refait seulement quand une parcelle arrive, change de
--- définition ou part (la boucle ne cède jamais la main au milieu d'un parcours : elle lit toujours une liste entière).
local function rebuildGroups()
    local list = {}
    for _, group in ipairs(wellGroups) do list[#list + 1] = group end
    for _, entry in pairs(parcels) do
        if entry.group then list[#list + 1] = entry.group end
    end
    groups = list
end

--- Groupe d'une parcelle : ses emplacements et son grenier (clé du prop, position, cap ; `model` fixe pour le grenier,
--- lu dans l'état reçu pour un emplacement).
---@param id string
---@param def table
---@return table|nil
local function parcelGroup(id, def)
    local key = 'parcel:' .. id
    local targets = {}
    for index = 1, geometry.slotCount(def) do
        local x, y, z = geometry.slotPosition(def, index)
        targets[#targets + 1] = { kind = 'slot', key = 'slot:' .. id .. ':' .. index, group = key,
            parcel = id, index = index, x = x, y = y, z = z, heading = def.heading }
    end
    local g = def.granary
    if g then
        targets[#targets + 1] = { kind = 'granary', key = 'granary:' .. id, group = key, parcel = id,
            model = g.prop, x = g.x, y = g.y, z = g.z, heading = g.heading }
    end
    local group = proximity.group(targets, function(target) return target.group end)[1]
    -- né « actif » : le premier passage retire ce qui serait hors de portée
    if group then group.active = true end
    return group
end

---@param group table|nil
local function removeGroup(group)
    if not group then return end
    for _, target in ipairs(group.targets) do remove(target.key) end
end

--- Place (ou replace) une parcelle reçue : ses props sont refaits si sa définition a changé (déplacée, agrandie…).
---@param id string
---@param def table
local function place(id, def)
    local signature = parcelzone.definitionKey(def)
    local entry = parcels[id]
    if entry and entry.signature == signature then
        entry.def = def
        return
    end
    if entry then removeGroup(entry.group) end
    parcels[id] = { def = def, signature = signature, group = parcelGroup(id, def) }
    local list = states[id]
    if list then
        local count = geometry.slotCount(def)
        for index in pairs(list) do
            if index > count then list[index] = nil end
        end
    end
    rebuildGroups()
end

--- Oublie une parcelle (éloigné, retirée, déchargement) : ses props partent, son état aussi.
---@param id string
local function forget(id)
    local entry = parcels[id]
    states[id] = nil
    if not entry then return end
    removeGroup(entry.group)
    parcels[id] = nil
    rebuildGroups()
    if nearest and nearest.parcel == id then
        nearest = nil
        if onNearest then onNearest(nil) end
    end
end

--- Passage immédiat après une notification : props et invite (culture, état, nom de la parcelle ou du grenier) suivent
--- aussitôt ce qui est reçu. Une parcelle arrive dans la marge d'abonnement (`subscribeSlack`) : sans ce passage, ses
--- props attendraient jusqu'à `idlePollMs` et un cavalier au galop les verrait apparaître trop près.
local function refresh()
    if playing then step() end
end

--- Une parcelle arrive (état entier), change (emplacements, définition) ou part : nom local = id de la parcelle ; état
--- `def` et `s<n°>` (shared/parcelzone.lua). Une définition illisible fait oublier la parcelle. Chaque notification
--- fait aussitôt un passage.
---@param kind string  'enter' | 'change' | 'leave'
---@param id string
---@param a table|nil  état (enter) ou valeurs changées (change)
---@param b table|nil  clés retirées (change)
local function onZone(kind, id, a, b)
    if type(id) ~= 'string' then return end
    if kind == 'leave' then
        forget(id)
        refresh()
        return
    end
    if type(a) ~= 'table' then return end
    if kind == 'enter' then
        local def = parcelzone.readDefinition(a[DEF])
        if not def then
            core.log.warn("parcelle '%s' : définition reçue illisible, ignorée", id)
            forget(id)
            refresh()
            return
        end
        place(id, def)
        states[id] = parcelzone.readSlots(a, geometry.slotCount(def))
    elseif kind == 'change' then
        if not parcels[id] then return end
        if a[DEF] ~= nil then
            local def = parcelzone.readDefinition(a[DEF])
            if not def then
                core.log.warn("parcelle '%s' : définition reçue illisible, ignorée", id)
                forget(id)
                refresh()
                return
            end
            place(id, def)
        end
        local count = geometry.slotCount(parcels[id].def)
        local list = states[id] or {}
        states[id] = list
        for key, raw in pairs(a) do
            local index = parcelzone.slotIndex(key)
            if index and index <= count then list[index] = parcelzone.readSlot(raw) end
        end
        if type(b) == 'table' then
            for _, key in ipairs(b) do
                local index = parcelzone.slotIndex(key)
                if index then list[index] = nil end
            end
        end
    else
        return
    end
    refresh()
end

--- Suit les parcelles proches (abonnements de zone du core) et la vie du personnage. Appelé par client/main.lua.
function props.start()
    if core.zones then
        local watched, watchErr = core.zones.watch(onZone)
        if not watched then core.log.error('parcelles non suivies : %s', tostring(watchErr)) end
    else
        core.log.error('parcelles indisponibles : vAvA_core 0.11.0 au moins est requis')
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
    for key in pairs(shown) do remove(key) end
end)
