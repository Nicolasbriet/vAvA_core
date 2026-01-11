--[[
    vAvA_player_manager - Client UI
    Gestion interface NUI
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = PlayerManagerConfig

local UIOpen = false
local CurrentUI = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATEUR DE PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:OpenCreator', function()
    UIOpen = true
    CurrentUI = 'creator'
    
    -- Setup caméra création
    SetupCreatorCamera()
    
    -- Ouvrir NUI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCreator',
        config = {
            allowCustomDOB = PMConfig.Creation.AllowCustomDOB,
            minAge = PMConfig.Creation.MinAge,
            maxAge = PMConfig.Creation.MaxAge,
            allowGenderChange = PMConfig.Creation.AllowGenderChange,
            nationalities = PMConfig.Creation.Nationalities,
            defaultNationality = PMConfig.Creation.DefaultNationality,
            storyMode = PMConfig.Creation.StoryMode,
            storyQuestions = PMConfig.Creation.StoryQuestions
        }
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CAMÉRA CRÉATEUR
-- ═══════════════════════════════════════════════════════════════════════════

local CreatorCamera = nil
local CreatorPed = nil

function SetupCreatorCamera()
    local coords = vector3(-813.97, 175.22, 76.74)
    local camCoords = vector3(-813.97, 176.22, 77.74)
    
    -- Créer ped temporaire
    local model = 'mp_m_freemode_01'
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    CreatorPed = CreatePed(4, model, coords.x, coords.y, coords.z, 180.0, false, true)
    SetEntityAsMissionEntity(CreatorPed, true, true)
    FreezeEntityPosition(CreatorPed, true)
    SetEntityInvincible(CreatorPed, true)
    
    -- Créer caméra
    CreatorCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(CreatorCamera, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(CreatorCamera, CreatorPed, 0.0, 0.0, 0.5, true)
    SetCamActive(CreatorCamera, true)
    RenderScriptCams(true, false, 0, true, true)
    
    DisplayRadar(false)
    DisplayHud(false)
end

function CloseCreatorCamera()
    if CreatorCamera then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(CreatorCamera, false)
        CreatorCamera = nil
        
        DisplayRadar(true)
        DisplayHud(true)
    end
    
    if CreatorPed and DoesEntityExist(CreatorPed) then
        DeleteEntity(CreatorPed)
        CreatorPed = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS - CRÉATEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('createCharacter', function(data, cb)
    -- Valider données
    if not data.firstname or not data.lastname or not data.dateofbirth or not data.sex then
        cb({error = 'Champs obligatoires manquants'})
        return
    end
    
    -- Vérifier âge
    local age = CalculateAge(data.dateofbirth)
    if age < PMConfig.Creation.MinAge then
        cb({error = string.format('Âge minimum: %d ans', PMConfig.Creation.MinAge)})
        return
    end
    if age > PMConfig.Creation.MaxAge then
        cb({error = string.format('Âge maximum: %d ans', PMConfig.Creation.MaxAge)})
        return
    end
    
    -- Envoyer au serveur
    TriggerServerEvent('vAvA_player_manager:server:CreateCharacter', {
        firstname = data.firstname,
        lastname = data.lastname,
        dateofbirth = data.dateofbirth,
        sex = data.sex,
        nationality = data.nationality or PMConfig.Creation.DefaultNationality,
        story = PMConfig.Creation.StoryMode and {
            background = data.background,
            reason_for_coming = data.reason,
            main_goal = data.goal
        } or nil
    })
    
    CloseCreatorCamera()
    UIOpen = false
    CurrentUI = nil
    SetNuiFocus(false, false)
    
    cb({success = true})
end)

RegisterNUICallback('cancelCreator', function(data, cb)
    CloseCreatorCamera()
    UIOpen = false
    CurrentUI = nil
    SetNuiFocus(false, false)
    
    -- Retour au sélecteur
    TriggerEvent('vAvA_player_manager:client:OpenSelector')
    
    cb('ok')
end)

RegisterNUICallback('updateCharacterPreview', function(data, cb)
    if CreatorPed and DoesEntityExist(CreatorPed) then
        -- Changer modèle si sexe change
        if data.sex then
            local model = data.sex == 'm' and 'mp_m_freemode_01' or 'mp_f_freemode_01'
            
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(10)
            end
            
            SetPlayerModel(PlayerId(), model)
            SetPedDefaultComponentVariation(CreatorPed)
        end
    end
    
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function CalculateAge(dateOfBirth)
    -- Format: DD/MM/YYYY
    local day, month, year = string.match(dateOfBirth, '(%d+)/(%d+)/(%d+)')
    
    if not day or not month or not year then
        return 0
    end
    
    day = tonumber(day)
    month = tonumber(month)
    year = tonumber(year)
    
    local currentDate = os.date('*t')
    local age = currentDate.year - year
    
    if currentDate.month < month or (currentDate.month == month and currentDate.day < day) then
        age = age - 1
    end
    
    return age
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ESC KEY
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if UIOpen then
            DisableControlAction(0, 322, true)  -- ESC
            DisableControlAction(0, 200, true)  -- ESC (alternative)
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenCreator', function()
    TriggerEvent('vAvA_player_manager:client:OpenCreator')
end)

exports('IsUIOpen', function()
    return UIOpen
end)

exports('GetCurrentUI', function()
    return CurrentUI
end)
