--[[
    vAvA_keys - Client Engine
    Contrôle du moteur
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Contrôler le moteur
function ToggleEngine()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if vehicle == 0 then
        vehicle = GetClosestVehicle(KeysConfig.Keys.InteractionDistance)
    end
    
    if vehicle and vehicle ~= 0 then
        local plate = GetVehicleNumberPlateText(vehicle)
        plate = string.gsub(plate, "%s+", "")
        
        -- Vérifier les clés
        if not HasKeys(plate) then
            -- Vérifier le cache job
            if not _G.jobAccessCache[plate] then
                ShowNoKeysNotification(plate)
                return false
            end
        end
        
        -- Demander le contrôle
        NetworkRequestControlOfEntity(vehicle)
        local timeout = 0
        while not NetworkHasControlOfEntity(vehicle) and timeout < 50 do
            Wait(10)
            timeout = timeout + 1
        end
        
        local engineOn = GetIsVehicleEngineRunning(vehicle)
        
        if engineOn then
            SetVehicleEngineOn(vehicle, false, false, true)
            ShowKeysNotif('Moteur éteint', 'info')
        else
            SetVehicleEngineOn(vehicle, true, false, true)
            ShowKeysNotif('Moteur démarré', 'success')
        end
        
        return true
    else
        ShowKeysNotif('Aucun véhicule à proximité', 'error')
        return false
    end
end

exports('ToggleEngine', ToggleEngine)

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTRÔLES
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        
        -- Touche G pour le moteur quand dans un véhicule
        if vehicle ~= 0 and IsControlJustPressed(0, KeysConfig.Commands.EngineKey) then
            local plate = GetVehicleNumberPlateText(vehicle)
            plate = string.gsub(plate, "%s+", "")
            
            if HasKeys(plate) or _G.jobAccessCache[plate] then
                local engineOn = GetIsVehicleEngineRunning(vehicle)
                SetVehicleEngineOn(vehicle, not engineOn, false, true)
                
                if engineOn then
                    ShowKeysNotif('Moteur éteint', 'info')
                else
                    ShowKeysNotif('Moteur démarré', 'success')
                end
            else
                ShowNoKeysNotification(plate)
            end
        end
    end
end)
