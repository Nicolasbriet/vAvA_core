--[[
    vAvA_vehicles - Tests Unitaires
    Tests du système de véhicules
]]

return {
    {
        name = 'test_vehicle_spawn',
        type = 'unit',
        description = 'Vérifie le spawn de véhicule',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Spawn un véhicule de test
            local vehicle = exports['vAvA_core']:SpawnVehicle('adder', vector3(0, 0, 0), 0.0, testPlayer)
            
            ctx.assert.isNotNil(vehicle, 'Le véhicule doit être spawné')
        end
    },
    
    {
        name = 'test_vehicle_ownership',
        type = 'unit',
        description = 'Vérifie la propriété des véhicules',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            local plate = 'TEST' .. math.random(100, 999)
            
            -- Attribuer un véhicule
            local success = exports['vAvA_core']:SetVehicleOwner(plate, testPlayer)
            
            ctx.assert.isTrue(success, 'La propriété doit être attribuée')
        end
    },
    
    {
        name = 'test_vehicle_keys',
        type = 'integration',
        description = 'Vérifie le système de clés',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            local plate = 'KEY' .. math.random(100, 999)
            
            -- Donner une clé
            if GetResourceState('keys') == 'started' then
                local success = exports['keys']:GiveKeys(testPlayer, plate)
                ctx.assert.isTrue(success, 'La clé doit être donnée')
            else
                ctx.skip('Module keys non disponible')
            end
        end
    },
    
    {
        name = 'test_vehicle_garage',
        type = 'integration',
        description = 'Vérifie le système de garage',
        run = function(ctx)
            if GetResourceState('vAvA_garage') == 'started' then
                local garages = exports['vAvA_garage']:GetGarages()
                ctx.assert.isNotNil(garages, 'Les garages doivent être définis')
                ctx.assert.isType(garages, 'table', 'Les garages doivent être une table')
            else
                ctx.skip('Module garage non disponible')
            end
        end
    },
    
    {
        name = 'test_vehicle_persistence',
        type = 'integration',
        description = 'Vérifie la persistance des véhicules',
        run = function(ctx)
            if GetResourceState('vAvA_persist') == 'started' then
                local testPlayer = 'test_player_' .. os.time()
                local plate = 'PERS' .. math.random(100, 999)
                
                -- Sauvegarder un véhicule
                local success = exports['vAvA_persist']:SaveVehicle(plate, {
                    model = 'adder',
                    coords = vector3(0, 0, 0),
                    heading = 0.0
                })
                
                ctx.assert.isTrue(success, 'Le véhicule doit être sauvegardé')
            else
                ctx.skip('Module persist non disponible')
            end
        end
    },
    
    {
        name = 'test_vehicle_damage',
        type = 'unit',
        description = 'Vérifie le système de dégâts',
        run = function(ctx)
            -- Vérifier que les fonctions de dégâts existent
            local hasDamage = pcall(function()
                return exports['vAvA_core']:GetVehicleDamage(1)
            end)
            
            ctx.assert.isTrue(hasDamage, 'Le système de dégâts doit exister')
        end
    }
}
