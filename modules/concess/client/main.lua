print('^2[vCore:Concess] Script client chargé^0')

--[[
    vAvA Core - Module Concessionnaire
    Client: Interface utilisateur et preview des véhicules
]]

-- Variables globales
local nuiOpen = false
local staticCam = nil
local vehicles = {}
local categories = {}
local playerJob = nil
local dealershipBlips = {}
local previewVeh = nil
local previewVehHeading = 103.04
local lastConcessPosition = nil
local currentVehicleType = 'cars'
local currentIsJobOnly = false
local distanceCheckActive = false
local currentDealershipPosition = nil
local lastCloseTime = 0

-- ================================
-- EXPORTS CLIENT
-- ================================

-- Ouvrir un concessionnaire spécifique
exports('OpenDealership', function(dealershipId)
    if not ConcessConfig.Dealerships[dealershipId] then
        print('[vCore:Concess] Concessionnaire non trouvé: ' .. tostring(dealershipId))
        return false
    end
    
    local dealership = ConcessConfig.Dealerships[dealershipId]
    lastConcessPosition = dealership.position
    TriggerServerEvent('vcore_concess:requestVehicles', dealership.isJobOnly, dealership.vehicleType)
    return true
end)

-- Fermer le concessionnaire
exports('CloseDealership', function()
    SafeCloseConcessionnaire()
    return true
end)

-- Vérifier si le NUI est ouvert
exports('IsNUIOpen', function()
    return nuiOpen
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

-- Fermeture sécurisée du concessionnaire
function SafeCloseConcessionnaire()
    -- Désactiver la surveillance
    ToggleDistanceCheck(false)
    
    -- Nettoyer le véhicule preview
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
        previewVeh = nil
    end
    
    -- Restaurer la caméra AVANT le NUI
    if staticCam then
        RenderScriptCams(false, true, 500, true, true)
        Wait(100)
        SetCamActive(staticCam, false)
        DestroyCam(staticCam, false)
        staticCam = nil
    end
    
    -- Restaurer le joueur
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    
    -- Reset caméra gameplay
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0, 1.0)
    
    -- Fermer le NUI
    SetNuiFocus(false, false)
    nuiOpen = false
    SendNUIMessage({ action = 'close' })
    
    lastCloseTime = GetGameTimer()
end

-- Alias pour compatibilité
function cleanupPreviewOnExit()
    SafeCloseConcessionnaire()
end

-- Reset forcé de la caméra
function ForceResetCamera()
    RenderScriptCams(false, true, 0, true, true)
    
    if staticCam then
        SetCamActive(staticCam, false)
        DestroyCam(staticCam, false)
        staticCam = nil
    end
    
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0, 1.0)
end

-- Toggle de la surveillance de distance
function ToggleDistanceCheck(enable)
    distanceCheckActive = enable
end

-- Obtenir les coordonnées de preview selon le type
function GetPreviewCoords(vehicleType, isJobOnly)
    while not ConcessConfig or not ConcessConfig.Dealerships do
        Wait(100)
    end
    
    -- Déterminer automatiquement le type si nil
    if not vehicleType or not isJobOnly then
        local plyPed = PlayerPedId()
        local plyCoords = GetEntityCoords(plyPed)
        
        for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
            local dist = #(plyCoords - dealership.position)
            if dist <= 50.0 then
                vehicleType = dealership.vehicleType
                isJobOnly = dealership.isJobOnly
                break
            end
        end
    end
    
    -- Chercher le concessionnaire exact
    for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
        local jobMatch = (dealership.isJobOnly == true and isJobOnly == true) or 
                         (dealership.isJobOnly == false and (isJobOnly == false or isJobOnly == nil))
        
        if dealership.vehicleType == vehicleType and jobMatch then
            return dealership.previewSpawn.coords, dealership.previewSpawn.heading
        end
    end
    
    -- Fallback
    if ConcessConfig.Dealerships['cars_civilian'] then
        return ConcessConfig.Dealerships['cars_civilian'].previewSpawn.coords,
               ConcessConfig.Dealerships['cars_civilian'].previewSpawn.heading
    end
    
    return vector3(-42.53, -1098.4, 26.42), 103.04
end

