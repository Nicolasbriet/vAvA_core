--[[
    vava_chat/client/layout.lua
    Rôle : place et taille du chat, choisies par le joueur (déplacé par son bandeau, agrandi par son coin) et gardées
           sur son PC (KVP de la ressource), en parts de l'écran pour suivre un changement de résolution.
           `/chat reinit` le remet à sa place par défaut.
    Dépendances : config_client.lua, client/nui.lua
]]

local type, pcall = type, pcall
local GetResourceKvpString, SetResourceKvp, DeleteResourceKvp = GetResourceKvpString, SetResourceKvp, DeleteResourceKvp
local encode, decode = json.encode, json.decode

local nui = VavaChat.nui
local cfg = VavaChat.config
local KVP = 'layout'
-- part de l'écran minimale d'un côté (le chat ne peut pas disparaître)
local MIN_SIDE = 0.05

local layout = {}
VavaChat.layout = layout

---@param value any
---@param low number
---@return boolean
local function share(value, low)
    return type(value) == 'number' and value == value and value >= low and value <= 1
end

--- Place valide (parts de l'écran) ?
---@param data any
---@return boolean
function layout.valid(data)
    return type(data) == 'table' and share(data.x, 0) and share(data.y, 0) and share(data.w, MIN_SIDE)
        and share(data.h, MIN_SIDE)
end

--- Place gardée, ou celle par défaut.
---@return table
function layout.load()
    local raw = GetResourceKvpString(KVP)
    if raw then
        local ok, data = pcall(decode, raw)
        if ok and layout.valid(data) then return { x = data.x, y = data.y, w = data.w, h = data.h } end
    end
    return cfg.ui.defaultLayout
end

function layout.reset()
    DeleteResourceKvp(KVP)
    nui.send('layout', cfg.ui.defaultLayout)
end

nui.onReady(function()
    nui.send('layout', layout.load())
end)

-- fin d'un déplacement ou d'un agrandissement
nui.on('layout', function(data)
    if not layout.valid(data) then return { ok = false, error = 'invalid_args' } end
    SetResourceKvp(KVP, encode({ x = data.x, y = data.y, w = data.w, h = data.h }))
    return { ok = true }
end)
