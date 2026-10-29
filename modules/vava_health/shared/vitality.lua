--[[
    vava_health/shared/vitality.lua
    Rôle : règles pures du seuil de mise à terre, partagées par le client (ped local) et le serveur (vie lue) :
           vie GTA à poser pour une part de vie, et sens d'une vie lue. Le seuil lui-même est ambigu (GTA peut y laisser
           un ped debout) : au seuil, le joueur est à terre pour le serveur, mais son ped n'est couché qu'une fois sa vie
           tombée sous le seuil (0 quand le client le couche). Aucun état.
    Dépendances : shared/constants.lua
]]

local ceil = math.ceil

local vitality = {}
VavaHealth.vitality = vitality

--- Vie GTA à poser pour une part de vie (0 à 1). 0 couche le ped (vie 0, jamais le seuil lui-même) ; une part non
--- nulle le laisse debout, au moins un point au-dessus du seuil.
---@param ratio number
---@param maxHealth integer
---@param threshold integer
---@return integer
function vitality.toGame(ratio, maxHealth, threshold)
    if ratio <= 0 then return 0 end
    local health = threshold + ceil(ratio * (maxHealth - threshold))
    if health <= threshold then health = threshold + 1 end
    return health
end

--- Vie lue d'un joueur debout : au seuil ou dessous, il est à terre.
---@param health integer
---@param threshold integer
---@return boolean
function vitality.fallen(health, threshold)
    return health <= threshold
end

--- Vie lue d'un joueur à terre : couché sous le seuil (0 une fois couché par son client). Au seuil ou au-dessus, il
--- n'a pas été couché (ordre perdu, client modifié, ped que GTA laisse debout au seuil) : il est à recoucher.
---@param health integer
---@param threshold integer
---@return boolean
function vitality.laidDown(health, threshold)
    return health < threshold
end
