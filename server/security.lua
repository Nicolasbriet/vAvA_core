--[[
    vAvA_core - Server Security
    Système de sécurité anti-exploit
]]

vCore = vCore or {}
vCore.Security = {}

-- Rate limiting data
local rateLimits = {}
local suspiciousActivities = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- RATE LIMITING
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie le rate limit pour un joueur
---@param source number
---@param action string
---@return boolean allowed
function vCore.Security.CheckRateLimit(source, action)
    if not Config.Security.RateLimit.enabled then return true end
    
    local key = source .. ':' .. action
    local now = GetGameTimer()
    
    if not rateLimits[key] then
        rateLimits[key] = {
            count = 0,
            lastReset = now
        }
    end
    
    local data = rateLimits[key]
    
    -- Reset toutes les secondes
    if now - data.lastReset > 1000 then
        data.count = 0
        data.lastReset = now
    end
    
    data.count = data.count + 1
    
    if data.count > Config.Security.RateLimit.maxRequests then
        vCore.Security.LogSuspicious(source, 'rate_limit', {
            action = action,
            count = data.count
        })
        return false
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉTECTION D'ACTIVITÉS SUSPECTES
-- ═══════════════════════════════════════════════════════════════════════════

---Log une activité suspecte
---@param source number
---@param type string
---@param data? table
function vCore.Security.LogSuspicious(source, type, data)
    local player = vCore.GetPlayer(source)
    local identifier = player and player:GetIdentifier() or vCore.Players.GetIdentifier(source)
    
    if not suspiciousActivities[source] then
        suspiciousActivities[source] = {}
    end
    
    table.insert(suspiciousActivities[source], {
        type = type,
        data = data,
        timestamp = GetGameTimer()
    })
    
    vCore.Utils.Warn('Activité suspecte:', source, type, json.encode(data or {}))
    
    vCore.Log('security', identifier, 
        'Activité suspecte: ' .. type,
        data
    )
    
    -- Vérifier si le joueur doit être banni
    vCore.Security.CheckAutoban(source)
end

---Vérifie si un joueur doit être auto-banni
---@param source number
function vCore.Security.CheckAutoban(source)
    local activities = suspiciousActivities[source]
    if not activities then return end
    
    -- 5 activités suspectes en 5 minutes = ban
    local now = GetGameTimer()
    local recentCount = 0
    
    for _, activity in ipairs(activities) do
        if now - activity.timestamp < 300000 then -- 5 minutes
            recentCount = recentCount + 1
        end
    end
    
    if recentCount >= 5 then
        local identifier = vCore.Players.GetIdentifier(source)
        vCore.Security.Ban(source, 'Activités suspectes répétées (auto-ban)', Config.Security.RateLimit.banDuration)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFICATION D'EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si un event est autorisé
---@param source number
---@param eventName string
---@return boolean
function vCore.Security.ValidateEvent(source, eventName)
    if not Config.Security.AntiTrigger.enabled then return true end
    
    -- Whitelist
    if vCore.Utils.TableContains(Config.Security.AntiTrigger.whitelist, eventName) then
        return true
    end
    
    -- Vérifier que le joueur est chargé
    local player = vCore.GetPlayer(source)
    if not player then
        vCore.Security.LogSuspicious(source, 'event_before_load', {event = eventName})
        return false
    end
    
    return true
end

