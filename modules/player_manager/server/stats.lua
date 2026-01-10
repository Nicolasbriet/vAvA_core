--[[
    vAvA_player_manager - Server Stats
    Mise à jour automatique des statistiques
]]

local PMConfig = PlayerManagerConfig

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local PlayerPositions = {}  -- Dernière position connue

-- ═══════════════════════════════════════════════════════════════════════════
-- THREAD MISE À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

if PMConfig.Stats.TrackDistance then
    CreateThread(function()
        while true do
            Wait(PMConfig.Stats.UpdateInterval)
            
            local players = GetPlayers()
            
            for _, playerId in ipairs(players) do
                local src = tonumber(playerId)
                local ped = GetPlayerPed(src)
                
                if ped and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local citizenId = GetPlayerCitizenId(src)
                    
                    if citizenId and PlayerPositions[src] then
                        local distance = #(coords - PlayerPositions[src])
                        
                        -- Distance en km
                        local distanceKm = distance / 1000
                        
                        -- Vérifier si en véhicule
                        local vehicle = GetVehiclePedIsIn(ped, false)
                        
                        if vehicle and vehicle ~= 0 and PMConfig.Stats.TrackVehicleDistance then
                            exports['vAvA_player_manager']:UpdateStat(citizenId, 'distance_driven', distanceKm)
                        else
                            exports['vAvA_player_manager']:UpdateStat(citizenId, 'distance_walked', distanceKm)
                        end
                    end
                    
                    PlayerPositions[src] = coords
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:AddDeath', function()
    local src = source
    local citizenId = GetPlayerCitizenId(src)
    
    if citizenId and PMConfig.Stats.TrackDeaths then
        exports['vAvA_player_manager']:UpdateStat(citizenId, 'deaths', 1)
        exports['vAvA_player_manager']:AddHistory(citizenId, 'death', 'Mort du personnage', nil, nil, nil)
    end
end)

RegisterNetEvent('vAvA_player_manager:server:AddArrest', function()
    local src = source
    local citizenId = GetPlayerCitizenId(src)
    
    if citizenId and PMConfig.Stats.TrackArrests then
        exports['vAvA_player_manager']:UpdateStat(citizenId, 'arrests', 1)
    end
end)

RegisterNetEvent('vAvA_player_manager:server:AddJobCompleted', function()
    local src = source
    local citizenId = GetPlayerCitizenId(src)
    
    if citizenId and PMConfig.Stats.TrackJobs then
        exports['vAvA_player_manager']:UpdateStat(citizenId, 'jobs_completed', 1)
    end
end)

RegisterNetEvent('vAvA_player_manager:server:AddMoneyEarned', function(amount)
    local src = source
    local citizenId = GetPlayerCitizenId(src)
    
    if citizenId and amount > 0 then
        exports['vAvA_player_manager']:UpdateStat(citizenId, 'money_earned', amount)
    end
end)

RegisterNetEvent('vAvA_player_manager:server:AddMoneySpent', function(amount)
    local src = source
    local citizenId = GetPlayerCitizenId(src)
    
    if citizenId and amount > 0 then
        exports['vAvA_player_manager']:UpdateStat(citizenId, 'money_spent', amount)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local src = source
    PlayerPositions[src] = nil
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function GetPlayerCitizenId(source)
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end
