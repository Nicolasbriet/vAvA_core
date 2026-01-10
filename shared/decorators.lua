--[[
    vAvA_core - Decorators
    Décorateurs pour fonctions (retry, cache, validation, etc.)
]]

vCore = vCore or {}
vCore.Decorators = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- RETRY DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour retry automatique
---@param func function
---@param maxRetries? number Nombre max de tentatives (défaut: 3)
---@param delay? number Délai entre tentatives en ms (défaut: 1000)
---@return function
function vCore.Decorators.Retry(func, maxRetries, delay)
    maxRetries = maxRetries or 3
    delay = delay or 1000
    
    return function(...)
        local args = {...}
        local attempts = 0
        local lastError
        
        while attempts < maxRetries do
            attempts = attempts + 1
            
            local success, result = pcall(func, table.unpack(args))
            
            if success then
                return result
            else
                lastError = result
                vCore.Utils.Warn('Tentative', attempts, '/', maxRetries, 'échouée:', result)
                
                if attempts < maxRetries then
                    Citizen.Wait(delay)
                end
            end
        end
        
        vCore.Utils.Error('Échec après', maxRetries, 'tentatives:', lastError)
        return nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CACHE DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour cache de résultats
---@param func function
---@param ttl? number Durée de vie du cache en secondes (défaut: 60)
---@return function
function vCore.Decorators.Cache(func, ttl)
    ttl = ttl or 60
    local cache = {}
    
    return function(...)
        local args = {...}
        local key = json.encode(args)
        local now = os.time()
        
        -- Vérifier cache
        if cache[key] and (now - cache[key].time) < ttl then
            return cache[key].result
        end
        
        -- Exécuter fonction
        local result = func(table.unpack(args))
        
        -- Mettre en cache
        cache[key] = {
            result = result,
            time = now
        }
        
        return result
    end
end

---Décorateur pour cache memoization (permanent)
---@param func function
---@return function
function vCore.Decorators.Memoize(func)
    local cache = {}
    
    return function(...)
        local args = {...}
        local key = json.encode(args)
        
        if cache[key] ~= nil then
            return cache[key]
        end
        
        local result = func(table.unpack(args))
        cache[key] = result
        
        return result
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDATION DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour validation des arguments
---@param func function
---@param validators table Tableau de règles de validation
---@return function
function vCore.Decorators.Validate(func, validators)
    return function(...)
        local args = {...}
        
        -- Valider chaque argument
        for i, validator in ipairs(validators) do
            if validator and args[i] ~= nil then
                local valid, err = validator(args[i])
                if not valid then
                    vCore.Utils.Error('Validation échouée argument', i, ':', err)
                    return nil
                end
            end
        end
        
        return func(table.unpack(args))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- THROTTLE DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour limiter la fréquence d'appel
---@param func function
---@param delay number Délai minimum entre appels en ms
---@return function
function vCore.Decorators.Throttle(func, delay)
    local lastCall = 0
    local scheduled = false
    local lastArgs = {}
    
    return function(...)
        local now = GetGameTimer()
        lastArgs = {...}
        
        if now - lastCall >= delay then
            lastCall = now
            return func(table.unpack(lastArgs))
        elseif not scheduled then
            scheduled = true
            
            Citizen.SetTimeout(delay - (now - lastCall), function()
                lastCall = GetGameTimer()
                scheduled = false
                func(table.unpack(lastArgs))
            end)
        end
    end
end

---Décorateur pour debounce (attendre la fin des appels)
---@param func function
---@param delay number Délai d'attente en ms
---@return function
function vCore.Decorators.Debounce(func, delay)
    local timer = nil
    
    return function(...)
        local args = {...}
        
        if timer then
            ClearTimeout(timer)
        end
        
        timer = SetTimeout(function()
            timer = nil
            func(table.unpack(args))
        end, delay)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TIMING DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour mesurer le temps d'exécution
---@param func function
---@param name? string Nom pour les logs
---@return function
function vCore.Decorators.Time(func, name)
    name = name or 'Function'
    
    return function(...)
        local startTime = GetGameTimer()
        local results = {func(...)}
        local endTime = GetGameTimer()
        local duration = endTime - startTime
        
        vCore.Utils.Debug(name, 'executed in', duration, 'ms')
        
        return table.unpack(results)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PERMISSION DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour vérifier les permissions (serveur uniquement)
