--[[
    vava_atelier/shared/constants.lua
    Rôle : table du module (seule globale : VavaAtelier) ; noms des RPC, évènements et hooks ; bornes que le client
           applique à ce qu'il reçoit. Détail : README (Fichiers).
    Dépendances : aucune
]]

VavaAtelier = {}

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
    -- T-102 : outil de placement (server/placement.lua)
    PLACE = 'vava_atelier:place',             -- atelier, type, entrée ('' : nouvelle), révision, lieu, parent, valeurs
    CHILDREN = 'vava_atelier:children',       -- atelier, type, entrée : lieux de la fiche, de son parent, de ses enfants
    -- T-157 : code du Conseil livré à la demande (server/delivery.lua, client/loader.lua)
    CODE = 'vava_atelier:code',               -- empreinte ('' : aucune), morceau (0 : description) : paquet du Conseil
}

-- Évènements serveur → client, toujours vers les seuls membres concernés (core.net).
VavaAtelier.EVENTS = {
    REVOKED = 'vava_atelier:revoked',         -- le membre a perdu le droit d'ouvrir l'Atelier : l'interface se ferme
    EDITOR_GONE = 'vava_atelier:editorGone',  -- l'atelier ouvert a quitté le registre (module arrêté) : identifiant
    -- une fiche de l'atelier ouvert a changé (saved, published, restored, removed, discarded, taken, trialEnded)
    ENTRY_CHANGED = 'vava_atelier:entryChanged',
    -- réponse d'une commande de l'Atelier (/atelier_archives) au seul membre : chat s'il y en a un, sinon notification
    SAY = 'vava_atelier:say',
}

-- Hooks déclenchés par le module.
VavaAtelier.HOOKS = {
    EDITORS_READY = 'vava_atelier:editorsReady',   -- serveur, after, {} : les modules (re)déclarent leurs éditeurs
    SESSION = 'vava_atelier:session',              -- serveur, after : { source, accountId, open }
    JOURNAL = 'vava_atelier:journal',              -- serveur, after : ligne écrite au journal
    -- client, local : { open, placing, suspended } (T-102 : `open = false` pendant l'essai joué, page mise de côté)
    STATE = 'vava_atelier:state',
    -- serveur, after, une fois par fiche d'un lot : { editor, kind, id, version, previous?, action, actor }
    PUBLISHED = 'vava_atelier:published',
    -- serveur, after : { editor, kind, id, accountId, source?, on, reason? }
    TRIAL = 'vava_atelier:trial',
}

-- Motifs (ancrés) et longueurs en octets.
-- écrits en ASCII explicite : `%w` et `%a` dépendent de la locale du système (lettres accentuées sous Windows)
VavaAtelier.EDITOR_PATTERN = '^[A-Za-z0-9_]+:[A-Za-z0-9_]+$'
VavaAtelier.MAX_EDITOR = 64
VavaAtelier.KEY_PATTERN = '^[A-Za-z][A-Za-z0-9_]*$'   -- type, champ, groupe, source
VavaAtelier.MAX_KEY = 32
VavaAtelier.ENTRY_PATTERN = '^[A-Za-z0-9_%-]+$'   -- identifiant d'une entrée d'un module
VavaAtelier.MAX_ENTRY = 48

-- T-102 : bornes que le client applique à ce qu'il reçoit de la page et du serveur (outil de placement).
VavaAtelier.MODEL_PATTERN = '^[A-Za-z0-9_]+$'     -- nom d'un modèle de fantôme
VavaAtelier.MAX_MODEL = 64
VavaAtelier.MAX_ROWS = 200                        -- lignes d'une réponse `children` gardées par l'outil
VavaAtelier.MAX_VERTICES = 32                     -- sommets d'un tracé (config.place.polygonPoints.max)

-- T-157 : paquet du Conseil (shared/codepack.lua, client/loader.lua ; web/boot.js en garde une copie vérifiée par
-- essai). Bornes que le client applique à ce qu'il reçoit, aussi lues par le serveur.
VavaAtelier.CODEPACK = {
    MAGIC = 'VAVAPAQ1',          -- première ligne du paquet (format 1)
    MAX_BYTES = 524288,          -- paquet entier, 512 Ko
    PART_BYTES = 65536,          -- un morceau envoyé, 64 Ko
    MAX_PARTS = 8,               -- MAX_BYTES / PART_BYTES
    MAX_PIECES = 48,             -- fichiers d'un paquet
    MAX_NAME = 96,               -- chemin d'un fichier, octets
    MAX_DEPTH = 4,               -- dossiers au plus dans un chemin
    DIGEST_LENGTH = 16,          -- empreinte : 16 chiffres hexadécimaux (minuscules)
    KVP_CHUNK = 32768,           -- morceau gardé en stockage local
    KVP_MAX_CHUNKS = 16,         -- MAX_BYTES / KVP_CHUNK
}
