--[[
    vava_crafting/server/api.lua
    Rôle : exports serveur pour les autres modules : stations (état, combustible, accès par genre de propriétaire),
           recettes, pièce en cours d'un joueur, poinçon. Aucune fonction ne lève d'erreur : `valeur` ou `nil/false, code`.
    Dépendances : server/core.lua, server/catalog.lua, server/stations.lua, server/signature.lua, server/crafting.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type
local GetInvokingResource = GetInvokingResource

local catalog = VavaCrafting.catalog
local stations = VavaCrafting.stations
local signature = VavaCrafting.signature
local crafting = VavaCrafting.crafting
local journal = VavaCrafting.journal

--- État d'une station : { id, label, type, typeLabel, quality, busy, x, y, z, fuel?, owner? }, ou nil.
exports('getStation', function(id)
    if not VavaCrafting.ready then return nil, 'not_ready' end
    local def = catalog.station(id)
    if not def then return nil, 'unknown_station' end
    return stations.view(def)
end)

--- Toutes les stations, dans l'ordre de la config.
exports('getStations', function()
    if not VavaCrafting.ready then return nil, 'not_ready' end
    local list = {}
    for i, def in ipairs(catalog.stations()) do list[i] = stations.view(def) end
    return list
end)

--- Place une station depuis un autre module (son type déjà déclaré au registre `vava_crafting:stations`) ; les clients
--- la voient par le state bag et la liste publiée (`getStations`). Depuis 1.1.0.
exports('addStation', function(spec)
    if not VavaCrafting.ready then return false, 'not_ready' end
    local def, err = catalog.addStation(spec)
    if not def then return false, err end
    stations.adopt(def)
    VavaCrafting.core.hooks.runAfter('vava_crafting:stationAdded', { station = def.id, type = def.type.id, module = GetInvokingResource() })
    return true
end)

--- Fixe le combustible d'une station au nom du module appelant.
exports('setFuel', function(id, amount)
    if not VavaCrafting.ready then return false, 'not_ready' end
    local def = catalog.station(id)
    if not def then return false, 'unknown_station' end
    if not def.type.fuel then return false, 'no_fuel_station' end
    if mathType(amount) ~= 'integer' or amount < 0 then return false, 'invalid_value' end
    stations.setFuel(def, amount)
    journal.write('admin_fuel', { station = def.id, details = { fuel = stations.fuel(def), module = GetInvokingResource() } })
    return true
end)

--- Branche un genre de propriétaire de station (foyer, guilde…) : `fn(ownerId, characterId)` → booléen.
exports('registerAccess', function(kind, fn)
    if not VavaCrafting.ready then return false, 'not_ready' end
    if type(kind) ~= 'string' or kind == '' then return false, 'invalid_kind' end
    if type(fn) ~= 'function' and not (type(fn) == 'table' and getmetatable(fn) and getmetatable(fn).__call) then return false, 'invalid_function' end
    stations.registerAccess(kind, function(ownerId, characterId) return fn(ownerId, characterId) == true end)
    return true
end)

--- Définition d'une recette ({ id, label, skill, level, station, tool, durationMs, difficulty, xp, signed,
--- transmission, ingredients, output }), ou nil.
exports('getRecipe', function(id)
    if not VavaCrafting.ready then return nil, 'not_ready' end
    local def = catalog.recipe(id)
    if not def then return nil, 'unknown_recipe' end
    return def
end)

--- Recettes d'un type de station, par niveau croissant.
exports('recipesOf', function(stationType)
    if not VavaCrafting.ready then return nil, 'not_ready' end
    if not catalog.stationType(stationType) then return nil, 'unknown_station_type' end
    return catalog.recipesOf(stationType)
end)

--- Pièce ou réparation en cours d'un joueur : { token, kind, station, recipe, startedAt, durationMs }, ou nil.
exports('getSession', function(source)
    if not VavaCrafting.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' then return nil, 'invalid_target' end
    local session = crafting.session(source)
    if not session then return nil end
    return { token = session.token, kind = session.kind, station = session.station.id, recipe = session.recipe.id, startedAt = session.startedAt, durationMs = session.durationMs }
end)

--- Poinçon d'un personnage, ou nil.
exports('getMark', function(characterId)
    if not VavaCrafting.ready then return nil, 'not_ready' end
    if mathType(characterId) ~= 'integer' then return nil, 'invalid_target' end
    return signature.markOf(characterId)
end)
