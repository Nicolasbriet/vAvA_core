--[[
    vava_farming/server/api.lua
    Rôle : exports serveur pour les autres modules : parcelles et emplacements, cultures, grenier, accès par genre de
           propriétaire, geste en cours d'un joueur. Aucune fonction ne lève d'erreur.
    Dépendances : server/core.lua, server/catalog.lua, server/slots.lua, server/granary.lua, server/actions.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type

local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local granary = VavaFarming.granary
local actions = VavaFarming.actions

---@param parcel vAvA.ParcelDefinition
---@return table
local function parcelView(parcel)
    local list = {}
    for index = 1, parcel.count do list[index] = slots.view(parcel, index) end
    return {
        id = parcel.id, label = parcel.label, x = parcel.x, y = parcel.y, z = parcel.z, count = parcel.count,
        communal = parcel.owner == nil, owner = parcel.owner and { kind = parcel.owner.kind, id = parcel.owner.id } or nil,
        granary = granary.containerOf(parcel.id), slots = list,
    }
end

--- Parcelle et ses emplacements, ou nil.
exports('getParcel', function(id)
    if not VavaFarming.ready then return nil, 'not_ready' end
    local parcel = catalog.parcel(id)
    if not parcel then return nil, 'unknown_parcel' end
    return parcelView(parcel)
end)

--- Toutes les parcelles.
exports('getParcels', function()
    if not VavaFarming.ready then return nil, 'not_ready' end
    local list = {}
    for i, parcel in ipairs(catalog.parcels()) do list[i] = parcelView(parcel) end
    return list
end)

--- Un emplacement : { parcel, index, crop, cropLabel, state, stage, stages, progress, moisture, fertility, … }.
exports('getSlot', function(parcelId, index)
    if not VavaFarming.ready then return nil, 'not_ready' end
    local parcel = catalog.parcel(parcelId)
    if not parcel then return nil, 'unknown_parcel' end
    if mathType(index) ~= 'integer' or index < 1 or index > parcel.count then return nil, 'unknown_slot' end
    return slots.view(parcel, index)
end)

--- Définition d'une culture, ou nil.
exports('getCrop', function(id)
    if not VavaFarming.ready then return nil, 'not_ready' end
    return catalog.crop(id)
end)

--- Conteneur du grenier d'une parcelle, ou nil.
exports('granaryOf', function(parcelId)
    if not VavaFarming.ready then return nil, 'not_ready' end
    return granary.containerOf(parcelId)
end)

--- Branche un genre de propriétaire de parcelle (foyer, guilde…) : `fn(ownerId, characterId)` → booléen.
exports('registerAccess', function(kind, fn)
    if not VavaFarming.ready then return false, 'not_ready' end
    if type(kind) ~= 'string' or kind == '' then return false, 'invalid_kind' end
    if type(fn) ~= 'function' and not (type(fn) == 'table' and getmetatable(fn) and getmetatable(fn).__call) then return false, 'invalid_function' end
    slots.registerAccess(kind, function(ownerId, characterId) return fn(ownerId, characterId) == true end)
    return true
end)

--- Geste en cours d'un joueur : { token, parcel, slot, action, startedAt, durationMs }, ou nil.
exports('getSession', function(source)
    if not VavaFarming.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' then return nil, 'invalid_target' end
    local session = actions.session(source)
    if not session then return nil end
    return { token = session.token, parcel = session.parcel.id, slot = session.index, action = session.action, startedAt = session.startedAt, durationMs = session.durationMs }
end)
