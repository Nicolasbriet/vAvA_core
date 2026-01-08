--[[
    vAvA Core - Module Sit
    Server-side
]]

local vCore = nil
local sitPoints = {}
local occupiedPoints = {}
local nextPointId = 1

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
    
    Wait(1000)
    LoadSitPoints()
end)

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

local function GetPlayer(source)
    if vCore and vCore.Functions and vCore.Functions.GetPlayer then
        return vCore.Functions.GetPlayer(source)
    end
    return nil
end

local function Notify(source, message, type)
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Assise',
            description = message,
            type = type or 'info'
        })
    else
        TriggerClientEvent('vCore:notification', source, message, type)
    end
end

local function IsPlayerAdmin(src)
    -- Vérifier par groupe
    for _, group in pairs(SitConfig.AdminGroups) do
        if vCore and vCore.Functions and vCore.Functions.HasPermission then
            if vCore.Functions.HasPermission(src, group) then
                return true
            end
        end
        
        if IsPlayerAceAllowed(src, 'command.' .. group) or IsPlayerAceAllowed(src, group) then
            return true
        end
    end
    
    -- Vérifier par license2
    local playerLicense = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local identifier = GetPlayerIdentifier(src, i)
        if string.match(identifier, "license2:") then
            playerLicense = identifier
            break
        end
    end
    
    if playerLicense then
        for _, adminLicense in ipairs(SitConfig.AdminLicenses) do
            if playerLicense == adminLicense then
                return true
            end
        end
    end
    
    return false
end

-- ================================
-- SAUVEGARDE / CHARGEMENT
-- ================================

function SaveSitPoints()
    SaveResourceFile(GetCurrentResourceName(), 'sit_points.json', json.encode(sitPoints))
end

function LoadSitPoints()
    local data = LoadResourceFile(GetCurrentResourceName(), 'sit_points.json')
    if data then
        sitPoints = json.decode(data) or {}
        for id, _ in pairs(sitPoints) do
            if tonumber(id) >= nextPointId then
                nextPointId = tonumber(id) + 1
            end
        end
        print('[vAvA Core - Sit] ' .. tableLength(sitPoints) .. ' point(s) chargé(s)')
    end
end

function tableLength(t)
    local count = 0
    for _ in pairs(t or {}) do count = count + 1 end
    return count
end

-- ================================
-- EVENTS
-- ================================

RegisterNetEvent('vCore:sit:getSitPoints', function()
    local src = source
    TriggerClientEvent('vCore:sit:updatePoints', src, sitPoints)
end)

RegisterNetEvent('vCore:sit:checkAdmin', function()
    local src = source
    TriggerClientEvent('vCore:sit:setAdminStatus', src, IsPlayerAdmin(src))
end)

RegisterNetEvent('vCore:sit:createPoint', function(pointData)
    local src = source
    
    if not IsPlayerAdmin(src) then
        Notify(src, SitConfig.Messages.no_permission, 'error')
        return
    end
    
    local pointId = tostring(nextPointId)
    sitPoints[pointId] = {
        id = pointId,
        coords = pointData.coords,
        heading = pointData.heading,
        created_by = GetPlayerName(src),
        created_at = os.time()
    }
    
    nextPointId = nextPointId + 1
    
    SaveSitPoints()
    TriggerClientEvent('vCore:sit:updatePoints', -1, sitPoints)
    
    Notify(src, SitConfig.Messages.point_created, 'success')
    print('[vAvA Core - Sit] Point créé par ' .. GetPlayerName(src) .. ' (ID: ' .. pointId .. ')')
end)

RegisterNetEvent('vCore:sit:updatePoint', function(pointId, pointData)
    local src = source
    
    if not IsPlayerAdmin(src) then
        Notify(src, SitConfig.Messages.no_permission, 'error')
        return
    end
    
    pointId = tostring(pointId)
    
    if not sitPoints[pointId] then
        Notify(src, SitConfig.Messages.point_not_found, 'error')
        return
    end
    
    -- Faire lever le joueur si le point est occupé
    if occupiedPoints[pointId] then
        TriggerClientEvent('vCore:sit:forceStandUp', occupiedPoints[pointId])
        occupiedPoints[pointId] = nil
    end
    
    sitPoints[pointId].coords = pointData.coords
    sitPoints[pointId].heading = pointData.heading
    sitPoints[pointId].updated_by = GetPlayerName(src)
    sitPoints[pointId].updated_at = os.time()
    
    SaveSitPoints()
    TriggerClientEvent('vCore:sit:updatePoints', -1, sitPoints)
    
    Notify(src, SitConfig.Messages.point_updated, 'success')
end)

RegisterNetEvent('vCore:sit:deletePoint', function(pointId)
    local src = source
    
    if not IsPlayerAdmin(src) then
        Notify(src, SitConfig.Messages.no_permission, 'error')
        return
    end
    
    pointId = tostring(pointId)
    
    if not sitPoints[pointId] then
        Notify(src, SitConfig.Messages.point_not_found, 'error')
        return
    end
    
    -- Faire lever le joueur si le point est occupé
    if occupiedPoints[pointId] then
        TriggerClientEvent('vCore:sit:forceStandUp', occupiedPoints[pointId])
        occupiedPoints[pointId] = nil
    end
    
    sitPoints[pointId] = nil
    
    SaveSitPoints()
    TriggerClientEvent('vCore:sit:updatePoints', -1, sitPoints)
    
    Notify(src, SitConfig.Messages.point_deleted, 'success')
end)

RegisterNetEvent('vCore:sit:occupy', function(pointId)
    local src = source
    pointId = tostring(pointId)
    
    if occupiedPoints[pointId] then
        Notify(src, SitConfig.Messages.point_occupied, 'error')
        return
    end
    
    occupiedPoints[pointId] = src
    TriggerClientEvent('vCore:sit:confirmSit', src, pointId)
end)

RegisterNetEvent('vCore:sit:release', function(pointId)
    local src = source
    pointId = tostring(pointId)
    
    if occupiedPoints[pointId] == src then
        occupiedPoints[pointId] = nil
    end
end)

-- ================================
-- EXPORTS SERVEUR
-- ================================

exports('CreateSitPoint', function(coords, heading)
    local pointId = tostring(nextPointId)
    sitPoints[pointId] = {
        id = pointId,
        coords = coords,
        heading = heading or 0.0,
        created_by = 'System',
        created_at = os.time()
    }
    
    nextPointId = nextPointId + 1
    SaveSitPoints()
    TriggerClientEvent('vCore:sit:updatePoints', -1, sitPoints)
    
    return pointId
end)

exports('DeleteSitPoint', function(pointId)
    pointId = tostring(pointId)
    
    if sitPoints[pointId] then
        if occupiedPoints[pointId] then
            TriggerClientEvent('vCore:sit:forceStandUp', occupiedPoints[pointId])
            occupiedPoints[pointId] = nil
        end
        
        sitPoints[pointId] = nil
        SaveSitPoints()
        TriggerClientEvent('vCore:sit:updatePoints', -1, sitPoints)
        return true
    end
    
    return false
end)

exports('GetSitPoints', function()
    return sitPoints
end)

exports('IsPointOccupied', function(pointId)
    return occupiedPoints[tostring(pointId)] ~= nil
end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('playerDropped', function()
    local src = source
    
    for pointId, occupant in pairs(occupiedPoints) do
        if occupant == src then
            occupiedPoints[pointId] = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(1000)
        LoadSitPoints()
    end
end)
