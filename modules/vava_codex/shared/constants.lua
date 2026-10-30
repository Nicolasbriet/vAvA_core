--[[
    vava_codex/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre lu, champ des
           préférences, RPC, évènements, bornes ; bornes du format des pages de lecture (1.5.0, `READING`).
    Dépendances : aucune
]]

VavaCodex = {}

-- Registre du core où chaque module déclare ses commandes et ses touches (server/core/commands.lua du core).
VavaCodex.REGISTRY = 'core:commands'
-- Champ de personnage (serveur seul : le client les reçoit à l'ouverture) : signets, dernières pages, réglages.
VavaCodex.PREFS_FIELD = 'vava_codex:prefs'

-- Bornes de validation (protocole).
VavaCodex.MAX_NAME = 64                      -- nom d'une commande (identifiant du core)
VavaCodex.MAX_ACTION = 32                    -- identifiant d'une sous-commande
VavaCodex.MAX_ARGS = 8                       -- arguments d'une commande ou d'une sous-commande
VavaCodex.MAX_LINE = 256                     -- ligne composée, lancée par le client
VavaCodex.MAX_OPTIONS = 200                  -- valeurs proposées pour un argument
VavaCodex.NAME_PATTERN = '^[%w_%-%.:]+$'     -- même motif que les identifiants du core
VavaCodex.VERSION_LENGTH = 16                -- empreinte du contenu ou des préférences (shared/fingerprint.lua)
VavaCodex.VERSION_PATTERN = '^%x*$'          -- chiffres hexadécimaux ; '' : le client n'a rien

-- Intentions du client (RPC à schéma strict, débit limité).
VavaCodex.RPC = {
    OPEN = 'vava_codex:open',                -- versions connues : contenu visible et préférences, s'ils ont changé
    OPTIONS = 'vava_codex:options',          -- nom, sous-commande ('' : forme nue), rang de l'argument : valeurs proposées
    FAVORITE = 'vava_codex:favorite',        -- nom, posé ? : signet
    RECENT = 'vava_codex:recent',            -- nom, sous-commande : une commande vient d'être lancée
    KEEP_OPEN = 'vava_codex:keepOpen',       -- rester ouvert après « Lancer » ?
    PAGE = 'vava_codex:page',                -- identifiant d'une page de lecture : son texte en blocs (1.5.0)
}

-- Pages de lecture (1.5.0) : bornes du format (shared/pages.lua). Elles protègent le réseau et le rendu de la page,
-- elles ne sont donc pas en config. Motifs écrits en ensembles ASCII explicites (aucune classe liée à la locale).
VavaCodex.READING = {
    ID_PATTERN = '^[a-z][a-z0-9_]*$',        -- identifiant de page ou de chapitre (jamais « vava… »)
    MAX_ID = 32,
    MAX_BODY = 6000,                         -- octets du corps source
    MAX_BLOCKS = 40,                         -- blocs par page
    MAX_ITEMS = 12,                          -- éléments par liste
    MAX_PARAGRAPH = 1200,                    -- octets d'un paragraphe ou d'une note (source, jetons compris)
    MAX_ITEM = 400,                          -- octets d'un élément de liste
    MAX_HEADING = 80,                        -- octets d'un intertitre
    MAX_TOKENS = 40,                         -- jetons par page (touches, commandes, liens, italiques)
    MAX_KBD = 16,                            -- octets d'une touche écrite en toutes lettres ([[F1]])
    MAX_LINK_LABEL = 48,                     -- octets du libellé d'un lien de page
    MAX_EM = 200,                            -- octets d'un passage en italique
    MAX_WIRE = 7500,                         -- poids msgpack estimé de la réponse `page` (sous le seuil latent de 8 Ko)
    MAX_PAGES = 40,
    MAX_CHAPTERS = 8,
    MAX_TITLE = 48,
    MAX_SUMMARY = 120,
    MAX_LABEL = 32,                          -- nom d'un chapitre
    MAX_PERMISSION = 32,                     -- droit vava_admin d'une page du Conseil
    MAX_REQUIRES = 64,                       -- ressource dont dépend une page
    NAME_PATTERN = '^[A-Za-z0-9_%-%.]+$',    -- touche ou commande citée ([[touche:…]], [[commande:…]]), MAX_NAME octets
    ACTION_PATTERN = '^[A-Za-z0-9_%-]+$',    -- sous-commande citée, MAX_ACTION octets
    PERMISSION_PATTERN = '^[a-z_]+$',
    REQUIRES_PATTERN = '^[A-Za-z0-9_%-]+$',
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaCodex.EVENTS = {
    NOTIFY = 'vava_codex:notify',            -- message, nature (info | warning | danger)
}
