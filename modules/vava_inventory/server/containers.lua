--[[
    vava_inventory/server/containers.lua
    Rôle : conteneurs en mémoire (source de vérité pendant le jeu) : chargement, création, carte d'occupation,
           poids, index objet → conteneur, attribution des identifiants d'objets.
    Les identifiants sont attribués en mémoire à partir du maximum lu au démarrage (un seul serveur par base) :
    aucune opération n'attend la base, donc aucune ne peut être entrelacée avec une autre.
    Dépendances : shared/, config.lua, server/core.lua, server/items.lua, server/persistence.lua
]]

local type, pairs, ipairs, tostring, tonumber, pcall, next = type, pairs, ipairs, tostring, tonumber, pcall, next
local mathType, tointeger = math.type, math.tointeger
local decodeJson = json.decode

local grid = VavaInventory.grid
local items = VavaInventory.items
local persistence = VavaInventory.persistence
local cfg = VavaInventory.config
local KIND = VavaInventory.KIND
local MAX_GRID = VavaInventory.MAX_GRID

local INSERT_SQL = 'INSERT INTO `vava_inventory_containers` (`kind`, `owner_type`, `owner_id`, `width`, `height`, `max_weight`, `label`) VALUES (?, ?, ?, ?, ?, ?, ?)'
local SELECT_SQL = 'SELECT `id`, `kind`, `owner_type`, `owner_id`, `width`, `height`, `max_weight`, `label` FROM `vava_inventory_containers` WHERE `id` = ?'
local SELECT_OWNED_SQL = 'SELECT `id` FROM `vava_inventory_containers` WHERE `owner_type` = ? AND `owner_id` = ? AND `kind` = ? LIMIT 1'
local SELECT_ITEMS_SQL = 'SELECT `id`, `item`, `x`, `y`, `rotated`, `quantity`, `metadata` FROM `vava_inventory_items` WHERE `container_id` = ?'
local UPDATE_SIZE_SQL = 'UPDATE `vava_inventory_containers` SET `width` = ?, `height` = ?, `max_weight` = ? WHERE `id` = ?'
local MAX_ID_SQL = 'SELECT COALESCE(MAX(`id`), 0) FROM `vava_inventory_items`'

local containers = {}
VavaInventory.containers = containers

---@class vAvA.ItemInstance
---@field id integer
---@field item string
---@field containerId integer
---@field x integer
---@field y integer
---@field rotated boolean
---@field quantity integer
---@field metadata table
---@field stored? boolean   a peut-être sa ligne en base (lu en base, ou écriture envoyée) : tenu par persistence.lua

---@class vAvA.Container : vAvA.Grid
---@field id integer              négatif pour un conteneur temporaire (sac au sol)
---@field kind string
---@field ownerType string
---@field ownerId string
---@field label string
---@field maxWeight integer       0 = illimité
---@field weight integer
---@field revision integer        incrémentée à chaque modification (détection des conflits)
---@field persisted boolean
---@field items table<integer, vAvA.ItemInstance>
---@field misplaced vAvA.ItemInstance[]  sans place (définition absente, objet agrandi, grille réduite) : conservés tels quels

---@type table<integer, vAvA.Container>
local byId = {}
---@type table<integer, vAvA.Container>
local ownerOf = {}
local nextTransientId = -1
local lastInstanceId = 0

local function db()
    return VavaInventory.core.db
end

---@return vAvA.Container
local function newContainer(id, kind, ownerType, ownerId, width, height, maxWeight, label, persisted)
    return {
        id = id, kind = kind, ownerType = ownerType, ownerId = ownerId, label = label,
        width = width, height = height, maxWeight = maxWeight, weight = 0, revision = 0,
        persisted = persisted, items = {}, occupancy = {}, misplaced = {},
    }
end

---@param value any
---@param max integer
---@return boolean
local function isDimension(value, max)
    return mathType(value) == 'integer' and value >= 1 and value <= max
end

--- Entier lu en base : oxmysql renvoie les BIGINT et DECIMAL en texte.
---@param value any
---@return integer|nil
local function toInteger(value)
    return tointeger(tonumber(value))
end

---@param raw any
---@return table
local function decodeMetadata(raw)
    if type(raw) == 'table' then return raw end
    if type(raw) ~= 'string' or raw == '' then return {} end
    local ok, decoded = pcall(decodeJson, raw)
    return ok and type(decoded) == 'table' and decoded or {}
end

