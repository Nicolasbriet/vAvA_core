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
            -- Vérifier que l'export existe
            local hasExport = pcall(function()
                return exports['vAvA_core']:SpawnVehicle
            end)
            
            if not hasExport then
                ctx.skip('Export SpawnVehicle non disponible')
                return
            end
            
            -- Test de l'existence de la fonction uniquement
            ctx.assert.isType(exports['vAvA_core'].SpawnVehicle, 'function', 'SpawnVehicle doit être une fonction')
        end
    },
    
    {
        name = 'test_vehicle_ownership',
        type = 'unit',
        description = 'Vérifie la propriété des véhicules',
        run = function(ctx)
            -- Vérifier que l'export existe
            local hasExport = pcall(function()
                return exports['vAvA_core']:SetVehicleOwner
            end)
            
            if not hasExport then
                ctx.skip('Export SetVehicleOwner non disponible')
                return
            end
            
            -- Test de l'existence de la fonction uniquement
            ctx.assert.isType(exports['vAvA_core'].SetVehicleOwner, 'function', 'SetVehicleOwner doit être une fonction')
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
            local state = GetResourceState('vAvA_garage')
            
            if state ~= 'started' and state ~= 'starting' then
                ctx.skip('Module garage non disponible')
                return
            end
            
            -- Vérifier que l'export existe
            local hasExport = pcall(function()
                return exports['vAvA_garage']:GetGarages
            end)
            
            if not hasExport then
                ctx.skip('Export GetGarages non disponible')
                return
            end
            
            local garages = exports['vAvA_garage']:GetGarages()
            ctx.assert.isType(garages, 'table', 'Les garages doivent être une table')
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
            local hasExport = pcall(function()
                return exports['vAvA_core']:GetVehicleDamage
            end)
            
            if not hasExport then
                ctx.skip('Export GetVehicleDamage non disponible')
                return
            end
            
            ctx.assert.isType(exports['vAvA_core'].GetVehicleDamage, 'function', 'GetVehicleDamage doit être une fonction')
        end
    }
}
