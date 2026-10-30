--[[
    vava_farming/server/zones.lua
    Rôle : chaque parcelle est une zone du core (abonnements de zone, vAvA_core 0.11.0) : connue des seuls joueurs
           proches (rayon de la parcelle + portée des props + battement, positions lues par le serveur), qui reçoivent
           son état entier en arrivant (définition et emplacements) puis les seuls emplacements changés. Les
           changements d'une parcelle faits dans un même passage (croissance, gel, Conseil) partent en un seul envoi.
           Une parcelle créée ou changée en jeu se partage de nouveau (déclarée, déplacée, état remplacé) et arrive chez
           les joueurs proches sans reconnexion. L'état d'une zone est public : il ne dit que ce qu'un passant voit
           (culture, stade, état) ; chaque geste revérifie la distance côté serveur sans se fier à l'abonnement.
    Dépendances : shared/constants.lua, config.lua, shared/parcelzone.lua, server/core.lua
]]

local ipairs, tostring = ipairs, tostring
local GlobalState, GetGameTimer = GlobalState, GetGameTimer

local parcelzone = VavaFarming.parcelzone
local cfg = VavaFarming.config
local LEGACY = VavaFarming.LEGACY_STATE_PARCEL
local MAX_CHANGES = VavaFarming.ZONE_MAX_CHANGES
local MIN_RADIUS = VavaFarming.ZONE_MIN_RADIUS
-- une erreur de partage d'une même parcelle n'est écrite en console qu'une fois par minute
local ERROR_INTERVAL_MS = 60000

local zones = {}
VavaFarming.zones = zones

-- parcelle → vrai si sa zone est déclarée au core
local declared = {}
-- parcelle → signatures des emplacements de la dernière publication réussie (nil : rien de sûr, tout repart)
local published = {}
-- parcelle → instant de la dernière erreur écrite
local lastError = {}

---@param parcelId string
---@param what string
---@param err any
local function report(parcelId, what, err)
    local now = GetGameTimer()
    local last = lastError[parcelId]
    if last and now - last < ERROR_INTERVAL_MS then return end
    lastError[parcelId] = now
    VavaFarming.log.error("parcelle '%s' : %s (%s) ; nouvel essai au prochain passage", parcelId, what, tostring(err))
end

---@param parcel vAvA.ParcelDefinition
---@return table
local function areaOf(parcel)
    local streaming = cfg.streaming
    return parcelzone.area(parcel, streaming.radius + streaming.subscribeSlack, MIN_RADIUS)
end

--- Déclare la zone de la parcelle, ou, déjà déclarée, la déplace et remplace tout son état (définition changée en jeu,
--- reprise après une erreur) : les joueurs proches la reçoivent entière, eux seuls.
---@param parcel vAvA.ParcelDefinition
---@param values { crop: string, stage: integer, state: string }[]  une valeur par emplacement (parcelzone.slotValue)
---@return boolean ok
function zones.share(parcel, values)
    local api = VavaFarming.core.zones
    local id = parcel.id
    local state, signatures = parcelzone.state(parcel, values)
    local ok, err
    if declared[id] then
        ok, err = api.move(id, areaOf(parcel))
        if ok then ok, err = api.replace(id, state) end
    else
        ok, err = api.define(id, areaOf(parcel), state)
        -- déjà connue du core alors qu'on la croyait retirée (retrait en échec) : elle est reprise, état remplacé
        if not ok and err == 'exists' then
            declared[id] = true
            return zones.share(parcel, values)
        end
    end
    if not ok then
        if err == 'unknown_zone' then declared[id] = nil end
        published[id] = nil
        report(id, 'zone non partagée avec les joueurs proches', err)
        return false
    end
    declared[id], published[id] = true, signatures
    return true
end

--- Envoie aux joueurs proches les seuls emplacements changés depuis la dernière publication (en un seul envoi par
--- parcelle et par passage, regroupé par le core) ; une parcelle pas encore déclarée l'est, entière.
---@param parcel vAvA.ParcelDefinition
---@param values { crop: string, stage: integer, state: string }[]
---@return boolean ok
function zones.publish(parcel, values)
    local id = parcel.id
    if not declared[id] then return zones.share(parcel, values) end
    local batches, signatures = parcelzone.diff(published[id], values, MAX_CHANGES)
    local set = VavaFarming.core.zones.set
    for _, changes in ipairs(batches) do
        local ok, err = set(id, changes)
        if not ok then
            -- rien de sûr chez les joueurs : tout repartira au prochain passage (déclaration entière si la zone est
            -- inconnue du core)
            if err == 'unknown_zone' then declared[id] = nil end
            published[id] = nil
            report(id, 'emplacements non envoyés aux joueurs proches', err)
            return false
        end
    end
    published[id] = signatures
    return true
end

--- Retire la zone d'une parcelle supprimée : ses abonnés l'oublient (props retirés).
---@param parcelId string
---@return boolean ok
function zones.drop(parcelId)
    if not declared[parcelId] then return true end
    local ok, err = VavaFarming.core.zones.remove(parcelId)
    if not ok and err ~= 'unknown_zone' then
        report(parcelId, 'zone non retirée', err)
        return false
    end
    declared[parcelId], published[parcelId], lastError[parcelId] = nil, nil, nil
    return true
end

--- Efface l'ancien state bag global de chaque parcelle s'il traîne encore (serveur non redémarré depuis la 1.6.0) :
--- un seul envoi par clé présente, puis plus jamais rien dans GlobalState. Appelé pendant le setup.
---@param parcels vAvA.ParcelDefinition[]
function zones.clearLegacy(parcels)
    for _, parcel in ipairs(parcels) do
        local key = LEGACY .. parcel.id
        if GlobalState[key] ~= nil then GlobalState[key] = nil end
    end
end
