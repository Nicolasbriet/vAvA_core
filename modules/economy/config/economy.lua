-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Configuration Économie
-- Fichier central contrôlant toute l'économie du serveur
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig = {}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎚️ MULTIPLICATEUR GLOBAL (MODIFIER TOUTE L'ÉCONOMIE EN 1 LIGNE)
-- ══════════════════════════════════════════════════════════════════════════════
-- baseMultiplier = 1.0  → Économie normale
-- baseMultiplier = 0.5  → Économie hardcore (tout coûte moitié prix, salaires divisés par 2)
-- baseMultiplier = 2.0  → Économie riche (tout coûte double, salaires doublés)
-- baseMultiplier = 5.0  → Économie ultra-riche

EconomyConfig.baseMultiplier = 1.0

-- ══════════════════════════════════════════════════════════════════════════════
-- 📊 PROFILS ÉCONOMIQUES PRÉDÉFINIS
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.profiles = {
    hardcore = 0.5,
    normal = 1.0,
    riche = 2.0,
    ultra_riche = 5.0
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 💰 RÈGLE FONDAMENTALE
-- ══════════════════════════════════════════════════════════════════════════════
-- 1 unité = 1 minute de travail d'un job basique
-- Cette règle garantit la cohérence de toute l'économie

EconomyConfig.baseUnit = 1 -- Prix de base

-- ══════════════════════════════════════════════════════════════════════════════
-- 💼 SALAIRES DES JOBS
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.jobs = {
    -- Jobs de base
    unemployed = {
        baseSalary = 50,
        bonus = 1.0,
        essential = false
    },
    
    -- Jobs essentiels (bonus x1.5)
    ambulance = {
        baseSalary = 150,
        bonus = 1.5,
        essential = true
    },
    
    police = {
        baseSalary = 150,
        bonus = 1.5,
        essential = true
    },
    
    mechanic = {
        baseSalary = 120,
        bonus = 1.3,
        essential = true
    },
    
    -- Jobs RP standard
    taxi = {
        baseSalary = 100,
        bonus = 1.0,
        essential = false
    },
    
    livreur = {
        baseSalary = 90,
        bonus = 1.0,
        essential = false
    },
    
    serveur = {
        baseSalary = 80,
        bonus = 1.0,
        essential = false
    },
    
    -- Jobs illégaux (bonus variable)
    gang = {
        baseSalary = 0,
        bonus = 0.0,
        essential = false
    }
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛍️ MULTIPLICATEURS PAR SHOP
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.shops = {
    -- Vêtements
    binco = 0.8,          -- Zone populaire
    suburban = 1.2,       -- Zone moyenne
    ponsonbys = 2.0,      -- Luxe
    
    -- Alimentation
    supermarket = 1.0,
    liquorstore = 1.1,
    
    -- Armes
    gunstore = 1.5,
    blackmarket = 2.5,
    
    -- Véhicules
    dealership_low = 0.9,
    dealership_mid = 1.2,
    dealership_premium = 2.0,
    dealership_luxury = 3.0,
    
    -- Autres
    hardware = 1.0,
    pharmacy = 1.2
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 💳 TAXES
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.taxes = {
    achat = 0.05,        -- 5% sur les achats
    vente = 0.03,        -- 3% sur les ventes
    salaire = 0.02,      -- 2% sur les salaires
    transfert = 0.01,    -- 1% sur les transferts bancaires
    vehicule = 0.10,     -- 10% sur l'achat de véhicules
    immobilier = 0.15    -- 15% sur l'achat immobilier
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 RARETÉ DES ITEMS (1-10)
-- ══════════════════════════════════════════════════════════════════════════════
-- Plus un item est rare, plus son prix est élevé
-- Le prix final est calculé automatiquement: rareté × baseMultiplier × shopMultiplier

EconomyConfig.itemsRarity = {
    -- Nourriture (rareté 1-2)
    bread = { rarity = 1, category = 'food', basePrice = 2 },
    water = { rarity = 1, category = 'drink', basePrice = 1 },
    sandwich = { rarity = 2, category = 'food', basePrice = 5 },
    burger = { rarity = 2, category = 'food', basePrice = 8 },
    pizza = { rarity = 3, category = 'food', basePrice = 12 },
    
    -- Boissons (rareté 1-3)
    coffee = { rarity = 2, category = 'drink', basePrice = 3 },
    soda = { rarity = 2, category = 'drink', basePrice = 3 },
    beer = { rarity = 3, category = 'drink', basePrice = 5 },
    wine = { rarity = 4, category = 'drink', basePrice = 15 },
    
    -- Vêtements (rareté 2-5)
    tshirt = { rarity = 2, category = 'clothing', basePrice = 10 },
    jeans = { rarity = 2, category = 'clothing', basePrice = 15 },
    jacket = { rarity = 3, category = 'clothing', basePrice = 30 },
    suit = { rarity = 5, category = 'clothing', basePrice = 100 },
    
    -- Outils (rareté 3-6)
    lockpick = { rarity = 4, category = 'tool', basePrice = 50 },
    drill = { rarity = 5, category = 'tool', basePrice = 150 },
    repair_kit = { rarity = 3, category = 'tool', basePrice = 30 },
    
    -- Armes (rareté 6-8)
    pistol = { rarity = 6, category = 'weapon', basePrice = 500 },
    smg = { rarity = 7, category = 'weapon', basePrice = 1500 },
    rifle = { rarity = 8, category = 'weapon', basePrice = 3000 },
    
    -- Items rares (rareté 8-10)
    gold = { rarity = 8, category = 'rare', basePrice = 2000 },
    diamond = { rarity = 10, category = 'rare', basePrice = 5000 },
    
    -- Drogues (rareté 5-7)
    weed = { rarity = 5, category = 'drug', basePrice = 100 },
    coke = { rarity = 7, category = 'drug', basePrice = 500 },
    
    -- Médical (rareté 4-6)
    bandage = { rarity = 3, category = 'medical', basePrice = 20 },
    medkit = { rarity = 5, category = 'medical', basePrice = 100 },
    
    -- Money (spécial)
    money = { rarity = 1, category = 'money', basePrice = 1 },
    black_money = { rarity = 1, category = 'money', basePrice = 1 }
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔄 SYSTÈME AUTO-ADAPTATIF
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.autoAdjust = {
    enabled = true,                    -- Activer l'ajustement automatique
    interval = 86400,                  -- Intervalle de recalcul (en secondes) - 24h
    maxVariation = 0.10,               -- Variation maximale par cycle (±10%)
    
    -- Facteurs d'ajustement
    factors = {
        buyRate = 0.05,                -- Impact du taux d'achat
        sellRate = 0.05,               -- Impact du taux de vente
        circulation = 0.03,            -- Impact de la quantité en circulation
        playerActivity = 0.02          -- Impact de l'activité des joueurs
    },
    
    -- Limites de prix
    minPrice = 1,                      -- Prix minimum
    maxPrice = 10000,                  -- Prix maximum
    
    -- Limites de salaire
    minSalary = 10,                    -- Salaire minimum
    maxSalary = 5000                   -- Salaire maximum
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 📈 INFLATION
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.inflation = {
    enabled = true,                    -- Activer l'inflation
    rate = 0.001,                      -- Taux d'inflation par jour (0.1%)
    maxInflation = 2.0,                -- Inflation maximale (200%)
    minInflation = 0.5                 -- Inflation minimale (50%)
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔐 SÉCURITÉ
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.security = {
    logAllChanges = true,              -- Logger tous les changements
    requireConfirmation = true,        -- Confirmation pour actions critiques
    cooldownRecalculate = 3600,        -- Cooldown recalcul manuel (1h)
    maxPriceOverride = 10000,          -- Prix max pour override manuel
    adminOnly = true                   -- Réservé aux admins
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎨 INTERFACE ADMIN
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.ui = {
    theme = 'dark',                    -- dark / light
    language = 'fr',                   -- fr / en / es
    graphDays = 30,                    -- Jours affichés dans les graphiques
    refreshInterval = 5000,            -- Intervalle de refresh (ms)
    animationSpeed = 300               -- Vitesse des animations (ms)
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 📊 MONITORING
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.monitoring = {
    enabled = true,                    -- Activer le monitoring
    alertThreshold = {
        priceChange = 0.20,            -- Alerte si prix varie de +20%
        inflationChange = 0.10,        -- Alerte si inflation varie de +10%
        salaryChange = 0.15            -- Alerte si salaire varie de +15%
    }
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔧 DEBUG
-- ══════════════════════════════════════════════════════════════════════════════

EconomyConfig.debug = false           -- Mode debug (logs détaillés)
