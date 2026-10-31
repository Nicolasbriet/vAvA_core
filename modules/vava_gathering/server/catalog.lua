--[[
    vava_gathering/server/catalog.lua
    Rôle : la donnée de la récolte en mémoire : zones, nœuds (par identifiant et par zone), ressources (part client de
           config_client.lua et part serveur `resourceStats` de config.lua, fusionnées), outils (genre de
           config_client.lua et `toolStats` de config.lua, versés au registre du core `vava_gathering:tools`,
           extensible par d'autres modules, cache tenu à jour par les hooks du registre), objets déclarés à
           l'inventaire (rappelé quand l'inventaire redémarre). Vérifie la cohérence de la config au démarrage : une
           erreur de donnée refuse le module (zone qui dépasserait les bornes d'une zone du core comprise : rayon,
           marge, nombre de nœuds ; ressource sans modèle ; parts client et serveur qui ne portent pas les mêmes
           identifiants).
           T-102 : le catalogue est MUTABLE. La config est la graine (gardée telle quelle pour le retour à l'original de
           l'Atelier) ; l'Atelier y pose ou retire une zone, un nœud (`putZone`, `dropZone`, `putNode`, `dropNode`,
           tout ou rien : un refus ne change rien) ; les définitions sont mises à jour sur place (les nœuds gardent leur
           zone). Ordre des zones : celui de la graine, puis de création.
    Dépendances : shared/constants.lua, config.lua, shared/zonestate.lua, server/core.lua, bridge/server.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local format = string.format
local tointeger = math.tointeger

local core = VavaGathering.core
local bridge = VavaGathering.bridge
local cfg = VavaGathering.config
local REGISTRY = VavaGathering.REGISTRY_TOOLS
local ID_PATTERN = VavaGathering.ID_PATTERN
local MAX_ZONE_ID, MAX_NODE_ID = VavaGathering.MAX_ZONE_ID, VavaGathering.MAX_NODE_ID
local ZONE_MAX_RADIUS, ZONE_MAX_MARGIN = VavaGathering.ZONE_MAX_RADIUS, VavaGathering.ZONE_MAX_MARGIN
local zonestate = VavaGathering.zonestate

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
---@field label string
---@field zone vAvA.ZoneDefinition
---@field resource vAvA.ResourceDefinition
---@field x number
---@field y number
---@field z number
---@field heading number
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
---@field prop { model: string, depleted: string }

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

--- Marge d'une zone du core : portée des props + jeu de l'abonnement.
local function margin()
    return cfg.streaming.radius + cfg.streaming.subscribeSlack
end

--- Ressources : part client et part serveur fusionnées, mêmes identifiants des deux côtés.
local function indexResources()
    local stats = cfg.resourceStats or {}
    for id in pairs(stats) do
        if not cfg.resources[id] then
            return false, format("ressource '%s' : dans resourceStats (config.lua), absente de resources (config_client.lua)", tostring(id))
        end
    end
    for id, def in pairs(cfg.resources) do
        if type(id) ~= 'string' or not id:find(ID_PATTERN) then return false, format("ressource '%s' : identifiant invalide", tostring(id)) end
        local stat = stats[id]
        if type(stat) ~= 'table' then return false, format("ressource '%s' : absente de resourceStats (config.lua)", id) end
        if type(stat.item) ~= 'string' or type(stat.skill) ~= 'string' then return false, format("ressource '%s' : item et skill requis", id) end
        if type(stat.yield) ~= 'table' or type(stat.yield[1]) ~= 'number' or type(stat.yield[2]) ~= 'number' or stat.yield[1] > stat.yield[2] then
            return false, format("ressource '%s' : yield = { min, max } attendu", id)
        end
        if not cfg.anims[def.anim] then return false, format("ressource '%s' : animation '%s' inconnue", id, tostring(def.anim)) end
        if type(def.prop) ~= 'table' or type(def.prop.model) ~= 'string' or def.prop.model == '' then
            return false, format("ressource '%s' : prop.model requis (config_client.lua)", id)
        end
        resourcesById[id] = {
            id = id, label = def.label or id, item = stat.item, skill = stat.skill, tool = def.tool, difficulty = stat.difficulty or 0,
            xp = stat.xp or 0, yield = { stat.yield[1], stat.yield[2] }, durationMs = stat.durationMs or 0, anim = def.anim,
            fishing = stat.fishing == true, extra = stat.extra,
            prop = { model = def.prop.model, depleted = def.prop.depleted or def.prop.model },
        }
    end
    return true
end

--- Zone contrôlée et normalisée (graine ou Atelier) : définition neuve, ou nil et une raison.
---@param zone table
---@return vAvA.ZoneDefinition|nil
---@return string|nil err
local function checkZone(zone)
    if type(zone.id) ~= 'string' or not zone.id:find(ID_PATTERN) or #zone.id > MAX_ZONE_ID then
        return nil, format('identifiant invalide (%d octets au plus)', MAX_ZONE_ID)
    end
    for _, key in ipairs({ 'x', 'y', 'z' }) do
        if type(zone[key]) ~= 'number' or zone[key] ~= zone[key] then return nil, format("zone '%s' : x, y, z requis", zone.id) end
    end
    local radius = zone.radius or 50.0
    if type(radius) ~= 'number' or radius <= 0 or radius > ZONE_MAX_RADIUS then
        return nil, format("zone '%s' : rayon de plus de 0 à %.0f m", zone.id, ZONE_MAX_RADIUS)
    end
    return {
        id = zone.id, label = zone.label or zone.id, kind = zone.kind or 'foret', x = zone.x, y = zone.y, z = zone.z,
        radius = radius, cost = zone.cost or 1.0, regenPerHour = zone.regenPerHour or 1.0, scarHours = zone.scarHours or 24,
    }
end

--- Nœud contrôlé (graine ou Atelier) : définition neuve (zone et ressource résolues), ou nil et une raison.
---@param node table  { id, label?, zone, resource, x, y, z, heading?, charges, regenMs? }
---@return vAvA.NodeDefinition|nil
---@return string|nil err
local function checkNode(node)
    if type(node.id) ~= 'string' or not node.id:find(ID_PATTERN) or #node.id > MAX_NODE_ID then
        return nil, format('identifiant invalide (%d octets au plus)', MAX_NODE_ID)
    end
    local zone = zonesById[node.zone]
    if not zone then return nil, format("nœud '%s' : zone '%s' inconnue", node.id, tostring(node.zone)) end
    local resource = resourcesById[node.resource]
    if not resource then return nil, format("nœud '%s' : ressource '%s' inconnue", node.id, tostring(node.resource)) end
    if type(node.charges) ~= 'number' or node.charges < 1 then return nil, format("nœud '%s' : charges ≥ 1 attendu", node.id) end
    for _, key in ipairs({ 'x', 'y', 'z' }) do
        if type(node[key]) ~= 'number' or node[key] ~= node[key] then return nil, format("nœud '%s' : x, y, z requis", node.id) end
    end
    return {
        id = node.id, label = node.label or node.id, zone = zone, resource = resource, x = node.x, y = node.y, z = node.z,
        heading = node.heading or 0.0, charges = tointeger(node.charges) or 1, regenMs = node.regenMs or 600000,
    }
end

--- Bornes d'une zone du core pour une zone et ses nœuds : nombre de nœuds, cercle englobant.
local function checkBounds(def, list)
    if #list > VavaGathering.ZONE_MAX_NODES then
        return false, format("zone '%s' : %d nœuds, %d au plus (clés de l'état d'une zone du core)", def.id, #list, VavaGathering.ZONE_MAX_NODES)
    end
    local area = zonestate.area(def, list, margin())
    if area.radius > ZONE_MAX_RADIUS then
        return false, format("zone '%s' : rayon de %.0f m (nœuds compris), %.0f m au plus (rayon d'une zone du core)", def.id, area.radius, ZONE_MAX_RADIUS)
    end
    return true
end

--- Copie d'une table de définition (mise à jour sur place, les nœuds gardant leur zone).
local function assign(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
    return target
end

--- Indexe et vérifie la config (graine). Renvoie une erreur explicite à la première incohérence.
---@return boolean ok
---@return string|nil err
local function index()
    local ok, err = indexResources()
    if not ok then return false, err end
    for i, zone in ipairs(cfg.zones) do
        local def
        def, err = checkZone(zone)
        if not def then return false, format('zone #%d : %s', i, err) end
        if zonesById[def.id] then return false, format("zone '%s' en double", def.id) end
        zonesById[def.id] = def
        zonesOrdered[#zonesOrdered + 1] = def
        nodesByZone[def.id] = {}
    end
    for i, node in ipairs(cfg.nodes) do
        local def
        def, err = checkNode(node)
        if not def then return false, format('nœud #%d : %s', i, err) end
        if nodesById[def.id] then return false, format("nœud '%s' en double", def.id) end
        nodesById[def.id] = def
        local list = nodesByZone[def.zone.id]
        list[#list + 1] = def
    end
    -- chaque zone de récolte devient une zone du core : ses bornes sont vérifiées ici, le core la refuserait sinon
    if margin() > ZONE_MAX_MARGIN then
        return false, format("streaming.radius + streaming.subscribeSlack : %.0f m, %.0f m au plus (marge d'une zone du core)", margin(), ZONE_MAX_MARGIN)
    end
    for _, def in ipairs(zonesOrdered) do
        ok, err = checkBounds(def, nodesByZone[def.id])
        if not ok then return false, err end
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

--- Outils : genre (config_client.lua) et part serveur (`toolStats`), mêmes objets des deux côtés.
local function toolsOf()
    local stats = cfg.toolStats or {}
    for item in pairs(stats) do
        if not cfg.tools[item] then return nil, format("outil '%s' : dans toolStats (config.lua), absent de tools (config_client.lua)", tostring(item)) end
    end
    local out = {}
    for item, tool in pairs(cfg.tools) do
        local stat = stats[item]
        if type(stat) ~= 'table' then return nil, format("outil '%s' : absent de toolStats (config.lua)", tostring(item)) end
        out[item] = { kind = tool.kind, power = stat.power, yieldBonus = stat.yieldBonus, qualityBonus = stat.qualityBonus, wear = stat.wear }
    end
    return out
end

--- Indexe la config, définit le registre des outils et y verse ceux de la config, déclare les objets, vérifie que
--- chaque ressource produit un objet connu. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function catalog.define()
    local ok, err = index()
    if not ok then return false, err end
    local tools
    tools, err = toolsOf()
    if not tools then return false, err end
    ok, err = core.registry.define(REGISTRY, { schema = TOOL_SCHEMA })
    if not ok then return false, err end
    for item, tool in pairs(tools) do
        ok, err = core.registry.add(REGISTRY, item, tool)
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

-- Atelier (T-102) : catalogue mutable ---------------------------------------------------------------------------------

--- Pose (crée ou remplace) une zone. Tout ou rien : true, ou false et une raison (rien n'a changé).
---@param zone table  { id, label, kind, x, y, z, radius, cost, regenPerHour, scarHours }
---@return boolean ok
---@return string|nil err
function catalog.putZone(zone)
    local def, err = checkZone(zone)
    if not def then return false, err end
    local known = zonesById[def.id]
    if not known and #zonesOrdered >= cfg.editor.maxZones then
        return false, format('%d zones au plus', cfg.editor.maxZones)
    end
    local ok, boundsErr = checkBounds(def, nodesByZone[def.id] or {})
    if not ok then return false, boundsErr end
    if known then
        assign(known, def)
    else
        zonesById[def.id] = def
        zonesOrdered[#zonesOrdered + 1] = def
        nodesByZone[def.id] = {}
    end
    return true
end

--- Retire une zone et ses nœuds (s'il en reste). Rend les identifiants des nœuds retirés.
---@param id string
---@return string[]
function catalog.dropZone(id)
    local removed = {}
    if not zonesById[id] then return removed end
    for _, node in ipairs(nodesByZone[id] or {}) do
        nodesById[node.id] = nil
        removed[#removed + 1] = node.id
    end
    zonesById[id], nodesByZone[id] = nil, nil
    for i, def in ipairs(zonesOrdered) do
        if def.id == id then
            table.remove(zonesOrdered, i)
            break
        end
    end
    return removed
end

local function unlink(node)
    local list = nodesByZone[node.zone.id]
    if not list then return end
    for i, known in ipairs(list) do
        if known == node then
            table.remove(list, i)
            return
        end
    end
end

--- Pose (crée ou remplace) un nœud. Tout ou rien : true et l'identifiant de son ancienne zone (s'il en change), ou
--- false et une raison.
---@param node table  { id, label, zone, resource, x, y, z, heading, charges, regenMs }
---@return boolean ok
---@return string|nil errOrPrevious
function catalog.putNode(node)
    local def, err = checkNode(node)
    if not def then return false, err end
    local known = nodesById[def.id]
    local zoneId = def.zone.id
    local list = {}
    for _, other in ipairs(nodesByZone[zoneId]) do
        if other.id ~= def.id then list[#list + 1] = other end
    end
    list[#list + 1] = def
    local ok, boundsErr = checkBounds(def.zone, list)
    if not ok then return false, boundsErr end
    local previous = nil
    if known then
        previous = known.zone.id
        if previous ~= zoneId then unlink(known) end
        assign(known, def)
        if previous ~= zoneId then
            local target = nodesByZone[zoneId]
            target[#target + 1] = known
        end
    else
        nodesById[def.id] = def
        local target = nodesByZone[zoneId]
        target[#target + 1] = def
    end
    return true, previous ~= zoneId and previous or nil
end

--- Retire un nœud. Rend l'identifiant de sa zone, ou nil s'il n'existait pas.
---@param id string
---@return string|nil
function catalog.dropNode(id)
    local node = nodesById[id]
    if not node then return nil end
    unlink(node)
    nodesById[id] = nil
    return node.zone.id
end

--- La graine telle que la config la donne (retour à l'original de l'Atelier) : { zones, nodes } (tables de la config,
--- lecture seule).
---@return { zones: table[], nodes: table[] }
function catalog.seed()
    return { zones = cfg.zones, nodes = cfg.nodes }
end

-- Lectures -----------------------------------------------------------------------------------------------------------

---@param id any
---@return vAvA.ZoneDefinition|nil
function catalog.zone(id)
    return type(id) == 'string' and zonesById[id] or nil
end

--- Zones dans l'ordre de la graine, puis de création.
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

--- Toutes les ressources (identifiant → définition, lecture seule).
---@return table<string, vAvA.ResourceDefinition>
function catalog.resources()
    return resourcesById
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
