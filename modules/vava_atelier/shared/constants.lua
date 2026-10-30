--[[
    vava_atelier/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre des éditeurs, RPC,
           évènements, hooks, bornes d'une déclaration, motifs, widgets et leur carte réseau, icônes de l'interface,
           actions du journal.
    Dépendances : aucune
]]

VavaAtelier = {}

-- Registre du core où chaque module déclare ses éditeurs : clé `<ressource>:<nom>` (server/editors.lua).
VavaAtelier.REGISTRY = 'vava_atelier:editors'
-- Registre des commandes et des touches du core (lu par le Codex).
VavaAtelier.COMMANDS_REGISTRY = 'core:commands'
-- Registre des objets de vava_inventory (widget `item`).
VavaAtelier.ITEMS_REGISTRY = 'vava_inventory:items'

-- Intentions du client (RPC à schéma strict, débit limité ; server/main.lua).
VavaAtelier.RPC = {
    HOME = 'vava_atelier:home',               -- version gardée : accueil, brouillons, journal récent ; ouvre la session
    EDITOR = 'vava_atelier:editor',           -- atelier, version gardée : descripteur s'il a changé
    LIST = 'vava_atelier:list',               -- atelier, type, page, filtre : entrées en vigueur
    READ = 'vava_atelier:read',               -- atelier, type, entrée : valeurs de la fiche
    CHECK = 'vava_atelier:check',             -- atelier, type, entrée ('' : nouvelle), valeurs : « Vérifier »
    OPTIONS = 'vava_atelier:options',         -- atelier, type, champ, filtre, page : valeurs proposées
    SEARCH = 'vava_atelier:search',           -- texte : entrées des ateliers visibles
    JOURNAL = 'vava_atelier:journal',         -- curseur, atelier ('' : tous) : page du journal
    CLOSE = 'vava_atelier:close',             -- fin de la session
}

-- Évènements serveur → client, toujours vers les seuls membres concernés (core.net).
VavaAtelier.EVENTS = {
    REVOKED = 'vava_atelier:revoked',         -- le membre a perdu le droit d'ouvrir l'Atelier : l'interface se ferme
    EDITOR_GONE = 'vava_atelier:editorGone',  -- l'atelier ouvert a quitté le registre (module arrêté) : identifiant
}

-- Hooks déclenchés par le module.
VavaAtelier.HOOKS = {
    EDITORS_READY = 'vava_atelier:editorsReady',   -- serveur, after, {} : les modules (re)déclarent leurs éditeurs
    SESSION = 'vava_atelier:session',              -- serveur, after : { source, accountId, open }
    JOURNAL = 'vava_atelier:journal',              -- serveur, after : ligne écrite au journal
    STATE = 'vava_atelier:state',                  -- client, local : { open }
}

-- Motifs (ancrés) et longueurs en octets.
VavaAtelier.EDITOR_PATTERN = '^[%w_]+:[%w_]+$'
VavaAtelier.MAX_EDITOR = 64
VavaAtelier.KEY_PATTERN = '^[%a][%w_]*$'       -- type, champ, groupe, source
VavaAtelier.MAX_KEY = 32
VavaAtelier.ENTRY_PATTERN = '^[%w_%-]+$'       -- identifiant d'une entrée d'un module
VavaAtelier.MAX_ENTRY = 48
VavaAtelier.VERSION_PATTERN = '^%x*$'          -- empreinte (shared/fingerprint.lua) ; '' : rien de gardé
VavaAtelier.VERSION_LENGTH = 16
-- filtre, recherche : contrôles ASCII écrits octet par octet (`%c` dépend de la locale et refuserait « Ï » ou « í »)
VavaAtelier.QUERY_PATTERN = '^[^\0-\31\127<>]*$'
VavaAtelier.MAX_QUERY = 48
VavaAtelier.OPTION_PATTERN = '^[%w_%-]+$'      -- valeur d'un choix (segmented, select, model)
VavaAtelier.MAX_OPTION = 32
VavaAtelier.MAX_MODEL = 64
VavaAtelier.ITEM_PATTERN = '^[%w_%-%.:]+$'     -- nom d'un objet du registre vava_inventory:items
VavaAtelier.MAX_ITEM = 64
VavaAtelier.MAX_VALUE_STRING = 1200            -- valeur texte reçue (300 caractères UTF-8 accentués)

-- Clés réservées d'une définition : jamais des champs de fiche (ajoutées par T-101 et T-102).
VavaAtelier.RESERVED = { id = true, place = true, version = true, status = true, parent = true }

-- Les huit widgets et leur carte réseau : `n` nombre, `s` chaîne, `b` booléen.
VavaAtelier.WIDGETS = { 'slider', 'segmented', 'select', 'toggle', 'text', 'duration', 'item', 'model' }
VavaAtelier.CARD = {
    slider = 'n', duration = 'n', toggle = 'b',
    segmented = 's', select = 's', text = 's', item = 's', model = 's',
}

-- Mises en page d'une fiche, articles d'un nom, placements (T-102), jeux de caractères d'un texte, unités de durée.
VavaAtelier.LAYOUTS = { page = true, side = true }
VavaAtelier.ARTICLES = { ['le'] = true, ['la'] = true, ["l'"] = true }
VavaAtelier.PLACEMENTS = { point = true, oriented = true, circle = true, polygon = true, door = true }
VavaAtelier.CHARSETS = { name = true, id = true, free = true }
VavaAtelier.DURATION_UNITS = { s = true, min = true, h = true, j = true }

-- Icônes de l'interface (SVG en ligne de web/js/components.js) : `icon` d'un éditeur en est une.
VavaAtelier.ICONS = {
    'recolte', 'agriculture', 'artisanat', 'porte', 'confrerie', 'logis', 'geste', 'combat', 'effet', 'sort',
    'parchemin',
}

-- Actions du journal (colonne `action`) : celles de T-101 et T-102 déjà rédigées, et `note` (annotation).
VavaAtelier.ACTIONS = {
    'created', 'saved', 'trial', 'published', 'archived', 'restored', 'removed', 'imported', 'placed', 'moved', 'note',
}

-- Bornes d'une déclaration d'éditeur (shared/formschema.lua).
VavaAtelier.LIMITS = {
    label = 32, description = 120, order = 999,
    textsLabel = 32, publishHint = 120,
    kinds = 8, noun = 24, newLabel = 32, steps = 4, step = 24,
    groups = 8, groupLabel = 40, groupHelp = 140,
    fields = 40, cardS = 24, cardB = 24, fieldLabel = 40, help = 140,
    segmented = { min = 2, max = 8, label = 24 },
    select = { min = 1, max = 64, label = 40 },
    choices = { min = 1, max = 32, label = 40 },
    unit = 8, prefix = 4, decimals = 3, sliderSteps = 2000, sliderAbs = 1e9,
    textMax = 80, textMultilineMax = 300, textLines = 8,
    durationMax = 31536000,
    category = 32,
}

-- Bornes de ce que rend un module, nettoyé par l'Atelier avant de partir vers le client.
VavaAtelier.OUT = {
    title = 64, hint = 60,                    -- entrée d'une liste (index)
    optionLabel = 40, image = 160,            -- valeur proposée
    compareTitle = 80, compareText = 160,     -- encadré « Pour comparer »
    errors = 16, errorText = 160,             -- réponse de « Vérifier »
    summary = 160, actor = 80,                -- ligne du journal
}
