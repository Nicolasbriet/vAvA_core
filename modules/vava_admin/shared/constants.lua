--[[
    vava_admin/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaAdmin = {}

VavaAdmin.PREFIX = 'vava_admin:'

-- Événements serveur → client.
VavaAdmin.EVENTS = {
    NOTIFY = 'vava_admin:notify',             -- message au joueur : { text, kind, title? }
    ANNOUNCE = 'vava_admin:announcement',     -- annonce du Conseil à tout le serveur (seul envoi à tous)
    REPORT = 'vava_admin:reportNew',          -- nouveau signalement, aux seuls membres qui les traitent
}

-- Hooks déclenchés par le module.
VavaAdmin.HOOKS = {
    ACTION = 'vava_admin:action',             -- after : toute action du personnel (journal, panneau web, alertes)
    TOOLS_READY = 'vava_admin:toolsReady',    -- after (serveur) : registre des outils prêt, les modules y ajoutent les leurs
    TOOL_OPENED = 'vava_admin:toolOpened',    -- after (client) : { key } outil d'un module ouvert depuis le Registre
    REPORT = 'vava_admin:report',             -- after (serveur) : { action = created|claimed|closed, id, author } (panneau web)
}

-- Coordonnées acceptées pour un déplacement (mètres, au-delà de la carte de GTA).
VavaAdmin.MAX_COORD = 20000

-- Champ privé du personnage d'un membre qui observe : sa place d'avant l'observation (server/spectate.lua).
VavaAdmin.SPECTATE_FIELD = 'vava_admin:spectateReturn'

-- Registre du core des outils ajoutés par les modules : clé `<ressource>:<nom>`, { label, hint?, permission }.
VavaAdmin.REGISTRY_TOOLS = 'vava_admin:tools'
VavaAdmin.TOOL_LIMITS = { label = 40, hint = 160, entries = 32, key = 64 }
-- Journal écrit par un module (export log) : libellé de l'action, détails.
VavaAdmin.LOG_LIMITS = { label = 32, details = 8, value = 120 }

-- Bornes de protocole.
VavaAdmin.MAX_TEXT = 500                      -- motif, message, annonce, signalement
VavaAdmin.MAX_ID = 0xFFFFFFFF
