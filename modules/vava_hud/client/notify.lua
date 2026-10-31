--[[
    vava_hud/client/notify.lua
    Rôle : notifications à l'écran pour tous les modules (remplacent celles de GTA, retirées avec son HUD). Message
           validé et borné ; l'interface gère l'empilement et la disparition.
    Dépendances : config_client.lua, client/nui.lua
]]

local type = type

local cfg = VavaHud.config.notifications
local nui = VavaHud.nui

local DEFAULT_KIND = 'info'

local notify = {}
VavaHud.notify = notify

local nextId = 0

---@param message any
---@param kind any  info, warning ou danger
---@return boolean ok
---@return string|nil code
function notify.push(message, kind)
    if type(message) ~= 'string' or #message == 0 then return false, 'invalid_message' end
    if #message > cfg.maxLength then message = message:sub(1, cfg.maxLength) end
    kind = kind or DEFAULT_KIND
    if not cfg.kinds[kind] then return false, 'invalid_kind' end
    nextId = nextId + 1
    nui.send('notify', { id = nextId, message = message, kind = kind })
    return true
end
