-- ============================================
-- vAvA Target - Client Main
-- Système de détection et raycast
-- ============================================

local currentTarget = nil
local currentEntity = nil
local currentOptions = {}
local isTargetActive = false
local isMenuOpen = false
local lastUpdate = 0
local cache = {}
local isAltPressed = false

print('[vAvA Target] Module loading...')

-- ============================================
-- DÉTECTION ET RAYCAST
-- ============================================

-- Fonction pour faire un raycast depuis la caméra
function DoRaycast(distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local cameraRotation = GetGameplayCamRot(2)
    local cameraCoords = GetGameplayCamCoord()
    
    -- Calculer direction du raycast
    local direction = RotationToDirection(cameraRotation)
    local destination = vector3(
        cameraCoords.x + direction.x * distance,
        cameraCoords.y + direction.y * distance,
        cameraCoords.z + direction.z * distance
    )
    
    -- Exécuter le raycast
    local rayHandle = StartShapeTestRay(
        cameraCoords.x, cameraCoords.y, cameraCoords.z,
        destination.x, destination.y, destination.z,
        TargetConfig.RaycastFlags,
        playerPed,
        0
    )
    
    local _, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(rayHandle)
    
    return hit == 1, entity, endCoords, surfaceNormal
end

-- Convertir rotation en direction
function RotationToDirection(rotation)
    local adjustedRotation = vector3(
        (math.pi / 180) * rotation.x,
        (math.pi / 180) * rotation.y,
        (math.pi / 180) * rotation.z
    )
    
    local direction = vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
    
    return direction
end

-- Obtenir distance maximale selon type d'entité
function GetMaxDistance(entity)
    if not DoesEntityExist(entity) then
        return TargetConfig.DefaultDistance
    end
    
    local entityType = GetEntityType(entity)
    
    if entityType == 2 then -- Véhicule
        return TargetConfig.VehicleDistance
    elseif entityType == 3 then -- Objet
        return TargetConfig.DefaultDistance
    elseif entityType == 1 then -- Ped
        return TargetConfig.DefaultDistance
    end
    
    return TargetConfig.DefaultDistance
end

-- Vérifier si entité est blacklistée
function IsEntityBlacklisted(entity)
    if not DoesEntityExist(entity) then
        return true
    end
    
    local model = GetEntityModel(entity)
    
    -- Vérifier modèles blacklistés
    for _, blacklistedModel in ipairs(TargetConfig.Blacklist.models) do
        if model == blacklistedModel then
            return true
        end
    end
    
    -- Vérifier entités blacklistées
    for _, blacklistedEntity in ipairs(TargetConfig.Blacklist.entities) do
        if entity == blacklistedEntity then
            return true
        end
    end
    
    return false
end

-- Obtenir les options pour une entité
function GetOptionsForEntity(entity)
    if not DoesEntityExist(entity) then
        return {}
    end
    
    local options = {}
    local model = GetEntityModel(entity)
    local entityType = GetEntityType(entity)
    
    -- Vérifier targets d'entité spécifique
    if registeredEntities[entity] then
        for _, option in ipairs(registeredEntities[entity]) do
            table.insert(options, option)
        end
    end
    
    -- Vérifier targets de modèle
    if registeredModels[model] then
        for _, option in ipairs(registeredModels[model]) do
            table.insert(options, option)
        end
    end
    
    -- Vérifier targets de bone (véhicules uniquement)
    if entityType == 2 and registeredBones then
        local boneOptions = GetBoneOptions(entity)
        for _, option in ipairs(boneOptions) do
            table.insert(options, option)
        end
    end
    
    return options
end

-- Obtenir les options pour un bone
function GetBoneOptions(vehicle)
    local options = {}
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    if not TargetConfig.Bones.vehicle then
        return options
    end
    
    for _, boneGroup in ipairs(TargetConfig.Bones.vehicle) do
        for _, boneName in ipairs(boneGroup.bones) do
            local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
            
            if boneIndex ~= -1 then
                local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
                local distance = #(playerCoords - boneCoords)
                
                if distance <= (boneGroup.distance or TargetConfig.DefaultDistance) then
                    for _, option in ipairs(boneGroup.options) do
                        local optionCopy = table.clone(option)
                        optionCopy.bone = boneName
                        table.insert(options, optionCopy)
                    end
                    break -- Un seul bone du groupe suffit
                end
            end
        end
    end
    
    return options
end

-- Vérifier les zones
function CheckZones(playerCoords)
    for _, zone in ipairs(registeredZones) do
        if IsPlayerInZone(playerCoords, zone) then
            return zone, zone.options
        end
    end
    
    return nil, {}
end

-- Vérifier si joueur est dans une zone
function IsPlayerInZone(playerCoords, zone)
    if zone.type == 'sphere' then
        local distance = #(playerCoords - zone.coords)
        return distance <= zone.radius
        
    elseif zone.type == 'box' then
        return IsPointInBox(playerCoords, zone.coords, zone.size, zone.heading or 0.0)
        
    elseif zone.type == 'cylinder' then
        local distance2D = #(vector2(playerCoords.x, playerCoords.y) - vector2(zone.coords.x, zone.coords.y))
        local heightDiff = math.abs(playerCoords.z - zone.coords.z)
        return distance2D <= zone.radius and heightDiff <= (zone.height / 2)
        
    elseif zone.type == 'poly' and zone.points then
        return IsPointInPoly(playerCoords, zone.points, zone.minZ, zone.maxZ)
    end
    
    return false
end

-- Vérifier si un point est dans une box
function IsPointInBox(point, center, size, heading)
    local rad = math.rad(heading)
    local cos = math.cos(rad)
    local sin = math.sin(rad)
    
    -- Rotation inverse
    local dx = point.x - center.x
    local dy = point.y - center.y
    
    local rotX = dx * cos + dy * sin
    local rotY = -dx * sin + dy * cos
    
    -- Vérification dans les limites
    local halfX = size.x / 2
    local halfY = size.y / 2
    local halfZ = size.z / 2
    
    return math.abs(rotX) <= halfX and
           math.abs(rotY) <= halfY and
           math.abs(point.z - center.z) <= halfZ
end

-- Vérifier si un point est dans un polygone (simplifié)
function IsPointInPoly(point, points, minZ, maxZ)
    if point.z < minZ or point.z > maxZ then
        return false
    end
    
    local inside = false
    local j = #points
    
    for i = 1, #points do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y
        
        if ((yi > point.y) ~= (yj > point.y)) and
           (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        
        j = i
    end
    
    return inside
end

-- Filtrer les options selon les conditions
function FilterOptions(options, entity, distance)
    local validOptions = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local isPlayerInVehicle = IsPedInAnyVehicle(playerPed, false)
    
    for _, option in ipairs(options) do
        local isValid = true
        
        -- Vérifier distance
        if option.distance and distance > option.distance then
            isValid = false
        end
        
        -- Vérifier véhicule
        if option.inVehicle and not isPlayerInVehicle then
            isValid = false
        elseif option.outVehicle and isPlayerInVehicle then
            isValid = false
        end
        
        -- Vérifier canInteract callback
        if option.canInteract and type(option.canInteract) == 'function' then
            local isPlayer = entity and IsEntityAPed(entity) and IsPedAPlayer(entity)
            if not option.canInteract(entity, distance, playerCoords, isPlayer) then
                isValid = false
            end
        end
        
        -- Vérifier job (client-side, validation serveur aussi)
        if option.job then
            -- Cette vérification sera faite côté serveur
            -- On l'affiche quand même pour l'UX
        end
        
        if isValid then
            table.insert(validOptions, option)
        end
    end
    
    return validOptions
end

-- ============================================
-- BOUCLE PRINCIPALE DE DÉTECTION (MODE ALT)
-- ============================================

Citizen.CreateThread(function()
    while true do
        local sleepTime = 500
        
        if not isTargetActive then
            Citizen.Wait(sleepTime)
            goto continue
        end
        
        -- Vérifier si ALT est pressé
        local activationKey = TargetConfig.ActivationKey or 19  -- 19 = ALT par défaut
        local isKeyPressed = IsControlPressed(0, activationKey)
        
        if TargetConfig.UseKeyActivation and not isKeyPressed then
            -- ALT non pressé, fermer le menu si ouvert
            if isMenuOpen then
                CloseTargetMenu()
            end
            
            if currentEntity or currentTarget then
                currentEntity = nil
                currentTarget = nil
                currentOptions = {}
                TriggerEvent('vava_target:onTargetExit')
            end
            
            Citizen.Wait(sleepTime)
            goto continue
        end
        
        -- ALT pressé, détecter les cibles
        sleepTime = TargetConfig.UpdateRate
        
        local now = GetGameTimer()
        
        -- Throttling
        if now - lastUpdate < TargetConfig.UpdateRate then
            Citizen.Wait(10)
            goto continue
        end
        
        lastUpdate = now
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        -- 1. Vérifier raycast (entités)
        local hit, entity, endCoords, surfaceNormal = DoRaycast(TargetConfig.MaxDistance)
        
        if hit and DoesEntityExist(entity) and not IsEntityBlacklisted(entity) then
            local distance = #(playerCoords - endCoords)
            local maxDistance = GetMaxDistance(entity)
            
            if distance <= maxDistance then
                local options = GetOptionsForEntity(entity)
                local validOptions = FilterOptions(options, entity, distance)
                
                if #validOptions > 0 then
                    -- Nouvelle cible détectée
                    if currentEntity ~= entity then
                        currentEntity = entity
                        currentOptions = validOptions
                        TriggerEvent('vava_target:onTargetEnter', entity, validOptions)
                        
                        if not isMenuOpen then
                            ShowTargetMenu(entity, validOptions, distance)
                        end
                    end
                    
                    goto continue
                end
            end
        end
        
        -- 2. Vérifier zones
        local zone, zoneOptions = CheckZones(playerCoords)
        
        if zone and #zoneOptions > 0 then
            local validOptions = FilterOptions(zoneOptions, nil, 0)
            
            if #validOptions > 0 then
                -- Zone détectée
                if currentTarget ~= zone.name then
                    currentTarget = zone.name
                    currentEntity = nil
                    currentOptions = validOptions
                    TriggerEvent('vava_target:onTargetEnter', nil, validOptions)
                    
                    if not isMenuOpen then
                        ShowTargetMenu(nil, validOptions, 0)
                    end
                end
                
                goto continue
            end
        end
        
        -- 3. Aucune cible
        if currentEntity or currentTarget then
            currentEntity = nil
            currentTarget = nil
            currentOptions = {}
            
            if isMenuOpen then
                CloseTargetMenu()
            end
            
            TriggerEvent('vava_target:onTargetExit')
        end
        
        ::continue::
        Citizen.Wait(sleepTime)
    end
end)

-- ============================================
-- AFFICHAGE MENU NUI
-- ============================================

function ShowTargetMenu(entity, options, distance)
    if #options == 0 then
        return
    end
    
    -- Limiter le nombre d'options
    if #options > TargetConfig.UI.MaxOptions then
        local limitedOptions = {}
        for i = 1, TargetConfig.UI.MaxOptions do
            table.insert(limitedOptions, options[i])
        end
        options = limitedOptions
    end
    
    isMenuOpen = true
    
    -- Activer le focus NUI pour pouvoir cliquer
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    
    SendNUIMessage({
        action = 'open',
        menuType = TargetConfig.UI.MenuType,
        position = TargetConfig.UI.Position,
        options = options,
        distance = distance,
        showDistance = TargetConfig.UI.ShowDistance,
        showIcon = TargetConfig.UI.ShowIcon,
        showKeybind = TargetConfig.UI.ShowKeybind,
        animationDuration = TargetConfig.UI.AnimationDuration
    })
end

function CloseTargetMenu()
    isMenuOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'close'
    })
