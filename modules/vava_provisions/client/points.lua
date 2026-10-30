--[[
    vava_provisions/client/points.lua
    Rôle : les points d'eau vus du joueur : seulement ceux que le serveur lui envoie, par les abonnements de zone du core
           (une zone par point, vAvA_core 0.11.0), tenus dans un carnet (shared/pointzone.lua) ; props LOCAUX (jamais
           réseau) créés pour les points à portée (`streaming.radius`), retirés au-delà ; point le plus proche à
           distance d'usage. Une seule boucle lente, active seulement quand un personnage est en jeu ET qu'un point est
           connu (aucune boucle loin de tout point d'eau) : elle mesure d'abord les groupes de points (cases de
           `streaming.groupCell`), ne parcourt que les points d'un groupe à portée, passe toutes les `streaming.pollMs`
           près d'un groupe et toutes les `streaming.idlePollMs` loin de tous ; un point reçu, changé ou oublié fait
           aussitôt un passage ; elle s'arrête d'elle-même à la sélection, au déchargement et quand le dernier point
           connu est oublié, et retire alors tous les props. Calqué sur vava_crafting/client/props.lua.
    Dépendances : shared/constants.lua, config.lua, shared/proximity.lua, shared/pointzone.lua, client/core.lua
                  (core.zones : vAvA_core 0.11.0)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local sqrt, max, huge = math.sqrt, math.max, math.huge
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject = PlayerPedId, GetEntityCoords, DoesEntityExist, DeleteObject
local RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey = RequestModel, HasModelLoaded, IsModelValid, SetModelAsNoLongerNeeded, GetHashKey
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly = CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, PlaceObjectOnGroundProperly

local core = VavaProvisions.core
if not core then return end

local cfg = VavaProvisions.config
local streaming = cfg.streaming
local proximity = VavaProvisions.proximity
local pointzone = VavaProvisions.pointzone
local RESOURCE = VavaProvisions.resource
local LOAD_POLL_MS = 50

local points = {}
VavaProvisions.points = points

-- points connus : ceux des zones suivies (le serveur décide lesquels, d'après la position du joueur)
local book = pointzone.book()
-- points groupés par case de grille, refaits au passage qui suit un changement
local groups, regroup = {}, false
-- props affichés : id du point → { entity, model }
local shown = {}
-- un point est mesuré si son groupe peut en avoir un à portée des props ou de l'invite
local REACH = max(streaming.radius, cfg.interact.distance)

local running, playing = false, false
local nearestId = nil
---@type fun(pointId: string|nil)|nil
local onNearest = nil

---@param point table
---@return string
local function cellOf(point)
    return proximity.cell(point.x, point.y, streaming.groupCell)
end

---@return number
local function distance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz)
end

---@param id any
---@return table|nil
function points.point(id)
    return book:point(id)
end

---@param id string
local function remove(id)
    local entry = shown[id]
    if not entry then return end
    shown[id] = nil
    if entry.entity and DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end
end

--- Crée le prop d'un point (modèle chargé avec une attente bornée), dans son propre thread. Modèle introuvable : ligne
--- d'avertissement, point sans prop mais utilisable.
---@param point table
local function spawn(point)
    local entry = { entity = nil, model = point.model }
    shown[point.id] = entry
    CreateThread(function()
        local hash = GetHashKey(point.model)
        if not IsModelValid(hash) then
            core.log.warn("point d'eau %s : modèle inconnu '%s'", point.id, point.model)
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + streaming.modelTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        -- le point a pu sortir de portée (ou changer) pendant le chargement
        if shown[point.id] ~= entry or not HasModelLoaded(hash) then
            if shown[point.id] == entry then shown[point.id] = nil end
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, point.x, point.y, point.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if entity == 0 then
            shown[point.id] = nil
            return
        end
        SetEntityHeading(entity, point.heading or 0.0)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        entry.entity = entity
    end)
end

--- Met le prop d'un point en accord avec sa distance ('' : aucun prop, point posé sur un décor de la carte).
---@param point table
---@param far number
local function reconcile(point, far)
    if far > streaming.radius then
        if shown[point.id] then remove(point.id) end
        return
    end
    if shown[point.id] or point.model == '' then return end
    spawn(point)
end

--- Groupes refaits depuis le carnet ; un groupe naît « actif » pour que le premier passage retire ce qui serait hors
--- de portée.
local function rebuildGroups()
    regroup = false
    groups = proximity.group(book:list(), cellOf)
    for _, group in ipairs(groups) do group.active = true end
end

--- Un passage : une distance par groupe, puis une par point des seuls groupes à portée ; un groupe qui sort de portée
--- retire ses props une fois. Ne cède jamais la main. Rend l'intervalle du prochain passage.
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
            for _, point in ipairs(group.targets) do
                local far = distance(px, py, pz, point.x, point.y, point.z)
                reconcile(point, far)
                if far <= bestDistance then bestId, bestDistance = point.id, far end
            end
        elseif group.active then
            group.active = false
            for _, point in ipairs(group.targets) do remove(point.id) end
        end
    end
    nearestId = bestId
    if onNearest then onNearest(bestId) end
    return proximity.interval(closest, streaming.radius, streaming.idleMargin, streaming.pollMs, streaming.idlePollMs)
end

--- Boucle lente justifiée, seulement quand un personnage est en jeu et qu'un point est connu (voir step).
local function loop()
    while playing and book:size() > 0 do
        Wait(step())
    end
    for id in pairs(shown) do remove(id) end
    nearestId = nil
    if onNearest then onNearest(nil) end
    running = false
end

--- Démarre la boucle si un personnage est en jeu, qu'un point est connu et qu'elle ne tourne pas déjà.
local function wake()
    if playing and not running and book:size() > 0 then
        running = true
        CreateThread(loop)
    end
end

--- Personnage en jeu ou non : la boucle démarre (si un point est connu) ou s'éteint.
---@param flag boolean
function points.setPlaying(flag)
    playing = flag
    wake()
end

--- Point d'eau le plus proche à distance d'usage, ou nil.
---@return string|nil
function points.nearest()
    return nearestId
end

--- Appelé à chaque passage de la boucle avec le point le plus proche (ou nil).
---@param fn fun(pointId: string|nil)
function points.onNearest(fn)
    onNearest = fn
end

--- Zones des points, envoyées par le core (nom local = identifiant du point, état { def }) : le carnet suit, le prop
--- d'un point qui a changé ou disparu est retiré (la boucle le recrée à portée).
---@param kind string  'enter' | 'change' | 'leave'
---@param id string
---@param a any  état entier (enter) ou valeurs changées (change)
---@param b any  clés retirées (change)
local function onZone(kind, id, a, b)
    local changed
    if kind == 'enter' then
        changed = book:enter(id, a)
    elseif kind == 'change' then
        changed = book:change(id, a, b)
    elseif kind == 'leave' then
        changed = book:leave(id)
    else
        return
    end
    if not changed then return end
    remove(id)
    regroup = true
    if not book:point(id) and id == nearestId then
        nearestId = nil
        if onNearest then onNearest(nil) end
    end
    -- passage immédiat si la boucle tourne déjà (un autre point est connu), sinon elle démarre
    if running and playing then step() end
    wake()
end

--- Suit les zones des points et le personnage. Appelé par client/main.lua.
function points.start()
    if core.zones then
        local watched, watchErr = core.zones.watch(onZone)
        if not watched then core.log.error("points d'eau non suivis : %s", tostring(watchErr)) end
    else
        core.log.error("points d'eau indisponibles : vAvA_core 0.11.0 au moins est requis")
    end

    core.hooks.after('core:character:spawning', function() points.setPlaying(true) end)
    core.hooks.after('core:character:selection', function() points.setPlaying(false) end)
    core.hooks.after('core:character:unloaded', function() points.setPlaying(false) end)
    if core.characters.current() and not core.characters.awaitingSelection() then points.setPlaying(true) end
end

-- arrêt du module : aucun prop ne doit rester dans le monde
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    playing = false
    for id in pairs(shown) do remove(id) end
end)
