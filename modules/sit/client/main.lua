--[[
    vAvA Core - Module Sit
    Client-side
]]

local vCore = nil
local PlayerData = {}
local sitPoints = {}
local isAdmin = false
local isEditMode = false
local isSitting = false
local currentSitPointId = nil
local currentAnimIndex = 1

-- Variables mode édition
local ghostPed = nil
local editCamera = nil
local currentGhostPos = vector3(0.0, 0.0, 0.0)
local currentGhostHeading = 0.0
local editingPointId = nil

-- Initialisation du framework
CreateThread(function()
    TriggerEvent('vCore:getSharedObject', function(obj) vCore = obj end)
    
    if not vCore then
        local success, result = pcall(function()
            return exports['vAvA_core']:GetCoreObject()
        end)
        if success then
            vCore = result
        end
    end
    
    Wait(2000)
    
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
    end
    
    TriggerServerEvent('vCore:sit:getSitPoints')
    TriggerServerEvent('vCore:sit:checkAdmin')
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

local function Notify(message, type)
    if GetResourceState('ox_lib') == 'started' then
        exports.ox_lib:notify({
            title = 'Assise',
            description = message,
            type = type or 'info'
        })
    else
        TriggerEvent('vCore:notification', message, type)
    end
end

local function tableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- ================================
-- EVENTS SYNCHRONISATION
-- ================================

RegisterNetEvent('vCore:sit:updatePoints', function(points)
    sitPoints = points
    RefreshTargets()
end)

RegisterNetEvent('vCore:sit:setAdminStatus', function(status)
    isAdmin = status
end)

RegisterNetEvent('vCore:Client:OnPlayerLoaded', function()
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
    end
    Wait(2000)
    TriggerServerEvent('vCore:sit:getSitPoints')
    TriggerServerEvent('vCore:sit:checkAdmin')
end)

-- ================================
-- SYSTÈME DE TARGET
-- ================================

function RefreshTargets()
    -- Supprimer les anciens targets
    if GetResourceState('ox_target') == 'started' then
        for id, _ in pairs(sitPoints) do
            exports.ox_target:removeZone('sit_point_' .. id)
        end
        
        -- Créer les nouveaux targets
        for id, point in pairs(sitPoints) do
            exports.ox_target:addSphereZone({
                name = 'sit_point_' .. id,
                coords = vector3(point.coords.x, point.coords.y, point.coords.z),
                radius = SitConfig.InteractionDistance,
                options = {
                    {
                        name = 'sit_' .. id,
                        icon = 'fas fa-chair',
                        label = 'S\'asseoir',
                        onSelect = function()
                            OpenAnimationMenu(id)
                        end
                    }
                }
            })
        end
    end
end

-- ================================
-- MENU ANIMATIONS
-- ================================

function OpenAnimationMenu(pointId)
    if isSitting then
        Notify(SitConfig.Messages.already_sitting, 'error')
        return
    end
    
    if GetResourceState('ox_lib') == 'started' then
        local options = {}
        
        for i, animData in ipairs(SitConfig.Animations) do
            table.insert(options, {
                title = animData.name,
                description = animData.description,
                icon = 'chair',
                onSelect = function()
                    SitDown(pointId, i)
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'sit_animation_menu',
            title = 'Choisir une position',
            options = options
        })
        
        exports.ox_lib:showContext('sit_animation_menu')
    else
        -- Fallback sans ox_lib
        SitDown(pointId, 1)
    end
end

-- ================================
-- SYSTÈME D'ASSISE
-- ================================

function SitDown(pointId, animIndex)
    local point = sitPoints[tostring(pointId)]
    if not point then return end
    
    TriggerServerEvent('vCore:sit:occupy', pointId)
    currentSitPointId = pointId
    currentAnimIndex = animIndex or 1
end

RegisterNetEvent('vCore:sit:confirmSit', function(pointId)
    local point = sitPoints[tostring(pointId)]
    if not point then return end
    
    local animData = SitConfig.Animations[currentAnimIndex] or SitConfig.Animations[1]
    local offset = animData.offset or vector3(0.0, 0.0, 0.0)
    
    local ped = PlayerPedId()
    
    -- Charger l'animation
    RequestAnimDict(animData.dict)
    while not HasAnimDictLoaded(animData.dict) do
        Wait(1)
    end
    
    -- Positionner le joueur
    local coords = vector3(point.coords.x + offset.x, point.coords.y + offset.y, point.coords.z + offset.z)
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, point.heading)
    
    Wait(100)
    
    -- Jouer l'animation
    TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, -8.0, -1, animData.flag, 0, false, false, false)
    
    isSitting = true
    
    -- Thread pour se lever
    CreateThread(function()
        while isSitting do
            Wait(0)
            
            -- Afficher l'instruction
            DrawText2D(0.5, 0.95, '[E] Se lever')
            
            if IsControlJustPressed(0, SitConfig.Controls.STAND_UP) then
                StandUp()
            end
        end
    end)
