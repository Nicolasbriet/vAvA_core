-- ========================================
-- EXEMPLES D'INTÉGRATION - vAvA_ems
-- ========================================

-- Ce fichier contient des exemples d'intégration du module EMS
-- avec d'autres ressources ou systèmes

-- ========================================
-- EXEMPLE 1: Dégâts par Balle
-- ========================================

-- À ajouter dans votre ressource de combat/armes
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local weapon = args[7]
        
        if IsEntityAPed(victim) and IsPedAPlayer(victim) then
            local player = PlayerId()
            if PlayerPedId() == victim then
                local victimId = GetPlayerServerId(player)
                
                -- Déterminer la zone touchée
                local boneHit = GetPedLastDamageBone(victim)
                local bodyPart = 'chest' -- Par défaut
                
                if boneHit == 31086 then bodyPart = 'head'
                elseif boneHit == 24817 or boneHit == 24818 then bodyPart = 'left_leg'
                elseif boneHit == 51826 or boneHit == 52301 then bodyPart = 'right_leg'
                elseif boneHit == 61163 or boneHit == 18905 then bodyPart = 'left_arm'
                elseif boneHit == 28252 or boneHit == 57005 then bodyPart = 'right_arm'
                elseif boneHit == 23553 or boneHit == 24816 then bodyPart = 'chest'
                elseif boneHit == 11816 then bodyPart = 'abdomen'
                end
                
                -- Ajouter blessure par balle
                TriggerServerEvent('vAvA_ems:addGunshot', bodyPart)
            end
        end
    end
end)

-- Côté serveur
RegisterNetEvent('vAvA_ems:addGunshot', function(bodyPart)
    local source = source
    
    -- Blessure d'entrée
    exports['vAvA_ems']:AddInjury(source, 'gunshot_entry', bodyPart, 3)
    
    -- Réduire volume sanguin (hémorragie)
    local vitals = exports['vAvA_ems']:GetVitalSigns(source)
    if vitals then
        local newVolume = math.max(0, vitals.bloodVolume - 15)
        exports['vAvA_ems']:SetVitalSign(source, 'bloodVolume', newVolume)
    end
    
    -- Augmenter la douleur
    exports['vAvA_ems']:SetVitalSign(source, 'painLevel', 8)
end)

-- ========================================
-- EXEMPLE 2: Accident de Voiture
-- ========================================

-- À ajouter dans votre ressource de véhicules
CreateThread(function()
    while true do
        Wait(500)
        
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local speed = GetEntitySpeed(vehicle) * 3.6 -- km/h
            
            if HasEntityCollidedWithAnything(vehicle) and speed > 50 then
                -- Collision à plus de 50 km/h
                local severity = 1
                if speed > 100 then severity = 3
                elseif speed > 70 then severity = 2
                end
                
                -- Blessures aléatoires
                TriggerServerEvent('vAvA_ems:carAccident', severity)
                
                Wait(5000) -- Cooldown 5 secondes
            end
        end
    end
end)

