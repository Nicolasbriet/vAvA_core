--[[
    vava_gathering/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre des outils, RPC,
           évènements ciblés, clés des state bags globaux, bandes de vitalité, bornes.
    Dépendances : aucune
]]

VavaGathering = {}

-- Registre du core défini par ce module : outils de récolte (objet → genre, puissance, bonus, usure), rempli par la
-- config et extensible par tout module qui déclare un outil.
VavaGathering.REGISTRY_TOOLS = 'vava_gathering:tools'

-- Bandes de vitalité d'une zone (de la meilleure à la pire).
VavaGathering.BANDS = { NORMAL = 'normal', REDUCED = 'reduced', DEPLETED = 'depleted' }

-- State bags globaux : état d'une zone et charges d'un nœud, écrits par le serveur au seul changement.
VavaGathering.STATE_ZONE = 'vava_gathering:zone:'   -- + id de zone → { band, scarred, vitality }
VavaGathering.STATE_NODE = 'vava_gathering:node:'   -- + id de nœud → charges (entier)

-- Bornes de validation (protocole).
VavaGathering.ID_PATTERN = '^[%l%d_]+$'
VavaGathering.MAX_TOKEN = 0x7FFFFFFF

-- Intentions du client (RPC à schéma strict, débit limité).
VavaGathering.RPC = {
    BEGIN = 'vava_gathering:begin',     -- nœud : commencer une récolte (ou lancer la ligne)
    CANCEL = 'vava_gathering:cancel',   -- jeton : interrompre
    FINISH = 'vava_gathering:finish',   -- jeton : fin du geste de récolte
    REEL = 'vava_gathering:reel',       -- jeton, tenue (booléen) : fin de la barre de tension
    ZONES = 'vava_gathering:zones',     -- zones proches et leur vitalité (panneau)
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaGathering.EVENTS = {
    BITE = 'vava_gathering:bite',       -- { token, tension = { durationMs, zoneMin, zoneMax, drift, pull, gravity } }
    NOTIFY = 'vava_gathering:notify',   -- message, nature (info | warning | danger)
}
