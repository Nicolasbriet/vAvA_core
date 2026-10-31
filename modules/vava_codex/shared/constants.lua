--[[
    vava_codex/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre lu, champ des
           préférences, RPC, évènements, bornes ; identifiant d'une page de lecture (1.5.0, `READING`) ; crochet de fermeture du livre (1.7.0,
           `HOOKS`).
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

-- Pages de lecture (1.5.0) : seules les bornes que le client relit (identifiant d'une page demandée par la page) ;
-- les autres bornes du format, réservées au serveur, sont en tête de shared/pages.lua (servi au seul serveur).
VavaCodex.READING = {
    ID_PATTERN = '^[a-z][a-z0-9_]*$',        -- identifiant de page ou de chapitre (jamais « vava… »)
    MAX_ID = 32,
}

-- Crochets émis par le module (client, locaux au joueur).
VavaCodex.HOOKS = {
    -- after (1.7.0) : { docked, reason } à chaque fermeture du livre, échec de l'ouverture compris ; reason : close (le
    -- joueur ou l'hôte), run (une commande lancée l'a fermé), failed (ouverture impossible), unloaded, stopped
    CLOSED = 'vava_codex:closed',
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaCodex.EVENTS = {
    NOTIFY = 'vava_codex:notify',            -- message, nature (info | warning | danger)
}
