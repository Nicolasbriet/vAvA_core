-- ============================================
-- EXEMPLE DE TEST SIMPLE
-- ============================================
-- Ce fichier montre comment créer des targets de test
-- Copiez ce code dans un autre script ou dans client/main.lua

-- Attendre que vAvA_target soit chargé
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    
    print('[Test vAvA Target] Creating test targets...')
    
    -- TEST 1: Target sur tous les véhicules
    exports.vAvA_target:AddTargetModel({'vehicle'}, {
        {
            icon = 'fas fa-car',
            label = 'Test Véhicule',
            action = function(entity)
                print('Interaction avec véhicule:', entity)
                TriggerEvent('chat:addMessage', {
                    color = {255, 30, 30},
                    args = {"vAvA Target", "Test véhicule réussi!"}
                })
            end
        }
    })
    
    -- TEST 2: Target sur tous les PNJ
    exports.vAvA_target:AddTargetModel({'ped'}, {
        {
            icon = 'fas fa-user',
            label = 'Test PNJ',
            action = function(entity)
                print('Interaction avec PNJ:', entity)
                TriggerEvent('chat:addMessage', {
                    color = {255, 30, 30},
                    args = {"vAvA Target", "Test PNJ réussi!"}
                })
            end
        }
    })
    
    -- TEST 3: Zone de test à La Mesa (centre de la map)
    local zoneCoords = vector3(762.0, -1345.0, 26.5)
    
    exports.vAvA_target:AddTargetZone({
        name = 'test_zone_mesa',
        type = 'sphere',
        coords = zoneCoords,
        radius = 2.0,
        debug = true  -- Afficher la zone en debug
    }, {
        {
            icon = 'fas fa-map-marker',
            label = 'Test Zone La Mesa',
            action = function()
                print('Interaction avec zone La Mesa')
                TriggerEvent('chat:addMessage', {
                    color = {255, 30, 30},
                    args = {"vAvA Target", "Test zone réussi!"}
                })
            end
        }
    })
    
    print('[Test vAvA Target] Test targets created successfully!')
    print('[Test vAvA Target] - Target sur tous les véhicules (orange)')
    print('[Test vAvA Target] - Target sur tous les PNJ (bleu)')
    print('[Test vAvA Target] - Zone de test à La Mesa (violet)')
    print('[Test vAvA Target] Maintenez ALT et visez pour tester')
end)

-- Commande pour téléporter à la zone de test
RegisterCommand('testzone', function()
    local ped = PlayerPedId()
    SetEntityCoords(ped, 762.0, -1345.0, 26.5)
    TriggerEvent('chat:addMessage', {
        color = {255, 30, 30},
        args = {"vAvA Target", "Téléporté à la zone de test La Mesa"}
    })
end, false)
