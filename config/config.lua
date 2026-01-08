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
        interval = 300000                     -- 5 minutes en ms
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
-- 🖥️ HUD
-- ═══════════════════════════════════════════════════════════════════════════

Config.HUD = {
    Enabled = true,
    
    -- Position
    Position = 'bottom-right',               -- bottom-right, bottom-left, top-right, top-left
    
    -- Éléments affichés
    ShowHealth = true,
    ShowArmor = true,
    ShowHunger = true,
    ShowThirst = true,
    ShowStress = false,                      -- Désactivé par défaut
    ShowMoney = true,
    ShowJob = true,
    
    -- Minimap
    Minimap = {
        enabled = true,
        shape = 'circle'                     -- circle, square
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔐 SÉCURITÉ
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
-- 🛠️ ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

Config.Admin = {
    -- Permissions
    Groups = {
        ['user'] = 0,
        ['mod'] = 1,
        ['admin'] = 2,
        ['superadmin'] = 3,
        ['owner'] = 4
    },
    
    -- Admins par identifiant
    Admins = {
        -- ['license:xxxxx'] = 'superadmin'
    },
    
    -- Commandes
    Commands = {
        prefix = '/',
        restrictedToAdmin = true
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
    AutoMigrate = true
}
