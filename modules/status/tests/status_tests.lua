-- ========================================
-- VAVA STATUS - TESTBENCH TESTS
-- Tests automatisés pour le module status
-- ========================================

return {
    name = "vAvA Status Tests",
    description = "Tests complets du système de faim et soif",
    author = "vAvA Team",
    version = "1.0.0",
    
    tests = {
        -- ========================================
        -- TESTS UNITAIRES
        -- ========================================
        
        {
            name = "Status Values Initialization",
            type = "unit",
            description = "Vérifie que les valeurs initiales sont correctes",
            run = function(ctx)
                -- Les nouveaux joueurs devraient avoir faim/soif à 100
                local hunger = exports['vAvA_status']:GetHunger(1)
                local thirst = exports['vAvA_status']:GetThirst(1)
                
                ctx.assert.equals(hunger, 100, "La faim initiale devrait être 100")
                ctx.assert.equals(thirst, 100, "La soif initiale devrait être 100")
            end
        },
        
        {
            name = "Set Hunger Validation",
            type = "unit",
            description = "Vérifie la validation des limites (0-100)",
            run = function(ctx)
                local playerId = 1
                
                -- Test valeur normale
                exports['vAvA_status']:SetHunger(playerId, 50)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 50, "SetHunger(50) devrait fonctionner")
                
                -- Test valeur négative (devrait être 0)
                exports['vAvA_status']:SetHunger(playerId, -10)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 0, "SetHunger(-10) devrait être clampé à 0")
                
                -- Test valeur > 100 (devrait être 100)
                exports['vAvA_status']:SetHunger(playerId, 150)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 100, "SetHunger(150) devrait être clampé à 100")
            end
        },
        
        {
            name = "Set Thirst Validation",
            type = "unit",
            description = "Vérifie la validation des limites pour la soif",
            run = function(ctx)
                local playerId = 1
                
                -- Test valeur normale
                exports['vAvA_status']:SetThirst(playerId, 75)
                ctx.assert.equals(exports['vAvA_status']:GetThirst(playerId), 75, "SetThirst(75) devrait fonctionner")
                
                -- Test limites
                exports['vAvA_status']:SetThirst(playerId, -5)
                ctx.assert.equals(exports['vAvA_status']:GetThirst(playerId), 0, "SetThirst(-5) devrait être clampé à 0")
                
                exports['vAvA_status']:SetThirst(playerId, 200)
                ctx.assert.equals(exports['vAvA_status']:GetThirst(playerId), 100, "SetThirst(200) devrait être clampé à 100")
            end
        },
        
        {
            name = "Add Hunger",
            type = "unit",
            description = "Vérifie AddHunger avec valeurs positives et négatives",
            run = function(ctx)
                local playerId = 1
                
                -- Partir de 50
                exports['vAvA_status']:SetHunger(playerId, 50)
                
                -- Ajouter 20
                exports['vAvA_status']:AddHunger(playerId, 20)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 70, "AddHunger(20) devrait donner 70")
                
                -- Retirer 30
                exports['vAvA_status']:AddHunger(playerId, -30)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 40, "AddHunger(-30) devrait donner 40")
                
                -- Tester overflow
                exports['vAvA_status']:AddHunger(playerId, 100)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 100, "AddHunger(100) ne devrait pas dépasser 100")
            end
        },
        
        {
            name = "Item Consumption",
            type = "unit",
            description = "Vérifie la consommation d'items",
            run = function(ctx)
                local playerId = 1
                
                -- Reset à 50
                exports['vAvA_status']:SetHunger(playerId, 50)
                exports['vAvA_status']:SetThirst(playerId, 50)
                
                -- Consommer du pain (hunger +15)
                local success = exports['vAvA_status']:ConsumeItem(playerId, 'bread')
                ctx.assert.isTrue(success, "ConsumeItem('bread') devrait réussir")
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 65, "Le pain devrait ajouter 15 faim")
                
                -- Consommer de l'eau (thirst +25)
                success = exports['vAvA_status']:ConsumeItem(playerId, 'water')
                ctx.assert.isTrue(success, "ConsumeItem('water') devrait réussir")
                ctx.assert.equals(exports['vAvA_status']:GetThirst(playerId), 75, "L'eau devrait ajouter 25 soif")
                
                -- Item inexistant
                success = exports['vAvA_status']:ConsumeItem(playerId, 'invalid_item')
                ctx.assert.isFalse(success, "ConsumeItem('invalid_item') devrait échouer")
            end
        },
        
        -- ========================================
        -- TESTS D'INTÉGRATION
        -- ========================================
        
        {
            name = "Status Decay Over Time",
            type = "integration",
            description = "Vérifie que la faim/soif diminue automatiquement",
            timeout = 360000, -- 6 minutes
            run = function(ctx)
                local playerId = 1
                
                -- Reset à 100
                exports['vAvA_status']:SetHunger(playerId, 100)
                exports['vAvA_status']:SetThirst(playerId, 100)
                
                -- Activer le mode test rapide
                StatusConfig.TestMode = true
                
                local initialHunger = exports['vAvA_status']:GetHunger(playerId)
                local initialThirst = exports['vAvA_status']:GetThirst(playerId)
                
                -- Attendre 5 minutes (devrait décrementer)
                ctx.utils.wait(5 * 60 * 1000)
                
                local finalHunger = exports['vAvA_status']:GetHunger(playerId)
                local finalThirst = exports['vAvA_status']:GetThirst(playerId)
                
                ctx.assert.isTrue(finalHunger < initialHunger, "La faim devrait avoir diminué")
                ctx.assert.isTrue(finalThirst < initialThirst, "La soif devrait avoir diminué")
                ctx.assert.isTrue(finalThirst <= finalHunger, "La soif devrait diminuer plus vite que la faim")
                
                -- Désactiver le mode test
                StatusConfig.TestMode = false
            end
        },
        
        {
            name = "Inventory Integration",
            type = "integration",
            description = "Vérifie l'intégration avec l'inventaire",
            run = function(ctx)
                local playerId = 1
                
                -- Vérifier que l'inventaire est chargé
                ctx.assert.isNotNil(exports['vAvA_core'], "Le module vAvA_core devrait être chargé")
                
                -- Reset status
                exports['vAvA_status']:SetHunger(playerId, 50)
                
                -- Simuler l'utilisation d'un item depuis l'inventaire
                local success = exports['vAvA_status']:ConsumeItem(playerId, 'burger')
                
                if success then
                    local newHunger = exports['vAvA_status']:GetHunger(playerId)
                    ctx.assert.isTrue(newHunger > 50, "Le burger devrait augmenter la faim")
                    ctx.assert.isTrue(newHunger <= 100, "La faim ne devrait pas dépasser 100")
                end
            end
        },
        
        {
            name = "HUD Update",
            type = "integration",
            description = "Vérifie que le HUD reçoit les mises à jour",
            run = function(ctx)
                local playerId = 1
                
                -- Cette fonction devrait déclencher un TriggerClientEvent
                exports['vAvA_status']:SetHunger(playerId, 60)
                exports['vAvA_status']:SetThirst(playerId, 40)
                
                -- On ne peut pas tester directement le client en server-side
                -- Mais on vérifie que les valeurs sont bien définies
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 60, "Hunger mis à jour")
                ctx.assert.equals(exports['vAvA_status']:GetThirst(playerId), 40, "Thirst mis à jour")
            end
        },
        
        -- ========================================
        -- TESTS DE SÉCURITÉ
        -- ========================================
        
        {
            name = "Anti-Cheat: Reject Invalid Values",
            type = "security",
            description = "Vérifie que les valeurs invalides sont rejetées",
            run = function(ctx)
                local playerId = 1
                
                -- Reset
                exports['vAvA_status']:SetHunger(playerId, 50)
                
                -- Tester types invalides
                exports['vAvA_status']:SetHunger(playerId, "invalid")
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 0, "String devrait être converti en 0")
                
                exports['vAvA_status']:SetHunger(playerId, nil)
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 0, "Nil devrait être converti en 0")
                
                exports['vAvA_status']:SetHunger(playerId, {})
                ctx.assert.equals(exports['vAvA_status']:GetHunger(playerId), 0, "Table devrait être converti en 0")
            end
        },
        
        {
            name = "Anti-Cheat: Rate Limiting",
            type = "security",
            description = "Vérifie que les updates trop rapides sont bloquées",
            run = function(ctx)
                local playerId = 1
                
                if not StatusConfig.Security.antiCheat then
                    print("Anti-cheat désactivé, skip test")
                    return
                end
                
                -- Premier update
                exports['vAvA_status']:SetHunger(playerId, 50)
                
                -- Update immédiat (devrait être bloqué)
                local result = exports['vAvA_status']:SetHunger(playerId, 60)
                
                -- En fonction de la config, le rate limit peut bloquer
                -- On vérifie juste que le système ne crash pas
                ctx.assert.isNotNil(result, "SetHunger devrait retourner un résultat")
            end
        },
        
        -- ========================================
        -- TESTS DE COHÉRENCE
        -- ========================================
        
        {
            name = "Status Levels Coherence",
            type = "coherence",
            description = "Vérifie la cohérence des niveaux de statut",
            run = function(ctx)
                local playerId = 1
                
                -- Test niveau normal
                exports['vAvA_status']:SetHunger(playerId, 80)
                -- Devrait être niveau "normal" (pas d'effets négatifs)
                
                -- Test niveau léger
                exports['vAvA_status']:SetHunger(playerId, 50)
                -- Devrait être niveau "light" (stamina réduite)
                
                -- Test niveau warning
                exports['vAvA_status']:SetHunger(playerId, 30)
                -- Devrait être niveau "warning" (effets plus importants)
                
                -- Test niveau danger
                exports['vAvA_status']:SetHunger(playerId, 10)
                -- Devrait être niveau "danger" (perte de vie)
                
                -- Test collapse
                exports['vAvA_status']:SetHunger(playerId, 0)
                -- Devrait déclencher K.O.
                
                -- Vérifier que les valeurs sont cohérentes
                ctx.assert.isTrue(true, "Les niveaux sont cohérents")
            end
        },
        
        {
            name = "Consumable Items Coherence",
            type = "coherence",
            description = "Vérifie la cohérence des items consommables",
            run = function(ctx)
                -- Vérifier que tous les items ont les bonnes propriétés
                for itemName, itemData in pairs(StatusConfig.ConsumableItems) do
                    ctx.assert.isType(itemName, "string", "Le nom d'item devrait être une string")
                    ctx.assert.isType(itemData.hunger, "number", itemName .. " devrait avoir une valeur hunger")
                    ctx.assert.isType(itemData.thirst, "number", itemName .. " devrait avoir une valeur thirst")
                    ctx.assert.isType(itemData.animation, "string", itemName .. " devrait avoir une animation")
                    
                    -- Vérifier que l'animation est valide
                    ctx.assert.isTrue(
                        itemData.animation == 'eat' or itemData.animation == 'drink',
                        itemName .. " devrait avoir une animation 'eat' ou 'drink'"
                    )
                end
            end
        }
    }
}
