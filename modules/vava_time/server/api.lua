--[[
    vava_time/server/api.lua
    Rôle : exports serveur pour les autres modules : saison (lue par l'agriculture et la récolte), date du royaume,
           heure du royaume, nuit de gel, ciel ; état et décisions du Conseil depuis le panneau web, par sa seule ressource-pont
           (droit vérifié et journal tenu par le pont auprès de vava_admin).
    Dépendances : shared/, config.lua, server/core.lua, server/clock.lua, server/seasons.lua, server/sky.lua,
                  server/council.lua
]]

local floor, mathType, tointeger = math.floor, math.type, math.tointeger
local time = os.time
local GetInvokingResource = GetInvokingResource

local calendar = VavaTime.calendar
local rules = VavaTime.weatherRules
local clock = VavaTime.clock
local seasons = VavaTime.seasons
local sky = VavaTime.sky
local council = VavaTime.council
local BRIDGE = VavaTime.config.web.bridge

--- Saison du royaume (`printemps`, `ete`, `automne`, `hiver`), ou nil avant le démarrage.
exports('getSeason', function()
    if not VavaTime.ready then return nil end
    return seasons.current().season
end)

--- Date du royaume : { season, label, name, day, year, yearText, text, length }, ou nil. `yearText` (« an 1 du
--- royaume ») et `text` sont écrits par la config (messages.year, messages.dateText) : l'ère n'est écrite qu'à un
--- endroit ; `length` : jours d'une saison en mode cycle (nil au vrai calendrier).
exports('getCalendar', function()
    if not VavaTime.ready then return nil end
    local date = seasons.current()
    local info = calendar.seasonInfo(date.season)
    return {
        season = date.season, label = info.label, name = info.name, day = date.day, year = date.year,
        yearText = calendar.yearText(date.year), text = calendar.dateText(date), length = calendar.seasonLength(),
    }
end)

--- Heure du royaume : { hour, minute, seconds, frozen, shift }, ou nil.
exports('getClock', function()
    if not VavaTime.ready then return nil end
    local seconds = floor(clock.seconds(time()))
    local hour, minute = calendar.hms(seconds)
    local state = clock.state()
    return { hour = hour, minute = minute, seconds = seconds, frozen = state.frozen ~= false, shift = state.shift }
end)

--- Nuit de gel du jour : { tonight, warned, struck, warnHour, hour }, ou nil.
exports('getFrost', function()
    if not VavaTime.ready then return nil end
    return VavaTime.frost.view()
end)

--- Ciel du royaume : { id, label, forced, frozen }, ou nil.
exports('getWeather', function()
    if not VavaTime.ready then return nil end
    local state = sky.state()
    local def = rules.get(state.id)
    return { id = state.id, label = def and def.label or state.id, forced = state.forced, frozen = state.frozen }
end)

-- Panneau web, par sa seule ressource-pont -------------------------------------------------------------------------

---@return boolean
local function fromBridge()
    return GetInvokingResource() == BRIDGE
end

--- Un nombre entier arrivé en décimal par le JSON du panneau (3.0) redevient entier ; le reste est rendu tel quel.
---@param value any
---@return any
local function integral(value)
    if mathType(value) == 'float' then return tointeger(value) or value end
    return value
end

--- Vue de l'outil : true, vue | false, code.
exports('webState', function()
    if not VavaTime.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    return true, council.view()
end)

--- Action sur l'heure (mêmes règles que le RPC) : true, vue, libellé du journal (nil : rien n'a changé), détails |
--- false, code.
exports('webClock', function(action, value)
    if not VavaTime.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    return council.clock(action, integral(value), 'web')
end)

--- Action sur le ciel (mêmes règles que le RPC) : true, vue, libellé du journal, détails | false, code.
exports('webWeather', function(action, weather, hold)
    if not VavaTime.ready then return false, 'not_ready' end
    if not fromBridge() then return false, 'forbidden' end
    return council.weather(action, weather, hold, 'web')
end)
