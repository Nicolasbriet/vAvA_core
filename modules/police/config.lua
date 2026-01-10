--[[
    vAvA_police - Configuration
    Toutes les options configurables du module police
]]

PoliceConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION GÉNÉRALE
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.General = {
    -- Activer le module
    Enabled = true,
    
    -- Jobs considérés comme police
    PoliceJobs = {"police", "sheriff", "bcso", "lspd", "swat", "fbi"},
    
    -- Distance d'interaction (en mètres)
    InteractionDistance = 3.0,
    
    -- Activer le GPS entre collègues
    GPS_Enabled = true,
    GPS_UpdateInterval = 5000, -- ms
    
    -- Activer les alertes automatiques
    AlertsEnabled = true,
    
    -- Logo du service (pour tablette/UI)
    ServiceLogo = "img/lspd_logo.png"
}

-- ═══════════════════════════════════════════════════════════════════════════
-- GRADES ET PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Grades = {
    [0] = {
        name = "Cadet",
        label = "Cadet de Police",
        salary = 2000,
        permissions = {
            handcuff = true,
            search = false,
            fine = false,
            impound = false,
            armory = false,
            tablet = false
        }
    },
    [1] = {
        name = "Officer",
        label = "Officier de Police",
        salary = 2500,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true
        }
    },
    [2] = {
        name = "Sergeant",
        label = "Sergent",
        salary = 3000,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true,
            dispatch = true
        }
    },
    [3] = {
        name = "Lieutenant",
        label = "Lieutenant",
        salary = 3500,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true,
            dispatch = true,
            manage_officers = true
        }
    },
    [4] = {
        name = "Captain",
        label = "Capitaine",
        salary = 4000,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true,
            dispatch = true,
            manage_officers = true,
            manage_fines = true
        }
    },
    [5] = {
        name = "Commander",
        label = "Commandant",
        salary = 4500,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true,
            dispatch = true,
            manage_officers = true,
            manage_fines = true,
            manage_records = true
        }
    },
    [6] = {
        name = "Chief",
        label = "Chef de Police",
        salary = 5000,
        permissions = {
            handcuff = true,
            search = true,
            fine = true,
            impound = true,
            armory = true,
            tablet = true,
            dispatch = true,
            manage_officers = true,
            manage_fines = true,
            manage_records = true,
            full_access = true
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMISSARIAT(S) - POSITIONS
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Stations = {
    {
        name = "LSPD Mission Row",
        coords = vector3(441.0, -982.0, 30.7),
        blip = {
            sprite = 60,
            color = 29,
            scale = 0.8,
            label = "LSPD - Mission Row"
        },
        
        -- Vestiaire
        cloakroom = vector3(452.6, -992.8, 30.7),
        
        -- Armurerie
        armory = vector3(453.2, -980.0, 30.7),
        armoryItems = {
            -- Grade minimum requis pour chaque arme
            {item = "weapon_nightstick", label = "Matraque", grade = 0},
            {item = "weapon_stungun", label = "Taser", grade = 0},
            {item = "weapon_flashlight", label = "Lampe Torche", grade = 0},
            {item = "weapon_pistol", label = "Pistolet de Service", grade = 1},
            {item = "weapon_combatpistol", label = "Pistolet de Combat", grade = 2},
            {item = "weapon_pumpshotgun", label = "Fusil à Pompe", grade = 2},
            {item = "weapon_carbinerifle", label = "Carabine", grade = 3},
            {item = "weapon_sniperrifle", label = "Sniper", grade = 4},
            {item = "weapon_smokegrenade", label = "Grenade Fumigène", grade = 2},
            {item = "weapon_bzgas", label = "Gaz Lacrymogène", grade = 2}
        },
        
        -- Garage
        garage = {
            coords = vector3(452.1, -1017.4, 28.4),
            heading = 90.0,
            vehicles = {
                {model = "police", label = "Police Cruiser", grade = 0},
                {model = "police2", label = "Police Interceptor", grade = 1},
                {model = "police3", label = "Police SUV", grade = 2},
                {model = "police4", label = "Police Unmarked", grade = 3},
                {model = "policeb", label = "Moto Police", grade = 1},
                {model = "riot", label = "Véhicule Anti-Émeute", grade = 4},
                {model = "policet", label = "Transport de Prisonniers", grade = 2}
            }
        },
        
        -- Prison (cellules)
        prison = {
            coords = vector3(461.0, -994.0, 24.9),
            cells = {
                vector3(461.8, -993.5, 24.9),
                vector3(461.8, -997.7, 24.9),
                vector3(461.8, -1001.9, 24.9)
            }
        }
    },
    
    -- Paleto Bay Sheriff
    {
        name = "Paleto Bay Sheriff",
        coords = vector3(-447.0, 6013.0, 31.7),
        blip = {
            sprite = 60,
            color = 29,
            scale = 0.7,
            label = "Sheriff - Paleto Bay"
        },
        cloakroom = vector3(-449.0, 6007.0, 31.7),
        armory = vector3(-440.0, 6007.0, 31.7),
        armoryItems = {
            {item = "weapon_nightstick", label = "Matraque", grade = 0},
            {item = "weapon_stungun", label = "Taser", grade = 0},
            {item = "weapon_pistol", label = "Pistolet", grade = 1},
            {item = "weapon_pumpshotgun", label = "Fusil à Pompe", grade = 2},
            {item = "weapon_carbinerifle", label = "Carabine", grade = 3}
        },
        garage = {
            coords = vector3(-475.4, 6031.3, 31.3),
            heading = 225.0,
            vehicles = {
                {model = "sheriff", label = "Sheriff Cruiser", grade = 0},
                {model = "sheriff2", label = "Sheriff SUV", grade = 1}
            }
        },
        prison = {
            coords = vector3(-437.0, 6015.0, 31.7),
            cells = {
                vector3(-437.0, 6015.0, 31.7)
            }
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- AMENDES - TYPES ET MONTANTS
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Fines = {
    -- Infractions routières
    {category = "traffic", label = "Excès de vitesse (mineur)", amount = 150},
    {category = "traffic", label = "Excès de vitesse (majeur)", amount = 350},
    {category = "traffic", label = "Excès de vitesse (grave)", amount = 750},
    {category = "traffic", label = "Griller un feu rouge", amount = 200},
    {category = "traffic", label = "Refus de priorité", amount = 250},
    {category = "traffic", label = "Stationnement interdit", amount = 100},
    {category = "traffic", label = "Conduite dangereuse", amount = 500},
    {category = "traffic", label = "Délit de fuite", amount = 1000},
    {category = "traffic", label = "Course de rue", amount = 1500},
    
    -- Infractions administratives
    {category = "admin", label = "Absence de permis de conduire", amount = 300},
    {category = "admin", label = "Véhicule non assuré", amount = 400},
    {category = "admin", label = "Absence de papiers d'identité", amount = 150},
    {category = "admin", label = "Port d'arme sans licence", amount = 2000},
    
    -- Infractions pénales
    {category = "criminal", label = "Agression simple", amount = 1000, jail_time = 5},
    {category = "criminal", label = "Agression avec arme", amount = 2500, jail_time = 15},
    {category = "criminal", label = "Vol simple", amount = 500, jail_time = 3},
    {category = "criminal", label = "Vol avec effraction", amount = 1500, jail_time = 10},
    {category = "criminal", label = "Vol de véhicule", amount = 2000, jail_time = 10},
    {category = "criminal", label = "Braquage", amount = 5000, jail_time = 20},
    {category = "criminal", label = "Braquage de banque", amount = 10000, jail_time = 40},
    {category = "criminal", label = "Meurtre", amount = 15000, jail_time = 60},
    {category = "criminal", label = "Tentative de meurtre", amount = 7500, jail_time = 30},
    {category = "criminal", label = "Kidnapping", amount = 8000, jail_time = 35},
    {category = "criminal", label = "Trafic de drogue", amount = 5000, jail_time = 25},
    {category = "criminal", label = "Production de drogue", amount = 7500, jail_time = 30},
    {category = "criminal", label = "Résistance à l'arrestation", amount = 1000, jail_time = 5},
    {category = "criminal", label = "Outrage à agent", amount = 500, jail_time = 3},
    {category = "criminal", label = "Corruption", amount = 10000, jail_time = 45}
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PRISON - CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Prison = {
    -- Position de la prison (Bolingbroke Penitentiary)
    Entrance = vector3(1845.0, 2585.8, 45.7),
    
    -- Position de spawn en prison
    Inside = vector3(1679.0, 2513.0, 45.6),
    
    -- Position de libération
    Release = vector3(1847.0, 2586.0, 45.7),
    
    -- Temps minimum/maximum (en minutes)
    MinTime = 1,
    MaxTime = 120,
    
    -- Réduction de peine (% par minute de travail)
    WorkTimeReduction = 0.5, -- 0.5 min réduite par minute travaillée
    
    -- Positions de travail (ramassage d'ordures)
    WorkLocations = {
        vector3(1629.6, 2564.6, 45.6),
        vector3(1645.0, 2526.0, 45.6),
        vector3(1693.0, 2565.0, 45.6),
        vector3(1707.0, 2481.0, 45.8),
        vector3(1748.0, 2492.0, 45.8)
    },
    
    -- Tenue de prisonnier
    Outfit = {
        male = {
            ["tshirt_1"] = 15, ["tshirt_2"] = 0,
            ["torso_1"] = 5, ["torso_2"] = 7,
            ["arms"] = 5,
            ["pants_1"] = 7, ["pants_2"] = 0,
            ["shoes_1"] = 1, ["shoes_2"] = 0
        },
        female = {
            ["tshirt_1"] = 15, ["tshirt_2"] = 0,
            ["torso_1"] = 48, ["torso_2"] = 0,
            ["arms"] = 44,
            ["pants_1"] = 34, ["pants_2"] = 0,
            ["shoes_1"] = 1, ["shoes_2"] = 0
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- RADAR - CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Radar = {
    -- Activer le radar de vitesse
    Enabled = true,
    
    -- Touche pour activer/désactiver (X = 73)
    ToggleKey = 73,
    
    -- Distance de détection (mètres)
    DetectionRange = 50.0,
    
    -- Limite de vitesse par défaut (km/h)
    DefaultSpeedLimit = 80,
    
    -- Zones avec limites spécifiques
    SpeedZones = {
        {coords = vector3(0.0, 0.0, 0.0), radius = 500.0, limit = 50, label = "Centre-ville"},
        {coords = vector3(-1000.0, -1500.0, 5.0), radius = 300.0, limit = 40, label = "Zone résidentielle"},
        {coords = vector3(1000.0, 3000.0, 40.0), radius = 1000.0, limit = 120, label = "Autoroute"}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DISPATCH - ALERTES
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Dispatch = {
    -- Types d'alertes automatiques
    AlertTypes = {
        {code = "10-31", label = "Crime en cours", color = "red", priority = 1},
        {code = "10-32", label = "Homme armé", color = "red", priority = 1},
        {code = "10-90", label = "Cambriolage en cours", color = "orange", priority = 2},
        {code = "10-60", label = "Vol de véhicule", color = "orange", priority = 2},
        {code = "10-50", label = "Accident de la route", color = "yellow", priority = 3},
        {code = "10-99", label = "Agent en détresse", color = "red", priority = 1, backup = true}
    },
    
    -- Durée d'affichage des alertes (secondes)
    AlertDuration = 30,
    
    -- Son d'alerte
    AlertSound = {
        name = "CONFIRM_BEEP",
        set = "HUD_MINI_GAME_SOUNDSET"
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- VESTIAIRE - TENUES
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Outfits = {
    male = {
        [0] = { -- Cadet
            ["tshirt_1"] = 58, ["tshirt_2"] = 0,
            ["torso_1"] = 55, ["torso_2"] = 0,
            ["arms"] = 41,
            ["pants_1"] = 25, ["pants_2"] = 0,
            ["shoes_1"] = 25, ["shoes_2"] = 0,
            ["chain_1"] = 0, ["chain_2"] = 0,
            ["helmet_1"] = -1, ["helmet_2"] = 0,
            ["bags_1"] = 0, ["bags_2"] = 0
        },
        [1] = { -- Officer
            ["tshirt_1"] = 58, ["tshirt_2"] = 0,
            ["torso_1"] = 55, ["torso_2"] = 0,
            ["arms"] = 41,
            ["pants_1"] = 25, ["pants_2"] = 0,
            ["shoes_1"] = 25, ["shoes_2"] = 0,
            ["chain_1"] = 8, ["chain_2"] = 0,
            ["helmet_1"] = -1, ["helmet_2"] = 0,
            ["bags_1"] = 0, ["bags_2"] = 0
        },
        [2] = { -- Sergeant
            ["tshirt_1"] = 58, ["tshirt_2"] = 0,
            ["torso_1"] = 55, ["torso_2"] = 1,
            ["arms"] = 41,
            ["pants_1"] = 25, ["pants_2"] = 0,
            ["shoes_1"] = 25, ["shoes_2"] = 0,
            ["chain_1"] = 8, ["chain_2"] = 0,
            ["helmet_1"] = -1, ["helmet_2"] = 0,
            ["bags_1"] = 0, ["bags_2"] = 0
        },
        -- Grades supérieurs (similaires avec variations)
        [3] = {["tshirt_1"] = 58, ["tshirt_2"] = 0, ["torso_1"] = 55, ["torso_2"] = 2, ["arms"] = 41, ["pants_1"] = 25, ["pants_2"] = 0, ["shoes_1"] = 25, ["shoes_2"] = 0},
        [4] = {["tshirt_1"] = 58, ["tshirt_2"] = 0, ["torso_1"] = 55, ["torso_2"] = 3, ["arms"] = 41, ["pants_1"] = 25, ["pants_2"] = 0, ["shoes_1"] = 25, ["shoes_2"] = 0},
        [5] = {["tshirt_1"] = 58, ["tshirt_2"] = 0, ["torso_1"] = 55, ["torso_2"] = 4, ["arms"] = 41, ["pants_1"] = 25, ["pants_2"] = 0, ["shoes_1"] = 25, ["shoes_2"] = 0},
        [6] = {["tshirt_1"] = 58, ["tshirt_2"] = 0, ["torso_1"] = 55, ["torso_2"] = 5, ["arms"] = 41, ["pants_1"] = 25, ["pants_2"] = 0, ["shoes_1"] = 25, ["shoes_2"] = 0}
    },
    female = {
        [0] = {
            ["tshirt_1"] = 35, ["tshirt_2"] = 0,
            ["torso_1"] = 48, ["torso_2"] = 0,
            ["arms"] = 44,
            ["pants_1"] = 34, ["pants_2"] = 0,
            ["shoes_1"] = 27, ["shoes_2"] = 0,
            ["chain_1"] = 0, ["chain_2"] = 0,
            ["helmet_1"] = -1, ["helmet_2"] = 0,
            ["bags_1"] = 0, ["bags_2"] = 0
        },
        -- Autres grades féminins...
        [1] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 0, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0},
        [2] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 1, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0},
        [3] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 2, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0},
        [4] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 3, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0},
        [5] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 4, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0},
        [6] = {["tshirt_1"] = 35, ["tshirt_2"] = 0, ["torso_1"] = 48, ["torso_2"] = 5, ["arms"] = 44, ["pants_1"] = 34, ["pants_2"] = 0, ["shoes_1"] = 27, ["shoes_2"] = 0}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- INTERACTIONS - CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

PoliceConfig.Interactions = {
    -- Durée des menottes (en secondes, 0 = infini jusqu'à libération)
    HandcuffDuration = 0,
    
    -- Items confisqués automatiquement lors de la fouille
    IllegalItems = {
        "weapon_pistol",
        "weapon_combatpistol",
        "weapon_smg",
        "weed",
        "cocaine",
        "meth",
        "lockpick",
        "drill"
    },
    
    -- Temps d'escorte (drag)
    EscortRange = 2.0
}
