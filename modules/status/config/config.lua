StatusConfig = {}

-- ========================================
-- CONFIGURATION GÉNÉRALE
-- ========================================

StatusConfig.Enabled = true

-- Interval de mise à jour (en minutes)
StatusConfig.UpdateInterval = 5 -- Toutes les 5 minutes

-- Décrémentation par interval
StatusConfig.Decrementation = {
    hunger = {
        min = 1,  -- Minimum
        max = 3   -- Maximum
    },
    thirst = {
        min = 2,  -- La soif descend plus vite
        max = 4
    }
}

-- ========================================
-- NIVEAUX ET EFFETS
-- ========================================

StatusConfig.Levels = {
    -- 70-100 : Normal (aucun effet)
    normal = {
        min = 70,
        max = 100,
        effects = {
            stamina = 1.0,  -- 100% stamina
            health = 0      -- Pas de perte de vie
        }
    },

    -- 40-70 : Léger inconfort
    light = {
        min = 40,
        max = 70,
        effects = {
            stamina = 0.85,  -- 85% stamina
            health = 0,
            message = true   -- Afficher message RP
        }
    },

    -- 20-40 : Avertissement
    warning = {
        min = 20,
        max = 40,
        effects = {
            stamina = 0.60,  -- 60% stamina
            health = 0,
            screenEffect = 'slight_blur',
            message = true
        }
    },

    -- 0-20 : Danger
    danger = {
        min = 0,
        max = 20,
        effects = {
            stamina = 0.30,  -- 30% stamina
            health = -1,     -- -1 HP toutes les 5 secondes
            screenEffect = 'heavy_blur',
            walkSpeed = 0.7, -- 70% vitesse marche
            message = true
        }
    },

    -- 0 : Effondrement
    collapse = {
        value = 0,
        effects = {
            knockout = true,  -- KO le joueur
            respawn = false   -- Pas de respawn auto (géré par ambulance)
        }
    }
}

-- ========================================
-- ITEMS CONSOMMABLES
-- ========================================

StatusConfig.ConsumableItems = {
    -- Nourriture
    bread = { hunger = 15, thirst = 0, animation = 'eat' },
    sandwich = { hunger = 30, thirst = 0, animation = 'eat' },
    burger = { hunger = 45, thirst = 0, animation = 'eat' },
    pizza = { hunger = 50, thirst = 0, animation = 'eat' },
    hotdog = { hunger = 35, thirst = 0, animation = 'eat' },
    taco = { hunger = 40, thirst = 0, animation = 'eat' },
    donut = { hunger = 20, thirst = 0, animation = 'eat' },
    apple = { hunger = 10, thirst = 5, animation = 'eat' },
    orange = { hunger = 10, thirst = 5, animation = 'eat' },
    chips = { hunger = 15, thirst = -5, animation = 'eat' }, -- Les chips donnent soif

    -- Boissons
    water = { hunger = 0, thirst = 25, animation = 'drink' },
    soda = { hunger = 0, thirst = 15, animation = 'drink' },
    coffee = { hunger = 5, thirst = 10, animation = 'drink' },
    juice = { hunger = 5, thirst = 20, animation = 'drink' },
    milk = { hunger = 10, thirst = 15, animation = 'drink' },
    beer = { hunger = 0, thirst = 10, animation = 'drink' }, -- À intégrer avec système alcool futur
    wine = { hunger = 0, thirst = 8, animation = 'drink' },
    whiskey = { hunger = 0, thirst = 5, animation = 'drink' },

    -- Items premium (restaurants)
    steak = { hunger = 60, thirst = 0, animation = 'eat' },
    pasta = { hunger = 55, thirst = 0, animation = 'eat' },
    salad = { hunger = 25, thirst = 10, animation = 'eat' },
    soup = { hunger = 30, thirst = 15, animation = 'eat' }
}

-- ========================================
-- ANIMATIONS
-- ========================================

StatusConfig.Animations = {
    eat = {
        dict = 'mp_player_inteat@burger',
        anim = 'mp_player_int_eat_burger',
        flags = 49,
        duration = 5000 -- 5 secondes
    },
    drink = {
        dict = 'mp_player_intdrink',
        anim = 'loop_bottle',
        flags = 49,
        duration = 3000 -- 3 secondes
    }
}

