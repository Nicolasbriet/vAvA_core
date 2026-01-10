--[[
    vAvA_testbench - Configuration
    Paramètres du module de test
]]

TestbenchConfig = {
    -- Général
    Enabled = true, -- Activer/désactiver le testbench
    DevMode = true, -- Mode développement (logs détaillés)
    
    -- Sécurité
    AdminOnly = true, -- Réservé aux admins uniquement
    AllowedACE = 'vava.admin', -- Permission ACE requise
    
    -- Tests automatiques au démarrage
    AutoStart = {
        Enabled = true, -- Exécuter tests au démarrage
        CriticalOnly = true, -- Uniquement tests critiques
        Delay = 5000 -- Délai avant démarrage (ms)
    },
    
    -- Tests programmés (cron)
    Scheduled = {
        Enabled = false,
        Interval = 3600000, -- 1 heure (ms)
        TestTypes = {'unit', 'integration'}
    },
    
    -- Niveaux de logs
    LogLevel = {
        Debug = true,
        Info = true,
        Warning = true,
        Error = true,
        Critical = true
    },
    
    -- Tests de charge
    StressTests = {
        Enabled = true,
        MaxPlayers = 200, -- Nombre max de joueurs simulés
        SimulateActions = true,
        ActionsPerSecond = 50 -- Actions simulées par seconde
    },
    
    -- Sandbox
    Sandbox = {
        Enabled = true, -- Isoler les tests destructifs
        FakeDatabase = true, -- Utiliser une BDD de test
        FakeEconomy = true, -- Ne pas affecter l'économie réelle
        FakeInventory = true -- Ne pas affecter les inventaires réels
    },
    
    -- Détection automatique
    AutoDetect = {
        ScanModules = true, -- Scanner automatiquement les modules
        LoadTests = true, -- Charger automatiquement les tests trouvés
        UpdateUI = true -- Mettre à jour l'UI automatiquement
    },
    
    -- Performance
    Performance = {
        MaxTestDuration = 30000, -- Timeout par test (ms)
        ParallelTests = 5, -- Nombre de tests en parallèle
        CacheResults = true -- Mettre en cache les résultats
    },
    
    -- Export
    Export = {
        Enabled = true,
        Format = 'json', -- json, xml, html
        AutoSave = true, -- Sauvegarder automatiquement
        SavePath = 'modules/testbench/logs/'
    },
    
    -- UI
    UI = {
        Theme = 'vava', -- Thème vAvA
        RefreshRate = 1000, -- Rafraîchissement UI (ms)
        MaxLogsDisplayed = 100, -- Nombre max de logs affichés
        EnableCharts = true, -- Activer graphiques
        EnableRealtime = true -- Mise à jour en temps réel
    },
    
    -- Notifications
    Notifications = {
        OnTestComplete = true,
        OnTestFail = true,
        OnCriticalError = true,
        InGame = true, -- Notifications in-game
        Console = true -- Logs console
    },
    
    -- Modules testés (détection auto + manuel)
    Modules = {
        'vAvA_core',
        'vAvA_inventory',
        'vAvA_jobs',
        'vAvA_economy',
        'vAvA_concess',
        'vAvA_garage',
        'vAvA_creator',
        'vAvA_chat',
        'vAvA_keys',
        'vAvA_status',
        'vAvA_target',
        'vAvA_jobshop',
        'vAvA_persist',
        'vAvA_sit',
        'vAvA_testbench'
    },
    
    -- Types de tests
    TestTypes = {
        unit = {
            enabled = true,
            critical = true,
            description = 'Tests unitaires - Fonctions individuelles'
        },
        integration = {
            enabled = true,
            critical = true,
            description = 'Tests d\'intégration - Interactions modules'
        },
        stress = {
            enabled = true,
            critical = false,
            description = 'Tests de charge - Performance sous stress'
        },
        security = {
            enabled = true,
            critical = true,
            description = 'Tests de sécurité - Anti-cheat et validations'
        },
        coherence = {
            enabled = true,
            critical = true,
            description = 'Tests de cohérence - Données et logique'
        }
    },
    
    -- Scénarios prédéfinis
    Scenarios = {
        {
            name = 'Cycle économique complet',
            enabled = true,
            critical = true,
            steps = {
                'GiveJob',
                'ReceiveSalary',
                'BuyItem',
                'SellItem',
                'BuyClothes',
                'BuyVehicle',
                'VerifyEconomy'
            }
        },
        {
            name = 'Création personnage',
            enabled = true,
            critical = true,
            steps = {
                'OpenCreator',
                'ModifyMorphology',
                'ModifyClothes',
                'SaveCharacter',
                'LoadCharacter',
                'VerifyDatabase'
            }
        },
        {
            name = 'Inventaire complet',
            enabled = true,
            critical = true,
            steps = {
                'AddItem',
                'RemoveItem',
                'StackItems',
                'Metadata',
                'DropItem'
            }
        },
        {
            name = 'Système jobs',
            enabled = true,
            critical = true,
            steps = {
                'ChangeJob',
                'ReceiveSalary',
                'VerifyPermissions'
            }
        }
    }
}

-- Messages personnalisables
TestbenchMessages = {
    -- Français
    fr = {
        test_started = '🧪 Test démarré: %s',
        test_passed = '✅ Test réussi: %s (%sms)',
        test_failed = '❌ Test échoué: %s',
        test_warning = '⚠️ Avertissement: %s',
        module_detected = '📦 Module détecté: %s',
        scanning_modules = '🔍 Scan des modules...',
        running_tests = '▶️ Exécution des tests...',
        all_tests_passed = '🎉 Tous les tests sont passés!',
        some_tests_failed = '⚠️ %d test(s) échoué(s)',
        access_denied = '❌ Accès refusé - Permissions admin requises',
        testbench_ready = '✅ Testbench prêt'
    },
    
    -- English
    en = {
        test_started = '🧪 Test started: %s',
        test_passed = '✅ Test passed: %s (%sms)',
        test_failed = '❌ Test failed: %s',
        test_warning = '⚠️ Warning: %s',
        module_detected = '📦 Module detected: %s',
        scanning_modules = '🔍 Scanning modules...',
        running_tests = '▶️ Running tests...',
        all_tests_passed = '🎉 All tests passed!',
        some_tests_failed = '⚠️ %d test(s) failed',
        access_denied = '❌ Access denied - Admin permissions required',
        testbench_ready = '✅ Testbench ready'
    }
}

-- Langue par défaut
TestbenchConfig.Language = 'fr'
