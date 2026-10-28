--[[
    vava_skills/shared/progression.lua
    Rôle : règles pures de progression, partagées par le client (affichage) et le serveur (décision) : XP d'un niveau
           au suivant, rang d'un niveau, budget consommé, rendements décroissants. Aucun état.
    Dépendances : shared/constants.lua, config.lua
]]

local floor, max, min = math.floor, math.max, math.min
local ipairs, pairs = ipairs, pairs

local cfg = VavaSkills.config
local xpCfg = cfg.xp
local levelCfg = cfg.levels

local progression = {}
VavaSkills.progression = progression

--- XP qu'il faut pour passer de `level` au niveau suivant.
---@param level integer
---@return integer
function progression.xpToNext(level)
    return floor(xpCfg.base + xpCfg.square * level * level)
end

--- Rang d'un niveau : { name, label, min }.
---@param level integer
---@return table
function progression.rankOf(level)
    local found = cfg.ranks[1]
    for _, rank in ipairs(cfg.ranks) do
        if level >= rank.min then found = rank end
    end
    return found
end

--- Rang par son nom, ou nil.
---@param name string
---@return table|nil
function progression.rank(name)
    for _, rank in ipairs(cfg.ranks) do
        if rank.name == name then return rank end
    end
    return nil
end

--- Vrai si le niveau atteint le rang nommé.
---@param level integer
---@param rankName string
---@return boolean
function progression.hasRank(level, rankName)
    local rank = progression.rank(rankName)
    return rank ~= nil and level >= rank.min
end

--- Points au-delà du savoir commun consommés par une compétence.
---@param level integer
---@return integer
function progression.budgetOf(level)
    return max(0, level - levelCfg.commonKnowledge)
end

--- Budget consommé par un ensemble de compétences { [skill] = { level } }.
---@param skills table<string, { level: integer }>
---@return integer
function progression.budgetUsed(skills)
    local used = 0
    for _, entry in pairs(skills) do used = used + progression.budgetOf(entry.level) end
    return used
end

--- Facteur de rendement d'une action de `difficulty` pour un personnage de `level` (1 = plein, floor au minimum).
---@param level integer
---@param difficulty integer
---@return number
function progression.diminishing(level, difficulty)
    local d = xpCfg.diminishing
    local gap = level - difficulty - d.margin
    if gap <= 0 then return 1.0 end
    if gap >= d.span then return d.floor end
    return max(d.floor, 1.0 - (1.0 - d.floor) * (gap / d.span))
end

--- Niveau borné aux limites du jeu.
---@param level number
---@return integer
function progression.clampLevel(level)
    return floor(min(levelCfg.max, max(0, level)))
end
