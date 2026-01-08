--[[
    vAvA_core - Server Bans
    Gestion des bans
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN - BAN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('ban', function(source, args, rawCommand)
    -- Vérifier les permissions
    if source > 0 then
        local player = vCore.GetPlayer(source)
        if not player or not player:IsAdmin() then
            vCore.Notify(source, Lang('admin_no_permission'), 'error')
            return
        end
    end
    
    if #args < 2 then
        if source > 0 then
            vCore.Notify(source, 'Usage: /ban [id] [durée en heures ou "perm"] [raison]', 'info')
        else
            print('Usage: ban [id] [durée en heures ou "perm"] [raison]')
        end
        return
    end
    
    local targetId = tonumber(args[1])
    local durationArg = args[2]
    local reason = table.concat(args, ' ', 3) or 'Aucune raison spécifiée'
    
    if not targetId then
        if source > 0 then
            vCore.Notify(source, 'ID invalide', 'error')
        else
            print('ID invalide')
        end
        return
    end
    
    local duration = nil
    if durationArg ~= 'perm' and durationArg ~= 'permanent' then
        duration = tonumber(durationArg)
        if duration then
            duration = duration * 3600 -- Convertir heures en secondes
        end
    end
    
    local bannedBy = source > 0 and GetPlayerName(source) or 'Console'
    
    if vCore.Security.Ban(targetId, reason, duration, bannedBy) then
        local msg = 'Joueur #' .. targetId .. ' banni'
        if source > 0 then
            vCore.Notify(source, msg, 'success')
        else
            print(msg)
        end
    else
        local msg = 'Impossible de bannir le joueur'
        if source > 0 then
            vCore.Notify(source, msg, 'error')
        else
            print(msg)
        end
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN - UNBAN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('unban', function(source, args, rawCommand)
    -- Vérifier les permissions
    if source > 0 then
        local player = vCore.GetPlayer(source)
        if not player or not player:IsAdmin() then
            vCore.Notify(source, Lang('admin_no_permission'), 'error')
            return
        end
    end
    
    if #args < 1 then
        if source > 0 then
            vCore.Notify(source, 'Usage: /unban [identifier]', 'info')
        else
            print('Usage: unban [identifier]')
        end
        return
    end
    
    local identifier = args[1]
    
    if vCore.Security.Unban(identifier) then
        local msg = 'Joueur ' .. identifier .. ' débanni'
        if source > 0 then
            vCore.Notify(source, msg, 'success')
        else
            print(msg)
        end
    else
        local msg = 'Joueur non trouvé dans les bans'
        if source > 0 then
            vCore.Notify(source, msg, 'error')
        else
            print(msg)
        end
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN - BANLIST
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('banlist', function(source, args, rawCommand)
    -- Vérifier les permissions
    if source > 0 then
        local player = vCore.GetPlayer(source)
        if not player or not player:IsAdmin() then
            vCore.Notify(source, Lang('admin_no_permission'), 'error')
            return
        end
    end
    
    local bans = vCore.DB.Query([[
        SELECT identifier, reason, expire, banned_by, created_at 
        FROM bans 
        WHERE expire IS NULL OR expire > NOW()
        ORDER BY created_at DESC
        LIMIT 20
    ]])
    
    if #bans == 0 then
        if source > 0 then
            vCore.Notify(source, 'Aucun ban actif', 'info')
        else
            print('Aucun ban actif')
        end
        return
    end
    
    print('=== BANS ACTIFS ===')
    for _, ban in ipairs(bans) do
        print(string.format(
            '[%s] %s - Raison: %s - Par: %s - Expire: %s',
            ban.created_at,
            ban.identifier,
            ban.reason,
            ban.banned_by,
            ban.expire or 'Permanent'
        ))
    end
    print('==================')
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE DES BANS EXPIRÉS
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(3600000) -- Toutes les heures
        
        local cleaned = vCore.DB.Execute([[
            DELETE FROM bans 
            WHERE expire IS NOT NULL 
            AND expire < NOW() 
            AND permanent = 0
        ]])
        
        if cleaned > 0 then
            vCore.Utils.Print('Bans expirés nettoyés:', cleaned)
        end
    end
end)
