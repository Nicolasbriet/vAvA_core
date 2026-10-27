--[[
    vava_health/client/keys.lua
    Rôle : touches réglables par le joueur (RegisterKeyMapping, aucune boucle) :
      - relever : intention envoyée au serveur, qui choisit la personne à terre la plus proche ;
      - rendre l'âme : touche à maintenir (appui et relâchement, sans boucle), puis intention envoyée.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/screen.lua, client/hud.lua
]]

local type, tostring = type, tostring
local CreateThread, SetTimeout, GetGameTimer = CreateThread, SetTimeout, GetGameTimer
local RegisterCommand, RegisterKeyMapping = RegisterCommand, RegisterKeyMapping

local core = VavaHealth.core
local cfg = VavaHealth.config
local RPC = VavaHealth.RPC
local screen, hud = VavaHealth.screen, VavaHealth.hud

local ASSIST_COMMAND = 'vava_health_assist'
local GIVE_UP_COMMAND = 'vava_health_giveup'

local keys = {}
VavaHealth.keys = keys

---@param code any
---@return string
local function messageFor(code)
    local text = cfg.messages[tostring(code)]
    if text then return text end
    -- raison rédigée par un module (hook) : affichée telle quelle
    if type(code) == 'string' and code:find(' ', 1, true) then return code end
    return cfg.messages.default
end
keys.messageFor = messageFor

--- Résultat d'un appel : rien si accepté, sinon le message du refus.
local function report(ok, success, code)
    if not ok then
        hud.notify(messageFor(success), 'danger')
    elseif not success then
        hud.notify(messageFor(code), 'warning')
    end
end

-- jeton du maintien en cours ; nil si la touche n'est pas tenue
local holding = nil

local function release()
    if not holding then return end
    holding = nil
    screen.hold(false)
end

RegisterCommand(ASSIST_COMMAND, function()
    local status = VavaHealth.status
    if not core.characters.current() or status.downed then return end
    CreateThread(function() report(core.rpc.call(RPC.ASSIST)) end)
end, false)
RegisterKeyMapping(ASSIST_COMMAND, cfg.labels.assist, 'keyboard', cfg.keys.assist)

RegisterCommand('+' .. GIVE_UP_COMMAND, function()
    local status = VavaHealth.status
    if not status.downed or holding then return end
    if status.downedFor + (GetGameTimer() - status.receivedAt) < cfg.downed.giveUpAfterMs then
        hud.notify(cfg.messages.too_early, 'warning')
        return
    end
    local token = {}
    holding = token
    screen.hold(true)
    SetTimeout(cfg.respawn.holdMs, function()
        if holding ~= token then return end
        holding = nil
        screen.hold(false)
        report(core.rpc.call(RPC.GIVE_UP))
    end)
end, false)
RegisterCommand('-' .. GIVE_UP_COMMAND, release, false)
RegisterKeyMapping('+' .. GIVE_UP_COMMAND, cfg.labels.giveUp, 'keyboard', cfg.keys.giveUp)

--- Relâche le maintien en cours (relevé, porté au lieu de soins).
keys.release = release
