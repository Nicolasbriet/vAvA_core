--[[
    vava_crafting/server/stations.lua
    Rôle : état des stations placées, tenu par le serveur : réserve de combustible (écrite par lots), occupation (un
           artisan à la fois, en mémoire), accès (publique, ou privée à son propriétaire ; d'autres genres de
           propriétaires — foyer — se branchent par `registerAccess`), distance au joueur, publication aux clients par un
           state bag global écrit au seul changement.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua, server/catalog.lua
]]

local pairs, ipairs = pairs, ipairs
local min, max = math.min, math.max
local time = os.time
local GlobalState = GlobalState

local bridge = VavaCrafting.bridge
local catalog = VavaCrafting.catalog
local cfg = VavaCrafting.config
local STATE_STATION = VavaCrafting.STATE_STATION

local SELECT_SQL = 'SELECT `station`, `fuel` FROM `vava_crafting_stations`'
local UPSERT_SQL = 'INSERT INTO `vava_crafting_stations` (`station`, `fuel`, `updated_at`) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `fuel` = VALUES(`fuel`), `updated_at` = VALUES(`updated_at`)'

local stations = {}
VavaCrafting.stations = stations

---@class vAvA.StationState
---@field fuel integer
---@field busyBy integer|nil     joueur qui travaille
---@field published { fuel: integer, busy: boolean }|nil
---@field dirty boolean|string   true : à écrire ; WRITING : écriture en cours (une modification pendant l'attente remet true)

---@type table<string, vAvA.StationState>
local states = {}
local WRITING = 'writing'
-- genre de propriétaire → fun(ownerId, characterId): boolean
local accessors = {
    character = function(ownerId, characterId) return ownerId == characterId end,
}

--- Charge la réserve de combustible de chaque station de la config. Bloque le thread courant.
---@return boolean ok
---@return string|nil err
function stations.load()
    local rows, err = bridge.db.query(SELECT_SQL, {})
    if err then return false, err end
    local byId = {}
    for _, row in ipairs(rows) do byId[row.station] = row end
    for _, def in ipairs(catalog.stations()) do
        local row = byId[def.id]
        local capacity = def.type.fuel and def.type.fuel.capacity or 0
        states[def.id] = { fuel = row and min(capacity, bridge.Integer(row.fuel, 0)) or 0, busyBy = nil, published = nil, dirty = row == nil }
    end
    return true
end

---@param def vAvA.StationDefinition
---@return vAvA.StationState
local function stateOf(def)
    return states[def.id]
end

--- Station ajoutée après le chargement (autre module) : état neuf, publié. Bloque le thread courant (lecture).
---@param def vAvA.StationDefinition
function stations.adopt(def)
    if states[def.id] then return end
    local capacity = def.type.fuel and def.type.fuel.capacity or 0
    local row = bridge.db.single('SELECT `fuel` FROM `vava_crafting_stations` WHERE `station` = ?', { def.id })
    states[def.id] = { fuel = row and min(capacity, bridge.Integer(row.fuel, 0)) or 0, busyBy = nil, published = nil, dirty = row == nil }
    stations.publish(def)
    stations.publishList()
end

---@param def vAvA.StationDefinition
function stations.publish(def)
    local state = stateOf(def)
    local snapshot = { fuel = state.fuel, busy = state.busyBy ~= nil }
    local previous = state.published
    if previous and previous.fuel == snapshot.fuel and previous.busy == snapshot.busy then return end
    state.published = snapshot
    GlobalState[STATE_STATION .. def.id] = snapshot
end

--- Publie la liste des stations placées (config et modules) : les clients la dessinent.
function stations.publishList()
    GlobalState[VavaCrafting.STATE_STATIONS] = catalog.stationList()
end

function stations.publishAll()
    for _, def in ipairs(catalog.stations()) do stations.publish(def) end
    stations.publishList()
end

--- Branche un genre de propriétaire (foyer, guilde…) : `fn(ownerId, characterId)` dit si le personnage a accès.
---@param kind string
---@param fn fun(ownerId: integer, characterId: integer): boolean
function stations.registerAccess(kind, fn)
    accessors[kind] = fn
end

--- Le personnage peut-il se servir de la station ? (publique, ou privée dont il est le propriétaire)
---@param def vAvA.StationDefinition
---@param characterId integer
---@return boolean
function stations.canAccess(def, characterId)
    if not def.owner then return true end
    local accessor = accessors[def.owner.kind]
    return accessor ~= nil and accessor(def.owner.id, characterId) == true
end

--- Le joueur est-il à portée de la station (position lue côté serveur, tolérance comprise) ?
---@param src integer
---@param def vAvA.StationDefinition
---@return boolean
function stations.near(src, def)
    local x, y, z = bridge.Position(src)
    if not x then return false end
    local dx, dy, dz = x - def.x, y - def.y, z - def.z
    local reach = cfg.interact.distance + cfg.interact.serverTolerance
    return dx * dx + dy * dy + dz * dz <= reach * reach
end

---@param def vAvA.StationDefinition
---@return integer|nil
function stations.busyBy(def)
    return stateOf(def).busyBy
end

---@param def vAvA.StationDefinition
---@param src integer|nil
function stations.setBusy(def, src)
    stateOf(def).busyBy = src
    stations.publish(def)
end

---@param def vAvA.StationDefinition
---@return integer
function stations.fuel(def)
    return stateOf(def).fuel
end

--- Vrai si la station a de quoi faire une pièce (ou n'a pas besoin de combustible).
---@param def vAvA.StationDefinition
---@return boolean
function stations.hasFuel(def)
    local fuel = def.type.fuel
    return fuel == nil or stateOf(def).fuel >= fuel.perCraft
end

---@param def vAvA.StationDefinition
function stations.consumeFuel(def)
    local fuel = def.type.fuel
    if not fuel then return end
    local state = stateOf(def)
    state.fuel = max(0, state.fuel - fuel.perCraft)
    state.dirty = true
    stations.publish(def)
end

--- Ajoute du combustible, jusqu'à la réserve. Renvoie la quantité réellement ajoutée.
---@param def vAvA.StationDefinition
---@param amount integer
---@return integer added
function stations.addFuel(def, amount)
    local fuel = def.type.fuel
    if not fuel then return 0 end
    local state = stateOf(def)
    local added = min(amount, fuel.capacity - state.fuel)
    if added <= 0 then return 0 end
    state.fuel = state.fuel + added
    state.dirty = true
    stations.publish(def)
    return added
end

--- Fixe la réserve (Conseil, module).
---@param def vAvA.StationDefinition
---@param amount integer
function stations.setFuel(def, amount)
    local fuel = def.type.fuel
    if not fuel then return end
    local state = stateOf(def)
    state.fuel = min(fuel.capacity, max(0, amount))
    state.dirty = true
    stations.publish(def)
end

--- Vue d'une station pour le menu et les exports.
---@param def vAvA.StationDefinition
---@return table
function stations.view(def)
    local state = stateOf(def)
    local fuel = def.type.fuel
    return {
        id = def.id, label = def.label, type = def.type.id, typeLabel = def.type.label, quality = def.quality,
        busy = state.busyBy ~= nil, x = def.x, y = def.y, z = def.z,
        fuel = fuel and { item = fuel.item, label = catalog.itemLabel(fuel.item), stock = state.fuel, capacity = fuel.capacity, perCraft = fuel.perCraft } or nil,
        owner = def.owner and { kind = def.owner.kind, id = def.owner.id } or nil,
    }
end

--- Requêtes des réserves à écrire, marquées « en cours d'écriture » : l'écriture cède la main, et du combustible
--- ajouté ou brûlé pendant l'attente les marque de nouveau à écrire au lieu d'être effacé par `markClean`.
---@param queries table[]
function stations.collect(queries)
    local now = time()
    for id, state in pairs(states) do
        if state.dirty then
            state.dirty = WRITING
            queries[#queries + 1] = { query = UPSERT_SQL, values = { id, state.fuel, now } }
        end
    end
end

--- Écriture réussie : seules les réserves restées telles qu'écrites sont propres (en échec, elles restent à écrire).
function stations.markClean()
    for _, state in pairs(states) do
        if state.dirty == WRITING then state.dirty = false end
    end
end

--- Joueur parti : il n'occupe plus rien.
---@param src integer
function stations.release(src)
    for _, def in ipairs(catalog.stations()) do
        if states[def.id].busyBy == src then stations.setBusy(def, nil) end
    end
end
