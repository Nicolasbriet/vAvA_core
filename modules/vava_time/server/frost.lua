--[[
    vava_time/server/frost.lua
    Rôle : les nuits de gel tenues par le serveur. Chaque jour du royaume, la nuit est tirée une fois (probabilité de la
           saison, config.frost) ; au soir, puis à la tombée de la nuit (heure du royaume, décalage et gel du Conseil
           compris), les autres modules sont prévenus par des hooks (l'agriculture avertit ses cultivateurs, puis perd
           les cultures ni couvertes ni résistantes). Rien n'est envoyé aux joueurs d'ici : la nuit de gel annoncée (du
           tirage au gel) est un champ de la date du royaume déjà publiée (server/seasons.lua). Au démarrage, ce qui
           est déjà passé dans la journée ne se rejoue pas.
    Dépendances : shared/, config.lua, server/core.lua, server/seasons.lua
]]

local random = math.random

local rules = VavaTime.frostRules
local cfg = VavaTime.config.frost
local HOOKS = VavaTime.HOOKS

local frost = {}
VavaTime.frost = frost

---@type vAvA.FrostNight|nil
local night = nil
local nightKey = nil

--- Passage de la boucle lente.
---@param date vAvA.TimeDate jour du royaume
---@param seconds number seconde du jour de l'heure du royaume
function frost.tick(date, seconds)
    local hour = seconds / 3600
    local key = date.year .. ':' .. date.season .. ':' .. date.day
    if key ~= nightKey then
        local late = night == nil
        nightKey = key
        night = rules.night(date.season, hour, late, random)
        if night.frosty then VavaTime.log.info('la nuit qui vient gèlera (%s)', key) end
    end
    local warn, strike = rules.due(night, hour)
    -- gel annoncé, publié avec la date du royaume (seasons.flush, après le passage) : dès le tirage, jusqu'au gel
    VavaTime.seasons.setFrost(rules.announced(night))
    local payload = { season = date.season, day = date.day, year = date.year, warnHour = cfg.warnHour, hour = cfg.hour }
    local hooks = VavaTime.core.hooks
    if warn then hooks.runAfter(HOOKS.FROST_WARNING, payload) end
    if strike then
        VavaTime.log.info('le gel tombe sur le royaume (%s)', key)
        hooks.runAfter(HOOKS.FROST, payload)
    end
end

--- La nuit en cours : { tonight, warned, struck, warnHour, hour }.
---@return table
function frost.view()
    return {
        tonight = night ~= nil and night.frosty, warned = night ~= nil and night.warned, struck = night ~= nil and night.struck,
        warnHour = cfg.warnHour, hour = cfg.hour,
    }
end
