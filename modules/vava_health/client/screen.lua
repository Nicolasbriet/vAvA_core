--[[
    vava_health/client/screen.lua
    Rôle : pont vers l'écran « à terre » (page NUI chargée en arrière-plan, sans focus : le jeu garde les touches).
           Rien n'est envoyé avant que la page se dise prête ; elle reçoit alors l'état en cours.
    Dépendances : config.lua, client/core.lua
]]

local SendNUIMessage, RegisterNUICallback = SendNUIMessage, RegisterNUICallback

local cfg = VavaHealth.config

local screen = {}
VavaHealth.screen = screen

local ready = false
-- dernier état de l'écran à terre, renvoyé si la page se recharge
local current = nil

local function send(action, payload)
    if ready then SendNUIMessage({ action = action, payload = payload }) end
end

--- Affiche (ou met à jour) l'écran à terre.
---@param giveUpInMs integer  délai avant de pouvoir rendre l'âme
---@param autoInMs integer    délai avant d'être porté au lieu de soins
function screen.downed(giveUpInMs, autoInMs)
    current = { giveUpInMs = giveUpInMs, autoInMs = autoInMs }
    send('downed', current)
end

function screen.up()
    current = nil
    send('up', {})
end

--- Geste pour relever : role = helper (je relève) ou patient (on me relève), state = start ou end.
---@param role string
---@param state string
---@param durationMs? integer
function screen.channel(role, state, durationMs)
    send('channel', { role = role, state = state, durationMs = durationMs })
end

--- Touche « rendre l'âme » maintenue (vrai) ou relâchée (faux).
---@param active boolean
function screen.hold(active)
    send('hold', { active = active, durationMs = cfg.respawn.holdMs })
end

RegisterNUICallback('ready', function(_, cb)
    ready = true
    cb({ ok = true })
    SendNUIMessage({ action = 'init', payload = { giveUpKey = cfg.keys.giveUp } })
    if current then send('downed', current) end
end)
