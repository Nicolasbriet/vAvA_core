--[[
    vava_inventory/server/positions.lua
    Rôle : position des joueurs lue CÔTÉ SERVEUR (OneSync) pour tout ce qui dépend d'une distance : sacs au sol,
           conteneurs ancrés à un lieu (coffre, grenier, station). Le client n'envoie jamais sa position.
    Dépendances : aucune
]]

local GetPlayerPed, DoesEntityExist, GetEntityCoords = GetPlayerPed, DoesEntityExist, GetEntityCoords

local positions = {}
VavaInventory.positions = positions

--- Position du ped d'un joueur, ou nil s'il n'a pas de ped (en sélection, pas encore apparu).
---@param src integer
---@return number|nil x, number|nil y, number|nil z
function positions.of(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    return coords.x, coords.y, coords.z
end

---@return number
function positions.distanceSquared(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return dx * dx + dy * dy + dz * dz
end

--- Vrai si le joueur est à moins de `radius` mètres du point (position lue côté serveur).
---@param src integer
---@param x number
---@param y number
---@param z number
---@param radius number
---@return boolean
function positions.within(src, x, y, z, radius)
    local px, py, pz = positions.of(src)
    if not px then return false end
    return positions.distanceSquared(px, py, pz, x, y, z) <= radius * radius
end
