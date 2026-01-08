--[[
    vAvA Core - Module Persist
    Configuration
]]

PersistConfig = {}

-- Mode debug
PersistConfig.Debug = false

-- Intervalle de sauvegarde automatique (ms)
PersistConfig.SaveInterval = 60000 -- 1 minute

-- Distance de rendu des véhicules (augmenter si despawn trop tôt)
PersistConfig.RenderDistance = 200.0

-- Délai avant de considérer un véhicule comme abandonné (ms)
PersistConfig.AbandonTimeout = 300000 -- 5 minutes sans joueur à proximité

-- Protection anti-collision NPC
PersistConfig.AntiNPCCollision = true

-- Véhicules de service par job (ne sont pas persistés)
PersistConfig.JobServiceVehicles = {
    ['police'] = {'police', 'police2', 'police3', 'sheriff', 'sheriff2', 'polmav'},
    ['ambulance'] = {'ambulance', 'firetruk'},
    ['mechanic'] = {'towtruck', 'towtruck2'}
}

-- États de stockage dans la BDD
-- 0 = en fourrière
-- 1 = au garage
-- 2 = sorti mais position inconnue
-- 3 = sorti avec position connue (persistant)
PersistConfig.StoredStates = {
    IMPOUNDED = 0,
    GARAGE = 1,
    OUT_UNKNOWN = 2,
    OUT_PERSISTED = 3
}

-- Paramètres de State Bag pour la synchronisation
PersistConfig.StateBags = {
    engine = true,
    body = true,
    fuel = true,
    mods = true,
    tuning = true
}

-- Blip pour localisation de véhicule
PersistConfig.LocationBlip = {
    sprite = 225,
    color = 3,
    scale = 0.8,
    duration = 60000 -- 1 minute
}

-- Messages
PersistConfig.Messages = {
    vehicle_saved = 'Position du véhicule sauvegardée',
    vehicle_located = 'Véhicule localisé sur la carte',
    vehicle_not_found = 'Véhicule introuvable',
    not_your_vehicle = 'Ce n\'est pas votre véhicule'
}
