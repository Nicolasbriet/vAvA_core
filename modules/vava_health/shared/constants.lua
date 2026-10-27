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
    DOWNED = 'vava_health:downed',      -- after : { source, characterId, reason, cause?, killer? }
    REVIVING = 'vava_health:reviving',  -- before, annulable : { source, target } (métier exigé, objet…)
    REVIVED = 'vava_health:revived',    -- after : { source, characterId, reason, by? }
    RESPAWNED = 'vava_health:respawned',-- after : { source, characterId, reason, point } (pénalités à venir)
}

-- Hooks d'autres modules écoutés (tous facultatifs).
VavaHealth.INVENTORY_HOOKS = { 'vava_inventory:move', 'vava_inventory:split', 'vava_inventory:merge', 'vava_inventory:drop', 'vava_inventory:use' }
VavaHealth.INVENTORY_USE = 'vava_inventory:use'
VavaHealth.NEEDS_DECAY = 'vava_needs:decay'
-- Effet d'objet lu par le module (`effects = { health = 20 }` : +20 % de la vie).
VavaHealth.EFFECT = 'health'
