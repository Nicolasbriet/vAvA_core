--[[
    vAvA_core - State Manager
    Gestionnaire d'état global et réactif
]]

vCore = vCore or {}
vCore.State = {}

local state = {}
local listeners = {}
local computed = {}
local history = {}
local maxHistorySize = 50

-- ═══════════════════════════════════════════════════════════════════════════
-- STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

---Définit une valeur dans le state
---@param key string
---@param value any
---@param silent? boolean Si true, ne déclenche pas les listeners
function vCore.State.Set(key, value, silent)
    local oldValue = state[key]
    
    -- Sauvegarder dans l'historique
    if oldValue ~= value then
        table.insert(history, {
            key = key,
            oldValue = oldValue,
            newValue = value,
            timestamp = os.time()
        })
        
        -- Limiter taille historique
        if #history > maxHistorySize then
            table.remove(history, 1)
        end
    end
    
    state[key] = value
    
    -- Déclencher listeners
    if not silent then
        vCore.State.NotifyListeners(key, value, oldValue)
    end
    
    -- Mettre à jour computed
    vCore.State.UpdateComputed(key)
end

---Obtient une valeur du state
---@param key string
---@param defaultValue? any
---@return any
function vCore.State.Get(key, defaultValue)
    local value = state[key]
    return value ~= nil and value or defaultValue
end

---Vérifie si une clé existe
---@param key string
---@return boolean
function vCore.State.Has(key)
    return state[key] ~= nil
end

---Supprime une clé du state
---@param key string
function vCore.State.Delete(key)
    vCore.State.Set(key, nil)
end

---Obtient tout le state
---@return table
function vCore.State.GetAll()
    return state
end

---Réinitialise tout le state
function vCore.State.Clear()
    state = {}
    listeners = {}
    computed = {}
    history = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NESTED VALUES
-- ═══════════════════════════════════════════════════════════════════════════

