--[[
    vava_health/client/hud.lua
    Rôle : jauge « Santé » et notifications par vava_hud. Facultatif : sans vava_hud, pas de jauge et les messages
           passent par les notifications de GTA. Appels inter-ressources isolés ; jauge redéclarée si vava_hud
           (re)démarre.
    Dépendances : config.lua, client/core.lua
]]

local pcall, tostring = pcall, tostring
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local cfg = VavaHealth.config.hud
local log = VavaHealth.log

local HUD = 'vava_hud'
local GAUGE = VavaHealth.resource .. ':health'
local FEED_TEXT = 'STRING'

local hud = {}
VavaHealth.hud = hud
hud.RESOURCE = HUD

local defined = false

local function invoke(fn, ...)
    local resource = exports[HUD]
    return resource[fn](resource, ...)
end

---@return boolean
local function call(fn, ...)
    if GetResourceState(HUD) ~= 'started' then return false end
    local called, ok, err = pcall(invoke, fn, ...)
    if not called then
        log.warn('%s.%s en erreur : %s', HUD, fn, tostring(ok))
        return false
    end
    if ok == false then
        log.warn('%s.%s refusé : %s', HUD, fn, tostring(err))
        return false
    end
    return true
end

---@param value number  0 à 1
function hud.set(value)
    if not defined then
        defined = call('defineGauge', GAUGE, { label = cfg.label, icon = cfg.icon, order = cfg.order, low = cfg.low, critical = cfg.critical })
        if not defined then return end
    end
    call('setGauge', GAUGE, value)
end

function hud.hide()
    if defined then call('removeGauge', GAUGE) end
    defined = false
end

--- vava_hud vient de (re)démarrer : la jauge est à redéclarer.
function hud.restarted()
    defined = false
end

--- Message au joueur : notification de vava_hud, sinon celle de GTA.
---@param message string
---@param kind? string  info, warning ou danger
function hud.notify(message, kind)
    if call('notify', message, kind) then return end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end
