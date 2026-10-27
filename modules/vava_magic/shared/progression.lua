--[[
    vava_magic/shared/progression.lua
    Rôle : règles de progression communes au serveur (qui décide) et au client (qui pré-vérifie et affiche) : niveau
           d'après l'XP, seuils, coût en mana selon le niveau, sigils mémorisables.
    Dépendances : shared/constants.lua, config.lua
]]

local floor = math.floor

local cfg = VavaMagic.config
local THRESHOLDS = cfg.progression.thresholds
local MULTIPLIERS = cfg.progression.costMultipliers
local MAX_LEVEL = #THRESHOLDS

local progression = {}
VavaMagic.progression = progression

progression.MAX_LEVEL = MAX_LEVEL
progression.MAX_XP = THRESHOLDS[MAX_LEVEL]

--- Niveau atteint avec cette XP (1 à MAX_LEVEL).
---@param xp integer
---@return integer
function progression.levelOf(xp)
    local level = 1
    for i = 2, MAX_LEVEL do
        if xp >= THRESHOLDS[i] then level = i end
    end
    return level
end

--- XP qu'il faut pour atteindre un niveau.
---@param level integer
---@return integer
function progression.threshold(level)
    return THRESHOLDS[level]
end

--- Coût en mana d'un sort à ce niveau, arrondi à l'entier.
---@param spellCfg table  config du sort (baseCost)
---@param level integer
---@param share? number   multiplicateur propre à l'action (orbe ancré…)
---@return integer
function progression.cost(spellCfg, level, share)
    return floor(spellCfg.baseCost * MULTIPLIERS[level] * (share or 1) + 0.5)
end

--- Sigils qu'un personnage peut garder : selon son niveau du sort qui gouverne les sigils s'il est mage et le
--- connaît, sinon la limite des non-mages.
---@param isMage boolean
---@param spellXp integer|nil  XP du sort des sigils (nil s'il ne le connaît pas)
---@return integer
function progression.sigilLimit(isMage, spellXp)
    local spell = cfg.spells[cfg.sigils.spell]
    if not isMage or spellXp == nil or not spell then return cfg.sigils.nonMageLimit end
    return spell.levels[progression.levelOf(spellXp)].sigils
end
