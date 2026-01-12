--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Server Shop                              ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

-- Attendre que vCore soit disponible (bloquant)
local vCore = nil
while not vCore do
    vCore = exports['vAvA_core']:GetCoreObject()
    if not vCore then Citizen.Wait(100) end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

local function GetPlayerLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, 'license:') then
            return id
        end
    end
    return nil
end

local function GetShopById(shopId)
    for _, shop in ipairs(Config.Shops) do
        if shop.id == shopId then
            return shop
        end
    end
    for _, shop in ipairs(Config.Barbers) do
        if shop.id == shopId then
            return shop
        end
    end
    for _, shop in ipairs(Config.TattooShops) do
        if shop.id == shopId then
            return shop
        end
    end
    return nil
end

local function GetCategoryPrice(category, multiplier)
    local basePrice = Config.Prices[category] or 50
    return math.floor(basePrice * (multiplier or 1.0))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - ACHATS VÊTEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Acheter un vêtement
vCore.RegisterServerCallback('vava_creator:buyClothing', function(source, cb, player, data)
    if not player then
        cb({ success = false, error = 'Joueur non trouvé' })
        return
    end
    
    local shop = GetShopById(data.shopId)
    if not shop then
        cb({ success = false, error = 'Magasin invalide' })
        return
    end
    
    -- Calculer le prix
    local price = GetCategoryPrice(data.category, shop.priceMultiplier)
    
    -- Vérifier l'argent
    local playerMoney = player.PlayerData.money
    if not playerMoney then
        cb({ success = false, error = 'Données financières indisponibles' })
        return
    end
    
    local paymentType = data.paymentType or 'cash'
    local currentMoney = playerMoney[paymentType] or 0
    
    if currentMoney < price then
        cb({ success = false, error = 'Pas assez d\'argent', required = price, current = currentMoney })
        return
    end
    
    -- Déduire l'argent
    if player.RemoveMoney then
        player.RemoveMoney(paymentType, price, 'clothing_purchase')
    elseif vCore.Economy and vCore.Economy.RemoveMoney then
        vCore.Economy.RemoveMoney(source, paymentType, price)
    end
    
    -- Sauvegarder le vêtement
    local charId = player.charId
    if charId then
        -- Récupérer les vêtements actuels
        MySQL.Async.fetchScalar([[
            SELECT clothes_data FROM characters WHERE id = ?
        ]], { charId }, function(clothesJson)
            local clothes = clothesJson and json.decode(clothesJson) or {}
            
            -- Mettre à jour le vêtement
            if data.component then
                clothes[data.component] = {
                    drawable = data.drawable,
                    texture = data.texture
                }
            elseif data.prop then
                clothes['prop_' .. data.prop] = {
                    drawable = data.drawable,
                    texture = data.texture
                }
            end
            
            -- Sauvegarder
            MySQL.Async.execute([[
                UPDATE characters SET clothes_data = ? WHERE id = ?
            ]], { json.encode(clothes), charId })
        end)
    end
    
    -- Log l'achat
    if vCore.Log then
        vCore.Log('shop', player:GetIdentifier(), string.format(
            '%s a acheté un vêtement (%s) pour $%d chez %s',
            player.PlayerData.firstname .. ' ' .. player.PlayerData.lastname,
            data.category,
            price,
            shop.name
        ), source)
    end
    
    cb({ 
        success = true, 
        message = 'Achat effectué!',
        price = price,
        newBalance = (playerMoney[paymentType] or 0) - price
    })
end)

