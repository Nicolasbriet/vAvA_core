--[[
    vava_gathering/server/commands.lua
    Rôle : déclaration des touches de la récolte et de la commande du Conseil (/recolte) au registre `core:commands` du
           core (Codex, suggestions du chat), et listes des zones et des nœuds pour ses formulaires (export codexList).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/catalog.lua, client/main.lua (noms des commandes)
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local format = string.format
local sort = table.sort

local cfg = VavaGathering.config
local catalog = VavaGathering.catalog
local REGISTRY = 'core:commands'
local CHAPTER = 'Récolte'
-- mêmes noms que client/main.lua
local INTERACT_COMMAND = 'vava_gathering_interact'
local ZONES_COMMAND = 'vava_gathering_zones'

local commands = {}
VavaGathering.commands = commands

local function entries()
    local admin = cfg.admin
    local zone = { name = 'zone', type = 'list', list = 'zones' }
    local node = { name = 'nœud', type = 'list', list = 'nodes' }
    return {
        [INTERACT_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.interact, label = cfg.labels.interact, hold = true },
        [ZONES_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.zones, label = cfg.labels.zones },
        [admin.command] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Zones et nœuds de récolte', description = 'État des zones et des nœuds, vitalité forcée, recharge d\'un nœud.',
            actions = {
                { id = 'zones', label = 'État des zones', description = 'Vitalité, bande et cicatrice de chaque zone, dans le chat.' },
                { id = 'zone', label = 'Détail d\'une zone', args = { zone } },
                { id = 'noeud', label = 'Détail d\'un nœud', args = { node } },
                { id = 'vitalite', label = 'Fixer la vitalité d\'une zone', description = '0 marque une cicatrice, 100 remet la zone à neuf.',
                    args = { zone, { name = 'vitalité', type = 'integer', min = 0, max = 100 } } },
                { id = 'recharger', label = 'Recharger un nœud', description = 'Remet toutes les charges du nœud.', args = { node } },
            } },
    }
end

--- Déclare les touches et la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaGathering.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaGathering.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

--- Listes pour les formulaires du Codex : `zones` (id → nom), `nodes` (id → ressource et zone).
---@param name string
---@return { value: string, label: string }[]
function commands.list(name)
    local out = {}
    if name == 'zones' then
        for _, def in ipairs(catalog.zones()) do out[#out + 1] = { value = def.id, label = def.label } end
    elseif name == 'nodes' then
        for _, def in ipairs(catalog.nodes()) do
            local resource, zone = catalog.resource(def.resource), catalog.zone(def.zone)
            out[#out + 1] = { value = def.id, label = format('%s — %s', resource and resource.label or def.resource, zone and zone.label or def.zone) }
        end
    end
    sort(out, function(a, b) return a.label < b.label end)
    return out
end

exports('codexList', function(name) return commands.list(name) end)
