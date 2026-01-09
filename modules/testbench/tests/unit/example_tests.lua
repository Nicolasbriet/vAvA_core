--[[
    vAvA_testbench - Example Unit Tests
    Template et exemples de tests unitaires
]]

-- Exemple de test basique
local BasicTests = {
    name = 'vAvA_core_basic',
    type = 'unit',
    description = 'Tests unitaires de base pour vAvA_core',
    
    -- Setup exécuté avant tous les tests
    setup = function(ctx)
        print('🔧 Setup: Initialisation des tests')
        ctx.data.testValue = 42
    end,
    
    -- Test 1: Vérifier les assertions de base
    testAssertions = {
        name = 'test_basic_assertions',
        run = function(ctx)
            -- Tests basiques
            ctx.assert.isTrue(true, 'true doit être true')
            ctx.assert.isFalse(false, 'false doit être false')
            ctx.assert.equals(1 + 1, 2, '1+1 doit égaler 2')
            ctx.assert.notEquals(1, 2, '1 ne doit pas égaler 2')
            
            -- Tests de type
            ctx.assert.isType('hello', 'string', 'doit être une string')
            ctx.assert.isType(123, 'number', 'doit être un number')
            ctx.assert.isType({}, 'table', 'doit être une table')
            
            -- Tests nil
            ctx.assert.isNil(nil, 'nil doit être nil')
            ctx.assert.isNotNil('value', 'value ne doit pas être nil')
        end
    },
    
    -- Test 2: Vérifier les données du contexte
    testContext = {
        name = 'test_context_data',
        run = function(ctx)
            ctx.assert.isNotNil(ctx.data, 'ctx.data doit exister')
            ctx.assert.equals(ctx.data.testValue, 42, 'testValue doit être 42')
        end
    },
    
    -- Test 3: Tester les erreurs
    testErrors = {
        name = 'test_error_handling',
        run = function(ctx)
            ctx.assert.throws(function()
                error('Test error')
            end, 'Doit lever une erreur')
        end
    },
    
    -- Teardown exécuté après tous les tests
    teardown = function(ctx)
        print('🧹 Teardown: Nettoyage après les tests')
        ctx.data = {}
    end
}

-- Exemple de test d'intégration
local IntegrationTests = {
    name = 'vAvA_economy_integration',
    type = 'integration',
    description = 'Tests d\'intégration pour l\'économie',
    
    setup = function(ctx)
        -- Mock des fonctions économiques
        ctx.data.playerMoney = 1000
        ctx.data.transactions = {}
    end,
    
    testTransactions = {
        name = 'test_money_transactions',
        run = function(ctx)
            -- Simuler une transaction
            local initialMoney = ctx.data.playerMoney
            local amount = 100
            
            -- Ajouter de l'argent
            ctx.data.playerMoney = ctx.data.playerMoney + amount
            ctx.assert.equals(ctx.data.playerMoney, initialMoney + amount, 
                'L\'argent doit être ajouté correctement')
            
            -- Retirer de l'argent
            ctx.data.playerMoney = ctx.data.playerMoney - amount
            ctx.assert.equals(ctx.data.playerMoney, initialMoney, 
                'L\'argent doit être retiré correctement')
        end
    },
    
    testNegativeBalance = {
        name = 'test_negative_balance_prevention',
        run = function(ctx)
            ctx.data.playerMoney = 50
            local withdrawAmount = 100
            
            -- Vérifier qu'on ne peut pas avoir un solde négatif
            local canWithdraw = ctx.data.playerMoney >= withdrawAmount
            ctx.assert.isFalse(canWithdraw, 
                'Ne doit pas pouvoir retirer plus que le solde')
        end
    }
}

