--[[
    vAvA_core - Tests d'intégration
    Tests de cycles complets
]]

return {
    {
        name = 'test_player_full_cycle',
        type = 'integration',
        description = 'Test du cycle complet d\'un joueur',
        run = function(ctx)
            local testIdentifier = 'test_' .. os.time()
            
            -- 1. Créer un joueur
            local player = exports['vAvA_core']:CreatePlayer(testIdentifier)
            ctx.assert.isNotNil(player, 'Le joueur doit être créé')
            
            -- 2. Créer un personnage
            local character = exports['vAvA_core']:CreateCharacter(testIdentifier, {
                firstname = 'Test',
                lastname = 'Player',
                dob = '01/01/2000',
                gender = 0
            })
            ctx.assert.isNotNil(character, 'Le personnage doit être créé')
            
            -- 3. Donner de l'argent
            local success = exports['vAvA_core']:AddMoney(testIdentifier, 'cash', 1000)
            ctx.assert.isTrue(success, 'L\'argent doit être ajouté')
            
            -- 4. Attribuer un job
            exports['jobs']:SetJob(testIdentifier, 'police', 0)
            local job = exports['jobs']:GetPlayerJob(testIdentifier)
            ctx.assert.equals(job.name, 'police', 'Le job doit être attribué')
            
            -- 5. Ajouter des items
            exports['inventory']:AddItem(testIdentifier, 'bread', 5)
            local count = exports['inventory']:GetItemCount(testIdentifier, 'bread')
            ctx.assert.equals(count, 5, 'Les items doivent être ajoutés')
        end
    },
    
    {
        name = 'test_economy_full_transaction',
        type = 'integration',
        description = 'Test d\'une transaction économique complète',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- 1. Donner de l'argent
            exports['vAvA_core']:AddMoney(testPlayer, 'cash', 5000)
            
            -- 2. Obtenir un prix
            local price = exports['economy']:GetPrice('bread', 'supermarket', 10)
            ctx.assert.isNotNil(price, 'Le prix doit être calculé')
            
            -- 3. Appliquer les taxes
            local totalPrice = exports['economy']:ApplyTax('purchase', price)
            ctx.assert.isTrue(totalPrice >= price, 'Les taxes doivent être appliquées')
            
            -- 4. Effectuer l'achat
            local canAfford = exports['vAvA_core']:GetMoney(testPlayer, 'cash') >= totalPrice
            ctx.assert.isTrue(canAfford, 'Le joueur doit avoir assez d\'argent')
            
            -- 5. Retirer l'argent
            local removed = exports['vAvA_core']:RemoveMoney(testPlayer, 'cash', totalPrice)
            ctx.assert.isTrue(removed, 'L\'argent doit être retiré')
            
            -- 6. Ajouter les items
            exports['inventory']:AddItem(testPlayer, 'bread', 10)
            
            -- 7. Enregistrer la transaction
            exports['economy']:RegisterTransaction({
                type = 'purchase',
                player = testPlayer,
                item = 'bread',
                quantity = 10,
                price = totalPrice,
                shop = 'supermarket'
            })
        end
    },
    
    {
        name = 'test_job_salary_payment',
        type = 'integration',
        description = 'Test du paiement de salaire',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- 1. Attribuer un job
            exports['jobs']:SetJob(testPlayer, 'police', 2)
            
            -- 2. Récupérer le salaire
            local salary = exports['economy']:GetSalary('police', 2)
            ctx.assert.isTrue(salary > 0, 'Le salaire doit être > 0')
            
            -- 3. Payer le salaire
            local initialMoney = exports['vAvA_core']:GetMoney(testPlayer, 'bank') or 0
            exports['jobs']:PaySalary(testPlayer)
            
            -- 4. Vérifier le paiement
            ctx.utils.wait(100)
            local finalMoney = exports['vAvA_core']:GetMoney(testPlayer, 'bank') or 0
            ctx.assert.isTrue(finalMoney > initialMoney, 'Le salaire doit être payé')
        end
    },
    
    {
        name = 'test_vehicle_purchase_cycle',
        type = 'integration',
        description = 'Test d\'achat de véhicule complet',
        run = function(ctx)
            if GetResourceState('concess') ~= 'started' then
                ctx.skip('Module concess non disponible')
                return
            end
            
            local testPlayer = 'test_player_' .. os.time()
            
            -- 1. Donner de l'argent
            exports['vAvA_core']:AddMoney(testPlayer, 'bank', 100000)
            
            -- 2. Obtenir le prix du véhicule
            local vehiclePrice = exports['economy']:GetVehiclePrice('adder')
            ctx.assert.isNotNil(vehiclePrice, 'Le prix du véhicule doit être défini')
            
            -- 3. Acheter le véhicule (simulation)
            local canBuy = exports['vAvA_core']:GetMoney(testPlayer, 'bank') >= vehiclePrice
            ctx.assert.isTrue(canBuy, 'Le joueur doit pouvoir acheter')
            
            -- 4. Retirer l'argent
            exports['vAvA_core']:RemoveMoney(testPlayer, 'bank', vehiclePrice)
            
            -- 5. Attribuer la propriété
            local plate = 'TEST' .. math.random(100, 999)
            exports['vAvA_core']:SetVehicleOwner(plate, testPlayer)
            
            -- 6. Donner les clés
            if GetResourceState('keys') == 'started' then
                exports['keys']:GiveKeys(testPlayer, plate)
            end
        end
    },
    
    {
        name = 'test_inventory_shop_integration',
        type = 'integration',
        description = 'Test de l\'intégration inventory + economy shop',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- 1. Donner de l'argent
            exports['vAvA_core']:AddMoney(testPlayer, 'cash', 1000)
            
            -- 2. Acheter plusieurs items
            local items = {
                {name = 'bread', quantity = 5},
                {name = 'water', quantity = 3},
                {name = 'phone', quantity = 1}
            }
            
            local totalCost = 0
            
            for _, item in ipairs(items) do
                -- Obtenir le prix
                local price = exports['economy']:GetPrice(item.name, 'supermarket', item.quantity)
                totalCost = totalCost + price
                
                -- Ajouter l'item
                exports['inventory']:AddItem(testPlayer, item.name, item.quantity)
            end
            
            -- 3. Retirer l'argent total
            local removed = exports['vAvA_core']:RemoveMoney(testPlayer, 'cash', totalCost)
            ctx.assert.isTrue(removed, 'L\'argent doit être retiré')
            
            -- 4. Vérifier l'inventaire
            local breadCount = exports['inventory']:GetItemCount(testPlayer, 'bread')
            ctx.assert.equals(breadCount, 5, 'Le pain doit être dans l\'inventaire')
        end
    }
}
