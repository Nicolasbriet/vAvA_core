--[[
    client/core/zones.lua
    Rôle : zones suivies par le joueur, décidées par le serveur (abonnements de zone, 0.11.0). Une réplique par zone
           (règles de révision : shared/lib/zonereplica.lua) ; instantané redemandé (core:zones:resync) s'il manque une
           révision ou si un instantané annoncé n'arrive pas ; le module propriétaire de chaque zone est prévenu par le
           gestionnaire qu'il a donné à core.zones.watch (enter, change, leave). Tout est oublié au déchargement et à la
           sélection du personnage ; les zones d'une ressource arrêtée sont oubliées sans notification.
           Instantané fantôme : un instantané latent annoncé, doublé par la sortie de sa zone (fiable) ou par un
           déchargement, est marqué ; s'il arrive ensuite, il est ignoré (sauf nouveau préavis de la même révision).
           Aucune boucle : quatre gestionnaires d'évènement, une minuterie par instantané attendu, un thread par demande
           d'instantané en cours (au plus une par zone).
    Dépendances : shared/init.lua, config/shared.lua, shared/lib/schema.lua, shared/lib/zonereplica.lua,
                  shared/core/logger.lua, shared/core/hooks.lua, client/core/rpc.lua
]]

local type, pairs, pcall, tostring, rawlen = type, pairs, pcall, tostring, rawlen
local mathType, min, max = math.type, math.min, math.max
local sort = table.sort
local match = string.match
local RegisterNetEvent, SetTimeout, CreateThread, Wait = RegisterNetEvent, SetTimeout, CreateThread, Wait
local GetGameTimer, GetInvokingResource = GetGameTimer, GetInvokingResource

local EVENTS = vAvA.EVENTS
local MAX_HANDLE = vAvA.RPC_MAX_ID
local RESYNC = vAvA.ZONE_RPC.RESYNC
local CORE = vAvA.CORE_OWNER
local schema = vAvA.lib.schema
local zonereplica = vAvA.lib.zonereplica
local logger = vAvA.logger
local hooks = vAvA.hooks
local rpc = vAvA.rpc
local cfg = vAvA.config.shared.zones
local log = logger.create('zones')

local NAME_MAX = 113
local MAX_HANDLES = 256
local ID_PATTERN = '^[%w_%-%.:]+$'

local zones = {}
vAvA.zones = zones

---@class vAvA.ZoneEntry
---@field handle integer
---@field replica vAvA.ZoneReplica
---@field name string|nil      inconnu tant que le premier instantané n'est pas arrivé
---@field owner string|nil
---@field id string|nil
---@field notified boolean     le module a reçu enter
---@field generation integer   minuteries plus anciennes sans effet
---@field resyncing boolean
---@field announced integer|nil  plus haute révision annoncée par un préavis (instantané latent en route)

---@type table<integer, vAvA.ZoneEntry>
local entries = {}
-- numéro → { revision, at } : instantané latent annoncé puis doublé par une sortie ou un déchargement ; un instantané de
-- cette révision ou plus ancien, arrivé ensuite, est ignoré (oublié au premier plus récent, ou après staleSnapshotMs)
local ghosts = {}
local RESOURCE = vAvA.resourceName
-- ressource → gestionnaire donné à watch
local handlers = {}
-- ressource → état de limitation de ses erreurs en console
local errorStates = {}
-- vrai entre le chargement du personnage et son déchargement (ou la sélection) : un instantané latent parti avant le
-- déchargement et arrivé après n'est pas gardé
local accepting = false

---@param value any
---@return boolean
local function validHandle(value)
    return mathType(value) == 'integer' and value >= 1 and value <= MAX_HANDLE
end

---@param value any
---@return boolean
local function validRevision(value)
    return mathType(value) == 'integer' and value >= 1
end

--- Ressource et identifiant local d'un nom de zone « <ressource>:<id> ».
---@param name any
---@return string|nil owner
---@return string|nil id
local function splitName(name)
    if type(name) ~= 'string' or #name > NAME_MAX then return nil end
    local owner, id = match(name, '^([%w_%-%.]+):(.+)$')
    if not owner or not match(id, ID_PATTERN) then return nil end
    return owner, id
end

---@param handle integer
---@return vAvA.ZoneEntry
local function entryOf(handle)
    local entry = entries[handle]
    if not entry then
        entry = {
            handle = handle, replica = zonereplica.new(cfg.maxBuffered), notified = false, generation = 0,
            resyncing = false,
        }
        entries[handle] = entry
    end
    return entry
end

