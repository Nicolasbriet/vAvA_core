--[[
    vAvA_testbench - Scanner
    Détection automatique et adaptative des modules
]]

Scanner = {}

-- Cache des modules scannés
local cachedModules = {}
local lastScanTime = 0
local CACHE_DURATION = 60000 -- 60 secondes

-- === SCAN PRINCIPAL ===
function Scanner.ScanAll()
    -- Vérifier le cache
    if TestbenchConfig.Performance.CacheResults then
        local now = GetGameTimer()
        if now - lastScanTime < CACHE_DURATION and #cachedModules > 0 then
            return cachedModules
        end
    end
    
    local modules = {}
    
    -- Scanner les ressources FiveM
    local numResources = GetNumResources()
    
    for i = 0, numResources - 1 do
        local resourceName = GetResourceByFindIndex(i)
        
        -- Filtrer les ressources vAvA
        if resourceName and (
            string.match(resourceName, '^vAvA_') or 
            string.match(resourceName, '^vava_') or
            resourceName == 'vAvA_core'
        ) then
            local moduleData = Scanner.AnalyzeResource(resourceName)
            if moduleData then
                table.insert(modules, moduleData)
            end
        end
    end
    
    -- Mettre en cache
    cachedModules = modules
    lastScanTime = GetGameTimer()
    
    return modules
end

-- === ANALYSE D'UNE RESSOURCE ===
function Scanner.AnalyzeResource(resourceName)
    local state = GetResourceState(resourceName)
    
    if state == 'missing' or state == 'unknown' then
        return nil
    end
    
    local moduleData = {
        name = resourceName,
        path = GetResourcePath(resourceName),
        state = state,
        type = Scanner.DetectModuleType(resourceName),
        files = {},
        dependencies = {},
        exports = {},
        events = {},
        commands = {},
        testsCount = 0,
        testsPassed = 0,
        testsFailed = 0,
        coverage = 0,
        lastTestTime = 0,
        metadata = {}
    }
    
    -- Analyser le manifest
    moduleData.metadata = Scanner.AnalyzeManifest(resourceName)
    
    -- Détecter les fichiers
    moduleData.files = Scanner.DetectFiles(resourceName)
    
    -- Détecter les exports
    moduleData.exports = Scanner.DetectExports(resourceName)
    
    -- Compter les tests disponibles
    moduleData.testsCount = Scanner.CountAvailableTests(resourceName)
    
    return moduleData
end

-- === DÉTECTION DU TYPE DE MODULE ===
function Scanner.DetectModuleType(resourceName)
    -- Core
    if resourceName == 'vAvA_core' then
        return 'core'
    end
    
    -- Modules spécifiques
    local moduleTypes = {
        inventory = 'gameplay',
        jobs = 'economy',
        economy = 'economy',
        shops = 'economy',
        vehicles = 'gameplay',
        garage = 'gameplay',
        concess = 'economy',
        creator = 'character',
        player = 'character',
        chat = 'social',
        housing = 'gameplay',
        admin = 'utility',
        utils = 'utility',
        persist = 'system',
        keys = 'gameplay',
        sit = 'gameplay',
        loadingscreen = 'ui'
    }
    
    for moduleName, moduleType in pairs(moduleTypes) do
        if string.find(resourceName:lower(), moduleName:lower()) then
            return moduleType
        end
    end
    
    return 'unknown'
end

-- === ANALYSE DU MANIFEST ===
function Scanner.AnalyzeManifest(resourceName)
    local metadata = {
        name = resourceName,
        author = GetResourceMetadata(resourceName, 'author', 0) or 'Unknown',
        version = GetResourceMetadata(resourceName, 'version', 0) or '0.0.0',
        description = GetResourceMetadata(resourceName, 'description', 0) or '',
        fx_version = GetResourceMetadata(resourceName, 'fx_version', 0) or 'unknown',
        game = GetResourceMetadata(resourceName, 'game', 0) or 'gta5'
    }
    
    return metadata
end

-- === DÉTECTION DES FICHIERS ===
function Scanner.DetectFiles(resourceName)
    local files = {
        client = {},
        server = {},
        shared = {},
        html = {},
        config = {}
    }
    
    -- Client scripts
    local clientScriptCount = GetNumResourceMetadata(resourceName, 'client_script')
    for i = 0, clientScriptCount - 1 do
        local script = GetResourceMetadata(resourceName, 'client_script', i)
        if script then
            table.insert(files.client, script)
        end
    end
    
    -- Server scripts
    local serverScriptCount = GetNumResourceMetadata(resourceName, 'server_script')
    for i = 0, serverScriptCount - 1 do
        local script = GetResourceMetadata(resourceName, 'server_script', i)
        if script then
            table.insert(files.server, script)
        end
    end
    
    -- Shared scripts
    local sharedScriptCount = GetNumResourceMetadata(resourceName, 'shared_script')
    for i = 0, sharedScriptCount - 1 do
        local script = GetResourceMetadata(resourceName, 'shared_script', i)
        if script then
            table.insert(files.shared, script)
        end
    end
    
    -- UI page
    local uiPage = GetResourceMetadata(resourceName, 'ui_page', 0)
    if uiPage then
        table.insert(files.html, uiPage)
    end
    
    return files
