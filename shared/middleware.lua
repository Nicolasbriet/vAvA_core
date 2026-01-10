--[[
    vAvA_core - Middleware System
    Système de middleware pour requêtes/commandes
]]

vCore = vCore or {}
vCore.Middleware = {}

local middlewares = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- MIDDLEWARE STACK
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un middleware
---@param name string
---@param handler function(context, next)
---@param priority? number
function vCore.Middleware.Register(name, handler, priority)
    priority = priority or 10
    
    table.insert(middlewares, {
        name = name,
        handler = handler,
        priority = priority
    })
    
    -- Trier par priorité
    table.sort(middlewares, function(a, b)
        return a.priority < b.priority
    end)
    
    vCore.Utils.Debug('Middleware enregistré:', name)
end

---Exécute une stack de middleware
---@param context table Contexte partagé
---@param finalHandler function Handler final
function vCore.Middleware.Execute(context, finalHandler)
    local index = 0
    
    local function next()
        index = index + 1
        
        if index <= #middlewares then
            local middleware = middlewares[index]
            
            local success, result = pcall(middleware.handler, context, next)
            
            if not success then
                vCore.Utils.Error('Erreur middleware', middleware.name, ':', result)
                return false
            end
            
            return result
        else
            -- Tous les middlewares passés, exécuter le handler final
            if finalHandler then
                return finalHandler(context)
            end
            return true
        end
    end
    
    return next()
end

---Supprime un middleware
---@param name string
function vCore.Middleware.Unregister(name)
    for i, middleware in ipairs(middlewares) do
        if middleware.name == name then
            table.remove(middlewares, i)
            vCore.Utils.Debug('Middleware supprimé:', name)
            return true
        end
    end
    return false
end

---Obtient tous les middlewares
---@return table
function vCore.Middleware.GetAll()
    return middlewares
end

---Vide tous les middlewares
function vCore.Middleware.Clear()
    middlewares = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MIDDLEWARES PRÉDÉFINIS
-- ═══════════════════════════════════════════════════════════════════════════

---Middleware de logging
vCore.Middleware.Logger = function(context, next)
    local startTime = GetGameTimer()
    
    vCore.Utils.Debug('[Middleware] Début:', context.action or 'unknown')
    
    local result = next()
    
    local duration = GetGameTimer() - startTime
    vCore.Utils.Debug('[Middleware] Fin:', context.action, 'en', duration, 'ms')
    
    return result
end

---Middleware de validation de source (serveur)
vCore.Middleware.ValidateSource = function(context, next)
    if not IsDuplicityVersion() then
        return next()
    end
    
    if not context.source or context.source < 1 then
        vCore.Utils.Error('[Middleware] Source invalide')
        return false
    end
    
    return next()
end

---Middleware de vérification de permission
---@param minLevel number
vCore.Middleware.RequirePermission = function(minLevel)
    return function(context, next)
        if not IsDuplicityVersion() then
            return next()
        end
        
        if not vCore.Permissions.HasLevel(context.source, minLevel) then
            vCore.Utils.Warn('[Middleware] Permission refusée:', context.source)
            
            if context.source then
                vCore.UI.Notify(context.source, {
                    message = 'Permission refusée',
                    type = 'error'
                })
            end
            
            return false
        end
        
        return next()
    end
end

---Middleware de vérification de job
---@param jobName string
---@param minGrade? number
vCore.Middleware.RequireJob = function(jobName, minGrade)
    return function(context, next)
        if not IsDuplicityVersion() then
            return next()
        end
        
        if not vCore.Permissions.HasJob(context.source, jobName, minGrade) then
            vCore.Utils.Warn('[Middleware] Job requis:', jobName)
            
            if context.source then
                vCore.UI.Notify(context.source, {
                    message = 'Job requis: ' .. jobName,
                    type = 'error'
                })
            end
            
            return false
        end
        
        return next()
    end
end

---Middleware de rate limiting
---@param maxCalls number Maximum d'appels
---@param window number Fenêtre en secondes
vCore.Middleware.RateLimit = function(maxCalls, window)
    local calls = {}
    
    return function(context, next)
        local source = context.source or 'global'
        local now = os.time()
        
        -- Initialiser si nécessaire
        if not calls[source] then
            calls[source] = {}
        end
        
        -- Nettoyer les anciennes entrées
        local recent = {}
        for _, timestamp in ipairs(calls[source]) do
            if now - timestamp < window then
                table.insert(recent, timestamp)
            end
        end
        calls[source] = recent
        
        -- Vérifier limite
        if #calls[source] >= maxCalls then
            vCore.Utils.Warn('[Middleware] Rate limit atteint:', source)
            
            if context.source then
                vCore.UI.Notify(context.source, {
                    message = 'Trop de requêtes, attendez un peu',
                    type = 'warning'
                })
            end
            
            return false
        end
        
        -- Enregistrer appel
        table.insert(calls[source], now)
        
        return next()
    end
