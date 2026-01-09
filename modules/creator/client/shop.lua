--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Client Shop                              ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

local vCore = nil
local isShopOpen = false
local currentShop = nil
local shopCam = nil
local originalSkin = {}
local currentClothes = {}
local cart = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while not vCore do
        vCore = exports['vAvA_core']:GetCoreObject()
        if not vCore then Wait(100) end
    end
    
    -- Créer les blips pour les shops
    CreateShopBlips()
    
    -- Créer les zones d'interaction
    CreateShopZones()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- BLIPS
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateShopBlips()
    -- Boutiques de vêtements
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Coiffeurs
    for _, shop in ipairs(Config.Barbers) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Tatoueurs
    for _, shop in ipairs(Config.TattooShops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
    end
    
    -- Chirurgie
    for _, shop in ipairs(Config.SurgeryShops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipColour(blip, shop.blip.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ZONES D'INTERACTION
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateShopZones()
    -- Boutiques de vêtements
    for _, shop in ipairs(Config.Shops) do
        CreateThread(function()
            while true do
                Wait(0)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - shop.coords)
                
                if distance < 2.0 then
                    DrawText3D(shop.coords.x, shop.coords.y, shop.coords.z + 1.0, '[E] ' .. shop.name)
                    
                    if IsControlJustPressed(0, 38) then -- E
                        OpenClothingShop(shop)
                    end
                elseif distance > 50.0 then
                    Wait(1000)
                elseif distance > 10.0 then
                    Wait(500)
                end
            end
        end)
    end
    
    -- Coiffeurs
    for _, shop in ipairs(Config.Barbers) do
        CreateThread(function()
            while true do
                Wait(0)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - shop.coords)
                
                if distance < 2.0 then
                    DrawText3D(shop.coords.x, shop.coords.y, shop.coords.z + 1.0, '[E] ' .. shop.name)
                    
                    if IsControlJustPressed(0, 38) then
                        OpenBarberShop(shop)
                    end
                elseif distance > 50.0 then
                    Wait(1000)
                elseif distance > 10.0 then
                    Wait(500)
                end
            end
        end)
    end
    
    -- Chirurgie
    for _, shop in ipairs(Config.SurgeryShops) do
        CreateThread(function()
            while true do
                Wait(0)
                local playerCoords = GetEntityCoords(PlayerPedId())
                local distance = #(playerCoords - shop.coords)
                
                if distance < 2.0 then
                    DrawText3D(shop.coords.x, shop.coords.y, shop.coords.z + 1.0, '[E] ' .. shop.name)
                    
                    if IsControlJustPressed(0, 38) then
                        OpenSurgeryShop(shop)
                    end
                elseif distance > 50.0 then
                    Wait(1000)
                elseif distance > 10.0 then
                    Wait(500)
                end
            end
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

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
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 100)
    ClearDrawOrigin()
end

local function SaveCurrentAppearance()
    local ped = PlayerPedId()
    originalSkin = {}
    
    -- Sauvegarder les composants
    for i = 0, 11 do
        originalSkin['component_' .. i] = {
            drawable = GetPedDrawableVariation(ped, i),
            texture = GetPedTextureVariation(ped, i)
        }
    end
    
    -- Sauvegarder les props
    for i = 0, 7 do
        originalSkin['prop_' .. i] = {
            drawable = GetPedPropIndex(ped, i),
            texture = GetPedPropTextureIndex(ped, i)
        }
    end
    
    -- Sauvegarder les overlays et cheveux
    -- Note: Ces valeurs ne peuvent pas être récupérées nativement, 
    -- on compte sur le skin sauvegardé
end

local function RestoreAppearance()
    local ped = PlayerPedId()
    
    for i = 0, 11 do
        local comp = originalSkin['component_' .. i]
        if comp then
            SetPedComponentVariation(ped, i, comp.drawable, comp.texture, 2)
        end
    end
    
    for i = 0, 7 do
        local prop = originalSkin['prop_' .. i]
        if prop then
            if prop.drawable >= 0 then
                SetPedPropIndex(ped, i, prop.drawable, prop.texture, true)
            else
                ClearPedProp(ped, i)
            end
        end
    end
end

local function CreateShopCamera()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    local camCoords = vector3(
        coords.x + (forward.x * 1.8),
        coords.y + (forward.y * 1.8),
        coords.z + 0.3
    )
    
    shopCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(shopCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(shopCam, coords.x, coords.y, coords.z + 0.3)
    SetCamFov(shopCam, 50.0)
    SetCamActive(shopCam, true)
    RenderScriptCams(true, true, 500, true, false)
end

local function UpdateShopCamera(zoomLevel, heightOffset)
    if not shopCam then return end
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    local distance = 1.0 + (zoomLevel or 1.0)
    local height = (heightOffset or 0.3)
    
    local camCoords = vector3(
        coords.x + (forward.x * distance),
        coords.y + (forward.y * distance),
        coords.z + height
    )
    
    SetCamCoord(shopCam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtCoord(shopCam, coords.x, coords.y, coords.z + height)
end

local function DestroyShopCamera()
    if shopCam then
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(shopCam, false)
        shopCam = nil
    end
end

local function RotatePed(direction)
    local ped = PlayerPedId()
    local heading = GetEntityHeading(ped)
    SetEntityHeading(ped, heading + (direction * 10))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHOP VÊTEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

function OpenClothingShop(shop)
    if isShopOpen then return end
    isShopOpen = true
    currentShop = shop
    cart = {}
    
    SaveCurrentAppearance()
    FreezeEntityPosition(PlayerPedId(), true)
    CreateShopCamera()
    
    -- Obtenir les infos du shop
    vCore.TriggerCallback('vava_creator:getShopInfo', function(result)
        if not result.success then
            CloseShop()
            return
        end
        
        -- Obtenir le solde du joueur
        vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openShop',
                data = {
                    type = 'clothing',
                    shop = result.shop,
                    categories = Config.ClothingCategories,
                    money = money,
                    sex = IsPedMale(PlayerPedId()) and 0 or 1
                }
            })
        end)
    end, shop.id)
