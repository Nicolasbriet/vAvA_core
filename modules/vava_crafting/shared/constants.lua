--[[
    vava_crafting/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registres du core, RPC,
           évènements ciblés, state bag des stations, bornes.
    Dépendances : aucune
]]

VavaCrafting = {}

-- Registres du core définis par ce module : types de stations et recettes (données complètes), remplis par la config,
-- extensibles par d'autres modules. Les recettes sont aussi déclarées à vava_skills (compétence, niveau, transmission).
VavaCrafting.REGISTRY = {
    STATIONS = 'vava_crafting:stations',
    RECIPES = 'vava_crafting:recipes',
}

-- State bag global d'une station : + id → { fuel, busy }
VavaCrafting.STATE_STATION = 'vava_crafting:station:'

-- Champ de personnage : poinçon de l'artisan (glyphe de la config), visible du seul joueur.
VavaCrafting.MARK_FIELD = 'vava_crafting:mark'

-- Bornes de validation (protocole).
VavaCrafting.ID_PATTERN = '^[%l%d_]+$'
VavaCrafting.MAX_TOKEN = 0x7FFFFFFF
VavaCrafting.MAX_INSTANCE = 9007199254740991
VavaCrafting.MAX_TIER = 5

-- Intentions du client (RPC à schéma strict, débit limité).
VavaCrafting.RPC = {
    OPEN = 'vava_crafting:open',       -- station : menu (recettes connues, réparables, combustible, poinçon)
    CRAFT = 'vava_crafting:craft',     -- station, recette, paliers choisis { [objet] = palier }
    CANCEL = 'vava_crafting:cancel',   -- jeton
    FINISH = 'vava_crafting:finish',   -- jeton : fin du geste (création ou réparation)
    FUEL = 'vava_crafting:fuel',       -- station, quantité : alimenter le combustible
    REPAIR = 'vava_crafting:repair',   -- station, objet : réparer
    MARK = 'vava_crafting:setMark',    -- glyphe : choisir son poinçon
    NAME = 'vava_crafting:name',       -- objet, nom : baptiser un chef-d'œuvre
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaCrafting.EVENTS = {
    NOTIFY = 'vava_crafting:notify',     -- message, nature
    CRAFTED = 'vava_crafting:crafted',   -- { kind = craft | repair, item, label, quality, tier, signed, nameable, instanceId, nameWindowMs }
    STATION = 'vava_crafting:station',   -- { id, fuel, busy } : la station ouverte a changé
}
