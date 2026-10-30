--[[
    vava_farming/shared/growth.lua
    Rôle : règles pures de la croissance, partagées par le client (affichage) et le serveur (décision) : avancée d'un
           emplacement d'après le temps écoulé (humidité qui baisse, croissance tant que la terre est humide, pause,
           flétrissement puis mort quand elle est sèche, jachère qui rend de la fertilité ; saison de vava_time qui
           accélère ou ralentit la pousse et le dessèchement), stade et état, régularité
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
---@field covered boolean       couvert contre le gel jusqu'à la récolte
---@field updatedAt integer

--- Applique le temps écoulé depuis `updatedAt` à l'emplacement (modifié en place). `season` (vava_time, facultatif) :
--- `growth` multiplie la vitesse de pousse, `drying` celle à laquelle la terre sèche ; sans saison, rien ne change.
--- Avec une saison, la croissance garde ses fractions de seconde (une pousse lente appliquée toutes les 10 s ne perd
--- rien à l'arrondi) ; elle est écrite entière en base.
---@param slot vAvA.SlotState
---@param crop table|nil  définition de la culture plantée
---@param now integer
---@param season? { growth: number|nil, drying: number|nil }
function growth.advance(slot, crop, now, season)
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
    local speed = season and season.growth or 1
    local rate = crop.waterPerHour / 3600 * (season and season.drying or 1)
    local wetTime = 0
    if slot.moisture > g.moistureThreshold then
        -- une terre qui ne sèche pas (saison à 0) reste humide tout le temps écoulé
        wetTime = rate > 0 and (slot.moisture - g.moistureThreshold) / rate or elapsed
    end
    local grown = min(elapsed, wetTime)
    if not slot.wilted and grown > 0 and speed > 0 then
        slot.growth = min(crop.growMinutes * 60, slot.growth + (season and grown * speed or floor(grown)))
    end
    slot.moisture = max(0, slot.moisture - rate * elapsed)
    local dry = elapsed - wetTime
    if dry > 0 then
        slot.drySince = slot.drySince or (now - floor(dry))
        -- les heures sèches s'arrêtent à la mort : même compte calculé en une fois ou peu à peu
        local deathAt = slot.drySince + g.dieAfterHours * 3600
        local counted = min(now, deathAt) - (now - dry)
        if counted > 0 then slot.dryHours = slot.dryHours + counted / 3600 end
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

--- Le gel d'une nuit d'hiver (vava_time) tue-t-il la plante de cet emplacement ? Oui si elle est plantée et vivante,
--- sans couverture, et d'une culture qui ne résiste pas au froid (`frostHardy`).
---@param slot vAvA.SlotState
---@param crop table|nil  définition de la culture plantée
---@return boolean
function growth.frostKills(slot, crop)
    return slot.crop ~= nil and crop ~= nil and not slot.dead and slot.covered ~= true and crop.frostHardy ~= true
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

--- Stade visuel (1 à #stages) d'après l'avancement. Le dernier modèle est celui de la plante mûre : il n'apparaît
--- qu'à maturité ; les précédents se partagent la croissance à parts égales.
---@param slot vAvA.SlotState
---@param crop table
---@return integer
function growth.stage(slot, crop)
    local count = #crop.stages
    if count == 0 then return 0 end
    local progress = growth.progress(slot, crop)
    if count == 1 or progress >= 1 then return count end
    return min(count - 1, floor(progress * (count - 1)) + 1)
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