---Définit une valeur imbriquée (ex: "user.profile.name")
---@param path string
---@param value any
function vCore.State.SetNested(path, value)
    local keys = {}
    for key in path:gmatch('[^.]+') do
        table.insert(keys, key)
    end
    
    local current = state
    
    for i = 1, #keys - 1 do
        local key = keys[i]
        if type(current[key]) ~= 'table' then
            current[key] = {}
        end
        current = current[key]
    end
    
    local lastKey = keys[#keys]
    current[lastKey] = value
    
    -- Notifier avec le premier niveau
    vCore.State.NotifyListeners(keys[1], state[keys[1]], state[keys[1]])
end

---Obtient une valeur imbriquée
---@param path string
---@param defaultValue? any
---@return any
function vCore.State.GetNested(path, defaultValue)
    local keys = {}
    for key in path:gmatch('[^.]+') do
        table.insert(keys, key)
    end
    
    local current = state
    
    for _, key in ipairs(keys) do
        if type(current) ~= 'table' or current[key] == nil then
            return defaultValue
        end
        current = current[key]
    end
    
    return current
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LISTENERS (OBSERVERS)
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un listener sur une clé
---@param key string
---@param callback function(newValue, oldValue)
---@return number listenerId
function vCore.State.Watch(key, callback)
    if not listeners[key] then
        listeners[key] = {}
    end
    
    local listenerId = #listeners[key] + 1
    
    table.insert(listeners[key], {
        id = listenerId,
        callback = callback
    })
    
    return listenerId
end

---Supprime un listener
---@param key string
---@param listenerId number
function vCore.State.Unwatch(key, listenerId)
    if not listeners[key] then return end
    
    for i, listener in ipairs(listeners[key]) do
        if listener.id == listenerId then
            table.remove(listeners[key], i)
            break
        end
    end
end

---Notifie tous les listeners d'une clé
---@param key string
---@param newValue any
---@param oldValue any
function vCore.State.NotifyListeners(key, newValue, oldValue)
    if not listeners[key] then return end
    
    for _, listener in ipairs(listeners[key]) do
        local success, err = pcall(listener.callback, newValue, oldValue)
        if not success then
            vCore.Utils.Error('Erreur listener', key, ':', err)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPUTED VALUES
-- ═══════════════════════════════════════════════════════════════════════════

---Définit une valeur computed (recalculée automatiquement)
---@param key string
---@param dependencies table Clés dont dépend cette valeur
---@param computeFn function Fonction de calcul
function vCore.State.Computed(key, dependencies, computeFn)
    computed[key] = {
        dependencies = dependencies,
        compute = computeFn
    }
    
    -- Calculer valeur initiale
    vCore.State.UpdateComputed(key)
end

---Met à jour une valeur computed
---@param changedKey string
function vCore.State.UpdateComputed(changedKey)
    for key, comp in pairs(computed) do
        -- Vérifier si cette computed dépend de la clé changée
        local shouldUpdate = false
        
        for _, dep in ipairs(comp.dependencies) do
            if dep == changedKey then
                shouldUpdate = true
                break
            end
        end
        
        if shouldUpdate then
            local success, result = pcall(comp.compute)
            
            if success then
                vCore.State.Set(key, result, false)
            else
                vCore.Utils.Error('Erreur computed', key, ':', result)
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BATCH UPDATES
-- ═══════════════════════════════════════════════════════════════════════════

local batchMode = false
local batchChanges = {}

---Active le mode batch (regroupe les notifications)
function vCore.State.BeginBatch()
    batchMode = true
    batchChanges = {}
end

---Termine le mode batch et notifie tous les changements
function vCore.State.EndBatch()
    batchMode = false
    
    for key, change in pairs(batchChanges) do
        vCore.State.NotifyListeners(key, change.newValue, change.oldValue)
    end
    
    batchChanges = {}
end

---Met à jour plusieurs valeurs en batch
---@param updates table
function vCore.State.Update(updates)
    vCore.State.BeginBatch()
    
    for key, value in pairs(updates) do
        vCore.State.Set(key, value)
    end
    
    vCore.State.EndBatch()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HISTORY
-- ═══════════════════════════════════════════════════════════════════════════

---Obtient l'historique des changements
---@param key? string Si fourni, filtre par clé
---@return table
function vCore.State.GetHistory(key)
    if key then
        local filtered = {}
        for _, entry in ipairs(history) do
            if entry.key == key then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end
    
    return history
end

---Vide l'historique
function vCore.State.ClearHistory()
    history = {}
end

---Défait le dernier changement
---@return boolean
function vCore.State.Undo()
    if #history == 0 then
        return false
    end
    
    local lastChange = table.remove(history)
    vCore.State.Set(lastChange.key, lastChange.oldValue, true)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PERSISTENCE
-- ═══════════════════════════════════════════════════════════════════════════

---Sauvegarde le state (serveur uniquement)
---@param identifier string
function vCore.State.Save(identifier)
    if not IsDuplicityVersion() then
        vCore.Utils.Warn('State.Save() disponible uniquement côté serveur')
        return
    end
    
    local serialized = json.encode(state)
    
    MySQL.Async.execute('INSERT INTO state (identifier, data, updated_at) VALUES (?, ?, NOW()) ON DUPLICATE KEY UPDATE data = ?, updated_at = NOW()', {
        identifier,
        serialized,
        serialized
    })
end

---Charge le state (serveur uniquement)
---@param identifier string
---@param callback function
function vCore.State.Load(identifier, callback)
    if not IsDuplicityVersion() then
        vCore.Utils.Warn('State.Load() disponible uniquement côté serveur')
        return
    end
    
    MySQL.Async.fetchAll('SELECT data FROM state WHERE identifier = ?', {identifier}, function(result)
        if result[1] then
            state = json.decode(result[1].data)
            vCore.Utils.Debug('State chargé:', identifier)
        end
        
        if callback then
            callback(state)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHORTCUTS
-- ═══════════════════════════════════════════════════════════════════════════

---Alias pour Set
---@param key string
---@param value any
function vCore.SetState(key, value)
    vCore.State.Set(key, value)
end

---Alias pour Get
---@param key string
---@param defaultValue? any
---@return any
function vCore.GetState(key, defaultValue)
    return vCore.State.Get(key, defaultValue)
end

---Alias pour Watch
---@param key string
---@param callback function
---@return number
function vCore.WatchState(key, callback)
    return vCore.State.Watch(key, callback)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLES
-- ═══════════════════════════════════════════════════════════════════════════

--[[
EXEMPLES D'UTILISATION:

-- State simple
vCore.State.Set('playerMoney', 5000)
local money = vCore.State.Get('playerMoney', 0)

-- State imbriqué
vCore.State.SetNested('player.inventory.water', 5)
local water = vCore.State.GetNested('player.inventory.water', 0)

-- Observer les changements
vCore.State.Watch('playerMoney', function(newMoney, oldMoney)
    print('Money changed:', oldMoney, '->', newMoney)
end)

-- Valeurs computed
vCore.State.Set('price', 100)
vCore.State.Set('quantity', 5)

vCore.State.Computed('total', {'price', 'quantity'}, function()
    local price = vCore.State.Get('price', 0)
    local quantity = vCore.State.Get('quantity', 0)
    return price * quantity
end)

-- total sera automatiquement recalculé quand price ou quantity change
print(vCore.State.Get('total'))  -- 500

-- Batch updates
vCore.State.Update({
    playerMoney = 10000,
    playerJob = 'police',
    playerGrade = 3
})

-- Historique
vCore.State.Set('test', 1)
vCore.State.Set('test', 2)
vCore.State.Set('test', 3)

local history = vCore.State.GetHistory('test')
-- history contient tous les changements

vCore.State.Undo()  -- Retour à test = 2

-- Persistence (serveur)
vCore.State.Save('player:123')
vCore.State.Load('player:123', function(loadedState)
    print('State loaded:', json.encode(loadedState))
end)
]]

print('^2[vCore:State]^7 Gestionnaire d'état chargé')
