--[[
    vAvA_player_manager - Client Selector
    Interface sélection personnages
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = require 'config'

local IsOpen = false
local Characters = {}
local SelectedChar = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- OUVRIR SÉLECTEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:OpenSelector', function()
    if IsOpen then return end
    
    exports['vAvA_player_manager']:SetInSelector(true)
    IsOpen = true
    
    -- Charger personnages
    vCore.TriggerCallback('vAvA_player_manager:server:GetCharacters', function(chars)
        Characters = chars
        
        -- Setup caméra
        SetupSelectorCamera()
        
        -- Ouvrir NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openSelector',
            characters = Characters,
            config = {
                maxCharacters = PMConfig.General.MaxCharacters,
                showLastPlayed = PMConfig.Selector.ShowLastPlayed,
                showPlaytime = PMConfig.Selector.ShowPlaytime,
                allowQuickJoin = PMConfig.Selector.AllowQuickJoin
            }
        })
        
        -- Afficher premier personnage si existe
        if #Characters > 0 then
            ShowCharacterPreview(Characters[1])
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CAMÉRA
-- ═══════════════════════════════════════════════════════════════════════════

local SelectorCamera = nil

function SetupSelectorCamera()
    if PMConfig.Selector.EnableBackground3D then
        local coords = PMConfig.Selector.CameraCoords
        local rot = PMConfig.Selector.CameraRotation
        
        SelectorCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(SelectorCamera, coords.x, coords.y, coords.z)
        SetCamRot(SelectorCamera, rot.x, rot.y, rot.z, 2)
        SetCamActive(SelectorCamera, true)
        RenderScriptCams(true, false, 0, true, true)
        
        -- Cacher HUD
        DisplayRadar(false)
        DisplayHud(false)
    end
end

function CloseSelectorCamera()
    if SelectorCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(SelectorCamera, false)
        SelectorCamera = nil
        
        DisplayRadar(true)
        DisplayHud(true)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- APERÇU PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

local PreviewPed = nil

function ShowCharacterPreview(character)
    SelectedChar = character
    
    if not PMConfig.Selector.EnableBackground3D then return end
    
    -- Supprimer ancien ped
    if PreviewPed and DoesEntityExist(PreviewPed) then
        DeleteEntity(PreviewPed)
    end
    
    -- Créer nouveau ped
    local spawn = PMConfig.Selector.CharacterSpawnCoords
    local model = character.sex == 'm' and 'mp_m_freemode_01' or 'mp_f_freemode_01'
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    PreviewPed = CreatePed(4, model, spawn.x, spawn.y, spawn.z, spawn.w, false, true)
    SetEntityAsMissionEntity(PreviewPed, true, true)
    SetBlockingOfNonTemporaryEvents(PreviewPed, true)
    FreezeEntityPosition(PreviewPed, true)
    SetEntityInvincible(PreviewPed, true)
    
    -- Charger apparence
    vCore.TriggerCallback('vAvA_player_manager:server:GetAppearance', function(appearance)
        if appearance and appearance.skin then
            local skinData = json.decode(appearance.skin)
            -- Appliquer apparence
            TriggerEvent('vAvA_appearance:client:ApplyToEntity', PreviewPed, skinData)
        end
    end, character.citizenid)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('selectCharacter', function(data, cb)
    local charIndex = tonumber(data.index)
    if Characters[charIndex] then
        ShowCharacterPreview(Characters[charIndex])
    end
    cb('ok')
end)

RegisterNUICallback('playCharacter', function(data, cb)
    if not SelectedChar then
        cb('error')
        return
    end
    
    CloseSelector()
    TriggerServerEvent('vAvA_player_manager:server:LoadCharacter', SelectedChar.citizenid)
    cb('ok')
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    if not SelectedChar then
        cb('error')
        return
    end
    
    TriggerServerEvent('vAvA_player_manager:server:DeleteCharacter', SelectedChar.citizenid)
    cb('ok')
end)

RegisterNUICallback('createCharacter', function(data, cb)
    CloseSelector()
    TriggerEvent('vAvA_player_manager:client:OpenCreator')
    cb('ok')
end)

RegisterNUICallback('closeSelector', function(data, cb)
    CloseSelector()
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FERMETURE
-- ═══════════════════════════════════════════════════════════════════════════

function CloseSelector()
    IsOpen = false
    exports['vAvA_player_manager']:SetInSelector(false)
    
    SetNuiFocus(false, false)
    SendNUIMessage({action = 'closeSelector'})
    
    CloseSelectorCamera()
    
    -- Nettoyer ped preview
    if PreviewPed and DoesEntityExist(PreviewPed) then
        DeleteEntity(PreviewPed)
        PreviewPed = nil
    end
    
    SelectedChar = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenSelector', function()
    TriggerEvent('vAvA_player_manager:client:OpenSelector')
end)

exports('CloseSelector', CloseSelector)