end

function CloseShop(cancelled)
    if not isShopOpen then return end
    isShopOpen = false
    
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeShop' })
    
    DestroyShopCamera()
    FreezeEntityPosition(PlayerPedId(), false)
    
    if cancelled then
        RestoreAppearance()
    end
    
    currentShop = nil
    cart = {}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COIFFEUR
-- ═══════════════════════════════════════════════════════════════════════════

function OpenBarberShop(shop)
    if isShopOpen then return end
    isShopOpen = true
    currentShop = shop
    
    SaveCurrentAppearance()
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- Camera plus proche pour le visage
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    shopCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(shopCam, coords.x + forward.x * 0.8, coords.y + forward.y * 0.8, coords.z + 0.65)
    PointCamAtCoord(shopCam, coords.x, coords.y, coords.z + 0.65)
    SetCamFov(shopCam, 35.0)
    SetCamActive(shopCam, true)
    RenderScriptCams(true, true, 500, true, false)
    
    vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openShop',
            data = {
                type = 'barber',
                shop = { name = shop.name, id = shop.id },
                prices = Config.BarberPrices,
                money = money,
                sex = IsPedMale(PlayerPedId()) and 0 or 1,
                hairColors = Config.HairColors,
                maxHair = GetNumberOfPedDrawableVariations(ped, 2) - 1,
                maxBeard = GetNumHeadOverlayValues(1) - 1,
                maxEyebrows = GetNumHeadOverlayValues(2) - 1
            }
        })
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CHIRURGIE
-- ═══════════════════════════════════════════════════════════════════════════

function OpenSurgeryShop(shop)
    if isShopOpen then return end
    isShopOpen = true
    currentShop = shop
    
    SaveCurrentAppearance()
    FreezeEntityPosition(PlayerPedId(), true)
    
    -- Camera pour le visage
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    
    shopCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(shopCam, coords.x + forward.x * 0.7, coords.y + forward.y * 0.7, coords.z + 0.65)
    PointCamAtCoord(shopCam, coords.x, coords.y, coords.z + 0.65)
    SetCamFov(shopCam, 30.0)
    SetCamActive(shopCam, true)
    RenderScriptCams(true, true, 500, true, false)
    
    vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'openShop',
            data = {
                type = 'surgery',
                shop = { name = shop.name, id = shop.id, price = shop.price },
                money = money,
                sex = IsPedMale(PlayerPedId()) and 0 or 1,
                parents = Config.Parents,
                eyeColors = Config.EyeColors
            }
        })
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS SHOP
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeShop', function(data, cb)
    CloseShop(data.cancelled)
    cb({ success = true })
end)

RegisterNUICallback('shopRotatePed', function(data, cb)
    RotatePed(data.direction or 1)
    cb({ success = true })
end)

RegisterNUICallback('shopZoom', function(data, cb)
    UpdateShopCamera(data.zoom, data.height)
    cb({ success = true })
end)

-- Essayer un vêtement
RegisterNUICallback('tryClothing', function(data, cb)
    local ped = PlayerPedId()
    
    if data.component ~= nil then
        SetPedComponentVariation(ped, data.component, data.drawable, data.texture or 0, 2)
    elseif data.prop ~= nil then
        if data.drawable >= 0 then
            SetPedPropIndex(ped, data.prop, data.drawable, data.texture or 0, true)
        else
            ClearPedProp(ped, data.prop)
        end
    end
    
    cb({ success = true })
end)

