--[[
    vava_time/shared/cycle.lua
    Rôle : règles pures du cours des ciels, servies au seul serveur (testées hors jeu : tests/spec) : poids d'un ciel
           dans une saison (aucune neige hors de l'hiver, ni avec `snow = false`), candidats qui peuvent suivre le ciel
           courant, tirage pondéré avec un aléa fourni par l'appelant (tests déterministes), durée d'un ciel. Complète
           les règles de shared/weather.lua. Aucun état.
    Dépendances : shared/weather.lua, config.lua (weather.next, seasons, snow, durationMinutes, durations)
]]

local ipairs, type = ipairs, type
local floor, max = math.floor, math.max

local rules = VavaTime.weatherRules
-- cours des ciels de config.lua ; les ciels eux-mêmes sont ceux de shared/weather.lua (config_client.lua)
local cfg = VavaTime.config.weather
-- un ciel dure au moins une minute
local MIN_DURATION = 60
-- clés du cours des ciels et leur type (durations, facultative, n'en est pas)
local COURSE = {
    { 'next', 'table' }, { 'seasons', 'table' }, { 'snow', 'boolean' }, { 'durationMinutes', 'table' },
    { 'fadeSeconds', 'number' },
}

--- Clés du cours des ciels absentes ou d'un autre type (config.lua d'avant 1.5.0 gardé par une mise à jour, avec le
--- config_client.lua de 1.5.0 qui ne les a plus) ; liste vide si tout y est.
---@param wcfg? table config.weather (essais)
---@return string[]
function rules.missingCourse(wcfg)
    local course = wcfg or cfg
    local out = {}
    for _, entry in ipairs(COURSE) do
        if type(course[entry[1]]) ~= entry[2] then out[#out + 1] = entry[1] end
    end
    return out
end

--- Poids d'un ciel dans une saison pour le cycle (0 : jamais tiré).
---@param id string
---@param season string|nil
---@param wcfg? table config.weather (essais)
---@return number
function rules.weight(id, season, wcfg)
    local course = wcfg or cfg
    local def = rules.get(id, wcfg)
    if not def or (def.snow and not course.snow) then return 0 end
    local weights = season and course.seasons[season]
    local weight = weights and weights[id]
    if type(weight) ~= 'number' or weight ~= weight or weight <= 0 then return 0 end
    return weight
end

--- Le cycle peut-il tirer ce ciel dans cette saison ?
---@param id string
---@param season string|nil
---@param wcfg? table
---@return boolean
function rules.allowed(id, season, wcfg)
    return rules.weight(id, season, wcfg) > 0
end

--- Candidats pondérés pour succéder à `current` : ses successeurs de saison, sinon tous les ciels de la saison.
---@param current string|nil
---@param season string|nil
---@param wcfg? table
---@return { id: string, weight: number }[] list
---@return number total
function rules.candidates(current, season, wcfg)
    local list, total = {}, 0
    local successors = current and (wcfg or cfg).next[current]
    for _, id in ipairs(successors or {}) do
        local weight = rules.weight(id, season, wcfg)
        if weight > 0 then
            list[#list + 1] = { id = id, weight = weight }
            total = total + weight
        end
    end
    if total > 0 then return list, total end
    list, total = {}, 0
    for _, id in ipairs(rules.ids(wcfg)) do
        local weight = rules.weight(id, season, wcfg)
        if weight > 0 then
            list[#list + 1] = { id = id, weight = weight }
            total = total + weight
        end
    end
    return list, total
end

--- Ciel qui suit `current` ; `rnd()` rend un nombre dans [0, 1). Nil si aucun ciel n'est de saison.
---@param current string|nil
---@param season string|nil
---@param rnd fun(): number
---@param wcfg? table
---@return string|nil
function rules.pick(current, season, rnd, wcfg)
    local list, total = rules.candidates(current, season, wcfg)
    if total <= 0 then return nil end
    local target = rnd() * total
    for _, entry in ipairs(list) do
        target = target - entry.weight
        if target < 0 then return entry.id end
    end
    return list[#list].id
end

--- Durée d'un ciel (secondes entières, une minute au moins).
---@param id string
---@param rnd fun(): number
---@param wcfg? table
---@return integer
function rules.duration(id, rnd, wcfg)
    local course = wcfg or cfg
    local range = (course.durations and course.durations[id]) or course.durationMinutes
    local minutes = range[1] + (range[2] - range[1]) * rnd()
    return max(MIN_DURATION, floor(minutes * 60))
end