--- Prévient le module propriétaire (gestionnaire isolé : une erreur est écrite en console, une par intervalle).
---@param entry vAvA.ZoneEntry
---@param kind string  'enter' | 'change' | 'leave'
local function notify(entry, kind, ...)
    local owner = entry.owner
    local handler = owner and handlers[owner]
    if not handler then return end
    if kind == 'enter' then entry.notified = true end
    local ok, err = pcall(handler, kind, entry.id, ...)
    if ok then return end
    local state = errorStates[owner]
    if not state then
        state = {}
        errorStates[owner] = state
    end
    local allowed, suppressed = logger.throttle(state)
    if allowed then
        log.error("gestionnaire de zones de '%s' en erreur (%s) : %s%s", owner, kind, tostring(err),
            logger.suppressedNote(suppressed))
    end
end

--- Retire une zone ; le module est prévenu s'il l'avait reçue.
---@param handle integer
---@param silent boolean|nil
local function drop(handle, silent)
    local entry = entries[handle]
    if not entry then return end
    entries[handle] = nil
    entry.generation = entry.generation + 1
    -- instantané latent annoncé et pas encore arrivé : s'il arrive après la sortie, il ne doit rien recréer
    local announced = entry.announced
    if announced and (entry.replica.revision == nil or announced > entry.replica.revision) then
        local ghost = ghosts[handle]
        ghosts[handle] = { revision = ghost and max(ghost.revision, announced) or announced, at = GetGameTimer() }
    end
    if entry.notified and not silent then notify(entry, 'leave') end
end

--- Oublie les marques d'instantanés fantômes trop anciennes (aucun latent n'est en route si longtemps).
local function sweepGhosts()
    local now = GetGameTimer()
    for handle, ghost in pairs(ghosts) do
        if now - ghost.at > cfg.staleSnapshotMs then ghosts[handle] = nil end
    end
end

--- Vrai si cet instantané est un fantôme : annoncé avant une sortie (ou un déchargement), arrivé après, et sans
--- nouveau préavis de la même révision depuis.
---@param handle integer
---@param revision integer
---@return boolean
local function isGhost(handle, revision)
    local ghost = ghosts[handle]
    if not ghost then return false end
    if GetGameTimer() - ghost.at > cfg.staleSnapshotMs or revision > ghost.revision then
        ghosts[handle] = nil
        return false
    end
    local entry = entries[handle]
    if entry and entry.announced == revision then
        ghosts[handle] = nil
        return false
    end
    return true
end

--- Évènements des zones : seulement ceux du serveur (un déclenchement local par une autre ressource est ignoré).
---@return boolean
local function fromServer()
    local invoker = GetInvokingResource()
    return invoker == nil or invoker == RESOURCE
end

local requestResync

--- Minuterie : instantané toujours attendu à l'échéance → redemandé.
---@param entry vAvA.ZoneEntry
---@param ms integer
local function awaitSnapshot(entry, ms)
    entry.generation = entry.generation + 1
    local generation = entry.generation
    SetTimeout(ms, function()
        if entries[entry.handle] == entry and entry.generation == generation and entry.replica.awaiting then
            requestResync(entry, 'délai dépassé')
        end
    end)
end

--- Demande l'instantané au serveur (un thread à la fois par zone), avec des essais espacés en cas d'échec.
---@param entry vAvA.ZoneEntry
---@param detail string
requestResync = function(entry, detail)
    if entry.resyncing then return end
    entry.resyncing = true
    log.debug('instantané redemandé : %s (%s)', entry.name or ('n° ' .. entry.handle), detail)
    CreateThread(function()
        local delay = cfg.resyncRetryMs
        while entries[entry.handle] == entry and entry.replica.awaiting do
            local ok, success, code = rpc.call(nil, RESYNC, entry.handle)
            if entries[entry.handle] ~= entry then break end
            if ok and success == true then
                -- l'instantané vient (ou viendra au passage suivant) : redemandé s'il n'arrive pas
                if entry.replica.awaiting then awaitSnapshot(entry, cfg.maxAwaitMs) end
                break
            end
            if ok and code == 'not_subscribed' then
                drop(entry.handle)
                break
            end
            Wait(delay)
            delay = min(delay * 2, cfg.resyncMaxRetryMs)
        end
        entry.resyncing = false
    end)
end

---@param handle any
---@param name any
---@param revision any
---@param state any
local function onState(handle, name, revision, state)
    if not accepting or not fromServer() then return end
    if not validHandle(handle) or not validRevision(revision) or type(state) ~= 'table' then return end
    local owner, id = splitName(name)
    if not owner or isGhost(handle, revision) then return end
    local entry = entryOf(handle)
    if entry.name and entry.name ~= name then return end
    entry.name, entry.owner, entry.id = name, owner, id
    local result = entry.replica:snapshot(revision, state)
    if result == 'ready' then
        entry.generation = entry.generation + 1
        notify(entry, 'enter', entry.replica.state)
    elseif result == 'resync' then
        requestResync(entry, ('reçu %d, révision suivante manquante'):format(revision))
    end
end

