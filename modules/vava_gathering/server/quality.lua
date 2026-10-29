--[[
    vava_gathering/server/quality.lua
    Rôle : règles pures d'une récolte : durée du geste (ressource, outil, niveau), score de qualité (niveau, outil,
           vitalité, aléa) et palier, rendement (ressource, outil, bande, saison), échec selon la bande. Aucun état.
    Dépendances : config.lua
]]

local type, ipairs = type, ipairs
local floor, min, max, random = math.floor, math.min, math.max, math.random

local cfg = VavaGathering.config
local q = cfg.quality
local d = cfg.duration

local quality = {}
VavaGathering.quality = quality

--- Durée du geste (ms) : base de la ressource, raccourcie par le niveau, divisée par la puissance de l'outil.
---@param resource vAvA.ResourceDefinition
---@param tool vAvA.ToolDefinition|nil
---@param level integer
---@return integer
function quality.duration(resource, tool, level)
    local ms = resource.durationMs * max(0.0, 1.0 - level * d.skillFactor) / (tool and tool.power or 1.0)
    return max(d.minMs, floor(ms))
end

--- Qualité de l'outil tenu (0 à 100) : sa métadonnée `quality`, sinon la valeur par défaut.
---@param held table|nil
---@return number
function quality.toolQuality(held)
    local meta = held and held.metadata
    local value = type(meta) == 'table' and meta.quality
    if type(value) ~= 'number' then return q.defaultToolQuality end
    return min(100, max(0, value))
end

--- Score 0–100 : niveau, qualité de l'outil, vitalité, bonus de l'outil, aléa.
---@param level integer
---@param toolQuality number
---@param vitality number
---@param toolBonus integer
---@return number
function quality.score(level, toolQuality, vitality, toolBonus)
    local score = level * q.weights.skill + toolQuality * q.weights.tool + vitality * q.weights.vitality
        + toolBonus + (random() * 2 - 1) * q.jitter
    return min(100, max(0, score))
end

--- Palier 1 à 5 d'un score, moins le malus de la bande (jamais sous 1).
---@param score number
---@param malus integer
---@return integer
function quality.tier(score, malus)
    local tier = 1
    for index, threshold in ipairs(q.tiers) do
        if score >= threshold then tier = index + 1 end
    end
    return max(1, tier - (malus or 0))
end

--- Unités produites : tirage dans la fourchette, bonus de l'outil, part de la bande, facteur de la saison (vava_time,
--- 1 sans lui) ; au moins une.
---@param resource vAvA.ResourceDefinition
---@param tool vAvA.ToolDefinition|nil
---@param effects table
---@param season? number
---@return integer
function quality.yield(resource, tool, effects, season)
    local base = random(resource.yield[1], resource.yield[2]) + (tool and tool.yieldBonus or 0)
    return max(1, floor(base * effects.yield * (season or 1) + 0.5))
end

--- La terre se refuse-t-elle ? (chance d'échec de la bande)
---@param effects table
---@return boolean
function quality.failed(effects)
    return effects.failure > 0 and random() < effects.failure
end
