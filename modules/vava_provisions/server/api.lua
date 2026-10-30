--[[
    vava_provisions/server/api.lua
    Rôle : exports serveur des points d'eau : liste et détail (réserve comprise, pour un module ou un outil du Conseil),
           point le plus proche d'un joueur d'après la position de son ped lue par le serveur (pour un module qui veut
           savoir si un joueur est au bord de l'eau). Aucun export client.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/points.lua
]]

local ipairs = ipairs
local mathType, min = math.type, math.min

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local points = VavaProvisions.points
local cfg = VavaProvisions.config

local DEFAULT_RADIUS = cfg.interact.distance + cfg.interact.serverTolerance
local MAX_RADIUS = 10.0

--- Points d'eau dans l'ordre de la config : `{ id, kind, label, x, y, z, reserve? = { level, capacity } }`.
exports('getPoints', function()
    if not VavaProvisions.ready then return nil, 'not_ready' end
    local now = bridge.Now()
    local list = {}
    for _, point in ipairs(points.list()) do list[#list + 1] = points.view(point, now) end
    return list
end)

--- Un point d'eau, de la même forme, ou `nil, 'unknown_point'`.
exports('getPoint', function(id)
    if not VavaProvisions.ready then return nil, 'not_ready' end
    local point = points.get(id)
    if not point then return nil, 'unknown_point' end
    return points.view(point, bridge.Now())
end)

--- Point d'eau le plus proche du joueur (position du ped lue par le serveur) à au plus `radius` mètres (3,5 par
--- défaut, 10 au plus) : `id, distance`, ou `nil`. `nil, 'invalid_target'` pour une cible qui n'est pas un joueur.
exports('pointNear', function(source, radius)
    if not VavaProvisions.ready then return nil, 'not_ready' end
    if mathType(source) ~= 'integer' or source <= 0 then return nil, 'invalid_target' end
    local reach = DEFAULT_RADIUS
    if rules.finite(radius) and radius > 0 then reach = min(radius, MAX_RADIUS) end
    local x, y, z = bridge.Position(source)
    if not x then return nil, 'invalid_target' end
    return points.near(x, y, z, reach)
end)