end

-- ============================================
-- CALLBACKS NUI
-- ============================================

RegisterNUICallback('selectOption', function(data, cb)
    local option = data.option
    
    if not option then
        cb({success = false, error = 'No option provided'})
        return
    end
    
    -- Fermer le menu
    CloseTargetMenu()
    
    -- Déclencher l'action
    TriggerTargetOption(option, currentEntity)
    
    cb({success = true})
end)

RegisterNUICallback('close', function(data, cb)
    CloseTargetMenu()
    cb({success = true})
end)

-- Déclencher l'action d'une option
function TriggerTargetOption(option, entity)
    -- Event
    if option.event then
        if option.server then
            -- Validation serveur
            TriggerServerEvent('vava_target:validateInteraction', {
                event = option.event,
                entity = entity and NetworkGetNetworkIdFromEntity(entity) or nil,
                data = option.data
            })
        else
            -- Event client
            TriggerEvent(option.event, {
                entity = entity,
                data = option.data
            })
        end
    end
    
    -- Export
    if option.export and option.export.resource and option.export.func then
        local success, result = pcall(function()
            return exports[option.export.resource][option.export.func](entity, option.data)
        end)
        
        if not success then
            print('[vAvA Target] Export error:', result)
        end
    end
    
    -- Command
    if option.command then
        ExecuteCommand(option.command)
    end
    
    -- Action callback
    if option.action and type(option.action) == 'function' then
        option.action(entity, option.data)
    end
    
    -- Event système
    TriggerEvent('vava_target:onInteract', entity, option)
