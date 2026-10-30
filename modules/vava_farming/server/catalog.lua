--[[
    vava_farming/server/catalog.lua
    Rôle : la donnée de l'agriculture indexée depuis la config : cultures (registre `vava_farming:crops`, rempli par la
           config, extensible, cache tenu à jour par les hooks du registre), parcelles et positions de leurs
           emplacements, puits, outils reconnus, objets déclarés à l'inventaire (rappelé quand il redémarre), composteur
           déclaré à l'artisanat. Vérifie la cohérence au démarrage.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format = string.format

local core = VavaFarming.core
local bridge = VavaFarming.bridge
local geometry = VavaFarming.geometry
local cfg = VavaFarming.config
local REGISTRY = VavaFarming.REGISTRY_CROPS
local ID_PATTERN = VavaFarming.ID_PATTERN

local CROP_SCHEMA = {
    type = 'table',
    fields = {
        label = { type = 'string', min = 1, max = 48 },
        family = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN },
        seed = { type = 'string', min = 1, max = 64 },
        product = { type = 'string', min = 1, max = 64 },
        growMinutes = { type = 'number', min = 1, max = 100000 },
        waterPerHour = { type = 'number', min = 0, max = 100 },
        fertilityCost = { type = 'number', min = 0, max = 100 },
        yield = { type = 'array', min = 2, max = 2, items = { type = 'integer', min = 0, max = 1000 } },
        xp = { type = 'integer', min = 0, max = 500 },
        difficulty = { type = 'integer', min = 0, max = 100 },
        stages = { type = 'array', min = 1, max = 8, items = { type = 'string', min = 1, max = 64 } },
        wilted = { type = 'string', min = 1, max = 64 },
        dead = { type = 'string', min = 1, max = 64 },
        frostHardy = { type = 'boolean', optional = true },
    },
}

local catalog = {}
VavaFarming.catalog = catalog

---@class vAvA.ParcelDefinition
---@field id string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field rows integer
---@field cols integer
---@field spacing number
---@field count integer
---@field owner { kind: string, id: integer }|nil
---@field granary { x: number, y: number, z: number, heading: number|nil, label: string, width: integer, height: integer, maxWeight: integer, prop: string }|nil
---@field positions { x: number, y: number, z: number }[]

local parcelsById, parcelsOrdered = {}, {}
local wellsById = {}
local cropsById = nil

local function invalidate(payload)
    if payload.registry == REGISTRY then cropsById = nil end
end

local function rebuildCrops()
    cropsById = {}
    for id, data in pairs(core.registry.all(REGISTRY) or {}) do
        cropsById[id] = {
            id = id, label = data.label, family = data.family, seed = data.seed, product = data.product,
            growMinutes = data.growMinutes, waterPerHour = data.waterPerHour, fertilityCost = data.fertilityCost,
            yield = { data.yield[1], data.yield[2] }, xp = data.xp, difficulty = data.difficulty,
            stages = data.stages, wilted = data.wilted, dead = data.dead, frostHardy = data.frostHardy == true,
        }
    end
end

