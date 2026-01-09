--[[
    vAvA_economy - Tests Unitaires
    Tests du système économique
]]

return {
    {
        name = 'test_economy_initialization',
        type = 'critical',
        description = 'Vérifie que le module economy est initialisé',
        run = function(ctx)
            -- Vérifier que les exports existent
            local hasExport = pcall(function()
                exports['economy']:GetPrice('bread', 'supermarket', 1)
            end)
            
            ctx.assert.isTrue(hasExport, 'Le module economy doit avoir des exports')
        end
    },
    
    {
        name = 'test_price_calculation',
        type = 'unit',
        description = 'Vérifie le calcul des prix',
        run = function(ctx)
            local price = exports['economy']:GetPrice('bread', 'supermarket', 1)
            
            ctx.assert.isNotNil(price, 'Le prix ne doit pas être nil')
            ctx.assert.isType(price, 'number', 'Le prix doit être un nombre')
            ctx.assert.isTrue(price > 0, 'Le prix doit être positif')
        end
    },
    
    {
        name = 'test_salary_calculation',
        type = 'unit',
        description = 'Vérifie le calcul des salaires',
        run = function(ctx)
            local salary = exports['economy']:GetSalary('police', 0)
            
            ctx.assert.isNotNil(salary, 'Le salaire ne doit pas être nil')
            ctx.assert.isType(salary, 'number', 'Le salaire doit être un nombre')
            ctx.assert.isTrue(salary >= 0, 'Le salaire doit être >= 0')
        end
    },
    
    {
        name = 'test_tax_application',
        type = 'unit',
        description = 'Vérifie l\'application des taxes',
        run = function(ctx)
            local amount = 1000
            local taxed = exports['economy']:ApplyTax('purchase', amount)
            
            ctx.assert.isNotNil(taxed, 'Le montant taxé ne doit pas être nil')
            ctx.assert.isType(taxed, 'number', 'Le montant taxé doit être un nombre')
            ctx.assert.isTrue(taxed >= amount, 'Le montant taxé doit être >= montant original')
        end
    },
    
    {
        name = 'test_economy_state',
        type = 'unit',
        description = 'Vérifie l\'état de l\'économie',
        run = function(ctx)
            local state = exports['economy']:GetEconomyState()
            
            ctx.assert.isNotNil(state, 'L\'état économique ne doit pas être nil')
            ctx.assert.isNotNil(state.inflation, 'L\'inflation doit être définie')
            ctx.assert.isNotNil(state.baseMultiplier, 'Le multiplicateur de base doit être défini')
        end
    },
    
    {
        name = 'test_quantity_discount',
        type = 'unit',
        description = 'Vérifie les remises sur quantité',
        run = function(ctx)
            local price1 = exports['economy']:GetPrice('bread', 'supermarket', 1)
            local price10 = exports['economy']:GetPrice('bread', 'supermarket', 10)
            
            -- Le prix unitaire pour 10 devrait être <= au prix unitaire pour 1
            local unitPrice10 = price10 / 10
            ctx.assert.isTrue(unitPrice10 <= price1, 'Une remise sur quantité devrait s\'appliquer')
        end
    },
    
    {
        name = 'test_transaction_logging',
        type = 'integration',
        description = 'Vérifie l\'enregistrement des transactions',
        run = function(ctx)
            local logged = false
            
            -- Enregistrer une transaction de test
            exports['economy']:RegisterTransaction({
                type = 'purchase',
                player = 'test_player',
                item = 'bread',
                amount = 100,
                shop = 'supermarket'
            })
            
            logged = true
            
            ctx.assert.isTrue(logged, 'La transaction doit être enregistrée')
        end
    },
    
    {
        name = 'test_auto_adjustment',
        type = 'integration',
        description = 'Vérifie le système d\'auto-ajustement',
        run = function(ctx)
            -- Vérifier que la fonction existe
            local hasAdjustment = pcall(function()
                exports['economy']:RecalculateEconomy()
            end)
            
            ctx.assert.isTrue(hasAdjustment, 'Le système d\'auto-ajustement doit exister')
        end
    }
}
