--[[
    vAvA Core - Module Jobs
    Client - Main
]]

local vCore = nil
local PlayerData = {}
local CurrentJob = nil
local JobConfig = nil
local Interactions = {}
local NearbyInteractions = {}
local IsNUIOpen = false

-- Initialisation
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
        CurrentJob = PlayerData.job
    end
    
    TriggerServerEvent('vCore:jobs:requestData')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS FRAMEWORK
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:Client:OnPlayerLoaded', function()
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
        CurrentJob = PlayerData.job
    end
    Wait(2000)
    TriggerServerEvent('vCore:jobs:requestData')
end)

RegisterNetEvent('vCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
    CurrentJob = JobInfo
    TriggerServerEvent('vCore:jobs:requestData')
end)

RegisterNetEvent('vCore:jobs:updateJob', function(jobData)
    CurrentJob = jobData
    TriggerServerEvent('vCore:jobs:requestData')
end)

RegisterNetEvent('vCore:jobs:updateDuty', function(onDuty)
    if CurrentJob then
        CurrentJob.onduty = onDuty
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SYNCHRONISATION
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:jobs:receiveData', function(data)
    CurrentJob = data.job
    JobConfig = data.jobConfig
    Interactions = data.interactions or {}
    
    if JobsConfig.Debug then
        print(('[vCore:Jobs] Données reçues pour le job: %s'):format(CurrentJob.name))
        print(('[vCore:Jobs] %d interactions chargées'):format(#Interactions))
    end
end)

RegisterNetEvent('vCore:jobs:syncInteractions', function(interactions)
    if CurrentJob and interactions[CurrentJob.name] then
        Interactions = interactions[CurrentJob.name]
    end
end)

RegisterNetEvent('vCore:jobs:syncJobs', function(jobs)
    if CurrentJob and jobs[CurrentJob.name] then
        JobConfig = jobs[CurrentJob.name]
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- BOUCLES PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Thread principal pour détecter les interactions proches
CreateThread(function()
    while true do
        local sleep = 1000
        
        if CurrentJob and Interactions and #Interactions > 0 then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            NearbyInteractions = {}
            
            for _, interaction in ipairs(Interactions) do
                if interaction.enabled then
                    local pos = vector3(interaction.position.x, interaction.position.y, interaction.position.z)
                    local distance = #(coords - pos)
                    
                    if distance <= JobsConfig.InteractionDistance then
                        table.insert(NearbyInteractions, {
                            interaction = interaction,
                            distance = distance
                        })
                        sleep = 0
                    end
                end
            end
            
            -- Trier par distance
            table.sort(NearbyInteractions, function(a, b)
                return a.distance < b.distance
            end)
        end
        
        Wait(sleep)
    end
end)

---Thread pour afficher les markers
CreateThread(function()
    while true do
        local sleep = 1000
        
        if CurrentJob and Interactions and #Interactions > 0 then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            
            for _, interaction in ipairs(Interactions) do
                if interaction.enabled then
                    local pos = vector3(interaction.position.x, interaction.position.y, interaction.position.z)
                    local distance = #(coords - pos)
                    
                    if distance <= 50.0 then
                        sleep = 0
                        
                        -- Récupérer le marker approprié
                        local marker = interaction.marker
                        if not marker or not marker.type then
                            marker = JobsConfig.DefaultMarkers[interaction.type] or JobsConfig.DefaultMarkers.custom
                        end
                        
                        if marker and marker.type then
                            DrawMarker(
                                marker.type,
                                pos.x, pos.y, pos.z,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                marker.size.x, marker.size.y, marker.size.z,
                                marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                                marker.bobUpAndDown or false,
                                false,
                                2,
                                marker.rotate or false,
                                nil, nil, false
                            )
                        end
                        
                        -- Texte d'aide si très proche
                        if distance <= JobsConfig.InteractionDistance then
                            local label = interaction.label or interaction.name
                            DrawText3D(pos.x, pos.y, pos.z + 1.0, '[~g~E~w~] ' .. label)
                        end
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

---Thread pour gérer les inputs
CreateThread(function()
    while true do
        local sleep = 500
        
        if #NearbyInteractions > 0 then
            sleep = 0
            
            if IsControlJustReleased(0, 38) then -- E
                local nearest = NearbyInteractions[1]
                if nearest then
                    HandleInteraction(nearest.interaction)
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Gère une interaction
---@param interaction table
function HandleInteraction(interaction)
    -- Vérifier le grade minimum
    if CurrentJob.grade < interaction.min_grade then
        Notify(JobsConfig.Notifications.grade_required, 'error')
        return
    end
    
    -- Vérifier si en service pour certains types
    local requiresDuty = {'vehicle', 'farm', 'craft', 'process', 'sell'}
    if TableContains(requiresDuty, interaction.type) then
        if not CurrentJob.onduty then
            Notify(JobsConfig.Notifications.not_on_duty, 'error')
            return
        end
    end
    
    -- Traiter selon le type
    if interaction.type == 'duty' then
        TriggerServerEvent('vCore:jobs:toggleDuty')
        
    elseif interaction.type == 'wardrobe' then
        OpenWardrobeMenu(interaction)
        
    elseif interaction.type == 'vehicle' then
        OpenVehicleMenu(interaction)
        
    elseif interaction.type == 'storage' then
        OpenStorage(interaction)
        
    elseif interaction.type == 'boss' then
        OpenBossMenu(interaction)
        
    elseif interaction.type == 'shop' then
        OpenShopMenu(interaction)
        
    elseif interaction.type == 'farm' then
        StartFarmAction(interaction)
        
    elseif interaction.type == 'craft' then
        OpenCraftMenu(interaction)
        
    elseif interaction.type == 'process' then
        StartProcessAction(interaction)
        
    elseif interaction.type == 'sell' then
        OpenSellMenu(interaction)
        
    elseif interaction.type == 'custom' then
        -- Event custom
        TriggerEvent('vCore:jobs:customInteraction', interaction)
    end
end

---Affiche du texte en 3D
---@param x number
---@param y number
---@param z number
---@param text string
function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

---Vérifie si une table contient une valeur
---@param table table
---@param element any
---@return boolean
function TableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

---Notification
---@param message string
---@param type string
function Notify(message, type)
    local success, _ = pcall(function()
        exports.ox_lib:notify({description = message, type = type or 'inform'})
    end)
    
    if not success then
        if vCore and vCore.Notify then
            vCore.Notify(message, type or 'info')
        else
            SetNotificationTextEntry('STRING')
            AddTextComponentString(message)
            DrawNotification(false, true)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetCurrentJob', function()
    return CurrentJob
end)

exports('GetJobConfig', function()
    return JobConfig
end)

exports('GetInteractions', function()
    return Interactions
end)

exports('IsOnDuty', function()
    return CurrentJob and CurrentJob.onduty or false
end)
