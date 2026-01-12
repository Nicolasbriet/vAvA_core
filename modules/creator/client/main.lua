--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Client Main                              ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

local vCore = nil
local isCreatorOpen = false
local isSelectionOpen = false
local currentSkin = {}
local creatorCam = nil
local creatorPed = nil
local originalPosition = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not vCore do
        vCore = exports['vAvA_core']:GetCoreObject()
        if not vCore then Wait(100) end
    end
    
    Wait(2000)
    TriggerServerEvent('vava_creator:playerLoaded')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS CAMERA
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateCamera(preset)
    if creatorCam then
        DestroyCam(creatorCam, false)
    end
    
    local ped = creatorPed or PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    local settings = Config.Camera.Presets[preset] or Config.Camera.Presets.summary
    local distance = settings.distance or Config.Camera.DefaultDistance
    local height = settings.height or Config.Camera.HeightOffset
    local fov = settings.fov or 50.0
    
    local camCoords = vector3(
        pedCoords.x + (forward.x * distance),
        pedCoords.y + (forward.y * distance),
        pedCoords.z + height
    )
    
    creatorCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(creatorCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(creatorCam, pedCoords.x, pedCoords.y, pedCoords.z + height)
    SetCamFov(creatorCam, fov)
    SetCamActive(creatorCam, true)
    RenderScriptCams(true, true, Config.Creator.TransitionDuration, true, false)
end

local function UpdateCameraPosition(preset)
    CreateCamera(preset)
end

local function DestroyCamera()
    if creatorCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(creatorCam, false)
        creatorCam = nil
    end
end

local function RotateCamera(direction)
    if not creatorPed then return end
    
    local currentHeading = GetEntityHeading(creatorPed)
    local rotationAmount = direction * Config.Camera.RotationSpeed * 10
    SetEntityHeading(creatorPed, currentHeading + rotationAmount)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS SKIN/APPARENCE
-- ═══════════════════════════════════════════════════════════════════════════

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    
    if not IsModelInCdimage(hash) then
        return false
    end
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    return HasModelLoaded(hash)
end

local function SetPedAppearance(ped, skin)
    if not ped or not DoesEntityExist(ped) then return end
    if not skin then return end
    
    -- Héritage (parents)
    SetPedHeadBlendData(ped,
        skin.mom or 21,
        skin.dad or 0,
        0,
        skin.mom or 21,
        skin.dad or 0,
        0,
        skin.mix or 0.5,
        skin.skinMix or 0.5,
        0.0,
        false
    )
    
    -- Traits du visage
    local faceFeatures = {
        { index = 0, value = skin.noseWidth or 0.0 },
        { index = 1, value = skin.nosePeakHeight or 0.0 },
        { index = 2, value = skin.nosePeakLength or 0.0 },
        { index = 3, value = skin.noseBoneHigh or 0.0 },
        { index = 4, value = skin.nosePeakLowering or 0.0 },
        { index = 5, value = skin.noseBoneTwist or 0.0 },
        { index = 6, value = skin.eyeBrowHeight or 0.0 },
        { index = 7, value = skin.eyeBrowLength or 0.0 },
        { index = 8, value = skin.cheekBoneHeight or 0.0 },
        { index = 9, value = skin.cheekBoneWidth or 0.0 },
        { index = 10, value = skin.cheekWidth or 0.0 },
        { index = 11, value = skin.eyeOpenning or 0.0 },
        { index = 12, value = skin.lipThickness or 0.0 },
        { index = 13, value = skin.jawBoneWidth or 0.0 },
        { index = 14, value = skin.jawBoneLength or 0.0 },
        { index = 15, value = skin.chinBoneHeight or 0.0 },
        { index = 16, value = skin.chinBoneLength or 0.0 },
        { index = 17, value = skin.chinBoneWidth or 0.0 },
        { index = 18, value = skin.chinDimple or 0.0 },
        { index = 19, value = skin.neckThickness or 0.0 }
    }
    
    for _, feature in ipairs(faceFeatures) do
        SetPedFaceFeature(ped, feature.index, feature.value)
    end
    
    -- Cheveux
    SetPedComponentVariation(ped, 2, skin.hair or 0, 0, 2)
    SetPedHairColor(ped, skin.hairColor or 0, skin.hairHighlight or 0)
    
    -- Overlays (maquillage, barbe, etc.)
    -- Barbe
    if skin.beard and skin.beard >= 0 then
        SetPedHeadOverlay(ped, 1, skin.beard, skin.beardOpacity or 1.0)
        SetPedHeadOverlayColor(ped, 1, 1, skin.beardColor or 0, skin.beardColor or 0)
    else
        SetPedHeadOverlay(ped, 1, 255, 0.0)
    end
    
    -- Sourcils
    SetPedHeadOverlay(ped, 2, skin.eyebrows or 0, skin.eyebrowsOpacity or 1.0)
    SetPedHeadOverlayColor(ped, 2, 1, skin.eyebrowsColor or 0, skin.eyebrowsColor or 0)
    
    -- Blemishes
    if skin.blemishes and skin.blemishes >= 0 then
        SetPedHeadOverlay(ped, 0, skin.blemishes, skin.blemishesOpacity or 1.0)
    else
        SetPedHeadOverlay(ped, 0, 255, 0.0)
    end
    
    -- Ageing
    if skin.ageing and skin.ageing >= 0 then
        SetPedHeadOverlay(ped, 3, skin.ageing, skin.ageingOpacity or 1.0)
    else
        SetPedHeadOverlay(ped, 3, 255, 0.0)
    end
    
    -- Complexion
    if skin.complexion and skin.complexion >= 0 then
        SetPedHeadOverlay(ped, 6, skin.complexion, skin.complexionOpacity or 1.0)
    else
        SetPedHeadOverlay(ped, 6, 255, 0.0)
    end
    
    -- Sun damage
    if skin.sunDamage and skin.sunDamage >= 0 then
        SetPedHeadOverlay(ped, 7, skin.sunDamage, skin.sunDamageOpacity or 1.0)
    else
        SetPedHeadOverlay(ped, 7, 255, 0.0)
    end
    
    -- Moles
    if skin.moles and skin.moles >= 0 then
        SetPedHeadOverlay(ped, 9, skin.moles, skin.molesOpacity or 1.0)
    else
        SetPedHeadOverlay(ped, 9, 255, 0.0)
    end
    
    -- Makeup
    if skin.makeup and skin.makeup >= 0 then
        SetPedHeadOverlay(ped, 4, skin.makeup, skin.makeupOpacity or 1.0)
        SetPedHeadOverlayColor(ped, 4, 2, skin.makeupColor or 0, skin.makeupColor or 0)
    else
        SetPedHeadOverlay(ped, 4, 255, 0.0)
    end
    
    -- Lipstick
    if skin.lipstick and skin.lipstick >= 0 then
        SetPedHeadOverlay(ped, 8, skin.lipstick, skin.lipstickOpacity or 1.0)
        SetPedHeadOverlayColor(ped, 8, 2, skin.lipstickColor or 0, skin.lipstickColor or 0)
    else
        SetPedHeadOverlay(ped, 8, 255, 0.0)
    end
    
    -- Blush
    if skin.blush and skin.blush >= 0 then
        SetPedHeadOverlay(ped, 5, skin.blush, skin.blushOpacity or 1.0)
        SetPedHeadOverlayColor(ped, 5, 2, skin.blushColor or 0, skin.blushColor or 0)
    else
        SetPedHeadOverlay(ped, 5, 255, 0.0)
    end
    
    -- Couleur des yeux
    SetPedEyeColor(ped, skin.eyeColor or 0)
end

local function SetPedClothes(ped, skin)
    if not ped or not DoesEntityExist(ped) then return end
    if not skin then return end
    
    -- Composants
    SetPedComponentVariation(ped, 1, skin.mask or 0, skin.maskTexture or 0, 2)
    SetPedComponentVariation(ped, 3, skin.arms or 15, skin.armsTexture or 0, 2)
    SetPedComponentVariation(ped, 4, skin.pants or 21, skin.pantsTexture or 0, 2)
    SetPedComponentVariation(ped, 5, skin.bag or 0, skin.bagTexture or 0, 2)
    SetPedComponentVariation(ped, 6, skin.shoes or 34, skin.shoesTexture or 0, 2)
    SetPedComponentVariation(ped, 7, skin.accessory or 0, skin.accessoryTexture or 0, 2)
    SetPedComponentVariation(ped, 8, skin.tshirt or 15, skin.tshirtTexture or 0, 2)
    SetPedComponentVariation(ped, 10, skin.decals or 0, skin.decalsTexture or 0, 2)
    SetPedComponentVariation(ped, 11, skin.torso or 15, skin.torsoTexture or 0, 2)
    
    -- Props
    if skin.hat and skin.hat >= 0 then
        SetPedPropIndex(ped, 0, skin.hat, skin.hatTexture or 0, true)
    else
        ClearPedProp(ped, 0)
    end
    
    if skin.glasses and skin.glasses >= 0 then
        SetPedPropIndex(ped, 1, skin.glasses, skin.glassesTexture or 0, true)
    else
        ClearPedProp(ped, 1)
    end
    
    if skin.ears and skin.ears >= 0 then
        SetPedPropIndex(ped, 2, skin.ears, skin.earsTexture or 0, true)
    else
        ClearPedProp(ped, 2)
    end
    
    if skin.watch and skin.watch >= 0 then
        SetPedPropIndex(ped, 6, skin.watch, skin.watchTexture or 0, true)
    else
        ClearPedProp(ped, 6)
    end
    
    if skin.bracelet and skin.bracelet >= 0 then
        SetPedPropIndex(ped, 7, skin.bracelet, skin.braceletTexture or 0, true)
    else
        ClearPedProp(ped, 7)
    end
end

local function ApplyFullSkin(ped, skin)
    SetPedAppearance(ped, skin)
    SetPedClothes(ped, skin)
end

local function ChangeSex(newSex)
    local model = newSex == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01'
    
    if LoadModel(model) then
        local coords = GetEntityCoords(creatorPed or PlayerPedId())
        local heading = GetEntityHeading(creatorPed or PlayerPedId())
        
        SetPlayerModel(PlayerId(), GetHashKey(model))
        creatorPed = PlayerPedId()
        
        SetEntityCoords(creatorPed, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(creatorPed, heading)
        
        -- Appliquer le skin par défaut pour ce sexe
        currentSkin = table.clone(newSex == 0 and Config.DefaultSkin.male or Config.DefaultSkin.female)
        ApplyFullSkin(creatorPed, currentSkin)
        
        SetModelAsNoLongerNeeded(GetHashKey(model))
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- OUVERTURE CRÉATEUR
-- ═══════════════════════════════════════════════════════════════════════════

local function OpenCreator(isFirstTime)
    if isCreatorOpen then return end
    isCreatorOpen = true
    
    -- Sauvegarder la position originale
    originalPosition = GetEntityCoords(PlayerPedId())
    
    -- Téléporter à la zone de création
    local spawn = Config.Creator.CreatorSpawn
    SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), spawn.w)
    
    Wait(500)
    
    -- Créer le ped avec le modèle par défaut
    local model = 'mp_m_freemode_01'
    if LoadModel(model) then
        SetPlayerModel(PlayerId(), GetHashKey(model))
        creatorPed = PlayerPedId()
        
        -- Appliquer le skin par défaut
        currentSkin = table.clone(Config.DefaultSkin.male)
        ApplyFullSkin(creatorPed, currentSkin)
        
        SetModelAsNoLongerNeeded(GetHashKey(model))
    end
    
    -- Setup camera
    CreateCamera('gender')
    
    -- Freeze le joueur
    FreezeEntityPosition(creatorPed, true)
    
    -- Préparer les données pour l'UI
    local uiData = {
        isFirstTime = isFirstTime,
        skin = currentSkin,
        parents = Config.Parents,
        hairColors = Config.HairColors,
        eyeColors = Config.EyeColors,
        config = {
            minAge = Config.Creator.MinAge,
            maxAge = Config.Creator.MaxAge,
            minNameLength = Config.Creator.MinNameLength,
            maxNameLength = Config.Creator.MaxNameLength,
            maxStoryLength = Config.Creator.MaxStoryLength
        }
    }
    
    -- Ouvrir l'UI
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'openCreator',
        data = uiData
    })
