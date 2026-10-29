--[[
    vava_needs/shared/starvation.lua
    Rôle : règle pure de la perte de vie d'un besoin épuisé : vie GTA visée d'après la vie actuelle, la perte, le seuil
           de mise à terre et le plancher. Sans module de mise à terre, jamais sous le plancher ; avec lui, la perte qui
           atteint le seuil donne 0 : le ped tombe franchement (GTA peut laisser debout un ped posé exactement sur le
           seuil). Aucun état.
    Dépendances : shared/constants.lua
]]

local ceil, max = math.ceil, math.max

local starvation = {}
VavaNeeds.starvation = starvation

--- Vie GTA après la perte, ou nil s'il n'y a rien à retirer (déjà au plancher ou au seuil).
---@param current integer     vie GTA actuelle
---@param amount number       points de vie perdus
---@param maxHealth integer
---@param threshold integer   seuil de mise à terre
---@param floorRatio number   plancher sans module de mise à terre (part de la vie au-dessus du seuil)
---@param downing boolean     un module de mise à terre tourne : le plancher est levé
---@return integer|nil
function starvation.health(current, amount, maxHealth, threshold, floorRatio, downing)
    local minimum = ceil(threshold + (downing and 0 or floorRatio) * (maxHealth - threshold))
    if current <= minimum then return nil end
    local left = current - amount
    if downing and left <= minimum then return 0 end
    return max(minimum, left)
end
