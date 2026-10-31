--[[
    vava_pause/client/sources.lua
    Rôle : lectures locales des autres modules, sans réseau, chacune isolée (ressource démarrée, pcall) : vie et mise
           à terre (vava_health), faim et soif (vava_needs), heure et saison (vava_time, repli : horloge du jeu),
           portée de la voix (vava_voice), Codex en panneau (vava_codex) ; touche réellement liée par le joueur à une
           entrée du registre (même méthode que vava_codex/client/keys.lua).
    Dépendances : shared/constants.lua, client/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local match, mathType = string.match, math.type
local GetResourceState, GetClockHours = GetResourceState, GetClockHours
local GetControlInstructionalButton, GetHashKey = GetControlInstructionalButton, GetHashKey

local HEALTH, NEEDS, TIME, VOICE = 'vava_health', 'vava_needs', 'vava_time', 'vava_voice'
-- bit qui désigne, pour GTA, une commande liée par RegisterKeyMapping
local MAPPED_COMMAND = 0x80000000
local UINT32 = 0xFFFFFFFF

local sources = {}
VavaPause.sources = sources

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Vrai si la ressource tourne.
---@param resource string
---@return boolean
function sources.started(resource)
    return type(resource) == 'string' and GetResourceState(resource) == 'started'
end

--- Export client d'une autre ressource, isolé : `true, valeurs…` ou `false`.
---@return boolean called
function sources.call(resource, fn, ...)
    if not sources.started(resource) then return false end
    local ok, a, b = pcall(invoke, resource, fn, ...)
    if not ok then
        VavaPause.log.warn('%s.%s en erreur : %s', resource, fn, tostring(a))
        return false
    end
    return true, a, b
end

--- État de vava_health : { health (0 à 1), downed }, ou nil.
---@return table|nil
function sources.health()
    local called, state = sources.call(HEALTH, 'get')
    return called and type(state) == 'table' and state or nil
end

--- Vrai si le joueur est à terre (pré-vérification : le serveur décide).
---@return boolean
function sources.downed()
    local state = sources.health()
    return state ~= nil and state.downed == true
end

--- Faim et soif (0 à 100), ou nil.
---@return { hunger: number|nil, thirst: number|nil }|nil
function sources.needs()
    local called, values = sources.call(NEEDS, 'get')
    if not called or type(values) ~= 'table' then return nil end
    return { hunger = type(values.hunger) == 'number' and values.hunger or nil,
             thirst = type(values.thirst) == 'number' and values.thirst or nil }
end

--- Heure du royaume (0 à 23) : vava_time, sinon l'horloge du jeu.
---@return integer
function sources.hour()
    local called, clock = sources.call(TIME, 'getClock')
    if called and type(clock) == 'table' and mathType(clock.hour) == 'integer' then return clock.hour end
    return GetClockHours()
end

--- Saison du royaume (identifiant), ou nil.
---@return string|nil
function sources.season()
    local called, season = sources.call(TIME, 'getSeason')
    return called and type(season) == 'string' and season or nil
end

--- Portée de la voix : { label, distance }, ou nil.
---@return table|nil
function sources.voice()
    local called, range = sources.call(VOICE, 'getRange')
    if not called or type(range) ~= 'table' or type(range.label) ~= 'string' or type(range.distance) ~= 'number' then
        return nil
    end
    return { label = range.label, distance = range.distance }
end

--- Touche du joueur pour une entrée du registre : lettre lue dans le jeu, sinon `keyDisplay`, sinon `key`.
---@param entry { name: string, hold?: boolean, key?: string, keyDisplay?: string }
---@return string|nil
function sources.keyLabel(entry)
    if not entry.key then return nil end
    -- Échap et P : lus directement par la bannière, aucune liaison FiveM à lire
    if entry.module == VavaPause.resource then return entry.keyDisplay or entry.key end
    local command = entry.hold and ('+' .. entry.name) or entry.name
    local button = GetControlInstructionalButton(0, (GetHashKey(command) | MAPPED_COMMAND) & UINT32, true)
    if type(button) == 'string' then
        local letter = match(button, '^t_(.+)$')
        if letter then return letter end
    end
    return entry.keyDisplay or entry.key
end
