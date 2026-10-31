--[[
    vava_combat/client/keys.lua
    Rôle : touches du combat (patron de vava_magic/client/keys.lua). Chaque action a une commande liée par
           RegisterKeyMapping (bouton de la souris par défaut ; réglable dans Paramètres > Raccourcis > FiveM). Les
           touches sont déclarées au registre `core:commands` par le serveur (server/commands.lua) : le Codex les montre.
    Dépendances : config_client.lua
]]

local RegisterCommand, RegisterKeyMapping = RegisterCommand, RegisterKeyMapping

local KEYS = VavaCombat.config.keys

local keys = {}
VavaCombat.keys = keys

--- Lie une action à sa touche (config `keys.<nom>`).
---@param name string
---@param handler fun()
function keys.bind(name, handler)
    local key = KEYS[name]
    RegisterCommand(key.command, function() handler() end, false)
    RegisterKeyMapping(key.command, key.label, key.device or 'keyboard', key.key)
end

--- Lie une action maintenue à sa touche (commandes +/-) : `onDown` à l'appui, `onUp` au relâchement.
---@param name string
---@param onDown fun()
---@param onUp fun()
function keys.bindHold(name, onDown, onUp)
    local key = KEYS[name]
    RegisterCommand('+' .. key.command, function() onDown() end, false)
    RegisterCommand('-' .. key.command, function() onUp() end, false)
    RegisterKeyMapping('+' .. key.command, key.label, key.device or 'keyboard', key.key)
end
