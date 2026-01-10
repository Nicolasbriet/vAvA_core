EMSConfig = {}

-- ========================================
-- CONFIGURATION GÉNÉRALE
-- ========================================

EMSConfig.Debug = false
EMSConfig.Locale = 'fr'

-- Job EMS requis
EMSConfig.EMSJob = 'ambulance'

-- ========================================
-- SYSTÈME MÉDICAL
-- ========================================

-- États possibles du joueur
EMSConfig.MedicalStates = {
    NORMAL = 'normal',
    LIGHT_PAIN = 'light_pain',
    MODERATE_PAIN = 'moderate_pain',
    SEVERE_PAIN = 'severe_pain',
    BLEEDING = 'bleeding',
    UNCONSCIOUS = 'unconscious',
    COMA = 'coma',
    CARDIAC_ARREST = 'cardiac_arrest',
    DEAD = 'dead'
}

-- Signes vitaux normaux
EMSConfig.NormalVitalSigns = {
    pulse = 75,              -- BPM (40-180)
    bloodPressureSystolic = 120,
    bloodPressureDiastolic = 80,
    oxygenSaturation = 98,   -- % (0-100)
    temperature = 37.0,      -- °C (35-42)
    painLevel = 0,           -- 0-10
    bloodVolume = 100        -- % (0-100, critique < 60%)
}

-- Limites critiques
EMSConfig.CriticalLimits = {
    pulse = { min = 40, max = 180, critical_low = 50, critical_high = 150 },
    bloodPressureSystolic = { min = 80, max = 200, critical_low = 90, critical_high = 160 },
    oxygenSaturation = { min = 0, max = 100, critical_low = 90 },
    temperature = { min = 35.0, max = 42.0, critical_low = 36.0, critical_high = 39.0 },
    bloodVolume = { min = 0, max = 100, critical = 60 }
}

-- Perte de sang par seconde selon type
EMSConfig.BleedingRates = {
    none = 0,
    slow = 0.05,      -- 0.05% par seconde
    active = 0.15,    -- 0.15% par seconde
    critical = 0.50   -- 0.50% par seconde
}

-- Effets selon l'état
EMSConfig.StateEffects = {
    light_pain = {
        moveSpeed = 0.95,     -- 5% plus lent
        stamina = 0.85        -- 15% stamina en moins
    },
    moderate_pain = {
        moveSpeed = 0.85,
        stamina = 0.60,
        screenShake = true
    },
    severe_pain = {
        moveSpeed = 0.70,
        stamina = 0.40,
        screenShake = true,
        blurredVision = true
    },
    bleeding = {
        damagePerSecond = 0.1  -- 0.1 HP par seconde
    },
    unconscious = {
        canMove = false,
        canShoot = false,
        ragdoll = true
    }
}

-- ========================================
-- SYSTÈME DE BLESSURES
-- ========================================

EMSConfig.InjuryTypes = {
    'contusion',          -- Bleus, impacts légers
    'open_wound',         -- Coupures, lacérations
    'simple_fracture',    -- Fracture fermée
    'open_fracture',      -- Fracture avec exposition osseuse
    'gunshot_entry',      -- Blessure par balle (entrée)
    'gunshot_exit',       -- Blessure par balle (sortie)
    'burn_first',         -- Brûlure 1er degré
    'burn_second',        -- Brûlure 2e degré
    'burn_third',         -- Brûlure 3e degré
    'head_trauma',        -- Traumatisme crânien
    'internal_injury',    -- Lésion interne
    'internal_bleeding'   -- Hémorragie interne
}

-- Parties du corps
EMSConfig.BodyParts = {
    'head',        -- Critique, affecte vision et conscience
    'neck',        -- Très critique
    'chest',       -- Affecte respiration et cœur
    'abdomen',     -- Risque hémorragie interne
    'left_arm',    -- Limite utilisation
    'right_arm',   -- Limite utilisation
    'left_leg',    -- Affecte mobilité
    'right_leg'    -- Affecte mobilité
}

-- Sévérité des blessures
EMSConfig.InjurySeverity = {
    MINOR = 1,      -- Légère
    MODERATE = 2,   -- Modérée
    SEVERE = 3,     -- Sévère
    CRITICAL = 4    -- Critique
}

-- Effets des blessures par localisation
EMSConfig.InjuryEffects = {
    head = {
        blurredVision = true,
        consciousnessLoss = 0.20  -- 20% chance perte conscience
    },
    chest = {
        breathingDifficulty = true,
        oxygenPenalty = 10         -- -10% O2 saturation
    },
    abdomen = {
        internalBleedingRisk = 0.30  -- 30% risque hémorragie interne
    },
    left_leg = {
        limping = true,
        moveSpeedPenalty = 0.25    -- -25% vitesse
    },
    right_leg = {
        limping = true,
        moveSpeedPenalty = 0.25
    },
    left_arm = {
        aimPenalty = 0.30,         -- -30% précision
        reloadPenalty = 0.40       -- -40% vitesse rechargement
    },
    right_arm = {
        aimPenalty = 0.30,
        reloadPenalty = 0.40
    }
}

