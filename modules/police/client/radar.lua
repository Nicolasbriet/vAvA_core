--[[
    vAvA_police - Client Radar
    Radar de vitesse pour contrôles routiers
]]

local radarActive = false
local radarTarget = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- TOGGLE RADAR
-- ═══════════════════════════════════════════════════════════════════════════

function ToggleRadar()
    if not PoliceConfig.Radar.Enabled then return end
    
    radarActive = not radarActive
    
    if radarActive then
        exports['vAvA_core']:ShowNotification('Radar ~g~ACTIVÉ~s~', 'success')
        StartRadarDetection()
    else
        exports['vAvA_core']:ShowNotification('Radar ~r~DÉSACTIVÉ~s~', 'error')
        radarTarget = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉTECTION VÉHICULES
-- ═══════════════════════════════════════════════════════════════════════════

function StartRadarDetection()
    CreateThread(function()
        while radarActive do
            Wait(100)
            
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            if vehicle == 0 then
                radarActive = false
                exports['vAvA_core']:ShowNotification('Vous devez être dans un véhicule', 'error')
                return
            end
            
            -- Chercher véhicules dans le rayon
            local detectedVehicle = nil
            local closestDist = PoliceConfig.Radar.DetectionRange
            
            for veh in EnumerateVehicles() do
                if veh ~= vehicle then
                    local vehCoords = GetEntityCoords(veh)
                    local dist = #(pedCoords - vehCoords)
                    
                    if dist < closestDist then
                        local vehHeading = GetEntityHeading(veh)
                        local pedHeading = GetEntityHeading(vehicle)
                        local angle = math.abs(vehHeading - pedHeading)
                        
                        -- Véhicule doit être devant
                        if angle < 90 or angle > 270 then
                            closestDist = dist
                            detectedVehicle = veh
                        end
                    end
                end
            end
            
            radarTarget = detectedVehicle
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHAGE HUD RADAR
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if radarActive and radarTarget and DoesEntityExist(radarTarget) then
            local speed = GetEntitySpeed(radarTarget) * 3.6 -- Convertir en km/h
            local plate = GetVehicleNumberPlateText(radarTarget)
            local model = GetDisplayNameFromVehicleModel(GetEntityModel(radarTarget))
            
            -- Déterminer limite de vitesse
            local limit = PoliceConfig.Radar.DefaultSpeedLimit
            local targetCoords = GetEntityCoords(radarTarget)
            
            for _, zone in ipairs(PoliceConfig.Radar.SpeedZones) do
                if #(targetCoords - zone.coords) <= zone.radius then
                    limit = zone.limit
                    break
                end
            end
            
            -- Afficher HUD
            local isSpeeding = speed > limit
            local color = isSpeeding and '~r~' or '~g~'
            
            DrawText2D(0.85, 0.5, '~o~RADAR ACTIF~s~', 0.5)
            DrawText2D(0.85, 0.55, 'Véhicule: ~y~' .. model, 0.4)
            DrawText2D(0.85, 0.58, 'Plaque: ~y~' .. plate, 0.4)
            DrawText2D(0.85, 0.62, color .. math.floor(speed) .. ' km/h~s~', 0.6)
            DrawText2D(0.85, 0.67, 'Limite: ~y~' .. limit .. ' km/h', 0.4)
            
            if isSpeeding then
                DrawText2D(0.85, 0.72, '~r~EXCÈS DE VITESSE~s~', 0.45)
                DrawText2D(0.85, 0.76, 'Dépassement: ~r~+' .. math.floor(speed - limit) .. ' km/h', 0.4)
            end
        elseif radarActive then
            DrawText2D(0.85, 0.5, '~o~RADAR ACTIF~s~', 0.5)
            DrawText2D(0.85, 0.55, '~r~Aucun véhicule détecté', 0.4)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(scale, scale)
    SetTextEntry("STRING")
    SetTextCentre(false)
    SetTextOutline()
    AddTextComponentString(text)
    DrawText(x, y)
end

function EnumerateVehicles()
    return coroutine.wrap(function()
        local iter, id = FindFirstVehicle()
        if not id or id == 0 then
            EndFindVehicle(iter)
            return
        end
        
        local enum = {handle = iter, destructor = EndFindVehicle}
        setmetatable(enum, {__gc = function(enum) enum.destructor(enum.handle) end})
        
        local next = true
        repeat
            coroutine.yield(id)
            next, id = FindNextVehicle(iter)
        until not next
        
        EndFindVehicle(iter)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBIND
-- ═══════════════════════════════════════════════════════════════════════════

RegisterKeyMapping('policeradar', 'Toggle Radar', 'keyboard', 'X')
RegisterCommand('policeradar', function()
    local vCore = exports['vAvA_core']:GetCoreObject()
    local playerData = vCore.GetPlayerData()
    
    if playerData.job and playerData.job.name then
        for _, policeJob in ipairs(PoliceConfig.General.PoliceJobs) do
            if playerData.job.name == policeJob then
                ToggleRadar()
                return
            end
        end
    end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ToggleRadar', ToggleRadar)
exports('IsRadarActive', function() return radarActive end)
