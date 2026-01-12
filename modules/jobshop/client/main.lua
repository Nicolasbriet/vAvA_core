--[[
    vAvA Core - Module JobShop
    Client-side
]]

local vCore = nil
local PlayerData = {}
local JobShops = {}
local shopPeds = {}
local shopBlips = {}
local isNUIOpen = false

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
    
    TriggerServerEvent('vCore:jobshop:requestShops')
end)

-- ================================
-- EVENTS FRAMEWORK
-- ================================

RegisterNetEvent('vCore:Client:OnPlayerLoaded', function()
    if vCore and vCore.Functions and vCore.Functions.GetPlayerData then
        PlayerData = vCore.Functions.GetPlayerData()
    end
    Wait(2000)
    TriggerServerEvent('vCore:jobshop:requestShops')
end)

RegisterNetEvent('vCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- ================================
-- SYNCHRONISATION DES BOUTIQUES
-- ================================

RegisterNetEvent('vCore:jobshop:syncShops', function(shops)
    JobShops = shops
    ClearShops()
    Wait(500)
    LoadShops()
end)

RegisterNetEvent('vCore:jobshop:receiveShops', function(shops)
    JobShops = shops
    ClearShops()
    Wait(500)
    LoadShops()
end)

-- ================================
-- GESTION DES BOUTIQUES
-- ================================

function LoadShops()
    for _, shop in pairs(JobShops) do
        CreateShopPed(shop)
        CreateShopBlip(shop)
    end
end

function ClearShops()
    for _, ped in pairs(shopPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    
    for _, blip in pairs(shopBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    
    shopPeds = {}
    shopBlips = {}
end

function CreateShopPed(shop)
    local model = GetHashKey(JobShopConfig.PedModel)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    local ped = CreatePed(4, model, shop.x, shop.y, shop.z - 1.0, shop.heading, false, true)
    
    SetEntityHeading(ped, shop.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, "WORLD_HUMAN_STAND_IMPATIENT", 0, true)
    
    shopPeds[shop.id] = ped
    
    -- Système de target
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'jobshop_buy_' .. shop.id,
                icon = 'fas fa-shopping-cart',
                label = 'Acheter',
                distance = JobShopConfig.InteractionDistance,
                onSelect = function()
                    TriggerServerEvent('vCore:jobshop:getShopData', shop.id)
                end
            },
            {
                name = 'jobshop_boss_' .. shop.id,
                icon = 'fas fa-cog',
                label = 'Gestion (Patron)',
                distance = JobShopConfig.InteractionDistance,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == shop.job and PlayerData.job.grade.level >= shop.boss_grade
                end,
                onSelect = function()
                    TriggerServerEvent('vCore:jobshop:getBossMenu', shop.id)
                end
            },
            {
                name = 'jobshop_stock_' .. shop.id,
                icon = 'fas fa-box',
                label = 'Approvisionner',
                distance = JobShopConfig.InteractionDistance,
                canInteract = function()
                    return PlayerData.job and PlayerData.job.name == shop.job
                end,
                onSelect = function()
                    OpenStockMenu(shop)
                end
            }
        })
    else
        -- Fallback sans target
        CreateThread(function()
            while DoesEntityExist(ped) do
                local playerCoords = GetEntityCoords(PlayerPedId())
                local pedCoords = GetEntityCoords(ped)
                local distance = #(playerCoords - pedCoords)
                
                if distance <= JobShopConfig.InteractionDistance then
                    local text = "[E] Acheter"
                    local isBoss = PlayerData.job and PlayerData.job.name == shop.job and PlayerData.job.grade.level >= shop.boss_grade
                    local isEmployee = PlayerData.job and PlayerData.job.name == shop.job
                    
                    if isBoss then
                        text = text .. " | [F] Gestion"
                    end
                    if isEmployee then
                        text = text .. " | [G] Stock"
                    end
                    
                    DrawText3D(pedCoords.x, pedCoords.y, pedCoords.z + 1.0, text)
                    
                    if IsControlJustReleased(0, 38) then -- E
                        TriggerServerEvent('vCore:jobshop:getShopData', shop.id)
                    elseif IsControlJustReleased(0, 23) and isBoss then -- F
                        TriggerServerEvent('vCore:jobshop:getBossMenu', shop.id)
                    elseif IsControlJustReleased(0, 47) and isEmployee then -- G
                        OpenStockMenu(shop)
                    end
                end
                
                Wait(0)
            end
        end)
    end
    
    SetModelAsNoLongerNeeded(model)
