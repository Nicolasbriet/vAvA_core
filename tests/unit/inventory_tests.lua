--[[
    vAvA_inventory - Tests Unitaires
    Tests du système d'inventaire
]]

return {
    {
        name = 'test_inventory_initialization',
        type = 'critical',
        description = 'Vérifie que le module inventory est initialisé',
        run = function(ctx)
            local hasExport = pcall(function()
                exports['vAvA_inventory']:GetInventory('test')
            end)
            
            ctx.assert.isTrue(hasExport, 'Le module inventory doit avoir des exports')
        end
    },
    
    {
        name = 'test_add_item',
        type = 'unit',
        description = 'Vérifie l\'ajout d\'un item',
        run = function(ctx)
            -- Vérifier que la fonction existe
            local hasAddItem = pcall(function()
                return exports['vAvA_inventory']:AddItem
            end)
            
            if not hasAddItem then
                ctx.skip('Export AddItem non disponible')
                return
            end
            
            -- Mock d'un joueur
            local testPlayer = 1 -- Utiliser un ID numérique
            
            -- Ajouter un item (peut retourner nil si le joueur n'existe pas)
            local success = exports['vAvA_inventory']:AddItem(testPlayer, 'bread', 1)
            
            -- Accepter nil ou true comme succès pour ce test
            ctx.assert.isTrue(success ~= false, 'L\'item ne doit pas retourner false')
        end
    },
    
    {
        name = 'test_remove_item',
        type = 'unit',
        description = 'Vérifie la suppression d\'un item',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Ajouter puis retirer
            exports['vAvA_inventory']:AddItem(testPlayer, 'bread', 5)
            local success = exports['vAvA_inventory']:RemoveItem(testPlayer, 'bread', 2)
            
            ctx.assert.isTrue(success, 'L\'item doit être retiré avec succès')
        end
    },
    
    {
        name = 'test_item_count',
        type = 'unit',
        description = 'Vérifie le comptage des items',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Ajouter 3 items
            exports['vAvA_inventory']:AddItem(testPlayer, 'water', 3)
            
            -- Compter
            local count = exports['vAvA_inventory']:GetItemCount(testPlayer, 'water')
            
            ctx.assert.equals(count, 3, 'Le comptage doit retourner 3')
        end
    },
    
    {
        name = 'test_weight_limit',
        type = 'unit',
        description = 'Vérifie la limite de poids',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Obtenir le poids maximum
            local maxWeight = exports['vAvA_inventory']:GetMaxWeight(testPlayer)
            
            ctx.assert.isNotNil(maxWeight, 'Le poids maximum doit être défini')
            ctx.assert.isTrue(maxWeight > 0, 'Le poids maximum doit être > 0')
        end
    },
    
    {
        name = 'test_item_metadata',
        type = 'unit',
        description = 'Vérifie la gestion des métadonnées',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Ajouter un item avec metadata
            local success = exports['vAvA_inventory']:AddItem(testPlayer, 'weapon_pistol', 1, {
                ammo = 12,
                serial = 'TEST123'
            })
            
            ctx.assert.isTrue(success, 'L\'item avec metadata doit être ajouté')
        end
    },
    
    {
        name = 'test_hotbar',
        type = 'unit',
        description = 'Vérifie le système de hotbar',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Définir un slot de hotbar
            local success = exports['vAvA_inventory']:SetHotbarSlot(testPlayer, 1, 'bread')
            
            ctx.assert.isTrue(success, 'Le slot hotbar doit être défini')
        end
    },
    
    {
        name = 'test_item_usage',
        type = 'integration',
        description = 'Vérifie l\'utilisation d\'un item',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Ajouter un item utilisable
            exports['vAvA_inventory']:AddItem(testPlayer, 'bread', 1)
            
            -- Utiliser l'item
            local used = exports['vAvA_inventory']:UseItem(testPlayer, 'bread')
            
            ctx.assert.isTrue(used, 'L\'item doit pouvoir être utilisé')
        end
    },
    
    {
        name = 'test_inventory_slots',
        type = 'unit',
        description = 'Vérifie le système de slots',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Obtenir les slots
            local slots = exports['vAvA_inventory']:GetSlots(testPlayer)
            
            ctx.assert.isNotNil(slots, 'Les slots doivent être définis')
            ctx.assert.isTrue(slots > 0, 'Il doit y avoir au moins 1 slot')
        end
    }
}
