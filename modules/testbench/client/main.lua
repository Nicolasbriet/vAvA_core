--[[
    vAvA_testbench - Client Script
    Interface utilisateur et commandes
]]

local isOpen = false

-- Commande pour ouvrir le testbench (admin seulement)
RegisterCommand('testbench', function(source, args, rawCommand)
    -- Vérifier permissions
    TriggerServerEvent('testbench:checkPermission')
end, false)

-- Ouvrir l'interface
RegisterNetEvent('testbench:open', function()
    if not isOpen then
        isOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'show'
        })
    end
end)

-- Fermer l'interface
RegisterNetEvent('testbench:close', function()
    if isOpen then
        isOpen = false
        SetNuiFocus(false, false)
        SendNUIMessage({
            action = 'hide'
        })
    end
end)

-- Message d'erreur d'accès
RegisterNetEvent('testbench:accessDenied', function()
    TriggerEvent('chat:addMessage', {
        color = {255, 30, 30},
        multiline = true,
        args = {"vAvA Testbench", "Accès refusé - Permissions admin requises"}
    })
end)

-- Mettre à jour les modules détectés
RegisterNetEvent('testbench:updateModules', function(modules)
    SendNUIMessage({
        action = 'updateModules',
        modules = modules
    })
end)

-- Notifier le début d'un test
RegisterNetEvent('testbench:testStarted', function(testData)
    SendNUIMessage({
        action = 'testStarted',
        test = testData
    })
end)

-- Notifier la fin d'un test
RegisterNetEvent('testbench:testCompleted', function(result)
    SendNUIMessage({
        action = 'testCompleted',
        result = result
    })
end)

-- Ajouter un log
RegisterNetEvent('testbench:addLog', function(logData)
    SendNUIMessage({
        action = 'addLog',
        log = logData
    })
end)

-- Mettre à jour les statistiques
RegisterNetEvent('testbench:updateStats', function(stats)
    SendNUIMessage({
        action = 'updateStats',
        stats = stats
    })
end)

-- === NUI CALLBACKS ===

-- Fermer l'interface
RegisterNUICallback('testbench:close', function(data, cb)
    TriggerEvent('testbench:close')
    cb('ok')
end)

-- Scanner les modules
RegisterNUICallback('testbench:scanModules', function(data, cb)
    TriggerServerEvent('testbench:scanModules')
    cb('ok')
end)

-- Obtenir les données initiales
RegisterNUICallback('testbench:getInitialData', function(data, cb)
    -- Demander au serveur
    TriggerServerEvent('testbench:requestInitialData')
    
    -- Le serveur répondra via un event qui mettra à jour l'UI
    cb('ok')
end)

-- Obtenir les détails d'un module
RegisterNUICallback('testbench:getModuleDetails', function(data, cb)
    TriggerServerEvent('testbench:getModuleDetails', data.moduleName)
    cb('ok')
end)

-- Exécuter tous les tests
RegisterNUICallback('testbench:runAllTests', function(data, cb)
    TriggerServerEvent('testbench:runAllTests')
    cb('ok')
end)

-- Exécuter un test spécifique
RegisterNUICallback('testbench:runTest', function(data, cb)
    TriggerServerEvent('testbench:runTest', data.testName)
    cb('ok')
end)

-- Arrêter les tests
RegisterNUICallback('testbench:stopTests', function(data, cb)
    TriggerServerEvent('testbench:stopTests')
    cb('ok')
end)

-- Exécuter un scénario
RegisterNUICallback('testbench:runScenario', function(data, cb)
    TriggerServerEvent('testbench:runScenario', data.scenario)
    cb('ok')
end)

-- Exporter les résultats
RegisterNUICallback('testbench:export', function(data, cb)
    TriggerServerEvent('testbench:exportResults', data.data)
    cb('ok')
end)

-- === EVENTS DE TEST (pour les tests unitaires) ===

-- Callback pour tester le système de callbacks vAvA
RegisterNetEvent('testbench:test:callback', function(testData)
    print('[TESTBENCH] Test callback reçu:', json.encode(testData))
end)

-- Fonction utilitaire pour les tests
function TestbenchClientUtils()
    return {
        -- Obtenir les coordonnées du joueur
        GetPlayerCoords = function()
            return GetEntityCoords(PlayerPedId())
        end,
        
        -- Obtenir le véhicule du joueur
        GetPlayerVehicle = function()
            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) then
                return GetVehiclePedIsIn(ped, false)
            end
            return 0
        end,
        
        -- Obtenir les infos du joueur
        GetPlayerInfo = function()
            return {
                serverId = GetPlayerServerId(PlayerId()),
                ped = PlayerPedId(),
                coords = GetEntityCoords(PlayerPedId()),
                health = GetEntityHealth(PlayerPedId())
            }
        end,
        
        -- Simuler une action
        SimulateAction = function(actionType)
            print('[TESTBENCH] Simulation action:', actionType)
            return true
        end
    }
end

-- Exporter les utilitaires
exports('GetTestUtils', TestbenchClientUtils)

-- === CONSOLE LOGS ===
CreateThread(function()
    if TestbenchConfig and TestbenchConfig.DevMode then
        print('^2[vAvA TESTBENCH]^7 Client chargé - Tapez /testbench pour ouvrir^0')
    end
end)