---@param func function
---@param minLevel number
---@return function
function vCore.Decorators.RequirePermission(func, minLevel)
    if not IsDuplicityVersion() then
        return func
    end
    
    return function(source, ...)
        if not vCore.Permissions.HasLevel(source, minLevel) then
            vCore.Utils.Warn('Permission refusée pour source', source)
            return nil
        end
        
        return func(source, ...)
    end
end

---Décorateur pour vérifier le job (serveur uniquement)
---@param func function
---@param jobName string
---@param minGrade? number
---@return function
function vCore.Decorators.RequireJob(func, jobName, minGrade)
    if not IsDuplicityVersion() then
        return func
    end
    
    return function(source, ...)
        if not vCore.Permissions.HasJob(source, jobName, minGrade) then
            vCore.Utils.Warn('Job requis non satisfait pour source', source)
            return nil
        end
        
        return func(source, ...)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ASYNC DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour rendre une fonction asynchrone
---@param func function
---@return function
function vCore.Decorators.Async(func)
    return function(...)
        local args = {...}
        
        Citizen.CreateThread(function()
            func(table.unpack(args))
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SAFE DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour exécution safe avec gestion d'erreur
---@param func function
---@param onError? function Callback en cas d'erreur
---@return function
function vCore.Decorators.Safe(func, onError)
    return function(...)
        local success, result = pcall(func, ...)
        
        if not success then
            vCore.Utils.Error('Erreur dans fonction safe:', result)
            
            if onError then
                return onError(result)
            end
            
            return nil
        end
        
        return result
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ONCE DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour fonction exécutable une seule fois
---@param func function
---@return function
function vCore.Decorators.Once(func)
    local called = false
    local result
    
    return function(...)
        if not called then
            called = true
            result = func(...)
        end
        
        return result
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CHAIN DECORATOR
-- ═══════════════════════════════════════════════════════════════════════════

---Décorateur pour chaîner plusieurs décorateurs
---@param func function
---@param decorators table Liste de décorateurs à appliquer
---@return function
function vCore.Decorators.Chain(func, decorators)
    local decorated = func
    
    for i = #decorators, 1, -1 do
        decorated = decorators[i](decorated)
    end
    
    return decorated
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLES
-- ═══════════════════════════════════════════════════════════════════════════

--[[
EXEMPLES D'UTILISATION:

-- Retry automatique
local robustFunction = vCore.Decorators.Retry(function()
    -- Code qui peut échouer
    return MySQL.Sync.fetchAll('SELECT * FROM users')
end, 3, 1000)  -- 3 tentatives, 1000ms entre chaque

-- Cache
local cachedQuery = vCore.Decorators.Cache(function(identifier)
    return MySQL.Sync.fetchAll('SELECT * FROM users WHERE identifier = ?', {identifier})
end, 60)  -- Cache 60 secondes

-- Validation
local validatedFunction = vCore.Decorators.Validate(function(name, age, email)
    -- Code
end, {
    function(name) return vCore.Validation.IsString(name, 1, 50) end,
    function(age) return vCore.Validation.IsNumber(age, 18, 120) end,
    function(email) return vCore.Validation.IsEmail(email) end
})

-- Throttle
local throttledSave = vCore.Decorators.Throttle(function()
    -- Sauvegarde
end, 5000)  -- Max 1 fois toutes les 5 secondes

-- Permission
local adminOnly = vCore.Decorators.RequirePermission(function(source, data)
    -- Code admin
end, vCore.PermissionLevel.ADMIN)

-- Chaîner plusieurs décorateurs
local complexFunction = vCore.Decorators.Chain(function(source, data)
    -- Code
end, {
    function(f) return vCore.Decorators.RequirePermission(f, vCore.PermissionLevel.ADMIN) end,
    function(f) return vCore.Decorators.Retry(f, 3, 1000) end,
    function(f) return vCore.Decorators.Time(f, 'ComplexFunction') end,
    function(f) return vCore.Decorators.Safe(f) end
})
]]

print('^2[vCore:Decorators]^7 Système de décorateurs chargé')