---Wrapper pour les events sécurisés
---@param eventName string
---@param handler function
function vCore.Security.RegisterSecureEvent(eventName, handler)
    RegisterNetEvent(eventName, function(...)
        local source = source
        
        if not vCore.Security.ValidateEvent(source, eventName) then
            return
        end
        
        if not vCore.Security.CheckRateLimit(source, eventName) then
            return
        end
        
        handler(source, ...)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFICATIONS SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie une action économique côté serveur
---@param source number
---@param amount number
---@param action string
---@return boolean
function vCore.Security.ValidateMoneyAction(source, amount, action)
    if amount < 0 then
        vCore.Security.LogSuspicious(source, 'negative_money', {
            action = action,
            amount = amount
        })
        return false
    end
    
    if amount > 1000000000 then
        vCore.Security.LogSuspicious(source, 'excessive_money', {
            action = action,
            amount = amount
        })
        return false
    end
    
    return true
end

---Vérifie une action inventaire côté serveur
---@param source number
---@param itemName string
---@param amount number
---@return boolean
function vCore.Security.ValidateItemAction(source, itemName, amount)
    if amount <= 0 then
        vCore.Security.LogSuspicious(source, 'invalid_item_amount', {
            item = itemName,
            amount = amount
        })
        return false
    end
    
    -- Vérifier que l'item existe
    local item = vCore.Cache.Items.Get(itemName)
    if not item then
        vCore.Security.LogSuspicious(source, 'unknown_item', {
            item = itemName
        })
        return false
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BAN
-- ═══════════════════════════════════════════════════════════════════════════

---Bannit un joueur
---@param source number
---@param reason string
---@param duration? number en secondes (nil = permanent)
---@param bannedBy? string
---@return boolean
function vCore.Security.Ban(source, reason, duration, bannedBy)
    local identifier = vCore.Players.GetIdentifier(source)
    if not identifier then return false end
    
    local identifiers = vCore.Players.GetAllIdentifiers(source)
    bannedBy = bannedBy or 'System'
    
    local expire = nil
    if duration then
        expire = os.date('%Y-%m-%d %H:%M:%S', os.time() + duration)
    end
    
    -- Ajouter le ban en DB
    vCore.DB.Execute([[
        INSERT INTO bans (identifier, license, steam, discord, ip, reason, expire_at, permanent, banned_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        identifier,
        identifiers.license,
        identifiers.steam,
        identifiers.discord,
        identifiers.ip,
        reason,
        expire,
        duration == nil and 1 or 0,
        bannedBy
    })
    
    -- Log
    vCore.Log('security', identifier, 'Joueur banni: ' .. reason, {
        duration = duration,
        expire = expire,
        bannedBy = bannedBy
    })
    
    -- Kick
    local expireText = expire or Lang('security_ban_permanent')
    DropPlayer(source, Lang('security_banned') .. '\n' .. Lang('security_ban_reason', reason) .. '\n' .. Lang('security_ban_expire', expireText))
    
    -- Event
    TriggerEvent(vCore.Events.PLAYER_BANNED, identifier, reason, duration)
    
    return true
end

---Débannit un joueur
---@param identifier string
---@return boolean
function vCore.Security.Unban(identifier)
    local success = vCore.DB.RemoveBan(identifier)
    
    if success then
        vCore.Log('security', identifier, 'Joueur débanni')
    end
    
    return success
end

---Vérifie si un joueur est banni
---@param identifier string
---@return boolean, table|nil
function vCore.Security.IsBanned(identifier)
    local ban = vCore.DB.GetBan(identifier)
    return ban ~= nil, ban
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('BanPlayer', function(source, reason, duration, bannedBy)
    return vCore.Security.Ban(source, reason, duration, bannedBy)
end)

exports('UnbanPlayer', function(identifier)
    return vCore.Security.Unban(identifier)
end)

exports('IsPlayerBanned', function(identifier)
    return vCore.Security.IsBanned(identifier)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE PÉRIODIQUE
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(60000) -- Toutes les minutes
        
        -- Nettoyer les rate limits anciens
        local now = GetGameTimer()
        for key, data in pairs(rateLimits) do
            if now - data.lastReset > 60000 then
                rateLimits[key] = nil
            end
        end
        
        -- Nettoyer les activités suspectes anciennes
        for source, activities in pairs(suspiciousActivities) do
            local newActivities = {}
            for _, activity in ipairs(activities) do
                if now - activity.timestamp < 600000 then -- 10 minutes
                    table.insert(newActivities, activity)
                end
            end
            
            if #newActivities > 0 then
                suspiciousActivities[source] = newActivities
            else
                suspiciousActivities[source] = nil
            end
        end
    end
end)