--- Lit le dernier identifiant d'objet utilisé. À appeler une fois, pendant le setup.
---@return boolean ok
---@return string|nil err
function containers.init()
    local maxId, err = db().scalar(MAX_ID_SQL, {})
    if err then return false, err end
    -- BIGINT et DECIMAL arrivent en texte depuis oxmysql : conversion explicite
    local value = toInteger(maxId)
    -- sans maximum fiable, de nouveaux objets écraseraient des objets existants : on refuse de démarrer
    if not value or value < 0 then return false, 'maximum des identifiants illisible : ' .. tostring(maxId) end
    lastInstanceId = value
    return true
end

---@return integer
function containers.nextInstanceId()
    lastInstanceId = lastInstanceId + 1
    return lastInstanceId
end

--- Place un objet déjà positionné : occupation, poids, index.
---@param container vAvA.Container
---@param instance vAvA.ItemInstance
---@param def vAvA.ItemDefinition
function containers.attach(container, instance, def)
    local w, h = grid.footprint(def, instance.rotated)
    grid.mark(container, w, h, instance.x, instance.y, instance.id)
    container.items[instance.id] = instance
    container.weight = container.weight + def.weight * instance.quantity
    instance.containerId = container.id
    ownerOf[instance.id] = container
end

---@param container vAvA.Container
---@param instance vAvA.ItemInstance
---@param def vAvA.ItemDefinition
function containers.detach(container, instance, def)
    local w, h = grid.footprint(def, instance.rotated)
    grid.unmark(container, w, h, instance.x, instance.y, instance.id)
    container.items[instance.id] = nil
    container.weight = container.weight - def.weight * instance.quantity
    if ownerOf[instance.id] == container then ownerOf[instance.id] = nil end
end

--- Change la quantité d'une pile et le poids de son conteneur.
---@param container vAvA.Container
---@param instance vAvA.ItemInstance
---@param def vAvA.ItemDefinition
---@param delta integer
function containers.adjust(container, instance, def, delta)
    instance.quantity = instance.quantity + delta
    container.weight = container.weight + def.weight * delta
end

