-- ============================================
-- vAvA Target - Configuration
-- ============================================

TargetConfig = {}

-- ============================================
-- GÉNÉRAL
-- ============================================
TargetConfig.Enabled = true                      -- Activer le module
TargetConfig.Debug = false                       -- Mode debug (affichage zones, logs)
TargetConfig.Language = 'fr'                     -- Langue par défaut (fr, en, es)

-- ============================================
-- DÉTECTION ET RAYCAST
-- ============================================
TargetConfig.DefaultDistance = 2.5               -- Distance par défaut (mètres)
TargetConfig.MaxDistance = 10.0                  -- Distance maximale (mètres)
TargetConfig.VehicleDistance = 3.0               -- Distance pour véhicules (mètres)
TargetConfig.ZoneDistance = 2.0                  -- Distance pour zones (mètres)

TargetConfig.ActivationKey = 19                  -- Touche d'activation (19 = ALT)
TargetConfig.UseKeyActivation = true             -- true = ALT pour activer, false = automatique
TargetConfig.UpdateRate = 100                    -- Fréquence de détection quand ALT pressé (ms)
TargetConfig.RaycastFlags = 30                   -- Flags raycast (30 = tout sauf peds)
TargetConfig.EnableCache = true                  -- Activer le cache (optimisation)
TargetConfig.CacheDuration = 1000                -- Durée cache (ms)

-- ============================================
-- INTERFACE (NUI)
-- ============================================
TargetConfig.UI = {
    -- Type de menu
    MenuType = 'radial',                         -- 'radial', 'list', 'compact'
    
    -- Position (pour liste uniquement)
    Position = 'top-right',                      -- 'top-left', 'top-right', 'bottom-left', 'bottom-right', 'center'
    
    -- Apparence
    ShowDistance = true,                         -- Afficher la distance
    ShowIcon = true,                             -- Afficher les icônes
    ShowKeybind = true,                          -- Afficher les touches
    ShowDot = true,                              -- Afficher le point central quand ALT pressé
    DotSize = 8,                                 -- Taille du point (pixels)
    DotColor = {255, 30, 30, 255},               -- Couleur du point (R, G, B, A)
    
    -- Animations
    AnimationDuration = 300,                     -- Durée animations (ms)
    FadeIn = true,                               -- Fade in à l'ouverture
    FadeOut = true,                              -- Fade out à la fermeture
    
    -- Auto-fermeture
    AutoClose = true,                            -- Fermeture automatique
    AutoCloseDelay = 30000,                      -- Délai avant fermeture auto (ms)
    CloseOnMove = true,                          -- Fermer si joueur bouge
    CloseOnDistance = true,                      -- Fermer si distance trop grande
    
    -- Keybinds
    OpenKey = 'E',                               -- Touche pour ouvrir (désactivé par défaut, auto)
    CloseKey = 'ESC',                            -- Touche pour fermer
    SelectKey = 'ENTER',                         -- Touche pour sélectionner
    
    -- Limites
    MaxOptions = 10,                             -- Nombre max d'options affichées
    
    -- Responsive
    ScaleWithDistance = true,                    -- Adapter taille avec distance
    MinScale = 0.8,                              -- Échelle minimale
    MaxScale = 1.2                               -- Échelle maximale
}

-- ============================================
-- SÉCURITÉ
-- ============================================
TargetConfig.Security = {
    -- Anti-cheat
    EnableAntiCheat = true,                      -- Activer l'anti-cheat
    MaxInteractionsPerMinute = 60,               -- Max interactions/minute
    ValidateDistance = true,                     -- Valider distance serveur
    ValidateEntity = true,                       -- Valider entité existe
    
    -- Logging
    LogInteractions = true,                      -- Logger les interactions
    LogLevel = 'warning',                        -- Niveau logs: 'debug', 'info', 'warning', 'error'
    LogToDatabase = false,                       -- Sauvegarder logs en BDD
    
    -- Sanctions
    AutoKick = true,                             -- Kick automatique
    AutoBan = false,                             -- Ban automatique
    WarningsBeforeKick = 3                       -- Warnings avant kick
}

-- ============================================
-- TYPES D'ENTITÉS SUPPORTÉES
-- ============================================
TargetConfig.EntityTypes = {
    peds = true,                                 -- Activer ciblage PNJ
    vehicles = true,                             -- Activer ciblage véhicules
    objects = true,                              -- Activer ciblage objets
    players = true                               -- Activer ciblage joueurs
}

-- ============================================
-- ZONES PRÉDÉFINIES (POIs)
-- ============================================
TargetConfig.Zones = {
    -- Exemple: Shops
    {
        name = 'shop_24_7_1',
        type = 'sphere',
        coords = vector3(25.7, -1347.3, 29.5),
        radius = 2.0,
        debug = false,
        options = {
            {
                label = 'Ouvrir la boutique',
                icon = 'fa-solid fa-shopping-cart',
                event = 'vava:openShop',
                server = false,
                data = {shopType = '24_7'}
            }
        }
    },
    
    -- Exemple: Garage
    {
        name = 'garage_central_1',
        type = 'box',
        coords = vector3(215.8, -810.1, 30.7),
        size = vector3(3.0, 3.0, 2.0),
        heading = 0.0,
        debug = false,
        options = {
            {
                label = 'Sortir un véhicule',
                icon = 'fa-solid fa-car',
                event = 'vava_garage:openMenu',
                server = false,
                job = nil
            },
            {
                label = 'Ranger le véhicule',
                icon = 'fa-solid fa-warehouse',
                event = 'vava_garage:store',
                server = true,
                inVehicle = true
            }
        }
    },
    
    -- Exemple: Job LSPD
    {
        name = 'lspd_armory',
        type = 'box',
        coords = vector3(452.6, -980.0, 30.7),
        size = vector3(2.0, 2.0, 2.0),
        heading = 0.0,
        debug = false,
        options = {
            {
                label = 'Accéder à l\'armurerie',
                icon = 'fa-solid fa-gun',
                event = 'vava_jobs:openArmory',
                server = false,
                job = {'police', 'sheriff'},
                grade = 1,
                duty = true
            }
        }
    }
}

