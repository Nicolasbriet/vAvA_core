--[[
    shared/core/logger.lua
    Rôle : journalisation console à niveaux (debug, info, warn, error), préfixée par module, avec limitation de fréquence.
    Dépendances : shared/init.lua, config/shared.lua
]]

local print, type, tostring, select, pcall = print, type, tostring, select, pcall
local format = string.format
local GetGameTimer = GetGameTimer

local cfg = vAvA.config.shared.log
local PREFIX = cfg.prefix
local RESET = cfg.colors.reset
local THROTTLE_MS = cfg.throttleMs

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local LEVEL_NAMES = { 'debug', 'info', 'warn', 'error' }
local LEVEL_LABELS = { 'DEBUG', 'INFO', 'WARN', 'ERROR' }
local LEVEL_COLORS = { cfg.colors.debug, cfg.colors.info, cfg.colors.warn, cfg.colors.error }

local logger = {}
vAvA.logger = logger

-- Tout est affiché tant que init.lua n'a pas appliqué le niveau configuré : aucun message de démarrage n'est perdu.
local minLevel = LEVELS.debug

---@param levelName string
---@return boolean ok  false si le niveau est inconnu (le niveau courant est conservé)
function logger.setLevel(levelName)
    local level = LEVELS[levelName]
    if not level then return false end
    minLevel = level
    return true
end

--- Permet d'éviter un calcul coûteux (sérialisation…) destiné à un niveau qui ne sera pas affiché.
---@param levelName string
---@return boolean
function logger.isEnabled(levelName)
    local level = LEVELS[levelName]
    return level ~= nil and level >= minLevel
end

---@param message any
---@return string
local function render(message, ...)
    if type(message) ~= 'string' then message = tostring(message) end
    if select('#', ...) == 0 then return message end
    local ok, result = pcall(format, message, ...)
    if ok then return result end
    return message .. ' [format invalide : ' .. tostring(result) .. ']'
end

---@param level integer
---@param scope string
---@param message any
local function emit(level, scope, message, ...)
    print(format('%s[%s][%s][%s] %s%s', LEVEL_COLORS[level], PREFIX, LEVEL_LABELS[level], scope, render(message, ...), RESET))
end

--- Écrit un message. Le formatage (string.format) n'a lieu que si le niveau est affiché.
---@param levelName 'debug'|'info'|'warn'|'error'
---@param scope string
---@param message any
---@param ... any arguments de format
function logger.write(levelName, scope, message, ...)
    local level = LEVELS[levelName]
    if not level or level < minLevel then return end
    emit(level, scope, message, ...)
end

---@class vAvA.ScopedLogger
---@field debug fun(message: any, ...: any)
---@field info fun(message: any, ...: any)
---@field warn fun(message: any, ...: any)
---@field error fun(message: any, ...: any)

--- Crée un logger dont chaque message est préfixé par `scope` (nom du sous-système ou du module).
---@param scope string
---@return vAvA.ScopedLogger
function logger.create(scope)
    local scoped = {}
    for level = 1, #LEVEL_NAMES do
        scoped[LEVEL_NAMES[level]] = function(message, ...)
            if level < minLevel then return end
            emit(level, scope, message, ...)
        end
    end
    return scoped
end

--- Limite la fréquence d'un log répétitif. L'état est porté par l'objet concerné (bucket, entrée de hook…) :
--- il disparaît avec lui, rien n'est à nettoyer ici.
---@param state table
---@return boolean allowed
---@return integer suppressed  messages ignorés depuis le dernier autorisé
function logger.throttle(state)
    local now = GetGameTimer()
    local nextAt = state.logNextAt
    if nextAt and now < nextAt then
        state.logSuppressed = (state.logSuppressed or 0) + 1
        return false, 0
    end
    local suppressed = state.logSuppressed or 0
    state.logSuppressed = 0
    state.logNextAt = now + THROTTLE_MS
    return true, suppressed
end

--- Mention à ajouter à un log limité : vide si rien n'a été ignoré depuis le précédent.
---@param suppressed integer
---@return string
function logger.suppressedNote(suppressed)
    if suppressed == 0 then return '' end
    return format(' [%d message(s) similaire(s) ignoré(s)]', suppressed)
end
