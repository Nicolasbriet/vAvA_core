--[[
    vava_pause/server/api.lua
    Rôle : export serveur pour les autres modules : savoir si un joueur est « en combat » (fenêtre de 10 s après un coup
           donné ou reçu passé par vava_health:hit), pour refuser un échange, une téléportation… (T-030 et suivants).
    Dépendances : server/core.lua, server/combat.lua
]]

local mathType = math.type

local fight = VavaPause.fight
if not fight then return end

--- `true, millisecondes restantes` si le joueur est en combat, sinon `false`.
---@param src integer
---@return boolean
---@return integer|nil remaining
exports('inCombat', function(src)
    if mathType(src) ~= 'integer' then return false end
    local remaining = fight.remaining(src)
    if remaining > 0 then return true, remaining end
    return false
end)