end

-- === DÉTECTION DES EXPORTS ===
function Scanner.DetectExports(resourceName)
    local exports = {}
    
    -- Les exports ne peuvent pas être énumérés directement
    -- On peut seulement vérifier les exports connus
    
    -- Exports standards vAvA
    local standardExports = {
        'GetFramework',
        'GetPlayer',
        'GetPlayers',
        'RegisterCallback',
        'TriggerCallback',
        'ShowNotification',
        'GetConfig',
        'HasPermission'
    }
    
    for _, exportName in ipairs(standardExports) do
        local success, result = pcall(function()
            return exports[resourceName][exportName]
        end)
        
        if success and result ~= nil then
            table.insert(exports, {
                name = exportName,
                type = type(result)
            })
        end
    end
    
    return exports
end

-- === COMPTAGE DES TESTS DISPONIBLES ===
function Scanner.CountAvailableTests(resourceName)
    local count = 0
    
    -- Chemins possibles pour les tests
    local testPaths = {
        -- Tests dans vAvA_core/tests/
        {resource = 'vAvA_core', path = 'tests/unit/core_tests.lua', module = 'vAvA_core'},
        {resource = 'vAvA_core', path = 'tests/unit/economy_tests.lua', module = 'economy'},
        {resource = 'vAvA_core', path = 'tests/unit/inventory_tests.lua', module = 'inventory'},
        {resource = 'vAvA_core', path = 'tests/unit/jobs_tests.lua', module = 'jobs'},
        {resource = 'vAvA_core', path = 'tests/unit/vehicles_tests.lua', module = 'vehicles'},
        {resource = 'vAvA_core', path = 'tests/integration/full_cycle_tests.lua', module = 'vAvA_core'},
        -- Tests dans le module testbench
        {resource = 'vAvA_testbench', path = 'tests/unit/example_tests.lua', module = 'vAvA_testbench'}
    }
    
    -- Vérifier si ce module a des tests
    for _, testPath in ipairs(testPaths) do
        if testPath.module == resourceName then
            -- Essayer de charger le fichier
            local success, tests = pcall(function()
                local corePath = GetResourcePath('vAvA_core')
                local testbenchPath = GetResourcePath('vAvA_testbench')
                local filePath
                
                if testPath.resource == 'vAvA_core' then
                    filePath = corePath .. '/' .. testPath.path
                else
                    filePath = testbenchPath .. '/' .. testPath.path
                end
                
                return LoadResourceFile(testPath.resource, testPath.path)
            end)
            
            if success and tests then
                -- Compter approximativement le nombre de tests
                -- En comptant les occurrences de "name = 'test_"
                local _, testCount = string.gsub(tests, "name%s*=%s*['\"]test_", "")
                count = count + testCount
            end
        end
    end
        end
    end
    
    return count
end

-- === DÉTECTION DES DÉPENDANCES ===
function Scanner.DetectDependencies(resourceName)
    local dependencies = {}
    
    -- Dependencies
    local depCount = GetNumResourceMetadata(resourceName, 'dependency')
    for i = 0, depCount - 1 do
        local dep = GetResourceMetadata(resourceName, 'dependency', i)
        if dep then
            table.insert(dependencies, {
                name = dep,
                type = 'required'
            })
        end
    end
    
    -- Optional dependencies
    local optDepCount = GetNumResourceMetadata(resourceName, 'dependencies')
    for i = 0, optDepCount - 1 do
        local dep = GetResourceMetadata(resourceName, 'dependencies', i)
        if dep then
            table.insert(dependencies, {
                name = dep,
                type = 'optional'
            })
        end
    end
    
    return dependencies
end

