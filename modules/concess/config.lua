--[[
    vAvA Core - Module Concessionnaire
    Configuration du système de vente de véhicules
]]

ConcessConfig = {}

-- Configuration générale
ConcessConfig.General = {
    -- Distance pour afficher les marqueurs et messages
    InteractionDistance = 2.0,
    -- Distance pour afficher les blips sur la carte
    BlipDisplayDistance = 100.0,
    -- Touche d'interaction (38 = E)
    InteractionKey = 38,
    -- Délai minimum entre deux ouvertures (ms)
    ReopenDelay = 500
}

-- Configuration des clés de véhicules
ConcessConfig.VehicleKeys = {
    Enabled = true,
    -- Utiliser le module keys intégré ou un externe
    UseIntegratedKeys = true,
    -- Si externe, configurer ici
    ExternalResource = 'vAvA_keys',
    ExportName = 'GiveKeys'
}

-- Configuration de la persistance des véhicules
ConcessConfig.Persistence = {
    Enabled = true,
    -- Utiliser le module persist intégré ou un externe
    UseIntegratedPersist = true,
    ExternalResource = 'vAvA_persist'
}

-- Configuration des paiements
ConcessConfig.Payment = {
    -- Types de paiement disponibles
    Methods = {'cash', 'bank'},
    -- Textes affichés
    Labels = {
        cash = 'Espèces',
        bank = 'Virement bancaire'
    }
}

-- Configuration des permissions admin
-- Utiliser les groupes vCore ou les licenses spécifiques
ConcessConfig.Admin = {
    -- Utiliser les groupes du core (admin, superadmin, etc.)
    UseVCoreGroups = true,
    AllowedGroups = {'admin', 'superadmin', 'developer'},
    -- Ou utiliser les licenses spécifiques
    UseLicenses = false,
    Licenses = {
        -- ["license_hash"] = true
    }
}

