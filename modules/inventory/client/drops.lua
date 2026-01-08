--[[
    vAvA_inventory - Client Drops
    Gestion des items au sol côté client
]]

local droppedItems = {}
local pickupPrompts = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATION / SUPPRESSION DROPS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_inventory:createDroppedItem')
AddEventHandler('vAvA_inventory:createDroppedItem', function(id, itemName, amount, coords)
    CreateDroppedItemObject(id, itemName, amount, coords)
end)

RegisterNetEvent('vAvA_inventory:removeDroppedItem')
AddEventHandler('vAvA_inventory:removeDroppedItem', function(id)
    RemoveDroppedItemObject(id)
end)

function CreateDroppedItemObject(id, itemName, amount, coords)
    local model = GetDropModel(itemName)
    
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Créer l'objet
    local obj = CreateObject(model, coords.x, coords.y, coords.z - 0.5, false, true, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    
    -- Ajouter un léger effet de "hover"
    local objCoords = GetEntityCoords(obj)
    SetEntityCoords(obj, objCoords.x, objCoords.y, objCoords.z + 0.1, false, false, false, false)
    
    droppedItems[id] = {
        id = id,
        object = obj,
        item = itemName,
        amount = amount,
        coords = objCoords
    }
    
    SetModelAsNoLongerNeeded(model)
end

function RemoveDroppedItemObject(id)
    local drop = droppedItems[id]
    if drop then
        if DoesEntityExist(drop.object) then
            DeleteEntity(drop.object)
        end
        droppedItems[id] = nil
    end
end

function GetDropModel(itemName)
    -- Modèles par catégorie d'item
    local models = {
        -- Armes
        weapon_ = `prop_box_guncase_01a`,
        
        -- Munitions
        ammo_ = `prop_ld_ammo_pack_01`,
        
        -- Nourriture
        bread = `prop_cs_burger_01`,
        burger = `prop_cs_burger_01`,
        water = `prop_ld_flow_bottle`,
        
        -- Défaut
        default = `prop_cs_cardbox_01`
    }
    
    local lowerName = string.lower(itemName)
    
    -- Vérifier les préfixes
    if string.find(lowerName, 'weapon_') then
        return models.weapon_
    elseif string.find(lowerName, 'ammo_') then
        return models.ammo_
    end
    
    -- Vérifier les noms exacts
    return models[lowerName] or models.default
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉTECTION PROXIMITÉ
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(500)
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestDrop = nil
        local nearestDistance = (InventoryConfig and InventoryConfig.Drops and InventoryConfig.Drops.pickupDistance) or 2.0
        
        for id, drop in pairs(droppedItems) do
            local distance = #(playerCoords - drop.coords)
            if distance < nearestDistance then
                nearestDistance = distance
                nearestDrop = drop
            end
        end
        
        -- Gérer l'affichage du prompt
        if nearestDrop then
            ShowPickupPrompt(nearestDrop)
        else
            HidePickupPrompt()
        end
    end
end)

local currentPrompt = nil

function ShowPickupPrompt(drop)
    if currentPrompt ~= drop.id then
        currentPrompt = drop.id
        
        CreateThread(function()
            while currentPrompt == drop.id do
                Wait(0)
                
                -- Afficher le texte 3D
                local coords = GetEntityCoords(drop.object)
                DrawText3D(coords.x, coords.y, coords.z + 0.3, 
                    string.format("~w~%s~n~~g~[E]~w~ Ramasser", GetItemLabel(drop.item)))
                
                -- Vérifier l'input
                if IsControlJustPressed(0, 38) then -- E
                    TriggerServerEvent('vAvA_inventory:pickupItem', drop.id)
                    HidePickupPrompt()
                end
            end
        end)
    end
end

function HidePickupPrompt()
    currentPrompt = nil
end

function GetItemLabel(itemName)
    if not itemName then return 'Item' end
    
    -- Vérifier dans les armes
    if InventoryConfig and InventoryConfig.WeaponsList then
        local weaponData = InventoryConfig.WeaponsList[string.lower(itemName)]
        if weaponData then
            return weaponData.label
        end
    end
    
    -- Vérifier dans les munitions
    if InventoryConfig and InventoryConfig.AmmoItems then
        local ammoData = InventoryConfig.AmmoItems[string.lower(itemName)]
        if ammoData then
            return ammoData.label
        end
    end
    
    return itemName
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local camCoords = GetGameplayCamCoords()
    local distance = #(vector3(x, y, z) - camCoords)
    
    if onScreen then
        local scale = 0.35 * (1 / distance) * (1 / GetRenderedSceneInfo())
        if scale > 0.4 then scale = 0.4 end
        if scale < 0.2 then scale = 0.2 end
        
        SetTextScale(scale, scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

function GetRenderedSceneInfo()
    local resolution = GetActiveScreenResolution()
    return resolution / 1920
end

-- Animation de rotation pour les drops
CreateThread(function()
    local rotSpeed = 0.5
    
    while true do
        Wait(100) -- Attendre 100ms pour éviter de surcharger
        
        for id, drop in pairs(droppedItems) do
            if drop and drop.object and DoesEntityExist(drop.object) then
                local heading = GetEntityHeading(drop.object)
                SetEntityHeading(drop.object, heading + rotSpeed)
            end
        end
    end
end)

-- Nettoyage à la déconnexion
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for id, drop in pairs(droppedItems) do
            if DoesEntityExist(drop.object) then
                DeleteEntity(drop.object)
            end
        end
    end
end)
