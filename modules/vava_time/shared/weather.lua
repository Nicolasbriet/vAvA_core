--[[
    vava_time/shared/weather.lua
    Rôle : règles pures de la météo, partagées par le serveur (cycle) et le client (application) : définition d'un
           ciel, poids d'un ciel dans une saison (aucune neige hors de l'hiver, ni avec `snow = false`), candidats qui
           peuvent suivre le ciel courant, tirage pondéré avec un aléa fourni par l'appelant (tests déterministes),
           durée d'un ciel, avancement d'une transition. Aucun état.
    Dépendances : shared/constants.lua, config_client.lua (weather)
]]

local ipairs, type = ipairs, type
local floor, max = math.floor, math.max

local cfg = VavaTime.config.weather
-- un ciel dure au moins une minute
local MIN_DURATION = 60

local rules = {}
VavaTime.weatherRules = rules

--- Définition d'un ciel ({ id, gta, label, phrase, snow?, tracks? }), ou nil.
---@param id any
---@param wcfg? table config.weather
---@return table|nil
function rules.get(id, wcfg)
    for _, def in ipairs((wcfg or cfg).types) do
        if def.id == id then return def end
    end
    return nil
end

--- Identifiants de tous les ciels, dans l'ordre de la config.
---@param wcfg? table
---@return string[]
function rules.ids(wcfg)
    local out = {}
    for index, def in ipairs((wcfg or cfg).types) do out[index] = def.id end
    return out
end

--- Poids d'un ciel dans une saison pour le cycle (0 : jamais tiré).
---@param id string
---@param season string|nil
---@param wcfg? table
---@return number
function rules.weight(id, season, wcfg)
    wcfg = wcfg or cfg
    local def = rules.get(id, wcfg)
    if not def or (def.snow and not wcfg.snow) then return 0 end
    local weights = season and wcfg.seasons[season]
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
    wcfg = wcfg or cfg
    local list, total = {}, 0
    local successors = current and wcfg.next[current]
    for _, id in ipairs(successors or {}) do
        local weight = rules.weight(id, season, wcfg)
        if weight > 0 then
            list[#list + 1] = { id = id, weight = weight }
            total = total + weight
        end
    end
    if total > 0 then return list, total end
    list, total = {}, 0
    for _, def in ipairs(wcfg.types) do
        local weight = rules.weight(def.id, season, wcfg)
        if weight > 0 then
            list[#list + 1] = { id = def.id, weight = weight }
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
    wcfg = wcfg or cfg
    local range = (wcfg.durations and wcfg.durations[id]) or wcfg.durationMinutes
    local minutes = range[1] + (range[2] - range[1]) * rnd()
    return max(MIN_DURATION, floor(minutes * 60))
end

--- Avancement d'une transition commencée à `at` et longue de `fade` secondes (0 à 1).
---@param at number
---@param fade number
---@param now number
---@return number
function rules.progress(at, fade, now)
    if type(fade) ~= 'number' or fade <= 0 then return 1 end
    local value = (now - at) / fade
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end