-- Essayer une coupe de cheveux
RegisterNUICallback('tryHair', function(data, cb)
    local ped = PlayerPedId()
    
    if data.hair ~= nil then
        SetPedComponentVariation(ped, 2, data.hair, 0, 2)
    end
    
    if data.hairColor ~= nil then
        SetPedHairColor(ped, data.hairColor, data.hairHighlight or data.hairColor)
    end
    
    if data.beard ~= nil then
        if data.beard >= 0 then
            SetPedHeadOverlay(ped, 1, data.beard, data.beardOpacity or 1.0)
            SetPedHeadOverlayColor(ped, 1, 1, data.beardColor or 0, data.beardColor or 0)
        else
            SetPedHeadOverlay(ped, 1, 255, 0.0)
        end
    end
    
    if data.eyebrows ~= nil then
        SetPedHeadOverlay(ped, 2, data.eyebrows, data.eyebrowsOpacity or 1.0)
        SetPedHeadOverlayColor(ped, 2, 1, data.eyebrowsColor or 0, data.eyebrowsColor or 0)
    end
    
    cb({ success = true })
end)

-- Essayer chirurgie (modification du visage)
RegisterNUICallback('trySurgery', function(data, cb)
    local ped = PlayerPedId()
    
    if data.mom ~= nil and data.dad ~= nil then
        SetPedHeadBlendData(ped,
            data.mom,
            data.dad,
            0,
            data.mom,
            data.dad,
            0,
            data.mix or 0.5,
            data.skinMix or 0.5,
            0.0,
            false
        )
    end
    
    if data.faceFeature ~= nil and data.value ~= nil then
        SetPedFaceFeature(ped, data.faceFeature, data.value)
    end
    
    if data.eyeColor ~= nil then
        SetPedEyeColor(ped, data.eyeColor)
    end
    
    cb({ success = true })
end)

-- Acheter un vêtement
RegisterNUICallback('buyClothing', function(data, cb)
    data.shopId = currentShop.id
    
    vCore.TriggerCallback('vava_creator:buyClothing', function(result)
        if result.success then
            -- Mettre à jour le solde affiché
            vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
                SendNUIMessage({
                    action = 'updateMoney',
                    data = money
                })
            end)
            
            -- Sauvegarder la nouvelle apparence comme "originale"
            SaveCurrentAppearance()
        else
            -- Restaurer l'apparence précédente
            RestoreAppearance()
        end
        
        cb(result)
    end, data)
end)

-- Acheter coiffure
RegisterNUICallback('buyBarberService', function(data, cb)
    data.shopId = currentShop.id
    
    vCore.TriggerCallback('vava_creator:buyBarberService', function(result)
        if result.success then
            vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
                SendNUIMessage({
                    action = 'updateMoney',
                    data = money
                })
            end)
            SaveCurrentAppearance()
        else
            RestoreAppearance()
        end
        
        cb(result)
    end, data)
end)

-- Acheter chirurgie
RegisterNUICallback('buySurgery', function(data, cb)
    vCore.TriggerCallback('vava_creator:buySurgery', function(result)
        if result.success then
            vCore.TriggerCallback('vava_creator:getPlayerMoney', function(money)
                SendNUIMessage({
                    action = 'updateMoney',
                    data = money
                })
            end)
            SaveCurrentAppearance()
            CloseShop(false)
        else
            RestoreAppearance()
        end
        
        cb(result)
    end, data)
end)

-- Obtenir le nombre de variations
RegisterNUICallback('getShopVariations', function(data, cb)
    local ped = PlayerPedId()
    local result = {}
    
    if data.component ~= nil then
        result.drawableCount = GetNumberOfPedDrawableVariations(ped, data.component)
        result.textureCount = GetNumberOfPedTextureVariations(ped, data.component, data.drawable or 0)
    elseif data.prop ~= nil then
        result.drawableCount = GetNumberOfPedPropDrawableVariations(ped, data.prop)
        result.textureCount = GetNumberOfPedPropTextureVariations(ped, data.prop, data.drawable or 0)
    end
    
    cb(result)
end)

-- Annuler les modifications
RegisterNUICallback('cancelChanges', function(data, cb)
    RestoreAppearance()
    cb({ success = true })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenClothingShop', function(shopId)
    for _, shop in ipairs(Config.Shops) do
        if shop.id == shopId then
            OpenClothingShop(shop)
            return
        end
    end
end)

exports('OpenBarberShop', function(shopId)
    for _, shop in ipairs(Config.Barbers) do
        if shop.id == shopId then
            OpenBarberShop(shop)
            return
        end
    end
end)

exports('OpenSurgeryShop', function()
    if Config.SurgeryShops[1] then
        OpenSurgeryShop(Config.SurgeryShops[1])
    end
end)

exports('IsShopOpen', function()
    return isShopOpen
end)