-- Exemple de test de performance
local PerformanceTests = {
    name = 'vAvA_inventory_performance',
    type = 'stress',
    description = 'Tests de performance pour l\'inventaire',
    
    testBulkOperations = {
        name = 'test_bulk_item_operations',
        run = function(ctx)
            local startTime = os.clock()
            
            -- Simuler 1000 opérations
            local inventory = {}
            for i = 1, 1000 do
                inventory['item_' .. i] = {
                    name = 'item_' .. i,
                    count = i
                }
            end
            
            local duration = (os.clock() - startTime) * 1000
            
            -- Vérifier que ça prend moins de 100ms
            ctx.assert.isTrue(duration < 100, 
                string.format('Opérations doivent prendre moins de 100ms (actuel: %.2fms)', duration))
            
            -- Vérifier le résultat
            ctx.assert.equals(#inventory, 0, 'Inventory doit avoir des clés')
            
            -- Compter manuellement
            local count = 0
            for k, v in pairs(inventory) do
                count = count + 1
            end
            ctx.assert.equals(count, 1000, '1000 items doivent être présents')
        end
    }
}

-- Exemple de test de sécurité
local SecurityTests = {
    name = 'vAvA_security_checks',
    type = 'security',
    description = 'Tests de sécurité',
    
    testSQLInjection = {
        name = 'test_sql_injection_prevention',
        run = function(ctx)
            -- Tester des injections SQL communes
            local maliciousInputs = {
                "' OR '1'='1",
                "'; DROP TABLE users; --",
                "admin'--",
                "1' UNION SELECT NULL--"
            }
            
            for _, input in ipairs(maliciousInputs) do
                -- Vérifier qu'aucune caractère SQL dangereux n'est accepté
                local isSafe = not string.match(input, "'") or 
                               string.find(input, "%%'%%")
                
                ctx.assert.isTrue(isSafe or input:match("^[%w_%-]+$"), 
                    'Input doit être échappé ou sanitisé: ' .. input)
            end
        end
    },
    
    testPermissionChecks = {
        name = 'test_admin_permission_checks',
        run = function(ctx)
            -- Mock d'un joueur sans permissions
            local player = {
                identifier = 'player_123',
                permissions = {}
            }
            
            -- Fonction de vérification des permissions
            local function hasPermission(player, permission)
                for _, perm in ipairs(player.permissions) do
                    if perm == permission then
                        return true
                    end
                end
                return false
            end
            
            -- Tester
            ctx.assert.isFalse(hasPermission(player, 'admin'), 
                'Joueur sans permission ne doit pas être admin')
            
            -- Ajouter la permission
            table.insert(player.permissions, 'admin')
            ctx.assert.isTrue(hasPermission(player, 'admin'), 
                'Joueur avec permission doit être admin')
        end
    }
}

-- Exemple de test avec mock
local MockTests = {
    name = 'vAvA_mock_example',
    type = 'unit',
    description = 'Exemple d\'utilisation des mocks',
    
    testMockFunction = {
        name = 'test_function_mocking',
        run = function(ctx)
            -- Créer un mock
            local mockFn, mock = ctx.utils.mock(function(a, b)
                return a + b
            end)
            
            -- Utiliser le mock
            local result = mockFn(2, 3)
            
            -- Vérifier que la fonction a été appelée
            ctx.assert.isTrue(mock.wasCalled(), 'Mock doit avoir été appelé')
            ctx.assert.isTrue(mock.wasCalledWith(2, 3), 'Mock doit avoir été appelé avec (2,3)')
            ctx.assert.equals(result, 5, 'Mock doit retourner 5')
        end
    }
}

-- Exemple de scénario complet
local CompleteScenario = {
    name = 'complete_player_lifecycle',
    type = 'integration',
    description = 'Scénario complet du cycle de vie d\'un joueur',
    critical = true,
    
    setup = function(ctx)
        ctx.data.player = {
            identifier = 'test_player_' .. ctx.utils.randomString(8),
            money = 5000,
            inventory = {},
            job = 'unemployed'
        }
    end,
    
    steps = {
        {
            name = 'step_1_create_character',
            run = function(ctx)
                ctx.assert.isNotNil(ctx.data.player, 'Joueur doit exister')
                ctx.assert.isNotNil(ctx.data.player.identifier, 'Joueur doit avoir un identifier')
            end
        },
        {
            name = 'step_2_set_job',
            run = function(ctx)
                ctx.data.player.job = 'police'
                ctx.assert.equals(ctx.data.player.job, 'police', 'Job doit être police')
            end
        },
        {
            name = 'step_3_receive_salary',
            run = function(ctx)
                local salary = 500
                ctx.data.player.money = ctx.data.player.money + salary
                ctx.assert.equals(ctx.data.player.money, 5500, 'Argent doit inclure le salaire')
            end
        },
        {
            name = 'step_4_buy_item',
            run = function(ctx)
                local itemPrice = 100
                ctx.data.player.money = ctx.data.player.money - itemPrice
                ctx.data.player.inventory['bread'] = 1
                
                ctx.assert.equals(ctx.data.player.money, 5400, 'Argent doit être déduit')
                ctx.assert.equals(ctx.data.player.inventory['bread'], 1, 'Item doit être ajouté')
            end
        }
    },
    
    run = function(ctx)
        for i, step in ipairs(CompleteScenario.steps) do
            print(string.format('  ↳ Étape %d/%d: %s', i, #CompleteScenario.steps, step.name))
            step.run(ctx)
        end
    end,
    
    teardown = function(ctx)
        ctx.data.player = nil
    end
}

-- === EXPORT DES TESTS ===
return {
    BasicTests,
    IntegrationTests,
    PerformanceTests,
    SecurityTests,
    MockTests,
    CompleteScenario
}