end

function CreateShopBlip(shop)
    local blip = AddBlipForCoord(shop.x, shop.y, shop.z)
    
    SetBlipSprite(blip, JobShopConfig.Blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, JobShopConfig.Blip.scale)
    SetBlipColour(blip, JobShopConfig.Blip.color)
    SetBlipAsShortRange(blip, JobShopConfig.Blip.shortRange)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(shop.name)
    EndTextCommandSetBlipName(blip)
    
    shopBlips[shop.id] = blip
end

-- ================================
-- NUI CALLBACKS
-- ================================

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    isNUIOpen = false
    cb({})
end)

RegisterNUICallback('buyItem', function(data, cb)
    TriggerServerEvent('vCore:jobshop:buyItem', data.shopId, data.itemName, data.quantity)
    cb({})
end)

RegisterNUICallback('withdrawCash', function(data, cb)
    TriggerServerEvent('vCore:jobshop:withdrawMoney', data.shopId, data.amount)
    cb({})
end)

RegisterNUICallback('setItemPrice', function(data, cb)
    TriggerServerEvent('vCore:jobshop:setItemPrice', data.shopId, data.itemName, data.price)
    cb({})
end)

RegisterNUICallback('addItem', function(data, cb)
    TriggerServerEvent('vCore:jobshop:addItem', data.shopId, data.itemName, data.price, data.stock)
    cb({})
end)

RegisterNUICallback('toggleItem', function(data, cb)
    TriggerServerEvent('vCore:jobshop:toggleItem', data.shopId, data.itemName, data.enabled)
    cb({})
end)

RegisterNUICallback('addStock', function(data, cb)
    TriggerServerEvent('vCore:jobshop:addStock', data.shopId, data.itemName, data.quantity)
    cb({})
end)

RegisterNUICallback('createShop', function(data, cb)
    SetNuiFocus(false, false)
    isNUIOpen = false
    
    if data.shopName and data.jobName then
        Notify('Positionnez-vous et appuyez sur ENTRÉE pour créer', 'info')
        CreateShopPositioning({
            name = data.shopName,
            job = data.jobName,
            boss_grade = tonumber(data.bossGrade) or 0
        })
    end
    cb({})
end)

RegisterNUICallback('deleteShop', function(data, cb)
    TriggerServerEvent('vCore:jobshop:deleteShop', data.shopId)
    cb({})
end)

RegisterNUICallback('adminAction', function(data, cb)
    if data.action == 'create' then
        SendNUIMessage({
            action = 'showCreateForm'
        })
    elseif data.action == 'list' then
        SetNuiFocus(false, false)
        isNUIOpen = false
        TriggerServerEvent('vCore:jobshop:listShops')
    elseif data.action == 'delete' then
        SendNUIMessage({
            action = 'showDeleteForm',
            shops = JobShops
        })
    end
    cb({})
end)

-- ================================
-- EVENTS D'OUVERTURE
-- ================================

RegisterNetEvent('vCore:jobshop:openShop', function(data)
    SendNUIMessage({
        action = 'openShop',
        shop = data.shop,
        items = data.items
    })
    SetNuiFocus(true, true)
    isNUIOpen = true
end)

RegisterNetEvent('vCore:jobshop:openBossMenu', function(data)
    SendNUIMessage({
        action = 'openBossMenu',
        shop = data.shop,
        items = data.items
    })
    SetNuiFocus(true, true)
    isNUIOpen = true
end)