-- Acheter plusieurs vêtements (panier)
vCore.RegisterServerCallback('vava_creator:buyCart', function(source, cb, player, data)
    if not player then
        cb({ success = false, error = 'Joueur non trouvé' })
        return
    end
    
    local shop = GetShopById(data.shopId)
    if not shop then
        cb({ success = false, error = 'Magasin invalide' })
        return
    end
    
    -- Calculer le prix total
    local totalPrice = 0
    for _, item in ipairs(data.items) do
        totalPrice = totalPrice + GetCategoryPrice(item.category, shop.priceMultiplier)
    end
    
    -- Vérifier l'argent
    local playerMoney = player.PlayerData.money
    local paymentType = data.paymentType or 'cash'
    local currentMoney = playerMoney[paymentType] or 0
    
    if currentMoney < totalPrice then
        cb({ success = false, error = 'Pas assez d\'argent', required = totalPrice, current = currentMoney })
        return
    end
    
    -- Déduire l'argent
    if player.RemoveMoney then
        player.RemoveMoney(paymentType, totalPrice, 'clothing_cart_purchase')
    elseif vCore.Economy and vCore.Economy.RemoveMoney then
        vCore.Economy.RemoveMoney(source, paymentType, totalPrice)
    end
    
    -- Sauvegarder les vêtements
    local charId = player.charId
    if charId then
        MySQL.Async.fetchScalar([[
            SELECT clothes_data FROM characters WHERE id = ?
        ]], { charId }, function(clothesJson)
            local clothes = clothesJson and json.decode(clothesJson) or {}
            
            for _, item in ipairs(data.items) do
                if item.component then
                    clothes[item.component] = {
                        drawable = item.drawable,
                        texture = item.texture
                    }
                elseif item.prop then
                    clothes['prop_' .. item.prop] = {
                        drawable = item.drawable,
                        texture = item.texture
                    }
                end
            end
            
            MySQL.Async.execute([[
                UPDATE characters SET clothes_data = ? WHERE id = ?
            ]], { json.encode(clothes), charId })
        end)
    end
    
    cb({ 
        success = true, 
        message = 'Panier acheté!',
        totalPrice = totalPrice,
        itemCount = #data.items
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - COIFFEUR
-- ═══════════════════════════════════════════════════════════════════════════

vCore.RegisterServerCallback('vava_creator:buyBarberService', function(source, cb, player, data)
    if not player then
        cb({ success = false, error = 'Joueur non trouvé' })
        return
    end
    
    -- Calculer le prix
    local price = 0
    if data.services then
        for _, service in ipairs(data.services) do
            price = price + (Config.BarberPrices[service] or 30)
        end
    else
        price = Config.BarberPrices[data.service] or 30
    end
    
    -- Vérifier l'argent
    local playerMoney = player.PlayerData.money
    local paymentType = data.paymentType or 'cash'
    local currentMoney = playerMoney[paymentType] or 0
    
    if currentMoney < price then
        cb({ success = false, error = 'Pas assez d\'argent' })
        return
    end
    
    -- Déduire l'argent
    if player.RemoveMoney then
        player.RemoveMoney(paymentType, price, 'barber_service')
    end
    
    -- Sauvegarder dans skin_data
    local charId = player.charId
    if charId and data.skinUpdates then
        MySQL.Async.fetchScalar([[
            SELECT skin_data FROM characters WHERE id = ?
        ]], { charId }, function(skinJson)
            local skin = skinJson and json.decode(skinJson) or {}
            
            -- Appliquer les modifications
            for key, value in pairs(data.skinUpdates) do
                skin[key] = value
            end
            
            MySQL.Async.execute([[
                UPDATE characters SET skin_data = ? WHERE id = ?
            ]], { json.encode(skin), charId })
        end)
    end
    
    cb({ success = true, price = price })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - CHIRURGIE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.RegisterServerCallback('vava_creator:buySurgery', function(source, cb, player, data)
    if not player then
        cb({ success = false, error = 'Joueur non trouvé' })
        return
    end
    
    -- Prix fixe pour la chirurgie
    local price = Config.SurgeryShops[1] and Config.SurgeryShops[1].price or 5000
    
    -- Vérifier l'argent
    local playerMoney = player.PlayerData.money
    local paymentType = data.paymentType or 'bank'
    local currentMoney = playerMoney[paymentType] or 0
    
    if currentMoney < price then
        cb({ success = false, error = 'Pas assez d\'argent ($' .. price .. ' requis)' })
        return
    end
    
    -- Déduire l'argent
    if player.RemoveMoney then
        player.RemoveMoney(paymentType, price, 'surgery')
    end
    
    -- Sauvegarder le nouveau skin
    local charId = player.charId
    if charId and data.newSkin then
        MySQL.Async.execute([[
            UPDATE characters SET skin_data = ? WHERE id = ?
        ]], { json.encode(data.newSkin), charId })
    end
    
    -- Log
    if vCore.Log then
        vCore.Log('shop', player:GetIdentifier(), string.format(
            '%s a effectué une chirurgie esthétique pour $%d',
            player.PlayerData.firstname .. ' ' .. player.PlayerData.lastname,
            price
        ), source)
    end
    
    cb({ success = true, price = price })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - INFORMATIONS SHOP
-- ═══════════════════════════════════════════════════════════════════════════

vCore.RegisterServerCallback('vava_creator:getShopInfo', function(source, cb, player, shopId)
    local shop = GetShopById(shopId)
    if not shop then
        cb({ success = false, error = 'Magasin invalide' })
        return
    end
    
    -- Construire les prix avec le multiplicateur
    local prices = {}
    for category, basePrice in pairs(Config.Prices) do
        prices[category] = GetCategoryPrice(category, shop.priceMultiplier)
    end
    
    cb({
        success = true,
        shop = {
            id = shop.id,
            name = shop.name,
            categories = shop.categories,
            multiplier = shop.priceMultiplier or 1.0,
            prices = prices
        }
    })
end)

-- Récupérer le solde du joueur
vCore.RegisterServerCallback('vava_creator:getPlayerMoney', function(source, cb, player)
    if not player then
        cb({ cash = 0, bank = 0 })
        return
    end
    
    cb(player.PlayerData.money or { cash = 0, bank = 0 })
end)
