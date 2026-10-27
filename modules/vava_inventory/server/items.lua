--[[
    vava_inventory/server/items.lua
    Rôle : définitions d'objets. Le registre vava_inventory:items vit dans le core (validation, purge à l'arrêt du
           module déclarant, hooks) ; ce fichier le définit et garde un cache local, tenu à jour par les hooks du
           registre : une opération ne paie pas un appel inter-ressources par lecture.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type = type

local cfg = VavaInventory.config
local REGISTRY = VavaInventory.REGISTRY

local items = {}
VavaInventory.items = items

---@class vAvA.ItemDefinition
---@field label string
---@field description? string
---@field width integer
---@field height integer
---@field weight integer      grammes par unité
---@field stack integer       quantité maximale par pile (1 = non empilable)
---@field image? string       chemin NUI (nui://ressource/chemin) servi par le module déclarant
---@field category? string
---@field effects? table<string, number>  effets lus par d'autres modules à l'utilisation (faim, soif…) ; une unité consommée
---@field onUse? fun(source: integer, item: table): boolean?, string?  true = une unité consommée ; message optionnel

local SIZE = { type = 'integer', min = 1, max = cfg.maxItemSize }
local EFFECT = cfg.effects

local SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 48 },
        description = { type = 'string', max = 300, optional = true },
        width = SIZE,
        height = SIZE,
        weight = { type = 'integer', min = 0, max = VavaInventory.MAX_QUANTITY },
        stack = { type = 'integer', min = 1, max = VavaInventory.MAX_QUANTITY },
        image = { type = 'string', max = 200, optional = true },
        category = { type = 'string', max = 32, optional = true },
        effects = {
            type = 'map', min = 1, max = EFFECT.maxEntries, optional = true,
            key = { type = 'string', min = 1, max = 32, pattern = '^[%a_][%w_]*$' },
            value = { type = 'number', min = -EFFECT.maxValue, max = EFFECT.maxValue },
        },
        onUse = { type = 'function', optional = true },
    },
}

-- nom → définition, ou false si inconnu ; vidé pour un nom à chaque ajout ou retrait dans le registre
local cache = {}

local function invalidate(payload)
    if payload.registry == REGISTRY then cache[payload.key] = nil end
end

--- Définit le registre et branche l'invalidation du cache. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function items.define()
    local core = VavaInventory.core
    local ok, err = core.registry.define(REGISTRY, { schema = SCHEMA })
    if not ok then return false, err end
    core.hooks.after('core:registry:added', invalidate)
    core.hooks.after('core:registry:removed', invalidate)
    return true
end

---@param name string
---@return vAvA.ItemDefinition|nil
function items.get(name)
    local def = cache[name]
    if def == nil then
        def = (type(name) == 'string' and VavaInventory.core.registry.get(REGISTRY, name)) or false
        cache[name] = def
    end
    return def or nil
end

--- Un objet s'utilise s'il a une fonction d'utilisation ou des effets.
---@param def vAvA.ItemDefinition
---@return boolean
function items.isUsable(def)
    return def.onUse ~= nil or def.effects ~= nil
end

--- Définition transmissible au client (sans la fonction d'utilisation).
---@param name string
---@return table|nil
function items.public(name)
    local def = items.get(name)
    if not def then return nil end
    return {
        label = def.label, description = def.description, width = def.width, height = def.height,
        weight = def.weight, stack = def.stack, image = def.image, category = def.category,
        effects = def.effects, usable = items.isUsable(def),
    }
end
