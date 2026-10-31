--[[
    vava_combat/shared/guard.lua
    Rôle : règle pure de la garde du statebag du bouclier, servie au seul serveur (server_scripts) : délai avant de
           remettre la valeur du serveur sur un ped dont le statebag a été réécrit. Règle de
           vava_inventory/shared/held.lua (guardDelay), recopiée (une ressource n'en charge pas une autre) ; sortie de
           shared/shield.lua en 1.2.0 (relecture réseau R-3 de T-142 : le client ne s'en sert pas).
    Dépendances : shared/constants.lua
]]

local min = math.min

-- au-delà, le décalage du délai déborderait : le plafond est atteint bien avant
local MAX_SHIFT = 20

local guard = {}
VavaCombat.guard = guard

--- Délai avant de remettre la valeur du serveur : `guardDelayMs` tant que la valeur n'a pas été remise
--- `guardMaxCorrections` fois depuis la dernière publication, puis doublé à chaque remise jusqu'à `guardMaxDelayMs`.
---@param streak integer  remises déjà faites depuis la dernière publication
---@param cfg { guardDelayMs: integer, guardMaxCorrections: integer, guardMaxDelayMs: integer }
---@return integer
function guard.delay(streak, cfg)
    local over = streak - cfg.guardMaxCorrections
    if over < 0 then return cfg.guardDelayMs end
    if over >= MAX_SHIFT then return cfg.guardMaxDelayMs end
    return min(cfg.guardDelayMs << (over + 1), cfg.guardMaxDelayMs)
end
