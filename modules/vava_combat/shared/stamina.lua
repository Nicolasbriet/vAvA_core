--[[
    vava_combat/shared/stamina.lua
    Rôle : règles pures de l'endurance, servies au seul serveur (docs/plan/specs/T-114.md § 7.2) : coût d'une technique,
           dépense, coût et suite d'un coup bloqué (garde brisée quand il coûte au moins ce qui reste), attente avant
           qu'un coût soit payable, part de la recharge laissée par la faim et la soif, pente, changement de pente, état
           envoyé au porteur. Jauge en dixièmes entiers (0 à ENDURANCE_MAX) ; un état est `{ value, at, restAt, rate, … }`
           (shared/endurance.lua) ; absent = plein. Aucune native, aucun état ; une valeur illisible ne lève jamais
           d'erreur. Complète VavaCombat.stamina (server/stamina.lua y ajoute la mémoire des jauges).
    Dépendances : shared/constants.lua, shared/endurance.lua
]]

local type, pairs = type, pairs
local floor, ceil, huge, max, min, tointeger = math.floor, math.ceil, math.huge, math.max, math.min, math.tointeger

local level = VavaCombat.endurance.level
local MAX, REST_MAX = VavaCombat.ENDURANCE_MAX, VavaCombat.ENDURANCE_REST_MAX
-- attente la plus longue rendue au client (jauge qui ne remonte pas, ou très lentement)
local WAIT_MAX = 30000

local stamina = {}
VavaCombat.stamina = stamina

stamina.WAIT_MAX = WAIT_MAX

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Pente de base ou réduite : `max(1, floor(regenPerSecond × 10 × factor + 0,5))` dixièmes par seconde.
---@param factor number
---@param cfg table  config du module (endurance)
---@return integer
function stamina.rateOf(factor, cfg)
    if not finite(factor) then factor = 1 end
    return max(1, floor(cfg.endurance.regenPerSecond * 10 * factor + 0.5))
end

--- Copie de `g` (les champs du porteur sont gardés) avec une valeur vraie à `now` et une reprise de la recharge.
---@param g table|nil
---@param value integer
---@param now integer
---@param restAt integer
---@param cfg table
---@return table
local function settled(g, value, now, restAt, cfg)
    local out = {}
    if type(g) == 'table' then
        for key, field in pairs(g) do out[key] = field end
    end
    out.value, out.at, out.restAt = value, now, restAt
    if not finite(out.rate) then out.rate = stamina.rateOf(1, cfg) end
    return out
end

--- Coût d'une technique en dixièmes : `stamina × 10` (attaque, parade, pas de côté : ce qu'elle coûte ; garde : ce que
--- coûte un coup léger bloqué, exigé pour la lever). Sans `stamina` lisible : 0.
---@param def any
---@return integer
function stamina.needOf(def)
    local cost = type(def) == 'table' and def.stamina or nil
    local int = finite(cost) and tointeger(cost) or nil
    if not int or int <= 0 then return 0 end
    return int * 10
end

