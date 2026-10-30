--[[
    vava_crafting/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registres du core, RPC,
           évènements ciblés, anciennes clés GlobalState des stations (effacées au démarrage), bornes.
    Dépendances : aucune
]]

VavaCrafting = {}

-- Registres du core définis par ce module : types de stations et recettes (données complètes), remplis par la config,
-- extensibles par d'autres modules. Les recettes sont aussi déclarées à vava_skills (compétence, niveau, transmission).
VavaCrafting.REGISTRY = {
    STATIONS = 'vava_crafting:stations',
    RECIPES = 'vava_crafting:recipes',
}

-- Anciennes clés GlobalState (jusqu'à 1.4.0) : état d'une station (+ id) et liste des stations placées. Depuis 1.5.0,
-- chaque station est une zone du core (abonnements de zone, shared/stationzone.lua) : le serveur efface une fois ces
-- clés au démarrage (utile seulement s'il n'a pas redémarré depuis l'ancienne version) et n'y écrit plus.
VavaCrafting.LEGACY_STATE_STATION = 'vava_crafting:station:'
VavaCrafting.LEGACY_STATE_STATIONS = 'vava_crafting:stations'

-- Champ de personnage : poinçon de l'artisan (glyphe de la config), visible du seul joueur.
VavaCrafting.MARK_FIELD = 'vava_crafting:mark'

-- Bornes de validation (protocole).
VavaCrafting.ID_PATTERN = '^[%l%d_]+$'
VavaCrafting.STATION_ID_MAX = 32
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

-- Évènements serveur → client, toujours vers le seul joueur concerné. Le combustible et l'occupation d'une station
-- arrivent aux joueurs proches par sa zone du core (1.5.0), plus par un évènement.
VavaCrafting.EVENTS = {
    NOTIFY = 'vava_crafting:notify',     -- message, nature
    CRAFTED = 'vava_crafting:crafted',   -- { kind = craft | repair, item, label, quality, tier, signed, nameable, instanceId, nameWindowMs }
}
