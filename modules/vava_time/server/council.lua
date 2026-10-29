--[[
    vava_time/server/council.lua
    Rôle : les décisions du Conseil, communes au Registre en jeu (RPC) et à la Chancellerie (exports web du pont) :
           valeurs revalidées action par action, état changé, publié et écrit, hook ; rend la vue des interfaces, le
           libellé et les détails du journal (inscrits par l'appelant : vava_admin.log en jeu, webLog par le pont).
           Le droit est vérifié avant d'arriver ici (RPC gardé, ou pont auprès du Registre).
    Dépendances : shared/, config.lua, server/core.lua, server/store.lua, server/clock.lua, server/seasons.lua,
                  server/sky.lua
]]

local ipairs, type, mathType = ipairs, type, math.type
local floor, abs = math.floor, math.abs
local format = string.format
local time = os.time

local calendar = VavaTime.calendar
local rules = VavaTime.weatherRules
local store = VavaTime.store
local clock = VavaTime.clock
local seasons = VavaTime.seasons
local sky = VavaTime.sky
local cfg = VavaTime.config
local messages = cfg.messages
local HOOK_CLOCK = VavaTime.HOOKS.CLOCK
local DAY_MINUTES = VavaTime.DAY_MINUTES
local MAX_SHIFT_MINUTES = cfg.clock.maxShiftMinutes

local CLOCK_ACTIONS, WEATHER_ACTIONS = {}, {}
for _, action in ipairs(VavaTime.CLOCK_ACTIONS) do CLOCK_ACTIONS[action] = true end
for _, action in ipairs(VavaTime.WEATHER_ACTIONS) do WEATHER_ACTIONS[action] = true end

local council = {}
VavaTime.council = council

--- « 22:05 ».
---@param seconds number
---@return string
local function hhmm(seconds)
    local hour, minute = calendar.hms(seconds)
    return format('%02d:%02d', hour, minute)
end

--- « +3 h 00 », « −1 h 30 », « aucun ».
---@param shift integer secondes
---@return string
local function shiftText(shift)
    if shift == 0 then return 'aucun' end
    local minutes = abs(shift) // 60
    return format('%s%d h %02d', shift < 0 and '−' or '+', minutes // 60, minutes % 60)
end

--- Vue complète pour l'outil du Conseil et la Chancellerie (au seul membre qui la demande).
---@param now? integer
---@return table
function council.view(now)
    now = now or time()
    local date = seasons.current()
    local info = calendar.seasonInfo(date.season)
    local state = clock.state()
    local weathers = {}
    for index, def in ipairs(cfg.weather.types) do
        weathers[index] = { id = def.id, label = def.label, inSeason = rules.allowed(def.id, date.season) }
    end
    return {
        clock = {
            seconds = floor(clock.seconds(now)), real = floor(calendar.realSeconds(now)), shift = state.shift,
            frozen = state.frozen ~= false,
        },
        calendar = {
            season = date.season, label = info.label, name = info.name, day = date.day, year = date.year,
            text = calendar.dateText(date),
        },
        weather = sky.view(now, date.season),
        weathers = weathers,
        limits = { maxShiftMinutes = MAX_SHIFT_MINUTES },
    }
end

--- Valeur permise pour une action sur l'heure (minutes).
---@param action string
---@param value any
---@return boolean
local function validClockValue(action, value)
    if mathType(value) ~= 'integer' then return false end
    if action == 'set' then return value >= 0 and value < DAY_MINUTES end
    if action == 'shift' then return value ~= 0 and value >= -MAX_SHIFT_MINUTES and value <= MAX_SHIFT_MINUTES end
    return value == 0
end

--- Action du Conseil sur l'heure. `value` en minutes : `set` minute du jour (0–1439), `shift` décalage à ajouter
--- (± maxShiftMinutes, jamais 0), sinon 0.
---@param action any set | shift | freeze | resume | real
---@param value any
---@param by string council | web
---@return boolean ok
---@return table|string view  ou code d'erreur
---@return string|nil label   libellé du journal, nil si rien n'a changé
---@return table|nil details
function council.clock(action, value, by)
    if not VavaTime.ready then return false, 'not_ready' end
    if type(action) ~= 'string' or not CLOCK_ACTIONS[action] or not validClockValue(action, value) then
        return false, 'invalid_value'
    end
    local now = time()
    local ok, changed = clock.apply(action, value * 60, now)
    if not ok then return false, changed end
    local state = clock.state()
    if changed then
        clock.publish()
        store.save()
        VavaTime.core.hooks.runAfter(HOOK_CLOCK, { shift = state.shift, frozen = state.frozen ~= false, by = by })
    end
    local details = {
        heure = hhmm(clock.seconds(now)), decalage = shiftText(state.shift),
        fige = state.frozen and messages.yes or messages.no,
    }
    return true, council.view(now), changed and messages.log[action] or nil, details
end

local WEATHER_LOG = { impose = 'impose', freeze = 'weatherFreeze', release = 'release' }

--- Action du Conseil sur le ciel : `impose` (ciel connu, `hold` le fige), `freeze`, `release`.
---@param action any
---@param weather any
---@param hold any
---@param by string council | web
---@return boolean ok
---@return table|string view  ou code d'erreur
---@return string|nil label
---@return table|nil details
function council.weather(action, weather, hold, by)
    if not VavaTime.ready then return false, 'not_ready' end
    if type(action) ~= 'string' or not WEATHER_ACTIONS[action] then return false, 'invalid_value' end
    if hold ~= nil and type(hold) ~= 'boolean' then return false, 'invalid_value' end
    local now = time()
    local season = seasons.current().season
    local changed
    if action == 'impose' then
        if type(weather) ~= 'string' or not rules.get(weather) then return false, 'unknown_weather' end
        changed = sky.impose(weather, hold == true, now, by)
    elseif action == 'freeze' then
        changed = sky.freeze(now, by)
    else
        changed = sky.release(now, season, by)
    end
    local state = sky.state()
    local def = rules.get(state.id)
    local details = {
        ciel = def and def.label or state.id, fige = state.frozen and messages.yes or messages.no,
        de_saison = rules.allowed(state.id, season) and messages.yes or messages.no,
    }
    return true, council.view(now), changed and messages.log[WEATHER_LOG[action]] or nil, details
end
