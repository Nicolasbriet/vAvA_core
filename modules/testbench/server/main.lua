--[[
    vAvA_testbench - Server Main
    Gestion principale du testbench
]]

-- État global
TestbenchState = {
    modules = {},
    tests = {},
    runningTests = {},
    results = {},
    logs = {},
    isRunning = false
}

-- Messages
local messages = TestbenchMessages[TestbenchConfig.Language] or TestbenchMessages['fr']

-- === INITIALIZATION ===
CreateThread(function()
    print('^2[vAvA TESTBENCH]^7 Initialisation...^0')
    
    -- Charger la configuration
    if TestbenchConfig.DevMode then
        print('[TESTBENCH] Mode développement activé')
    end
    
    -- Scanner les modules au démarrage si activé
    if TestbenchConfig.AutoStart.Enabled then
        Wait(TestbenchConfig.AutoStart.Delay)
        print('[TESTBENCH] Auto-scan des modules...')
        ScanModules()
        
        if TestbenchConfig.AutoStart.CriticalOnly then
            print('[TESTBENCH] Auto-test des tests critiques...')
            RunCriticalTests()
        end
    end
    
    print(string.format('^2[vAvA TESTBENCH]^7 %s^0', messages.testbench_ready))
end)

-- === PERMISSIONS ===
function HasTestbenchPermission(source)
    if not TestbenchConfig.AdminOnly then
        return true
    end
    
    -- Vérifier ACE permission
    if IsPlayerAceAllowed(source, TestbenchConfig.AllowedACE) then
        return true
    end
    
    -- Vérifier si c'est un admin vAvA (si le système existe)
    if GetResourceState('vAvA_core') == 'started' then
        local hasPermission = exports['vAvA_core']:HasPermission(source, 'admin')
        if hasPermission then
            return true
        end
    end
    
    return false
end

-- === EVENTS ===

-- Vérifier permission
RegisterServerEvent('testbench:checkPermission', function()
    local source = source
    
    if HasTestbenchPermission(source) then
        TriggerClientEvent('testbench:open', source)
        LogInfo('Player ' .. GetPlayerName(source) .. ' opened testbench')
    else
        TriggerClientEvent('testbench:accessDenied', source)
        LogWarning('Player ' .. GetPlayerName(source) .. ' tried to access testbench without permission')
    end
end)

-- Demander les données initiales
RegisterServerEvent('testbench:requestInitialData', function()
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    -- Envoyer les modules
    TriggerClientEvent('testbench:updateModules', source, TestbenchState.modules)
end)

