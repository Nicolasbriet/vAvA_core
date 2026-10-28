--[[
    vava_farming/shared/geometry.lua
    Rôle : géométrie pure partagée par le client (props, invite) et le serveur (validation) : position d'un emplacement
           dans la grille d'une parcelle (centre, cap, lignes, colonnes, espacement), distances.
    Dépendances : aucune
]]

local sqrt, rad, cos, sin, floor = math.sqrt, math.rad, math.cos, math.sin, math.floor

local geometry = {}
VavaFarming.geometry = geometry

--- Position d'un emplacement (1 à rows × cols) : grille centrée sur la parcelle, tournée de son cap.
---@param parcel { x: number, y: number, z: number, heading: number, rows: integer, cols: integer, spacing: number }
---@param index integer
---@return number x, number y, number z
function geometry.slotPosition(parcel, index)
    local row = (index - 1) // parcel.cols
    local col = (index - 1) % parcel.cols
    local localX = (col - (parcel.cols - 1) / 2) * parcel.spacing
    local localY = (row - (parcel.rows - 1) / 2) * parcel.spacing
    local angle = rad(parcel.heading or 0.0)
    local c, s = cos(angle), sin(angle)
    return parcel.x + localX * c - localY * s, parcel.y + localX * s + localY * c, parcel.z
end

---@return number
function geometry.distance(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz)
end

--- Vrai si le point est à moins de `radius` du centre.
---@return boolean
function geometry.within(x, y, z, cx, cy, cz, radius)
    local dx, dy, dz = x - cx, y - cy, z - cz
    return dx * dx + dy * dy + dz * dz <= radius * radius
end

--- Nombre d'emplacements d'une parcelle.
---@param parcel { rows: integer, cols: integer }
---@return integer
function geometry.slotCount(parcel)
    return floor(parcel.rows * parcel.cols)
end