-- Obtenir les coordonnées de caméra
function GetCameraCoords(vehicleType, isJobOnly)
    while not ConcessConfig or not ConcessConfig.Dealerships do
        Wait(100)
    end
    
    for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
        if dealership.vehicleType == vehicleType and dealership.isJobOnly == (isJobOnly or false) then
            return dealership.camera.coords, dealership.camera.rotation
        end
    end
    
    -- Fallback
    if ConcessConfig.Dealerships['cars_civilian'] then
        return ConcessConfig.Dealerships['cars_civilian'].camera.coords,
               ConcessConfig.Dealerships['cars_civilian'].camera.rotation
    end
    
    return vector3(-48.5, -1098.5, 26.8), vector3(-5.0, 0.0, 265.0)
end

-- Assurer un spawn propre au sol
function EnsureGroundSpawn(coords, vehicleType)
    local x, y, z = coords.x, coords.y, coords.z
    
    -- Bateaux: garder la hauteur configurée
    if vehicleType == 'boats' then
        local area = GetClosestVehicle(x, y, z, 5.0, 0, 71)
        if DoesEntityExist(area) and area ~= previewVeh then
            SetEntityAsMissionEntity(area, true, true)
            DeleteVehicle(area)
        end
        ClearAreaOfObjects(x, y, z, 5.0, 0)
        return vector3(x, y, z)
    end
    
    -- Autres véhicules: trouver le sol
    local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z, false)
    if foundGround then
        if vehicleType == 'helicopters' or vehicleType == 'planes' then
            z = groundZ + 3.0
        else
            z = groundZ + 0.5
        end
    end
    
    local area = GetClosestVehicle(x, y, z, 5.0, 0, 71)
    if DoesEntityExist(area) and area ~= previewVeh then
        SetEntityAsMissionEntity(area, true, true)
        DeleteVehicle(area)
    end
    ClearAreaOfObjects(x, y, z, 5.0, 0)
    
    return vector3(x, y, z)
end

-- ================================
-- COMMANDES
-- ================================

RegisterCommand('fixcam', function()
    ForceResetCamera()
    cleanupPreviewOnExit()
    
    if nuiOpen then
        SetNuiFocus(false, false)
        nuiOpen = false
    end
    
    print('[vCore:Concess] Reset effectué')
end, false)

-- Commande de test pour ouvrir le concess
RegisterCommand('testconcess', function(source, args)
    local dealershipId = args[1] or 'cars_civilian'
    
    if not ConcessConfig.Dealerships[dealershipId] then
        print('[vCore:Concess] Concessionnaire invalide. IDs disponibles:')
        for id, _ in pairs(ConcessConfig.Dealerships) do
            print('  - ' .. id)
        end
        return
    end
    
    local dealership = ConcessConfig.Dealerships[dealershipId]
    lastConcessPosition = dealership.position
    currentIsJobOnly = dealership.isJobOnly
    currentVehicleType = dealership.vehicleType
    currentDealershipPosition = dealership.position
    
    print('[vCore:Concess] Ouverture test: ' .. dealershipId)
    TriggerServerEvent('vcore_concess:requestVehicles', dealership.isJobOnly, dealership.vehicleType)
end, false)

-- ================================
-- CALLBACKS NUI
-- ================================

-- Sélection d'un véhicule pour preview
RegisterNUICallback('selectPreview', function(data, cb)
    ToggleDistanceCheck(true)
    
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    
    -- Supprimer l'ancien preview
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
        previewVeh = nil
    end
    
    local spawnCoords, heading = GetPreviewCoords(currentVehicleType, currentIsJobOnly)
    spawnCoords = EnsureGroundSpawn(spawnCoords, currentVehicleType)
    
    -- Créer le véhicule preview
    local vehHash = GetHashKey(data.model)
    RequestModel(vehHash)
    while not HasModelLoaded(vehHash) do Wait(10) end
    
    previewVeh = CreateVehicle(vehHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, heading, false, true)
    SetEntityAsMissionEntity(previewVeh, true, true)
    SetVehicleExtraColours(previewVeh, 0, 0)
    
    if currentVehicleType ~= 'boats' then
        SetVehicleOnGroundProperly(previewVeh)
    end
    
    previewVehHeading = heading
    
    if data.livery and data.livery >= 0 then
        SetVehicleLivery(previewVeh, data.livery)
    end
    
    cb('ok')
end)

-- Rotation du véhicule preview
RegisterNUICallback('rotatePreview', function(data, cb)
    if previewVeh and DoesEntityExist(previewVeh) then
        local step = 15.0
        if data.direction == 'left' then
            previewVehHeading = (previewVehHeading - step) % 360
        elseif data.direction == 'right' then
            previewVehHeading = (previewVehHeading + step) % 360
        end
        SetEntityHeading(previewVeh, previewVehHeading)
    end
    cb('ok')
end)

