--[[
    vava_voice/config_client.lua
    Rôle : réglages du chat vocal que lit le client (le serveur les lit aussi) : portées, touche, rythmes du client,
           cercle au sol, zones de voix et leur éditeur, médaillon. Téléchargé par chaque joueur. Ce que lit le seul
           serveur (portée à terre, droits et marge des zones, outil du Registre, pont du web, débits, textes du
           journal) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaVoice.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.4.0)

    -- Portées, de la plus basse à la plus haute (mètres). La touche passe à la suivante, puis revient à la première.
    ranges = {
        { name = 'whisper', label = 'Chuchoter', distance = 1.5 },
        { name = 'talk', label = 'Parler', distance = 5.0 },
        { name = 'shout', label = 'Crier', distance = 15.0 },
        { name = 'declaim', label = 'Déclamer', distance = 25.0 },
    },
    -- portée d'un joueur qui n'a encore rien choisi (numéro dans la liste)
    defaultRange = 2,

    -- Touche (réglable par le joueur dans Paramètres > Raccourcis > FiveM). FiveM nomme les touches par leur place sur
    -- un clavier QWERTY : 'Z' est la touche marquée W sur un clavier AZERTY (en bas à gauche). Changer de commande
    -- remet la touche par défaut chez tous les joueurs : FiveM garde sinon celle déjà enregistrée chez chacun.
    key = 'Z',
    command = 'vava_voice_portee',
    keyLabel = 'Portée de la voix (Chuchoter, Parler, Crier, Déclamer)',

    client = {
        targetsPollMs = 250,     -- recalcul des joueurs à portée
        targetMargin = 2.0,      -- marge (m) : la voix ne se coupe pas à chaque pas en bordure de portée
        talkingPollMs = 150,     -- lueur du médaillon quand le joueur parle
        zonesPollMs = 500,       -- zone de voix où se trouve le joueur
        connectPollMs = 250,     -- attente de la connexion vocale et de l'entrée dans son salon
        connectTries = 120,
        rejoinEvery = 8,         -- essais entre deux demandes d'entrée dans le salon
        voiceTarget = 1,         -- cible Mumble de la parole (les salons des joueurs à portée)
        channelBase = 1000,      -- salon d'un joueur en jeu : base + son numéro de joueur
        idleChannel = 0,         -- salon racine : hors du jeu (sélection), personne ne parle à personne
        rangeKvp = 'range',      -- portée choisie, gardée sur la machine du joueur
        -- limite de portée redemandée à l'apparition et au redémarrage du module : essais si le serveur n'est pas prêt
        syncTries = 5,
        syncRetryMs = 2000,
    },

    -- Cercle au sol au changement de portée (vu du seul joueur) : marqueur « cercle fin », couleur laiton.
    ring = {
        durationMs = 1500,
        fadeShare = 0.4,         -- part de la durée où le cercle s'efface
        marker = 25,
        color = { 220, 192, 138 },
        alpha = 180,
        groundOffset = 0.95,     -- des hanches (position du ped) au sol
        thickness = 1.0,
    },

    -- Zones de voix : cylindre centré sur la position du membre du Conseil (ses hanches) : la hauteur se compte de là,
    -- et la zone descend de baseOffset sous ce centre. Effet sur toutes les portées. Si des zones se chevauchent, la
    -- plus petite l'emporte (la plus précise).
    zones = {
        command = 'zonesvoix',
        max = 200,
        labelMax = 40,                   -- signes du nom (un « é » compte pour un)
        radius = { min = 2.0, max = 60.0, default = 10.0, step = 0.5 },
        height = { min = 2.0, max = 30.0, default = 6.0, step = 0.5 },
        multipliers = { 0.5, 0.75, 1.0, 1.5, 2.0, 3.0 },
        defaultMultiplier = 2.0,
        baseOffset = 1.0,                -- la zone commence à cette hauteur sous le centre
        drawDistance = 150.0,            -- zones dessinées dans l'éditeur jusqu'à cette distance
        marker = 1,                      -- cylindre
        colors = {
            quiet = { 96, 140, 176 },    -- la voix porte moins loin
            neutral = { 200, 190, 170 },
            loud = { 220, 170, 90 },     -- la voix porte plus loin
        },
        alpha = 55,
        selectedAlpha = 120,
    },

    hud = { label = 'Voix', icon = 'nui://vava_voice/web/icons/voice.svg', order = 40 },
}