end)

function StandUp()
    if not isSitting then return end
    
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    
    TriggerServerEvent('vCore:sit:release', currentSitPointId)
    
    isSitting = false
    currentSitPointId = nil
end

RegisterNetEvent('vCore:sit:forceStandUp', function()
    StandUp()
end)

-- ================================
-- MODE ÉDITION
-- ================================

function CreateGhost()
    if ghostPed then DeleteEntity(ghostPed) end
    
    local playerPed = PlayerPedId()
    local playerModel = GetEntityModel(playerPed)
    local playerPos = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    ghostPed = CreatePed(4, playerModel, playerPos.x, playerPos.y, playerPos.z, playerHeading, false, false)
    
    SetEntityAlpha(ghostPed, SitConfig.GhostAlpha, false)
    SetEntityCollision(ghostPed, false, false)
    SetEntityInvincible(ghostPed, true)
    FreezeEntityPosition(ghostPed, true)
    
    ClonePedToTarget(playerPed, ghostPed)
    
    -- Appliquer une animation d'assise
    local animData = SitConfig.Animations[4] -- Position réfléchie
    RequestAnimDict(animData.dict)
    while not HasAnimDictLoaded(animData.dict) do
        Wait(1)
    end
    TaskPlayAnim(ghostPed, animData.dict, animData.anim, 8.0, -8.0, -1, animData.flag, 0, false, false, false)
    
    currentGhostPos = GetEntityCoords(ghostPed)
    currentGhostHeading = GetEntityHeading(ghostPed)
end

function CreateEditCamera()
    if editCamera then DestroyCam(editCamera, false) end
    
    local ghostPos = GetEntityCoords(ghostPed)
    local camPos = ghostPos + SitConfig.CameraOffset
    
    editCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(editCamera, camPos.x, camPos.y, camPos.z)
    PointCamAtEntity(editCamera, ghostPed, 0.0, 0.0, 0.0, true)
    SetCamFov(editCamera, SitConfig.CameraFov)
    SetCamActive(editCamera, true)
    RenderScriptCams(true, true, 1000, true, true)
end

function UpdateCamera()
    if editCamera and ghostPed then
        local ghostPos = GetEntityCoords(ghostPed)
        local camPos = ghostPos + SitConfig.CameraOffset
        SetCamCoord(editCamera, camPos.x, camPos.y, camPos.z)
        PointCamAtEntity(editCamera, ghostPed, 0.0, 0.0, 0.0, true)
    end
end

function EnterEditMode(pointId)
    if isEditMode then return end
    
    isEditMode = true
    editingPointId = pointId
    
    if pointId and sitPoints[tostring(pointId)] then
        local point = sitPoints[tostring(pointId)]
        currentGhostPos = vector3(point.coords.x, point.coords.y, point.coords.z)
        currentGhostHeading = point.heading
    end
    
    CreateGhost()
    
    if editingPointId then
        SetEntityCoords(ghostPed, currentGhostPos.x, currentGhostPos.y, currentGhostPos.z, false, false, false, false)
        SetEntityHeading(ghostPed, currentGhostHeading)
    end
    
    CreateEditCamera()
    
    Notify(SitConfig.Messages.edit_mode_enabled, 'info')
    
    CreateThread(function()
        while isEditMode do
            DisableAllControlActions(0)
            EnableControlAction(0, SitConfig.Controls.MOUSE_WHEEL_UP, true)
            EnableControlAction(0, SitConfig.Controls.MOUSE_WHEEL_DOWN, true)
            EnableControlAction(0, SitConfig.Controls.VALIDATE, true)
            EnableControlAction(0, SitConfig.Controls.CANCEL, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_FORWARD, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_BACKWARD, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_LEFT, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_RIGHT, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_UP, true)
            EnableControlAction(0, SitConfig.Controls.MOVE_DOWN, true)
            
            HandleEditControls()
            DrawEditInstructions()
            
            Wait(0)
        end
    end)
