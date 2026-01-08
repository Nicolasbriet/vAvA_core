--[[
    vAvA_keys - Configuration
    Module intégré à vAvA_core
]]

KeysConfig = {}

-- Paramètres généraux
KeysConfig.Debug = false

-- Auto-création de la base de données
KeysConfig.AutoCreateDatabase = true
KeysConfig.ShowDatabaseLogs = true

-- Notifications
KeysConfig.Notifications = {
    Duration = 5000,
    Position = 'top-right'
}

-- Système de clés
KeysConfig.Keys = {
    -- Durée des clés temporaires (en minutes)
    TempKeyDuration = 30,
    
    -- Distance maximale pour interagir avec un véhicule
    InteractionDistance = 5.0,
    
    -- Vérifier automatiquement les clés en entrant dans un véhicule
    AutoCheckKeys = true,
    
    -- Bloquer le démarrage sans clés
    BlockEngineWithoutKeys = false,
    
    -- Activer les animations de télécommande
    EnableKeyFobAnimation = true,
    
    -- Cooldown entre les actions (ms)
    ActionCooldown = 600,
    
    -- Cooldown pour les notifications "pas de clés" (ms)
    NoKeysNotificationCooldown = 5000
}

-- Commandes et touches
KeysConfig.Commands = {
    LockKey = 182,        -- L - Verrouiller/Déverrouiller
    EngineKey = 47,       -- G - Moteur
    MenuKey = 39          -- ; - Menu gestion
}

-- Double appui pour actions spéciales
KeysConfig.DoubleTap = {
    Enabled = true,
    Delay = 400           -- Délai pour détecter un double appui (ms)
}

-- Effets visuels
KeysConfig.Effects = {
    FlashLights = true,
    FlashDuration = 200,
    LocationBlipDuration = 120000,
    LocationBlipColor = 2,
    LocationBlipSprite = 225
}

-- Base de données
KeysConfig.Database = {
    PlayerVehiclesTable = 'player_vehicles',
    SharedKeysTable = 'shared_vehicle_keys',
    Columns = {
        CitizenId = 'citizenid',
        Plate = 'plate',
        Vehicle = 'vehicle'
    }
}

-- Accès par métier
KeysConfig.JobKeys = {
    Enabled = true,
    Jobs = {
        ['police'] = {
            vehicles = {'police', 'police2', 'police3'},
            plates = {'LSPD*', 'BCSO*'}
        },
        ['ambulance'] = {
            vehicles = {'ambulance'},
            plates = {'EMS*'}
        },
        ['mechanic'] = {
            vehicles = {'towtruck', 'towtruck2'},
            plates = {'MECA*'}
        }
    }
}

-- Système de Car Jacking
KeysConfig.CarJack = {
    Enabled = true,
    MinDuration = 5000,
    MaxDuration = 15000,
    SuccessChance = 70,
    RequireWeapon = false,
    AlertPolice = true,
    AlertRadius = 300
}
