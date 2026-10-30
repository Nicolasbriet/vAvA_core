--[[
    vava_time/shared/frost.lua
    Rôle : règles pures des nuits de gel : probabilité de gel d'une saison (config), tirage d'une nuit avec un aléa
           fourni par l'appelant (tests déterministes), moments dus à une heure du royaume (avertissement du soir, gel
           de la nuit) sans rejouer ce qui est fait ni ce qui était déjà passé au démarrage. Aucun état : l'appelant
           garde celui de la nuit.
    Dépendances : shared/constants.lua, config.lua
]]

local type = type

local cfg = VavaTime.config.frost

local rules = {}
VavaTime.frostRules = rules

---@class vAvA.FrostNight
---@field frosty boolean  la nuit gèle
---@field warned boolean  avertissement du soir donné (ou passé)
---@field struck boolean  gel tombé (ou passé)

--- Probabilité (0 à 1) qu'une nuit de cette saison gèle ; 0 pour une saison absente ou un réglage invalide.
---@param season string|nil
---@param fcfg? table config.frost
---@return number
function rules.chance(season, fcfg)
    fcfg = fcfg or cfg
    local value = season and fcfg.seasons and fcfg.seasons[season]
    if type(value) ~= 'number' or value ~= value or value <= 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Nouvelle nuit : gèle-t-elle ? (`rnd()` dans [0, 1)). `late` : premier passage après un démarrage, les moments déjà
--- passés à cette heure sont comptés comme faits (rien n'est rejoué, aucun retirage n'en fait tomber un).
---@param season string|nil
---@param hour number heure du royaume (décimale)
---@param late boolean
---@param rnd fun(): number
---@param fcfg? table
---@return vAvA.FrostNight
function rules.night(season, hour, late, rnd, fcfg)
    fcfg = fcfg or cfg
    local chance = rules.chance(season, fcfg)
    return {
        frosty = chance > 0 and rnd() < chance,
        warned = late and hour >= fcfg.warnHour or false,
        struck = late and hour >= fcfg.hour or false,
    }
end

--- Moments dus à cette heure du royaume ; la nuit est marquée en conséquence. Une heure qui saute au-delà du gel
--- (décalage du Conseil) rend les deux moments dus ensemble, l'avertissement d'abord.
---@param night vAvA.FrostNight
---@param hour number
---@param fcfg? table
---@return boolean warn
---@return boolean strike
function rules.due(night, hour, fcfg)
    fcfg = fcfg or cfg
    if not night.frosty then return false, false end
    local warn = not night.warned and hour >= fcfg.warnHour
    local strike = not night.struck and hour >= fcfg.hour
    if warn then night.warned = true end
    if strike then night.struck = true end
    return warn, strike
end
