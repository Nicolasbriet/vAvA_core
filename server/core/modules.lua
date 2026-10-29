--[[
    server/core/modules.lua
    Rôle : déclaration et cycle de vie des modules.
      declared → waiting (core prêt, dépendances prêtes et en bonne version) → migrating → starting (setup) → ready
      Un échec à n'importe quelle étape : failed, message explicite, purge de tout ce que le module a enregistré.
    Le nom d'un module est celui de sa ressource (imposé) : aucune ressource ne peut se faire passer pour une autre.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/table.lua, shared/lib/semver.lua, shared/lib/schema.lua,
                  shared/core/logger.lua, shared/core/hooks.lua, server/core/migrations.lua
]]

local type, tostring, pairs, xpcall = type, tostring, pairs, xpcall
local traceback = debug.traceback
local format = string.format
local concat, sort = table.concat, table.sort
local CreateThread, SetTimeout, GetResourceState = CreateThread, SetTimeout, GetResourceState
local newPromise, await = promise.new, Citizen.Await

local tbl = vAvA.lib.table
local semver = vAvA.lib.semver
local schema = vAvA.lib.schema
local hooks = vAvA.hooks
local migrations = vAvA.migrations
local cfg = vAvA.config.server.modules
local log = vAvA.logger.create('modules')

local CORE_OWNER = vAvA.CORE_OWNER
local HOOK_READY = 'core:module:ready'
local HOOK_FAILED = 'core:module:failed'
local HOOK_STOPPED = 'core:module:stopped'

-- Une ressource démarrée ou en cours de démarrage peut encore se déclarer : on l'attend.
local RUNNING_STATES = { started = true, starting = true }

local modules = {}
vAvA.modules = modules

---@alias vAvA.ModuleState 'declared'|'waiting'|'migrating'|'starting'|'ready'|'failed'

---@class vAvA.ModuleRecord
---@field name string
---@field version string
---@field coreVersion string
---@field dependencies table<string, string>  nom → version minimale
---@field setup? function
---@field state vAvA.ModuleState
---@field error? string

---@type table<string, vAvA.ModuleRecord>
local records = {}
-- nom → attentes { settled, promise } résolues par 'ready' | 'failed' | 'stopped' | 'timeout'
local waiters = {}
local coreState, coreError = 'booting', nil
---@type fun(owner: string)
local purgeOwner = function() end

---@param name string
---@param outcome string
local function settle(name, outcome)
    local list = waiters[name]
    if not list then return end
    waiters[name] = nil
    for i = 1, #list do
        local waiter = list[i]
        if not waiter.settled then
            waiter.settled = true
            waiter.promise:resolve(outcome)
        end
    end
end