-- ========================================
-- GROUPES SANGUINS
-- ========================================

EMSConfig.BloodTypes = {
    'O-', 'O+',
    'A-', 'A+',
    'B-', 'B+',
    'AB-', 'AB+'
}

-- Compatibilité transfusion
EMSConfig.BloodCompatibility = {
    ['O-'] = { 'O-' },
    ['O+'] = { 'O-', 'O+' },
    ['A-'] = { 'O-', 'A-' },
    ['A+'] = { 'O-', 'O+', 'A-', 'A+' },
    ['B-'] = { 'O-', 'B-' },
    ['B+'] = { 'O-', 'O+', 'B-', 'B+' },
    ['AB-'] = { 'O-', 'A-', 'B-', 'AB-' },
    ['AB+'] = { 'O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+' }  -- Receveur universel
}

-- Stock initial hôpital (en unités)
EMSConfig.InitialBloodStock = {
    ['O-'] = 20,
    ['O+'] = 30,
    ['A-'] = 15,
    ['A+'] = 25,
    ['B-'] = 10,
    ['B+'] = 20,
    ['AB-'] = 5,
    ['AB+'] = 15
}

-- Don de sang
EMSConfig.BloodDonation = {
    enabled = true,
    cooldown = 56 * 24 * 60 * 60,  -- 56 jours en secondes
    unitsPerDonation = 1,
    reward = 100,                   -- Argent en compensation
    minHealth = 80,                 -- Santé minimale pour donner
    effectDuration = 300,           -- 5 minutes d'effets post-don
    effects = {
        fatigue = true,
        moveSpeedPenalty = 0.10     -- -10% vitesse temporaire
    }
}

-- ========================================
-- MATÉRIEL MÉDICAL
-- ========================================

EMSConfig.MedicalEquipment = {
    -- Équipement basique (Stagiaire, Ambulancier)
    basic = {
        { name = 'medical_gloves', label = 'Gants médicaux', required = true },
        { name = 'bandage', label = 'Bandage', heals = 10, stops_bleeding = 'slow' },
        { name = 'splint', label = 'Attelle', fixes = 'simple_fracture' },
        { name = 'antiseptic', label = 'Antiseptique', prevents = 'infection' },
        { name = 'oxygen_portable', label = 'Oxygène portable', restores_o2 = 20 },
        { name = 'compress', label = 'Pansement compressif', stops_bleeding = 'active' }
    },
    
    -- Équipement avancé (Paramedic, Médecin)
    advanced = {
        { name = 'defibrillator', label = 'Défibrillateur', revives = true, grade = 2 },
        { name = 'iv_nacl', label = 'Perfusion NaCl', restores_blood = 10 },
        { name = 'iv_plasma', label = 'Perfusion Plasma', restores_blood = 15 },
        { name = 'iv_ringer', label = 'Ringer Lactate', restores_blood = 20 },
        { name = 'morphine', label = 'Morphine', reduces_pain = 5 },
        { name = 'adrenaline', label = 'Adrénaline', stabilizes = true },
        { name = 'suture_kit', label = 'Kit de suture', heals = 30, stops_bleeding = 'critical' },
        { name = 'chest_kit', label = 'Kit thoracique', fixes = 'pneumothorax' },
        { name = 'backboard', label = 'Planche dorsale', stabilizes_spine = true }
    },
    
    -- Équipement critique (Médecin, Chirurgien)
    critical = {
        { name = 'intubation_kit', label = 'Kit d\'intubation', ventilation = true, grade = 3 },
        { name = 'ventilator', label = 'Ventilateur mécanique', prolonged_ventilation = true },
        { name = 'surgery_kit', label = 'Kit chirurgie d\'urgence', surgery = true },
        { name = 'resuscitation_kit', label = 'Kit réanimation avancée', advanced_resus = true },
        { name = 'ultrasound', label = 'Échographie portable', diagnoses = 'internal_bleeding' },
        { name = 'transfusion_kit', label = 'Kit transfusion', transfusion = true }
    }
}

-- Grades EMS requis par équipement
EMSConfig.EquipmentGrades = {
    [0] = 'basic',      -- Stagiaire
    [1] = 'basic',      -- Ambulancier
    [2] = 'advanced',   -- Paramedic
    [3] = 'critical',   -- Médecin
    [4] = 'critical'    -- Chirurgien
}

-- ========================================
-- VÉHICULES EMS
-- ========================================

