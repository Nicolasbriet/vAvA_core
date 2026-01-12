--[[
    vAvA_core - Configuration globale
]]

Config = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🌍 GÉNÉRAL
-- ═══════════════════════════════════════════════════════════════════════════

Config.Locale = 'fr'                          -- Langue par défaut (fr, en, es)
Config.Debug = false                          -- Mode debug
Config.ServerName = 'vAvA Server'             -- Nom du serveur

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎨 BRANDING / IDENTITÉ VISUELLE
-- ═══════════════════════════════════════════════════════════════════════════

Config.Branding = {
    Logo = 'css/logov_core.png',              -- Logo principal (dans html/css/)
    LogoSize = {
        width = 150,                          -- Largeur en pixels
        height = 150                          -- Hauteur en pixels
    },
    Colors = {
        primary = '#FF1E1E',                  -- Rouge Néon
        primaryDark = '#8B0000',              -- Rouge Foncé
        background = '#000000',               -- Noir Profond
        text = '#FFFFFF'                      -- Blanc
    },
    Fonts = {
        title = 'Orbitron',                   -- Police des titres
        text = 'Montserrat'                   -- Police du texte
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 👤 JOUEURS
-- ═══════════════════════════════════════════════════════════════════════════

Config.Players = {
    -- Identification
    Identifiers = {
        primary = 'license',                  -- Identifiant principal (license, steam, discord)
        secondary = {'steam', 'discord'}      -- Identifiants secondaires
    },
    
    -- Multi-personnages
    MultiCharacter = {
        enabled = true,
        maxCharacters = 5
    },
    
    -- Sauvegarde automatique
    AutoSave = {
        enabled = true,
        interval = 60,                        -- 1 minute pour test (60 secondes)
        saveOnDisconnect = true,              -- Sauvegarder à la déconnexion
        saveOnDeath = true,                   -- Sauvegarder à la mort
        saveOnVehicleChange = false,          -- Sauvegarder au changement de véhicule
        savePosition = true,                  -- Sauvegarder la position
        saveStatus = true,                    -- Sauvegarder hunger/thirst
        saveMoney = true,                     -- Sauvegarder l'argent
        saveInventory = true,                 -- Sauvegarder l'inventaire
        debug = true                          -- Afficher logs de sauvegarde
    },
    
    -- Spawn par défaut
    DefaultSpawn = {
        x = -269.4,
        y = -955.3,
        z = 31.2,
        heading = 205.0
    },
    
    -- Argent de départ
    StartingMoney = {
        cash = 5000,
        bank = 10000,
        black_money = 0
    },
    
    -- Status de départ
    StartingStatus = {
        hunger = 100,
        thirst = 100,
        stress = 0,
        health = 200,
        armor = 0
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 💰 ÉCONOMIE
-- ═══════════════════════════════════════════════════════════════════════════

Config.Economy = {
    -- Types d'argent
    MoneyTypes = {
        'cash',                               -- Argent liquide
        'bank',                               -- Banque
        'black_money'                         -- Argent sale
    },
    
    -- Logs
    LogTransactions = true,
    
    -- Limites
    MaxCash = 1000000000,
    MaxBank = 1000000000,
    
    -- Taxes (optionnel)
    Taxes = {
        enabled = false,
        rate = 0.05                           -- 5%
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 💼 JOBS
-- ═══════════════════════════════════════════════════════════════════════════

Config.Jobs = {
    DefaultJob = 'unemployed',
    DefaultGrade = 0,
    
    -- Liste des jobs (extensible via modules)
    List = {
        ['unemployed'] = {
            label = 'Chômeur',
            grades = {
                [0] = {
                    name = 'unemployed',
                    label = 'Sans emploi',
                    salary = 0,
                    permissions = {}
                }
            }
        },
        ['police'] = {
            label = 'Police',
            grades = {
                [0] = {
                    name = 'recruit',
                    label = 'Recrue',
                    salary = 2000,
                    permissions = {'handcuff', 'frisk'}
                },
                [1] = {
                    name = 'officer',
                    label = 'Officier',
                    salary = 2500,
                    permissions = {'handcuff', 'frisk', 'impound'}
                },
                [2] = {
                    name = 'sergeant',
                    label = 'Sergent',
                    salary = 3000,
                    permissions = {'handcuff', 'frisk', 'impound', 'hire'}
                },
                [3] = {
                    name = 'lieutenant',
                    label = 'Lieutenant',
                    salary = 3500,
                    permissions = {'handcuff', 'frisk', 'impound', 'hire', 'fire'}
                },
                [4] = {
                    name = 'chief',
                    label = 'Chef de Police',
                    salary = 5000,
                    permissions = {'handcuff', 'frisk', 'impound', 'hire', 'fire', 'manage'}
                }
            }
        },
        ['ambulance'] = {
            label = 'EMS',
            grades = {
                [0] = {
                    name = 'recruit',
                    label = 'Stagiaire',
                    salary = 1800,
                    permissions = {'revive'}
                },
                [1] = {
                    name = 'paramedic',
                    label = 'Ambulancier',
                    salary = 2200,
                    permissions = {'revive', 'heal'}
                },
                [2] = {
                    name = 'doctor',
                    label = 'Médecin',
                    salary = 3000,
                    permissions = {'revive', 'heal', 'surgery'}
                },
                [3] = {
                    name = 'chief',
                    label = 'Chef des Urgences',
                    salary = 4000,
                    permissions = {'revive', 'heal', 'surgery', 'hire', 'fire'}
                }
            }
        },
        ['mechanic'] = {
            label = 'Mécanicien',
            grades = {
                [0] = {
                    name = 'employee',
                    label = 'Employé',
                    salary = 1500,
                    permissions = {'repair'}
                },
                [1] = {
                    name = 'mechanic',
                    label = 'Mécanicien',
                    salary = 2000,
                    permissions = {'repair', 'tune'}
                },
                [2] = {
                    name = 'boss',
                    label = 'Patron',
                    salary = 3000,
                    permissions = {'repair', 'tune', 'hire', 'fire'}
                }
            }
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎒 INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

Config.Inventory = {
    MaxWeight = 40000,                        -- Poids max en grammes
    MaxSlots = 50,                            -- Nombre de slots max
    
    -- Drops
    DropEnabled = true,
    DropTimeout = 300000,                     -- 5 minutes avant disparition
    
    -- Coffres
    Stashes = {
        enabled = true,
        maxWeight = 100000,
        maxSlots = 100
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ❤️ STATUS
-- ═══════════════════════════════════════════════════════════════════════════

Config.Status = {
    Enabled = true,
    
    -- Décrémentation
    DecreaseRate = {
        hunger = 0.5,                         -- Par minute
        thirst = 0.7,                         -- Par minute
        stress = -0.2                         -- Récupération par minute
    },
    
    -- Effets
    Effects = {
        hunger = {
            critical = 10,                    -- Niveau critique
            damage = 5                        -- Dégâts par tick
        },
        thirst = {
            critical = 10,
            damage = 5
        },
        stress = {
            high = 80,                        -- Niveau de stress élevé
            effects = {'screen_shake'}        -- Effets visuels
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🚗 VÉHICULES
-- ═══════════════════════════════════════════════════════════════════════════

Config.Vehicles = {
    -- Propriété
    OwnershipEnabled = true,
    
    -- Garage
    Garages = {
        enabled = true,
        impoundPrice = 500
    },
    
    -- Clés
    KeySystem = {
        enabled = true
    },
    
    -- Assurance
    Insurance = {
        enabled = true,
        price = 5000
    },
    
    -- Spawn
    SpawnDistance = 100.0
}

-- ═══════════════════════════════════════════════════════════════════════════
--  SÉCURITÉ
-- ═══════════════════════════════════════════════════════════════════════════

Config.Security = {
    -- Anti-trigger
    AntiTrigger = {
        enabled = true,
        whitelist = {}                       -- Events whitelistés
    },
    
    -- Rate limit
    RateLimit = {
        enabled = true,
        maxRequests = 10,                    -- Requêtes max par seconde
        banDuration = 86400                  -- 24h en secondes
    },
    
    -- Logs
    Logging = {
        enabled = true,
        discord = {
            enabled = false,
            webhook = ''
        }
    },
    
    -- Vérifications
    ServerSideChecks = true                  -- Toujours vérifier côté serveur
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🛠️ PERMISSIONS (Basé sur txAdmin ACE)
-- ═══════════════════════════════════════════════════════════════════════════

Config.Permissions = {
    -- Méthode de vérification: 'ace' (txAdmin) ou 'group' (vCore interne)
    Method = 'ace',                          -- 'ace' = txAdmin ACE permissions
    
    -- Préfixe des permissions ACE (ex: vava.admin, vava.mod)
    AcePrefix = 'vava',
    
    -- Permissions ACE à vérifier (ordre de priorité)
    -- Ces permissions doivent être définies dans txAdmin ou server.cfg
    AceLevels = {
        owner = {
            aces = {'vava.owner', 'txadmin.operator.super'},
            level = 5
        },
        developer = {
            aces = {'vava.developer', 'vava.dev'},
            level = 4
        },
        superadmin = {
            aces = {'vava.superadmin', 'txadmin.operator'},
            level = 3
        },
        admin = {
            aces = {'vava.admin', 'txadmin.operator'},
            level = 2
        },
        mod = {
            aces = {'vava.mod', 'vava.moderator'},
            level = 1
        },
        helper = {
            aces = {'vava.helper'},
            level = 0
        }
    },
    
    -- Compatibilité avec d'autres systèmes (WaveAdmin, etc.)
    ExtraAces = {
        'WaveAdmin.owner',
        'WaveAdmin._dev',
        'WaveAdmin.god',
        'WaveAdmin.superadmin',
        'WaveAdmin.mod',
        'WaveAdmin.helper'
    },
    
    -- Fallback: utiliser les groupes vCore si ACE non trouvé
    FallbackToGroups = true
}

-- Configuration des groupes (fallback si ACE non disponible)
Config.Admin = {
    -- Niveaux de permissions internes
    Groups = {
        ['user'] = 0,
        ['helper'] = 0,
        ['mod'] = 1,
        ['admin'] = 2,
        ['superadmin'] = 3,
        ['developer'] = 4,
        ['owner'] = 5
    },
    
    -- Admins par identifiant (fallback)
    Admins = {
        ['license:9ca277a68ad4d2c3324edf1f068c2a8229f069fd'] = 'owner',
    },
    
    -- Commandes
    Commands = {
        prefix = '/',
        restrictedToAdmin = true
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎨 UI (NOUVEAU - UI Manager)
-- ═══════════════════════════════════════════════════════════════════════════

Config.UI = {
    -- Notifications
    Notifications = {
        enabled = true,
        position = 'top-right',              -- top-right, top-left, bottom-right, bottom-left
        duration = 5000,                     -- Durée par défaut en ms
        maxStack = 5                         -- Nombre max de notifications affichées
    },
    
    -- Progress Bar
    ProgressBar = {
        enabled = true,
        position = 'bottom',                 -- bottom, center
        canCancelByDefault = true            -- Autoriser annulation par défaut
    },
    
    -- Prompts
    Prompts = {
        enabled = true,
        closeOnEscape = true
    },
    
    -- HUD Updates
    HUDUpdate = {
        interval = 1000,                     -- Fréquence de mise à jour en ms
        smoothTransitions = true
    },
    
    -- 3D Text & Markers
    Rendering = {
        text3DDistance = 10.0,               -- Distance max affichage texte 3D
        markerDistance = 50.0,               -- Distance max affichage markers
        updateRate = 0                       -- 0 = chaque frame, sinon ms
    },
    
    -- Menus natifs
    NativeMenus = {
        enabled = true,
        library = 'native'                   -- 'native', 'nativeui', 'menuv'
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🧩 MODULES (Activation/Désactivation)
-- ═══════════════════════════════════════════════════════════════════════════

Config.Modules = {
    -- Modules du core (intégrés)
    Core = {
        economy = true,
        jobs = true,
        inventory = true,
        vehicles = true,
        status = true,
        hud = true
    },
    
    -- Modules externes (dossier modules/)
    External = {
        police = true,
        player_manager = true,
        ems = true,
        garage = true,
        keys = true,
        persist = true,
        chat = true,
        concess = true,
        creator = true,
        jobshop = true,
        loadingscreen = true,
        sit = true,
        target = true,
        testbench = true
    },
    
    -- Dépendances inter-modules
    Dependencies = {
        garage = {'keys', 'persist', 'vehicles'},
        police = {'player_manager'},
        ems = {'player_manager'}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🗄️ BASE DE DONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

Config.Database = {
    -- Cache
    Cache = {
        enabled = true,
        ttl = 60000,                         -- Time to live en ms
        maxSize = 1000                       -- Entrées max
    },
    
    -- Migrations
    AutoMigrate = true,
    
    -- Optimisation
    PreparedStatements = true,
    ConnectionPool = {
        min = 2,
        max = 10
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 GAMEPLAY
-- ═══════════════════════════════════════════════════════════════════════════

Config.Gameplay = {
    -- PVP
    PVP = {
        enabled = true,
        safezones = {}                       -- Coordonnées zones sûres
    },
    
    -- Mort
    Death = {
        respawnTime = 300,                   -- Temps avant respawn (secondes)
        loseMoneyOnDeath = true,
        moneyLossPercentage = 5,             -- % argent perdu
        dropInventoryOnDeath = false
    },
    
    -- Voix
    Voice = {
        enabled = true,
        system = 'pma-voice',                -- 'pma-voice', 'mumble-voip', 'saltychat'
        defaultRange = 3.0
    },
    
    -- Interactions
    Interactions = {
        enabled = true,
        useTargetSystem = true,              -- Utiliser vAvA_target
        interactionKey = 38                  -- E par défaut
    }
}
