-- ========================================
-- SYSTÈME EMS - CLIENT PRINCIPAL
-- ========================================

local vCore = exports['vAvA_core']
local PlayerData = {}
local MedicalState = nil
local InHospital = false
local CurrentTarget = nil

-- ========================================
-- INITIALISATION
-- ========================================

CreateThread(function()
    Wait(1000)
    TriggerServerEvent('vAvA_ems:server:requestMedicalData')
end)

-- ========================================
-- GESTION DE L'ÉTAT MÉDICAL
-- ========================================

-- Mettre à jour l'état médical local
RegisterNetEvent('vAvA_ems:client:updateMedicalState', function(state)
    MedicalState = state
    
    -- Mettre à jour le HUD
    if EMSConfig.HUD.enabled then
        SendNUIMessage({
            action = 'updateVitals',
            data = state.vitalSigns
        })
    end
    
    -- Appliquer les effets
    ApplyMedicalEffects()
end)

-- Appliquer les effets visuels et gameplay
function ApplyMedicalEffects()
    if not MedicalState then return end
    
    local state = MedicalState.state
    local effects = EMSConfig.StateEffects[state]
    
    if not effects then
        -- État normal - réinitialiser
        ClearMedicalEffects()
        return
    end
    
    -- Effets de mouvement
    if effects.moveSpeed then
        SetPedMoveRateOverride(PlayerPedId(), effects.moveSpeed)
    end
    
    -- Effets de stamina
    if effects.stamina then
        local multiplier = effects.stamina
        -- Appliquer via native (simulé)
        RestorePlayerStamina(PlayerId(), 1.0 * multiplier)
    end
    
    -- Effets visuels
    if effects.blurredVision then
        ApplyBlurEffect()
    end
    
    if effects.screenShake then
        ApplyScreenShake()
    end
    
    -- Ragdoll si inconscient
    if effects.ragdoll then
        SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, 0, 0, 0)
    end
end

-- Réinitialiser les effets
function ClearMedicalEffects()
    SetPedMoveRateOverride(PlayerPedId(), 1.0)
    ClearTimecycleModifier()
    ShakeGameplayCam('DRUNK_SHAKE', 0.0)
end

-- Effet de flou
function ApplyBlurEffect()
    if not HasStreamedTextureDictLoaded("timecycle_mods_heavy") then
        RequestStreamedTextureDict("timecycle_mods_heavy", true)
        while not HasStreamedTextureDictLoaded("timecycle_mods_heavy") do
            Wait(0)
        end
    end
    
    SetTimecycleModifier("BikerFilter")
    SetTimecycleModifierStrength(0.3)
end

-- Effet de tremblement
function ApplyScreenShake()
    ShakeGameplayCam('DRUNK_SHAKE', 0.3)
end

-- ========================================
-- INTERACTIONS EMS
-- ========================================

-- Menu principal EMS
function OpenEMSMenu()
    local playerJob = vCore:GetPlayerData().job
    if not playerJob or playerJob.name ~= EMSConfig.EMSJob then
        vCore:Notify(Lang('not_ems'), 'error')
        return
    end
    
    -- Ouvrir le menu NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openEMSMenu',
        data = {
            grade = playerJob.grade,
            bloodStock = nil -- Sera chargé via callback
        }
    })
end

-- Diagnostiquer un patient
function DiagnosePatient(targetId)
    local playerJob = vCore:GetPlayerData().job
    if not playerJob or playerJob.name ~= EMSConfig.EMSJob then
        vCore:Notify(Lang('not_ems'), 'error')
        return
    end
    
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    local playerPed = PlayerPedId()
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    if distance > 3.0 then
        vCore:Notify(Lang('too_far'), 'error')
        return
    end
    
    -- Animation d'examen
    TaskStartScenarioInPlace(playerPed, "CODE_HUMAN_MEDIC_TEND_TO_DEAD", 0, true)
    
    -- Attendre 5 secondes
    local examining = true
    CreateThread(function()
        Wait(5000)
        examining = false
        ClearPedTasks(playerPed)
    end)
    
    -- Afficher une barre de progression
    exports['vAvA_core']:ShowProgressBar(5000, Lang('examining_patient'))
    
    Wait(5000)
    
    -- Obtenir les données médicales du patient
    vCore:TriggerCallback('vAvA_ems:getPatientData', function(patientData)
        if patientData then
            -- Ouvrir l'interface de diagnostic
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openDiagnosis',
                data = patientData
            })
        else
            vCore:Notify(Lang('diagnosis_failed'), 'error')
        end
    end, targetId)
