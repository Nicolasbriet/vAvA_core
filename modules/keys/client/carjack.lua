--[[
    vAvA_keys - Client Carjack
    Système de vol de voiture
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local isCarjacking = false

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function StartCarjack(vehicle)
    if not KeysConfig.CarJack.Enabled then
        ShowKeysNotif('Le carjack est désactivé', 'error')
        return false
    end
    
    if isCarjacking then
        return false
    end
    
    if not vehicle or not DoesEntityExist(vehicle) then
        ShowKeysNotif('Aucun véhicule à proximité', 'error')
        return false
    end
    
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = string.gsub(plate, "%s+", "")
    
    -- Déjà les clés ?
    if HasKeys(plate) then
        ShowKeysNotif('Vous avez déjà les clés', 'info')
        return false
    end
    
    isCarjacking = true
    
    -- Calculer la durée
    local duration = math.random(KeysConfig.CarJack.MinDuration, KeysConfig.CarJack.MaxDuration)
    
    -- Animation
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 1000)
    Wait(500)
    
    -- Progressbar
    ShowKeysNotif('Tentative de vol...', 'info')
    
    local animDict = "missheistfbisetup1"
    local animName = "hassle_intro_loop_f"
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, duration, 1, 0, false, false, false)
    
    -- Timer
    local startTime = GetGameTimer()
    local cancelled = false
    
    while GetGameTimer() - startTime < duration do
        Wait(100)
        
        -- Annulation si le joueur bouge trop
        if not IsEntityPlayingAnim(ped, animDict, animName, 3) then
            cancelled = true
            break
        end
        
        -- Annulation si le joueur presse une touche
        if IsControlPressed(0, 200) then -- ESC
            cancelled = true
            break
        end
    end
    
    ClearPedTasks(ped)
    isCarjacking = false
    
    if cancelled then
        ShowKeysNotif('Vol annulé', 'error')
        return false
    end
    
    -- Calculer le succès
    local success = math.random(1, 100) <= KeysConfig.CarJack.SuccessChance
    
    if success then
        -- Donner les clés
        TriggerServerEvent('vAvA_keys:carjackSuccess', plate)
        ShowKeysNotif('Vous avez obtenu les clés !', 'success')
        
        -- Alerter la police ?
        if KeysConfig.CarJack.AlertPolice then
            local coords = GetEntityCoords(vehicle)
            TriggerServerEvent('vAvA_keys:alertPolice', coords, 'Tentative de vol de véhicule')
        end
        
        return true
    else
        ShowKeysNotif('Le vol a échoué', 'error')
        
        -- Alerter la police même en cas d'échec
        if KeysConfig.CarJack.AlertPolice then
            local coords = GetEntityCoords(vehicle)
            TriggerServerEvent('vAvA_keys:alertPolice', coords, 'Tentative de vol de véhicule')
        end
        
        return false
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_keys:carjackSuccess')
AddEventHandler('vAvA_keys:carjackSuccess', function(plate)
    plate = string.gsub(plate, "%s+", "")
    _G.playerKeys[plate] = true
end)
