--[[
    vava_time/shared/weather.lua
    Rôle : règles pures de la météo, partagées par le serveur et le client (application) : définition d'un ciel,
           identifiants des ciels, avancement d'une transition. Le cours des ciels (poids, successeurs, durées) est tiré
           par le seul serveur : shared/cycle.lua. Aucun état.
    Dépendances : shared/constants.lua, config_client.lua (weather.types)
]]

local ipairs, type = ipairs, type

-- ciels de config_client.lua, gardés au chargement : au serveur aussi (avant config.lua), le client et le serveur
-- connaissent les mêmes
local types = VavaTime.config.weather.types

local rules = {}
VavaTime.weatherRules = rules

--- Définition d'un ciel ({ id, gta, label, phrase, snow?, tracks? }), ou nil.
---@param id any
---@param wcfg? table config.weather (essais)
---@return table|nil
function rules.get(id, wcfg)
    for _, def in ipairs(wcfg and wcfg.types or types) do
        if def.id == id then return def end
    end
    return nil
end

--- Identifiants de tous les ciels, dans l'ordre de la config.
---@param wcfg? table
---@return string[]
function rules.ids(wcfg)
    local out = {}
    for index, def in ipairs(wcfg and wcfg.types or types) do out[index] = def.id end
    return out
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
