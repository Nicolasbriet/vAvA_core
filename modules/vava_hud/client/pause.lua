--[[
    vava_hud/client/pause.lua
    Rôle : lien avec la bannière (vava_pause) : déployée ou non, réglages du joueur lus et suivis (taille, durée des
           notifications, chiffres des coups) ; sans elle, valeurs de base.
    Dépendances : config_client.lua, client/core.lua, client/nui.lua
]]

local type, pcall, tostring = type, pcall, tostring
local floor = math.floor
local GetResourceState, AddEventHandler = GetResourceState, AddEventHandler

local core = VavaHud.core
if not core then return end

local cfg = VavaHud.config
local nui = VavaHud.nui
local PAUSE = cfg.pauseResource
local SCALE_KEY, DURATION_KEY, NUMBERS_KEY = 'ui.scale', 'hud.notifyDuration', 'combat.numbers'
local DEFAULT_SCALE, DEFAULT_DURATION = 1.0, cfg.notifications.durationMs

local pause = {}
VavaHud.pause = pause

local open = false
local current = { scale = DEFAULT_SCALE, durationMs = DEFAULT_DURATION }
-- réglage « Chiffres des coups » tel que lu (nil : bannière absente ; une valeur inconnue vaut numbers.defaultMode)
local numbersMode = nil
-- après chaque changement : appelé par main.lua (visibilité du HUD)
local onChange = nil

local function readSetting(key)
    return exports[PAUSE]:setting(key)
end

--- Réglage de la bannière, ou nil (ressource arrêtée, ancienne ou en erreur).
local function setting(key)
    if type(PAUSE) ~= 'string' or GetResourceState(PAUSE) ~= 'started' then return nil end
    local ok, value = pcall(readSetting, key)
    if not ok then
        core.log.warn('%s.setting en erreur : %s', PAUSE, tostring(value))
        return nil
    end
    return value
end

--- Valeurs effectives d'après les réglages (choix inconnu : valeur de base).
local function effective(scaleChoice, durationChoice)
    local scale = cfg.scales and cfg.scales[scaleChoice] or DEFAULT_SCALE
    local factor = cfg.notifyDurations and cfg.notifyDurations[durationChoice] or 1.0
    return { scale = scale, durationMs = floor(DEFAULT_DURATION * factor + 0.5) }
end

local function apply(value)
    if value.scale == current.scale and value.durationMs == current.durationMs then return end
    current = value
    nui.send('settings', { scale = value.scale, durationMs = value.durationMs })
end

--- Relit les deux réglages chez la bannière (démarrage, bannière démarrée ou arrêtée).
local function reload()
    apply(effective(setting(SCALE_KEY), setting(DURATION_KEY)))
    numbersMode = setting(NUMBERS_KEY)
end

function pause.isOpen()
    return open
end

--- Réglages effectifs, pour l'état complet envoyé à la page prête.
function pause.settings()
    return { scale = current.scale, durationMs = current.durationMs }
end

--- Réglage « Chiffres des coups » (`tous`, `infliges`, `aucun`), ou nil.
function pause.numbersMode()
    return numbersMode
end

function pause.onChange(handler)
    onChange = handler
end

core.hooks.after('vava_pause:state', function(payload)
    open = type(payload) == 'table' and payload.open == true
    if onChange then onChange() end
end)

core.hooks.after('vava_pause:settingChanged', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.key == SCALE_KEY or payload.key == DURATION_KEY then
        reload()
    elseif payload.key == NUMBERS_KEY then
        numbersMode = setting(NUMBERS_KEY)
    end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == PAUSE then reload() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= PAUSE then return end
    open = false
    numbersMode = nil
    apply(effective(nil, nil))
    if onChange then onChange() end
end)

reload()
