--[[
    vava_crafting/shared/quality.lua
    Rôle : règles pures de la qualité d'une pièce : qualité moyenne des matériaux d'après les paliers choisis, score
           pondéré plafonné par le niveau, palier d'une qualité. Aucun état. Servies au seul serveur (décision, qui
           ajoute l'aléa ; le menu reçoit son aperçu du serveur, T-132).
    Dépendances : shared/constants.lua, config_client.lua, config.lua
]]

local ipairs = ipairs
local floor, min, max = math.floor, math.min, math.max

local cfg = VavaCrafting.config
local q = cfg.quality
local tiers = cfg.tiers

local quality = {}
VavaCrafting.quality = quality

--- Qualité (0–100) correspondant à un palier de matière.
---@param tier integer
---@return number
function quality.materialQuality(tier)
    return tiers.materialQuality[min(#tiers.materialQuality, max(1, tier))]
end

--- Qualité moyenne des matériaux : paliers choisis pondérés par les quantités.
---@param ingredients { quantity: integer }[]
---@param choices table<integer, integer>  index d'ingrédient → palier
---@return number
function quality.materials(ingredients, choices)
    local total, weight = 0, 0
    for index, ingredient in ipairs(ingredients) do
        total = total + quality.materialQuality(choices[index] or 1) * ingredient.quantity
        weight = weight + ingredient.quantity
    end
    if weight == 0 then return 0 end
    return total / weight
end

--- Score sans aléa : matériaux × m + niveau × n + station × s, plafonné par le niveau si la config le demande.
---@param materials number
---@param level integer
---@param station number  qualité de la station (0–100)
---@return number
function quality.score(materials, level, station)
    local score = materials * q.weights.materials + level * q.weights.skill + station * q.weights.station
    if q.capByLevel then score = min(score, level) end
    return min(100, max(0, score))
end

--- Qualité finale : score, aléa ajouté par l'appelant, bornée et arrondie à l'entier ; le plafond du niveau tient.
---@param score number
---@param jitter number
---@param level integer
---@return integer
function quality.finalize(score, jitter, level)
    local value = score + jitter
    if q.capByLevel then value = min(value, level) end
    return floor(min(100, max(0, value)) + 0.5)
end

--- Palier (1 à 5) d'une qualité.
---@param value number
---@return integer
function quality.tierOf(value)
    local tier = 1
    for index, threshold in ipairs(tiers.thresholds) do
        if value >= threshold then tier = index + 1 end
    end
    return tier
end

--- Libellé d'un palier.
---@param tier integer
---@return string
function quality.tierLabel(tier)
    return tiers.labels[tier] or tostring(tier)
end
