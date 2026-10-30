--[[
    vava_time/server/seasons.lua
    Rôle : date du royaume tenue par le serveur (saison, jour de la saison, an), relue par la boucle lente et publiée
           par GlobalState au seul changement : une fois par jour, et les jours où une nuit de gel est annoncée, à son
           annonce et quand elle est tombée (champ `frost`, voir seasons.setFrost) ; hooks au changement de jour et de
           saison. Une publication due est faite par seasons.flush, une fois par passage de la boucle : le changement
           de jour et la nuit de gel tirée au même passage ne font qu'une écriture.
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
-- une nuit de gel est annoncée (tirée, pas encore tombée) : publiée avec la date (`frost = true`, absent sinon)
local frostTonight = false
-- la date publiée n'est plus à jour : seasons.flush la republie
local dirty = false

--- Date du royaume (copie) : { season, day, year }.
---@return vAvA.TimeDate
function seasons.current()
    return { season = current.season, day = current.day, year = current.year }
end

--- Publie la date du royaume : { season, day, year }, plus `frost = true` quand une nuit de gel est annoncée.
function seasons.publish()
    local date = seasons.current()
    if frostTonight then date.frost = true end
    dirty = false
    GlobalState[KEY] = date -- audit: ok (date du royaume : ~50 o, une fois par jour, plus le gel annoncé puis tombé)
end

--- Republie la date si elle a changé depuis la dernière publication (après chaque passage de la boucle).
function seasons.flush()
    if dirty then seasons.publish() end
end

--- Nuit de gel annoncée (true : tirée et pas encore tombée) ; publiée au prochain seasons.flush si elle change.
---@param announced boolean
function seasons.setFrost(announced)
    announced = announced == true
    if announced == frostTonight then return end
    frostTonight = announced
    dirty = true
end

--- Relit la date ; au changement, la marque à publier (seasons.flush) et prévient les autres modules (sauf à la
--- première lecture).
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
    dirty = true
    local hooks = VavaTime.core.hooks
    hooks.runAfter(HOOKS.DAY, { season = date.season, day = date.day, year = date.year })
    if previous.season == date.season then return false end
    VavaTime.log.info('le royaume entre dans la %s', calendar.seasonInfo(date.season).name)
    hooks.runAfter(HOOKS.SEASON, { season = date.season, previous = previous.season, day = date.day, year = date.year })
    return true
end
