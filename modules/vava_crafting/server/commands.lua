--[[
    vava_crafting/server/commands.lua
    Rôle : déclaration de la touche des stations et de la commande du Conseil (/artisanat) au registre `core:commands`
           du core (Codex, suggestions du chat), et liste des stations placées pour ses formulaires (export codexList).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/catalog.lua, client/main.lua (nom de la commande)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format
local sort = table.sort

local cfg = VavaCrafting.config
local catalog = VavaCrafting.catalog
local REGISTRY = 'core:commands'
local CHAPTER = 'Artisanat'
-- même nom que client/main.lua
local INTERACT_COMMAND = 'vava_crafting_interact'

local commands = {}
VavaCrafting.commands = commands

local function entries()
    local admin = cfg.admin
    local station = { name = 'station', type = 'list', list = 'stations' }
    return {
        [INTERACT_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.interact, label = cfg.labels.interact },
        [admin.command] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Stations d\'artisanat', description = 'État des stations, détail d\'une station, combustible forcé.',
            actions = {
                { id = 'stations', label = 'État des stations', description = 'Toutes les stations placées, dans le chat.' },
                { id = 'station', label = 'Détail d\'une station', description = 'État, combustible et recettes de la station.', args = { station } },
                { id = 'carburant', label = 'Fixer le combustible', args = { station, { name = 'combustible', type = 'integer', min = 0, max = 99 } } },
            } },
    }
end

--- Déclare la touche et la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaCrafting.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaCrafting.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

--- Listes pour les formulaires du Codex : `stations`, les stations placées (config et modules).
---@param name string
---@return { value: string, label: string }[]
function commands.list(name)
    local out = {}
    if name == 'stations' then
        for _, def in ipairs(catalog.stations()) do out[#out + 1] = { value = def.id, label = def.label } end
    end
    sort(out, function(a, b) return a.label < b.label end)
    return out
end

exports('codexList', function(name) return commands.list(name) end)
