--[[
    vava_atelier/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre des éditeurs, RPC,
           évènements, hooks, bornes d'une déclaration, motifs, widgets et leur carte réseau, icônes de l'interface,
           actions du journal ; définitions gardées (T-101) : statuts, origines, boutons du pied de fiche, codes de
           refus, bornes d'une fiche, d'un lieu et d'un fichier d'archives.
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
    -- T-101 : définitions gardées (server/lifecycle.lua, server/history.lua)
    SAVE = 'vava_atelier:save',               -- atelier, type, entrée ('' : nouvelle), révision lue, valeurs
    TRIAL = 'vava_atelier:trial',             -- atelier, type, entrée, révision : essai chez l'auteur seul
    END_TRIAL = 'vava_atelier:endTrial',      -- atelier, type, entrée : fin de l'essai
    PREVIEW = 'vava_atelier:preview',         -- atelier, type, entrée, publish | restore, révision ou version : résumé
    PUBLISH = 'vava_atelier:publish',         -- atelier, type, entrée, révision, jeton du résumé
    RESTORE = 'vava_atelier:restore',         -- atelier, type, entrée, version visée, jeton du résumé
    DISCARD = 'vava_atelier:discard',         -- atelier, type, entrée, révision : brouillon abandonné
    RETIRE = 'vava_atelier:retire',           -- atelier, type, entrée : brouillon de retrait
    TAKE = 'vava_atelier:take',               -- atelier, type, entrée, révision vue : reprise du brouillon d'un autre
    HISTORY = 'vava_atelier:history',         -- atelier, type, entrée, avant la version (0 : récentes)
    VERSION = 'vava_atelier:version',         -- atelier, type, entrée, version : version figée en lecture
    REMOVED = 'vava_atelier:removed',         -- atelier, type, page : fiches retirées du royaume
}

-- Évènements serveur → client, toujours vers les seuls membres concernés (core.net).
VavaAtelier.EVENTS = {
    REVOKED = 'vava_atelier:revoked',         -- le membre a perdu le droit d'ouvrir l'Atelier : l'interface se ferme
    EDITOR_GONE = 'vava_atelier:editorGone',  -- l'atelier ouvert a quitté le registre (module arrêté) : identifiant
    -- une fiche de l'atelier ouvert a changé (saved, published, restored, removed, discarded, taken, trialEnded)
    ENTRY_CHANGED = 'vava_atelier:entryChanged',
}

-- Hooks déclenchés par le module.
VavaAtelier.HOOKS = {
    EDITORS_READY = 'vava_atelier:editorsReady',   -- serveur, after, {} : les modules (re)déclarent leurs éditeurs
    SESSION = 'vava_atelier:session',              -- serveur, after : { source, accountId, open }
    JOURNAL = 'vava_atelier:journal',              -- serveur, after : ligne écrite au journal
    STATE = 'vava_atelier:state',                  -- client, local : { open }
    -- serveur, after, une fois par fiche d'un lot : { editor, kind, id, version, previous?, action, actor }
    PUBLISHED = 'vava_atelier:published',
    -- serveur, after : { editor, kind, id, accountId, source?, on, reason? }
    TRIAL = 'vava_atelier:trial',
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

-- Actions du journal (colonne `action`, 16 octets) : celles de T-101 et T-102, et `note` (annotation).
VavaAtelier.ACTIONS = {
    'created', 'saved', 'trial', 'published', 'archived', 'restored', 'removed', 'imported', 'placed', 'moved', 'note',
    'discarded', 'taken', 'trial_ended', 'exported', 'received',
}

-- Définitions gardées (T-101, table vava_atelier_definitions) -------------------------------------------------------

-- Statuts d'une ligne (une ligne par version) et origines d'une version.
VavaAtelier.STATUSES = { 'draft', 'trial', 'published', 'archived' }
VavaAtelier.ORIGINS = { 'seed', 'atelier', 'restore', 'import' }

-- Boutons du pied de fiche (`footer` d'une fiche : { id, label, primary?, link? }), rendus par le serveur.
VavaAtelier.FOOTER = {
    SAVE = 'save', TRIAL = 'trial', END_TRIAL = 'endTrial', PUBLISH = 'publish', HISTORY = 'history',
    DISCARD = 'discard', RETIRE = 'retire', TAKE = 'take', RESTORE = 'restore', CHECK = 'check',
}

-- Codes de refus des RPC de T-101 (traduits par web/js/strings.js).
VavaAtelier.REFUSALS = {
    'stale', 'draft_taken', 'draft_open', 'not_holder', 'no_draft', 'not_stored', 'too_large', 'full',
    'parent_missing', 'trial_busy', 'no_trial', 'syncing', 'unknown_version', 'not_archived', 'unchanged',
    'unreadable',
}

-- Bornes d'une fiche gardée.
VavaAtelier.DEF = {
    formatMax = 65535,         -- `format` d'un éditeur (SMALLINT UNSIGNED)
    versionMax = 4294967295,   -- numéro de version (INT UNSIGNED)
    revMax = 2147483647,       -- révision d'un brouillon
    slugMax = 40,              -- identifiant tiré d'un nom (shared/slug.lua), avant le suffixe _2 … _99
    slugSuffixes = 99,
    parentDepth = 3,           -- chaîne des types parents (fiche, enfant, petit-enfant)
    trialLine = 80,            -- texts.trialLine d'un éditeur
    tokenLength = 16,          -- jeton d'un résumé (empreinte)
    title = 64,                -- colonne `title`
    summary = 160,             -- colonne `summary`, textes d'un module (`diff`, refus d'`apply`)
    previewLines = 8,          -- lignes d'un résumé
    previewWarnings = 4,
    author = 80,
}

-- Lieux (shared/place.lua) : forme d'un `placement`, clés permises, bornes fixes (le reste vient de config.place).
VavaAtelier.PLACE = {
    round = 0.01,              -- coordonnées au centimètre
    roundHeading = 0.1,        -- cap au dixième de degré, ramené dans [0, 360)
    minEdge = 0.05,            -- deux sommets consécutifs d'un polygone, au moins
    minArea = 0.01,            -- aire d'un polygone, au moins (m²)
    modelMin = -2147483648,    -- empreinte d'un modèle (porte) : signée ou non
    modelMax = 4294967295,
}

-- Archives JSON (shared/exchange.lua) : nom d'un fichier (sans barre ni « .. »), version du format, profondeur.
VavaAtelier.EXCHANGE = {
    filePattern = '^[A-Za-z0-9_%-]+%.json$',
    fileMax = 64,
    version = 1,
    depth = 6,                 -- tables imbriquées dans une fiche du fichier (fiche, data, lieu, sommets, sommet)
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
