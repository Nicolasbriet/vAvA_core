--[[
    vAvA_player_manager - Client Licenses
    Gestion licences côté client
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = require 'config'

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHER LICENCES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:ShowLicenses', function()
    local player = vCore.GetPlayerData()
    
    if not player then return end
    
    vCore.TriggerCallback('vAvA_player_manager:server:GetLicenses', function(licenses)
        -- Ouvrir interface NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'showLicenses',
            licenses = licenses,
            availableLicenses = PMConfig.Licenses
        })
    end, player.citizenid)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ACHETER LICENCE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:BuyLicense', function(licenseType)
    -- Trouver config licence
    local licenseConfig = nil
    for _, license in ipairs(PMConfig.Licenses) do
        if license.name == licenseType then
            licenseConfig = license
            break
        end
    end
    
    if not licenseConfig then
        return TriggerEvent('vAvA:Notify', 'Licence introuvable', 'error')
    end
    
    -- Vérifier si examen requis
    if licenseConfig.examRequired then
        TriggerEvent('vAvA:Notify', string.format('Vous devez passer un examen. Rendez-vous au point d\'examen.'), 'info')
        
        -- Créer blip
        if licenseConfig.examLocation then
            CreateExamBlip(licenseConfig)
        end
        return
    end
    
    -- Acheter directement
    TriggerServerEvent('vAvA_player_manager:server:BuyLicense', licenseType)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXAMENS
-- ═══════════════════════════════════════════════════════════════════════════

local ExamBlips = {}

function CreateExamBlip(licenseConfig)
    -- Supprimer anciens blips
    for _, blip in pairs(ExamBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    ExamBlips = {}
    
    -- Créer nouveau blip
    local coords = licenseConfig.examLocation
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 408)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 46)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Examen: ' .. licenseConfig.label)
    EndTextCommandSetBlipName(blip)
    
    table.insert(ExamBlips, blip)
    
    -- Créer point d'interaction
    CreateExamPoint(licenseConfig)
end

function CreateExamPoint(licenseConfig)
    local coords = licenseConfig.examLocation
    
    CreateThread(function()
        local examStarted = false
        
        while not examStarted do
            Wait(0)
            
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(playerCoords - coords)
            
            if distance < 10.0 then
                DrawMarker(27, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.5, 1.5, 1.0, 255, 30, 30, 200, false, true, 2, false, nil, nil, false)
                
                if distance < 2.0 then
                    DrawText3D(coords.x, coords.y, coords.z, '[~g~E~s~] Commencer examen: ' .. licenseConfig.label)
                    
                    if IsControlJustReleased(0, 38) then  -- E
                        examStarted = true
                        StartExam(licenseConfig)
                        
                        -- Supprimer blip
                        for _, blip in pairs(ExamBlips) do
                            if DoesBlipExist(blip) then
                                RemoveBlip(blip)
                            end
                        end
                        ExamBlips = {}
                    end
                end
            end
        end
    end)
end

function StartExam(licenseConfig)
    TriggerEvent('vAvA:Notify', 'Examen commencé: ' .. licenseConfig.label, 'info')
    
    -- Ouvrir interface examen
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'startExam',
        license = licenseConfig
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeLicenses', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyLicense', function(data, cb)
    SetNuiFocus(false, false)
    TriggerEvent('vAvA_player_manager:client:BuyLicense', data.licenseType)
    cb('ok')
end)

RegisterNUICallback('examComplete', function(data, cb)
    SetNuiFocus(false, false)
    
    if data.passed then
        TriggerServerEvent('vAvA_player_manager:server:BuyLicense', data.licenseType)
        TriggerEvent('vAvA:Notify', 'Examen réussi!', 'success')
    else
        TriggerEvent('vAvA:Notify', 'Examen échoué', 'error')
    end
    
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowLicenses', function()
    TriggerEvent('vAvA_player_manager:client:ShowLicenses')
end)

exports('BuyLicense', function(licenseType)
    TriggerEvent('vAvA_player_manager:client:BuyLicense', licenseType)
end)