RegisterNetEvent('vCore:jobshop:openAdminMenu', function(shops)
    SendNUIMessage({
        action = 'openAdminMenu',
        shops = shops
    })
    SetNuiFocus(true, true)
    isNUIOpen = true
end)

-- ================================
-- MENU STOCK (EMPLOYÉ)
-- ================================

function OpenStockMenu(shop)
    if vCore and vCore.Functions and vCore.Functions.TriggerCallback then
        vCore.Functions.TriggerCallback('vCore:jobshop:getPlayerItems', function(items)
            if not items or #items == 0 then
                Notify(JobShopConfig.Notifications.no_items, 'error')
                return
            end
            
            SendNUIMessage({
                action = 'openStockMenu',
                shop = shop,
                items = items
            })
            SetNuiFocus(true, true)
            isNUIOpen = true
        end, shop.id)
    else
        -- Fallback: envoyer directement au serveur
        TriggerServerEvent('vCore:jobshop:requestPlayerItems', shop.id)
    end
end

RegisterNetEvent('vCore:jobshop:receivePlayerItems', function(shop, items)
    if not items or #items == 0 then
        Notify(JobShopConfig.Notifications.no_items, 'error')
        return
    end
    
    SendNUIMessage({
        action = 'openStockMenu',
        shop = shop,
        items = items
    })
    SetNuiFocus(true, true)
    isNUIOpen = true
end)

-- ================================
-- CRÉATION DE BOUTIQUE (ADMIN)
-- ================================

function CreateShopPositioning(shopData)
    local positioning = true
    local markerColor = JobShopConfig.AdminMenu.marker_color
    local markerSize = JobShopConfig.AdminMenu.marker_size
    
    CreateThread(function()
        while positioning do
            local coords = GetEntityCoords(PlayerPedId())
            local heading = GetEntityHeading(PlayerPedId())
            
            DrawText3D(coords.x, coords.y, coords.z + 1.0, '~g~ENTRÉE~w~ - Créer ici | ~r~ÉCHAP~w~ - Annuler')
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 
                markerSize.x, markerSize.y, markerSize.z, 
                markerColor.r, markerColor.g, markerColor.b, markerColor.a, 
                false, true, 2, false, nil, nil, false)
            
            if IsControlJustReleased(0, 191) then -- ENTRÉE
                positioning = false
                shopData.coords = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z,
                    w = heading
                }
                TriggerServerEvent('vCore:jobshop:createShop', shopData)
            elseif IsControlJustReleased(0, 322) then -- ÉCHAP
                positioning = false
                Notify('Création annulée', 'error')
            end
            
            Wait(0)
        end
    end)
end

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

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
    DrawRect(0.0, 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function Notify(message, type)
    if vCore and vCore.Notify then
        vCore.Notify(message, type or 'info')
    else
        TriggerEvent('vCore:notification', message, type)
    end
end

-- ================================
-- EXPORTS
-- ================================

exports('OpenJobShop', function(shopId)
    TriggerServerEvent('vCore:jobshop:getShopData', shopId)
end)

exports('OpenBossMenu', function(shopId)
    TriggerServerEvent('vCore:jobshop:getBossMenu', shopId)
end)

exports('OpenStockMenu', function(shopId)
    local shop = JobShops[shopId]
    if shop then
        OpenStockMenu(shop)
    end
end)

-- ================================
-- GESTION ESCAPE
-- ================================

CreateThread(function()
    while true do
        Wait(0)
        if isNUIOpen and IsControlJustReleased(0, 322) then
            SetNuiFocus(false, false)
            SendNUIMessage({action = 'close'})
            isNUIOpen = false
        end
    end
end)

-- ================================
-- CLEANUP
-- ================================

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        TriggerServerEvent('vCore:jobshop:requestShops')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        ClearShops()
    end
end)
