--[[
    vAvA_core - Tests Unitaires
    Tests du système core
]]

return {
    {
        name = 'test_core_initialization',
        type = 'critical',
        description = 'Vérifie que le core est correctement initialisé',
        run = function(ctx)
            -- Vérifier que vAvA existe
            ctx.assert.isNotNil(_G.vAvA, 'vAvA global doit exister')
            
            -- Vérifier les fonctions principales
            ctx.assert.isType(vAvA.GetPlayer, 'function', 'GetPlayer doit être une fonction')
            ctx.assert.isType(vAvA.GetPlayers, 'function', 'GetPlayers doit être une fonction')
        end
    },
    
    {
        name = 'test_database_connection',
        type = 'critical',
        description = 'Vérifie la connexion à la base de données',
        run = function(ctx)
            local success = false
            
            -- Tester une query simple
            MySQL.scalar('SELECT 1 as test', {}, function(result)
                success = (result == 1)
            end)
            
            -- Attendre la réponse
            ctx.utils.wait(1000)
            
            ctx.assert.isTrue(success, 'La base de données doit répondre')
        end
    },
    
    {
        name = 'test_player_table_exists',
        type = 'critical',
        description = 'Vérifie que les tables joueurs existent',
        run = function(ctx)
            local tables = {}
            
            MySQL.query('SHOW TABLES LIKE "users"', {}, function(result)
                if result and #result > 0 then
                    table.insert(tables, 'users')
                end
            end)
            
            MySQL.query('SHOW TABLES LIKE "characters"', {}, function(result)
                if result and #result > 0 then
                    table.insert(tables, 'characters')
                end
            end)
            
            ctx.utils.wait(1000)
            
            ctx.assert.isTrue(#tables >= 2, 'Les tables users et characters doivent exister')
        end
    },
    
    {
        name = 'test_callback_system',
        type = 'unit',
        description = 'Vérifie que le système de callbacks fonctionne',
        run = function(ctx)
            local callbackCalled = false
            
            -- Enregistrer un callback de test
            vAvA.RegisterCallback('testbench:test_callback', function(source, cb)
                callbackCalled = true
                cb(true)
            end)
            
            -- Déclencher le callback
            vAvA.TriggerCallback('testbench:test_callback', function(result)
                ctx.assert.isTrue(result, 'Le callback doit retourner true')
            end)
            
            ctx.utils.wait(100)
            ctx.assert.isTrue(callbackCalled, 'Le callback doit être appelé')
        end
    },
    
    {
        name = 'test_player_cache',
        type = 'unit',
        description = 'Vérifie le système de cache des joueurs',
        run = function(ctx)
            -- Le cache doit exister
            ctx.assert.isNotNil(vAvA.Players, 'Le cache Players doit exister')
            ctx.assert.isType(vAvA.Players, 'table', 'Players doit être une table')
        end
    },
    
    {
        name = 'test_permissions_system',
        type = 'security',
        description = 'Vérifie le système de permissions',
        run = function(ctx)
            -- Vérifier que les fonctions de permissions existent
            ctx.assert.isType(vAvA.HasPermission, 'function', 'HasPermission doit exister')
            ctx.assert.isType(vAvA.AddPermission, 'function', 'AddPermission doit exister')
            ctx.assert.isType(vAvA.RemovePermission, 'function', 'RemovePermission doit exister')
        end
    }
}
