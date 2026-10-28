--[[
    vava_gathering/server/api.lua
    Rôle : exports serveur pour les autres modules : zones (état, vitalité), nœuds, ressources, outils, récolte en cours
           d'un joueur. Aucune fonction ne lève d'erreur : `valeur` ou `nil/false, code`.
    Dépendances : server/core.lua, server/catalog.lua, server/zones.lua, server/nodes.lua, server/harvest.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type
local GetInvokingResource = GetInvokingResource

local catalog = VavaGathering.catalog
local zones = VavaGathering.zones
local nodes = VavaGathering.nodes
local harvest = VavaGathering.harvest

--- État d'une zone : { id, label, kind, vitality, band, scarred, x, y, z, radius }, ou nil.
exports('getZone', function(id)
    if not VavaGathering.ready then return nil, 'not_ready' end
    local def = catalog.zone(id)
    if not def then return nil, 'unknown_zone' end
    return zones.view(def)
end)

--- Toutes les zones, dans l'ordre de la config.
exports('getZones', function()
    if not VavaGathering.ready then return nil, 'not_ready' end
    local list = {}
    for i, def in ipairs(catalog.zones()) do list[i] = zones.view(def) end
    return list
end)

--- Fixe la vitalité d'une zone (0 à 100) au nom du module appelant ; une valeur positive lève la cicatrice.
exports('setVitality', function(id, value)
    if not VavaGathering.ready then return false, 'not_ready' end
    local def = catalog.zone(id)
    if not def then return false, 'unknown_zone' end
    if type(value) ~= 'number' or value ~= value or value < 0 or value > 100 then return false, 'invalid_value' end
    zones.setVitality(def, value, { module = GetInvokingResource() })
    return true
end)

--- État d'un nœud : { id, zone, resource, charges, max }, ou nil.
exports('nodeState', function(id)
    if not VavaGathering.ready then return nil, 'not_ready' end
    local def = catalog.node(id)
    if not def then return nil, 'unknown_node' end
    return nodes.view(def)
end)

--- Définition d'une ressource ({ id, label, item, skill, tool, difficulty, xp, yield, fishing }), ou nil.
exports('getResource', function(id)
    if not VavaGathering.ready then return nil, 'not_ready' end
    local def = catalog.resource(id)
    if not def then return nil, 'unknown_resource' end
    return { id = def.id, label = def.label, item = def.item, skill = def.skill, tool = def.tool, difficulty = def.difficulty, xp = def.xp, yield = { def.yield[1], def.yield[2] }, fishing = def.fishing }
end)

--- Définition d'un outil ({ item, kind, power, yieldBonus, qualityBonus, wear }), ou nil.
exports('getTool', function(item)
    if not VavaGathering.ready then return nil, 'not_ready' end
    return catalog.tool(item)
end)

--- Récolte en cours d'un joueur : { token, node, resource, kind, startedAt, durationMs }, ou nil.
exports('getSession', function(source)
    if not VavaGathering.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' then return nil, 'invalid_target' end
    local session = harvest.session(source)
    if not session then return nil end
    return { token = session.token, node = session.node.id, resource = session.resource.id, kind = session.kind, startedAt = session.startedAt, durationMs = session.durationMs }
end)
