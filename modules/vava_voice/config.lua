--[[
    vava_voice/config.lua
    Rôle : réglages du chat vocal que lit le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           version du core, portée à terre, pont du web, droits et marge d'abonnement des zones, outil du Registre,
           débits, textes du journal. Complète la table ouverte par config_client.lua (portées, touche, cercle,
           zones et éditeur, médaillon) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaVoice.config

config.coreVersion = '0.11.0'  -- abonnements de zone (core.zones)
-- à terre (vava_health) : seules les portées jusqu'à celle-ci (Chuchoter et Parler) ; la précédente revient
-- après la réanimation
config.downedMaxRange = 2

-- Chancellerie (panneau web) : seule ressource admise à modifier ou supprimer une zone en son nom.
config.web = { bridge = 'vava_chancellerie' }

-- Zones de voix : droits et marge d'abonnement (le reste de `zones`, lu par l'éditeur, est dans config_client.lua).
config.zones.permission = 'tools'               -- droit vava_admin pour créer, modifier, supprimer
config.zones.teleportPermission = 'teleport'    -- droit vava_admin pour « S'y rendre »
-- mètres au-delà du bord : la zone est connue du joueur avant qu'il y entre (envoyée par le core aux seuls joueurs à
-- rayon + marge)
config.zones.subscribeMargin = 40.0
-- outil du Registre
config.zones.tool = {
    label = 'Zones de voix',
    hint = 'Lieux où la voix porte plus loin (tribune, place du marché) ou moins (bibliothèque, crypte).',
}

config.rateLimits = {
    zones = { capacity = 3, refillPerSecond = 0.2 },  -- limite de portée renvoyée (apparition, redémarrage)
    editor = { capacity = 5, refillPerSecond = 1 },   -- ouverture de l'éditeur
    edit = { capacity = 10, refillPerSecond = 1 },    -- création, modification, suppression, déplacement
}

-- Textes du journal du Registre (32 caractères au plus) ; l'éditeur a les siens (web/js/strings.js).
config.messages = {
    logCreate = 'Zone de voix créée',
    logUpdate = 'Zone de voix modifiée',
    logDelete = 'Zone de voix supprimée',
}
