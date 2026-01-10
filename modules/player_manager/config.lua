--[[
    vAvA_player_manager - Configuration
    Gestion complète des joueurs et personnages
]]

PlayerManagerConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRAL
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.General = {
    MaxCharacters = 5,                  -- Nombre maximum de personnages par compte
    DefaultMoney = {
        cash = 5000,                    -- Argent liquide de départ
        bank = 25000                    -- Argent en banque de départ
    },
    DefaultSpawn = vector4(-265.0, -963.6, 31.2, 205.0),  -- Spawn par défaut (Legion Square)
    EnableHardcore = false,             -- Mode hardcore (mort permanente)
    DeleteDeadCharacters = false,       -- Supprimer perso à la mort (hardcore)
    AllowCharacterTransfer = false      -- Permettre transfert entre comptes
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SÉLECTEUR DE PERSONNAGES
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Selector = {
    EnableBackground3D = true,          -- Afficher personnage en 3D
    CameraCoords = vector3(-813.97, 176.22, 77.74),  -- Position caméra sélecteur
    CameraRotation = vector3(0.0, 0.0, 200.0),
    CharacterSpawnCoords = vector4(-813.97, 175.22, 76.74, 180.0),  -- Spawn perso sélecteur
    EnableMusic = true,                 -- Musique d'ambiance
    MusicVolume = 0.3,                  -- Volume (0.0 - 1.0)
    ShowLastPlayed = true,              -- Afficher "Dernière connexion"
    ShowPlaytime = true,                -- Afficher temps de jeu
    AllowQuickJoin = true,              -- Rejoindre dernier perso (bouton)
    CharacterPreview = {
        EnableRotation = true,          -- Rotation personnage avec souris
        EnableZoom = true,              -- Zoom avec molette
        RotationSpeed = 2.0,
        ZoomSpeed = 0.5
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATION DE PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Creation = {
    AllowCustomDOB = true,              -- Date de naissance personnalisée
    MinAge = 18,                        -- Âge minimum
    MaxAge = 80,                        -- Âge maximum
    AllowGenderChange = true,           -- Changer sexe après création
    DefaultNationality = 'USA',         -- Nationalité par défaut
    Nationalities = {                   -- Nationalités disponibles
        'USA', 'France', 'UK', 'Canada', 'Mexico', 'Germany', 'Italy', 'Spain', 'Russia', 'China', 'Japan', 'Brazil'
    },
    StoryMode = true,                   -- Histoire de personnage
    StoryQuestions = {                  -- Questions pour histoire
        {question = 'Quelle était votre profession avant Los Santos?', maxLength = 200},
        {question = 'Pourquoi êtes-vous venu(e) à Los Santos?', maxLength = 200},
        {question = 'Quel est votre objectif principal?', maxLength = 200}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CARTE D'IDENTITÉ
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.IDCard = {
    RequireIDForInteractions = true,    -- ID obligatoire pour certaines actions
    ShowIDCommand = '/showid',          -- Commande pour montrer ID
    CheckIDCommand = '/checkid',        -- Commande pour vérifier ID
    IDCardItem = 'id_card',             -- Nom de l'item carte ID
    DriverLicenseItem = 'driver_license',
    EnablePhotoID = true,               -- Photo sur carte ID
    IDValidityDays = 0,                 -- Durée validité (0 = illimité)
    EnableDigitalID = true              -- ID numérique (téléphone)
}

-- ═══════════════════════════════════════════════════════════════════════════
-- LICENCES
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Licenses = {
    {
        name = 'driver',
        label = 'Permis de Conduire',
        description = 'Autorise la conduite de véhicules légers',
        cost = 5000,
        examRequired = true,
        examLocation = vector3(218.0, -1391.0, 30.6),  -- Auto-école
        examDuration = 300,             -- 5 minutes
        validityDays = 365,             -- 1 an
        canRevoke = true,
        suspensionDuration = 7          -- Jours de suspension (conduite dangereuse)
    },
    {
        name = 'weapon',
        label = 'Permis de Port d\'Arme',
        description = 'Autorise le port d\'armes légales',
        cost = 15000,
        examRequired = true,
        examLocation = vector3(811.0, -2160.0, 29.6),  -- Champ de tir
        examDuration = 600,             -- 10 minutes
        validityDays = 180,             -- 6 mois
        canRevoke = true,
        requiresCleanRecord = true      -- Casier vierge requis
    },
    {
        name = 'business',
        label = 'Licence Commerciale',
        description = 'Autorise l\'ouverture d\'un commerce',
        cost = 25000,
        examRequired = false,
        validityDays = 0,               -- Illimité
        canRevoke = true
    },
    {
        name = 'hunting',
        label = 'Permis de Chasse',
        description = 'Autorise la chasse d\'animaux sauvages',
        cost = 2000,
        examRequired = false,
        examLocation = vector3(-679.0, 5834.0, 17.3),  -- Paleto Bay
        validityDays = 365
    },
    {
        name = 'fishing',
        label = 'Permis de Pêche',
        description = 'Autorise la pêche commerciale',
        cost = 1500,
        examRequired = false,
        validityDays = 365
    },
    {
        name = 'pilot',
        label = 'Licence de Pilote',
        description = 'Autorise le pilotage d\'aéronefs',
        cost = 50000,
        examRequired = true,
        examLocation = vector3(-1652.0, -3142.0, 13.9),  -- Aéroport LSIA
        examDuration = 900,             -- 15 minutes
        validityDays = 365,
        canRevoke = true
    },
    {
        name = 'boat',
        label = 'Permis Bateau',
        description = 'Autorise la navigation de bateaux',
        cost = 8000,
        examRequired = true,
        examLocation = vector3(-1607.0, -1163.0, 1.0),  -- Marina
        examDuration = 300,
        validityDays = 365
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- STATISTIQUES
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Stats = {
    TrackPlaytime = true,               -- Suivre temps de jeu
    TrackDistance = true,               -- Suivre distance parcourue
    TrackVehicleDistance = true,        -- Distance en véhicule
    TrackDeaths = true,                 -- Nombre de morts
    TrackArrests = true,                -- Nombre d'arrestations
    TrackJobs = true,                   -- Historique emplois
    UpdateInterval = 60000,             -- Mise à jour stats (60s)
    
    Categories = {
        {name = 'playtime', label = 'Temps de jeu', unit = 'heures', icon = '⏱️'},
        {name = 'distance_walked', label = 'Distance à pied', unit = 'km', icon = '🚶'},
        {name = 'distance_driven', label = 'Distance en véhicule', unit = 'km', icon = '🚗'},
        {name = 'deaths', label = 'Nombre de morts', unit = '', icon = '💀'},
        {name = 'arrests', label = 'Arrestations', unit = '', icon = '👮'},
        {name = 'jobs_completed', label = 'Missions accomplies', unit = '', icon = '💼'},
        {name = 'money_earned', label = 'Argent gagné', unit = '$', icon = '💰'},
        {name = 'money_spent', label = 'Argent dépensé', unit = '$', icon = '💸'}
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HISTORIQUE
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.History = {
    TrackJobChanges = true,             -- Suivre changements d'emploi
    TrackNameChanges = true,            -- Suivre changements de nom
    TrackBanks = true,                  -- Suivre transactions bancaires
    TrackProperties = true,             -- Suivre achat/vente propriétés
    TrackVehicles = true,               -- Suivre achat/vente véhicules
    HistoryRetention = 90,              -- Jours de rétention (0 = illimité)
    
    EventTypes = {
        'job_change',       -- Changement emploi
        'name_change',      -- Changement nom
        'bank_deposit',     -- Dépôt banque
        'bank_withdraw',    -- Retrait banque
        'bank_transfer',    -- Virement
        'property_buy',     -- Achat propriété
        'property_sell',    -- Vente propriété
        'vehicle_buy',      -- Achat véhicule
        'vehicle_sell',     -- Vente véhicule
        'arrest',           -- Arrestation
        'fine',             -- Amende
        'jail',             -- Prison
        'death',            -- Mort
        'revive'            -- Réanimation
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- APPARENCE
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Appearance = {
    AllowPlasticSurgery = true,         -- Permettre chirurgie esthétique
    PlasticSurgeryCost = 50000,         -- Coût chirurgie
    PlasticSurgeryLocations = {
        vector3(341.0, -584.0, 74.0),   -- Pillbox Hospital
        vector3(-448.0, -340.0, 34.0)   -- Rockford Hills (cabinet privé)
    },
    AllowTattooShops = true,
    AllowBarberShops = true,
    AllowClothingStores = true,
    SaveOutfits = true,                 -- Sauvegarder tenues
    MaxOutfits = 10                     -- Nombre max tenues
}

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Commands = {
    {command = 'characters', label = 'Ouvrir sélecteur personnages', adminOnly = false},
    {command = 'deletechar', label = 'Supprimer personnage', adminOnly = true},
    {command = 'resetchar', label = 'Réinitialiser personnage', adminOnly = true},
    {command = 'givelicense', label = 'Donner licence', adminOnly = true},
    {command = 'revokelicense', label = 'Révoquer licence', adminOnly = true},
    {command = 'showid', label = 'Montrer carte ID', adminOnly = false},
    {command = 'checkid', label = 'Vérifier carte ID', adminOnly = false},
    {command = 'showlicenses', label = 'Voir mes licences', adminOnly = false},
    {command = 'stats', label = 'Voir statistiques', adminOnly = false}
}

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════

PlayerManagerConfig.Notifications = {
    CharacterCreated = 'Personnage créé avec succès!',
    CharacterDeleted = 'Personnage supprimé',
    CharacterSelected = 'Bienvenue %s %s',
    LicenseObtained = 'Vous avez obtenu: %s',
    LicenseRevoked = 'Votre licence %s a été révoquée',
    LicenseExpired = 'Votre licence %s a expiré',
    IDShown = 'Vous avez montré votre carte d\'identité',
    StatsUpdated = 'Statistiques mises à jour'
}

return PlayerManagerConfig