end

-- ============================================
-- AUTO-FERMETURE
-- ============================================

Citizen.CreateThread(function()
    local lastPosition = vector3(0, 0, 0)
    local menuOpenTime = 0
    
    while true do
        Citizen.Wait(100)
        
        if isMenuOpen then
            local playerPed = PlayerPedId()
            local currentPosition = GetEntityCoords(playerPed)
            
            -- Fermeture si mouvement
            if TargetConfig.UI.CloseOnMove then
                local moved = #(currentPosition - lastPosition) > 1.0
                if moved then
                    CloseTargetMenu()
                end
            end
            
            -- Fermeture si distance
            if TargetConfig.UI.CloseOnDistance and currentEntity then
                if DoesEntityExist(currentEntity) then
                    local distance = #(currentPosition - GetEntityCoords(currentEntity))
                    local maxDistance = GetMaxDistance(currentEntity)
                    
                    if distance > maxDistance * 1.5 then -- 50% de marge
                        CloseTargetMenu()
                    end
                else
                    CloseTargetMenu()
                end
            end
            
            -- Timeout
            if TargetConfig.UI.AutoClose then
                if GetGameTimer() - menuOpenTime > TargetConfig.UI.AutoCloseDelay then
                    CloseTargetMenu()
                end
            end
            
            lastPosition = currentPosition
        else
            menuOpenTime = GetGameTimer()
            lastPosition = GetEntityCoords(PlayerPedId())
        end
    end
end)

