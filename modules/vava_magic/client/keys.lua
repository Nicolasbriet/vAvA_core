--[[
    vava_magic/client/keys.lua
    Rôle : touches, boutons de la souris et commandes du joueur. Chaque action a une commande liée par
           RegisterKeyMapping (clavier, bouton ou molette de la souris ; réglable dans Paramètres > Raccourcis >
           FiveM) ; la touche choisie est relue pour le grimoire. Commandes du chat avec leur suggestion en français.
    Dépendances : config_client.lua, bridge/client.lua
]]

local type, pairs, match = type, pairs, string.match
local RegisterCommand, RegisterKeyMapping, GetControlInstructionalButton, GetHashKey =
    RegisterCommand, RegisterKeyMapping, GetControlInstructionalButton, GetHashKey

local bridge = VavaMagic.bridge
local cfg = VavaMagic.config
local KEYS = cfg.keys
-- bit qui désigne, pour GTA, une commande liée par RegisterKeyMapping
local MAPPED_COMMAND = 0x80000000
local UINT32 = 0xFFFFFFFF

local keys = {}
VavaMagic.keys = keys

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

--- Touche choisie par le joueur pour une action, telle que GTA l'affiche (« L »), sinon son nom de la config
--- (« Clic droit »).
---@param name string
---@return string|nil
function keys.label(name)
    local key = KEYS[name]
    if not key then return nil end
    local command = key.hold and ('+' .. key.command) or key.command
    local button = GetControlInstructionalButton(0, (GetHashKey(command) | MAPPED_COMMAND) & UINT32, true)
    if type(button) == 'string' then
        local letter = match(button, '^t_(.+)$')
        if letter then return letter end
    end
    return key.display or key.key
end

-- suggestions envoyées au chat, renvoyées s'il (re)démarre après le module
local suggestions = {}

---@param command string
---@param suggestion string|table  texte, ou { help, params }
function keys.suggest(command, suggestion)
    suggestions[command] = suggestion
    if type(suggestion) == 'table' then
        bridge.ChatSuggestion(command, suggestion.help, suggestion.params)
    else
        bridge.ChatSuggestion(command, suggestion)
    end
end

--- Le chat vient de (re)démarrer : toutes les suggestions repartent.
function keys.resuggest()
    for command, suggestion in pairs(suggestions) do keys.suggest(command, suggestion) end
end

--- Commande du chat, avec sa suggestion.
---@param command string
---@param suggestion string|table
---@param handler fun(args: string[])
function keys.command(command, suggestion, handler)
    RegisterCommand(command, function(_, args) handler(args or {}) end, false)
    keys.suggest(command, suggestion)
end
