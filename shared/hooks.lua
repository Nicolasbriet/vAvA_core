--[[
    vAvA_core - Hooks System
    Système de hooks pour étendre les fonctionnalités
]]

vCore = vCore or {}
vCore.Hooks = {}

local hooks = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK REGISTRATION
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un hook
---@param hookName string
---@param callback function
---@param priority? number Plus petit = exécuté en premier (défaut: 10)
---@return number hookId
function vCore.Hooks.Register(hookName, callback, priority)
    priority = priority or 10
    
    if not hooks[hookName] then
        hooks[hookName] = {}
    end
    
    local hookId = #hooks[hookName] + 1
    
    table.insert(hooks[hookName], {
        id = hookId,
        callback = callback,
        priority = priority
    })
    
    -- Trier par priorité
    table.sort(hooks[hookName], function(a, b)
        return a.priority < b.priority
    end)
    
    return hookId
end

---Désenregistre un hook
---@param hookName string
---@param hookId number
function vCore.Hooks.Unregister(hookName, hookId)
    if not hooks[hookName] then return end
    
    for i, hook in ipairs(hooks[hookName]) do
        if hook.id == hookId then
            table.remove(hooks[hookName], i)
            break
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOK EXECUTION
-- ═══════════════════════════════════════════════════════════════════════════

---Déclenche un hook (tous les callbacks sont exécutés)
---@param hookName string
---@param ... any Arguments passés aux callbacks
function vCore.Hooks.Trigger(hookName, ...)
    if not hooks[hookName] then return end
    
    for _, hook in ipairs(hooks[hookName]) do
        local success, err = pcall(hook.callback, ...)
        if not success then
            vCore.Utils.Error('Erreur hook', hookName, ':', err)
        end
    end
end

---Déclenche un hook et retourne les résultats
---@param hookName string
---@param ... any Arguments
---@return table Tableau des résultats
function vCore.Hooks.TriggerWithResults(hookName, ...)
    if not hooks[hookName] then return {} end
    
    local results = {}
    
    for _, hook in ipairs(hooks[hookName]) do
        local success, result = pcall(hook.callback, ...)
        if success then
            table.insert(results, result)
        else
            vCore.Utils.Error('Erreur hook', hookName, ':', result)
        end
    end
    
    return results
end

---Déclenche un hook avec possibilité de stopper la chaîne
---@param hookName string
---@param ... any Arguments
---@return boolean stopped Si true, un callback a stoppé la chaîne
function vCore.Hooks.TriggerStoppable(hookName, ...)
    if not hooks[hookName] then return false end
    
    for _, hook in ipairs(hooks[hookName]) do
        local success, shouldStop = pcall(hook.callback, ...)
        if success and shouldStop == true then
            return true  -- Un callback a demandé l'arrêt
        elseif not success then
            vCore.Utils.Error('Erreur hook', hookName, ':', shouldStop)
        end
    end
    
    return false
end

---Déclenche un hook qui modifie une valeur
---@param hookName string
---@param value any Valeur initiale
---@param ... any Arguments additionnels
---@return any Valeur modifiée
function vCore.Hooks.Filter(hookName, value, ...)
    if not hooks[hookName] then return value end
    
    local currentValue = value
    
    for _, hook in ipairs(hooks[hookName]) do
        local success, result = pcall(hook.callback, currentValue, ...)
        if success then
            currentValue = result
        else
            vCore.Utils.Error('Erreur hook filter', hookName, ':', result)
        end
    end
    
    return currentValue
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HOOKS PRÉDÉFINIS
-- ═══════════════════════════════════════════════════════════════════════════

-- Player hooks
vCore.Hooks.PLAYER_CONNECTING = 'vCore:playerConnecting'
vCore.Hooks.PLAYER_LOADED = 'vCore:playerLoaded'
vCore.Hooks.PLAYER_DISCONNECTED = 'vCore:playerDisconnected'
vCore.Hooks.PLAYER_SAVED = 'vCore:playerSaved'

