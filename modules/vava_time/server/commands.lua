--[[
    vava_time/server/commands.lua
    Rôle : déclaration des commandes du module au registre `core:commands` du core (Codex, suggestions du chat) :
           /date pour tout le monde, /ciel et ses sous-commandes pour le Conseil. Les commandes elles-mêmes sont
           enregistrées côté client (client/main.lua) : /date se lit sans réseau, /ciel passe par les RPC gardés.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format

local cfg = VavaTime.config
local REGISTRY = 'core:commands'
local CHAPTER = 'Ciel et heure'

local commands = {}
VavaTime.commands = commands

local function entries()
    local choices, labels = {}, {}
    for index, def in ipairs(cfg.weather.types) do
        choices[index] = def.id
        labels[def.id] = def.label
    end
    local maxHours = cfg.clock.maxShiftMinutes // 60
    return {
        [cfg.commands.date] = { kind = 'command', scope = 'player', label = 'Date et heure du royaume',
            description = 'L\'heure, le jour, la saison et le ciel du royaume, en quelques mots.' },
        [cfg.commands.council] = { kind = 'command', scope = 'admin', permission = cfg.council.permission, ui = true,
            label = cfg.tool.label,
            description = 'Décaler ou figer l\'heure du royaume, imposer un ciel, rendre la main à l\'heure réelle et au cycle.',
            actions = {
                { label = 'Ouvrir « Ciel et heure »', description = 'L\'outil du Conseil, comme depuis le Registre.' },
                { id = 'heure', label = 'Mettre l\'heure', description = 'L\'heure du royaume repart de là, au rythme réel (ou reste figée).',
                    args = { { name = 'heures', type = 'integer', min = 0, max = 23 }, { name = 'minutes', type = 'integer', min = 0, max = 59, optional = true } } },
                { id = 'decaler', label = 'Décaler l\'heure', description = 'Avance ou recule l\'heure du royaume.',
                    args = { { name = 'heures', type = 'integer', min = -maxHours, max = maxHours } } },
                { id = 'figer', label = 'Figer l\'heure' },
                { id = 'reprendre', label = 'Laisser le temps reprendre', description = 'L\'heure repart de là où elle était figée.' },
                { id = 'reelle', label = 'Rendre l\'heure réelle', description = 'Heure de Paris, sans décalage ni gel.' },
                { id = 'meteo', label = 'Imposer un ciel', description = 'Le ciel change en quelques secondes ; « figer » l\'y garde.',
                    args = { { name = 'ciel', type = 'choice', choices = choices, labels = labels },
                        { name = 'figer', type = 'choice', choices = { 'figer' }, labels = { figer = 'le figer' }, optional = true } } },
                { id = 'garder', label = 'Figer le ciel', description = 'Le ciel actuel ne change plus.' },
                { id = 'cycle', label = 'Rendre le ciel au cycle', description = 'Le ciel reprend son cours selon la saison.' },
            } },
    }
end

--- Déclare les commandes du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaTime.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaTime.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end
