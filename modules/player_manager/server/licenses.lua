--[[
    vAvA_player_manager - Server Licenses
    Gestion des licences
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local Config = PlayerManagerConfig

-- ═══════════════════════════════════════════════════════════════════════════
-- OBTENIR LICENCES
-- ═══════════════════════════════════════════════════════════════════════════

function GetLicenses(citizenId, callback)
    MySQL.query('SELECT * FROM player_licenses WHERE citizenid = ? ORDER BY obtained_at DESC', {citizenId}, function(result)
        callback(result or {})
    end)
end

function HasLicense(citizenId, licenseType, callback)
    MySQL.single('SELECT * FROM player_licenses WHERE citizenid = ? AND license_type = ?', {citizenId, licenseType}, function(result)
        if not result then
            return callback(false)
        end
        
        -- Vérifier expiration
        if result.expires_at then
            local expires = os.time({
                year = tonumber(string.sub(result.expires_at, 1, 4)),
                month = tonumber(string.sub(result.expires_at, 6, 7)),
                day = tonumber(string.sub(result.expires_at, 9, 10))
            })
            
            if os.time() > expires then
                return callback(false)
            end
        end
        
        -- Vérifier suspension
        if result.is_suspended == 1 then
            if result.suspended_until then
                local suspended = os.time({
                    year = tonumber(string.sub(result.suspended_until, 1, 4)),
                    month = tonumber(string.sub(result.suspended_until, 6, 7)),
                    day = tonumber(string.sub(result.suspended_until, 9, 10))
                })
                
                if os.time() < suspended then
                    return callback(false)
                else
                    -- Lever suspension
                    MySQL.update('UPDATE player_licenses SET is_suspended = 0, suspended_until = NULL WHERE id = ?', {result.id})
                end
            else
                return callback(false)
            end
        end
        
        callback(true)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNER LICENCE
-- ═══════════════════════════════════════════════════════════════════════════

function GiveLicense(citizenId, licenseType, issuedBy, callback)
    -- Trouver config licence
    local licenseConfig = nil
    for _, license in ipairs(PMConfig.Licenses) do
        if license.name == licenseType then
            licenseConfig = license
            break
        end
    end
    
    if not licenseConfig then
        if callback then callback(false) end
        return
    end
    
    -- Calculer expiration
    local expiresAt = nil
    if licenseConfig.validityDays > 0 then
        expiresAt = os.date('%Y-%m-%d %H:%M:%S', os.time() + (licenseConfig.validityDays * 86400))
    end
    
    MySQL.query('INSERT INTO player_licenses (citizenid, license_type, license_label, expires_at, issued_by) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE obtained_at = NOW(), expires_at = VALUES(expires_at), is_suspended = 0, suspended_until = NULL', {
        citizenId,
        licenseType,
        licenseConfig.label,
        expiresAt,
        issuedBy
    }, function()
        -- Logger
        exports['vAvA_player_manager']:AddHistory(citizenId, 'license_obtained', 'Licence obtenue: ' .. licenseConfig.label, nil, licenseConfig.cost, nil)
        
        if callback then callback(true) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉVOQUER LICENCE
-- ═══════════════════════════════════════════════════════════════════════════

function RevokeLicense(citizenId, licenseType, callback)
    MySQL.update('DELETE FROM player_licenses WHERE citizenid = ? AND license_type = ?', {citizenId, licenseType}, function(affectedRows)
        if affectedRows > 0 then
            exports['vAvA_player_manager']:AddHistory(citizenId, 'license_revoked', 'Licence révoquée: ' .. licenseType, nil, nil, nil)
        end
        
        if callback then callback(affectedRows > 0) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SUSPENDRE LICENCE
-- ═══════════════════════════════════════════════════════════════════════════

function SuspendLicense(citizenId, licenseType, days, callback)
    local suspendedUntil = os.date('%Y-%m-%d %H:%M:%S', os.time() + (days * 86400))
    
    MySQL.update('UPDATE player_licenses SET is_suspended = 1, suspended_until = ? WHERE citizenid = ? AND license_type = ?', {suspendedUntil, citizenId, licenseType}, function(affectedRows)
        if affectedRows > 0 then
            exports['vAvA_player_manager']:AddHistory(citizenId, 'license_suspended', 'Licence suspendue: ' .. licenseType .. ' (' .. days .. ' jours)', nil, nil, nil)
        end
        
        if callback then callback(affectedRows > 0) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:BuyLicense', function(licenseType)
    local src = source
    local player = vCore.GetPlayer(src)
    
    if not player then return end
    
    -- Trouver config
    local licenseConfig = nil
    for _, license in ipairs(PMConfig.Licenses) do
        if license.name == licenseType then
            licenseConfig = license
            break
        end
    end
    
    if not licenseConfig then
        return TriggerClientEvent('vAvA:Notify', src, 'Licence introuvable', 'error')
    end
    
    -- Vérifier argent
    if player.GetMoney('bank') < licenseConfig.cost then
        return TriggerClientEvent('vAvA:Notify', src, 'Fonds insuffisants', 'error')
    end
    
    -- Vérifier examen requis
    if licenseConfig.examRequired then
        return TriggerClientEvent('vAvA:Notify', src, 'Vous devez passer un examen', 'info')
    end
    
    -- Retirer argent
    player.RemoveMoney('bank', licenseConfig.cost)
    
    -- Donner licence
    GiveLicense(player.PlayerData.citizenid, licenseType, 'auto', function(success)
        if success then
            TriggerClientEvent('vAvA:Notify', src, string.format(PMConfig.Notifications.LicenseObtained, licenseConfig.label), 'success')
        else
            player.AddMoney('bank', licenseConfig.cost)  -- Rembourser
            TriggerClientEvent('vAvA:Notify', src, 'Erreur', 'error')
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_player_manager:server:GetLicenses', function(source, cb, citizenId)
    GetLicenses(citizenId, function(licenses)
        cb(licenses)
    end)
end)

vCore.CreateCallback('vAvA_player_manager:server:HasLicense', function(source, cb, citizenId, licenseType)
    HasLicense(citizenId, licenseType, function(has)
        cb(has)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('givelicense', function(source, args, rawCommand)
    if source == 0 then
        print('[vAvA_player_manager] Cette commande doit être exécutée en jeu')
        return
    end
    
    local player = vCore.GetPlayer(source)
    if not player or not player.IsAdmin() then
        return TriggerClientEvent('vAvA:Notify', source, 'Accès refusé', 'error')
    end
    
    if not args[1] or not args[2] then
        return TriggerClientEvent('vAvA:Notify', source, 'Usage: /givelicense [id] [type]', 'error')
    end
    
    local targetId = tonumber(args[1])
    local targetPlayer = vCore.GetPlayer(targetId)
    
    if not targetPlayer then
        return TriggerClientEvent('vAvA:Notify', source, 'Joueur introuvable', 'error')
    end
    
    GiveLicense(targetPlayer.PlayerData.citizenid, args[2], player.PlayerData.citizenid, function(success)
        if success then
            TriggerClientEvent('vAvA:Notify', source, 'Licence donnée', 'success')
            TriggerClientEvent('vAvA:Notify', targetId, 'Vous avez reçu une licence: ' .. args[2], 'success')
        else
            TriggerClientEvent('vAvA:Notify', source, 'Erreur', 'error')
        end
    end)
end, false)

RegisterCommand('revokelicense', function(source, args, rawCommand)
    if source == 0 then
        print('[vAvA_player_manager] Cette commande doit être exécutée en jeu')
        return
    end
    
    local player = vCore.GetPlayer(source)
    if not player or not player.IsAdmin() then
        return TriggerClientEvent('vAvA:Notify', source, 'Accès refusé', 'error')
    end
    
    if not args[1] or not args[2] then
        return TriggerClientEvent('vAvA:Notify', source, 'Usage: /revokelicense [id] [type]', 'error')
    end
    
    local targetId = tonumber(args[1])
    local targetPlayer = vCore.GetPlayer(targetId)
    
    if not targetPlayer then
        return TriggerClientEvent('vAvA:Notify', source, 'Joueur introuvable', 'error')
    end
    
    RevokeLicense(targetPlayer.PlayerData.citizenid, args[2], function(success)
        if success then
            TriggerClientEvent('vAvA:Notify', source, 'Licence révoquée', 'success')
            TriggerClientEvent('vAvA:Notify', targetId, 'Votre licence ' .. args[2] .. ' a été révoquée', 'error')
        else
            TriggerClientEvent('vAvA:Notify', source, 'Erreur', 'error')
        end
    end)
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetLicenses', GetLicenses)
exports('HasLicense', HasLicense)
exports('GiveLicense', GiveLicense)
exports('RevokeLicense', RevokeLicense)
exports('SuspendLicense', SuspendLicense)