-- ============================================
-- EVENTS
-- ============================================

-- Activer/désactiver le système
RegisterNetEvent('vava_target:toggle')
AddEventHandler('vava_target:toggle', function(state)
    isTargetActive = state
    
    if not state and isMenuOpen then
        CloseTargetMenu()
    end
end)

-- Affichage du point central quand ALT est pressé
local debugCounter = 0

Citizen.CreateThread(function()
    print('[vAvA Target] Dot display thread started')
    Citizen.Wait(2000)  -- Attendre que tout soit chargé
    
    while true do
        Citizen.Wait(0)
        
        debugCounter = debugCounter + 1
        if debugCounter == 1 or debugCounter % 500 == 0 then
            print('[vAvA Target] Dot thread tick', debugCounter, 'Active:', isTargetActive)
        end
        
        if not isTargetActive then
            Citizen.Wait(500)
            goto continue
        end
        
        local activationKey = TargetConfig.ActivationKey or 19  -- 19 = ALT par défaut
        local keyPressed = IsControlPressed(0, activationKey)
        
        if keyPressed then
            if not isAltPressed then
                print('[vAvA Target] ALT KEY PRESSED!')
                print('[vAvA Target] TargetConfig.UI:', TargetConfig.UI)
                if TargetConfig.UI then
                    print('[vAvA Target] ShowDot:', TargetConfig.UI.ShowDot)
                    print('[vAvA Target] DotSize:', TargetConfig.UI.DotSize)
                    print('[vAvA Target] DotColor:', json.encode(TargetConfig.UI.DotColor))
                end
            end
            isAltPressed = true
            
            -- Afficher le point central
            if TargetConfig.UI and TargetConfig.UI.ShowDot then
                local color = TargetConfig.UI.DotColor or {255, 30, 30, 255}
                local size = (TargetConfig.UI.DotSize or 8) * 0.001
                
                -- Dessiner un point central (rectangle petit)
                DrawRect(0.5, 0.5, size, size * 1.5, color[1], color[2], color[3], color[4])
                
                -- Cercle autour pour meilleure visibilité
                local circleSize = size * 2.5
                DrawRect(0.5, 0.5, circleSize, circleSize * 0.05, color[1], color[2], color[3], 180)
                DrawRect(0.5, 0.5, circleSize * 0.05, circleSize, color[1], color[2], color[3], 180)
            end
        else
            if isAltPressed then
                print('[vAvA Target] ALT KEY RELEASED')
            end
            isAltPressed = false
            Citizen.Wait(50)
        end
        
        ::continue::
    end
end)