-- Money hooks
vCore.Hooks.BEFORE_MONEY_ADD = 'vCore:beforeMoneyAdd'
vCore.Hooks.AFTER_MONEY_ADD = 'vCore:afterMoneyAdd'
vCore.Hooks.BEFORE_MONEY_REMOVE = 'vCore:beforeMoneyRemove'
vCore.Hooks.AFTER_MONEY_REMOVE = 'vCore:afterMoneyRemove'

-- Job hooks
vCore.Hooks.BEFORE_JOB_CHANGE = 'vCore:beforeJobChange'
vCore.Hooks.AFTER_JOB_CHANGE = 'vCore:afterJobChange'

-- Item hooks
vCore.Hooks.BEFORE_ITEM_ADD = 'vCore:beforeItemAdd'
vCore.Hooks.AFTER_ITEM_ADD = 'vCore:afterItemAdd'
vCore.Hooks.BEFORE_ITEM_REMOVE = 'vCore:beforeItemRemove'
vCore.Hooks.AFTER_ITEM_REMOVE = 'vCore:afterItemRemove'
vCore.Hooks.ITEM_USED = 'vCore:itemUsed'

-- Vehicle hooks
vCore.Hooks.VEHICLE_SPAWNED = 'vCore:vehicleSpawned'
vCore.Hooks.VEHICLE_STORED = 'vCore:vehicleStored'

-- Command hooks
vCore.Hooks.BEFORE_COMMAND = 'vCore:beforeCommand'
vCore.Hooks.AFTER_COMMAND = 'vCore:afterCommand'

-- System hooks
vCore.Hooks.SERVER_READY = 'vCore:serverReady'
vCore.Hooks.MODULE_LOADED = 'vCore:moduleLoaded'

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITIES
-- ═══════════════════════════════════════════════════════════════════════════

---Obtient tous les hooks enregistrés pour un nom
---@param hookName string
---@return table
function vCore.Hooks.GetHooks(hookName)
    return hooks[hookName] or {}
end

---Obtient le nombre de hooks pour un nom
---@param hookName string
---@return number
function vCore.Hooks.Count(hookName)
    return #(hooks[hookName] or {})
end

---Vérifie si un hook existe
---@param hookName string
---@return boolean
function vCore.Hooks.Exists(hookName)
    return hooks[hookName] ~= nil and #hooks[hookName] > 0
end

---Supprime tous les hooks d'un nom
---@param hookName string
function vCore.Hooks.Clear(hookName)
    hooks[hookName] = nil
end

---Supprime tous les hooks
function vCore.Hooks.ClearAll()
    hooks = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉCORATEURS
-- ═══════════════════════════════════════════════════════════════════════════

---Décore une fonction avec des hooks before/after
---@param hookName string
---@param func function
---@return function
function vCore.Hooks.Decorate(hookName, func)
    return function(...)
        -- Before hook
        local stopped = vCore.Hooks.TriggerStoppable('before:' .. hookName, ...)
        if stopped then
            return nil  -- Hook a stoppé l'exécution
        end
        
        -- Exécuter fonction originale
        local results = {func(...)}
        
        -- After hook
        vCore.Hooks.Trigger('after:' .. hookName, ...)
        
        return table.unpack(results)
    end
end

---Décore une fonction avec un hook filter
---@param hookName string
---@param func function
---@return function
function vCore.Hooks.DecorateFilter(hookName, func)
    return function(...)
        local result = func(...)
        return vCore.Hooks.Filter(hookName, result, ...)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHORTCUTS
-- ═══════════════════════════════════════════════════════════════════════════

---Alias pour Register
---@param hookName string
---@param callback function
---@param priority? number
---@return number
function vCore.Hook(hookName, callback, priority)
    return vCore.Hooks.Register(hookName, callback, priority)
end

---Alias pour Trigger
---@param hookName string
---@param ... any
function vCore.TriggerHook(hookName, ...)
    vCore.Hooks.Trigger(hookName, ...)
end

---Alias pour Filter
---@param hookName string
---@param value any
---@param ... any
---@return any
function vCore.FilterHook(hookName, value, ...)
    return vCore.Hooks.Filter(hookName, value, ...)
end

print('^2[vCore:Hooks]^7 Système de hooks chargé')
