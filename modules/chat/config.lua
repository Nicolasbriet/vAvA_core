--[[
    vAvA_chat - Configuration
    Module intégré à vAvA_core
]]

ChatConfig = {}

-- Configuration générale
ChatConfig.General = {
    -- Distance de proximité pour les messages /me, /do, /ooc (en mètres)
    ProximityRadius = 20.0,
    
    -- Touche pour ouvrir le chat (T = 245)
    OpenKey = 245,
    
    -- Durée d'affichage des messages (ms) avant disparition automatique
    MessageDisplayTime = 5000
}

-- Configuration des couleurs par type de message
ChatConfig.Colors = {
    me = {255, 0, 255},        -- Violet
    ['do'] = {0, 150, 255},    -- Bleu clair
    de = {255, 255, 0},        -- Jaune
    ooc = {180, 180, 180},     -- Gris
    mp = {0, 255, 180},        -- Cyan
    police = {0, 150, 255},    -- Bleu police
    ems = {255, 0, 100},       -- Rose EMS
    staff = {255, 140, 0}      -- Orange staff
}

-- Configuration des permissions staff (via ACE)
ChatConfig.StaffPermissions = {
    "vAvA.owner",
    "vAvA.admin",
    "vAvA.superadmin",
    "vAvA.mod",
    "vAvA.helper",
    -- Compatibilité avec anciens systèmes
    "WaveAdmin.owner",
    "WaveAdmin._dev",
    "WaveAdmin.god",
    "WaveAdmin.superadmin",
    "WaveAdmin.mod",
    "WaveAdmin.helper"
}

-- Jobs autorisés pour les canaux métiers
ChatConfig.JobChannels = {
    police = {"police", "bcso", "sheriff", "lspd"},
    ems = {"ambulance", "ems", "doctor", "hospital"}
}
