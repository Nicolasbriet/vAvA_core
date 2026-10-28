--[[
    vava_farming/server/commands.lua
    Rôle : déclaration de la touche des parcelles et de la commande du Conseil (/agriculture) au registre `core:commands`
           du core (Codex, suggestions du chat), et liste des parcelles pour ses formulaires (export codexList).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/catalog.lua, client/main.lua (nom de la commande)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format
local sort = table.sort

local cfg = VavaFarming.config
local catalog = VavaFarming.catalog
local REGISTRY = 'core:commands'
local CHAPTER = 'Agriculture'
-- même nom que client/main.lua
local INTERACT_COMMAND = 'vava_farming_interact'

local commands = {}
VavaFarming.commands = commands

local function entries()
    local admin = cfg.admin
    local parcel = { name = 'parcelle', type = 'list', list = 'parcels' }
    local slot = { name = 'emplacement', type = 'integer', min = 1, max = 64, hint = 'numéro de l\'emplacement dans la parcelle' }
    return {
        [INTERACT_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.interact, label = cfg.labels.interact },
        [admin.command] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Parcelles agricoles', description = 'État des parcelles, fertilité forcée, croissance et arrosage immédiats.',
            actions = {
                { id = 'parcelles', label = 'État des parcelles', description = 'Toutes les parcelles et leurs emplacements occupés, dans le chat.' },
                { id = 'parcelle', label = 'Détail d\'une parcelle', args = { parcel } },
                { id = 'fertilite', label = 'Fixer la fertilité d\'un emplacement', args = { parcel, slot, { name = 'fertilité', type = 'integer', min = 0, max = 100 } } },
                { id = 'pousser', label = 'Faire mûrir un emplacement', description = 'Porte la plante à maturité sur-le-champ.', args = { parcel, slot } },
                { id = 'arroser', label = 'Arroser toute la parcelle', args = { parcel } },
            } },
    }
end

--- Déclare la touche et la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaFarming.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaFarming.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

--- Listes pour les formulaires du Codex : `parcels`, les parcelles de la config.
---@param name string
---@return { value: string, label: string }[]
function commands.list(name)
    local out = {}
    if name == 'parcels' then
        for _, def in ipairs(catalog.parcels()) do out[#out + 1] = { value = def.id, label = def.label } end
    end
    sort(out, function(a, b) return a.label < b.label end)
    return out
end

exports('codexList', function(name) return commands.list(name) end)
