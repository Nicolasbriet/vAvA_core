--[[
    vava_time/server/seasons.lua
    Rôle : date du royaume tenue par le serveur (saison, jour de la saison, an), relue par la boucle lente et publiée
           par GlobalState au seul changement (une fois par jour) ; hooks au changement de jour et de saison.
    Dépendances : shared/, config.lua, server/core.lua
]]

local GlobalState = GlobalState

local calendar = VavaTime.calendar
local KEY = VavaTime.STATE.CALENDAR
local HOOKS = VavaTime.HOOKS

local seasons = {}
VavaTime.seasons = seasons

---@type vAvA.TimeDate|nil
local current = nil

--- Date du royaume (copie) : { season, day, year }.
---@return vAvA.TimeDate
function seasons.current()
    return { season = current.season, day = current.day, year = current.year }
end

function seasons.publish()
    GlobalState[KEY] = seasons.current() -- audit: ok (date du royaume : petite, une fois par jour, utile à tous)
end

--- Relit la date ; au changement, la publie et prévient les autres modules (sauf à la première lecture).
---@param now integer secondes UTC
---@return boolean seasonChanged
function seasons.refresh(now)
    local date = calendar.date(now)
    local previous = current
    if previous and previous.season == date.season and previous.day == date.day and previous.year == date.year then
        return false
    end
    current = date
    if not previous then return false end
    seasons.publish()
    local hooks = VavaTime.core.hooks
    hooks.runAfter(HOOKS.DAY, { season = date.season, day = date.day, year = date.year })
    if previous.season == date.season then return false end
    VavaTime.log.info('le royaume entre dans la %s', calendar.seasonInfo(date.season).name)
    hooks.runAfter(HOOKS.SEASON, { season = date.season, previous = previous.season, day = date.day, year = date.year })
    return true
end
