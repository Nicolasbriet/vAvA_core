--[[
    vAvA Core - Module Jobs
    Configuration principale
]]

JobsConfig = {}

-- Debug mode
JobsConfig.Debug = false

-- Groupes admin pour la création de jobs
JobsConfig.AdminGroups = {'admin', 'god', 'superadmin'}

-- Distance d'interaction maximale
JobsConfig.InteractionDistance = 2.5

-- Distance de synchronisation des points
JobsConfig.SyncDistance = 150.0

-- Rafraîchissement automatique (en ms)
JobsConfig.RefreshInterval = 30000 -- 30 secondes

-- Activer les salaires automatiques
JobsConfig.EnablePaycheck = true
JobsConfig.PaycheckInterval = 600000 -- 10 minutes

-- Blips par défaut pour les jobs
JobsConfig.DefaultBlips = {
    ambulance = {
        sprite = 61,
        color = 1,
        scale = 0.8,
        label = 'Hôpital'
    },
    police = {
        sprite = 60,
        color = 29,
        scale = 0.8,
        label = 'Commissariat'
    },
    mechanic = {
        sprite = 446,
        color = 5,
        scale = 0.8,
        label = 'Garage'
    }
}

-- Markers par défaut
JobsConfig.DefaultMarkers = {
    duty = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 0, g = 255, b = 0, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    wardrobe = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 0, g = 100, b = 255, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    vehicle = {
        type = 27,
        size = {x = 2.0, y = 2.0, z = 1.0},
        color = {r = 255, g = 255, b = 0, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    storage = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 255, g = 150, b = 0, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    boss = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 255, g = 0, b = 0, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    shop = {
        type = 27,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 0, g = 255, b = 255, a = 100},
        bobUpAndDown = false,
        rotate = false
    },
    farm = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 100, g = 255, b = 100, a = 100},
        bobUpAndDown = true,
        rotate = false
    },
    craft = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 255, g = 100, b = 255, a = 100},
        bobUpAndDown = true,
        rotate = false
    },
    process = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 255, g = 150, b = 100, a = 100},
        bobUpAndDown = true,
        rotate = false
    },
    sell = {
        type = 1,
        size = {x = 1.5, y = 1.5, z = 1.0},
        color = {r = 100, g = 255, b = 100, a = 100},
        bobUpAndDown = true,
        rotate = false
    }
}

-- Animations par défaut
JobsConfig.DefaultAnimations = {
    farm = {
        dict = 'amb@world_human_gardener_plant@male@base',
        anim = 'base',
        flag = 1
    },
    craft = {
        dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        flag = 49
    },
    process = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49
    }
}

-- Messages de notification
JobsConfig.Notifications = {
    -- Général
    no_permission = 'Vous n\'avez pas la permission',
    job_required = 'Vous devez avoir le job %s',
    grade_required = 'Grade insuffisant',
    not_on_duty = 'Vous devez être en service',
    already_on_duty = 'Vous êtes déjà en service',
    now_on_duty = 'Vous êtes maintenant en service',
    now_off_duty = 'Vous n\'êtes plus en service',
    
    -- Interactions
    interaction_created = 'Point d\'interaction créé',
    interaction_deleted = 'Point d\'interaction supprimé',
    farm_success = 'Vous avez récolté %s',
    farm_failed = 'Récolte échouée',
    craft_success = 'Fabrication réussie',
    craft_failed = 'Fabrication échouée',
    process_success = 'Traitement réussi',
    process_failed = 'Traitement échoué',
    sell_success = 'Vente réussie: %s$',
    sell_failed = 'Vente échouée',
    no_item = 'Vous n\'avez pas cet item',
    inventory_full = 'Inventaire plein',
    
    -- Véhicules
    vehicle_spawned = 'Véhicule sorti',
    vehicle_stored = 'Véhicule rangé',
    vehicle_already_out = 'Un véhicule est déjà sorti',
    no_vehicle = 'Aucun véhicule à proximité',
    
    -- Boss
    employee_hired = '%s a été embauché',
    employee_fired = '%s a été renvoyé',
    salary_updated = 'Salaire mis à jour',
    money_withdrawn = '%s$ retirés du compte société',
    money_deposited = '%s$ déposés sur le compte société',
    insufficient_society_funds = 'Fonds société insuffisants',
    
    -- Job Creator
    job_created = 'Job créé avec succès',
    job_updated = 'Job mis à jour',
    job_deleted = 'Job supprimé',
    grade_added = 'Grade ajouté',
    grade_removed = 'Grade supprimé'
}

-- Types d'interactions disponibles
JobsConfig.InteractionTypes = {
    'duty',
    'wardrobe',
    'vehicle',
    'storage',
    'boss',
    'shop',
    'farm',
    'craft',
    'process',
    'sell',
    'custom'
}

-- Permissions par défaut pour les grades
JobsConfig.DefaultPermissions = {
    boss = {
        'hire',
        'fire',
        'promote',
        'demote',
        'manage',
        'withdraw',
        'deposit',
        'all'
    },
    management = {
        'hire',
        'fire',
        'promote',
        'demote',
        'manage'
    },
    supervisor = {
        'hire'
    }
}