-- Côté serveur
RegisterNetEvent('vAvA_ems:carAccident', function(severity)
    local source = source
    
    -- Traumatisme crânien
    exports['vAvA_ems']:AddInjury(source, 'head_trauma', 'head', severity)
    
    -- Contusions diverses
    local bodyParts = {'chest', 'left_arm', 'right_arm', 'left_leg', 'right_leg'}
    for i = 1, math.random(2, 4) do
        local part = bodyParts[math.random(#bodyParts)]
        exports['vAvA_ems']:AddInjury(source, 'contusion', part, math.max(1, severity - 1))
    end
    
    -- Possible fracture
    if severity >= 2 then
        exports['vAvA_ems']:AddInjury(source, 'simple_fracture', 'left_leg', severity)
    end
    
    -- Augmenter la douleur
    exports['vAvA_ems']:SetVitalSign(source, 'painLevel', 4 + severity)
end)

-- ========================================
-- EXEMPLE 3: Chute de Grande Hauteur
-- ========================================

-- Client
local lastZ = 0
local falling = false

CreateThread(function()
    while true do
        Wait(100)
        
        local ped = PlayerPedId()
        if IsPedFalling(ped) and not falling then
            falling = true
            lastZ = GetEntityCoords(ped).z
        elseif falling and not IsPedFalling(ped) then
            falling = false
            local currentZ = GetEntityCoords(ped).z
            local fallDistance = lastZ - currentZ
            
            if fallDistance > 5.0 then
                -- Chute de plus de 5 mètres
                local severity = math.min(4, math.floor(fallDistance / 5))
                TriggerServerEvent('vAvA_ems:fallDamage', severity, fallDistance)
            end
        end
    end
end)

-- Serveur
RegisterNetEvent('vAvA_ems:fallDamage', function(severity, distance)
    local source = source
    
    -- Blessures aux jambes
    exports['vAvA_ems']:AddInjury(source, 'simple_fracture', 'left_leg', severity)
    exports['vAvA_ems']:AddInjury(source, 'simple_fracture', 'right_leg', severity)
    
    if severity >= 3 then
        -- Traumatisme crânien
        exports['vAvA_ems']:AddInjury(source, 'head_trauma', 'head', severity)
        
        -- Lésions internes
        exports['vAvA_ems']:AddInjury(source, 'internal_injury', 'chest', severity)
    end
    
    -- Douleur
    exports['vAvA_ems']:SetVitalSign(source, 'painLevel', 5 + severity)
end)

-- ========================================
-- EXEMPLE 4: Incendie / Brûlures
-- ========================================

-- Client
CreateThread(function()
    while true do
        Wait(1000)
        
        local ped = PlayerPedId()
        if IsPedOnFire(ped) then
            -- Le joueur brûle
            TriggerServerEvent('vAvA_ems:burning')
            Wait(5000) -- Check toutes les 5 secondes tant qu'il brûle
        end
    end
end)

-- Serveur
RegisterNetEvent('vAvA_ems:burning', function()
    local source = source
    
    -- Brûlures aléatoires
    local bodyParts = {'head', 'chest', 'left_arm', 'right_arm', 'left_leg', 'right_leg'}
    local burnType = 'burn_second' -- Par défaut 2e degré
    
    for i = 1, math.random(2, 4) do
        local part = bodyParts[math.random(#bodyParts)]
        exports['vAvA_ems']:AddInjury(source, burnType, part, 2)
    end
    
    -- Douleur intense
    exports['vAvA_ems']:SetVitalSign(source, 'painLevel', 7)
end)

-- ========================================
-- EXEMPLE 5: Système de Faim/Soif
-- ========================================

-- Si vous avez un système de faim/soif, l'intégrer avec les signes vitaux

-- Serveur (dans votre système de status)
AddEventHandler('vAvA_status:hungerCritical', function(playerId)
    -- Faim critique affecte la santé
    local vitals = exports['vAvA_ems']:GetVitalSigns(playerId)
    if vitals then
        -- Réduire légèrement le volume sanguin (déshydratation)
        local newVolume = math.max(60, vitals.bloodVolume - 5)
        exports['vAvA_ems']:SetVitalSign(playerId, 'bloodVolume', newVolume)
        
        -- Augmenter légèrement la douleur
        local newPain = math.min(10, vitals.painLevel + 1)
        exports['vAvA_ems']:SetVitalSign(playerId, 'painLevel', newPain)
    end
end)

-- ========================================
-- EXEMPLE 6: Notification EMS Personnalisée
-- ========================================

-- Dans n'importe quelle ressource, créer un appel EMS custom

-- Client
RegisterCommand('appelems', function()
    -- Menu personnalisé pour type d'urgence
    local urgencyTypes = {
        { label = '🔴 Urgence Vitale', value = 'RED' },
        { label = '🟠 Urgence', value = 'ORANGE' },
        { label = '🟡 Semi-urgence', value = 'YELLOW' },
        { label = '🔵 Assistance', value = 'BLUE' }
    }
    
    -- Votre système de menu ici
    -- Exemple simplifié:
    local urgencyType = 'YELLOW' -- Choisi par le joueur
    local message = 'Je me suis blessé en tombant'
    
    TriggerServerEvent('vAvA_ems:server:emergencyCall', urgencyType, message)
end)

-- ========================================
-- EXEMPLE 7: Mort RP Définitive
-- ========================================

-- Si vous voulez activer la mort RP définitive sous certaines conditions

-- Serveur
AddEventHandler('vAvA_ems:playerDied', function(playerId, cause)
    local state = exports['vAvA_ems']:GetPlayerMedicalState(playerId)
    
    if state then
        -- Conditions pour mort RP définitive
        local canPermadeath = false
        
        -- Exemple: Si le joueur a trop de blessures critiques non soignées
        local criticalInjuries = 0
        for _, injury in ipairs(state.injuries) do
            if injury.severity >= 3 then
                criticalInjuries = criticalInjuries + 1
            end
        end
        
        if criticalInjuries >= 3 then
            canPermadeath = true
        end
        
        -- Ou si volume sanguin = 0 depuis trop longtemps
        if state.vitalSigns.bloodVolume <= 0 then
            canPermadeath = true
        end
        
        if canPermadeath then
            -- Gérer la mort RP définitive
            -- (par exemple, réinitialiser le personnage)
            TriggerEvent('vAvA_core:deleteCharacter', playerId)
        end
    end
end)

-- ========================================
-- EXEMPLE 8: Expérience EMS
-- ========================================

-- Système d'XP pour récompenser les EMS

-- Serveur
local EMSExperience = {}

RegisterNetEvent('vAvA_ems:treatmentComplete', function(patientId, treatmentType)
    local source = source
    local xPlayer = exports['vAvA_core']:GetPlayer(source)
    
    if xPlayer and xPlayer:GetJob().name == 'ambulance' then
        -- Donner de l'XP selon le traitement
        local xpGain = 0
        
        if treatmentType == 'diagnosis' then xpGain = 10
        elseif treatmentType == 'treatment' then xpGain = 25
        elseif treatmentType == 'surgery' then xpGain = 100
        elseif treatmentType == 'transfusion' then xpGain = 75
        elseif treatmentType == 'revive' then xpGain = 150
        end
        
        -- Ajouter l'XP (système à créer)
        EMSExperience[source] = (EMSExperience[source] or 0) + xpGain
        
        TriggerClientEvent('vAvA_core:Notify', source, 
            string.format('XP EMS: +%d (Total: %d)', xpGain, EMSExperience[source]), 'success')
    end
end)

-- ========================================
-- EXEMPLE 9: Statistiques Hôpital
-- ========================================

-- Tracker les statistiques médicales

-- Serveur
local HospitalStats = {
    patientsToday = 0,
    revenuesToday = 0,
    bloodDonationsToday = 0,
    emergencyCallsToday = 0
}

RegisterNetEvent('vAvA_ems:patientTreated', function(cost)
    HospitalStats.patientsToday = HospitalStats.patientsToday + 1
    HospitalStats.revenuesToday = HospitalStats.revenuesToday + cost
end)

RegisterNetEvent('vAvA_ems:bloodDonated', function()
    HospitalStats.bloodDonationsToday = HospitalStats.bloodDonationsToday + 1
end)

-- Réinitialiser à minuit
CreateThread(function()
    while true do
        Wait(3600000) -- 1 heure
        
        local currentHour = tonumber(os.date('%H'))
        if currentHour == 0 then
            -- Minuit - Réinitialiser les stats
            HospitalStats = {
                patientsToday = 0,
                revenuesToday = 0,
                bloodDonationsToday = 0,
                emergencyCallsToday = 0
            }
        end
    end
end)

-- ========================================
-- EXEMPLE 10: Animations Personnalisées
-- ========================================

-- Ajouter des animations custom pour les traitements

-- Client
function PlayMedicalAnimation(animType)
    local ped = PlayerPedId()
    local animDict, animName
    
    if animType == 'bandage' then
        animDict = 'amb@world_human_clipboard@male@idle_a'
        animName = 'idle_c'
    elseif animType == 'injection' then
        animDict = 'mp_arresting'
        animName = 'a_uncuff'
    elseif animType == 'cpr' then
        animDict = 'mini@cpr@char_a@cpr_str'
        animName = 'cpr_pumpchest'
    elseif animType == 'surgery' then
        animDict = 'amb@medic@standing@tendtodead@base'
        animName = 'base'
    end
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(0)
    end
    
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
end

-- Utilisation
RegisterNetEvent('vAvA_ems:playAnimation', function(animType)
    PlayMedicalAnimation(animType)
end)

--[[
    
    CES EXEMPLES MONTRENT COMMENT INTÉGRER vAvA_ems AVEC:
    
    1. Système de combat/armes (dégâts par balle)
    2. Véhicules (accidents)
    3. Chutes (dégâts chute)
    4. Incendies (brûlures)
    5. Faim/Soif (status)
    6. Appels personnalisés
    7. Mort RP définitive
    8. Système d'XP EMS
    9. Statistiques hôpital
    10. Animations custom
    
    Adaptez ces exemples à vos besoins spécifiques !
    
]]
