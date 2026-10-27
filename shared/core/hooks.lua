--[[
    shared/core/hooks.lua
    Rôle : moteur de hooks commun client/serveur. "before" peut annuler l'action, "after" y réagit.
    Ordre d'exécution : priorité croissante, puis ordre d'inscription. Chaque handler est isolé (xpcall).
    Un handler "before" en erreur annule l'action (fail-closed) et l'erreur est journalisée.
    Dépendances : shared/init.lua, config/shared.lua, shared/lib/table.lua, shared/lib/string.lua,
                  shared/lib/schema.lua, shared/core/logger.lua
]]

local xpcall, type, pairs, tostring = xpcall, type, pairs, tostring
local traceback = debug.traceback
local mathType = math.type
local format = string.format
local sort = table.sort
local GetGameTimer = GetGameTimer

local tbl = vAvA.lib.table
local str = vAvA.lib.string
local schema = vAvA.lib.schema
local logger = vAvA.logger
local cfg = vAvA.config.shared.hooks
local log = logger.create('hooks')

local PHASES = { before = true, after = true }

local hooks = {}
vAvA.hooks = hooks

---@class vAvA.HookEntry
---@field id integer
---@field owner string
---@field name string
---@field phase 'before'|'after'
---@field priority integer
---@field handler function|table
---@field slowLog table  état de limitation des logs "handler lent"

-- name → { before = HookEntry[], after = HookEntry[] }
-- Les listes sont remplacées à chaque inscription/désinscription (copy-on-write), jamais modifiées en place :
-- un déclenchement en cours parcourt sa propre version, sans copie ni tri au moment du déclenchement.
local chains = {}
---@type table<integer, vAvA.HookEntry>
local entriesById = {}
local lastId = 0

---@param a vAvA.HookEntry
---@param b vAvA.HookEntry
local function runsBefore(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.id < b.id
end

---@param entry vAvA.HookEntry
local function detach(entry)
    entriesById[entry.id] = nil
    local chain = chains[entry.name]
    if not chain then return end
    local current, list = chain[entry.phase], {}
    for i = 1, #current do
        if current[i] ~= entry then list[#list + 1] = current[i] end
    end
    chain[entry.phase] = list
    if #chain.before == 0 and #chain.after == 0 then
        chains[entry.name] = nil
    end
end

--- Inscrit un handler.
---@param owner string
---@param phase 'before'|'after'
---@param name string
---@param handler function  before : renvoyer false[, raison] pour annuler · after : valeur de retour ignorée
---@param priority? integer
---@return integer|nil id
---@return string|nil err
function hooks.subscribe(owner, phase, name, handler, priority)
    if not PHASES[phase] then return nil, 'phase invalide (before ou after)' end
    if not str.isIdentifier(name) then return nil, format("nom de hook invalide '%s'", tostring(name)) end
    if not schema.isCallable(handler) then return nil, 'handler non appelable' end
    if priority == nil then
        priority = cfg.defaultPriority
    elseif mathType(priority) ~= 'integer' or priority < cfg.minPriority or priority > cfg.maxPriority then
        return nil, format('priorité invalide (entier de %d à %d)', cfg.minPriority, cfg.maxPriority)
    end

    lastId = lastId + 1
    local entry = { id = lastId, owner = owner, name = name, phase = phase, priority = priority, handler = handler, slowLog = {} }
    local chain = chains[name]
    if not chain then
        chain = { before = {}, after = {} }
        chains[name] = chain
    end
    local list = tbl.copyArray(chain[phase])
    list[#list + 1] = entry
    sort(list, runsBefore)
    chain[phase] = list
    entriesById[entry.id] = entry
    return entry.id
end

--- Désinscrit un handler. Seul son propriétaire peut le retirer.
---@param owner string
---@param id integer
---@return boolean ok
---@return string|nil err
function hooks.unsubscribe(owner, id)
    local entry = entriesById[id]
    if not entry then return false, 'hook inconnu' end
    if entry.owner ~= owner then return false, 'ce hook appartient à une autre ressource' end
    detach(entry)
    return true
end

--- Retire tous les handlers d'un propriétaire (ressource arrêtée ou module en échec).
---@param owner string
---@return integer count
function hooks.purgeOwner(owner)
    local owned = {}
    for _, entry in pairs(entriesById) do
        if entry.owner == owner then owned[#owned + 1] = entry end
    end
    for i = 1, #owned do
        detach(owned[i])
    end
    return #owned
end

---@param entry vAvA.HookEntry
---@param payload any
---@return boolean ok
---@return any result
---@return any reason
local function invoke(entry, payload)
    local startedAt = GetGameTimer()
    local ok, result, reason = xpcall(entry.handler, traceback, payload)
    local elapsed = GetGameTimer() - startedAt
    if elapsed > cfg.slowHandlerMs then
        local allowed, suppressed = logger.throttle(entry.slowLog)
        if allowed then
            log.warn("handler lent sur '%s' (%s, priorité %d, ressource %s) : %d ms%s",
                entry.name, entry.phase, entry.priority, entry.owner, elapsed, logger.suppressedNote(suppressed))
        end
    end
    return ok, result, reason
end

---@param entry vAvA.HookEntry
---@param err any
local function reportError(entry, err)
    local allowed, suppressed = logger.throttle(entry)
    if allowed then
        log.error("handler %s de '%s' (ressource %s) en erreur%s : %s",
            entry.phase, entry.name, entry.owner, logger.suppressedNote(suppressed), tostring(err))
    end
end

--- Exécute les handlers "before". S'arrête au premier refus ou à la première erreur.
--- Le payload est en lecture seule par contrat : une autre ressource n'en reçoit qu'une copie.
---@param name string
---@param payload any
---@return boolean allowed
---@return string|nil reason  raison du refus, ou 'hook_error'
function hooks.runBefore(name, payload)
    local chain = chains[name]
    if not chain then return true end
    local list = chain.before
    for i = 1, #list do
        local entry = list[i]
        -- un handler retiré pendant que la chaîne attendait (ressource arrêtée) n'est plus appelé
        if entriesById[entry.id] == entry then
            local ok, result, reason = invoke(entry, payload)
            if not ok then
                reportError(entry, result)
                return false, 'hook_error'
            end
            if result == false then
                return false, type(reason) == 'string' and reason or 'cancelled'
            end
        end
    end
    return true
end

--- Exécute les handlers "after". Une erreur est journalisée et n'interrompt pas les suivants.
---@param name string
---@param payload any
function hooks.runAfter(name, payload)
    local chain = chains[name]
    if not chain then return end
    local list = chain.after
    for i = 1, #list do
        local entry = list[i]
        if entriesById[entry.id] == entry then
            local ok, err = invoke(entry, payload)
            if not ok then reportError(entry, err) end
        end
    end
end
