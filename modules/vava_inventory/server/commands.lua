--[[
    vava_inventory/server/commands.lua
    Rôle : déclaration des touches de l'inventaire (ouverture, ceinture) et de la commande du catalogue de développement
           au registre `core:commands` du core (Codex, suggestions du chat), et liste des catégories d'objets pour le
           formulaire du Codex (export codexList).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/items.lua, client/main.lua (noms des commandes)
]]

local pairs, tostring = pairs, tostring
local format = string.format
local sort = table.sort

local cfg = VavaInventory.config
local items = VavaInventory.items
local ITEMS_REGISTRY = VavaInventory.REGISTRY
local REGISTRY = 'core:commands'
local CHAPTER = 'Inventaire'
-- mêmes noms que client/main.lua (OPEN_COMMAND, SLOT_COMMAND sans son numéro)
local OPEN_COMMAND = 'vava_inventory'
local SLOT_COMMAND = 'vava_inventory_slot'

local commands = {}
VavaInventory.commands = commands

local function entries()
    local list = {
        [OPEN_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.open, label = cfg.labels.open },
        [SLOT_COMMAND] = { kind = 'key', scope = 'player', key = cfg.keys.hotbar[1], keyDisplay = format('%s à %s', cfg.keys.hotbar[1], cfg.keys.hotbar[cfg.hotbarSize]),
            label = format('Raccourcis de la ceinture (%d emplacements)', cfg.hotbarSize) },
    }
    if cfg.catalog.enabled then
        list[cfg.catalog.command] = { kind = 'command', scope = 'admin', permission = cfg.catalog.permission, ace = cfg.catalog.ace, ui = true,
            label = 'Catalogue de développement', description = 'Ouvrir le catalogue de tous les objets connus, par catégorie et par page (serveur de test).',
            args = {
                { name = 'catégorie', type = 'list', list = 'categories', optional = true },
                { name = 'page', type = 'integer', min = 1, max = 999, optional = true },
            } }
    end
    return list
end

--- Déclare les touches et la commande du module. Appelée pendant le setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaInventory.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaInventory.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

--- Listes pour les formulaires du Codex : `categories`, les catégories des objets déclarés.
---@param name string
---@return { value: string, label: string }[]
function commands.list(name)
    local out = {}
    if name ~= 'categories' or not VavaInventory.ready then return out end
    local seen = {}
    for item in pairs(VavaInventory.core.registry.all(ITEMS_REGISTRY) or {}) do
        local def = items.get(item)
        local category = def and def.category
        if category and not seen[category] then
            seen[category] = true
            out[#out + 1] = { value = category, label = category }
        end
    end
    sort(out, function(a, b) return a.value < b.value end)
    return out
end

exports('codexList', function(name) return commands.list(name) end)