end

local function CloseCreator(cancelled)
    if not isCreatorOpen then return end
    isCreatorOpen = false
    
    -- Fermer l'UI
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeCreator'
    })
    
    -- Détruire la caméra
    DestroyCamera()
    
    -- Unfreeze le joueur
    if creatorPed then
        FreezeEntityPosition(creatorPed, false)
    end
    
    if cancelled and originalPosition then
        -- Retourner à la position originale
        SetEntityCoords(PlayerPedId(), originalPosition.x, originalPosition.y, originalPosition.z)
    end
    
    originalPosition = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SÉLECTION DE PERSONNAGES
-- ═══════════════════════════════════════════════════════════════════════════

local function OpenSelection()
    if isSelectionOpen then return end
    isSelectionOpen = true
    
    vCore.TriggerCallback('vava_creator:getCharacters', function(result)
        if not result.success then
            if vCore.Notify then
                vCore.Notify('Erreur: ' .. (result.error or 'Inconnue'), 'error')
            end
            isSelectionOpen = false
            return
        end
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openSelection',
            data = {
                characters = result.characters,
                maxCharacters = result.maxCharacters,
                canCreate = result.canCreate
            }
        })
    end)
end

local function CloseSelection()
    if not isSelectionOpen then return end
    isSelectionOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeSelection'
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

