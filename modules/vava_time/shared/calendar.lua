--[[
    vava_time/shared/calendar.lua
    Rôle : règles pures du temps, partagées par le serveur (décision) et le client (affichage) : dates civiles depuis
           les secondes UTC (sans dépendre du fuseau de la machine), heure de Paris (règle européenne de l'heure d'été :
           du dernier dimanche de mars au dernier dimanche d'octobre, à 01:00 UTC), heure du royaume (décalage, gel),
           saison, jour de la saison et an du royaume (vrai calendrier ou cycle), texte de /date. Aucun état.
    Dépendances : shared/constants.lua, config.lua
]]

local floor, max, ipairs = math.floor, math.max, ipairs

local cfg = VavaTime.config
local DAY = VavaTime.DAY_SECONDS
local HALF_DAY = DAY // 2
local HOUR = 3600
-- 1970-01-01 était un jeudi (0 = dimanche)
local EPOCH_WEEKDAY = 4

local calendar = {}
VavaTime.calendar = calendar

-- Dates civiles (calendrier grégorien proleptique, jours depuis le 1er janvier 1970) -----------------------------------

--- Jours écoulés depuis le 1er janvier 1970 jusqu'à une date.
---@param y integer
---@param m integer 1–12
---@param d integer 1–31
---@return integer
function calendar.daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = y // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12                          -- mars = 0
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

--- Date d'un nombre de jours depuis le 1er janvier 1970.
---@param z integer
---@return integer y, integer m, integer d
function calendar.civilFromDays(z)
    z = z + 719468
    local era = z // 146097
    local doe = z - era * 146097
    local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
    local mp = (5 * doy + 2) // 153
    local d = doy - (153 * mp + 2) // 5 + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end

--- Jour de la semaine (0 = dimanche).
---@param days integer
---@return integer
function calendar.weekday(days)
    return (days + EPOCH_WEEKDAY) % 7
end

--- Quantième du dernier dimanche d'un mois.
---@param y integer
---@param m integer
---@return integer
function calendar.lastSunday(y, m)
    local nextMonth = m == 12 and calendar.daysFromCivil(y + 1, 1, 1) or calendar.daysFromCivil(y, m + 1, 1)
    local last = nextMonth - 1
    local _, _, d = calendar.civilFromDays(last)
    return d - calendar.weekday(last)
end

-- Heure de Paris -------------------------------------------------------------------------------------------------------

--- Écart de Paris sur l'UTC (s) : 7200 à l'heure d'été, 3600 sinon.
---@param utc number secondes UTC
---@return integer
function calendar.parisOffset(utc)
    local y = calendar.civilFromDays(floor(utc) // DAY)
    local summer = calendar.daysFromCivil(y, 3, calendar.lastSunday(y, 3)) * DAY + HOUR
    local winter = calendar.daysFromCivil(y, 10, calendar.lastSunday(y, 10)) * DAY + HOUR
    return (utc >= summer and utc < winter) and 2 * HOUR or HOUR
end

--- Secondes « à l'heure de Paris » (comme si Paris était à l'UTC) : base de l'heure et de la date du royaume.
---@param utc number
---@return number
function calendar.paris(utc)
    return utc + calendar.parisOffset(utc)
end

--- Seconde du jour de l'heure réelle de Paris.
---@param utc number
---@return number
function calendar.realSeconds(utc)
    return calendar.paris(utc) % DAY
end

-- Heure du royaume ----------------------------------------------------------------------------------------------------

---@class vAvA.TimeClockState
---@field shift integer           secondes ajoutées à l'heure de Paris
---@field frozen integer|false|nil seconde du jour figée ; false ou nil : l'heure court

--- Seconde du jour (0 ≤ s < 86400) de l'heure du royaume.
---@param utc number
---@param state vAvA.TimeClockState|nil
---@return number
function calendar.clock(utc, state)
    if state and state.frozen then return state.frozen % DAY end
    return (calendar.paris(utc) + (state and state.shift or 0)) % DAY
end

--- Décalage ramené à −12 h ≤ décalage < +12 h.
---@param shift number
---@return number
function calendar.normalizeShift(shift)
    local value = shift % DAY
    if value >= HALF_DAY then value = value - DAY end
    return value
end

--- Décalage (s, entier) qui donne l'heure voulue maintenant.
---@param utc number
---@param target number seconde du jour voulue
---@return integer
function calendar.shiftFor(utc, target)
    return floor(calendar.normalizeShift(target - calendar.realSeconds(utc)))
end

--- Heures, minutes et secondes d'une seconde du jour.
---@param seconds number
---@return integer hour, integer minute, integer second
function calendar.hms(seconds)
    local s = floor(seconds) % DAY
    return s // HOUR, (s % HOUR) // 60, s % 60
end

--- Moment du jour d'une heure (« le matin »…).
---@param hour integer
---@param moments? table[]
---@return string
function calendar.moment(hour, moments)
    moments = moments or cfg.calendar.moments
    local label = moments[1] and moments[1].label or ''
    for _, moment in ipairs(moments) do
        if hour >= moment.from then label = moment.label end
    end
    return label
end

-- Calendrier du royaume -------------------------------------------------------------------------------------------

---@class vAvA.TimeDate
---@field season string
---@field day integer  jour de la saison (1 = premier)
---@field year integer an du royaume (1 au moins)

--- Saison, jour de la saison et an du royaume d'une date de Paris, au vrai calendrier.
---@param y integer
---@param m integer
---@param d integer
---@param cal? table config.calendar
---@return vAvA.TimeDate
function calendar.realDate(y, m, d, cal)
    cal = cal or cfg.calendar
    local today = calendar.daysFromCivil(y, m, d)
    local bestIndex, bestDays = #cal.starts, nil
    for year = y - 1, y do
        for index, start in ipairs(cal.starts) do
            local days = calendar.daysFromCivil(year, start.month, start.day)
            if days <= today and (not bestDays or days > bestDays) then bestIndex, bestDays = index, days end
        end
    end
    local first = cal.starts[1]
    local yearOfFirst = today >= calendar.daysFromCivil(y, first.month, first.day) and y or y - 1
    return {
        season = cal.starts[bestIndex].season,
        day = today - (bestDays or today) + 1,
        year = max(1, yearOfFirst - cal.firstYear + 1),
    }
end

--- Saison, jour et an en mode cycle : chaque saison dure `cycle.seasonDays` jours réels depuis minuit (Paris) de
--- `cycle.origin`, en commençant par `cycle.first` ; l'an change au retour de la première saison de `starts`.
---@param utc number
---@param cal? table config.calendar
---@return vAvA.TimeDate
function calendar.cycleDate(utc, cal)
    cal = cal or cfg.calendar
    local cycle = cal.cycle
    local count = #cal.starts
    local firstIndex = 1
    for index, start in ipairs(cal.starts) do
        if start.season == cycle.first then firstIndex = index end
    end
    local origin = calendar.daysFromCivil(cycle.origin.year, cycle.origin.month, cycle.origin.day) * DAY
    local elapsed = max(0, calendar.paris(utc) - origin)
    local length = max(1, cycle.seasonDays * DAY)
    local index = floor(elapsed / length)
    local position = firstIndex - 1 + index
    return {
        season = cal.starts[position % count + 1].season,
        day = floor((elapsed - index * length) / DAY) + 1,
        year = position // count + 1,
    }
end

--- Date du royaume d'un instant, selon le mode de la config.
---@param utc number
---@param cal? table config.calendar
---@return vAvA.TimeDate
function calendar.date(utc, cal)
    cal = cal or cfg.calendar
    if cal.mode == 'cycle' then return calendar.cycleDate(utc, cal) end
    local y, m, d = calendar.civilFromDays(floor(calendar.paris(utc)) // DAY)
    return calendar.realDate(y, m, d, cal)
end

--- « 1er », « 2e »…
---@param n integer
---@return string
function calendar.ordinal(n)
    return n == 1 and '1er' or (n .. 'e')
end

--- Libellé et nom d'une saison ; l'identifiant s'il est inconnu.
---@param season string
---@param cal? table
---@return { label: string, name: string }
function calendar.seasonInfo(season, cal)
    cal = cal or cfg.calendar
    return cal.seasons[season] or { label = season, name = season }
end

--- « an 1 du royaume » (config.messages.year : l'ère n'est écrite qu'à cet endroit).
---@param year integer
---@param messages? table config.messages
---@return string
function calendar.yearText(year, messages)
    return (messages or cfg.messages).year:format(year)
end

--- « 39e jour de la saison des brumes (automne), an 1 du royaume », sans l'heure : pour /date et les interfaces.
---@param date vAvA.TimeDate
---@param cal? table config.calendar
---@param messages? table config.messages
---@return string
function calendar.dateText(date, cal, messages)
    messages = messages or cfg.messages
    local info = calendar.seasonInfo(date.season, cal)
    return messages.dateText:format(calendar.ordinal(date.day), info.name, info.label, calendar.yearText(date.year, messages))
end

--- Jours d'une saison en mode cycle (nil au vrai calendrier, où elles n'ont pas toutes la même durée).
---@param cal? table config.calendar
---@return number|nil
function calendar.seasonLength(cal)
    cal = cal or cfg.calendar
    if cal.mode == 'cycle' then return cal.cycle.seasonDays end
    return nil
end

--- Texte de /date : heure, jour, saison, an, moment du jour et ciel ; une phrase de plus si l'heure est figée.
---@param seconds number seconde du jour du royaume
---@param frozen boolean
---@param date vAvA.TimeDate
---@param phrase string ce que fait le ciel (« il pleut »)
---@param cal? table config.calendar
---@param messages? table config.messages
---@return string
function calendar.describe(seconds, frozen, date, phrase, cal, messages)
    cal = cal or cfg.calendar
    messages = messages or cfg.messages
    local hour, minute = calendar.hms(seconds)
    local text = messages.date:format(messages.hour:format(hour, minute), calendar.dateText(date, cal, messages),
        calendar.moment(hour, cal.moments), phrase)
    if frozen then text = text .. ' ' .. messages.frozen end
    return text
end