end

-- Utiliser un équipement médical
function UseEquipment(equipmentName, targetId)
    local playerJob = vCore:GetPlayerData().job
    if not playerJob or playerJob.name ~= EMSConfig.EMSJob then
        vCore:Notify(Lang('not_ems'), 'error')
        return
    end
    
    -- Vérifier que le joueur a l'item
    local hasItem = exports['vAvA_core']:HasItem(equipmentName)
    if not hasItem then
        vCore:Notify(Lang('missing_equipment'), 'error')
        return
    end
    
    -- Animation
    local playerPed = PlayerPedId()
    TaskStartScenarioInPlace(playerPed, "CODE_HUMAN_MEDIC_TEND_TO_DEAD", 0, true)
    
    Wait(3000)
    
    ClearPedTasks(playerPed)
    
    -- Appliquer l'effet (côté serveur)
    TriggerServerEvent('vAvA_ems:server:useEquipment', equipmentName, targetId)
end

-- Réanimer un joueur
RegisterNetEvent('vAvA_ems:client:revive', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    
    -- Animation de réveil
    DoScreenFadeOut(1000)
    Wait(1000)
    
    -- Restaurer la santé
    SetEntityHealth(playerPed, 200)
    
    -- Réinitialiser l'état
    MedicalState.state = EMSConfig.MedicalStates.NORMAL
    MedicalState.vitalSigns.bloodVolume = 100
    MedicalState.vitalSigns.pulse = 75
    
    ClearMedicalEffects()
    
    DoScreenFadeIn(1000)
    
    vCore:Notify(Lang('revived'), 'success')
end)

-- ========================================
-- SYSTÈME D'APPELS D'URGENCE
-- ========================================

-- Appeler les urgences (911)
function CallEmergency()
    -- Menu de sélection du type d'urgence
    local elements = {}
    
    for code, data in pairs(EMSConfig.EmergencyCalls.codes) do
        table.insert(elements, {
            label = data.label,
            value = code
        })
    end
    
    -- Ouvrir un menu (à adapter selon votre système de menu)
    vCore:ShowMenu({
        title = Lang('emergency_call'),
        elements = elements
    }, function(data)
        local callType = data.value
        
        -- Input pour le message
        local message = vCore:GetInput(Lang('describe_emergency'), '', 100)
        
        if message then
            TriggerServerEvent('vAvA_ems:server:emergencyCall', callType, message)
            vCore:Notify(Lang('emergency_called'), 'success')
        end
    end)
end

-- Recevoir un nouvel appel d'urgence
RegisterNetEvent('vAvA_ems:client:newEmergencyCall', function(call)
    local playerJob = vCore:GetPlayerData().job
    if not playerJob or playerJob.name ~= EMSConfig.EMSJob then return end
    
    -- Notification sonore
    PlaySound(-1, "Menu_Accept", "Phone_SoundSet_Default", 0, 0, 1)
    
    -- Notification visuelle
    local code = EMSConfig.EmergencyCalls.codes[call.type]
    vCore:Notify(string.format("%s - %s", code.label, call.location), 'info', 10000)
    
    -- Waypoint sur la map
    SetNewWaypoint(call.coords.x, call.coords.y)
    
    -- Blip temporaire
    local blip = AddBlipForCoord(call.coords.x, call.coords.y, call.coords.z)
    SetBlipSprite(blip, 153)
    SetBlipColour(blip, 1)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 1)
    
    -- Retirer le blip après 5 minutes
    CreateThread(function()
        Wait(300000)
        RemoveBlip(blip)
    end)
end)

-- ========================================
-- HÔPITAL
-- ========================================

-- Zones de l'hôpital
CreateThread(function()
    for zoneName, coords in pairs(EMSConfig.Hospital.zones) do
        -- Créer des blips/markers si nécessaire
    end
end)

-- Don de sang
RegisterNetEvent('vAvA_ems:client:openBloodDonation', function()
    -- Confirmation
    vCore:ShowConfirm({
        title = Lang('blood_donation_title'),
        message = Lang('blood_donation_confirm'),
        onConfirm = function()
            TriggerServerEvent('vAvA_ems:server:donateBlood')
        end
    })
end)