-- ============================================
-- MODÈLES PRÉDÉFINIS (POIs)
-- ============================================
TargetConfig.Models = {
    -- Exemple: Distributeurs ATM
    {
        models = {'prop_atm_01', 'prop_atm_02', 'prop_atm_03', 'prop_fleeca_atm'},
        distance = 2.0,
        options = {
            {
                label = 'Utiliser le distributeur',
                icon = 'fa-solid fa-credit-card',
                event = 'vava_banking:openATM',
                server = false
            }
        }
    },
    
    -- Exemple: Poubelles
    {
        models = {'prop_bin_01a', 'prop_bin_02a', 'prop_bin_03a', 'prop_bin_04a'},
        distance = 2.0,
        options = {
            {
                label = 'Fouiller la poubelle',
                icon = 'fa-solid fa-dumpster',
                event = 'vava:searchTrash',
                server = true,
                canInteract = function(entity, distance, coords, isPlayer)
                    return not IsPedInAnyVehicle(PlayerPedId(), false)
                end
            }
        }
    },
    
    -- Exemple: Portes
    {
        models = {'prop_door_01', 'prop_door_02', 'v_ilev_ph_door01', 'v_ilev_ph_door02'},
        distance = 2.0,
        options = {
            {
                label = 'Ouvrir/Fermer',
                icon = 'fa-solid fa-door-open',
                event = 'vava_doors:toggle',
                server = true
            },
            {
                label = 'Déverrouiller',
                icon = 'fa-solid fa-key',
                event = 'vava_doors:unlock',
                server = true,
                item = 'lockpick'
            }
        }
    }
}

-- ============================================
-- BONES (OS) SUPPORTÉS
-- ============================================
TargetConfig.Bones = {
    -- Véhicules
    vehicle = {
        -- Portes
        {
            bones = {'door_dside_f', 'door_pside_f', 'door_dside_r', 'door_pside_r'},
            distance = 1.5,
            options = {
                {
                    label = 'Ouvrir/Fermer la porte',
                    icon = 'fa-solid fa-door-open',
                    event = 'vava_vehicles:toggleDoor',
                    server = false
                }
            }
        },
        
        -- Coffre
        {
            bones = {'boot'},
            distance = 2.0,
            options = {
                {
                    label = 'Ouvrir le coffre',
                    icon = 'fa-solid fa-box',
                    event = 'vava_inventory:openTrunk',
                    server = false
                }
            }
        },
        
        -- Capot
        {
            bones = {'bonnet'},
            distance = 2.0,
            options = {
                {
                    label = 'Ouvrir le capot',
                    icon = 'fa-solid fa-toolbox',
                    event = 'vava_vehicles:openHood',
                    server = false
                },
                {
                    label = 'Réparer',
                    icon = 'fa-solid fa-wrench',
                    event = 'vava_vehicles:repair',
                    server = true,
                    item = 'repair_kit',
                    job = {'mechanic'}
                }
            }
        }
    }
}

-- ============================================
-- BLACKLIST
-- ============================================
TargetConfig.Blacklist = {
    -- Entités blacklistées (handles réseau)
    entities = {},
    
    -- Modèles blacklistés (hash)
    models = {
        -- Exemple: GetHashKey('prop_test')
    },
    
    -- Joueurs blacklistés (identifiers)
    players = {}
}

-- ============================================
-- PERMISSIONS
-- ============================================
TargetConfig.Permissions = {
    -- Utiliser le système target
    Use = 'user',                                -- 'user', 'admin', 'superadmin'
    
    -- Activer/désactiver le debug
    Debug = 'admin',
    
    -- Voir les zones en debug
    ViewZones = 'admin',
    
    -- Ajouter/supprimer des targets en jeu
    Manage = 'admin'
}

-- ============================================
-- OPTIMISATION
-- ============================================
TargetConfig.Performance = {
    -- Stream uniquement les entités proches
    UseStreamingDistance = true,
    StreamingDistance = 50.0,                    -- Distance streaming (mètres)
    
    -- Limiter le nombre d'entités traitées
    MaxEntitiesPerFrame = 10,
    
    -- Désactiver automatiquement si FPS bas
    AutoDisableOnLowFPS = false,
    MinFPS = 30,
    
    -- Thread sleep
    ThreadSleep = 0                              -- 0 = pas de sleep (max performance)
}

-- ============================================
-- INTÉGRATIONS MODULES VAVA
-- ============================================
TargetConfig.Integrations = {
    -- Module Inventory
    Inventory = {
        enabled = true,
        hookUseItem = true                       -- Hook automatique sur utilisation item
    },
    
    -- Module Economy
    Economy = {
        enabled = true,
        dynamicPrices = true                     -- Supporter prix dynamiques
    },
    
    -- Module Jobs
    Jobs = {
        enabled = true,
        checkDuty = true                         -- Vérifier si en service
    },
    
    -- Module Testbench
    Testbench = {
        enabled = true,
        generateTests = true                     -- Générer tests auto
    }
}

return TargetConfig
