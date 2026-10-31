--[[
    vava_pause/shared/plaque.lua
    Rôle : logique pure de la plaque du royaume (bas à droite de la bannière), côté client : moment du jour d'après
           l'heure, heure écrite (« Soir, 19 h »), saison, habitants présents (« 28 habitants présents »). Une partie
           impossible à écrire rend nil : la page l'omet avec son losange.
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type

local plaque = {}
VavaPause.plaque = plaque

---@param hour any
---@return boolean
local function isHour(hour)
    return mathType(hour) == 'integer' and hour >= 0 and hour <= 23
end

--- Libellé du moment du jour : dernière période dont le début est atteint (périodes triées par `from`).
---@param hour integer  0 à 23
---@param periods { from: integer, label: string }[]
---@return string|nil
function plaque.period(hour, periods)
    if not isHour(hour) or type(periods) ~= 'table' then return nil end
    local label = nil
    for _, period in ipairs(periods) do
        if hour >= period.from then label = period.label end
    end
    return label
end

--- Heure écrite : `format` reçoit le moment du jour et l'heure (« %s, %d h »).
---@param hour integer
---@param periods table[]
---@param format string
---@return string|nil
function plaque.time(hour, periods, format)
    local label = plaque.period(hour, periods)
    if not label then return nil end
    return format:format(label, hour)
end

--- Libellé de la saison, ou nil (saison inconnue ou absente).
---@param season any
---@param seasons table<string, string>
---@return string|nil
function plaque.season(season, seasons)
    if type(season) ~= 'string' or type(seasons) ~= 'table' then return nil end
    local label = seasons[season]
    return type(label) == 'string' and label or nil
end

--- Habitants présents : `one` pour un, `many` (« %d … ») sinon ; nil si ce n'est pas un entier positif ou nul.
---@param count any
---@param formats { one: string, many: string }
---@return string|nil
function plaque.people(count, formats)
    if mathType(count) ~= 'integer' or count < 0 then return nil end
    if count == 1 then return formats.one end
    return formats.many:format(count)
end