end

function HandleEditControls()
    local moveVector = vector3(0.0, 0.0, 0.0)
    local rotationChange = 0.0
    
    if IsControlPressed(0, SitConfig.Controls.MOVE_FORWARD) then
        moveVector = moveVector + vector3(0.0, SitConfig.MoveSpeed, 0.0)
    end
    if IsControlPressed(0, SitConfig.Controls.MOVE_BACKWARD) then
        moveVector = moveVector + vector3(0.0, -SitConfig.MoveSpeed, 0.0)
    end
    if IsControlPressed(0, SitConfig.Controls.MOVE_LEFT) then
        moveVector = moveVector + vector3(-SitConfig.MoveSpeed, 0.0, 0.0)
    end
    if IsControlPressed(0, SitConfig.Controls.MOVE_RIGHT) then
        moveVector = moveVector + vector3(SitConfig.MoveSpeed, 0.0, 0.0)
    end
    if IsControlPressed(0, SitConfig.Controls.MOVE_UP) then
        moveVector = moveVector + vector3(0.0, 0.0, SitConfig.HeightSpeed)
    end
    if IsControlPressed(0, SitConfig.Controls.MOVE_DOWN) then
        moveVector = moveVector + vector3(0.0, 0.0, -SitConfig.HeightSpeed)
    end
    
    if IsControlJustPressed(0, SitConfig.Controls.MOUSE_WHEEL_UP) then
        rotationChange = SitConfig.RotationSpeed
    end
    if IsControlJustPressed(0, SitConfig.Controls.MOUSE_WHEEL_DOWN) then
        rotationChange = -SitConfig.RotationSpeed
    end
    
    -- Appliquer les changements
    if moveVector.x ~= 0.0 or moveVector.y ~= 0.0 or moveVector.z ~= 0.0 then
        currentGhostPos = currentGhostPos + moveVector
        SetEntityCoordsNoOffset(ghostPed, currentGhostPos.x, currentGhostPos.y, currentGhostPos.z, false, false, false)
        UpdateCamera()
    end
    
    if rotationChange ~= 0.0 then
        currentGhostHeading = currentGhostHeading + rotationChange
        if currentGhostHeading >= 360.0 then currentGhostHeading = currentGhostHeading - 360.0 end
        if currentGhostHeading < 0.0 then currentGhostHeading = currentGhostHeading + 360.0 end
        SetEntityHeading(ghostPed, currentGhostHeading)
    end
    
    -- Valider
    if IsControlJustPressed(0, SitConfig.Controls.VALIDATE) then
        if editingPointId then
            TriggerServerEvent('vCore:sit:updatePoint', editingPointId, {
                coords = currentGhostPos,
                heading = currentGhostHeading
            })
        else
            TriggerServerEvent('vCore:sit:createPoint', {
                coords = currentGhostPos,
                heading = currentGhostHeading
            })
        end
    end
    
    -- Annuler
    if IsControlJustPressed(0, SitConfig.Controls.CANCEL) then
        ExitEditMode()
    end
end

function DrawEditInstructions()
    local instructions = {
        "~y~Mode Édition",
        "~w~ZQSD: Déplacer",
        "~w~Q/E: Hauteur",
        "~w~Molette: Rotation",
        "~g~ENTER~w~: Valider",
        "~r~RETOUR~w~: Quitter"
    }
    
    for i, text in ipairs(instructions) do
        DrawText2D(0.015, 0.28 + (i * 0.03), text, 0.35, true)
    end
end

function ExitEditMode()
    if not isEditMode then return end
    
    isEditMode = false
    editingPointId = nil
    
    if ghostPed then
        DeleteEntity(ghostPed)
        ghostPed = nil
    end
    
    if editCamera then
        RenderScriptCams(false, true, 1000, true, true)
        DestroyCam(editCamera, false)
        editCamera = nil
    end
    
    Notify(SitConfig.Messages.edit_mode_disabled, 'error')
end

-- ================================
-- MENU ADMIN
-- ================================