EMSConfig.Vehicles = {
    ambulance = {
        label = 'Ambulance standard',
        model = 'ambulance',
        equipment = { 'basic', 'advanced' },
        spawn = vector4(307.7, -1433.4, 29.9, 230.0)
    },
    ambulance2 = {
        label = 'Ambulance de réanimation',
        model = 'ambulance2',
        equipment = { 'basic', 'advanced', 'critical' },
        spawn = vector4(297.3, -1431.5, 29.9, 230.0)
    },
    polmav = {
        label = 'Hélicoptère médical',
        model = 'polmav',
        equipment = { 'advanced', 'critical' },
        spawn = vector4(351.58, -587.45, 74.16, 252.0)
    }
}

-- ========================================
-- HÔPITAL
-- ========================================

EMSConfig.Hospital = {
    main = {
        name = 'Pillbox Hill Medical Center',
        coords = vector3(304.27, -600.33, 43.28),
        blip = { sprite = 61, color = 1, scale = 1.0 }
    },
    
    -- Zones hospitalières
    zones = {
        reception = vector3(307.92, -595.26, 43.28),
        emergency = vector3(298.60, -584.45, 43.28),
        triage = vector3(310.64, -571.46, 43.28),
        surgery = vector3(324.49, -580.05, 43.28),
        icu = vector3(325.31, -570.74, 43.28),
        pharmacy = vector3(309.59, -598.47, 43.28),
        radiology = vector3(327.23, -603.32, 43.28),
        laboratory = vector3(315.44, -593.16, 43.28),
        bloodbank = vector3(306.47, -602.11, 43.28)
    },
    
    -- Lits d'hôpital
    beds = {
        { coords = vector4(317.67, -585.37, 43.28, 160.0), occupied = false },
        { coords = vector4(314.47, -584.20, 43.28, 160.0), occupied = false },
        { coords = vector4(311.00, -582.90, 43.28, 160.0), occupied = false },
        { coords = vector4(307.70, -581.75, 43.28, 160.0), occupied = false },
        { coords = vector4(322.62, -587.17, 43.28, 160.0), occupied = false },
        { coords = vector4(319.55, -585.96, 43.28, 160.0), occupied = false }
    },
    
    -- Coûts hospitaliers
    costs = {
        checkup = 50,           -- Consultation
        emergency = 500,        -- Urgences
        surgery = 2500,         -- Chirurgie
        hospitalization = 1000, -- Hospitalisation par jour RP
        bloodTransfusion = 500
    }
}

-- ========================================
-- SYSTÈME D'APPELS D'URGENCE
-- ========================================

EMSConfig.EmergencyCalls = {
    enabled = true,
    autoDetect = true,          -- Détection automatique joueur inconscient
    autoDetectDelay = 30,       -- 30 secondes avant alerte auto
    cooldown = 60,              -- Cooldown entre appels (secondes)
    
    -- Types d'alertes
    codes = {
        RED = { priority = 1, label = 'Code Rouge', color = '#FF0000' },      -- Arrêt cardiaque
        ORANGE = { priority = 2, label = 'Code Orange', color = '#FF8800' },  -- Inconscient
        YELLOW = { priority = 3, label = 'Code Jaune', color = '#FFFF00' },   -- Blessé
        BLUE = { priority = 4, label = 'Code Bleu', color = '#00AAFF' }       -- Assistance
    }
}

-- ========================================
-- RESPAWN & MORT
-- ========================================

EMSConfig.Death = {
    enablePermadeath = false,        -- Mort RP définitive
    unconsciousTime = 300,           -- 5 minutes inconscient avant mort
    respawnCost = 5000,              -- Coût respawn hôpital
    respawnLocation = vector4(341.89, -581.32, 43.28, 255.0),
    loseInventory = false,           -- Perte inventaire à la mort
    loseMoneyPercent = 10            -- Perte 10% argent liquide
}

-- ========================================
-- ANIMATIONS
-- ========================================

EMSConfig.Animations = {
    examine = { dict = 'amb@medic@standing@kneel@base', anim = 'base', flag = 1 },
    treat = { dict = 'amb@medic@standing@tendtodead@base', anim = 'base', flag = 1 },
    cpr = { dict = 'mini@cpr@char_a@cpr_str', anim = 'cpr_pumpchest', flag = 1 },
    bandage = { dict = 'anim@gangops@facility@servers@bodysearch@', anim = 'player_search', flag = 1 },
    inject = { dict = 'mp_arresting', anim = 'a_uncuff', flag = 16 },
    revive = { dict = 'mini@cpr@char_a@cpr_str', anim = 'cpr_success', flag = 1 }
}

-- ========================================
-- SYSTÈME DE SAUVEGARDES
-- ========================================

EMSConfig.Save = {
    interval = 300,  -- Sauvegarde auto toutes les 5 minutes
    onDeath = true,
    onDisconnect = true
}

-- ========================================
-- HUD EMS
-- ========================================

EMSConfig.HUD = {
    enabled = true,
    onlyForEMS = true,           -- HUD visible uniquement pour EMS
    position = 'bottom-right',   -- top-left, top-right, bottom-left, bottom-right
    updateInterval = 1000,       -- Mise à jour toutes les 1 seconde
    showWhenDead = false
}

return EMSConfig