-- Changement de couleur
RegisterNUICallback('changeColor', function(data, cb)
    if previewVeh and DoesEntityExist(previewVeh) then
        local primary = tonumber(data.primary) or 0
        local secondary = tonumber(data.secondary) or 0
        SetVehicleColours(previewVeh, primary, secondary)
    end
    cb('ok')
end)

-- Changement de livrée
RegisterNUICallback('changeLivery', function(data, cb)
    if previewVeh and DoesEntityExist(previewVeh) then
        local livery = tonumber(data.livery)
        if livery and livery >= 0 then
            SetVehicleLivery(previewVeh, livery)
            Wait(50)
            SetVehicleLivery(previewVeh, livery)
        else
            SetVehicleLivery(previewVeh, -1)
        end
    end
    cb('ok')
end)

-- Obtenir le nombre de livrées
RegisterNUICallback('getLiveryCount', function(data, cb)
    local maxLiveries = 0
    if previewVeh and DoesEntityExist(previewVeh) then
        maxLiveries = GetVehicleLiveryCount(previewVeh)
    end
    cb(maxLiveries)
end)

-- Fermeture du NUI
RegisterNUICallback('close', function(_, cb)
    cb('ok')
    SafeCloseConcessionnaire()
    currentDealershipPosition = nil
    
    if lastConcessPosition then
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, lastConcessPosition.x, lastConcessPosition.y, lastConcessPosition.z, false, false, false, true)
    end
end)

-- Achat d'un véhicule
RegisterNUICallback('buyVehicle', function(data, cb)
    data.vehicleType = currentVehicleType
    data.isJobOnly = currentIsJobOnly
    TriggerServerEvent('vcore_concess:buyVehicle', data)
    cb('ok')
end)

-- Actions admin
RegisterNUICallback('adminAction', function(data, cb)
    TriggerServerEvent('vcore_concess:adminAction', data)
    cb('ok')
end)

RegisterNUICallback('chooseColor', function(data, cb)
    cb('ok')
end)

-- ================================
-- EVENTS CLIENT
-- ================================

-- Fermeture forcée du NUI
RegisterNetEvent('vcore_concess:closeNUI')
AddEventHandler('vcore_concess:closeNUI', function()
    if nuiOpen == nil then
        nuiOpen = false
    end
    
    cleanupPreviewOnExit()
    currentDealershipPosition = nil
    
    if nuiOpen then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'close' })
    end
    nuiOpen = false
    
    currentVehicleType = 'cars'
    currentIsJobOnly = false
    lastCloseTime = GetGameTimer()
end)