--- Dépense `cost` dixièmes à `now` : rend le nouvel état et vrai ; pas assez : l'état tel quel et faux. Une dépense
--- nulle ne touche à rien (la recharge n'est pas retardée).
---@param g table|nil
---@param cost integer
---@param now integer
---@param cfg table
---@return table|nil state
---@return boolean ok
function stamina.spend(g, cost, now, cfg)
    if not finite(cost) or cost <= 0 then return g, true end
    local v = level(g, now)
    if v < cost then return g, false end
    return settled(g, v - cost, now, now + cfg.endurance.regenDelayMs, cfg), true
end

--- Coût en dixièmes d'un coup bloqué : `floor(stamina de la garde × 10 × poids × (bouclier : shieldFactor) + 0,5)`.
---@param guardDef table
---@param weight integer   1, ou heavyWeight pour un coup lourd
---@param byShield boolean bloqué par le bouclier encore accroché au bras
---@param cfg table
---@return integer
function stamina.blockCost(guardDef, weight, byShield, cfg)
    if not finite(weight) or weight <= 0 then weight = 1 end
    local factor = byShield and cfg.endurance.block.shieldFactor or 1
    return floor(stamina.needOf(guardDef) * weight * factor + 0.5)
end

--- Coup bloqué : retire `cost` à ce qui reste (jamais sous 0) ; rend le nouvel état et vrai si la garde cède (le coup
--- coûtait au moins ce qui restait). Coût nul : rien ne change, rien ne cède.
---@param g table|nil
---@param cost integer
---@param now integer
---@param cfg table
---@return table|nil state
---@return boolean broken
function stamina.drain(g, cost, now, cfg)
    if not finite(cost) or cost <= 0 then return g, false end
    local v = level(g, now) - cost
    return settled(g, max(0, v), now, now + cfg.endurance.regenDelayMs, cfg), v <= 0
end

--- Attente (ms) avant que `need` soit payable : nil s'il l'est ; reprise de la recharge puis remontée (instant exact où
--- le niveau l'atteint), 30 000 au plus.
---@param g table|nil
---@param need integer
---@param now integer
---@return integer|nil
function stamina.waitFor(g, need, now)
    local v = level(g, now)
    if not finite(need) or v >= need then return nil end
    if type(g) ~= 'table' then return WAIT_MAX end
    local rate = g.rate
    if not finite(rate) or rate <= 0 then return WAIT_MAX end
    -- instant exact où le niveau atteint `need` (même arrondi que endurance.level)
    local wait = max(g.at, g.restAt) + ceil((need - g.value) * 1000 / rate) - now
    return min(WAIT_MAX, max(1, floor(wait)))
end

--- Part de la recharge laissée par la faim et la soif : le besoin le plus bas (toute valeur numérique finie de `values`
--- compte), puis le plus petit `factor` des paliers dont `at` l'atteint (`at ≥` valeur). Rien de lisible : 1.
---@param values any   { hunger, thirst, … } (export vava_needs:get)
---@param tiers table  config.endurance.needs
---@return number
function stamina.needsFactor(values, tiers)
    if type(values) ~= 'table' or type(tiers) ~= 'table' then return 1 end
    local lowest = nil
    for _, value in pairs(values) do
        if finite(value) and (lowest == nil or value < lowest) then lowest = value end
    end
    if lowest == nil then return 1 end
    local factor = 1
    for _, tier in pairs(tiers) do
        if type(tier) == 'table' and finite(tier.at) and finite(tier.factor) and tier.at >= lowest
            and tier.factor < factor then
            factor = tier.factor
        end
    end
    return factor
end

--- Nouvelle pente à `now` : la part déjà rechargée l'a été à l'ancienne pente (valeur reprise à `now`), la reprise de la
--- recharge est gardée.
---@param g table
---@param now integer
---@param rate integer
---@param factor number
---@return table
function stamina.rebase(g, now, rate, factor)
    local out = {}
    for key, field in pairs(g) do out[key] = field end
    out.value, out.at, out.rate, out.factor = level(g, now), now, rate, factor
    return out
end

--- État envoyé au porteur : niveau, ms avant la reprise de la recharge (0 si pleine, 10 000 au plus), pente. Absent :
--- plein, 0, `baseRate`. Toujours trois entiers.
---@param g table|nil
---@param now integer
---@param baseRate integer
---@return integer value
---@return integer restIn
---@return integer rate
function stamina.wireOf(g, now, baseRate)
    if type(g) ~= 'table' then return MAX, 0, baseRate end
    local v = level(g, now)
    local rate = finite(g.rate) and tointeger(floor(g.rate)) or baseRate
    if v >= MAX or not finite(g.restAt) then return v, 0, rate end
    return v, tointeger(floor(min(REST_MAX, max(0, g.restAt - now)))), rate
end
