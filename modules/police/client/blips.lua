--[[
    vAvA_police - Client Blips
    GPS collègues et waypoints
]]

local policeBlips = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR LISTE POLICIERS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:UpdateOnDutyList', function(policeList)
    -- Supprimer anciens blips
    for _, blip in pairs(policeBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    policeBlips = {}
    
    -- Créer nouveaux blips
    if PoliceConfig.General.GPS_Enabled then
        for _, officer in ipairs(policeList) do
            if officer.source ~= GetPlayerServerId(PlayerId()) then
                CreatePoliceBlip(officer.source, officer.name)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉER BLIP POLICIER
-- ═══════════════════════════════════════════════════════════════════════════

function CreatePoliceBlip(playerId, playerName)
    local player = GetPlayerFromServerId(playerId)
    if player == -1 then return end
    
    local ped = GetPlayerPed(player)
    if ped == 0 then return end
    
    local blip = AddBlipForEntity(ped)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 29) -- Bleu police
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    SetBlipCategory(blip, 7)
    ShowHeadingIndicatorOnBlip(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("👮 " .. playerName)
    EndTextCommandSetBlipName(blip)
    
    policeBlips[playerId] = blip
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR POSITIONS (THREAD)
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(PoliceConfig.General.GPS_UpdateInterval or 5000)
        
        if PoliceConfig.General.GPS_Enabled then
            -- Mettre à jour positions existantes
            for playerId, blip in pairs(policeBlips) do
                local player = GetPlayerFromServerId(playerId)
                if player ~= -1 then
                    local ped = GetPlayerPed(player)
                    if ped ~= 0 and DoesBlipExist(blip) then
                        local coords = GetEntityCoords(ped)
                        SetBlipCoords(blip, coords.x, coords.y, coords.z)
                    end
                else
                    -- Joueur déconnecté
                    if DoesBlipExist(blip) then
                        RemoveBlip(blip)
                    end
                    policeBlips[playerId] = nil
                end
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RECEVOIR ALERTES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:ReceiveAlert', function(alert)
    -- Notification
    local vCore = exports['vAvA_core']:GetCoreObject()
    vCore.ShowNotification(
        string.format('~r~ALERTE~s~\n%s: %s\nAppuyez sur ~g~Y~s~ pour GPS', alert.code, alert.message),
        'error',
        10000
    )
    
    -- Son d'alerte
    PlaySoundFrontend(-1, PoliceConfig.Dispatch.AlertSound.name, PoliceConfig.Dispatch.AlertSound.set, true)
    
    -- Créer blip temporaire
    local blip = AddBlipForCoord(alert.coords.x, alert.coords.y, alert.coords.z)
    SetBlipSprite(blip, 161)
    SetBlipColour(blip, 1) -- Rouge
    SetBlipScale(blip, 1.2)
    SetBlipAsShortRange(blip, false)
    SetBlipFlashes(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('⚠️ ' .. alert.code)
    EndTextCommandSetBlipName(blip)
    
    -- Supprimer après durée
    SetTimeout(PoliceConfig.Dispatch.AlertDuration * 1000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
    
    -- Permettre GPS
    local displayTime = GetGameTimer()
    CreateThread(function()
        while GetGameTimer() - displayTime < 10000 do
            Wait(0)
            if IsControlJustReleased(0, 246) then -- Y
                SetNewWaypoint(alert.coords.x, alert.coords.y)
                vCore.ShowNotification('GPS activé vers l\'alerte', 'success')
                break
            end
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- BACKUP DEMANDÉ
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:BackupRequested', function(requester, coords)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.ShowNotification(
        string.format('~r~RENFORT DEMANDÉ~s~\nPar: %s\nAppuyez sur ~g~Y~s~ pour GPS', requester),
        'error',
        10000
    )
    
    PlaySoundFrontend(-1, "CONFIRM_BEEP", "HUD_MINI_GAME_SOUNDSET", true)
    
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 280)
    SetBlipColour(blip, 29)
    SetBlipScale(blip, 1.5)
    SetBlipFlashes(blip, true)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString('🚨 Renfort')
    EndTextCommandSetBlipName(blip)
    
    SetTimeout(60000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
    
    local displayTime = GetGameTimer()
    CreateThread(function()
        while GetGameTimer() - displayTime < 10000 do
            Wait(0)
            if IsControlJustReleased(0, 246) then
                SetNewWaypoint(coords.x, coords.y)
                vCore.ShowNotification('GPS activé vers le renfort', 'success')
                break
            end
        end
    end)
end)
