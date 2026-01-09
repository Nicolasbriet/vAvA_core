-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_economy - Exemples d'Utilisation
-- Exemples concrets pour développeurs
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 1: Créer un shop avec prix dynamiques
-- ══════════════════════════════════════════════════════════════════════════════

-- Client: Ouvrir le shop
RegisterCommand('openshop', function()
    local shop = 'supermarket' -- Nom du shop (voir config/economy.lua)
    
    -- Récupérer les items disponibles
    local items = {
        {name = 'bread', label = 'Pain'},
        {name = 'water', label = 'Eau'},
        {name = 'sandwich', label = 'Sandwich'}
    }
    
    -- Envoyer à la NUI avec les prix en temps réel
    SendNUIMessage({
        action = 'openShop',
        shop = shop,
        items = items
    })
end)

-- Server: Acheter un item
RegisterNetEvent('myshop:buyItem', function(itemName, quantity)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- 1. Obtenir le prix depuis economy
    local basePrice = exports['economy']:GetPrice(itemName, 'supermarket', quantity)
    
    -- 2. Appliquer la taxe d'achat (5% par défaut)
    local finalPrice, taxAmount = exports['economy']:ApplyTax('achat', basePrice)
    
    -- 3. Vérifier l'argent
    if xPlayer.getMoney() < finalPrice then
        TriggerClientEvent('vcore:showNotification', source, 'Argent insuffisant', 'error')
        return
    end
    
    -- 4. Transaction
    xPlayer.removeMoney(finalPrice)
    
    -- 5. Ajouter l'item (via votre système d'inventaire)
    exports['inventory']:AddItem(xPlayer.identifier, itemName, quantity)
    
    -- 6. Enregistrer la transaction pour l'auto-ajustement
    exports['economy']:RegisterTransaction(
        itemName,
        'buy',
        quantity,
        finalPrice,
        'supermarket',
        xPlayer.identifier
    )
    
    -- 7. Notifier
    TriggerClientEvent('vcore:showNotification', source, 
        ('Acheté %dx %s pour %s $ (Taxe: %s $)'):format(quantity, itemName, basePrice, taxAmount),
        'success'
    )
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 2: Système de paycheck avec salaires dynamiques
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Donner les salaires toutes les 10 minutes
CreateThread(function()
    while true do
        Wait(600000) -- 10 minutes
        
        local xPlayers = vCore.GetPlayers()
        for _, playerId in ipairs(xPlayers) do
            local xPlayer = vCore.GetPlayerFromId(playerId)
            
            if xPlayer and xPlayer.job then
                -- 1. Obtenir le salaire depuis economy (prend en compte grade, bonus, inflation)
                local baseSalary = exports['economy']:GetSalary(xPlayer.job.name, xPlayer.job.grade)
                
                -- 2. Appliquer la taxe sur salaire (2% par défaut)
                local netSalary, taxAmount = exports['economy']:ApplyTax('salaire', baseSalary)
                
                -- 3. Payer
                xPlayer.addAccountMoney('bank', netSalary)
                
                -- 4. Notifier avec détails
                TriggerClientEvent('vcore:showNotification', playerId,
                    ('💰 Salaire: %s $\n📉 Impôts: -%s $\n💳 Net: %s $'):format(
                        baseSalary,
                        taxAmount,
                        netSalary
                    ),
                    'success'
                )
            end
        end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 3: Concessionnaire avec multiplicateur de zone
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Acheter un véhicule
RegisterNetEvent('myconcess:buyVehicle', function(vehicleModel, dealershipType)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Déterminer le shop selon le type de concessionnaire
    local shopName = 'dealership_' .. dealershipType -- low, mid, premium, luxury
    
    -- 1. Obtenir le prix (l'item doit être 'vehicle_adder', 'vehicle_buffalo', etc.)
    local itemName = 'vehicle_' .. vehicleModel
    local basePrice = exports['economy']:GetPrice(itemName, shopName)
    
    -- 2. Appliquer la taxe véhicule (10% par défaut)
    local finalPrice, taxAmount = exports['economy']:ApplyTax('vehicule', basePrice)
    
    -- 3. Vérifier l'argent (banque seulement pour véhicules)
    if xPlayer.getAccount('bank').money < finalPrice then
        TriggerClientEvent('vcore:showNotification', source, 'Fonds insuffisants', 'error')
        return
    end
    
    -- 4. Transaction
    xPlayer.removeAccountMoney('bank', finalPrice)
    
    -- 5. Créer le véhicule (votre système)
    -- CreateVehicle(...) ou votre méthode
    
    -- 6. Enregistrer transaction
    exports['economy']:RegisterTransaction(
        itemName,
        'buy',
        1,
        finalPrice,
        shopName,
        xPlayer.identifier
    )
    
    -- 7. Notifier
    TriggerClientEvent('vcore:showNotification', source,
        ('Véhicule acheté:\n💵 Prix: %s $\n📋 Taxe: %s $\n💳 Total: %s $'):format(
            basePrice,
            taxAmount,
            finalPrice
        ),
        'success'
    )
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 4: Vente d'items avec prix automatique à 75%
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Vendre un item
RegisterNetEvent('myshop:sellItem', function(itemName, quantity)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- 1. Vérifier que le joueur a l'item
    local hasItem = exports['inventory']:HasItem(xPlayer.identifier, itemName, quantity)
    if not hasItem then
        TriggerClientEvent('vcore:showNotification', source, 'Vous n\'avez pas cet item', 'error')
        return
    end
    
    -- 2. Obtenir le prix de vente (75% du prix d'achat)
    local sellPrice = exports['economy']:GetSellPrice(itemName, nil, quantity)
    
    -- 3. Appliquer la taxe de vente (3% par défaut)
    local finalPrice, taxAmount = exports['economy']:ApplyTax('vente', sellPrice)
    
    -- 4. Transaction
    xPlayer.addMoney(finalPrice)
    exports['inventory']:RemoveItem(xPlayer.identifier, itemName, quantity)
    
    -- 5. Enregistrer transaction
    exports['economy']:RegisterTransaction(
        itemName,
        'sell',
        quantity,
        finalPrice,
        nil,
        xPlayer.identifier
    )
    
    -- 6. Notifier
    TriggerClientEvent('vcore:showNotification', source,
        ('Vendu %dx %s pour %s $ (Taxe: -%s $)'):format(quantity, itemName, sellPrice, taxAmount),
        'success'
    )
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 5: Craft avec coût de recette
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Craft un item
RegisterNetEvent('mycraft:craftItem', function(recipeId)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer then return end
    
    -- Définir la recette
    local recipe = {
        result = 'burger',
        resultQuantity = 1,
        ingredients = {
            {item = 'bread', quantity = 2},
            {item = 'meat', quantity = 1}
        },
        craftCost = 10 -- Coût de fabrication
    }
    
    -- 1. Vérifier les ingrédients
    for _, ingredient in ipairs(recipe.ingredients) do
        local hasItem = exports['inventory']:HasItem(xPlayer.identifier, ingredient.item, ingredient.quantity)
        if not hasItem then
            TriggerClientEvent('vcore:showNotification', source, 'Ingrédients manquants', 'error')
            return
        end
    end
    
    -- 2. Calculer le coût total (coût craft + valeur ingrédients)
    local ingredientsCost = 0
    for _, ingredient in ipairs(recipe.ingredients) do
        local itemPrice = exports['economy']:GetPrice(ingredient.item, nil, ingredient.quantity)
        ingredientsCost = ingredientsCost + itemPrice
    end
    
    local totalCost = recipe.craftCost + ingredientsCost
    
    -- 3. Vérifier l'argent pour le craft
    if xPlayer.getMoney() < recipe.craftCost then
        TriggerClientEvent('vcore:showNotification', source, 'Argent insuffisant pour craft', 'error')
        return
    end
    
    -- 4. Transaction
    xPlayer.removeMoney(recipe.craftCost)
    
    -- Retirer ingrédients
    for _, ingredient in ipairs(recipe.ingredients) do
        exports['inventory']:RemoveItem(xPlayer.identifier, ingredient.item, ingredient.quantity)
    end
    
    -- Ajouter résultat
    exports['inventory']:AddItem(xPlayer.identifier, recipe.result, recipe.resultQuantity)
    
    -- 5. Notifier
    TriggerClientEvent('vcore:showNotification', source,
        ('Craft réussi: %dx %s (Coût: %s $)'):format(recipe.resultQuantity, recipe.result, recipe.craftCost),
        'success'
    )
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 6: Obtenir des informations économiques
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Commande pour voir les infos économie
RegisterCommand('economyinfo', function(source)
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer or xPlayer.getGroup() < 3 then return end
    
    -- 1. État global
    local state = exports['economy']:GetEconomyState()
    print(('Inflation: %.4f'):format(state.inflation))
    print(('Multiplicateur: %.2f'):format(state.baseMultiplier))
    print(('Profil: %s'):format(state.profile))
    
    -- 2. Info item
    local itemName = 'bread'
    local buyPrice = exports['economy']:GetPrice(itemName)
    local sellPrice = exports['economy']:GetSellPrice(itemName)
    local rarity = exports['economy']:GetItemRarity(itemName)
    
    print(('Item: %s | Rareté: %d | Achat: %s $ | Vente: %s $'):format(
        itemName, rarity, buyPrice, sellPrice
    ))
    
    -- 3. Info job
    local jobName = 'police'
    local salary = exports['economy']:GetSalary(jobName, 0)
    
    print(('Job: %s | Salaire Grade 0: %s $'):format(jobName, salary))
end, false)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 7: Modifier l'économie depuis un script externe
-- ══════════════════════════════════════════════════════════════════════════════

-- Server: Event saisonnier (réduire tous les prix de 20%)
RegisterCommand('blackfriday', function(source)
    local xPlayer = vCore.GetPlayerFromId(source)
    if not xPlayer or xPlayer.getGroup() < 4 then return end
    
    -- Activer profil "riche inversé" (tout moins cher)
    local oldMultiplier = exports['economy']:GetEconomyState().baseMultiplier
    
    -- Mettre à 0.8 (= -20%)
    MySQL.update('UPDATE economy_state SET base_multiplier = 0.8 WHERE id = 1')
    
    -- Notifier tous les joueurs
    TriggerClientEvent('vcore:showNotification', -1,
        '🎉 BLACK FRIDAY! Tous les prix -20% pendant 24h!',
        'info'
    )
    
    -- Remettre après 24h
    SetTimeout(86400000, function()
        MySQL.update('UPDATE economy_state SET base_multiplier = ? WHERE id = 1', {oldMultiplier})
        TriggerClientEvent('vcore:showNotification', -1, 'Black Friday terminé!', 'info')
    end)
end, false)

-- ══════════════════════════════════════════════════════════════════════════════
-- EXEMPLE 8: Dashboard personnalisé (récupérer données)
-- ══════════════════════════════════════════════════════════════════════════════

-- Client: Afficher un mini-dashboard
RegisterCommand('prices', function()
    vCore.TriggerCallback('vAvA_economy:getState', function(state)
        -- Afficher dans une NUI custom
        SendNUIMessage({
            action = 'showMiniDashboard',
            inflation = state.inflation,
            multiplier = state.baseMultiplier,
            profile = state.profile
        })
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Fin des exemples
-- ══════════════════════════════════════════════════════════════════════════════