-- Réception des véhicules
RegisterNetEvent('vcore_concess:sendVehicles')
AddEventHandler('vcore_concess:sendVehicles', function(vehList, isAdmin, serverPlayerJob, vehicleType, isJobOnly)
    print('^2[vCore:Concess] Event reçu: vcore_concess:sendVehicles^0')
    print('^2[vCore:Concess] Nombre de véhicules reçus: ' .. tostring(#vehList) .. '^0')
    playerJob = serverPlayerJob
    currentVehicleType = vehicleType or 'cars'
    currentIsJobOnly = isJobOnly or false
    
    -- Trouver la position du concessionnaire
    local plyPed = PlayerPedId()
    local plyCoords = GetEntityCoords(plyPed)
    for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
        local dist = #(plyCoords - dealership.position)
        if dist <= ConcessConfig.General.InteractionDistance then
            currentDealershipPosition = dealership.position
            break
        end
    end
    
    vehicles = vehList
    categories = {}
    for _, v in ipairs(vehicles) do
        if not categories[v.category] then
            categories[v.category] = true
        end
    end
    
    -- Ouvrir le NUI
    SetNuiFocus(true, true)
    nuiOpen = true
    SendNUIMessage({
        action = 'open',
        vehicles = vehicles,
        categories = categories,
        isAdmin = isAdmin or false,
        playerJob = playerJob
    })
    
    -- Créer la caméra
    if staticCam then
        DestroyCam(staticCam, false)
        RenderScriptCams(false, false, 0, true, true)
        staticCam = nil
    end
    
    staticCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camCoords, camRot = GetCameraCoords(currentVehicleType, currentIsJobOnly)
    SetCamCoord(staticCam, camCoords.x, camCoords.y, camCoords.z)
    SetCamRot(staticCam, camRot.x, camRot.y, camRot.z, 2)
    SetCamActive(staticCam, true)
    RenderScriptCams(true, false, 0, true, true)
end)

-- Spawn du véhicule acheté
RegisterNetEvent('vcore_concess:spawnVehicle')
AddEventHandler('vcore_concess:spawnVehicle', function(model, plate, livery, primaryColor, secondaryColor)
    -- Supprimer le preview
    if previewVeh and DoesEntityExist(previewVeh) then
        DeleteEntity(previewVeh)
        previewVeh = nil
    end
    
    local playerPed = PlayerPedId()
    local vehHash = GetHashKey(model)
    RequestModel(vehHash)
    while not HasModelLoaded(vehHash) do Wait(10) end
    
    -- Trouver les coordonnées de spawn
    local spawnCoords, heading
    for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
        if dealership.vehicleType == currentVehicleType and not dealership.isJobOnly then
            spawnCoords = dealership.vehicleSpawn.coords
            heading = dealership.vehicleSpawn.heading
            break
        end
    end
    
    if not spawnCoords and ConcessConfig.Dealerships['cars_civilian'] then
        spawnCoords = ConcessConfig.Dealerships['cars_civilian'].vehicleSpawn.coords
        heading = ConcessConfig.Dealerships['cars_civilian'].vehicleSpawn.heading
    end
    
    -- Ajuster la hauteur pour hélicos/avions
    local finalSpawnZ = spawnCoords.z
    local vehicleClass = GetVehicleClassFromName(vehHash)
    
    if vehicleClass == 15 or vehicleClass == 16 then
        local groundFound, groundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z, false)
        if groundFound then
            finalSpawnZ = groundZ + 2.0
        else
            finalSpawnZ = spawnCoords.z - 5.0
        end
    end
    
    local veh = CreateVehicle(vehHash, spawnCoords.x, spawnCoords.y, finalSpawnZ, heading, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetEntityAsMissionEntity(veh, true, true)
    
    -- Protéger contre le despawn
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId ~= 0 then
        TriggerServerEvent('vcore_concess:protectVehicle', netId)
    end
    
    -- Gestion spéciale hélicos/avions
    if vehicleClass == 15 or vehicleClass == 16 then
        SetEntityInvincible(veh, true)
        SetVehicleEngineOn(veh, true, true, false)
        
        if vehicleClass == 15 then
            SetVehicleOnGroundProperly(veh)
        end
        
        SetTimeout(3000, function()
            if DoesEntityExist(veh) then
                SetEntityInvincible(veh, false)
            end
        end)
    end
    
    SetVehicleExtraColours(veh, 0, 0)
    
    if primaryColor and secondaryColor then
        SetVehicleColours(veh, tonumber(primaryColor) or 0, tonumber(secondaryColor) or 0)
    end
    
    if livery and tonumber(livery) >= 0 then
        SetVehicleLivery(veh, tonumber(livery))
    end
    
    TaskWarpPedIntoVehicle(playerPed, veh, -1)
    
    -- Enregistrer dans vAvA_persist si disponible
    if ConcessConfig.Persistence.Enabled then
        SetTimeout(2000, function()
            if DoesEntityExist(veh) then
                local coords = GetEntityCoords(veh)
                local heading = GetEntityHeading(veh)
                local netId = NetworkGetNetworkIdFromEntity(veh)
                TriggerServerEvent('vava_persist:registerVehicle', plate, netId)
                TriggerServerEvent('vava_persist:updateVehicle', plate, coords, heading)
            end
        end)
    end
end)

-- Mise à jour du cache de véhicules
RegisterNetEvent('vcore_concess:updateVehicleCache')
AddEventHandler('vcore_concess:updateVehicleCache', function(newVehiclesList)
    vehicles = newVehiclesList
    
    if nuiOpen then
        cleanupPreviewOnExit()
        currentDealershipPosition = nil
        SetNuiFocus(false, false)
        nuiOpen = false
        SendNUIMessage({ action = 'close' })
    end
end)

-- Véhicules admin
RegisterNetEvent('vcore_concess:receiveVehiclesAdmin')
AddEventHandler('vcore_concess:receiveVehiclesAdmin', function(vehiclesList)
    SendNUIMessage({
        action = 'updateAdminVehicles',
        vehicles = vehiclesList
    })
end)

-- Panel admin
RegisterNetEvent('vcore_concess:openAdminPanel')
AddEventHandler('vcore_concess:openAdminPanel', function()
    SendNUIMessage({ action = 'openAdmin' })
    SetNuiFocus(true, true)
end)

-- ================================
-- THREADS
-- ================================

-- Thread de surveillance caméra
Citizen.CreateThread(function()
    while true do
        Wait(5000)
        
        if not nuiOpen and staticCam and DoesEntityExist(staticCam) then
            ForceResetCamera()
        end
    end
end)

-- Thread de surveillance de distance
Citizen.CreateThread(function()
    while true do
        local waitTime = distanceCheckActive and 500 or 2000
        
        if distanceCheckActive and previewVeh and DoesEntityExist(previewVeh) and currentDealershipPosition then
            local plyPed = PlayerPedId()
            local plyCoords = GetEntityCoords(plyPed)
            local dist = #(plyCoords - currentDealershipPosition)
            
            if dist > 10.0 then
                cleanupPreviewOnExit()
                currentDealershipPosition = nil
                distanceCheckActive = false
                
                if nuiOpen then
                    SetNuiFocus(false, false)
                    nuiOpen = false
                    SendNUIMessage({ action = 'close' })
                end
            end
            Wait(2000)
        else
            Wait(5000)
        end
    end
end)

-- Thread principal: blips et interaction
Citizen.CreateThread(function()
    while not ConcessConfig or not ConcessConfig.Dealerships do
        Wait(100)
    end
    
    -- Créer les blips
    for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
        if dealership.blip.enabled then
            local blip = AddBlipForCoord(dealership.position.x, dealership.position.y, dealership.position.z)
            SetBlipSprite(blip, dealership.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, dealership.blip.scale)
            SetBlipColour(blip, dealership.blip.color)
            SetBlipAsShortRange(blip, dealership.blip.shortRange)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(dealership.blip.name)
            EndTextCommandSetBlipName(blip)
            
            dealershipBlips[dealershipId] = blip
        end
    end
    
    -- Boucle d'interaction
    while true do
        Wait(0)
        local plyPed = PlayerPedId()
        local plyCoords = GetEntityCoords(plyPed)
        local nearDealership = false
        
        for dealershipId, dealership in pairs(ConcessConfig.Dealerships) do
            local dist = #(plyCoords - dealership.position)
            
            if dist <= ConcessConfig.General.InteractionDistance then
                nearDealership = true
                
                -- Dessiner le marqueur
                DrawMarker(
                    dealership.marker.type,
                    dealership.position.x, dealership.position.y, dealership.position.z - 1.0,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    dealership.marker.scale.x, dealership.marker.scale.y, dealership.marker.scale.z,
                    dealership.marker.color.r, dealership.marker.color.g, dealership.marker.color.b, dealership.marker.color.a,
                    dealership.marker.bobUpAndDown,
                    dealership.marker.faceCamera,
                    2,
                    dealership.marker.rotate,
                    nil, nil, false
                )
                
                -- Texte d'aide
                SetTextComponentFormat('STRING')
                AddTextComponentString(dealership.helpText)
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                
                -- Interaction avec E
                if IsControlJustReleased(0, ConcessConfig.General.InteractionKey) and not nuiOpen then
                    print('[vCore:Concess] Touche E détectée près de: ' .. dealershipId)
                    local currentTime = GetGameTimer()
                    if currentTime - lastCloseTime >= ConcessConfig.General.ReopenDelay then
                        print('[vCore:Concess] Envoi requête véhicules - isJobOnly:', dealership.isJobOnly, 'vehicleType:', dealership.vehicleType)
                        lastConcessPosition = dealership.position
                        currentIsJobOnly = dealership.isJobOnly
                        currentVehicleType = dealership.vehicleType
                        currentDealershipPosition = dealership.position
                        TriggerServerEvent('vcore_concess:requestVehicles', dealership.isJobOnly, dealership.vehicleType)
                        
                        local veh = GetVehiclePedIsIn(plyPed, false)
                        if veh ~= 0 then
                            SetEntityAsMissionEntity(veh, true, true)
                            DeleteVehicle(veh)
                        end
                    end
                end
                
                break
            end
        end
        
        if not nearDealership then
            Wait(500)
        end
    end
end)

-- Thread pour Escape
Citizen.CreateThread(function()
    while true do
        Wait(0)
        if nuiOpen then
            if IsControlJustReleased(0, 177) then -- Escape
                cleanupPreviewOnExit()
                currentDealershipPosition = nil
                SetNuiFocus(false, false)
                nuiOpen = false
                SendNUIMessage({ action = 'close' })
            end
            Wait(500)
        end
    end
end)

print('^2[vCore:Concess] Client initialisé^0')
