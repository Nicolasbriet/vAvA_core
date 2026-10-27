--[[
    vava_admin/server/ranks.lua
    Rôle : rangs du Conseil, compilés une fois depuis la configuration : droits cumulés (chaque rang a ceux des rangs
           inférieurs), comparaison des rangs, règle des durées de ban. La console a tous les droits.
    Dépendances : shared/constants.lua, config.lua
]]

local ipairs, pairs, setmetatable = ipairs, pairs, setmetatable
local huge = math.huge
local sort = table.sort

local cfg = VavaAdmin.config

local ranks = {}
VavaAdmin.ranks = ranks

---@class vAvA.AdminRank
---@field name string
---@field label string
---@field level number
---@field maxBanHours number
---@field permanentBans boolean
---@field permissions table<string, boolean>

---@type table<string, vAvA.AdminRank>
local byName = {}
---@type vAvA.AdminRank[]
local ordered = {}

local inherited = {}
for i, def in ipairs(cfg.ranks) do
    for _, permission in ipairs(def.permissions) do inherited[permission] = true end
    local permissions = {}
    for permission in pairs(inherited) do permissions[permission] = true end
    local rank = {
        name = def.name, label = def.label, level = def.level,
        maxBanHours = def.maxBanHours or 0, permanentBans = def.permanentBans == true, permissions = permissions,
    }
    byName[def.name] = rank
    ordered[i] = rank
end

-- la console (et plus tard le panneau web de confiance) : au-dessus de tous les rangs
ranks.CONSOLE = {
    name = 'console', label = cfg.messages.console, level = huge, maxBanHours = huge, permanentBans = true,
    permissions = setmetatable({}, { __index = function() return true end }),
}

---@param name any
---@return vAvA.AdminRank|nil
function ranks.get(name)
    return byName[name]
end

--- Rangs du plus bas au plus haut, pour le panneau : { name, label, level }.
---@return table[]
function ranks.list()
    local out = {}
    for i, rank in ipairs(ordered) do out[i] = { name = rank.name, label = rank.label, level = rank.level } end
    return out
end

--- Droits d'un rang, en liste (pour le panneau, qui n'affiche que ce qu'il peut faire).
---@param rank vAvA.AdminRank
---@return string[]
function ranks.permissionsOf(rank)
    local out = {}
    for permission in pairs(rank.permissions) do out[#out + 1] = permission end
    sort(out)
    return out
end

--- Un rang peut-il prononcer un ban de cette durée ? `hours` = 0 : définitif.
---@param rank vAvA.AdminRank
---@param hours integer
---@return boolean
function ranks.canBan(rank, hours)
    if not rank.permissions.ban then return false end
    if rank.permanentBans then return true end
    return hours > 0 and hours <= rank.maxBanHours
end

--- Durées proposées à un rang (heures ; 0 = définitif).
---@param rank vAvA.AdminRank
---@return integer[]
function ranks.banDurationsFor(rank)
    local out = {}
    for _, hours in ipairs(cfg.banDurations) do
        if ranks.canBan(rank, hours) then out[#out + 1] = hours end
    end
    return out
end