-- Fermer l'UI
RegisterNUICallback('close', function(data, cb)
    if isCreatorOpen then
        CloseCreator(true)
    elseif isSelectionOpen then
        CloseSelection()
    end
    cb('ok')
end)

-- Changer le sexe
RegisterNUICallback('changeSex', function(data, cb)
    ChangeSex(data.sex)
    cb({ success = true })
end)

-- Mettre à jour une valeur du skin
RegisterNUICallback('updateSkin', function(data, cb)
    if data.key and data.value ~= nil then
        currentSkin[data.key] = data.value
        ApplyFullSkin(creatorPed, currentSkin)
    end
    cb({ success = true })
end)

-- Mettre à jour plusieurs valeurs
RegisterNUICallback('updateSkinBatch', function(data, cb)
    if data.updates then
        for key, value in pairs(data.updates) do
            currentSkin[key] = value
        end
        ApplyFullSkin(creatorPed, currentSkin)
    end
    cb({ success = true })
end)

-- Changer l'étape (caméra)
RegisterNUICallback('changeStep', function(data, cb)
    UpdateCameraPosition(data.step)
    cb({ success = true })
end)

-- Tourner le personnage
RegisterNUICallback('rotatePed', function(data, cb)
    RotateCamera(data.direction or 1)
    cb({ success = true })
end)