---@param handle any
---@param revision any
---@param delayMs any
local function onPending(handle, revision, delayMs)
    if not accepting or not fromServer() or not validHandle(handle) or not validRevision(revision) then return end
    if mathType(delayMs) ~= 'integer' or delayMs < 0 then return end
    local entry = entryOf(handle)
    entry.announced = max(entry.announced or 0, revision)
    if entry.replica:notice(revision) == 'awaiting' then
        awaitSnapshot(entry, min(delayMs + cfg.awaitMarginMs, cfg.maxAwaitMs))
    end
end

---@param handle any
---@param revision any
---@param set any
---@param removed any
local function onDiff(handle, revision, set, removed)
    if not accepting or not fromServer() or not validHandle(handle) or not validRevision(revision) then return end
    if set ~= nil and type(set) ~= 'table' then return end
    if removed ~= nil and not zonereplica.isKeyList(removed) then return end
    local entry = entryOf(handle)
    local expected = (entry.replica.revision or 0) + 1
    local result = entry.replica:diff(revision, set, removed)
    if result == 'applied' then
        if entry.notified then notify(entry, 'change', set or {}, removed or {}) end
    elseif result == 'resync' then
        requestResync(entry, ('attendu %d, reçu %d'):format(expected, revision))
    end
end

---@param handles any
local function onLeave(handles)
    if not fromServer() or type(handles) ~= 'table' then return end
    local length = rawlen(handles)
    if length > MAX_HANDLES then return end
    sweepGhosts()
    for i = 1, length do
        local handle = handles[i]
        if validHandle(handle) then drop(handle) end
    end
end

--- Toutes les zones oubliées (déchargement, sélection) ; chaque module est prévenu pour les siennes. Les instantanés
--- latents annoncés et pas encore arrivés restent marqués : arrivés après le chargement suivant, ils sont ignorés.
local function clearAll()
    accepting = false
    sweepGhosts()
    local list = {}
    for handle in pairs(entries) do list[#list + 1] = handle end
    sort(list)
    for i = 1, #list do drop(list[i]) end
end

-- Surface des modules ------------------------------------------------------------------------------------------------

--- Gestionnaire du module : ('enter', id, état), ('change', id, valeurs, retirées), ('leave', id). Un second appel
--- remplace le premier ; les zones déjà à jour sont rejouées (enter) au tour suivant.
---@param owner string
---@param handler any
---@return boolean ok
---@return string|nil err
function zones.watch(owner, handler)
    if not schema.isCallable(handler) then return false, 'handler non appelable' end
    handlers[owner] = handler
    for _, entry in pairs(entries) do
        if entry.owner == owner then entry.notified = false end
    end
    -- rejoué au tour suivant : le module a fini son appel et posé son propre état
    SetTimeout(0, function()
        if handlers[owner] ~= handler then return end
        local list = {}
        for handle, entry in pairs(entries) do
            if entry.owner == owner and not entry.notified and entry.replica:isReady() then list[#list + 1] = handle end
        end
        sort(list)
        for i = 1, #list do
            local entry = entries[list[i]]
            if entry and not entry.notified and entry.replica:isReady() then notify(entry, 'enter', entry.replica.state) end
        end
    end)
    return true
end

--- État d'une zone du module, à jour, et sa révision ; nil sinon.
---@param owner string
---@param id any
---@return table|nil state
---@return integer|nil revision
function zones.get(owner, id)
    if type(id) ~= 'string' then return nil end
    local name = owner .. ':' .. id
    for _, entry in pairs(entries) do
        if entry.name == name and entry.replica:isReady() then return entry.replica.state, entry.replica.revision end
    end
    return nil
end

--- Identifiants locaux des zones à jour du module, triés.
---@param owner string
---@return string[]
function zones.list(owner)
    local list = {}
    for _, entry in pairs(entries) do
        if entry.owner == owner and entry.replica:isReady() then list[#list + 1] = entry.id end
    end
    sort(list)
    return list
end

-- Service du core ---------------------------------------------------------------------------------------------------

--- Ressource arrêtée : ses zones et son gestionnaire oubliés, sans notification.
---@param owner string
function zones.purgeOwner(owner)
    handlers[owner] = nil
    errorStates[owner] = nil
    local list = {}
    for handle, entry in pairs(entries) do
        if entry.owner == owner then list[#list + 1] = handle end
    end
    for i = 1, #list do drop(list[i], true) end
end

--- Branche les évènements et le nettoyage. Appelé par client/init.lua.
function zones.start()
    RegisterNetEvent(EVENTS.ZONE_STATE, onState)
    RegisterNetEvent(EVENTS.ZONE_PENDING, onPending)
    RegisterNetEvent(EVENTS.ZONE_DIFF, onDiff)
    RegisterNetEvent(EVENTS.ZONE_LEAVE, onLeave)
    hooks.subscribe(CORE, 'after', 'core:character:loaded', function() accepting = true end)
    hooks.subscribe(CORE, 'after', 'core:character:unloaded', clearAll)
    hooks.subscribe(CORE, 'after', 'core:character:selection', clearAll)
end
