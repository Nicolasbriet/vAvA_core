--[[
    vava_provisions/server/commands.lua
    Rôle : déclaration de la touche des points d'eau et de la commande du Conseil (/eau) au registre `core:commands` du
           core (Codex, suggestions du chat ; chapitre « Vivres »), et liste des points d'eau pour ses formulaires
           (export codexList).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/points.lua, client/main.lua (nom de la touche)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format
local sort = table.sort

local cfg = VavaProvisions.config
local points = VavaProvisions.points
local REGISTRY = 'core:commands'
local CHAPTER = 'Vivres'
-- même nom que client/main.lua
local INTERACT_COMMAND = 'vava_provisions_interact'

local commands = {}
VavaProvisions.commands = commands

local function entries()
    local admin = cfg.admin
    return {
        [INTERACT_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.interact, label = cfg.labels.interact },
        [admin.command] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Points d\'eau', description = 'Puits, fontaines et sources du royaume, et ce qui reste à y puiser.',
            actions = {
                { id = 'points', label = 'État des points d\'eau', description = 'Chaque point, sa sorte et sa réserve, dans le chat.' },
                { id = 'reserve', label = 'Régler une réserve', description = 'Fixe ce qu\'on peut encore puiser à un puits ou une source.',
                    args = { { name = 'point', type = 'list', list = 'points' }, { name = 'réserve', type = 'integer', min = 0, max = 1000 } } },
            } },
    }
end

--- Déclare la touche et la commande du module. Appelée en tête du setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaProvisions.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaProvisions.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

--- Listes pour les formulaires du Codex : `points`, les points d'eau, triés par nom.
---@param name string
---@return { value: string, label: string }[]
function commands.list(name)
    local out = {}
    if name == 'points' then
        for _, point in ipairs(points.list()) do out[#out + 1] = { value = point.id, label = point.label } end
    end
    sort(out, function(a, b) return a.label < b.label end)
    return out
end

exports('codexList', function(name) return commands.list(name) end)
