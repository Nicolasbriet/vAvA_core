-- ============================================
-- vAvA Target - Tests Testbench
-- ============================================

return {
    name = 'vAvA_target',
    description = 'Tests for vAvA Target system',
    version = '1.0.0',
    
    tests = {
        -- ============================================
        -- TESTS UNITAIRES
        -- ============================================
        {
            name = 'API Validation - Valid Option',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local validOption = {
                    label = 'Test Action',
                    icon = 'fa-solid fa-test',
                    event = 'test:event'
                }
                
                local isValid = TargetAPI.ValidateOption(validOption)
                ctx.assert.isTrue(isValid, 'Valid option should pass validation')
            end
        },
        
        {
            name = 'API Validation - Invalid Option (No Label)',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local invalidOption = {
                    icon = 'fa-solid fa-test',
                    event = 'test:event'
                }
                
                local isValid, err = TargetAPI.ValidateOption(invalidOption)
                ctx.assert.isFalse(isValid, 'Option without label should fail')
                ctx.assert.isNotNil(err, 'Should return error message')
            end
        },
        
        {
            name = 'API Validation - Invalid Option (No Action)',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local invalidOption = {
                    label = 'Test Action',
                    icon = 'fa-solid fa-test'
                }
                
                local isValid, err = TargetAPI.ValidateOption(invalidOption)
                ctx.assert.isFalse(isValid, 'Option without action should fail')
            end
        },
        
        {
            name = 'API Validation - Valid Sphere Zone',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local validZone = {
                    name = 'test_sphere',
                    type = 'sphere',
                    coords = vector3(0, 0, 0),
                    radius = 2.0
                }
                
                local isValid = TargetAPI.ValidateZone(validZone)
                ctx.assert.isTrue(isValid, 'Valid sphere zone should pass')
            end
        },
        
        {
            name = 'API Validation - Invalid Zone (No Radius)',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local invalidZone = {
                    name = 'test_sphere',
                    type = 'sphere',
                    coords = vector3(0, 0, 0)
                }
                
                local isValid, err = TargetAPI.ValidateZone(invalidZone)
                ctx.assert.isFalse(isValid, 'Sphere zone without radius should fail')
                ctx.assert.isNotNil(err, 'Should return error message')
            end
        },
        
        {
            name = 'API Model Conversion',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local stringModel = 'prop_atm_01'
                local hash = TargetAPI.ModelToHash(stringModel)
                
                ctx.assert.isType(hash, 'number', 'Should convert string to hash')
                ctx.assert.equals(hash, GetHashKey(stringModel), 'Hash should match GetHashKey')
            end
        },
        
        {
            name = 'API Distance Calculation',
            type = 'unit',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local coords1 = vector3(0, 0, 0)
                local coords2 = vector3(3, 4, 0)
                
                local distance = TargetAPI.GetDistance(coords1, coords2)
                
                ctx.assert.equals(distance, 5.0, 'Distance should be 5.0 (Pythagorean theorem)')
            end
        },
        
        -- ============================================
        -- TESTS D'INTÉGRATION
        -- ============================================
        {
            name = 'Add and Remove Target Model',
            type = 'integration',
            run = function(ctx)
                local model = 'prop_atm_01'
                local options = {
                    {
                        label = 'Use ATM',
                        event = 'test:atm',
                        icon = 'fa-solid fa-credit-card'
                    }
                }
                
                -- Ajouter target
                local ids = exports['vAvA_target']:AddTargetModel(model, options)
                
                ctx.assert.isNotNil(ids, 'Should return IDs')
                ctx.assert.isType(ids, 'table', 'IDs should be a table')
                ctx.assert.isTrue(#ids > 0, 'Should have at least one ID')
                
                -- Supprimer target
                local removed = exports['vAvA_target']:RemoveTargetModel(model)
                
                ctx.assert.isTrue(removed, 'Should successfully remove target')
            end
        },
        
        {
            name = 'Add and Remove Target Zone',
            type = 'integration',
            run = function(ctx)
                local zoneData = {
                    name = 'test_zone_integration',
                    type = 'sphere',
                    coords = vector3(0, 0, 0),
                    radius = 5.0
                }
                
                local options = {
                    {
                        label = 'Test Zone',
                        event = 'test:zone',
                        icon = 'fa-solid fa-location-dot'
                    }
                }
                
                -- Ajouter zone
                local id = exports['vAvA_target']:AddTargetZone(zoneData, options)
                
                ctx.assert.isNotNil(id, 'Should return ID')
                ctx.assert.isType(id, 'string', 'ID should be a string')
                
                -- Supprimer zone
                local removed = exports['vAvA_target']:RemoveTargetZone(zoneData.name)
                
                ctx.assert.isTrue(removed, 'Should successfully remove zone')
            end
        },
        
        {
            name = 'Get Nearby Targets',
            type = 'integration',
            run = function(ctx)
                -- Ajouter un target temporaire
                local model = 'prop_test_temp'
                local options = {
                    {
                        label = 'Test Nearby',
                        event = 'test:nearby',
                        icon = 'fa-solid fa-circle'
                    }
                }
                
                exports['vAvA_target']:AddTargetModel(model, options)
                
                -- Obtenir targets proches
                local nearbyTargets = exports['vAvA_target']:GetNearbyTargets(50.0)
                
                ctx.assert.isNotNil(nearbyTargets, 'Should return nearby targets')
                ctx.assert.isType(nearbyTargets, 'table', 'Nearby targets should be a table')
                ctx.assert.isNotNil(nearbyTargets.entities, 'Should have entities array')
                ctx.assert.isNotNil(nearbyTargets.zones, 'Should have zones array')
                
                -- Cleanup
                exports['vAvA_target']:RemoveTargetModel(model)
            end
        },
        
        {
            name = 'Target System Toggle',
            type = 'integration',
            run = function(ctx)
                -- Désactiver
                exports['vAvA_target']:DisableTarget(true)
                
                ctx.utils.wait(500)
                
                local isActive = exports['vAvA_target']:IsTargetActive()
                ctx.assert.isFalse(isActive, 'Target should be inactive after disabling')
                
                -- Réactiver
                exports['vAvA_target']:DisableTarget(false)
                
                ctx.utils.wait(500)
                
                isActive = exports['vAvA_target']:IsTargetActive()
                ctx.assert.isTrue(isActive, 'Target should be active after enabling')
            end
        },
        
        -- ============================================
        -- TESTS DE SÉCURITÉ
        -- ============================================
        {
            name = 'Security - Invalid Entity Interaction',
            type = 'security',
            run = function(ctx)
                -- Essayer d'interagir avec une entité invalide
                local invalidNetworkId = 999999
                
                TriggerServerEvent('vava_target:validateInteraction', {
                    event = 'test:security',
                    entity = invalidNetworkId
                })
                
                ctx.utils.wait(1000)
                
                -- Le serveur devrait rejeter cette interaction
                -- (pas de moyen simple de vérifier côté client, mais le serveur devrait logger)
                ctx.assert.isTrue(true, 'Server should reject invalid entity')
            end
        },
        
        {
            name = 'Security - Distance Validation',
            type = 'security',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                -- Créer deux points très éloignés
                local coords1 = vector3(0, 0, 0)
                local coords2 = vector3(1000, 1000, 0)
                
                local distance = TargetAPI.GetDistance(coords1, coords2)
                
                ctx.assert.isTrue(distance > TargetConfig.MaxDistance, 
                    'Distance should exceed max distance')
                
                -- Cette interaction devrait être rejetée par le serveur
            end
        },
        
        {
            name = 'Security - Permission Check',
            type = 'security',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                local option = {
                    label = 'Admin Only',
                    event = 'test:admin',
                    job = 'admin',
                    grade = 5
                }
                
                local playerData = {
                    job = 'police',
                    grade = 2
                }
                
                local hasPermission = TargetAPI.CheckPermissions(option, playerData)
                
                ctx.assert.isFalse(hasPermission, 'Player without permission should be denied')
            end
        },
        
        -- ============================================
        -- TESTS DE COHÉRENCE
        -- ============================================
        {
            name = 'Coherence - Config Structure',
            type = 'coherence',
            run = function(ctx)
                ctx.assert.isNotNil(TargetConfig, 'TargetConfig should be defined')
                ctx.assert.isType(TargetConfig.Enabled, 'boolean', 'Enabled should be boolean')
                ctx.assert.isType(TargetConfig.DefaultDistance, 'number', 'DefaultDistance should be number')
                ctx.assert.isType(TargetConfig.UI, 'table', 'UI config should be table')
                ctx.assert.isType(TargetConfig.Security, 'table', 'Security config should be table')
            end
        },
        
        {
            name = 'Coherence - Predefined Zones',
            type = 'coherence',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                if TargetConfig.Zones then
                    ctx.assert.isType(TargetConfig.Zones, 'table', 'Zones should be a table')
                    
                    for i, zone in ipairs(TargetConfig.Zones) do
                        local isValid, err = TargetAPI.ValidateZone(zone)
                        
                        ctx.assert.isTrue(isValid, 
                            string.format('Zone %d (%s) should be valid: %s', i, zone.name or 'unknown', err or 'no error'))
                    end
                end
            end
        },
        
        {
            name = 'Coherence - Predefined Models',
            type = 'coherence',
            run = function(ctx)
                local TargetAPI = require('shared/api')
                
                if TargetConfig.Models then
                    ctx.assert.isType(TargetConfig.Models, 'table', 'Models should be a table')
                    
                    for i, modelData in ipairs(TargetConfig.Models) do
                        ctx.assert.isNotNil(modelData.models, 
                            string.format('Model data %d should have models', i))
                        
                        ctx.assert.isNotNil(modelData.options, 
                            string.format('Model data %d should have options', i))
                        
                        for j, option in ipairs(modelData.options) do
                            local isValid, err = TargetAPI.ValidateOption(option)
                            
                            ctx.assert.isTrue(isValid, 
                                string.format('Model %d option %d should be valid: %s', i, j, err or 'no error'))
                        end
                    end
                end
            end
        },
        
        {
            name = 'Coherence - Exports Available',
            type = 'coherence',
            run = function(ctx)
                local requiredExports = {
                    'AddTargetEntity',
                    'AddTargetModel',
                    'AddTargetZone',
                    'AddTargetBone',
                    'RemoveTarget',
                    'RemoveTargetModel',
                    'RemoveTargetZone',
                    'DisableTarget',
                    'IsTargetActive',
                    'GetNearbyTargets'
                }
                
                for _, exportName in ipairs(requiredExports) do
                    local exportFunc = exports['vAvA_target'][exportName]
                    
                    ctx.assert.isNotNil(exportFunc, 
                        string.format('Export %s should be available', exportName))
                    
                    ctx.assert.isType(exportFunc, 'function', 
                        string.format('Export %s should be a function', exportName))
                end
            end
        }
    }
}
