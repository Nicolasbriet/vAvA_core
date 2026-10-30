--[[
    vava_crafting/server/stations.lua
    Rôle : état des stations placées, tenu par le serveur : réserve de combustible (écrite par lots), occupation (un
           artisan à la fois, en mémoire), accès (publique, ou privée à son propriétaire ; d'autres genres de
           propriétaires — foyer — se branchent par `registerAccess`), distance au joueur. Chaque station est une zone du
           core (abonnements de zone, 1.5.0) : son dessin (`def`) et son état (`s` : combustible, occupation) ne partent
           qu'aux joueurs proches (positions lues par le serveur), puis seulement ses changements, écrits au seul
           changement. Une déclaration refusée par le core est retentée par la boucle d'écriture au plus une fois par
           minute ; un état non envoyé, au passage suivant de cette boucle. Aucune clé GlobalState (les anciennes sont
           effacées une fois au démarrage, pour les seules stations connues : celle d'une station retirée de la config
           part au redémarrage du serveur).
    Dépendances : shared/constants.lua, config.lua, shared/stationzone.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local min, max = math.min, math.max
local time = os.time
local GlobalState, GetGameTimer = GlobalState, GetGameTimer

local bridge = VavaCrafting.bridge
local catalog = VavaCrafting.catalog
local stationzone = VavaCrafting.stationzone
local cfg = VavaCrafting.config
local streaming = cfg.streaming
local LEGACY_STATE_STATION, LEGACY_STATE_STATIONS = VavaCrafting.LEGACY_STATE_STATION, VavaCrafting.LEGACY_STATE_STATIONS
local DEF, STATUS = stationzone.DEF, stationzone.STATUS

local SELECT_SQL = 'SELECT `station`, `fuel` FROM `vava_crafting_stations`'
local UPSERT_SQL = 'INSERT INTO `vava_crafting_stations` (`station`, `fuel`, `updated_at`) VALUES (?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `fuel` = VALUES(`fuel`), `updated_at` = VALUES(`updated_at`)'

local stations = {}
VavaCrafting.stations = stations

---@class vAvA.StationState
---@field fuel integer
---@field busyBy integer|nil     joueur qui travaille
---@field published { fuel: integer, busy: boolean }|nil   dernier état accepté par le core (nil : zone pas encore déclarée)
---@field pendingStatus true|nil  un état n'a pas pu partir : renvoyé au passage suivant de la boucle d'écriture
---@field dirty boolean|string   true : à écrire ; WRITING : écriture en cours (une modification pendant l'attente remet true)

---@type table<string, vAvA.StationState>
local states = {}
local WRITING = 'writing'
-- stations dont la zone du core est déclarée (une déclaration refusée est retentée par stations.retry)
---@type table<string, true>
local declared = {}
-- dernier refus de déclaration par station (GetGameTimer) : nouvel essai au plus une fois par RETRY_MS
---@type table<string, integer>
local refusedAt = {}
local RETRY_MS = 60000
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

--- Ancienne clé GlobalState (1.4.0 et avant) effacée si elle existe encore : une seule écriture, seulement quand le
--- serveur n'a pas redémarré depuis l'ancienne version.
---@param key string
local function forgetLegacy(key)
    if GlobalState[key] ~= nil then
        GlobalState[key] = nil -- audit: ok (effacement unique d'une clé de l'ancienne version, plus jamais écrite)
    end
end

--- Zone du core de la station : cercle au sol autour d'elle, connu à streaming.radius + subscribeSlack de son bord.
---@param def vAvA.StationDefinition
---@return table
local function areaOf(def)
    return stationzone.area(def, streaming.zoneRadius, streaming.radius + streaming.subscribeSlack)
end

--- Déclare la zone de la station au core, ou, déjà déclarée, la déplace et remplace son dessin et son état : les
--- joueurs proches la reçoivent (ou la voient changer) sans reconnexion, eux seuls. Appelé au démarrage, pour une
--- station placée par un module (`addStation`) et par stations.retry. Une station dont le lieu, le nom ou le modèle
--- change en jeu (Atelier, Conseil : T-101, T-102) devra aussi passer par ici ; son retrait demandera un `RemoveZone`
--- au bridge, qui n'existe pas encore.
---@param def vAvA.StationDefinition
---@return boolean ok
---@return string|nil err  code du core
function stations.share(def)
    local state = stateOf(def)
    local status = stationzone.status(state.fuel, state.busyBy ~= nil)
    local ok, err
    if declared[def.id] then
        ok, err = bridge.MoveZone(def.id, areaOf(def))
        if ok then ok, err = bridge.SetZone(def.id, { [DEF] = stationzone.drawing(def), [STATUS] = status }) end
    else
        ok, err = bridge.DefineZone(def.id, areaOf(def), { [DEF] = stationzone.drawing(def), [STATUS] = status })
        if ok then declared[def.id] = true end
    end
    if not ok then
        refusedAt[def.id] = GetGameTimer()
        VavaCrafting.log.error("station '%s' non partagée avec les joueurs proches : %s ; nouvel essai dans une minute", def.id, tostring(err))
        return false, tostring(err)
    end
    refusedAt[def.id] = nil
    state.published, state.pendingStatus = status, nil
    return true
end

--- Station ajoutée après le chargement (autre module) : état neuf, partagé avec les joueurs proches. Une zone refusée
--- par le core (`full` : trop de zones) fait oublier son état : l'appelant retire la station du catalogue et le dit au
--- module qui l'a placée. Bloque le thread courant (lecture).
---@param def vAvA.StationDefinition
---@return boolean ok
---@return string|nil err  code du core
function stations.adopt(def)
    if states[def.id] then return true end
    local capacity = def.type.fuel and def.type.fuel.capacity or 0
    local row = bridge.db.single('SELECT `fuel` FROM `vava_crafting_stations` WHERE `station` = ?', { def.id })
    states[def.id] = { fuel = row and min(capacity, bridge.Integer(row.fuel, 0)) or 0, busyBy = nil, published = nil, dirty = row == nil }
    forgetLegacy(LEGACY_STATE_STATION .. def.id)
    local ok, err = stations.share(def)
    if not ok then
        states[def.id], refusedAt[def.id] = nil, nil
        return false, err
    end
    return true
end

--- Combustible et occupation envoyés aux abonnés de la zone de la station, au seul changement (une différence
--- d'environ 34 octets, regroupée par le core avec les autres changements du même tour). Zone pas encore déclarée :
--- rien ne part, l'état entier partira à sa déclaration (stations.retry). Envoi refusé : renvoyé au passage suivant
--- de stations.retry.
---@param def vAvA.StationDefinition
function stations.publish(def)
    if not declared[def.id] then return end
    local state = stateOf(def)
    local status = stationzone.status(state.fuel, state.busyBy ~= nil)
    if stationzone.sameStatus(state.published, status) then
        state.pendingStatus = nil
        return
    end
    local ok, err = bridge.SetZone(def.id, { [STATUS] = status })
    if not ok then
        if not state.pendingStatus then
            VavaCrafting.log.warn("station '%s' : état non envoyé aux joueurs proches : %s ; nouvel essai au prochain passage", def.id, tostring(err))
        end
        state.pendingStatus = true
        return
    end
    state.published, state.pendingStatus = status, nil
end

--- Passage de la boucle d'écriture : déclare de nouveau les stations refusées par le core (au plus une fois par minute
--- chacune) et renvoie les états qui n'ont pas pu partir.
function stations.retry()
    local now = GetGameTimer()
    for _, def in ipairs(catalog.stations()) do
        local state = stateOf(def)
        if state and not declared[def.id] then
            local at = refusedAt[def.id]
            if not at or now - at >= RETRY_MS then stations.share(def) end
        elseif state and state.pendingStatus then
            stations.publish(def)
        end
    end
end

--- Déclare au core la zone de chaque station placée (setup du module, après stations.load()) et efface les anciennes
--- clés GlobalState. Une station refusée est écrite en console et n'empêche pas les autres.
---@return integer shared  stations partagées
function stations.declareAll()
    declared, refusedAt = {}, {}
    forgetLegacy(LEGACY_STATE_STATIONS)
    local shared = 0
    for _, def in ipairs(catalog.stations()) do
        forgetLegacy(LEGACY_STATE_STATION .. def.id)
        if stations.share(def) then shared = shared + 1 end
    end
    return shared
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
