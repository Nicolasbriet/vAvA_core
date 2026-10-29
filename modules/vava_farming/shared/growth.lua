--[[
    vava_farming/shared/growth.lua
    Rôle : règles pures de la croissance, partagées par le client (affichage) et le serveur (décision) : avancée d'un
           emplacement d'après le temps écoulé (humidité qui baisse, croissance tant que la terre est humide, pause,
           flétrissement puis mort quand elle est sèche, jachère qui rend de la fertilité), stade et état, régularité
           d'arrosage, qualité d'une récolte. Aucun état : les fonctions reçoivent et rendent des tables.
    Dépendances : shared/constants.lua, config.lua
]]

local floor, min, max = math.floor, math.min, math.max
local ipairs = ipairs

local cfg = VavaFarming.config
local g = cfg.growth
local f = cfg.fertility
local q = cfg.quality
local STATES = VavaFarming.STATES

local growth = {}
VavaFarming.growth = growth

---@class vAvA.SlotState
---@field crop string|nil
---@field seedTier integer
---@field plantedAt integer
---@field growth integer        secondes de croissance effective
---@field moisture number       0–100
---@field fertility number      0–100
---@field drySince integer|nil  depuis quand la terre est sèche
---@field dryHours number       heures de sécheresse depuis la plantation
---@field waterings integer
---@field wilted boolean
---@field dead boolean
---@field lastFamily string|nil
---@field updatedAt integer

--- Applique le temps écoulé depuis `updatedAt` à l'emplacement (modifié en place).
---@param slot vAvA.SlotState
---@param crop table|nil  définition de la culture plantée
---@param now integer
function growth.advance(slot, crop, now)
    local elapsed = now - slot.updatedAt
    if elapsed <= 0 then return end
    if not slot.crop or not crop then
        -- jachère : la terre se refait
        slot.fertility = min(100, slot.fertility + f.fallowPerDay * (elapsed / 86400))
        slot.updatedAt = now
        return
    end
    if slot.dead then
        slot.updatedAt = now
        return
    end
    local rate = crop.waterPerHour / 3600
    local wetTime = slot.moisture > g.moistureThreshold and (slot.moisture - g.moistureThreshold) / rate or 0
    local grown = min(elapsed, wetTime)
    if not slot.wilted and grown > 0 then
        slot.growth = min(crop.growMinutes * 60, slot.growth + floor(grown))
    end
    slot.moisture = max(0, slot.moisture - rate * elapsed)
    local dry = elapsed - wetTime
    if dry > 0 then
        slot.dryHours = slot.dryHours + dry / 3600
        slot.drySince = slot.drySince or (now - floor(dry))
        local drySeconds = now - slot.drySince
        if drySeconds >= g.dieAfterHours * 3600 then
            slot.dead = true
        elseif drySeconds >= g.wiltAfterHours * 3600 then
            slot.wilted = true
        end
    else
        slot.drySince = nil
    end
    slot.updatedAt = now
end

--- Arrosage : humidité pleine, une plante flétrie reprend.
---@param slot vAvA.SlotState
function growth.water(slot)
    slot.moisture = 100
    slot.drySince = nil
    slot.waterings = slot.waterings + 1
    if slot.wilted and not slot.dead then slot.wilted = false end
end

--- Avancement de la croissance (0 à 1).
---@param slot vAvA.SlotState
---@param crop table
---@return number
function growth.progress(slot, crop)
    local total = crop.growMinutes * 60
    if total <= 0 then return 1 end
    return min(1, slot.growth / total)
end

--- État d'un emplacement planté.
---@param slot vAvA.SlotState
---@param crop table
---@return string
function growth.state(slot, crop)
    if slot.dead then return STATES.DEAD end
    if slot.wilted then return STATES.WILTED end
    if growth.progress(slot, crop) >= 1 then return STATES.RIPE end
    return STATES.GROWING
end

--- Stade visuel (1 à #stages) d'après l'avancement.
---@param slot vAvA.SlotState
---@param crop table
---@return integer
function growth.stage(slot, crop)
    local count = #crop.stages
    if count == 0 then return 0 end
    return min(count, floor(growth.progress(slot, crop) * count) + 1)
end

--- Régularité d'arrosage (0–100) : heures de sécheresse rapportées à la durée de croissance.
---@param slot vAvA.SlotState
---@param crop table
---@return number
function growth.regularity(slot, crop)
    local hours = crop.growMinutes / 60
    if hours <= 0 then return 100 end
    return max(0, 100 * (1 - slot.dryHours / hours))
end

--- Qualité (0–100) d'une récolte : graine, compétence, régularité, fertilité, aléa fourni par l'appelant.
---@param seedTier integer
---@param level integer
---@param regularity number
---@param fertility number
---@param jitter number
---@return integer
function growth.quality(seedTier, level, regularity, fertility, jitter)
    local seedQuality = q.materialQuality[min(#q.materialQuality, max(1, seedTier))]
    local value = seedQuality * q.weights.seed + level * q.weights.skill + regularity * q.weights.watering + fertility * q.weights.fertility + jitter
    return floor(min(100, max(0, value)) + 0.5)
end

--- Palier (1 à 5) d'une qualité.
---@param value number
---@return integer
function growth.tierOf(value)
    local tier = 1
    for index, threshold in ipairs(q.tiers) do
        if value >= threshold then tier = index + 1 end
    end
    return tier
end

--- Fertilité après une récolte : coût de la culture, rotation (famille différente) ou répétition (même famille).
---@param fertility number
---@param crop table
---@param lastFamily string|nil
---@return number
function growth.fertilityAfterHarvest(fertility, crop, lastFamily)
    local value = fertility - crop.fertilityCost
    -- première culture (lastFamily nil) : ni bonus ni pénalité, même pour une culture sans famille
    if lastFamily ~= nil then
        if lastFamily == crop.family then
            value = value - f.sameFamilyPenalty
        else
            value = value + f.rotationBonus
        end
    end
    return min(100, max(0, value))
end