-- Effets après don de sang
RegisterNetEvent('vAvA_ems:client:bloodDonationEffects', function(duration)
    local endTime = GetGameTimer() + (duration * 1000)
    
    CreateThread(function()
        while GetGameTimer() < endTime do
            Wait(0)
            
            -- Ralentissement léger
            local ped = PlayerPedId()
            SetPedMoveRateOverride(ped, 0.90)
            
            -- Légère fatigue visuelle
            SetTimecycleModifier("hud_def_blur")
            SetTimecycleModifierStrength(0.1)
        end
        
        -- Réinitialiser
        SetPedMoveRateOverride(PlayerPedId(), 1.0)
        ClearTimecycleModifier()
        
        vCore:Notify(Lang('blood_donation_effects_end'), 'success')
    end)
end)

-- ========================================
-- MORT & RESPAWN
-- ========================================

local IsDead = false
local DeathTime = 0

-- Gérer la mort
CreateThread(function()
    while true do
        Wait(0)
        
        local playerPed = PlayerPedId()
        
        if IsEntityDead(playerPed) and not IsDead then
            IsDead = true
            DeathTime = GetGameTimer()
            
            -- Désactiver les contrôles
            DisableAllControlActions(0)
            
            -- Notification
            vCore:Notify(Lang('you_are_dead'), 'error')
            
            -- Écran noir
            DoScreenFadeOut(1000)
            Wait(1000)
            
            -- Attendre l'aide EMS
            local canRespawn = false
            CreateThread(function()
                Wait(EMSConfig.Death.unconsciousTime * 1000)
                canRespawn = true
                vCore:Notify(Lang('can_respawn'), 'info')
            end)
            
            -- Boucle de mort
            while IsDead do
                Wait(0)
                
                DrawGenericText(Lang('waiting_ems'))
                
                if canRespawn then
                    DrawGenericText(Lang('press_respawn'))
                    
                    if IsControlJustPressed(0, 38) then -- E
                        RespawnAtHospital()
                    end
                end
            end
        end
        
        if not IsEntityDead(playerPed) and IsDead then
            IsDead = false
        end
    end
end)

-- Respawn à l'hôpital
function RespawnAtHospital()
    DoScreenFadeOut(1000)
    Wait(1000)
    
    local playerPed = PlayerPedId()
    local respawnCoords = EMSConfig.Death.respawnLocation
    
    -- Téléporter
    SetEntityCoords(playerPed, respawnCoords.x, respawnCoords.y, respawnCoords.z, false, false, false, false)
    SetEntityHeading(playerPed, respawnCoords.w)
    
    -- Restaurer
    ResurrectPed(playerPed)
    SetEntityHealth(playerPed, 200)
    ClearPedBloodDamage(playerPed)
    
    IsDead = false
    
    -- Coût
    local xPlayer = vCore:GetPlayerData()
    if xPlayer then
        TriggerServerEvent('vAvA_core:removeMoney', 'bank', EMSConfig.Death.respawnCost)
        vCore:Notify(Lang('respawn_cost', {cost = EMSConfig.Death.respawnCost}), 'info')
    end
    
    DoScreenFadeIn(1000)
end

-- ========================================
-- HELPERS
-- ========================================

function DrawGenericText(text)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.5, 0.8)
end

-- ========================================
-- NUI CALLBACKS
-- ========================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('useEquipment', function(data, cb)
    UseEquipment(data.equipment, data.target)
    cb('ok')
end)

RegisterNUICallback('diagnosePatient', function(data, cb)
    DiagnosePatient(data.target)
    cb('ok')
end)

RegisterNUICallback('transfuseBlood', function(data, cb)
    TriggerServerEvent('vAvA_ems:server:transfuseBlood', data.target, data.bloodType)
    cb('ok')
end)

-- ========================================
-- EXPORTS
-- ========================================

exports('GetLocalMedicalState', function()
    return MedicalState
end)

exports('OpenEMSMenu', OpenEMSMenu)
exports('OpenPatientDiagnosis', DiagnosePatient)
exports('UseEquipment', UseEquipment)

-- ========================================
-- COMMANDES
-- ========================================

RegisterCommand('ems', function()
    OpenEMSMenu()
end, false)

RegisterCommand('911', function()
    CallEmergency()
end, false)

RegisterCommand('revive', function()
    if EMSConfig.Debug then
        TriggerEvent('vAvA_ems:client:revive')
    end
end, false)
