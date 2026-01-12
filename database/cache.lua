--[[
    vAvA_core - Système de cache intelligent
]]

vCore = vCore or {}
vCore.Cache = {}

local cache = {}
local cacheTimestamps = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CacheConfig = {
    enabled = true,
    defaultTTL = 60000,     -- 60 secondes
    maxSize = 1000,
    cleanupInterval = 30000 -- 30 secondes
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS DE BASE
-- ═══════════════════════════════════════════════════════════════════════════

---Définit une valeur dans le cache
---@param category string
---@param key string
---@param value any
---@param ttl? number Time to live en ms
function vCore.Cache.Set(category, key, value, ttl)
    if not CacheConfig.enabled then return end
    
    if not cache[category] then
        cache[category] = {}
        cacheTimestamps[category] = {}
    end
    
    cache[category][key] = value
    cacheTimestamps[category][key] = {
        time = GetGameTimer(),
        ttl = ttl or CacheConfig.defaultTTL
    }
    
    vCore.Utils.Debug('Cache SET:', category, key)
end

---Récupère une valeur du cache
---@param category string
---@param key string
---@return any|nil
function vCore.Cache.Get(category, key)
    if not CacheConfig.enabled then return nil end
    if not cache[category] or not cache[category][key] then return nil end
    
    local timestamp = cacheTimestamps[category][key]
    if not timestamp then return nil end
    
    -- Vérifier si expiré (ttl = 0 signifie pas d'expiration)
    if timestamp.ttl > 0 and GetGameTimer() - timestamp.time > timestamp.ttl then
        vCore.Cache.Delete(category, key)
        return nil
    end
    
    vCore.Utils.Debug('Cache HIT:', category, key)
    return cache[category][key]
end

---Supprime une valeur du cache
---@param category string
---@param key string
function vCore.Cache.Delete(category, key)
    if cache[category] then
        cache[category][key] = nil
        cacheTimestamps[category][key] = nil
        vCore.Utils.Debug('Cache DELETE:', category, key)
    end
end

---Supprime une catégorie entière
---@param category string
function vCore.Cache.DeleteCategory(category)
    cache[category] = nil
    cacheTimestamps[category] = nil
    vCore.Utils.Debug('Cache DELETE CATEGORY:', category)
end

---Vérifie si une clé existe
---@param category string
---@param key string
---@return boolean
function vCore.Cache.Has(category, key)
    return vCore.Cache.Get(category, key) ~= nil
end

---Vide tout le cache
function vCore.Cache.Clear()
    cache = {}
    cacheTimestamps = {}
    vCore.Utils.Debug('Cache CLEARED')
end

---Retourne la taille du cache
---@return number
function vCore.Cache.Size()
    local count = 0
    for category, items in pairs(cache) do
        for _ in pairs(items) do
            count = count + 1
        end
    end
    return count
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CACHE SPÉCIFIQUES
-- ═══════════════════════════════════════════════════════════════════════════

-- Cache des items
vCore.Cache.Items = {}

---Charge tous les items en cache
function vCore.Cache.Items.Load()
    local items = vCore.DB.GetAllItems()
    for _, item in ipairs(items) do
        vCore.Cache.Set('items', item.name, item, 0) -- TTL 0 = permanent
    end
    vCore.Utils.Print('Items chargés en cache:', #items)
end

---Récupère un item depuis le cache
---@param itemName string
---@return table|nil
function vCore.Cache.Items.Get(itemName)
    local cached = vCore.Cache.Get('items', itemName)
    if cached then return cached end
    
    -- Fallback DB
    local item = vCore.DB.GetItem(itemName)
    if item then
        vCore.Cache.Set('items', itemName, item, 0)
    end
    return item
end

-- Cache des jobs
vCore.Cache.Jobs = {}

---Charge tous les jobs en cache (depuis config)
function vCore.Cache.Jobs.Load()
    for jobName, jobData in pairs(Config.Jobs.List) do
        vCore.Cache.Set('jobs', jobName, jobData, 0)
    end
    vCore.Utils.Print('Jobs chargés en cache:', vCore.Utils.TableCount(Config.Jobs.List))
end

---Récupère un job depuis le cache
---@param jobName string
---@return table|nil
function vCore.Cache.Jobs.Get(jobName)
    return vCore.Cache.Get('jobs', jobName)
end

-- Cache des joueurs
vCore.Cache.Players = {}

---Ajoute un joueur au cache
---@param source number
---@param player vPlayer
function vCore.Cache.Players.Set(source, player)
    vCore.Cache.Set('players', tostring(source), player, 0)
end

---Récupère un joueur depuis le cache
---@param source number
---@return vPlayer|nil
function vCore.Cache.Players.Get(source)
    return vCore.Cache.Get('players', tostring(source))
end

---Supprime un joueur du cache
---@param source number
function vCore.Cache.Players.Delete(source)
    vCore.Cache.Delete('players', tostring(source))
end

---Récupère tous les joueurs en cache
---@return table
function vCore.Cache.Players.GetAll()
    local players = {}
    
    if cache['players'] then
        for source, player in pairs(cache['players']) do
            local numSource = tonumber(source)
            if numSource and player then
                players[numSource] = player
            end
        end
    end
    
    return players
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE AUTOMATIQUE
-- ═══════════════════════════════════════════════════════════════════════════

---Nettoie les entrées expirées
function vCore.Cache.Cleanup()
    local now = GetGameTimer()
    local cleaned = 0
    
    for category, timestamps in pairs(cacheTimestamps) do
        for key, data in pairs(timestamps) do
            if data.ttl > 0 and now - data.time > data.ttl then
                vCore.Cache.Delete(category, key)
                cleaned = cleaned + 1
            end
        end
    end
    
    if cleaned > 0 then
        vCore.Utils.Debug('Cache cleanup:', cleaned, 'entrées supprimées')
    end
end

-- Thread de nettoyage
CreateThread(function()
    while true do
        Wait(CacheConfig.cleanupInterval)
        vCore.Cache.Cleanup()
    end
end)
