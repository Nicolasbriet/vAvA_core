--[[
    vava_needs/shared/starvation.lua
    Rôle : règles pures de la perte de vie d'un besoin épuisé.
      - Avec vava_health (le serveur décide) : part de la vie au-dessus du seuil de mise à terre que représente la
        perte, passée à l'export `damage` de vava_health, qui tient la vie et la mise à terre.
      - Sans lui (repli, appliqué par le client) : vie GTA visée d'après la vie actuelle, la perte, le seuil de mise à
        terre et le plancher. Sans module de mise à terre, jamais sous le plancher ; avec lui, la perte qui atteint le
        seuil donne 0 : le ped tombe franchement (GTA peut laisser debout un ped posé exactement sur le seuil).
      Aucun état.
    Dépendances : shared/constants.lua
]]

local type = type
local ceil, max, huge = math.ceil, math.max, math.huge

local starvation = {}
VavaNeeds.starvation = starvation

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Part (0 à 1) de la vie au-dessus du seuil de mise à terre que retire une perte en points de vie GTA, ou nil s'il n'y
--- a rien à retirer (perte nulle ou invalide, vie maximale invalide ou pas au-dessus du seuil). Plafonnée à 1.
---@param amount any       points de vie GTA perdus
---@param maxHealth any    vie GTA maximale du ped (lue côté serveur)
---@param threshold any    seuil de mise à terre
---@return number|nil
function starvation.share(amount, maxHealth, threshold)
    if not isFinite(amount) or not isFinite(maxHealth) or not isFinite(threshold) or amount <= 0 then return nil end
    local span = maxHealth - threshold
    if span <= 0 then return nil end
    local value = amount / span
    if value > 1 then return 1 end
    return value
end

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
