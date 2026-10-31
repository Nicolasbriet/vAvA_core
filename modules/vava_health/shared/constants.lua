--[[
    vava_health/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaHealth = {}

-- Champ de personnage : { health = 0 à 1 (part de la vie au-dessus du seuil de mise à terre), downed, downedFor (ms) }.
-- Visibilité owner : envoyé au seul joueur du personnage.
VavaHealth.FIELD = 'vava_health:state'

-- Événements serveur → client (toujours vers le seul joueur concerné).
VavaHealth.EVENTS = {
    SET = 'vava_health:set',            -- vie à fixer (0 à 1) : soin, blessure décidés par le serveur
    DOWN = 'vava_health:down',          -- mise à terre décidée par le serveur : le client couche son ped
    REVIVE = 'vava_health:revive',      -- relevé sur place, avec la vie de départ
    RESPAWN = 'vava_health:respawn',    -- porté au lieu de soins (l'apparition suit), avec la vie de départ
    CHANNEL = 'vava_health:channel',    -- geste pour relever : { role = helper|patient, state = start|cancel|done, durationMs? }
    MESSAGE = 'vava_health:message',    -- message de la configuration à afficher (clé)
}

-- Intentions du client.
VavaHealth.RPC = {
    ASSIST = 'vava_health:assist',      -- relever la personne à terre la plus proche (choisie par le serveur)
    GIVE_UP = 'vava_health:giveUp',     -- à terre : rendre l'âme
}

-- Hooks déclenchés par le module.
VavaHealth.HOOKS = {
    DOWNED = 'vava_health:downed',      -- after : { source, characterId, reason, cause?, killer?, origin?, hitId? }
    REVIVING = 'vava_health:reviving',  -- before, annulable : { source, target } (métier exigé, objet…)
    REVIVED = 'vava_health:revived',    -- after : { source, characterId, reason, by? }
    RESPAWNED = 'vava_health:respawned',-- after : { source, characterId, reason, point } (pénalités à venir)
    -- chaîne de dégâts : before (refus seul) puis after (tout coup qui a atteint la chaîne, et les pertes natives)
    HIT = 'vava_health:hit',
}

-- Registre des modificateurs de la chaîne de dégâts (défini par ce module, rempli par les autres).
VavaHealth.MODIFIERS = 'vava_health:modifiers'

-- Étapes de la chaîne, dans l'ordre fixe de docs/plan/COMBAT_V1.md (une règle, pas un réglage) ; l'application à la
-- vie vient après la dernière.
VavaHealth.STAGES = { 'annulation', 'esquive', 'parade', 'blocage', 'bouclier', 'resistance' }

-- Codes de refus de l'export hit (nil, code) : le coup n'a pas atteint la chaîne.
VavaHealth.KNOWN_CODES = {
    'not_ready', 'invalid_target', 'no_character', 'invalid_packet', 'invalid_amount', 'invalid_kind',
    'invalid_source', 'invalid_part', 'invalid_ref', 'invalid_tags', 'invalid_launch', 'unknown_field', 'too_many_hits',
    'too_deep', 'hit_error',
}

-- Hooks d'autres modules écoutés (tous facultatifs).
VavaHealth.INVENTORY_HOOKS = { 'vava_inventory:move', 'vava_inventory:split', 'vava_inventory:merge', 'vava_inventory:drop', 'vava_inventory:use' }
VavaHealth.INVENTORY_USE = 'vava_inventory:use'
-- prendre en main ou reposer (inventaire 1.4.0) : payload.owner nil pour un geste du joueur
VavaHealth.INVENTORY_HOLD = 'vava_inventory:hold'
VavaHealth.NEEDS_DECAY = 'vava_needs:decay'
-- Effet d'objet lu par le module (`effects = { health = 20 }` : +20 % de la vie).
VavaHealth.EFFECT = 'health'
