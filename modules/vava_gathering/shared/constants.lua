--[[
    vava_gathering/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre des outils, RPC,
           évènements ciblés, bandes de vitalité, bornes, anciennes clés GlobalState (effacées une fois au démarrage).
    Dépendances : aucune
]]

VavaGathering = {}

-- Registre du core défini par ce module : outils de récolte (objet → genre, puissance, bonus, usure), rempli par la
-- config et extensible par tout module qui déclare un outil.
VavaGathering.REGISTRY_TOOLS = 'vava_gathering:tools'

-- Bandes de vitalité d'une zone (de la meilleure à la pire).
VavaGathering.BANDS = { NORMAL = 'normal', REDUCED = 'reduced', DEPLETED = 'depleted' }

-- Anciennes clés GlobalState (avant 1.6.0 : état des zones et charges des nœuds envoyés à tous). L'état passe désormais
-- par les abonnements de zone du core (shared/zonestate.lua, server/share.lua) : ces clés ne sont plus écrites,
-- seulement effacées une fois au démarrage si un serveur resté allumé les garde encore.
VavaGathering.LEGACY_STATE_ZONE = 'vava_gathering:zone:'   -- + id de zone
VavaGathering.LEGACY_STATE_NODE = 'vava_gathering:node:'   -- + id de nœud

-- Bornes de validation (protocole).
VavaGathering.ID_PATTERN = '^[%l%d_]+$'
-- longueur d'un identifiant (octets) : une zone de récolte est une zone du core (identifiant de 48 octets au plus) ;
-- un nœud est la clé `n:<nœud>` de l'état de sa zone (48 octets au plus, préfixe compris)
VavaGathering.MAX_ZONE_ID = 48
VavaGathering.MAX_NODE_ID = 46
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
