--[[
    vava_combat/shared/endurance.lua
    Rôle : règles pures de la jauge d'endurance lues par le client et le serveur (spec T-114 § 7.2) : niveau d'un état à
           un instant, lecture bornée d'un état reçu, instant où elle est pleine. Aucune native, aucun état.
    Dépendances : shared/constants.lua
]]

local type, mathType = type, math.type
local floor, ceil, huge, max = math.floor, math.ceil, math.huge, math.max

local MAX, REST_MAX, RATE_MAX = VavaCombat.ENDURANCE_MAX, VavaCombat.ENDURANCE_REST_MAX, VavaCombat.ENDURANCE_RATE_MAX

local endurance = {}
VavaCombat.endurance = endurance

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Niveau en dixièmes entiers (0 à MAX) d'un état `{ value, at, restAt, rate }` à `now` : `value` vrai à `at`, recharge
--- de `rate` dixièmes par seconde à partir de `max(at, restAt)`. Absent ou illisible : MAX (jamais une erreur).
---@param g table|nil
---@param now integer
---@return integer
function endurance.level(g, now)
    if type(g) ~= 'table' then return MAX end
    local value, at, restAt, rate = g.value, g.at, g.restAt, g.rate
    if not finite(value) or not finite(at) or not finite(restAt) or not finite(rate) or not finite(now) then return MAX end
    local level = value + floor(max(0, now - max(at, restAt)) * max(0, rate) / 1000)
    if level >= MAX then return MAX end
    if level <= 0 then return 0 end
    return floor(level)
end

--- État reçu du serveur (trois entiers bornés : dixièmes, ms avant la recharge, dixièmes par seconde) : `{ value, restIn,
--- rate }`, ou nil (message ignoré).
---@param value any
---@param restIn any
---@param rate any
---@return { value: integer, restIn: integer, rate: integer }|nil
function endurance.read(value, restIn, rate)
    if mathType(value) ~= 'integer' or mathType(restIn) ~= 'integer' or mathType(rate) ~= 'integer' then return nil end
    if value < 0 or value > MAX or restIn < 0 or restIn > REST_MAX or rate < 0 or rate > RATE_MAX then return nil end
    return { value = value, restIn = restIn, rate = rate }
end

--- Instant où la jauge sera pleine : `now` si elle l'est déjà ; `math.huge` si elle ne remonte pas.
---@param g table|nil
---@param now integer
---@return number
function endurance.fullAt(g, now)
    if endurance.level(g, now) >= MAX then return now end
    if not (g.rate > 0) then return huge end
    return max(g.at, g.restAt) + ceil((MAX - g.value) * 1000 / g.rate)
end
