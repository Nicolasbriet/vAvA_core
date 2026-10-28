--[[
    vava_gathering/shared/geometry.lua
    Rôle : distances pures, partagées par le client (streaming des props, invite) et le serveur (validation).
    Dépendances : aucune
]]

local sqrt = math.sqrt

local geometry = {}
VavaGathering.geometry = geometry

---@return number
function geometry.distance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz)
end

---@return number
function geometry.distanceSquared(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return dx * dx + dy * dy + dz * dz
end

--- Vrai si le point est à moins de `radius` du centre (distance au carré, sans racine).
---@return boolean
function geometry.within(x, y, z, cx, cy, cz, radius)
    return geometry.distanceSquared(x, y, z, cx, cy, cz) <= radius * radius
end
