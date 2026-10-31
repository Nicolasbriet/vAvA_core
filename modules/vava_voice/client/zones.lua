--[[
    vava_voice/client/zones.lua
    Rôle : zones de voix suivies par le client (les seules proches : envoyées par les abonnements de zone du core, à
           l'approche, puis à chaque changement décidé par le Conseil, et retirées quand on s'éloigne) et zone où se
           trouve un point : la plus petite qui le contient l'emporte (la plus précise). Cylindre : rayon à
           l'horizontale, de baseOffset sous le centre jusqu'à height au-dessus.
    Dépendances : config_client.lua
]]

local type, pairs, ipairs, mathType = type, pairs, ipairs, math.type

local cfg = VavaVoice.config.zones

local zones = {}
VavaVoice.zones = zones

---@type table<integer, table>
local list = {}

local FIELDS = { 'x', 'y', 'z', 'radius', 'height', 'multiplier' }

--- Zone reçue du serveur, vérifiée avant d'être gardée (copie).
---@param raw any
---@return table|nil
function zones.valid(raw)
    if type(raw) ~= 'table' or mathType(raw.id) ~= 'integer' or type(raw.label) ~= 'string' then return nil end
    for _, field in ipairs(FIELDS) do
        if type(raw[field]) ~= 'number' then return nil end
    end
    return {
        id = raw.id, label = raw.label, x = raw.x, y = raw.y, z = raw.z,
        radius = raw.radius, height = raw.height, multiplier = raw.multiplier,
    }
end

---@param raw any
---@return table|nil zone  la zone gardée (copie vérifiée), nil si refusée
function zones.set(raw)
    local zone = zones.valid(raw)
    if zone then list[zone.id] = zone end
    return zone
end

---@param id any
function zones.remove(id)
    if mathType(id) == 'integer' then list[id] = nil end
end

---@return table<integer, table>
function zones.all()
    return list
end

---@param zone table
---@param x number
---@param y number
---@param z number
---@return boolean
function zones.contains(zone, x, y, z)
    if z < zone.z - cfg.baseOffset or z > zone.z + zone.height then return false end
    local dx, dy = x - zone.x, y - zone.y
    return dx * dx + dy * dy <= zone.radius * zone.radius
end

--- Effet de la zone où se trouve ce point (1 hors de toute zone).
---@param coords { x: number, y: number, z: number }
---@return number multiplier
---@return table|nil zone
function zones.at(coords)
    local best = nil
    for _, zone in pairs(list) do
        if zones.contains(zone, coords.x, coords.y, coords.z) and (not best or zone.radius < best.radius) then best = zone end
    end
    if not best then return 1.0, nil end
    return best.multiplier, best
end
