--[[
    vava_voice/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaVoice = {}

-- Événements serveur → client.
VavaVoice.EVENTS = {
    LIMIT = 'vava_voice:limit',     -- au seul joueur concerné : portée maximale (numéro), 0 = aucune limite
    ZONE = 'vava_voice:zone',       -- à tous : ('set', zone) créée ou modifiée, ('remove', id) supprimée
}

-- Intentions du client (RPC du core).
VavaVoice.RPC = {
    ZONES = 'vava_voice:zones',         -- liste des zones (à l'apparition)
    EDITOR = 'vava_voice:editor',       -- ouvrir l'éditeur (droit du Conseil)
    CREATE = 'vava_voice:zoneCreate',   -- nouvelle zone centrée sur le membre du Conseil
    UPDATE = 'vava_voice:zoneUpdate',
    DELETE = 'vava_voice:zoneDelete',
    REACH = 'vava_voice:zoneReach',     -- s'y rendre
}

-- Hooks déclenchés par le module.
VavaVoice.HOOKS = {
    ZONES_CHANGED = 'vava_voice:zonesChanged', -- after (serveur) : { action = set|remove, id, zone?, source }
    RANGE_CHANGED = 'vava_voice:rangeChanged', -- after (client) : { index, name, distance }
}

-- Raison de limite posée par le module lui-même (à terre).
VavaVoice.LIMIT_DOWNED = 'vava_voice:downed'
-- Aucune limite de portée.
VavaVoice.NO_LIMIT = 0

-- Liens facultatifs avec d'autres modules (par leurs hooks, exports et registres).
VavaVoice.ADMIN = {
    RESOURCE = 'vava_admin',
    REGISTRY = 'vava_admin:tools',
    READY = 'vava_admin:toolsReady',
    OPENED = 'vava_admin:toolOpened',
    TOOL = 'vava_voice:zones',
}
VavaVoice.HEALTH = {
    RESOURCE = 'vava_health',
    DOWNED = 'vava_health:downed',
    REVIVED = 'vava_health:revived',
    RESPAWNED = 'vava_health:respawned',
}
