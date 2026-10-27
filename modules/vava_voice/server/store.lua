--[[
    vava_voice/server/store.lua
    Rôle : zones de voix en base (table vava_voice_zones). Les nombres sont relus par tonumber : oxmysql renvoie les
           DECIMAL en texte.
    Dépendances : server/core.lua
]]

local ipairs, tonumber = ipairs, tonumber

local db = VavaVoice.core and VavaVoice.core.db

local store = {}
VavaVoice.store = store

---@class vAvA.VoiceZone
---@field id integer
---@field label string
---@field x number
---@field y number
---@field z number
---@field radius number
---@field height number
---@field multiplier number

---@param row table
---@return vAvA.VoiceZone
local function zoneOf(row)
    return {
        id = tonumber(row.id), label = row.label, x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z),
        radius = tonumber(row.radius), height = tonumber(row.height), multiplier = tonumber(row.multiplier),
    }
end

--- Toutes les zones.
---@return vAvA.VoiceZone[]|nil zones
---@return string|nil err
function store.load()
    local rows, err = db.query('SELECT `id`, `label`, `x`, `y`, `z`, `radius`, `height`, `multiplier` FROM `vava_voice_zones` ORDER BY `id`', {})
    if not rows then return nil, err end
    local out = {}
    for i, row in ipairs(rows) do out[i] = zoneOf(row) end
    return out
end

---@param zone vAvA.VoiceZone  sans id
---@return integer|nil id
---@return string|nil err
function store.insert(zone)
    local id, err = db.insert('INSERT INTO `vava_voice_zones` (`label`, `x`, `y`, `z`, `radius`, `height`, `multiplier`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { zone.label, zone.x, zone.y, zone.z, zone.radius, zone.height, zone.multiplier })
    if not id then return nil, err end
    return tonumber(id)
end

---@param zone vAvA.VoiceZone
---@return boolean ok
---@return string|nil err
function store.update(zone)
    local affected, err = db.update('UPDATE `vava_voice_zones` SET `label` = ?, `x` = ?, `y` = ?, `z` = ?, `radius` = ?, `height` = ?, `multiplier` = ? WHERE `id` = ?',
        { zone.label, zone.x, zone.y, zone.z, zone.radius, zone.height, zone.multiplier, zone.id })
    if affected == nil then return false, err end
    return true
end

---@param id integer
---@return boolean ok
---@return string|nil err
function store.delete(id)
    local affected, err = db.update('DELETE FROM `vava_voice_zones` WHERE `id` = ?', { id })
    if affected == nil then return false, err end
    return true
end