---@return boolean ok
---@return string|nil err
local function indexParcels()
    for index, parcel in ipairs(cfg.parcels) do
        if type(parcel.id) ~= 'string' or not parcel.id:find(ID_PATTERN) then return false, format('parcelle #%d : identifiant invalide', index) end
        if parcelsById[parcel.id] then return false, format("parcelle '%s' en double", parcel.id) end
        local rows, cols = math.tointeger(parcel.rows), math.tointeger(parcel.cols)
        if not rows or not cols or rows < 1 or cols < 1 or rows * cols > VavaFarming.MAX_SLOTS then
            return false, format("parcelle '%s' : rows × cols entre 1 et %d attendu", parcel.id, VavaFarming.MAX_SLOTS)
        end
        local owner = nil
        if type(parcel.owner) == 'table' then
            if type(parcel.owner.kind) ~= 'string' or math.tointeger(parcel.owner.id) == nil then
                return false, format("parcelle '%s' : owner = { kind, id } attendu", parcel.id)
            end
            owner = { kind = parcel.owner.kind, id = math.tointeger(parcel.owner.id) }
        end
        local def = {
            id = parcel.id, label = parcel.label or parcel.id, x = parcel.x, y = parcel.y, z = parcel.z, heading = parcel.heading or 0.0,
            rows = rows, cols = cols, spacing = parcel.spacing or 1.5, count = rows * cols, owner = owner, positions = {},
        }
        for i = 1, def.count do
            local x, y, z = geometry.slotPosition(def, i)
            def.positions[i] = { x = x, y = y, z = z }
        end
        if type(parcel.granary) == 'table' then
            local g = parcel.granary
            def.granary = {
                x = g.x, y = g.y, z = g.z, heading = g.heading, label = g.label or 'Grenier commun', width = g.width or 10,
                height = g.height or 8, maxWeight = g.maxWeight or 0, prop = g.prop,
            }
        end
        parcelsById[parcel.id] = def
        parcelsOrdered[#parcelsOrdered + 1] = def
    end
    for index, well in ipairs(cfg.wells) do
        if type(well.id) ~= 'string' or not well.id:find(ID_PATTERN) then return false, format('puits #%d : identifiant invalide', index) end
        wellsById[well.id] = { id = well.id, label = well.label or well.id, x = well.x, y = well.y, z = well.z }
    end
    return true
end

function catalog.declareItems()
    for name, def in pairs(cfg.items) do
        local definition = {}
        for key, value in pairs(def) do definition[key] = value end
        definition.image = definition.image or ('nui://' .. VavaFarming.resource .. '/web/items/' .. name .. '.svg')
        bridge.DeclareItem(name, definition)
    end
end

--- Indexe la config, définit le registre des cultures, déclare objets et composteur. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function catalog.define()
    local ok, err = core.registry.define(REGISTRY, { schema = CROP_SCHEMA })
    if not ok then return false, err end
    for id, crop in pairs(cfg.crops) do
        ok, err = core.registry.add(REGISTRY, id, crop)
        if not ok then return false, format("culture '%s' : %s", id, tostring(err)) end
    end
    for _, hook in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
        local id, hookErr = core.hooks.after(hook, invalidate)
        if not id then return false, hookErr end
    end
    ok, err = indexParcels()
    if not ok then return false, err end
    catalog.declareItems()
    ok, err = bridge.DeclareComposter(cfg.composter)
    if not ok then VavaFarming.log.warn('composteur non déclaré à l\'artisanat : %s', tostring(err)) end
    local id
    id, err = core.hooks.after('core:module:ready', function(payload)
        if payload.name == bridge.INVENTORY then catalog.declareItems() end
        if payload.name == bridge.CRAFTING then bridge.DeclareComposter(cfg.composter) end
    end)
    if not id then return false, err end
    for cropId, crop in pairs(catalog.crops()) do
        if not bridge.ItemDefinition(crop.seed) then VavaFarming.log.warn("culture '%s' : graine '%s' inconnue de l'inventaire", cropId, crop.seed) end
        if not bridge.ItemDefinition(crop.product) then VavaFarming.log.warn("culture '%s' : produit '%s' inconnu de l'inventaire", cropId, crop.product) end
    end
    return true
end

---@param id any
---@return table|nil
function catalog.crop(id)
    if type(id) ~= 'string' then return nil end
    if not cropsById then rebuildCrops() end
    return cropsById[id]
end

---@return table<string, table>
function catalog.crops()
    if not cropsById then rebuildCrops() end
    return cropsById
end

--- Culture dont la graine est cet objet, ou nil.
---@param item string
---@return table|nil
function catalog.cropOfSeed(item)
    for _, crop in pairs(catalog.crops()) do
        if crop.seed == item then return crop end
    end
    return nil
end

---@param id any
---@return vAvA.ParcelDefinition|nil
function catalog.parcel(id)
    return type(id) == 'string' and parcelsById[id] or nil
end

---@return vAvA.ParcelDefinition[]
function catalog.parcels()
    return parcelsOrdered
end

---@param id any
---@return table|nil
function catalog.well(id)
    return type(id) == 'string' and wellsById[id] or nil
end

---@param item any
---@return string|nil
function catalog.toolKind(item)
    local tool = type(item) == 'string' and cfg.tools[item]
    return tool and tool.kind or nil
end

---@param item string
---@return string
function catalog.itemLabel(item)
    local def = bridge.ItemDefinition(item)
    if def and def.label then return def.label end
    local own = cfg.items[item]
    return own and own.label or item
end
