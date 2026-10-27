--[[
    vava_magic/shared/geometry.lua
    Rôle : calculs de positions communs au serveur et au client (tables { x, y, z } ou vecteurs) : distances, angle
           entre deux directions, zones protégées.
    Dépendances : shared/constants.lua, config.lua
]]

local sqrt, acos, deg = math.sqrt, math.acos, math.deg
local ipairs = ipairs

local ZONES = VavaMagic.config.combat.protectedZones

local geometry = {}
VavaMagic.geometry = geometry

---@return number
function geometry.distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

---@return number
function geometry.distance2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return sqrt(dx * dx + dy * dy)
end

--- Vecteur unitaire, ou nil pour un vecteur nul ou non fini.
---@return table|nil
function geometry.normalize(x, y, z)
    local length = sqrt(x * x + y * y + z * z)
    if length ~= length or length < 1e-6 or length == math.huge then return nil end
    return { x = x / length, y = y / length, z = z / length }
end

--- Angle (degrés) entre une direction unitaire et le vecteur origine → point.
---@param direction table  unitaire
---@param origin table
---@param point table
---@return number|nil  nil si le point est confondu avec l'origine
function geometry.angle(direction, origin, point)
    local toward = geometry.normalize(point.x - origin.x, point.y - origin.y, point.z - origin.z)
    if not toward then return nil end
    local dot = direction.x * toward.x + direction.y * toward.y + direction.z * toward.z
    if dot > 1 then dot = 1 elseif dot < -1 then dot = -1 end
    return deg(acos(dot))
end

--- Zone protégée contenant ce point (cercle au sol), ou nil.
---@param point table
---@return table|nil
function geometry.protectedZone(point)
    for _, zone in ipairs(ZONES) do
        if geometry.distance2d(point, zone) <= zone.radius then return zone end
    end
    return nil
end
