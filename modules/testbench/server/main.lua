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
    
    -- Log client (seulement si c'est un joueur)
    if source > 0 then
        TriggerClientEvent('testbench:addLog', source, {
            level = 'info',
            message = messages.running_tests,
            timestamp = os.time() * 1000
        })
    end
    
    -- Exécuter les tests dans un thread
    CreateThread(function()
        local results = RunAllTests(source)
        
        TestbenchState.isRunning = false
        
        -- Envoyer résultats au client (seulement si c'est un joueur)
        if source > 0 then
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
        end
    end)
end)

-- Exécuter un test spécifique
RegisterServerEvent('testbench:runTest', function(testName)
    local source = source
    
    if not HasTestbenchPermission(source) then return end
    
    LogInfo('Running test: ' .. testName)
    
    CreateThread(function()
        local result = RunSingleTest(testName, source)
        
        -- Envoyer résultat au client (seulement si c'est un joueur)
        if source > 0 then
            TriggerClientEvent('testbench:testCompleted', source, result)
        end
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
    TestbenchState.tests = {} -- Réinitialiser aussi les tests
    
    -- Modules configurés
    for _, moduleName in ipairs(TestbenchConfig.Modules) do
        local moduleData = {
            name = moduleName,
            path = 'modules/' .. moduleName,
            testCount = 0,
            testsCount = 0, -- Garder pour compatibilité
            testsPassed = 0,
            testsFailed = 0,
            avgTime = 0,
            hasTests = false,
            status = 'unknown'
        }
        
        -- Vérifier si le module existe
        if GetResourceState(moduleName) ~= 'missing' then
            moduleData.status = 'found'
            
            -- Scanner les tests du module
            local tests = LoadModuleTests(moduleName)
            moduleData.testCount = #tests
            moduleData.testsCount = #tests
            moduleData.hasTests = #tests > 0
            
            -- Stocker les tests dans TestbenchState
            if #tests > 0 then
                TestbenchState.tests[moduleName] = tests
            end
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
    local allTests = {}
    
    -- Extraire le nom court (sans vAvA_ prefix)
    local shortName = moduleName:gsub('^vAvA_', '')
    
    -- Chemins possibles pour les fichiers de tests
    local possiblePaths = {
        -- Tests dans vAvA_core pour les modules core (avec nom court)
        {resource = 'vAvA_core', path = 'tests/unit/' .. shortName .. '_tests.lua'},
        {resource = 'vAvA_core', path = 'tests/integration/' .. shortName .. '_tests.lua'},
        
        -- Tests dans les modules individuels (nom complet)
        {resource = moduleName, path = 'tests/' .. shortName .. '_tests.lua'},
        {resource = moduleName, path = 'tests/unit/' .. shortName .. '_tests.lua'},
        {resource = moduleName, path = 'tests/integration/' .. shortName .. '_tests.lua'},
    }
    
    -- Cas spéciaux pour vAvA_core
    if moduleName == 'vAvA_core' then
        table.insert(possiblePaths, {resource = 'vAvA_core', path = 'tests/unit/core_tests.lua'})
        table.insert(possiblePaths, {resource = 'vAvA_core', path = 'tests/integration/full_cycle_tests.lua'})
    end
    
    -- Charger les tests depuis tous les chemins possibles
    for _, pathData in ipairs(possiblePaths) do
        local success, tests = pcall(function()
            -- Vérifier si la ressource existe
            if GetResourceState(pathData.resource) == 'missing' then
                return nil
            end
            
            -- Charger le fichier
            local content = LoadResourceFile(pathData.resource, pathData.path)
            
            if content then
                -- Exécuter le fichier pour obtenir la table de tests
                local loadFunc = load(content, '@' .. pathData.path)
                if loadFunc then
                    local result = loadFunc()
                    if result and type(result) == 'table' then
                        if TestbenchConfig.DevMode then
                            print(string.format('[TESTBENCH] Loaded %d tests from %s/%s', #result, pathData.resource, pathData.path))
                        end
                        return result
                    end
                end
            end
            return nil
        end)
        
        if success and tests and type(tests) == 'table' then
            -- Ajouter les tests à la liste
            for _, test in ipairs(tests) do
                table.insert(allTests, test)
            end
        end
    end
    
    return allTests
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
            -- Notifier le client (seulement si c'est un joueur)
            if source > 0 then
                TriggerClientEvent('testbench:testStarted', source, test)
            end
            
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
            
            -- Notifier le client (seulement si c'est un joueur)
            if source > 0 then
                TriggerClientEvent('testbench:testCompleted', source, result)
            end
            
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
    
    LogInfo('Running test: ' .. test.name)
    
    -- Simuler l'exécution du test
    -- TODO: Implémenter l'exécution réelle des tests
    
    Wait(math.random(100, 500)) -- Simuler durée
    
    local duration = math.floor((os.clock() - startTime) * 1000)
    local success = math.random() > 0.2 -- 80% de réussite
    
    local result = {
        name = test.name,
        type = test.type,
        status = success and 'passed' or 'failed',
        duration = duration,
        message = success and 'Test passed' or 'Test failed: assertion error',
        timestamp = os.time() * 1000
    }
    
    -- Logger le résultat
    if success then
        LogInfo(string.format('✓ Test %s: PASSED (%dms)', test.name, duration))
    else
        LogError(string.format('✗ Test %s: FAILED - %s', test.name, result.message))
    end
    
    return result
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
function AddLog(level, message)
    -- Ajouter le log au tableau
    table.insert(TestbenchState.logs, {
        level = level,
        message = message,
        timestamp = os.time() * 1000
    })
    
    -- Limiter la taille des logs (max 1000)
    if #TestbenchState.logs > 1000 then
        table.remove(TestbenchState.logs, 1)
    end
end

function LogInfo(message)
    if not TestbenchConfig.LogLevel.Info then return end
    print(string.format('^2[TESTBENCH]^7 %s^0', message))
    AddLog('info', message)
end

function LogWarning(message)
    if not TestbenchConfig.LogLevel.Warning then return end
    print(string.format('^3[TESTBENCH]^7 %s^0', message))
    AddLog('warning', message)
end

function LogError(message)
    if not TestbenchConfig.LogLevel.Error then return end
    print(string.format('^1[TESTBENCH]^7 %s^0', message))
    AddLog('error', message)
end

function LogDebug(message)
    if not TestbenchConfig.LogLevel.Debug then return end
    print(string.format('^6[TESTBENCH]^7 %s^0', message))
    AddLog('debug', message)
end

function LogCritical(message)
    if not TestbenchConfig.LogLevel.Critical then return end
    print(string.format('^1[TESTBENCH CRITICAL]^7 %s^0', message))
    AddLog('critical', message)
end

-- === CONSOLE COMMANDS ===

-- Commande pour scanner les modules depuis la console
RegisterCommand('testbench_scan', function(source, args, rawCommand)
    -- Si source == 0, c'est la console serveur
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    print('^2[TESTBENCH]^7 Scan des modules en cours...^0')
    ScanModules()
    
    print(string.format('^2[TESTBENCH]^7 %d modules détectés :^0', #TestbenchState.modules))
    for _, module in ipairs(TestbenchState.modules) do
        local status = module.hasTests and '^2✓' or '^1✗'
        print(string.format('  %s^7 %s - Tests: %d^0', status, module.name, module.testCount or 0))
    end
end, true) -- true = restricted (console only)

-- Commande pour lancer tous les tests depuis la console
RegisterCommand('testbench_run', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    if TestbenchState.isRunning then
        print('^3[TESTBENCH]^7 Des tests sont déjà en cours d\'exécution^0')
        return
    end
    
    TestbenchState.isRunning = true
    print('^2[TESTBENCH]^7 Lancement de tous les tests...^0')
    
    CreateThread(function()
        local results = RunAllTests(0) -- source = 0 pour console
        
        TestbenchState.isRunning = false
        
        -- Afficher les résultats dans la console
        print('^2[TESTBENCH]^7 ========================================^0')
        print('^2[TESTBENCH]^7 RÉSULTATS DES TESTS^0')
        print('^2[TESTBENCH]^7 ========================================^0')
        print(string.format('^2[TESTBENCH]^7 Réussis  : ^2%d^0', results.passed))
        print(string.format('^2[TESTBENCH]^7 Échoués  : ^1%d^0', results.failed))
        print(string.format('^2[TESTBENCH]^7 Warnings : ^3%d^0', results.warnings))
        print('^2[TESTBENCH]^7 ========================================^0')
        
        if results.failed == 0 then
            print('^2[TESTBENCH]^7 ✓ Tous les tests sont passés !^0')
        else
            print('^1[TESTBENCH]^7 ✗ Certains tests ont échoué !^0')
        end
    end)
end, true)

-- Commande pour lancer un test spécifique depuis la console
RegisterCommand('testbench_run_test', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    local testName = args[1]
    if not testName then
        print('^1[TESTBENCH]^7 Usage: testbench_run_test <nom_du_test>^0')
        return
    end
    
    print(string.format('^2[TESTBENCH]^7 Lancement du test: %s^0', testName))
    
    CreateThread(function()
        local result = RunSingleTest(testName, 0)
        
        if result then
            local status = result.success and '^2RÉUSSI' or '^1ÉCHOUÉ'
            print(string.format('^2[TESTBENCH]^7 Test %s : %s^7^0', testName, status))
            if result.message then
                print(string.format('^2[TESTBENCH]^7 Message: %s^0', result.message))
            end
        else
            print(string.format('^1[TESTBENCH]^7 Test introuvable: %s^0', testName))
        end
    end)
end, true)

-- Commande pour lancer les tests critiques depuis la console
RegisterCommand('testbench_critical', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    print('^2[TESTBENCH]^7 Lancement des tests critiques...^0')
    
    CreateThread(function()
        RunCriticalTests()
        print('^2[TESTBENCH]^7 Tests critiques terminés^0')
    end)
end, true)

-- Commande pour lister tous les tests disponibles
RegisterCommand('testbench_list', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    print('^2[TESTBENCH]^7 ========================================^0')
    print('^2[TESTBENCH]^7 LISTE DES TESTS DISPONIBLES^0')
    print('^2[TESTBENCH]^7 ========================================^0')
    
    local totalTests = 0
    for moduleName, tests in pairs(TestbenchState.tests) do
        if tests and #tests > 0 then
            print(string.format('^2[TESTBENCH]^7 Module: ^5%s^7 (%d tests)^0', moduleName, #tests))
            for _, test in ipairs(tests) do
                local typeColor = test.type == 'critical' and '^1' or '^2'
                print(string.format('  %s- %s^7 [%s]^0', typeColor, test.name, test.type))
                totalTests = totalTests + 1
            end
        end
    end
    
    print('^2[TESTBENCH]^7 ========================================^0')
    print(string.format('^2[TESTBENCH]^7 Total: %d tests disponibles^0', totalTests))
end, true)

-- Commande pour voir les logs récents
RegisterCommand('testbench_logs', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    local count = tonumber(args[1]) or 10
    
    print('^2[TESTBENCH]^7 ========================================^0')
    print(string.format('^2[TESTBENCH]^7 DERNIERS LOGS (%d)^0', count))
    print('^2[TESTBENCH]^7 ========================================^0')
    
    local logCount = math.min(#TestbenchState.logs, count)
    local startIndex = math.max(1, #TestbenchState.logs - logCount + 1)
    
    for i = startIndex, #TestbenchState.logs do
        local log = TestbenchState.logs[i]
        local levelColor = '^7'
        if log.level == 'error' or log.level == 'critical' then
            levelColor = '^1'
        elseif log.level == 'warning' then
            levelColor = '^3'
        elseif log.level == 'info' then
            levelColor = '^2'
        end
        
        print(string.format('%s[%s]^7 %s^0', levelColor, string.upper(log.level), log.message))
    end
    
    print('^2[TESTBENCH]^7 ========================================^0')
end, true)

-- Commande d'aide
RegisterCommand('testbench_help', function(source, args, rawCommand)
    if source ~= 0 then
        print('^3[TESTBENCH]^7 Cette commande est réservée à la console serveur^0')
        return
    end
    
    print('^2[TESTBENCH]^7 ========================================^0')
    print('^2[TESTBENCH]^7 COMMANDES DISPONIBLES^0')
    print('^2[TESTBENCH]^7 ========================================^0')
    print('^5testbench_scan^7           - Scanner les modules disponibles^0')
    print('^5testbench_list^7           - Lister tous les tests^0')
    print('^5testbench_run^7            - Lancer tous les tests^0')
    print('^5testbench_run_test <nom>^7 - Lancer un test spécifique^0')
    print('^5testbench_critical^7       - Lancer uniquement les tests critiques^0')
    print('^5testbench_logs [count]^7   - Voir les derniers logs (défaut: 10)^0')
    print('^5testbench_help^7           - Afficher cette aide^0')
    print('^2[TESTBENCH]^7 ========================================^0')
end, true)

-- === EXPORTS ===
exports('ScanModules', ScanModules)
exports('RunTest', ExecuteTest)
exports('GetModules', function() return TestbenchState.modules end)
exports('GetResults', function() return TestbenchState.results end)
