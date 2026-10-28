--[[
    vava_inventory/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaInventory = {}

-- Registre des définitions d'objets (registre du core, défini par ce module, rempli par les autres).
VavaInventory.REGISTRY = 'vava_inventory:items'
-- Champ de personnage : barre de raccourcis (identifiants d'objets, 0 = vide).
VavaInventory.HOTBAR_FIELD = 'vava_inventory:hotbar'
-- Champ de personnage public (statebag) : objet tenu en main, { id, item, model, bone, offset, rotation } ou rien.
-- Chaque client en fait un accessoire local sur le ped du porteur (depuis 1.4.0).
VavaInventory.HANDS_FIELD = 'vava_inventory:hands'
-- Clé du statebag d'un sac au sol : identifiant de son conteneur (seule donnée publique).
VavaInventory.DROP_STATE = 'vava_inventory:drop'

-- catalog : catalogue de développement (1.5.0), temporaire, un par joueur du Conseil qui l'ouvre
VavaInventory.KIND = { CHARACTER = 'character', DROP = 'drop', CATALOG = 'catalog' }

-- Bornes de validation (protocole).
VavaInventory.MAX_GRID = 32                 -- largeur et hauteur maximales d'un conteneur
VavaInventory.MAX_ID = 9007199254740991     -- 2^53 - 1 : exact en Lua comme en JavaScript
VavaInventory.MAX_QUANTITY = 1000000

-- Événements serveur → client (toujours vers les seuls joueurs concernés).
VavaInventory.EVENTS = {
    SNAPSHOT = 'vava_inventory:snapshot',   -- ouverture : conteneurs visibles, définitions, raccourcis
    DELTA = 'vava_inventory:delta',         -- différences d'un conteneur ouvert
    CLOSED = 'vava_inventory:closed',       -- un conteneur ouvert n'est plus accessible (sac vidé, expiré)
    NOTIFY = 'vava_inventory:notify',       -- message au joueur (utilisation d'un objet…)
}

-- Intentions du client.
VavaInventory.RPC = {
    OPEN = 'vava_inventory:open',
    CLOSE = 'vava_inventory:close',
    MOVE = 'vava_inventory:move',
    SPLIT = 'vava_inventory:split',
    MERGE = 'vava_inventory:merge',
    DROP = 'vava_inventory:drop',
    USE = 'vava_inventory:use',
    HOTBAR_SET = 'vava_inventory:hotbarSet',
    HOTBAR_USE = 'vava_inventory:hotbarUse',
    HOLD = 'vava_inventory:hold',               -- prendre en main (id d'objet) ou reposer (0)
    CATALOG = 'vava_inventory:catalog',         -- bandeau du catalogue de développement : catégorie, page, recherche
}