-- ========================================
-- EFFETS VISUELS
-- ========================================

StatusConfig.ScreenEffects = {
    slight_blur = {
        name = 'MenuMGHeistIn',
        duration = -1,  -- Permanent tant que le niveau est atteint
        intensity = 0.3
    },
    heavy_blur = {
        name = 'MenuMGHeistIn',
        duration = -1,
        intensity = 0.7
    }
}

-- ========================================
-- INTÉGRATION ÉCONOMIE
-- ========================================

StatusConfig.EconomyIntegration = true

-- Si true, les prix des items sont gérés par vava_economy
-- Si false, utilise les prix fixes ci-dessous
StatusConfig.UseEconomyPrices = true

-- Prix fixes (utilisés si EconomyIntegration = false)
StatusConfig.FixedPrices = {
    bread = 5,
    sandwich = 15,
    burger = 25,
    water = 5,
    soda = 8,
    coffee = 10
}

-- ========================================
-- HUD CONFIGURATION
-- ========================================

-- Note: Le HUD est géré par vAvA_core (client/hud.lua)
-- Le module status envoie uniquement les données via l'event 'vAvA_hud:updateStatus'

StatusConfig.HUD = {
    enabled = true  -- Active/désactive l'envoi des données au HUD
}

-- ========================================
-- SÉCURITÉ
-- ========================================

StatusConfig.Security = {
    antiCheat = true,              -- Active l'anti-cheat
    maxValueChange = 50,           -- Maximum de changement de valeur par action
    logSuspiciousActivity = true,  -- Logger les activités suspectes
    banOnCheat = false,            -- Ban automatique (false = kick seulement)
    minUpdateInterval = 100        -- Minimum ms entre deux updates (anti-spam)
}

-- ========================================
-- LOGGING
-- ========================================

StatusConfig.Logging = {
    enabled = true,
    logConsumption = true,     -- Logger la consommation d'items
    logLevelChanges = true,    -- Logger les changements de niveau (normal → warning, etc.)
    logDeath = true,           -- Logger les morts par faim/soif
    logAPI = false             -- Logger tous les appels API (debug uniquement)
}

-- ========================================
-- TESTBENCH INTEGRATION
-- ========================================

StatusConfig.TestMode = false  -- Activé automatiquement par vava_testbench

-- Configuration spéciale pour les tests
StatusConfig.TestConfig = {
    fastDecay = true,          -- Décrémentation rapide pour les tests
    decayMultiplier = 10,      -- 10x plus rapide
    skipAnimations = true,     -- Pas d'animations pendant les tests
    instantEffects = true      -- Effets appliqués instantanément
}

-- ========================================
-- MESSAGES RP
-- ========================================

StatusConfig.RPMessages = {
    light_hunger = {
        "Vous commencez à avoir faim...",
        "Votre estomac gargouille légèrement.",
        "Il serait temps de manger quelque chose."
    },
    warning_hunger = {
        "Vous avez très faim !",
        "Votre estomac vous fait mal, vous devez manger !",
        "Vous êtes affamé, trouvez de la nourriture rapidement !"
    },
    danger_hunger = {
        "Vous êtes au bord de l'évanouissement à cause de la faim !",
        "Vous ne tenez plus debout, mangez immédiatement !",
        "Votre corps est épuisé par le manque de nourriture !"
    },

    light_thirst = {
        "Vous commencez à avoir soif...",
        "Votre gorge est un peu sèche.",
        "Il serait temps de boire quelque chose."
    },
    warning_thirst = {
        "Vous avez très soif !",
        "Votre gorge est desséchée, vous devez boire !",
        "Vous êtes déshydraté, trouvez de l'eau rapidement !"
    },
    danger_thirst = {
        "Vous êtes au bord de l'évanouissement à cause de la soif !",
        "Vous ne tenez plus debout, buvez immédiatement !",
        "Votre corps est épuisé par la déshydratation !"
    }
}

return StatusConfig
