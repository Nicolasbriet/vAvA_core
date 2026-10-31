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
-- repli du client pour la part de la barre de tension à tenir, si la touche reçue n'en porte pas une valide (de 0 à 1) :
-- le serveur envoie toujours `fishing.tension.holdRatio` de config.lua (relecture réseau R-2 de T-141)
VavaGathering.FISHING_HOLD_RATIO = 0.6
-- limites d'une zone du core (config/server.lua, zones : maxRadius, maxMargin, maxKeys), vérifiées à l'indexation pour
-- qu'une zone hors bornes refuse le module avec un message clair au lieu d'être refusée en silence par le core. Avec
-- 120 nœuds au plus (deux clés chacun, `p:` et `n:`, plus `zone` et `def` : 242 clés sur 256), l'état reste sous les
-- 32 Ko du core (≈ 9 Ko pour 120 points).
VavaGathering.ZONE_MAX_RADIUS = 500.0
VavaGathering.ZONE_MAX_MARGIN = 500.0
VavaGathering.ZONE_MAX_NODES = 120   -- T-102 : deux clés d'état par point (`p:` et `n:`), 2 + 2 × 120 ≤ 256

-- Intentions du client (RPC à schéma strict, débit limité).
VavaGathering.RPC = {
    BEGIN = 'vava_gathering:begin',     -- nœud : commencer une récolte (ou lancer la ligne)
    CANCEL = 'vava_gathering:cancel',   -- jeton : interrompre
    FINISH = 'vava_gathering:finish',   -- jeton : fin du geste de récolte
    REEL = 'vava_gathering:reel',       -- jeton, tenue (booléen) : fin de la barre de tension
    ZONES = 'vava_gathering:zones',     -- zones proches et leur vitalité (panneau)
    MAP = 'vava_gathering:map',         -- version gardée : liste des zones de la carte si elle a changé (T-102)
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaGathering.EVENTS = {
    BITE = 'vava_gathering:bite',       -- { token, tension = { durationMs, zoneMin, zoneMax, drift, pull, gravity } }
    NOTIFY = 'vava_gathering:notify',   -- message, nature (info | warning | danger)
    -- T-102 : essai de l'Atelier, au seul auteur : { zone, mode = 'full' | 'patch', def?, nodes?, hidden? }
    TRIAL = 'vava_gathering:trial',
    TRIAL_END = 'vava_gathering:trialEnd',   -- identifiant de la zone : l'essai prend fin
}

-- T-102 : état d'une zone tenu par le core (shared/zonestate.lua) : `def` (nom, type, lieu de la zone), `p:<nœud>`
-- (ressource et lieu d'un point), en plus de `zone` (bande, cicatrice) et `n:<nœud>` (charges).
VavaGathering.DEF_KEY = 'def'
VavaGathering.PLACE_PREFIX = 'p:'
VavaGathering.MAX_LABEL = 80          -- nom d'une zone dans l'état (octets)
VavaGathering.MAX_KIND = 16           -- type de lieu
VavaGathering.MAX_RESOURCE = 32       -- identifiant d'une ressource
-- liste des zones de la carte gardée par le client (stockage local) : clé, zones au plus, octets au plus
VavaGathering.MAP_KVP = 'vava_gathering:map'
VavaGathering.MAX_MAP_ZONES = 256
VavaGathering.MAX_MAP_BYTES = 16384