---@param container vAvA.Container
---@param instance vAvA.ItemInstance
local function place(container, instance)
    local def = items.get(instance.item)
    if def then
        local w, h = grid.footprint(def, instance.rotated)
        if grid.fits(container, w, h, instance.x, instance.y) then
            containers.attach(container, instance, def)
            return
        end
        local x, y, rotated = grid.findSpace(container, def)
        if x then
            instance.x, instance.y, instance.rotated = x, y, rotated
            containers.attach(container, instance, def)
            persistence.touch(instance, container.persisted)
            return
        end
    end
    container.misplaced[#container.misplaced + 1] = instance
    VavaInventory.log.warn("conteneur #%d : objet #%d (%s) sans place ou sans définition, conservé à part",
        container.id, instance.id, tostring(instance.item))
end

--- Charge un conteneur conservé (ou renvoie celui déjà en mémoire). Bloque le thread courant.
---@param id integer
---@return vAvA.Container|nil
---@return string|nil err
function containers.load(id)
    if byId[id] then return byId[id] end
    local row, err = db().single(SELECT_SQL, { id })
    if err then return nil, err end
    if not row then return nil, 'not_found' end
    local rows, itemsErr = db().query(SELECT_ITEMS_SQL, { id })
    if itemsErr then return nil, itemsErr end
    -- chargé entre-temps par un autre appel : celui-là fait foi
    if byId[id] then return byId[id] end

    local container = newContainer(row.id, row.kind, row.owner_type, row.owner_id, row.width, row.height, row.max_weight, row.label, true)
    local own = cfg.character
    local resized = row.kind == KIND.CHARACTER and (row.width ~= own.width or row.height ~= own.height or row.max_weight ~= own.maxWeight)
    if resized then
        -- la grille du personnage suit la configuration ; les objets hors grille cherchent une nouvelle place
        container.width, container.height, container.maxWeight = own.width, own.height, own.maxWeight
    end
    for _, r in ipairs(rows) do
        local instanceId, x, y, quantity = toInteger(r.id), toInteger(r.x), toInteger(r.y), toInteger(r.quantity)
        if instanceId and x and y and quantity then
            place(container, {
                id = instanceId, item = r.item, x = x, y = y, rotated = toInteger(r.rotated) == 1 or r.rotated == true,
                quantity = quantity, metadata = decodeMetadata(r.metadata), containerId = id, stored = true,
            })
        else
            VavaInventory.log.error('conteneur #%d : ligne d\'objet illisible ignorée (id %s)', id, tostring(r.id))
        end
    end
    byId[id] = container
    -- écriture après l'inscription en mémoire : elle cède la main, et un chargement concurrent doit trouver ce
    -- conteneur plutôt que d'en bâtir un second avec les mêmes objets
    if resized then db().update(UPDATE_SIZE_SQL, { own.width, own.height, own.maxWeight, id }) end
    return container
end

---@class vAvA.ContainerSpec
---@field kind string
---@field ownerType? string
---@field ownerId? string|integer
---@field width integer
---@field height integer
---@field maxWeight? integer
---@field label? string

---@param spec any
---@return string|nil err
local function checkSpec(spec)
    if type(spec) ~= 'table' or type(spec.kind) ~= 'string' or spec.kind == '' then return 'invalid_spec' end
    if not isDimension(spec.width, MAX_GRID) or not isDimension(spec.height, MAX_GRID) then return 'invalid_size' end
    if spec.maxWeight ~= nil and (mathType(spec.maxWeight) ~= 'integer' or spec.maxWeight < 0) then return 'invalid_weight' end
    return nil
end

--- Crée un conteneur conservé en base. Bloque le thread courant.
---@param spec vAvA.ContainerSpec
---@return vAvA.Container|nil
---@return string|nil err
function containers.create(spec)
    local specErr = checkSpec(spec)
    if specErr then return nil, specErr end
    local ownerType, ownerId, maxWeight, label = spec.ownerType or '', tostring(spec.ownerId or ''), spec.maxWeight or 0, spec.label or ''
    local id, err = db().insert(INSERT_SQL, { spec.kind, ownerType, ownerId, spec.width, spec.height, maxWeight, label })
    if not id then return nil, err end
    local container = newContainer(id, spec.kind, ownerType, ownerId, spec.width, spec.height, maxWeight, label, true)
    byId[id] = container
    return container
end

--- Crée un conteneur temporaire, jamais écrit en base (sac au sol). Synchrone.
---@param spec vAvA.ContainerSpec
---@return vAvA.Container|nil
---@return string|nil err
function containers.createTransient(spec)
    local specErr = checkSpec(spec)
    if specErr then return nil, specErr end
    local id = nextTransientId
    nextTransientId = nextTransientId - 1
    local container = newContainer(id, spec.kind, spec.ownerType or '', tostring(spec.ownerId or ''), spec.width, spec.height,
        spec.maxWeight or 0, spec.label or '', false)
    byId[id] = container
    return container
end

--- Identifiant du conteneur d'un propriétaire (1 requête). Bloque le thread courant.
---@param kind string
---@param ownerType string
---@param ownerId string|integer
---@return integer|nil id
---@return string|nil err
function containers.findOwned(kind, ownerType, ownerId)
    local id, err = db().scalar(SELECT_OWNED_SQL, { ownerType, tostring(ownerId), kind })
    if err then return nil, err end
    return toInteger(id)
end

---@param id integer
---@return vAvA.Container|nil
function containers.get(id)
    return byId[id]
end

---@param instanceId integer
---@return vAvA.Container|nil
function containers.ofInstance(instanceId)
    return ownerOf[instanceId]
end

--- Retire un conteneur de la mémoire (après écriture de son journal).
---@param id integer
function containers.unload(id)
    local container = byId[id]
    if not container then return end
    for instanceId in pairs(container.items) do ownerOf[instanceId] = nil end
    byId[id] = nil
end

---@param container vAvA.Container
---@return boolean
function containers.isEmpty(container)
    return next(container.items) == nil and #container.misplaced == 0
end

--- Représentation réseau d'un objet.
---@param instance vAvA.ItemInstance
---@return table
function containers.wire(instance)
    return {
        id = instance.id, item = instance.item, x = instance.x, y = instance.y,
        rotated = instance.rotated, quantity = instance.quantity, metadata = instance.metadata,
    }
end

--- Représentation réseau d'un conteneur (les objets sans place ne sont pas envoyés).
---@param container vAvA.Container
---@return table
function containers.describe(container)
    local list = {}
    for _, instance in pairs(container.items) do list[#list + 1] = containers.wire(instance) end
    return {
        id = container.id, kind = container.kind, label = container.label, width = container.width, height = container.height,
        maxWeight = container.maxWeight, weight = container.weight, items = list,
        catalog = container.catalog,   -- état du catalogue de développement (bandeau de l'interface), sinon rien
    }
end
