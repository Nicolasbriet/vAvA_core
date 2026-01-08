--[[
    vAvA Core - Module Sit
    Configuration
]]

SitConfig = {}

-- Mode debug
SitConfig.Debug = false

-- Groupes admin (peuvent créer/modifier les points)
SitConfig.AdminGroups = {'admin', 'god', 'superadmin'}

-- Licenses admin (alternative, par license2)
SitConfig.AdminLicenses = {
    -- 'license2:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
}

-- Commandes
SitConfig.Commands = {
    admin = 'sitmanager',
    menu = 'vsit'
}

-- Contrôles pour le mode édition
SitConfig.Controls = {
    MOVE_FORWARD = 32,      -- W/Z
    MOVE_BACKWARD = 33,     -- S
    MOVE_LEFT = 34,         -- A/Q  
    MOVE_RIGHT = 35,        -- D
    MOVE_UP = 44,           -- Q
    MOVE_DOWN = 38,         -- E
    MOUSE_WHEEL_UP = 15,    -- Molette haut (rotation)
    MOUSE_WHEEL_DOWN = 16,  -- Molette bas (rotation)
    VALIDATE = 191,         -- ENTER
    CANCEL = 177,           -- BACKSPACE
    STAND_UP = 38           -- E pour se lever
}

-- Vitesses de déplacement
SitConfig.MoveSpeed = 0.05
SitConfig.RotationSpeed = 2.0
SitConfig.HeightSpeed = 0.02

-- Configuration du fantôme (mode édition)
SitConfig.GhostAlpha = 180

-- Configuration de la caméra
SitConfig.CameraOffset = vector3(0.0, 2.0, 1.0)
SitConfig.CameraFov = 50.0

-- Distance d'interaction avec les points
SitConfig.InteractionDistance = 1.5

-- Animations d'assise disponibles
SitConfig.Animations = {
    {
        name = 'Position casual',
        description = 'Assise casual et détendue',
        dict = 'switch@michael@parkbench_smoke_ranger',
        anim = 'parkbench_smoke_ranger_loop',
        flag = 1,
        offset = vector3(0.15, 0.0, 0.0)
    },
    {
        name = 'Position pensif',
        description = 'Assise de détente pour regarder',
        dict = 'switch@michael@sitting',
        anim = 'idle',
        flag = 1,
        offset = vector3(0.10, 0.0, 0.0)
    },
    {
        name = 'Position penchée',
        description = 'Assise inclinée vers l\'avant',
        dict = 'rcmtmom_1leadinout',
        anim = 'tmom_1_rcm_p3_leadout_loop',
        flag = 1,
        offset = vector3(0.0, 0.0, 0.0)
    },
    {
        name = 'Position réfléchie',
        description = 'Assise de questionnement',
        dict = 'timetable@reunited@ig_10',
        anim = 'isthisthebest_amanda',
        flag = 1,
        offset = vector3(0.2, 0.25, 0.0)
    },
    {
        name = 'Position détendue',
        description = 'Assise relaxée',
        dict = 'anim@amb@nightclub@smoking@',
        anim = 'blunt_idle_a',
        flag = 1,
        offset = vector3(0.0, 0.0, 0.0)
    },
    {
        name = 'Position canapé',
        description = 'Assise confortable sur canapé',
        dict = 'missah_2_ext_altleadinout',
        anim = 'sofa_loop',
        flag = 1,
        offset = vector3(0.0, 0.0, 0.0)
    },
    {
        name = 'Position écoute',
        description = 'Assise d\'écoute attentive',
        dict = 'missheist_jewelleadinoutjh_endscene',
        anim = 'loop_mic',
        flag = 1,
        offset = vector3(0.0, 0.0, 0.0)
    },
    {
        name = 'Position classique',
        description = 'Assise standard',
        dict = 'timetable@maid@couch@',
        anim = 'base',
        flag = 1,
        offset = vector3(0.0, 0.0, 0.0)
    }
}

-- Messages
SitConfig.Messages = {
    edit_mode_enabled = 'Mode édition activé',
    edit_mode_disabled = 'Mode édition désactivé',
    point_created = 'Point d\'assise créé',
    point_deleted = 'Point d\'assise supprimé',
    point_updated = 'Point d\'assise modifié',
    no_permission = 'Vous n\'avez pas les permissions',
    point_not_found = 'Point introuvable',
    already_sitting = 'Vous êtes déjà assis',
    point_occupied = 'Ce point est déjà occupé'
}
