--[[
    vava_needs/client/hud.lua
    Rôle : jauges et messages des besoins par vava_hud. Facultatif : sans vava_hud, pas de jauge et les messages
           passent par les notifications de GTA. Chaque appel inter-ressources est isolé ; les jauges sont
           redéclarées quand vava_hud (re)démarre.
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local ipairs, pcall, tostring = ipairs, pcall, tostring
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local cfg = VavaNeeds.config
local MAX = VavaNeeds.MAX
local PREFIX = VavaNeeds.GAUGE_PREFIX
local log = VavaNeeds.log

local HUD = 'vava_hud'
local FEED_TEXT = 'STRING'

local hud = {}
VavaNeeds.hud = hud
hud.RESOURCE = HUD

local defined = false

local function invoke(fn, ...)
    local resource = exports[HUD]
    return resource[fn](resource, ...)
end

--- exports.vava_hud:<fn>(...), isolé. Renvoie vrai si l'appel a réussi.
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

local function define()
    local all = true
    for i, need in ipairs(cfg.needs) do
        all = call('defineGauge', PREFIX .. need.name, {
            label = need.label,
            icon = need.icon,
            order = cfg.hud.firstOrder + (i - 1) * cfg.hud.orderStep,
            low = cfg.thresholds.low / MAX,
            critical = cfg.thresholds.critical / MAX,
        }) and all
    end
    -- en cas d'échec (vava_hud absent ou pas encore démarré), redéclarées à la prochaine mise à jour
    defined = all
end

--- Affiche les valeurs (déclare les jauges au premier appel).
---@param values table<string, number>
function hud.show(values)
    if not defined then define() end
    if not defined then return end
    for _, need in ipairs(cfg.needs) do
        call('setGauge', PREFIX .. need.name, values[need.name] / MAX)
    end
end

--- Retire les jauges (personnage déchargé).
function hud.hide()
    if not defined then return end
    for _, need in ipairs(cfg.needs) do call('removeGauge', PREFIX .. need.name) end
    defined = false
end

--- vava_hud vient de (re)démarrer : ses jauges sont vides.
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
