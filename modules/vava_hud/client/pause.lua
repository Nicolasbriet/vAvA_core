--[[
    vava_hud/client/pause.lua
    Rôle : lien avec la bannière du royaume (vava_pause, 1.5.0) : bannière déployée ou non (crochet vava_pause:state,
           remis à « repliée » à l'arrêt de sa ressource) ; réglages du joueur lus chez elle (export setting, isolé) et
           suivis (crochet vava_pause:settingChanged) : taille de l'interface et durée des notifications, envoyées à la
           page (message `settings`) seulement quand elles changent. Sans vava_pause : échelle 1, durée de base.
    Dépendances : config.lua, client/core.lua, client/nui.lua
]]

local type, pcall, tostring = type, pcall, tostring
local floor = math.floor
local GetResourceState, AddEventHandler = GetResourceState, AddEventHandler

local core = VavaHud.core
if not core then return end

local cfg = VavaHud.config
local nui = VavaHud.nui
local PAUSE = cfg.pauseResource
local SCALE_KEY, DURATION_KEY = 'ui.scale', 'hud.notifyDuration'
local DEFAULT_SCALE, DEFAULT_DURATION = 1.0, cfg.notifications.durationMs

local pause = {}
VavaHud.pause = pause

local open = false
local current = { scale = DEFAULT_SCALE, durationMs = DEFAULT_DURATION }
-- après chaque changement : appelé par main.lua (visibilité du HUD)
local onChange = nil

---@param key string
---@return any
local function readSetting(key)
    return exports[PAUSE]:setting(key)
end

--- Réglage de la bannière, ou nil (ressource arrêtée, ancienne ou en erreur).
---@param key string
---@return any
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
---@param scaleChoice any
---@param durationChoice any
---@return { scale: number, durationMs: integer }
local function effective(scaleChoice, durationChoice)
    local scale = cfg.scales and cfg.scales[scaleChoice] or DEFAULT_SCALE
    local factor = cfg.notifyDurations and cfg.notifyDurations[durationChoice] or 1.0
    return { scale = scale, durationMs = floor(DEFAULT_DURATION * factor + 0.5) }
end

---@param value { scale: number, durationMs: integer }
local function apply(value)
    if value.scale == current.scale and value.durationMs == current.durationMs then return end
    current = value
    nui.send('settings', { scale = value.scale, durationMs = value.durationMs })
end

--- Relit les deux réglages chez la bannière (démarrage, bannière démarrée ou arrêtée).
local function reload()
    apply(effective(setting(SCALE_KEY), setting(DURATION_KEY)))
end

---@return boolean  bannière déployée
function pause.isOpen()
    return open
end

--- Réglages effectifs, pour l'état complet envoyé à la page prête.
---@return { scale: number, durationMs: integer }
function pause.settings()
    return { scale = current.scale, durationMs = current.durationMs }
end

---@param handler fun()
function pause.onChange(handler)
    onChange = handler
end

core.hooks.after('vava_pause:state', function(payload)
    open = type(payload) == 'table' and payload.open == true
    if onChange then onChange() end
end)

core.hooks.after('vava_pause:settingChanged', function(payload)
    if type(payload) ~= 'table' then return end
    if payload.key == SCALE_KEY or payload.key == DURATION_KEY then reload() end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == PAUSE then reload() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= PAUSE then return end
    open = false
    apply(effective(nil, nil))
    if onChange then onChange() end
end)

reload()
