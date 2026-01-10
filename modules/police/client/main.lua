--[[
    vAvA_police - Client Main
    Gestion principale client-side
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local vCore = exports['vAvA_core']:GetCoreObject()
local isPolice = false
local onDuty = false
local isHandcuffed = false
local isEscorted = false
local escortedBy = nil
local inJail = false
local jailTime = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    -- Vérifier si joueur est police
    while not vCore.PlayerLoaded do
        Wait(100)
    end
    
    local playerData = vCore.GetPlayerData()
    if playerData.job then
        for _, policeJob in ipairs(PoliceConfig.General.PoliceJobs) do
            if playerData.job.name == policeJob then
                isPolice = true
                break
            end
        end
    end
    
    -- Créer les blips des commissariats
    if PoliceConfig.General.Enabled then
        for _, station in ipairs(PoliceConfig.Stations) do
            local blip = AddBlipForCoord(station.coords.x, station.coords.y, station.coords.z)
            SetBlipSprite(blip, station.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, station.blip.scale)
            SetBlipColour(blip, station.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(station.blip.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:SetDuty', function(duty)
    onDuty = duty
end)

RegisterNetEvent('vAvA_police:client:GetHandcuffed', function()
    isHandcuffed = not isHandcuffed
    local ped = PlayerPedId()
    
    if isHandcuffed then
        -- Animation menottes
        RequestAnimDict("mp_arresting")
        while not HasAnimDictLoaded("mp_arresting") do Wait(10) end
        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8, -1, 49, 0, 0, 0, 0)
        
        -- Désactiver actions
        CreateThread(function()
            while isHandcuffed do
                Wait(0)
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 257, true) -- Attack 2
                DisableControlAction(0, 25, true) -- Aim
                DisableControlAction(0, 263, true) -- Melee Attack 1
                DisableControlAction(0, 45, true) -- Reload
                DisableControlAction(0, 22, true) -- Jump
                DisableControlAction(0, 44, true) -- Cover
                DisableControlAction(0, 37, true) -- Select Weapon
                DisableControlAction(0, 23, true) -- Enter Vehicle
                DisableControlAction(0, 288, true) -- F1
                DisableControlAction(0, 289, true) -- F2
                DisableControlAction(0, 170, true) -- F3
                DisableControlAction(0, 167, true) -- F6
            end
        end)
    else
        ClearPedTasks(ped)
    end
end)

RegisterNetEvent('vAvA_police:client:GetUnhandcuffed', function()
    isHandcuffed = false
    ClearPedTasks(PlayerPedId())
end)

RegisterNetEvent('vAvA_police:client:GetEscorted', function(officerId)
    isEscorted = not isEscorted
    escortedBy = isEscorted and GetPlayerFromServerId(officerId) or nil
    
    if isEscorted then
        CreateThread(function()
            while isEscorted and escortedBy do
                Wait(0)
                local targetPed = GetPlayerPed(escortedBy)
                if DoesEntityExist(targetPed) then
                    AttachEntityToEntity(PlayerPedId(), targetPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                else
                    isEscorted = false
                    escortedBy = nil
                    DetachEntity(PlayerPedId(), true, false)
                end
            end
            DetachEntity(PlayerPedId(), true, false)
        end)
    else
        DetachEntity(PlayerPedId(), true, false)
    end
end)

RegisterNetEvent('vAvA_police:client:PutInVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 then return end
    
    local vehicles = {}
    for veh in EnumerateVehicles() do
        if #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 5.0 then
            table.insert(vehicles, veh)
        end
    end
    
    if #vehicles > 0 then
        local vehicle = vehicles[1]
        for i = GetVehicleMaxNumberOfPassengers(vehicle), 0, -1 do
            if IsVehicleSeatFree(vehicle, i) then
                TaskWarpPedIntoVehicle(ped, vehicle, i)
                break
            end
        end
    end
end)

RegisterNetEvent('vAvA_police:client:RemoveFromVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle ~= 0 then
        TaskLeaveVehicle(ped, vehicle, 0)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- PRISON
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:SendToJail', function(time, reason)
    inJail = true
    jailTime = time
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, PoliceConfig.Prison.Inside.x, PoliceConfig.Prison.Inside.y, PoliceConfig.Prison.Inside.z)
    
    -- Changer tenue
    local model = GetEntityModel(ped)
    local outfit = model == GetHashKey("mp_m_freemode_01") and PoliceConfig.Prison.Outfit.male or PoliceConfig.Prison.Outfit.female
    
    for k, v in pairs(outfit) do
        local drawable = string.match(k, "(.+)_1")
        local texture = string.match(k, "(.+)_2")
        if drawable then
            SetPedComponentVariation(ped, GetPedDrawableVariation(ped, tonumber(drawable)), v, 0, 0)
        end
    end
    
    -- Timer affichage
    CreateThread(function()
        while inJail and jailTime > 0 do
            Wait(0)
            DrawText2D(0.5, 0.95, "~r~Prison: " .. jailTime .. " minutes restantes", 0.5)
        end
    end)
end)

RegisterNetEvent('vAvA_police:client:UpdateJailTime', function(time)
    jailTime = time
end)

RegisterNetEvent('vAvA_police:client:ReleaseFromJail', function()
    inJail = false
    jailTime = 0
    
    local ped = PlayerPedId()
    SetEntityCoords(ped, PoliceConfig.Prison.Release.x, PoliceConfig.Prison.Release.y, PoliceConfig.Prison.Release.z)
    
    -- Restaurer tenue
    TriggerServerEvent('vAvA_core:server:LoadOutfit')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- POINTS DE TRAVAIL EN PRISON
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(500)
        
        if inJail then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            for _, workCoords in ipairs(PoliceConfig.Prison.WorkLocations) do
                local dist = #(coords - workCoords)
                if dist < 2.0 then
                    DrawText2D(0.5, 0.9, "~g~[E]~s~ Travailler pour réduire votre peine", 0.4)
                    
                    if IsControlJustReleased(0, 38) then -- E
                        -- Animation travail
                        TaskStartScenarioInPlace(ped, "WORLD_HUMAN_GARDENER_PLANT", 0, true)
                        Wait(10000) -- 10 secondes de travail
                        ClearPedTasks(ped)
                        
                        TriggerServerEvent('vAvA_police:server:PrisonWork')
                    end
                end
            end
        else
            Wait(2000)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    DrawText(x, y)
end

function EnumerateVehicles()
    return EnumerateEntities(FindFirstVehicle, FindNextVehicle, EndFindVehicle)
end

function EnumerateEntities(initFunc, moveFunc, disposeFunc)
    return coroutine.wrap(function()
        local iter, id = initFunc()
        if not id or id == 0 then
            disposeFunc(iter)
            return
        end
        
        local enum = {handle = iter, destructor = disposeFunc}
        setmetatable(enum, entityEnumerator)
        
        local next = true
        repeat
            coroutine.yield(id)
            next, id = moveFunc(iter)
        until not next
        
        enum.destructor, enum.handle = nil, nil
        disposeFunc(iter)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('IsHandcuffed', function()
    return isHandcuffed
end)

exports('IsPolice', function()
    return isPolice
end)

exports('IsOnDuty', function()
    return onDuty
end)
