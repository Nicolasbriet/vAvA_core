--[[
    vAvA_player_manager - Client Identity
    Carte d'identité
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = PlayerManagerConfig

-- ═══════════════════════════════════════════════════════════════════════════
-- MONTRER CARTE ID
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:ShowID', function(targetId)
    local player = vCore.GetPlayerData()
    
    if not player then return end
    
    -- Envoyer info au joueur cible
    TriggerServerEvent('vAvA_player_manager:server:SendIDInfo', targetId, {
        firstname = player.firstName,
        lastname = player.lastName,
        dateofbirth = player.dateofbirth,
        sex = player.sex,
        phone = player.phone,
        citizenid = player.citizenid,
        job = player.job.label
    })
end)

RegisterNetEvent('vAvA_player_manager:client:ReceiveIDInfo', function(senderId, idInfo)
    -- Afficher carte ID
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showIDCard',
        data = idInfo,
        senderName = GetPlayerName(GetPlayerFromServerId(senderId))
    })
    
    -- Auto-fermer après 10 secondes
    SetTimeout(10000, function()
        SendNUIMessage({action = 'closeIDCard'})
        SetNuiFocus(false, false)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFIER ID
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('checkid', function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        -- Chercher joueur proche
        local coords = GetEntityCoords(PlayerPedId())
        local players = vCore.GetPlayersFromCoords(coords, 3.0)
        
        if #players > 0 then
            targetId = players[1]
        else
            return TriggerEvent('vAvA:Notify', 'Aucun joueur à proximité', 'error')
        end
    end
    
    TriggerServerEvent('vAvA_player_manager:server:RequestID', targetId)
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeIDCard', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowID', function(targetId)
    TriggerEvent('vAvA_player_manager:server:ShowID', targetId)
end)