-- Randomiser l'apparence
RegisterNUICallback('randomize', function(data, cb)
    local sex = currentSkin.sex or 0
    local baseSkin = sex == 0 and Config.DefaultSkin.male or Config.DefaultSkin.female
    
    currentSkin = table.clone(baseSkin)
    
    -- Randomiser les parents
    currentSkin.mom = Config.Parents.female[math.random(1, #Config.Parents.female)].id
    currentSkin.dad = Config.Parents.male[math.random(1, #Config.Parents.male)].id
    currentSkin.mix = math.random() 
    currentSkin.skinMix = math.random()
    
    -- Randomiser les traits du visage
    currentSkin.noseWidth = (math.random() * 2) - 1
    currentSkin.nosePeakHeight = (math.random() * 2) - 1
    currentSkin.nosePeakLength = (math.random() * 2) - 1
    currentSkin.cheekBoneHeight = (math.random() * 2) - 1
    currentSkin.cheekBoneWidth = (math.random() * 2) - 1
    currentSkin.jawBoneWidth = (math.random() * 2) - 1
    currentSkin.jawBoneLength = (math.random() * 2) - 1
    currentSkin.chinBoneHeight = (math.random() * 2) - 1
    currentSkin.chinBoneLength = (math.random() * 2) - 1
    
    -- Randomiser cheveux
    local maxHair = sex == 0 and 36 or 38
    currentSkin.hair = math.random(0, maxHair)
    currentSkin.hairColor = math.random(0, #Config.HairColors - 1)
    currentSkin.hairHighlight = math.random(0, #Config.HairColors - 1)
    
    -- Randomiser barbe (hommes seulement)
    if sex == 0 then
        currentSkin.beard = math.random(-1, 28)
        currentSkin.beardColor = currentSkin.hairColor
    end
    
    -- Couleur des yeux
    currentSkin.eyeColor = math.random(0, #Config.EyeColors - 1)
    
    ApplyFullSkin(creatorPed, currentSkin)
    
    cb({ success = true, skin = currentSkin })
end)

-- Réinitialiser l'apparence
RegisterNUICallback('reset', function(data, cb)
    local sex = currentSkin.sex or 0
    currentSkin = table.clone(sex == 0 and Config.DefaultSkin.male or Config.DefaultSkin.female)
    ApplyFullSkin(creatorPed, currentSkin)
    cb({ success = true, skin = currentSkin })
end)

-- Sauvegarder le personnage
RegisterNUICallback('saveCharacter', function(data, cb)
    -- Valider les données d'identité
    if not data.firstname or #data.firstname < Config.Creator.MinNameLength then
        cb({ success = false, error = 'Prénom invalide' })
        return
    end
    
    if not data.lastname or #data.lastname < Config.Creator.MinNameLength then
        cb({ success = false, error = 'Nom invalide' })
        return
    end
    
    if not data.age or data.age < Config.Creator.MinAge or data.age > Config.Creator.MaxAge then
        cb({ success = false, error = 'Âge invalide' })
        return
    end
    
    -- Envoyer au serveur
    vCore.TriggerCallback('vava_creator:createCharacter', function(result)
        if result.success then
            -- Appliquer le skin final
            ApplyFullSkin(PlayerPedId(), currentSkin)
            
            -- Fermer le créateur
            CloseCreator(false)
            
            -- Téléporter au spawn
            local spawn = Config.Creator.FirstSpawn
            SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z)
            SetEntityHeading(PlayerPedId(), spawn.w)
            
            -- Charger le personnage
            vCore.TriggerCallback('vava_creator:loadCharacter', function(loadResult)
                if loadResult.success then
                    if vCore.Notify then
                        vCore.Notify('Bienvenue ' .. data.firstname .. ' ' .. data.lastname .. '!', 'success')
                    end
                end
            end, result.citizenid)
        end
        
        cb(result)
    end, {
        firstname = data.firstname,
        lastname = data.lastname,
        age = data.age,
        gender = currentSkin.sex,
        nationality = data.nationality or 'Américain',
        story = data.story or '',
        skin = currentSkin,
        clothes = currentSkin
    })
end)

-- Sélectionner un personnage
RegisterNUICallback('selectCharacter', function(data, cb)
    local charId = tonumber(data.citizenid)
    
    if not charId then
        print('[vAvA_creator] ERROR: Invalid character ID')
        cb({ success = false })
        return
    end
    
    print('[vAvA_creator] Loading character ID:', charId)
    
    CloseSelection()
    
    -- Charger le personnage via le système core
    TriggerServerEvent('vCore:loadPlayer', charId)
    
    cb({ success = true })
end)

-- Supprimer un personnage
RegisterNUICallback('deleteCharacter', function(data, cb)
    vCore.TriggerCallback('vava_creator:deleteCharacter', function(result)
        if result.success then
            -- Rafraîchir la liste
            vCore.TriggerCallback('vava_creator:getCharacters', function(charsResult)
                SendNUIMessage({
                    action = 'updateCharacters',
                    data = charsResult
                })
            end)
        end
        cb(result)
    end, data.citizenid)
end)

-- Créer un nouveau personnage depuis la sélection
RegisterNUICallback('newCharacter', function(data, cb)
    CloseSelection()
    Wait(300)
    OpenCreator(false)
    cb({ success = true })
end)

-- Obtenir le nombre de variations disponibles
RegisterNUICallback('getVariationCount', function(data, cb)
    local ped = creatorPed or PlayerPedId()
    local result = {}
    
    if data.type == 'component' then
        result.count = GetNumberOfPedDrawableVariations(ped, data.componentId)
        result.textureCount = GetNumberOfPedTextureVariations(ped, data.componentId, data.drawableId or 0)
    elseif data.type == 'prop' then
        result.count = GetNumberOfPedPropDrawableVariations(ped, data.propId)
        result.textureCount = GetNumberOfPedPropTextureVariations(ped, data.propId, data.drawableId or 0)
    elseif data.type == 'hair' then
        result.count = GetNumberOfPedDrawableVariations(ped, 2)
    elseif data.type == 'overlay' then
        result.count = GetNumHeadOverlayValues(data.overlayId)
    end
    
    cb(result)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vava_creator:openCreator', function(isFirstTime)
    print('[vAvA_creator] Received openCreator event, isFirstTime:', isFirstTime)
    OpenCreator(isFirstTime)
end)

RegisterNetEvent('vava_creator:openSelection', function()
    print('[vAvA_creator] Received openSelection event')
    OpenSelection()
end)

RegisterNetEvent('vava_creator:autoLoadCharacter', function(charId)
    print('[vAvA_creator] Auto-loading character:', charId)
    TriggerServerEvent('vCore:loadPlayer', charId)
end)

RegisterNetEvent('vava_creator:characterLoaded', function(characterData)
    -- Le personnage est chargé, appliquer le skin
    if characterData.skin then
        local model = characterData.skin.sex == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01'
        if LoadModel(model) then
            SetPlayerModel(PlayerId(), GetHashKey(model))
            ApplyFullSkin(PlayerPedId(), characterData.skin)
            SetModelAsNoLongerNeeded(GetHashKey(model))
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILS
-- ═══════════════════════════════════════════════════════════════════════════

function table.clone(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.clone(orig_key)] = table.clone(orig_value)
        end
        setmetatable(copy, table.clone(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenCreator', function()
    OpenCreator(false)
end)

exports('OpenSelection', function()
    OpenSelection()
end)

exports('GetCurrentSkin', function()
    return currentSkin
end)

exports('ApplySkin', function(skin)
    if not skin then return end
    
    currentSkin = skin
    local ped = PlayerPedId()
    
    -- Déterminer le modèle en fonction du sexe
    local model = skin.sex == 0 and 'mp_m_freemode_01' or 'mp_f_freemode_01'
    local currentModel = GetEntityModel(ped)
    local targetModel = GetHashKey(model)
    
    -- Charger le bon modèle si nécessaire
    if currentModel ~= targetModel then
        print('[vAvA_creator] Changement de modèle:', model)
        if LoadModel(model) then
            SetPlayerModel(PlayerId(), targetModel)
            Wait(100)
            ped = PlayerPedId()
            SetModelAsNoLongerNeeded(targetModel)
        else
            print('^1[vAvA_creator]^7 ERROR: Failed to load model', model)
            return
        end
    end
    
    -- Appliquer le skin complet
    ApplyFullSkin(ped, skin)
    print('[vAvA_creator] Skin appliqué:', model)
end)