-- Désactiver les contrôles de tir quand le menu est ouvert
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isMenuOpen then
            -- Désactiver les contrôles de combat
            DisableControlAction(0, 24, true)  -- Attaque (clic gauche)
            DisableControlAction(0, 25, true)  -- Viser (clic droit)
            DisableControlAction(0, 47, true)  -- Dégainer arme
            DisableControlAction(0, 58, true)  -- Dégainer arme (touch G)
            DisableControlAction(0, 140, true) -- Corps à corps léger
            DisableControlAction(0, 141, true) -- Corps à corps lourd
            DisableControlAction(0, 142, true) -- Corps à corps alternatif
            DisableControlAction(0, 257, true) -- Attaque 2
            DisableControlAction(0, 263, true) -- Corps à corps
            DisableControlAction(0, 264, true) -- Corps à corps
            
            -- Désactiver les actions de véhicule
            DisableControlAction(0, 59, true)  -- Viser en véhicule
            DisableControlAction(0, 68, true)  -- Viser en véhicule (molette)
            DisableControlAction(0, 69, true)  -- Attaque en véhicule
            DisableControlAction(0, 70, true)  -- Attaque en véhicule 2
            
            -- Empêcher le joueur de courir ou sauter
            DisableControlAction(0, 21, true)  -- Sprint
            DisableControlAction(0, 22, true)  -- Saut
        else
            Citizen.Wait(200)
        end
    end
end)

-- Affichage helper texte ALT (optionnel)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        
        -- Désactivé car on a le point visuel maintenant
        -- Si vous voulez réactiver le texte, décommentez le code ci-dessous
        
        --[[
        if isTargetActive and TargetConfig.UseKeyActivation and not isMenuOpen then
            Citizen.Wait(0)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 180)
            SetTextDropshadow(0, 0, 0, 0, 255)
            SetTextEdge(1, 0, 0, 0, 255)
            SetTextDropShadow()
            SetTextOutline()
            SetTextCentre(1)
            SetTextEntry("STRING")
            AddTextComponentString("Maintenez ~INPUT_CONTEXT~ pour interagir")
            DrawText(0.5, 0.95)
        end
        --]]
    end
end)

