--[[
    vAvA_police - Client Tablet
    Tablette police pour recherches et informations
]]

local tabletOpen = false

-- ═══════════════════════════════════════════════════════════════════════════
-- OUVRIR/FERMER TABLETTE
-- ═══════════════════════════════════════════════════════════════════════════

function OpenTablet()
    if tabletOpen then return end
    
    tabletOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openTablet',
        data = {}
    })
    
    -- Animation tablette
    CreateThread(function()
        local ped = PlayerPedId()
        RequestAnimDict("amb@world_human_seat_wall_tablet@female@base")
        while not HasAnimDictLoaded("amb@world_human_seat_wall_tablet@female@base") do
            Wait(10)
        end
        
        TaskPlayAnim(ped, "amb@world_human_seat_wall_tablet@female@base", "base", 8.0, -8.0, -1, 49, 0, false, false, false)
        
        -- Prop tablette
        local tabletProp = CreateObject(GetHashKey('prop_cs_tablet'), 0.0, 0.0, 0.0, true, true, true)
        AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.03, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        
        while tabletOpen do
            Wait(100)
        end
        
        ClearPedTasks(ped)
        DeleteObject(tabletProp)
    end)
end

function CloseTablet()
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeTablet'
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeTablet', function(data, cb)
    CloseTablet()
    cb('ok')
end)

RegisterNUICallback('searchPerson', function(data, cb)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.TriggerServerCallback('vAvA_police:server:SearchPerson', function(result)
        cb(result)
    end, data.query)
end)

RegisterNUICallback('searchVehicle', function(data, cb)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.TriggerServerCallback('vAvA_police:server:SearchVehicle', function(result)
        cb(result)
    end, data.plate)
end)

RegisterNUICallback('getCriminalRecord', function(data, cb)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.TriggerServerCallback('vAvA_police:server:GetCriminalRecordFull', function(result)
        cb(result)
    end, data.citizenid)
end)

RegisterNUICallback('getRecentAlerts', function(data, cb)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.TriggerServerCallback('vAvA_police:server:GetRecentAlerts', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('getActiveUnits', function(data, cb)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    vCore.TriggerServerCallback('vAvA_police:server:GetOnDutyPolice', function(result)
        cb(result)
    end)
end)

RegisterNUICallback('respondToAlert', function(data, cb)
    TriggerServerEvent('vAvA_police:server:RespondToAlert', data.alertId)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RECEVOIR DONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:UpdateTabletData', function(dataType, data)
    SendNUIMessage({
        action = 'updateData',
        dataType = dataType,
        data = data
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenTablet', OpenTablet)
exports('CloseTablet', CloseTablet)