--- Attend que `name` atteigne un état final. Bloque le thread courant.
---@param name string
---@param timeoutMs? integer  sans timeout : attente jusqu'à l'état final
---@return string outcome
local function waitFor(name, timeoutMs)
    local waiter = { settled = false, promise = newPromise() }
    local list = waiters[name]
    if not list then
        list = {}
        waiters[name] = list
    end
    list[#list + 1] = waiter
    if timeoutMs then
        SetTimeout(timeoutMs, function()
            if waiter.settled then return end
            waiter.settled = true
            local current = waiters[name]
            if current then
                tbl.removeValue(current, waiter)
                if #current == 0 then waiters[name] = nil end
            end
            waiter.promise:resolve('timeout')
        end)
    end
    return await(waiter.promise)
end

--- Vrai si `from` dépend, directement ou non, de `target` parmi les modules déclarés.
---@param from string
---@param target string
---@param visited table<string, boolean>
---@return boolean
local function dependsOn(from, target, visited)
    if from == target then return true end
    if visited[from] then return false end
    visited[from] = true
    local record = records[from]
    if not record then return false end
    for depName in pairs(record.dependencies) do
        if dependsOn(depName, target, visited) then return true end
    end
    return false
end

---@param record vAvA.ModuleRecord
---@return boolean
local function isCurrent(record)
    return records[record.name] == record
end

---@param record vAvA.ModuleRecord
---@param reason string
local function fail(record, reason)
    if not isCurrent(record) then return end
    record.state = 'failed'
    record.error = reason
    record.setup = nil
    log.error("module '%s' v%s refusé : %s", record.name, record.version, reason)
    purgeOwner(record.name)
    settle(record.name, 'failed')
    hooks.runAfter(HOOK_FAILED, { name = record.name, version = record.version, reason = reason })
end

---@param record vAvA.ModuleRecord
---@param depName string
---@param minVersion string
---@return boolean ok
---@return string|nil err
local function checkDependency(record, depName, minVersion)
    local resourceState = GetResourceState(depName)
    if not RUNNING_STATES[resourceState] then
        return false, format("dépendance '%s' absente ou arrêtée (état de la ressource : %s)", depName, resourceState)
    end
    if dependsOn(depName, record.name, {}) then
        return false, format("dépendance circulaire avec '%s'", depName)
    end

    local dep = records[depName]
    if not dep or dep.state ~= 'ready' then
        if dep and dep.state == 'failed' then
            return false, format("dépendance '%s' en échec : %s", depName, tostring(dep.error))
        end
        local outcome = waitFor(depName, cfg.dependencyTimeoutMs)
        if not isCurrent(record) then return false, "module arrêté pendant l'attente" end
        if outcome == 'timeout' then
            return false, format("'%s' ne s'est pas déclaré comme module vAvA ou n'est pas prêt après %d ms", depName, cfg.dependencyTimeoutMs)
        elseif outcome ~= 'ready' then
            return false, format("dépendance '%s' %s", depName, outcome == 'failed' and 'en échec' or 'arrêtée')
        end
        dep = records[depName]
        if not dep then return false, format("dépendance '%s' arrêtée", depName) end
    end

    if not semver.satisfiesMin(dep.version, minVersion) then
        return false, format("'%s' v%s installé, v%s minimum requis", depName, dep.version, minVersion)
    end
    return true
end

---@param record vAvA.ModuleRecord
local function start(record)
    record.state = 'waiting'
    if coreState ~= 'ready' then
        local outcome = coreState == 'failed' and 'failed' or waitFor(CORE_OWNER)
        if outcome ~= 'ready' then
            return fail(record, "le core n'a pas pu démarrer : " .. tostring(coreError))
        end
    end
    if not isCurrent(record) then return end

    if not semver.satisfiesMin(vAvA.version, record.coreVersion) then
        return fail(record, format('requiert vAvA_core v%s minimum (installé : v%s)', record.coreVersion, vAvA.version))
    end

    for depName, minVersion in pairs(record.dependencies) do
        local ok, err = checkDependency(record, depName, minVersion)
        if not ok then return fail(record, err) end
    end

    record.state = 'migrating'
    local migrated, migrationErr = migrations.apply(record.name, record.name)
    if not isCurrent(record) then return end
    if not migrated then return fail(record, 'migrations : ' .. migrationErr) end

    record.state = 'starting'
    if record.setup then
        local called, result, reason = xpcall(record.setup, traceback)
        if not isCurrent(record) then return end
        if not called then return fail(record, 'erreur dans setup : ' .. tostring(result)) end
        if result == false then
            return fail(record, 'setup a refusé le démarrage : ' .. tostring(reason or 'aucune raison donnée'))
        end
    end

    record.state = 'ready'
    -- la référence vers setup n'a plus d'usage : la libérer permet à FiveM de récupérer la funcref
    record.setup = nil
    log.info("module '%s' v%s prêt", record.name, record.version)
    settle(record.name, 'ready')
    hooks.runAfter(HOOK_READY, { name = record.name, version = record.version })
end

---@class vAvA.ModuleDefinition
---@field version string                         version du module (MAJEUR.MINEUR.CORRECTIF)
---@field coreVersion string                     version minimale du core
---@field dependencies? table<string, string>    module → version minimale
---@field setup? fun(): (boolean?, string?)      appelé une fois prêt ; false[, raison] pour refuser

---@param owner string
---@param def any
---@return vAvA.ModuleRecord|nil
---@return string|nil err
local function buildRecord(owner, def)
    if type(def) ~= 'table' then
        return nil, 'définition de module attendue (table)'
    end
    if not semver.parse(def.version) then
        return nil, format("version invalide '%s' (attendu : MAJEUR.MINEUR.CORRECTIF)", tostring(def.version))
    end
    if not semver.parse(def.coreVersion) then
        return nil, format("coreVersion invalide '%s' (attendu : MAJEUR.MINEUR.CORRECTIF)", tostring(def.coreVersion))
    end
    local dependencies = {}
    if def.dependencies ~= nil then
        if type(def.dependencies) ~= 'table' then
            return nil, 'dependencies doit être une table { nomDuModule = versionMinimale }'
        end
        for depName, minVersion in pairs(def.dependencies) do
            if type(depName) ~= 'string' or depName == '' then
                return nil, 'nom de dépendance invalide'
            end
            if depName == owner then
                return nil, 'un module ne peut pas dépendre de lui-même'
            end
            if not semver.parse(minVersion) then
                return nil, format("version minimale invalide pour '%s' : '%s'", depName, tostring(minVersion))
            end
            dependencies[depName] = minVersion
        end
    end
    if def.setup ~= nil and not schema.isCallable(def.setup) then
        return nil, 'setup doit être une fonction'
    end
    return {
        name = owner, version = def.version, coreVersion = def.coreVersion,
        dependencies = dependencies, setup = def.setup, state = 'declared',
    }
end

--- Déclare un module. Ne bloque pas : la validation de forme est immédiate, le démarrage est asynchrone.
---@param owner string
---@param def vAvA.ModuleDefinition
---@return boolean ok
---@return string|nil err
function modules.declare(owner, def)
    if owner == CORE_OWNER or owner == vAvA.resourceName then
        return false, format("nom de module réservé '%s'", owner)
    end
    local existing = records[owner]
    if existing then
        return false, format("module '%s' déjà déclaré (état : %s)", owner, existing.state)
    end
    local record, err = buildRecord(owner, def)
    if not record then
        log.error("module '%s' refusé : %s", owner, err)
        return false, err
    end
    records[owner] = record
    CreateThread(function()
        local ok, crash = xpcall(start, traceback, record)
        if not ok then fail(record, 'erreur interne au démarrage : ' .. tostring(crash)) end
    end)
    return true
end

--- Vrai si le module peut utiliser l'API (pendant setup et une fois prêt).
---@param name string
---@return boolean
function modules.isActive(name)
    local record = records[name]
    return record ~= nil and (record.state == 'starting' or record.state == 'ready')
end

---@class vAvA.ModuleInfo
---@field name string
---@field version string
---@field state vAvA.ModuleState
---@field error? string
---@field dependencies table<string, string>

---@param record vAvA.ModuleRecord
---@return vAvA.ModuleInfo
local function describe(record)
    local dependencies = {}
    for depName, minVersion in pairs(record.dependencies) do
        dependencies[depName] = minVersion
    end
    return { name = record.name, version = record.version, state = record.state, error = record.error, dependencies = dependencies }
end

---@param name string
---@return vAvA.ModuleInfo|nil
function modules.get(name)
    local record = records[name]
    return record and describe(record)
end

---@return vAvA.ModuleInfo[]
function modules.list()
    local result = {}
    local names = tbl.sortedKeys(records)
    for i = 1, #names do
        result[i] = describe(records[names[i]])
    end
    return result
end

--- Arrêt d'une ressource : le module disparaît, ceux qui en dépendent sont signalés.
---@param name string
function modules.handleStop(name)
    local record = records[name]
    if not record then return end
    records[name] = nil
    settle(name, 'stopped')

    local dependents = {}
    for otherName, other in pairs(records) do
        if other.dependencies[name] and (other.state == 'starting' or other.state == 'ready') then
            dependents[#dependents + 1] = otherName
        end
    end
    if #dependents > 0 then
        sort(dependents)
        log.warn("module '%s' arrêté : %s en dépend(ent) et fonctionne(nt) désormais sans lui", name, concat(dependents, ', '))
    else
        log.info("module '%s' arrêté", name)
    end
    hooks.runAfter(HOOK_STOPPED, { name = name, version = record.version, dependents = dependents })
end

--- Injecte la purge des enregistrements d'un propriétaire (définie par init.lua, qui connaît tous les sous-systèmes).
---@param handler fun(owner: string)
function modules.setPurgeHandler(handler)
    purgeOwner = handler
end

function modules.setCoreReady()
    coreState = 'ready'
    settle(CORE_OWNER, 'ready')
end

---@return boolean
function modules.isCoreReady()
    return coreState == 'ready'
end

--- Attend la fin du démarrage du core (connexion d'un joueur pendant le boot). Bloque le thread courant.
--- Bornée : chaque tentative de connexion ajoute une attente, qui ne doit pas durer indéfiniment si le démarrage
--- reste bloqué (base injoignable). Les modules, eux, attendent le core sans limite (start) : leur nombre est
--- fixe, et un module en échec le resterait jusqu'au redémarrage alors que le core finit par démarrer.
---@param timeoutMs integer
---@return boolean ready
---@return string|nil reason  'failed' (le core a échoué) ou 'timeout' (toujours en démarrage)
function modules.awaitCore(timeoutMs)
    if coreState == 'booting' then waitFor(CORE_OWNER, timeoutMs) end
    if coreState == 'ready' then return true end
    return false, coreState == 'failed' and 'failed' or 'timeout'
end

---@param reason string
function modules.setCoreFailed(reason)
    coreState, coreError = 'failed', reason
    settle(CORE_OWNER, 'failed')
end