-- Initialisation
Citizen.CreateThread(function()
    print('[vAvA Target] Initialisation thread started')
    Citizen.Wait(1000)
    isTargetActive = TargetConfig.Enabled
    print('[vAvA Target] System initialized - Active:', isTargetActive)
    print('[vAvA Target] Config.Enabled:', TargetConfig.Enabled)
    print('[vAvA Target] Config.UseKeyActivation:', TargetConfig.UseKeyActivation)
    print('[vAvA Target] Config.ActivationKey:', TargetConfig.ActivationKey)
    if TargetConfig.UI then
        print('[vAvA Target] Config.UI.ShowDot:', TargetConfig.UI.ShowDot)
        print('[vAvA Target] Config.UI.DotSize:', TargetConfig.UI.DotSize)
    else
        print('[vAvA Target] WARNING: TargetConfig.UI is nil!')
    end
end)

-- ============================================
-- UTILITAIRES
-- ============================================

-- Clone de table (shallow)
function table.clone(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

-- ============================================
-- COMMANDES DEBUG
-- ============================================

RegisterCommand('targetdebug', function()
    print('=================================')
    print('[vAvA Target] DEBUG INFO')
    print('=================================')
    print('isTargetActive:', isTargetActive)
    print('isMenuOpen:', isMenuOpen)
    print('isAltPressed:', isAltPressed)
    print('TargetConfig.Enabled:', TargetConfig.Enabled)
    print('TargetConfig.ActivationKey:', TargetConfig.ActivationKey)
    print('TargetConfig.UseKeyActivation:', TargetConfig.UseKeyActivation)
    
    if TargetConfig.UI then
        print('TargetConfig.UI.ShowDot:', TargetConfig.UI.ShowDot)
        print('TargetConfig.UI.DotSize:', TargetConfig.UI.DotSize)
        print('TargetConfig.UI.DotColor:', json.encode(TargetConfig.UI.DotColor))
        print('TargetConfig.UI.MenuType:', TargetConfig.UI.MenuType)
    else
        print('TargetConfig.UI: nil (ERROR!)')
    end
    
    print('Key 19 (ALT) pressed:', IsControlPressed(0, 19))
    print('Key 21 (SHIFT) pressed:', IsControlPressed(0, 21))
    print('=================================')
    
    TriggerEvent('chat:addMessage', {
        color = {255, 30, 30},
        multiline = true,
        args = {"vAvA Target", "Debug info printed in F8 console"}
    })
end, false)

RegisterCommand('targettoggle', function()
    isTargetActive = not isTargetActive
    print('[vAvA Target] System toggled:', isTargetActive)
    
    TriggerEvent('chat:addMessage', {
        color = {255, 30, 30},
        multiline = true,
        args = {"vAvA Target", string.format("System %s", isTargetActive and "ENABLED" or "DISABLED")}
    })
end, false)

RegisterCommand('targettest', function()
    print('[vAvA Target] Testing dot display for 5 seconds...')
    
    local startTime = GetGameTimer()
    
    Citizen.CreateThread(function()
        while GetGameTimer() - startTime < 5000 do
            Citizen.Wait(0)
            
            -- Force affichage du point
            local color = {255, 30, 30, 255}
            local size = 0.008
            
            DrawRect(0.5, 0.5, size, size * 1.5, color[1], color[2], color[3], color[4])
            
            -- Croix
            local circleSize = size * 2.5
            DrawRect(0.5, 0.5, circleSize, circleSize * 0.05, color[1], color[2], color[3], 180)
            DrawRect(0.5, 0.5, circleSize * 0.05, circleSize, color[1], color[2], color[3], 180)
        end
        
        print('[vAvA Target] Test complete')
        TriggerEvent('chat:addMessage', {
            color = {255, 30, 30},
            args = {"vAvA Target", "Test dot display complete"}
        })
    end)
    
    TriggerEvent('chat:addMessage', {
        color = {255, 30, 30},
        args = {"vAvA Target", "Testing dot display..."}
    })
end, false)