-- Configuration des concessionnaires
ConcessConfig.Dealerships = {
    -- VOITURES CIVILES
    ['cars_civilian'] = {
        name = "Concessionnaire Voitures",
        vehicleType = 'cars',
        isJobOnly = false,
        
        -- Position du marqueur d'interaction
        position = vector3(-56.79, -1096.67, 27.44),
        
        -- Configuration du marqueur
        marker = {
            type = 36,
            scale = vector3(1.5, 1.5, 1.0),
            color = {r = 0, g = 255, b = 0, a = 100},
            bobUpAndDown = false,
            faceCamera = true,
            rotate = false
        },
        
        -- Message d'interaction
        helpText = "Appuie sur [E] pour ouvrir le concessionnaire",
        
        -- Configuration du blip sur la carte
        blip = {
            enabled = true,
            sprite = 326,
            color = 2,
            scale = 0.8,
            shortRange = true,
            name = "Concessionnaire Voitures"
        },
        
        -- Position de spawn des véhicules preview
        previewSpawn = {
            coords = vector3(-42.53, -1098.4, 26.42),
            heading = 103.04
        },
        
        -- Configuration de la caméra
        camera = {
            coords = vector3(-48.5, -1098.5, 26.8),
            rotation = vector3(-5.0, 0.0, 265.0)
        },
        
        -- Position de spawn pour les véhicules achetés
        vehicleSpawn = {
            coords = vector3(-51.95, -1074.56, 27.03),
            heading = 65.0
        }
    },

    -- VOITURES JOB
    ['cars_job'] = {
        name = "Concessionnaire Voitures (Job)",
        vehicleType = 'cars',
        isJobOnly = true,
        
        position = vector3(-31.83, -1110.47, 27.42),
        
        marker = {
            type = 36,
            scale = vector3(1.5, 1.5, 1.0),
            color = {r = 255, g = 165, b = 0, a = 100},
            bobUpAndDown = false,
            faceCamera = true,
            rotate = false
        },
        
        helpText = "Appuie sur [E] pour le concessionnaire de service",
        
        blip = {
            enabled = true,
            sprite = 326,
            color = 17,
            scale = 0.8,
            shortRange = true,
            name = "Concessionnaire Job"
        },
        
        previewSpawn = {
            coords = vector3(-42.53, -1098.4, 26.42),
            heading = 103.04
        },
        
        camera = {
            coords = vector3(-48.5, -1098.5, 26.8),
            rotation = vector3(-5.0, 0.0, 265.0)
        },
        
        vehicleSpawn = {
            coords = vector3(-51.95, -1074.56, 27.03),
            heading = 65.0
        }
    },

    -- BATEAUX CIVILS
    ['boats_civilian'] = {
        name = "Concessionnaire Bateaux",
        vehicleType = 'boats',
        isJobOnly = false,
        
        position = vector3(-815.45, -1346.69, 6.15),
        
        marker = {
            type = 36,
            scale = vector3(1.5, 1.5, 1.0),
            color = {r = 0, g = 191, b = 255, a = 100},
            bobUpAndDown = false,
            faceCamera = true,
            rotate = false
        },
        
        helpText = "Appuie sur [E] pour le concessionnaire de bateaux",
        
        blip = {
            enabled = true,
            sprite = 427,
            color = 3,
            scale = 0.8,
            shortRange = true,
            name = "Concessionnaire Bateaux"
        },
        
        previewSpawn = {
            coords = vector3(-854.68, -1336.95, -0.47),
            heading = 105.9
        },
        
        camera = {
            coords = vector3(-856.74, -1332.24, 1.6),
            rotation = vector3(0.0, 0.0, 180.0)
        },
        
        vehicleSpawn = {
            coords = vector3(-854.68, -1336.95, -0.47),
            heading = 105.9
        }
    },

    -- HELICOPTERES CIVILS
    ['helicopters_civilian'] = {
        name = "Concessionnaire Hélicoptères",
        vehicleType = 'helicopters',
        isJobOnly = false,
        
        position = vector3(-743.29, -1507.92, 6.0),
        
        marker = {
            type = 36,
            scale = vector3(1.5, 1.5, 1.0),
            color = {r = 255, g = 0, b = 255, a = 100},
            bobUpAndDown = false,
            faceCamera = true,
            rotate = false
        },
        
        helpText = "Appuie sur [E] pour le concessionnaire d'hélicoptères",
        
        blip = {
            enabled = true,
            sprite = 43,
            color = 13,
            scale = 0.8,
            shortRange = true,
            name = "Concessionnaire Hélicoptères"
        },
        
        previewSpawn = {
            coords = vector3(-745.56, -1469.49, 15.0),
            heading = 330.0
        },
        
        camera = {
            coords = vector3(-733.85, -1477.67, 5.0),
            rotation = vector3(-10.0, 1.0, 50.0)
        },
        
        vehicleSpawn = {
            coords = vector3(-745.56, -1469.49, 10.0),
            heading = 330.0
        }
    },

    -- AVIONS CIVILS
    ['planes_civilian'] = {
        name = "Concessionnaire Avions",
        vehicleType = 'planes',
        isJobOnly = false,
        
        position = vector3(-940.88, -2954.18, 13.95),
        
        marker = {
            type = 36,
            scale = vector3(1.5, 1.5, 1.0),
            color = {r = 255, g = 255, b = 0, a = 100},
            bobUpAndDown = false,
            faceCamera = true,
            rotate = false
        },
        
        helpText = "Appuie sur [E] pour le concessionnaire d'avions",
        
        blip = {
            enabled = true,
            sprite = 90,
            color = 5,
            scale = 0.8,
            shortRange = true,
            name = "Concessionnaire Avions"
        },
        
        previewSpawn = {
            coords = vector3(-977.72, -2996.96, 14.55),
            heading = 61.89
        },
        
        camera = {
            coords = vector3(-1038.0, -2668.0, 18.0),
            rotation = vector3(-5.0, 0.0, 60.0)
        },
        
        vehicleSpawn = {
            coords = vector3(-1056.67, -3041.93, 14.55),
            heading = 61.25
        }
    }
}

-- Configuration des catégories par type de véhicule
ConcessConfig.Categories = {
    ['cars'] = {'compacts', 'sedans', 'suvs', 'coupes', 'muscle', 'sports', 'super', 'motorcycles', 'offroad', 'utility', 'vans', 'classics', 'drift'},
    ['boats'] = {'boats'},
    ['helicopters'] = {'helicopters'},
    ['planes'] = {'planes'}
}

-- Types de véhicule pour la BDD
ConcessConfig.VehicleTypeDB = {
    ['cars'] = 'car',
    ['boats'] = 'boat',
    ['helicopters'] = 'helicopter',
    ['planes'] = 'plane'
}

-- Configuration des sprites de blips
ConcessConfig.BlipSprites = {
    ['cars'] = 326,
    ['boats'] = 427,
    ['helicopters'] = 43,
    ['planes'] = 90
}
