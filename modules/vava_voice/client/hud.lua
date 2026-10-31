--[[
    vava_voice/client/hud.lua
    Rôle : médaillon « Voix » dans vava_hud : rempli d'un quart par portée (Chuchoter = un quart, Déclamer = plein),
           lueur de laiton quand le joueur parle. Facultatif : sans vava_hud, pas de médaillon. Appels
           inter-ressources isolés ; médaillon redéclaré si vava_hud (re)démarre.
    Dépendances : config_client.lua, client/core.lua
]]

local pcall, tostring = pcall, tostring
local GetResourceState = GetResourceState

local cfg = VavaVoice.config.hud
local log = VavaVoice.log

local HUD = 'vava_hud'
local GAUGE = VavaVoice.resource .. ':voice'

local hud = {}
VavaVoice.hud = hud
hud.RESOURCE = HUD

local defined = false
-- dernier état voulu, réappliqué quand le médaillon est redéclaré
local value, active = 0, false

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

---@return boolean
local function ensure()
    if defined then return true end
    defined = call('defineGauge', GAUGE, { label = cfg.label, icon = cfg.icon, order = cfg.order })
    if defined then
        call('setGauge', GAUGE, value)
        call('setGaugeActive', GAUGE, active)
    end
    return defined
end

---@param ratio number  0 à 1
function hud.set(ratio)
    value = ratio
    if ensure() then call('setGauge', GAUGE, ratio) end
end

---@param talking boolean
function hud.setActive(talking)
    active = talking
    if ensure() then call('setGaugeActive', GAUGE, talking) end
end

function hud.hide()
    if defined then call('removeGauge', GAUGE) end
    defined = false
    active = false
end

--- vava_hud vient de (re)démarrer : le médaillon est à redéclarer.
function hud.restarted()
    defined = false
end
