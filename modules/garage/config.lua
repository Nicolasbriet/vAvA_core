--[[
    vAvA Core - Module Garage
    Configuration du système de garage et fourrière
]]

GarageConfig = {}

-- Configuration générale
GarageConfig.General = {
    -- Distance d'interaction avec les garages
    InteractionDistance = 3.0,
    -- Prix pour sortir un véhicule de la fourrière
    ImpoundPrice = 500,
    -- Prix pour transférer un véhicule
    TransferPrice = 500,
    -- Temps de transfert en minutes
    TransferTime = 5,
    -- Réparer les véhicules à la sortie de fourrière
    RepairOnImpoundRelease = true,
    -- Spawn côté serveur (recommandé)
    ServerSideSpawn = true
}

-- Configuration des clés
GarageConfig.VehicleKeys = {
    Enabled = true,
    UseIntegratedKeys = true,
    ExternalResource = 'vAvA_keys'
}

-- Configuration des permissions admin
GarageConfig.Admin = {
    UseVCoreGroups = true,
    AllowedGroups = {'admin', 'superadmin', 'developer'}
}

-- Configuration des jobs autorisés pour la fourrière
GarageConfig.ImpoundJobs = {'police', 'mechanic'}

-- Garages statiques par défaut
GarageConfig.Garages = {
    -- Garage Legion Square
    ['legion'] = {
        label = "Parking Legion Square",
        position = vector3(215.83, -809.34, 30.73),
        vehicleType = 'car',
        showBlip = true,
        spawns = {
            vector4(220.0, -805.0, 30.5, 160.0),
            vector4(223.0, -805.0, 30.5, 160.0),
            vector4(226.0, -805.0, 30.5, 160.0)
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Parking Legion"
        }
    },
    
    -- Garage Pillbox
    ['pillbox'] = {
        label = "Parking Pillbox",
        position = vector3(275.23, -345.78, 44.91),
        vehicleType = 'car',
        showBlip = true,
        spawns = {
            vector4(280.0, -340.0, 44.5, 70.0),
            vector4(280.0, -343.0, 44.5, 70.0)
        },
        blip = {
            sprite = 357,
            color = 3,
            scale = 0.8,
            label = "Parking Pillbox"
        }
    },

    -- Garage Bateaux
    ['boat_marina'] = {
        label = "Marina",
        position = vector3(-793.89, -1510.81, 1.59),
        vehicleType = 'boat',
        showBlip = true,
        spawns = {
            vector4(-796.0, -1515.0, -0.5, 110.0),
            vector4(-799.0, -1520.0, -0.5, 110.0)
        },
        blip = {
            sprite = 410,
            color = 3,
            scale = 0.8,
            label = "Marina"
        }
    },

    -- Garage Hélicoptères
    ['heli_hospital'] = {
        label = "Héliport Hôpital",
        position = vector3(352.26, -587.63, 74.16),
        vehicleType = 'helicopter',
        showBlip = true,
        spawns = {
            vector4(352.26, -588.63, 74.16, 160.0)
        },
        blip = {
            sprite = 43,
            color = 3,
            scale = 0.8,
            label = "Héliport"
        }
    }
}

-- Fourrières
GarageConfig.Impounds = {
    ['fourriere'] = {
        label = "Fourrière Municipale",
        position = vector3(401.79, -1631.62, 29.29),
        vehicleType = 'car',
        spawns = {
            vector4(417.59, -1627.28, 29.29, 134.44),
            vector4(419.86, -1629.23, 29.29, 141.86),
            vector4(421.17, -1636.05, 29.29, 89.69),
            vector4(420.1, -1638.98, 29.29, 88.69),
            vector4(420.44, -1642.13, 29.29, 94.37)
        },
        blip = {
            sprite = 524,
            color = 1,
            scale = 0.8,
            label = "Fourrière"
        }
    },
    
    ['boat_impound'] = {
        label = "Fourrière Bateaux",
        position = vector3(-800.0, -1500.0, 1.0),
        vehicleType = 'boat',
        spawns = {
            vector4(-805.0, -1505.0, 0.5, 90.0),
            vector4(-810.0, -1510.0, 0.5, 90.0)
        },
        blip = {
            sprite = 410,
            color = 1,
            scale = 0.8,
            label = "Fourrière Bateaux"
        }
    },
    
    ['heli_impound'] = {
        label = "Fourrière Hélicoptères",
        position = vector3(-1000.0, -3000.0, 14.0),
        vehicleType = 'helicopter',
        spawns = {
            vector4(-1005.0, -3005.0, 14.0, 0.0),
            vector4(-1010.0, -3010.0, 14.0, 0.0)
        },
        blip = {
            sprite = 43,
            color = 1,
            scale = 0.8,
            label = "Fourrière Hélicoptères"
        }
    }
}

-- Types de véhicules
GarageConfig.VehicleTypes = {
    ['car'] = {label = "Voiture", icon = "fa-car"},
    ['boat'] = {label = "Bateau", icon = "fa-ship"},
    ['helicopter'] = {label = "Hélicoptère", icon = "fa-helicopter"},
    ['plane'] = {label = "Avion", icon = "fa-plane"}
}

-- Icônes des blips par type
GarageConfig.BlipSprites = {
    ['car'] = 357,
    ['boat'] = 410,
    ['helicopter'] = 43,
    ['plane'] = 90
}

-- Debug mode
GarageConfig.Debug = false
