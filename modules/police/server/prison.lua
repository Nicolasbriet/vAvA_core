--[[
    vAvA_police - Système de Prison
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local prisoners = {} -- Cache des prisonniers actifs

-- ═══════════════════════════════════════════════════════════════════════════
-- ENVOYER EN PRISON
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:SendToJail', function(targetId, time, reason)
    local src = source
    local officer = vCore.GetPlayer(src)
    local target = vCore.GetPlayer(targetId)
    
    if not officer or not target then return end
    
    -- Vérifier permissions
    local isPolice, grade = exports['vAvA_police']:IsPolice(src)
    if not isPolice or not PoliceConfig.Grades[grade].permissions.fine then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    -- Limiter le temps
    time = math.min(math.max(time, PoliceConfig.Prison.MinTime), PoliceConfig.Prison.MaxTime)
    
    -- Enregistrer le prisonnier
    MySQL.insert('INSERT INTO police_prisoners (citizen_id, citizen_name, officer_id, officer_name, jail_time, time_remaining, reason, release_at) VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))', {
        target.PlayerData.citizenid,
        target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
        officer.PlayerData.citizenid,
        officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
        time,
        time,
        reason,
        time
    }, function(prisonId)
        prisoners[targetId] = {
            id = prisonId,
            time = time,
            remaining = time,
            reason = reason
        }
        
        -- Téléporter en prison
        TriggerClientEvent('vAvA_police:client:SendToJail', targetId, time, reason)
        TriggerClientEvent('vAvA:Notify', src, target.PlayerData.firstName .. ' envoyé en prison pour ' .. time .. ' minutes', 'success')
        TriggerClientEvent('vAvA:Notify', targetId, 'Vous avez été emprisonné pour ' .. time .. ' minutes\nMotif: ' .. reason, 'error')
        
        -- Ajouter au casier
        MySQL.insert('INSERT INTO police_criminal_records (citizen_id, citizen_name, officer_id, officer_name, offense, jail_time) VALUES (?, ?, ?, ?, ?, ?)', {
            target.PlayerData.citizenid,
            target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
            officer.PlayerData.citizenid,
            officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
            reason,
            time
        })
        
        -- Démarrer le timer
        StartJailTimer(targetId)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- TIMER DE PRISON
-- ═══════════════════════════════════════════════════════════════════════════

function StartJailTimer(playerId)
    CreateThread(function()
        while prisoners[playerId] and prisoners[playerId].remaining > 0 do
            Wait(60000) -- 1 minute
            
            prisoners[playerId].remaining = prisoners[playerId].remaining - 1
            
            -- Mettre à jour BDD
            MySQL.update('UPDATE police_prisoners SET time_remaining = ? WHERE id = ?', {
                prisoners[playerId].remaining,
                prisoners[playerId].id
            })
            
            -- Notifier le joueur
            if prisoners[playerId].remaining > 0 then
                TriggerClientEvent('vAvA_police:client:UpdateJailTime', playerId, prisoners[playerId].remaining)
            else
                -- Libération
                ReleaseFromJail(playerId)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LIBÉRATION
-- ═══════════════════════════════════════════════════════════════════════════

function ReleaseFromJail(playerId)
    if not prisoners[playerId] then return end
    
    -- Supprimer de la base
    MySQL.update('DELETE FROM police_prisoners WHERE id = ?', {prisoners[playerId].id})
    
    prisoners[playerId] = nil
    
    -- Téléporter à la sortie
    TriggerClientEvent('vAvA_police:client:ReleaseFromJail', playerId)
    TriggerClientEvent('vAvA:Notify', playerId, 'Vous avez été libéré de prison', 'success')
end

RegisterNetEvent('vAvA_police:server:ReleaseEarly', function(targetId)
    local src = source
    local isPolice, grade = exports['vAvA_police']:IsPolice(src)
    
    if not isPolice or grade < 3 then
        return TriggerClientEvent('vAvA:Notify', src, 'Grade insuffisant', 'error')
    end
    
    ReleaseFromJail(targetId)
    TriggerClientEvent('vAvA:Notify', src, 'Prisonnier libéré', 'success')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- TRAVAIL EN PRISON (RÉDUCTION DE PEINE)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:PrisonWork', function()
    local src = source
    
    if not prisoners[src] then return end
    
    local reduction = PoliceConfig.Prison.WorkTimeReduction
    prisoners[src].remaining = math.max(0, prisoners[src].remaining - reduction)
    
    MySQL.update('UPDATE police_prisoners SET time_remaining = ? WHERE id = ?', {
        prisoners[src].remaining,
        prisoners[src].id
    })
    
    TriggerClientEvent('vAvA:Notify', src, 'Peine réduite de ' .. reduction .. ' minutes', 'success')
    TriggerClientEvent('vAvA_police:client:UpdateJailTime', src, prisoners[src].remaining)
    
    if prisoners[src].remaining <= 0 then
        ReleaseFromJail(src)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT AU LOGIN
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('vAvA:playerLoaded', function(playerId, citizenId)
    MySQL.single('SELECT * FROM police_prisoners WHERE citizen_id = ?', {citizenId}, function(prisoner)
        if prisoner and prisoner.time_remaining > 0 then
            prisoners[playerId] = {
                id = prisoner.id,
                time = prisoner.jail_time,
                remaining = prisoner.time_remaining,
                reason = prisoner.reason
            }
            
            TriggerClientEvent('vAvA_police:client:SendToJail', playerId, prisoner.time_remaining, prisoner.reason)
            StartJailTimer(playerId)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉCONNEXION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local src = source
    if prisoners[src] then
        -- Sauvegarder le temps restant
        MySQL.update('UPDATE police_prisoners SET time_remaining = ? WHERE id = ?', {
            prisoners[src].remaining,
            prisoners[src].id
        })
        prisoners[src] = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

function SendToPrison(officerId, citizenId, time, reason)
    -- Export pour autres ressources
    local playerId = vCore.GetPlayerByCitizenId(citizenId)
    if playerId then
        TriggerEvent('vAvA_police:server:SendToJail', officerId, playerId, time, reason)
    end
end

exports('SendToPrison', SendToPrison)