function OpenAdminMenu()
    if not isAdmin then
        Notify(SitConfig.Messages.no_permission, 'error')
        return
    end
    
    if GetResourceState('ox_lib') == 'started' then
        local options = {
            {
                title = 'Créer un point',
                description = 'Entrer en mode création',
                icon = 'plus',
                onSelect = function()
                    EnterEditMode(nil)
                end
            },
            {
                title = 'Lister les points',
                description = tableLength(sitPoints) .. ' point(s) enregistré(s)',
                icon = 'list',
                onSelect = function()
                    OpenPointsList()
                end
            }
        }
        
        if isEditMode then
            table.insert(options, 1, {
                title = 'Quitter mode édition',
                icon = 'times',
                onSelect = function()
                    ExitEditMode()
                end
            })
        end
        
        exports.ox_lib:registerContext({
            id = 'sit_admin_menu',
            title = '🪑 Gestion des Points d\'Assise',
            options = options
        })
        
        exports.ox_lib:showContext('sit_admin_menu')
    end
end

function OpenPointsList()
    if GetResourceState('ox_lib') ~= 'started' then return end
    
    local options = {}
    
    for id, point in pairs(sitPoints) do
        table.insert(options, {
            title = 'Point #' .. id,
            description = string.format('Position: %.1f, %.1f, %.1f', point.coords.x, point.coords.y, point.coords.z),
            icon = 'chair',
            menu = 'sit_point_actions_' .. id
        })
        
        exports.ox_lib:registerContext({
            id = 'sit_point_actions_' .. id,
            title = 'Point #' .. id,
            menu = 'sit_points_list',
            options = {
                {
                    title = 'Modifier',
                    icon = 'edit',
                    onSelect = function()
                        EnterEditMode(id)
                    end
                },
                {
                    title = 'Téléporter',
                    icon = 'map-marker',
                    onSelect = function()
                        SetEntityCoords(PlayerPedId(), point.coords.x, point.coords.y, point.coords.z, false, false, false, false)
                    end
                },
                {
                    title = 'Supprimer',
                    icon = 'trash',
                    onSelect = function()
                        TriggerServerEvent('vCore:sit:deletePoint', id)
                    end
                }
            }
        })
    end
    
    if #options == 0 then
        table.insert(options, {
            title = 'Aucun point',
            description = 'Créez votre premier point d\'assise',
            icon = 'info'
        })
    end
    
    exports.ox_lib:registerContext({
        id = 'sit_points_list',
        title = 'Points d\'Assise',
        menu = 'sit_admin_menu',
        options = options
    })
    
    exports.ox_lib:showContext('sit_points_list')
end

-- ================================
-- FONCTIONS D'AFFICHAGE
-- ================================

function DrawText2D(x, y, text, scale, left)
    scale = scale or 0.35
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.0, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    if not left then SetTextCentre(true) end
    AddTextComponentString(text)
    DrawText(x, y)
end

-- ================================
-- COMMANDES
-- ================================

RegisterCommand(SitConfig.Commands.admin, function()
    OpenAdminMenu()
end, false)

RegisterCommand(SitConfig.Commands.menu, function()
    -- Trouver le point le plus proche
    local playerPos = GetEntityCoords(PlayerPedId())
    local nearestId = nil
    local nearestDist = SitConfig.InteractionDistance
    
    for id, point in pairs(sitPoints) do
        local dist = #(playerPos - vector3(point.coords.x, point.coords.y, point.coords.z))
        if dist < nearestDist then
            nearestDist = dist
            nearestId = id
        end
    end
    
    if nearestId then
        OpenAnimationMenu(nearestId)
    else
        Notify('Aucun point d\'assise à proximité', 'error')
    end
end, false)

-- ================================
-- EXPORTS
-- ================================

exports('OpenSitMenu', OpenAdminMenu)
exports('ToggleEditMode', function()
    if isEditMode then
        ExitEditMode()
    else
        EnterEditMode(nil)
    end
end)
exports('SitDown', SitDown)
exports('StandUp', StandUp)
exports('GetSitPoints', function() return sitPoints end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        TriggerServerEvent('vCore:sit:getSitPoints')
        TriggerServerEvent('vCore:sit:checkAdmin')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isSitting then StandUp() end
        if isEditMode then ExitEditMode() end
    end
end)