end

---Middleware de validation de données
---@param schema table Schéma de validation
vCore.Middleware.ValidateData = function(schema)
    return function(context, next)
        if not context.data then
            vCore.Utils.Error('[Middleware] Données manquantes')
            return false
        end
        
        for field, validator in pairs(schema) do
            local value = context.data[field]
            
            if validator.required and value == nil then
                vCore.Utils.Error('[Middleware] Champ requis manquant:', field)
                return false
            end
            
            if value ~= nil and validator.validate then
                local valid, err = validator.validate(value)
                if not valid then
                    vCore.Utils.Error('[Middleware] Validation échouée:', field, err)
                    return false
                end
            end
        end
        
        return next()
    end
end

---Middleware de sanitization
vCore.Middleware.Sanitize = function(context, next)
    if context.data and type(context.data) == 'table' then
        for key, value in pairs(context.data) do
            if type(value) == 'string' then
                -- Supprimer caractères dangereux
                context.data[key] = value:gsub('[<>\'"]', '')
            end
        end
    end
    
    return next()
end

---Middleware de cache
---@param ttl number Durée de vie en secondes
vCore.Middleware.Cache = function(ttl)
    local cache = {}
    
    return function(context, next)
        local key = json.encode(context.data or {})
        local now = os.time()
        
        -- Vérifier cache
        if cache[key] and (now - cache[key].time) < ttl then
            vCore.Utils.Debug('[Middleware] Cache hit')
            context.result = cache[key].result
            return true
        end
        
        -- Exécuter
        local result = next()
        
        -- Mettre en cache
        if result and context.result then
            cache[key] = {
                result = context.result,
                time = now
            }
        end
        
        return result
    end
end

---Middleware de retry
---@param maxRetries number
---@param delay number Délai en ms
vCore.Middleware.Retry = function(maxRetries, delay)
    return function(context, next)
        local attempts = 0
        local lastError
        
        while attempts < maxRetries do
            attempts = attempts + 1
            
            local success, result = pcall(next)
            
            if success and result then
                return result
            else
                lastError = result or 'Échec'
                vCore.Utils.Warn('[Middleware] Tentative', attempts, '/', maxRetries, 'échouée')
                
                if attempts < maxRetries then
                    Citizen.Wait(delay)
                end
            end
        end
        
        vCore.Utils.Error('[Middleware] Échec après', maxRetries, 'tentatives:', lastError)
        return false
    end
end

---Middleware de mesure de performance
vCore.Middleware.Benchmark = function(context, next)
    local startTime = GetGameTimer()
    local startMemory = collectgarbage('count')
    
    local result = next()
    
    local endTime = GetGameTimer()
    local endMemory = collectgarbage('count')
    
    local duration = endTime - startTime
    local memoryUsed = endMemory - startMemory
    
    vCore.Utils.Debug('[Benchmark]', context.action, ':', duration, 'ms,', memoryUsed, 'KB')
    
    context.metrics = {
        duration = duration,
        memory = memoryUsed
    }
    
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MIDDLEWARE BUILDER
-- ═══════════════════════════════════════════════════════════════════════════

---Crée un groupe de middlewares
---@param middlewareList table
---@return function
function vCore.Middleware.Group(middlewareList)
    return function(context, finalHandler)
        local index = 0
        
        local function next()
            index = index + 1
            
            if index <= #middlewareList then
                return middlewareList[index](context, next)
            else
                if finalHandler then
                    return finalHandler(context)
                end
                return true
            end
        end
        
        return next()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLES
-- ═══════════════════════════════════════════════════════════════════════════

--[[
EXEMPLES D'UTILISATION:

-- Enregistrer middlewares globaux
vCore.Middleware.Register('logger', vCore.Middleware.Logger, 1)
vCore.Middleware.Register('validate', vCore.Middleware.ValidateSource, 5)
vCore.Middleware.Register('sanitize', vCore.Middleware.Sanitize, 10)

-- Exécuter avec middlewares
vCore.Middleware.Execute({
    source = source,
    action = 'transfer_money',
    data = { amount = 1000, target = 2 }
}, function(context)
    -- Handler final
    print('Transfert de', context.data.amount, 'vers', context.data.target)
    return true
end)

-- Middleware spécifique pour une action
local transferMiddleware = vCore.Middleware.Group({
    vCore.Middleware.ValidateSource,
    vCore.Middleware.RequirePermission(vCore.PermissionLevel.USER),
    vCore.Middleware.RateLimit(5, 60),  -- 5 appels par minute
    vCore.Middleware.ValidateData({
        amount = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 999999) end
        },
        target = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 1024) end
        }
    }),
    vCore.Middleware.Sanitize
})

-- Utiliser le groupe
transferMiddleware({ source = source, data = data }, function(ctx)
    -- Code du transfert
end)
]]

print('^2[vCore:Middleware]^7 Système de middleware chargé')
