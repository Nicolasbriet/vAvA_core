--[[
    vAvA_keys - Client Keys
    Fonctions de verrouillage
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local lastLPress = 0
local lastLockAction = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Vérifier accès job
local function CheckJobAccess(plate, vehicle)
    plate = string.gsub(plate, "%s+", "")
    
    -- Vérifier dans le cache
    if _G.jobAccessCache and _G.jobAccessCache[plate] ~= nil then
        return _G.jobAccessCache[plate]
    end
    
    -- Vérifier la config locale
    if KeysConfig.JobKeys.Enabled then
        local vCore = exports['vAvA_core']:GetCoreObject()
        local playerData = vCore and vCore.PlayerData or {}
        local playerJob = playerData.job and playerData.job.name
        
        if playerJob then
            local jobConfig = KeysConfig.JobKeys.Jobs[playerJob]
            if jobConfig then
                -- Vérifier modèles
                if jobConfig.vehicles then
                    local vehicleModel = GetEntityModel(vehicle)
                    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel):lower()
                    
                    for _, allowedModel in ipairs(jobConfig.vehicles) do
                        if vehicleName == allowedModel:lower() then
                            return true
                        end
                    end
                end
                
                -- Vérifier patterns de plaques
                if jobConfig.plates then
                    for _, platePattern in ipairs(jobConfig.plates) do
                        local pattern = platePattern:gsub("*", ".*")
                        if string.match(plate, "^" .. pattern .. "$") then
                            return true
                        end
                    end
                end
            end
        end
    end
    
    -- Demander au serveur
    TriggerServerEvent('vAvA_keys:checkJobAccess', plate)
    return false
end

-- Verrouiller/Déverrouiller un véhicule
function ToggleVehicleLock(vehicle, plate)
    if not vehicle or not DoesEntityExist(vehicle) then return false end
    
    local locked = GetVehicleDoorLockStatus(vehicle)
    local isLocked = (locked == 2 or locked == 3 or locked == 4)
    
    -- Demander le contrôle réseau
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if netId then
        NetworkRequestControlOfEntity(vehicle)
        local timeout = 0
        while not NetworkHasControlOfEntity(vehicle) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
    end
    
    if isLocked then
        -- Déverrouiller
        SetVehicleDoorsLocked(vehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleAlarm(vehicle, false)
        FlashVehicleLights(vehicle)
        ShowKeysNotif('Véhicule déverrouillé', 'success')
        
        if netId then
            TriggerServerEvent('vAvA_keys:syncVehicleLock', netId, false)
        end
    else
        -- Verrouiller
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        SetVehicleAlarm(vehicle, false)
        FlashVehicleLights(vehicle)
        ShowKeysNotif('Véhicule verrouillé', 'success')
        
        if netId then
            TriggerServerEvent('vAvA_keys:syncVehicleLock', netId, true)
        end
    end
    
    PlayKeyFobAnimation()
    return true
end

-- Fonction principale de verrouillage
function ToggleLock()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    -- Si pas dans un véhicule, chercher le plus proche
    if vehicle == 0 then
        vehicle = GetClosestVehicle(KeysConfig.Keys.InteractionDistance)
    end
    
    if vehicle and vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        plate = string.gsub(plate, "%s+", "")
        
        if HasKeys(plate) then
            return ToggleVehicleLock(vehicle, plate)
        else
            local hasJobAccess = CheckJobAccess(plate, vehicle)
            if hasJobAccess then
                return ToggleVehicleLock(vehicle, plate)
            else
                ShowNoKeysNotification(plate)
                return false
            end
        end
    else
        ShowKeysNotif('Aucun véhicule à proximité', 'error')
        return false
    end
end

exports('ToggleLock', ToggleLock)

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTRÔLES CLAVIER - ✅ OPTIMISÉ: RegisterKeyMapping au lieu de Wait(0)
-- ═══════════════════════════════════════════════════════════════════════════

-- Commande pour verrouiller/déverrouiller (touche L)
RegisterCommand('+vava_togglelock', function()
    local now = GetGameTimer()
    
    -- Vérifier cooldown
    if now - lastLockAction > KeysConfig.Keys.ActionCooldown then
        -- Double appui pour moteur ?
        if KeysConfig.DoubleTap.Enabled then
            if now - lastLPress < KeysConfig.DoubleTap.Delay then
                -- Double appui = moteur
                ToggleEngine()
                lastLPress = 0
            else
                -- Simple appui = verrouillage
                lastLPress = now
                SetTimeout(KeysConfig.DoubleTap.Delay + 50, function()
                    -- Vérifier si pas de double appui
                    if lastLPress > 0 and GetGameTimer() - lastLPress >= KeysConfig.DoubleTap.Delay then
                        ToggleLock()
                        lastLockAction = GetGameTimer()
                    end
                end)
            end
        else
            ToggleLock()
            lastLockAction = now
        end
    end
end, false)

RegisterCommand('-vava_togglelock', function() end, false)

-- Mapping de la touche L
RegisterKeyMapping('+vava_togglelock', 'Verrouiller/Déverrouiller véhicule', 'keyboard', 'L')