-- === DÉTECTION INTELLIGENTE DES FONCTIONNALITÉS ===
function Scanner.DetectFeatures(resourceName)
    local features = {
        hasDatabase = false,
        hasEconomy = false,
        hasInventory = false,
        hasUI = false,
        hasCommands = false,
        hasCallbacks = false,
        hasExports = false
    }
    
    -- Analyser les fichiers du module
    local files = Scanner.DetectFiles(resourceName)
    
    -- UI
    if #files.html > 0 then
        features.hasUI = true
    end
    
    -- Database (vérifier MySQL/oxmysql dans les dépendances)
    local deps = Scanner.DetectDependencies(resourceName)
    for _, dep in ipairs(deps) do
        if dep.name == 'oxmysql' or dep.name == 'mysql-async' then
            features.hasDatabase = true
        end
    end
    
    -- Economy (vérifier si vAvA_economy est une dépendance)
    for _, dep in ipairs(deps) do
        if dep.name == 'vAvA_economy' or string.find(resourceName:lower(), 'economy') then
            features.hasEconomy = true
        end
    end
    
    -- Inventory
    if string.find(resourceName:lower(), 'inventory') then
        features.hasInventory = true
    end
    
    -- Exports
    local exportsData = Scanner.DetectExports(resourceName)
    if #exportsData > 0 then
        features.hasExports = true
    end
    
    return features
end

-- === SCAN PROFOND (ANALYSE DÉTAILLÉE) ===
function Scanner.DeepScan(resourceName)
    local module = Scanner.AnalyzeResource(resourceName)
    if not module then return nil end
    
    -- Ajouter les dépendances
    module.dependencies = Scanner.DetectDependencies(resourceName)
    
    -- Ajouter les features
    module.features = Scanner.DetectFeatures(resourceName)
    
    -- Analyser la complexité
    module.complexity = Scanner.AnalyzeComplexity(module)
    
    -- Recommandations de tests
    module.recommendedTests = Scanner.RecommendTests(module)
    
    return module
end

-- === ANALYSE DE COMPLEXITÉ ===
function Scanner.AnalyzeComplexity(module)
    local complexity = {
        score = 0,
        level = 'simple'
    }
    
    -- Calculer le score basé sur différents facteurs
    local score = 0
    
    -- Nombre de fichiers
    local totalFiles = #module.files.client + #module.files.server + #module.files.shared
    score = score + totalFiles * 2
    
    -- Dépendances
    score = score + #module.dependencies * 5
    
    -- Exports
    score = score + #module.exports * 3
    
    -- Features
    if module.features then
        if module.features.hasDatabase then score = score + 15 end
        if module.features.hasEconomy then score = score + 10 end
        if module.features.hasInventory then score = score + 10 end
        if module.features.hasUI then score = score + 8 end
    end
    
    complexity.score = score
    
    -- Déterminer le niveau
    if score < 20 then
        complexity.level = 'simple'
    elseif score < 50 then
        complexity.level = 'moderate'
    elseif score < 100 then
        complexity.level = 'complex'
    else
        complexity.level = 'very_complex'
    end
    
    return complexity
end

-- === RECOMMANDATION DE TESTS ===
function Scanner.RecommendTests(module)
    local tests = {}
    
    -- Tests unitaires de base (toujours)
    table.insert(tests, {
        type = 'unit',
        name = 'basic_initialization',
        priority = 'high',
        description = 'Vérifier le chargement du module'
    })
    
    -- Tests spécifiques selon les features
    if module.features then
        if module.features.hasDatabase then
            table.insert(tests, {
                type = 'integration',
                name = 'database_connection',
                priority = 'high',
                description = 'Tester la connexion à la base de données'
            })
            table.insert(tests, {
                type = 'integration',
                name = 'database_queries',
                priority = 'medium',
                description = 'Tester les requêtes SQL'
            })
        end
        
        if module.features.hasEconomy then
            table.insert(tests, {
                type = 'integration',
                name = 'economy_transactions',
                priority = 'high',
                description = 'Tester les transactions économiques'
            })
        end
        
        if module.features.hasInventory then
            table.insert(tests, {
                type = 'unit',
                name = 'inventory_operations',
                priority = 'high',
                description = 'Tester les opérations d\'inventaire'
            })
        end
        
        if module.features.hasUI then
            table.insert(tests, {
                type = 'unit',
                name = 'ui_rendering',
                priority = 'medium',
                description = 'Tester le rendu de l\'interface'
            })
        end
        
        if module.features.hasExports then
            table.insert(tests, {
                type = 'unit',
                name = 'exports_validation',
                priority = 'high',
                description = 'Valider les exports du module'
            })
        end
    end
    
    -- Tests de sécurité
    table.insert(tests, {
        type = 'security',
        name = 'permission_checks',
        priority = 'high',
        description = 'Vérifier les contrôles de permissions'
    })
    
    -- Tests de performance selon la complexité
    if module.complexity and module.complexity.level ~= 'simple' then
        table.insert(tests, {
            type = 'stress',
            name = 'load_test',
            priority = 'medium',
            description = 'Test de charge'
        })
    end
    
    return tests
end

-- === EXPORTS ===
return Scanner
