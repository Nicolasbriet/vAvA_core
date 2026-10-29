--[[
    vava_gathering/server/catalog.lua
    Rôle : la donnée de la récolte indexée depuis la config : zones, nœuds (par identifiant et par zone), ressources,
           outils (registre du core `vava_gathering:tools`, rempli par la config, extensible par d'autres modules,
           cache tenu à jour par les hooks du registre), objets déclarés à l'inventaire (rappelé quand l'inventaire
           redémarre). Vérifie la cohérence de la config au démarrage : une erreur de donnée refuse le module.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format = string.format

local core = VavaGathering.core
local bridge = VavaGathering.bridge
local cfg = VavaGathering.config
local REGISTRY = VavaGathering.REGISTRY_TOOLS
local ID_PATTERN = VavaGathering.ID_PATTERN

local TOOL_SCHEMA = {
    type = 'table',
    fields = {
        kind = { type = 'string', min = 1, max = 32, pattern = ID_PATTERN },
        power = { type = 'number', min = 0.1, max = 5 },
        yieldBonus = { type = 'integer', min = 0, max = 10, optional = true },
        qualityBonus = { type = 'integer', min = -50, max = 50, optional = true },
        wear = { type = 'integer', min = 0, max = 100, optional = true },
    },
}

local catalog = {}
VavaGathering.catalog = catalog

---@class vAvA.ZoneDefinition
---@field id string
---@field label string
---@field kind string
---@field x number
---@field y number
---@field z number
---@field radius number
---@field cost number
---@field regenPerHour number
---@field scarHours number

---@class vAvA.NodeDefinition
---@field id string
---@field zone vAvA.ZoneDefinition
---@field resource vAvA.ResourceDefinition
---@field x number
---@field y number
---@field z number
---@field charges integer
---@field regenMs integer

---@class vAvA.ResourceDefinition
---@field id string
---@field label string
---@field item string
---@field skill string
---@field tool string|nil
---@field difficulty integer
---@field xp integer
---@field yield integer[]
---@field durationMs integer
---@field anim string
---@field fishing boolean
---@field extra { item: string, chance: number }|nil

---@class vAvA.ToolDefinition
---@field item string
---@field kind string
---@field power number
---@field yieldBonus integer
---@field qualityBonus integer
---@field wear integer

local zonesById, zonesOrdered = {}, {}
local nodesById, nodesByZone = {}, {}
local resourcesById = {}
-- cache des outils (objet → définition), reconstruit après un changement du registre
local toolsByItem = nil

local function invalidate(payload)
    if payload.registry == REGISTRY then toolsByItem = nil end
end

local function rebuildTools()
    toolsByItem = {}
    for item, data in pairs(core.registry.all(REGISTRY) or {}) do
        toolsByItem[item] = {
            item = item, kind = data.kind, power = data.power,
            yieldBonus = data.yieldBonus or 0, qualityBonus = data.qualityBonus or 0, wear = data.wear or 0,
        }
    end
end

--- Indexe et vérifie la config. Renvoie une erreur explicite à la première incohérence.
---@return boolean ok
---@return string|nil err
local function index()
    for id, def in pairs(cfg.resources) do
        if type(id) ~= 'string' or not id:find(ID_PATTERN) then return false, format("ressource '%s' : identifiant invalide", tostring(id)) end
        if type(def.item) ~= 'string' or type(def.skill) ~= 'string' then return false, format("ressource '%s' : item et skill requis", id) end
        if type(def.yield) ~= 'table' or type(def.yield[1]) ~= 'number' or type(def.yield[2]) ~= 'number' or def.yield[1] > def.yield[2] then
            return false, format("ressource '%s' : yield = { min, max } attendu", id)
        end
        if not cfg.anims[def.anim] then return false, format("ressource '%s' : animation '%s' inconnue", id, tostring(def.anim)) end
        resourcesById[id] = {
            id = id, label = def.label or id, item = def.item, skill = def.skill, tool = def.tool, difficulty = def.difficulty or 0,
            xp = def.xp or 0, yield = { def.yield[1], def.yield[2] }, durationMs = def.durationMs or 0, anim = def.anim,
            fishing = def.fishing == true, extra = def.extra,
        }
    end
    for i, zone in ipairs(cfg.zones) do
        if type(zone.id) ~= 'string' or not zone.id:find(ID_PATTERN) then return false, format('zone #%d : identifiant invalide', i) end
        if zonesById[zone.id] then return false, format("zone '%s' en double", zone.id) end
        local def = {
            id = zone.id, label = zone.label or zone.id, kind = zone.kind or 'foret', x = zone.x, y = zone.y, z = zone.z,
            radius = zone.radius or 50.0, cost = zone.cost or 1.0, regenPerHour = zone.regenPerHour or 1.0, scarHours = zone.scarHours or 24,
        }
        zonesById[zone.id] = def
        zonesOrdered[#zonesOrdered + 1] = def
        nodesByZone[zone.id] = {}
    end
    for i, node in ipairs(cfg.nodes) do
        if type(node.id) ~= 'string' or not node.id:find(ID_PATTERN) then return false, format('nœud #%d : identifiant invalide', i) end
        if nodesById[node.id] then return false, format("nœud '%s' en double", node.id) end
        local zone = zonesById[node.zone]
        if not zone then return false, format("nœud '%s' : zone '%s' inconnue", node.id, tostring(node.zone)) end
        local resource = resourcesById[node.resource]
        if not resource then return false, format("nœud '%s' : ressource '%s' inconnue", node.id, tostring(node.resource)) end
        if type(node.charges) ~= 'number' or node.charges < 1 then return false, format("nœud '%s' : charges ≥ 1 attendu", node.id) end
        if type(node.prop) ~= 'table' or type(node.prop.model) ~= 'string' then return false, format("nœud '%s' : prop.model requis", node.id) end
        local def = {
            id = node.id, zone = zone, resource = resource, x = node.x, y = node.y, z = node.z,
            charges = math.tointeger(node.charges) or 1, regenMs = node.regenMs or 600000,
        }
        nodesById[node.id] = def
        local list = nodesByZone[zone.id]
        list[#list + 1] = def
    end
    return true
end

--- Déclare les objets de la config à l'inventaire (ceux qu'il ne connaît pas encore).
function catalog.declareItems()
    for name, def in pairs(cfg.items) do
        local definition = {}
        for key, value in pairs(def) do definition[key] = value end
        definition.image = definition.image or ('nui://' .. VavaGathering.resource .. '/web/items/' .. name .. '.svg')
        bridge.DeclareItem(name, definition)
    end
end

--- Indexe la config, définit le registre des outils et y verse ceux de la config, déclare les objets, vérifie que
--- chaque ressource produit un objet connu. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function catalog.define()
    local ok, err = index()
    if not ok then return false, err end
    ok, err = core.registry.define(REGISTRY, { schema = TOOL_SCHEMA })
    if not ok then return false, err end
    for item, tool in pairs(cfg.tools) do
        ok, err = core.registry.add(REGISTRY, item, { kind = tool.kind, power = tool.power, yieldBonus = tool.yieldBonus, qualityBonus = tool.qualityBonus, wear = tool.wear })
        if not ok then return false, format("outil '%s' : %s", item, tostring(err)) end
    end
    for _, hook in ipairs({ 'core:registry:added', 'core:registry:removed', 'core:registry:dropped' }) do
        local id, hookErr = core.hooks.after(hook, invalidate)
        if not id then return false, hookErr end
    end
    catalog.declareItems()
    -- l'inventaire redémarré a perdu nos objets : les redéclarer
    local id
    id, err = core.hooks.after('core:module:ready', function(payload)
        if payload.name == bridge.INVENTORY then catalog.declareItems() end
    end)
    if not id then return false, err end
    for _, resource in pairs(resourcesById) do
        if not bridge.ItemExists(resource.item) then
            VavaGathering.log.warn("ressource '%s' : l'objet '%s' n'est connu d'aucun module", resource.id, resource.item)
        end
        if resource.extra and not bridge.ItemExists(resource.extra.item) then
            VavaGathering.log.warn("ressource '%s' : l'objet '%s' (extra) n'est connu d'aucun module", resource.id, resource.extra.item)
        end
    end
    return true
end

---@param id any
---@return vAvA.ZoneDefinition|nil
function catalog.zone(id)
    return type(id) == 'string' and zonesById[id] or nil
end

--- Zones dans l'ordre de la config.
---@return vAvA.ZoneDefinition[]
function catalog.zones()
    return zonesOrdered
end

---@param id any
---@return vAvA.NodeDefinition|nil
function catalog.node(id)
    return type(id) == 'string' and nodesById[id] or nil
end

---@return table<string, vAvA.NodeDefinition>
function catalog.nodes()
    return nodesById
end

---@param zoneId string
---@return vAvA.NodeDefinition[]
function catalog.nodesOf(zoneId)
    return nodesByZone[zoneId] or {}
end

---@param id any
---@return vAvA.ResourceDefinition|nil
function catalog.resource(id)
    return type(id) == 'string' and resourcesById[id] or nil
end

---@param item any
---@return vAvA.ToolDefinition|nil
function catalog.tool(item)
    if type(item) ~= 'string' then return nil end
    if not toolsByItem then rebuildTools() end
    return toolsByItem[item]
end

--- Libellé d'un objet déclaré par ce module (son nom sinon).
---@param item string
---@return string
function catalog.itemLabel(item)
    local def = cfg.items[item]
    return def and def.label or item
end
