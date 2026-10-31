--[[
    vava_gathering/server/atelier.lua
    Rôle : l'atelier « Récolte » de l'Atelier du Conseil (T-102) : déclaration au registre `vava_atelier:editors` (au
           démarrage si l'Atelier tourne, et à son hook `vava_atelier:editorsReady`), et les fonctions qu'il appelle :
             - `index`, `read` : zones et points en vigueur (catalogue), ou la graine de config.lua (`original`) ;
             - `validate`, `validateLot`, `placeCheck` : règles du module (shared/editing.lua), seul juge ;
             - `apply`, `remove` : catalogue changé à chaud (tout ou rien), vitalité et charges reprises de la base,
               récoltes en cours sur un point changé oubliées, zone NOTÉE ; la diffusion part une fois, au dernier appel
               d'un lot (`info.last`) : différences regroupées par zone, aux seuls abonnés (server/share.lua) ;
             - `trial`, `endTrial` : essai à blanc chez l'auteur seul (server/trials.lua) ;
             - `options` (ressources), `compare` (une autre zone du même type).
           Sans l'Atelier, la récolte tourne sur sa graine (config.lua), avec un avertissement en console.
    Dépendances : shared/constants.lua, config.lua, shared/editing.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua, server/zones.lua, server/nodes.lua, server/share.lua, server/trials.lua,
                  server/harvest.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local sort = table.sort

local core = VavaGathering.core
local bridge = VavaGathering.bridge
local cfg = VavaGathering.config
local editing = VavaGathering.editing
local catalog, zones, nodes, share, trials, harvest = VavaGathering.catalog, VavaGathering.zones, VavaGathering.nodes,
    VavaGathering.share, VavaGathering.trials, VavaGathering.harvest

local KEY = 'vava_gathering:zones'
local READY_HOOK = 'vava_atelier:editorsReady'
local SOURCE = 'ressources'
local texts = cfg.editor.texts

local atelier = {}
VavaGathering.atelier = atelier

-- types de lieu permis (choix « Type de lieu »)
local KINDS = {}
for _, option in ipairs(cfg.editor.zoneKinds) do KINDS[option.value] = true end

--- Ce que les règles du module voient en ce moment (shared/editing.lua).
local function view()
    local resources = {}
    for id, resource in pairs(catalog.resources()) do
        resources[id] = { label = resource.label, fishing = resource.fishing }
    end
    return {
        zones = catalog.zones(), zone = catalog.zone, nodesOf = catalog.nodesOf, resources = resources,
        water = cfg.waterKinds or {}, kinds = KINDS, settings = cfg.editor,
    }
end

local function original(ctx)
    return type(ctx) == 'table' and ctx.original == true
end

-- Lecture ------------------------------------------------------------------------------------------------------------

local function index(kind, ctx)
    local out = {}
    if original(ctx) then
        local seed = catalog.seed()
        for _, item in ipairs(kind == 'zone' and seed.zones or kind == 'node' and seed.nodes or {}) do
            out[#out + 1] = { id = item.id, title = item.label or item.id }
        end
        return out
    end
    if kind == 'zone' then
        for _, zone in ipairs(catalog.zones()) do out[#out + 1] = { id = zone.id, title = zone.label } end
    elseif kind == 'node' then
        for id, node in pairs(catalog.nodes()) do out[#out + 1] = { id = id, title = node.label or id } end
        sort(out, function(a, b) return a.id < b.id end)
    end
    return out
end

local function read(kind, id, ctx)
    local seed = original(ctx) and catalog.seed() or nil
    if kind == 'zone' then
        local zone = nil
        if seed then
            for _, item in ipairs(seed.zones) do if item.id == id then zone = item end end
        else
            zone = catalog.zone(id)
        end
        if not zone then return nil end
        local data, place = editing.zoneData(zone)
        data.place = place
        return data
    elseif kind == 'node' then
        local node = nil
        if seed then
            for _, item in ipairs(seed.nodes) do if item.id == id then node = item end end
        else
            node = catalog.node(id)
        end
        if not node then return nil end
        local data, place, parent = editing.nodeData(node)
        data.place, data.parent = place, parent
        return data
    end
    return nil
end

local function validate(kind, data, ctx)
    if kind == 'zone' then return editing.validateZone(data, ctx, view()) end
    if kind == 'node' then return editing.validateNode(data, ctx, view()) end
    return false, texts.resource
end

local function validateLot(lot)
    return editing.validateLot(lot, view())
end

local function placeCheck(kind, place, ctx)
    return editing.placeCheck(kind, place, ctx or {}, view())
end

local function options(source)
    if source == SOURCE then return editing.resourceOptions(catalog.resources()) end
    return {}
end

local function compare(kind, data)
    if kind ~= 'zone' then return nil end
    return editing.compare(data, view())
end

-- Rechargement à chaud -------------------------------------------------------------------------------------------------

--- Fin d'un lot : les zones notées partent, une différence par zone et par abonné.
local function flushIfLast(info)
    if type(info) == 'table' and info.last then share.flush() end
end

local function apply(kind, def, info)
    if kind == 'zone' then
        local zone, why = editing.zoneOf(def)
        if not zone then return false, why == 'no_place' and texts.noPlaceZone or texts.kind end
        if not KINDS[zone.kind] then return false, texts.kind end
        local ok, err = catalog.putZone(zone)
        if not ok then return false, tostring(err) end
        zones.ensure(catalog.zone(zone.id))
        share.touch(zone.id)
    elseif kind == 'node' then
        local node, why = editing.nodeOf(def)
        if not node then return false, why == 'no_place' and texts.noPlaceNode or texts.resource end
        local ok, previous = catalog.putNode(node)
        if not ok then return false, tostring(previous) end
        nodes.ensure(catalog.node(node.id))
        harvest.forgetNode(node.id)
        share.touch(node.zone)
        if previous then share.touch(previous) end
    else
        return false, texts.resource
    end
    flushIfLast(info)
    return true
end

local function remove(kind, id, info)
    if kind == 'zone' then
        for _, nodeId in ipairs(catalog.dropZone(id)) do
            nodes.forget(nodeId)
            harvest.forgetNode(nodeId)
        end
        zones.forget(id)
        share.touch(id)
    elseif kind == 'node' then
        local zoneId = catalog.dropNode(id)
        nodes.forget(id)
        harvest.forgetNode(id)
        if zoneId then share.touch(zoneId) end
    end
    flushIfLast(info)
    return true
end

-- Essai à blanc --------------------------------------------------------------------------------------------------------

--- Nœud d'essai tiré d'une définition de l'Atelier (ressource résolue), ou nil.
local function trialNodeOf(def)
    local node = editing.nodeOf(def)
    local resource = node and catalog.resource(node.resource)
    if not resource then return nil end
    node.resource = resource
    return node
end

--- Nœuds montrés par un essai : ceux publiés de la zone (moins les retraits préparés), remplacés ou complétés par ceux
--- de l'essai.
local function shownNodes(zoneId, overrides, hidden)
    local list, seen = {}, {}
    for _, node in ipairs(overrides) do seen[node.id] = true end
    for _, node in ipairs(catalog.nodesOf(zoneId)) do
        if not seen[node.id] and not hidden[node.id] then list[#list + 1] = node end
    end
    for _, node in ipairs(overrides) do list[#list + 1] = node end
    return list
end

local function trial(kind, def, ctx)
    ctx = ctx or {}
    local source, accountId = ctx.source, ctx.accountId
    if not accountId then return false, texts.noZone end
    local overrides = {}
    for _, child in ipairs(ctx.children or {}) do
        if child.kind == 'node' then
            local node = trialNodeOf(child.def)
            if node then overrides[#overrides + 1] = node end
        end
    end
    local zone
    if kind == 'zone' then
        zone = editing.zoneOf(def)
        if not zone then return false, texts.noPlaceZone end
    elseif kind == 'node' then
        local node = trialNodeOf(def)
        if not node then return false, texts.noPlaceNode end
        local published = catalog.zone(node.zone)
        if not published then return false, texts.noZone end
        zone = {}
        for key, value in pairs(published) do zone[key] = value end
        overrides[#overrides + 1] = node
    else
        return false, texts.resource
    end
    if ctx.reason == 'save' and trials.patch(source, accountId, kind == 'zone' and zone or nil, overrides, nil) then
        return true
    end
    local hidden = {}
    for _, ref in ipairs(ctx.removed or {}) do
        if ref.kind == 'node' then hidden[ref.id] = true end
    end
    trials.start(source, accountId, zone, shownNodes(zone.id, overrides, hidden))
    return true
end

local function endTrial(_, _, ctx)
    ctx = ctx or {}
    trials.stop(ctx.accountId, ctx.source)
    return true
end

-- Déclaration ----------------------------------------------------------------------------------------------------------

local declaration = nil

--- Déclare l'atelier si le registre de l'Atelier existe et qu'il n'y est pas déjà.
function atelier.declare()
    if not declaration or not bridge.AtelierExists() or bridge.AtelierHas(KEY) then return end
    local def = {}
    for key, value in pairs(declaration) do def[key] = value end
    def.index, def.read, def.validate, def.validateLot, def.placeCheck = index, read, validate, validateLot, placeCheck
    def.apply, def.remove, def.trial, def.endTrial = apply, remove, trial, endTrial
    def.options, def.compare = options, compare
    local ok, err = bridge.AtelierDeclare(KEY, def)
    if not ok then VavaGathering.log.error("atelier '%s' refusé par l'Atelier : %s", KEY, tostring(err)) end
end

--- Démarrage : déclaration tirée de la config, hook de l'Atelier. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function atelier.start()
    declaration = editing.declaration(cfg)
    local id, err = core.hooks.after(READY_HOOK, atelier.declare)
    if not id then return false, READY_HOOK .. ' : ' .. tostring(err) end
    if not bridge.AtelierExists() then
        VavaGathering.log.warn('vava_atelier absent : la récolte tourne sur sa graine (config.lua) ; avec l\'Atelier, '
            .. 'la base fait foi')
    end
    atelier.declare()
    return true
end
