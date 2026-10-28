--[[
    vava_farming/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre des cultures, RPC,
           évènements ciblés, state bag des parcelles, états d'un emplacement, bornes.
    Dépendances : aucune
]]

VavaFarming = {}

-- Registre du core défini par ce module : cultures (graine, produit, croissance, eau, fertilité, famille, stades),
-- rempli par la config, extensible par d'autres modules.
VavaFarming.REGISTRY_CROPS = 'vava_farming:crops'

-- State bag global d'une parcelle : + id → { slots = { [index] = { crop, stage, state } } }
VavaFarming.STATE_PARCEL = 'vava_farming:parcel:'

-- États d'un emplacement planté.
VavaFarming.STATES = { GROWING = 'growing', RIPE = 'ripe', WILTED = 'wilted', DEAD = 'dead' }

-- Gestes sur un emplacement (durée et animation dans config.actions).
VavaFarming.ACTIONS = { PLANT = 'plant', WATER = 'water', FERTILIZE = 'fertilize', HARVEST = 'harvest', CLEAR = 'clear' }
VavaFarming.ACTION_LIST = { 'plant', 'water', 'fertilize', 'harvest', 'clear' }

-- Bornes de validation (protocole).
VavaFarming.ID_PATTERN = '^[%l%d_]+$'
VavaFarming.MAX_TOKEN = 0x7FFFFFFF
VavaFarming.MAX_SLOTS = 64
VavaFarming.MAX_TIER = 5

-- Intentions du client (RPC à schéma strict, débit limité).
VavaFarming.RPC = {
    OPEN = 'vava_farming:open',         -- parcelle, emplacement : menu de l'emplacement
    BEGIN = 'vava_farming:begin',       -- parcelle, emplacement, geste, culture | '', palier | 0 : commencer un geste
    CANCEL = 'vava_farming:cancel',     -- jeton
    FINISH = 'vava_farming:finish',     -- jeton : fin du geste (le serveur applique)
    FILL = 'vava_farming:fill',         -- puits : remplir le seau tenu
    GRANARY = 'vava_farming:granary',   -- parcelle : ouvrir le grenier commun
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaFarming.EVENTS = {
    NOTIFY = 'vava_farming:notify',     -- message, nature
    SLOT = 'vava_farming:slot',         -- vue d'un emplacement après un geste (menu ouvert)
}