-- Scanner les modules
RegisterServerEvent('testbench:scanModules', function()
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    LogInfo('Scanning modules...')
    ScanModules()
    
    -- Envoyer les modules au client
    TriggerClientEvent('testbench:updateModules', source, TestbenchState.modules)
    
    -- Log
    TriggerClientEvent('testbench:addLog', source, {
        level = 'info',
        message = string.format(messages.module_detected, #TestbenchState.modules),
        timestamp = os.time() * 1000
    })
end)

-- Obtenir les détails d'un module
RegisterServerEvent('testbench:getModuleDetails', function(moduleName)
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    local module = GetModuleByName(moduleName)
    if not module then return end
    
    -- Charger les tests du module
    local tests = LoadModuleTests(moduleName)
    
    TriggerClientEvent('testbench:updateModules', source, tests)
end)

-- Exécuter tous les tests
RegisterServerEvent('testbench:runAllTests', function()
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    if TestbenchState.isRunning then
        LogWarning('Tests already running')
        return
    end
    
    TestbenchState.isRunning = true
    LogInfo('Running all tests...')
    
    -- Log client
    TriggerClientEvent('testbench:addLog', source, {
        level = 'info',
        message = messages.running_tests,
        timestamp = os.time() * 1000
    })
    
    -- Exécuter les tests dans un thread
    CreateThread(function()
        local results = RunAllTests(source)
        
        TestbenchState.isRunning = false
        
        -- Envoyer résultats au client
        TriggerClientEvent('testbench:updateStats', source, results)
        
        -- Log final
        local logLevel = results.failed > 0 and 'error' or 'info'
        local logMessage = results.failed > 0 
            and string.format(messages.some_tests_failed, results.failed)
            or messages.all_tests_passed
        
        TriggerClientEvent('testbench:addLog', source, {
            level = logLevel,
            message = logMessage,
            timestamp = os.time() * 1000
        })
    end)
end)

-- Exécuter un test spécifique
RegisterServerEvent('testbench:runTest', function(testName)
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    LogInfo('Running test: ' .. testName)
    
    CreateThread(function()
        local result = RunSingleTest(testName, source)
        
        TriggerClientEvent('testbench:testCompleted', source, result)
    end)
end)

-- Arrêter les tests
RegisterServerEvent('testbench:stopTests', function()
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    TestbenchState.isRunning = false
    TestbenchState.runningTests = {}
    
    LogWarning('Tests stopped by user')
    
    TriggerClientEvent('testbench:addLog', source, {
        level = 'warning',
        message = 'Tests arrêtés',
        timestamp = os.time() * 1000
    })
end)

-- Exécuter un scénario
RegisterServerEvent('testbench:runScenario', function(scenarioName)
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    LogInfo('Running scenario: ' .. scenarioName)
    
    CreateThread(function()
        local result = RunScenario(scenarioName, source)
        
        TriggerClientEvent('testbench:updateStats', source, result)
    end)
end)

-- Exporter les résultats
RegisterServerEvent('testbench:exportResults', function(dataJson)
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    if not TestbenchConfig.Export.Enabled then
        LogWarning('Export disabled in config')
        return
    end
    
    local data = json.decode(dataJson)
    if not data then
        LogError('Failed to decode export data')
        return
    end
    
    -- Sauvegarder dans un fichier
    local filename = string.format('testbench_results_%s.json', os.date('%Y%m%d_%H%M%S'))
    local filepath = TestbenchConfig.Export.SavePath .. filename
    
    SaveResourceFile(GetCurrentResourceName(), filepath, dataJson, -1)
    
    LogInfo('Results exported to: ' .. filepath)
    
    TriggerClientEvent('testbench:addLog', source, {
        level = 'info',
        message = 'Résultats exportés: ' .. filename,
        timestamp = os.time() * 1000
    })
end)

-- === SCANNER DE MODULES ===
function ScanModules()
    TestbenchState.modules = {}
    
    -- Modules configurés
    for _, moduleName in ipairs(TestbenchConfig.Modules) do
        local moduleData = {
            name = moduleName,
            path = 'modules/' .. moduleName,
            testsCount = 0,
            testsPassed = 0,
            testsFailed = 0,
            avgTime = 0,
            status = 'unknown'
        }
        
        -- Vérifier si le module existe
        if GetResourceState(moduleName) ~= 'missing' then
            moduleData.status = 'found'
            
            -- Scanner les tests du module
            local tests = LoadModuleTests(moduleName)
            moduleData.testsCount = #tests
        end
        
        table.insert(TestbenchState.modules, moduleData)
    end
    
    LogInfo(string.format('Scanned %d modules', #TestbenchState.modules))
    
    return TestbenchState.modules
end

function GetModuleByName(name)
    for _, module in ipairs(TestbenchState.modules) do
        if module.name == name then
            return module
        end
    end
    return nil
end

-- === CHARGEMENT DES TESTS ===
function LoadModuleTests(moduleName)
    local tests = {}
    
    -- Chemin vers les tests du module
    local testPath = string.format('modules/testbench/tests/unit/%s_tests.lua', moduleName)
    
    -- Pour l'instant, retourner des tests de démo
    -- TODO: Implémenter le chargement dynamique des tests
    
    table.insert(tests, {
        name = moduleName .. '_basic_test',
        type = 'unit',
        description = 'Test basique pour ' .. moduleName,
        status = 'pending',
        critical = true
    })
    
    return tests
end

-- === EXÉCUTION DES TESTS ===
function RunAllTests(source)
    local results = {
        passed = 0,
        failed = 0,
        warnings = 0,
        total = 0
    }
    
    for _, module in ipairs(TestbenchState.modules) do
        local tests = LoadModuleTests(module.name)
        
        for _, test in ipairs(tests) do
            -- Notifier le client
            TriggerClientEvent('testbench:testStarted', source, test)
            
            -- Exécuter le test
            local result = ExecuteTest(test)
            
            -- Mettre à jour les résultats
            results.total = results.total + 1
            if result.status == 'passed' then
                results.passed = results.passed + 1
            elseif result.status == 'failed' then
                results.failed = results.failed + 1
            else
                results.warnings = results.warnings + 1
            end
            
            -- Notifier le client
            TriggerClientEvent('testbench:testCompleted', source, result)
            
            Wait(100) -- Petit délai entre les tests
        end
    end
    
    return results
end

function RunSingleTest(testName, source)
    -- Trouver le test
    local test = { name = testName, type = 'unit', description = 'Test ' .. testName }
    
    -- Notifier le client
    TriggerClientEvent('testbench:testStarted', source, test)
    
    -- Exécuter
    local result = ExecuteTest(test)
    
    return result
end

function ExecuteTest(test)
    local startTime = os.clock()
    
    -- Simuler l'exécution du test
    -- TODO: Implémenter l'exécution réelle des tests
    
    Wait(math.random(100, 500)) -- Simuler durée
    
    local duration = math.floor((os.clock() - startTime) * 1000)
    local success = math.random() > 0.2 -- 80% de réussite
    
    return {
        name = test.name,
        type = test.type,
        status = success and 'passed' or 'failed',
        duration = duration,
        message = success and 'Test passed' or 'Test failed: assertion error',
        timestamp = os.time() * 1000
    }
end

function RunCriticalTests()
    -- Exécuter uniquement les tests critiques au démarrage
    local criticalTests = {}
    
    for _, scenario in ipairs(TestbenchConfig.Scenarios) do
        if scenario.critical then
            table.insert(criticalTests, scenario)
        end
    end
    
    LogInfo(string.format('Running %d critical tests...', #criticalTests))
    
    -- TODO: Implémenter l'exécution des tests critiques
end

function RunScenario(scenarioName, source)
    LogInfo('Running scenario: ' .. scenarioName)
    
    -- Trouver le scénario
    local scenario = nil
    for _, s in ipairs(TestbenchConfig.Scenarios) do
        if s.name == scenarioName then
            scenario = s
            break
        end
    end
    
    if not scenario then
        LogError('Scenario not found: ' .. scenarioName)
        return { passed = 0, failed = 1, warnings = 0 }
    end
    
    -- Exécuter les étapes du scénario
    local results = { passed = 0, failed = 0, warnings = 0 }
    
    for _, step in ipairs(scenario.steps) do
        TriggerClientEvent('testbench:addLog', source, {
            level = 'info',
            message = 'Étape: ' .. step,
            timestamp = os.time() * 1000
        })
        
        -- TODO: Exécuter l'étape réelle
        Wait(500)
        
        results.passed = results.passed + 1
    end
    
    return results
end

-- === LOGS ===
function LogInfo(message)
    if not TestbenchConfig.LogLevel.Info then return end
    print(string.format('^2[TESTBENCH]^7 %s^0', message))
end

function LogWarning(message)
    if not TestbenchConfig.LogLevel.Warning then return end
    print(string.format('^3[TESTBENCH]^7 %s^0', message))
end

function LogError(message)
    if not TestbenchConfig.LogLevel.Error then return end
    print(string.format('^1[TESTBENCH]^7 %s^0', message))
end

function LogDebug(message)
    if not TestbenchConfig.LogLevel.Debug then return end
    print(string.format('^6[TESTBENCH]^7 %s^0', message))
end

-- === EXPORTS ===
exports('ScanModules', ScanModules)
exports('RunTest', ExecuteTest)
exports('GetModules', function() return TestbenchState.modules end)
exports('GetResults', function() return TestbenchState.results end)
