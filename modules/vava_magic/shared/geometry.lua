--[[
    vava_magic/shared/geometry.lua
    Rôle : calculs de positions communs au serveur et au client (tables { x, y, z } ou vecteurs) : distances, angle
           entre deux directions, zones protégées, distance à un segment et croisement de segments (zones en ligne).
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

--- Distance au sol (2D) d'un point au segment [a, b].
---@param point table
---@param a table
---@param b table
---@return number
function geometry.segmentDistance2d(point, a, b)
    local abx, aby = b.x - a.x, b.y - a.y
    local length2 = abx * abx + aby * aby
    local t = 0
    if length2 > 1e-9 then
        t = ((point.x - a.x) * abx + (point.y - a.y) * aby) / length2
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
    end
    local dx, dy = point.x - (a.x + abx * t), point.y - (a.y + aby * t)
    return sqrt(dx * dx + dy * dy)
end

--- Les segments [a, b] et [c, d] se croisent-ils au sol (2D) ?
---@return boolean
function geometry.segmentsCross2d(a, b, c, d)
    local function side(p, q, r)
        return (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
    end
    local d1, d2 = side(c, d, a), side(c, d, b)
    local d3, d4 = side(a, b, c), side(a, b, d)
    return ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0))
end

--- Vecteur unitaire au sol (2D) de a vers b, ou nil s'ils sont confondus.
---@return table|nil
function geometry.direction2d(a, b)
    local dx, dy = b.x - a.x, b.y - a.y
    local length = sqrt(dx * dx + dy * dy)
    if length < 1e-6 then return nil end
    return { x = dx / length, y = dy / length }
end
