--[[
    vava_codex/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : registre lu, champ des
           préférences, RPC, évènements, bornes.
    Dépendances : aucune
]]

VavaCodex = {}

-- Registre du core où chaque module déclare ses commandes et ses touches (server/core/commands.lua du core).
VavaCodex.REGISTRY = 'core:commands'
-- Champ de personnage (visible du seul joueur) : signets, dernières pages, réglages du Codex.
VavaCodex.PREFS_FIELD = 'vava_codex:prefs'

-- Bornes de validation (protocole).
VavaCodex.MAX_NAME = 64                      -- nom d'une commande (identifiant du core)
VavaCodex.MAX_ACTION = 32                    -- identifiant d'une sous-commande
VavaCodex.MAX_ARGS = 8                       -- arguments d'une commande ou d'une sous-commande
VavaCodex.MAX_LINE = 256                     -- ligne composée, lancée par le client
VavaCodex.MAX_OPTIONS = 200                  -- valeurs proposées pour un argument
VavaCodex.NAME_PATTERN = '^[%w_%-%.:]+$'     -- même motif que les identifiants du core

-- Intentions du client (RPC à schéma strict, débit limité).
VavaCodex.RPC = {
    OPEN = 'vava_codex:open',                -- commandes et touches visibles du joueur, non décrites (Conseil), préférences
    OPTIONS = 'vava_codex:options',          -- nom, sous-commande ('' : forme nue), rang de l'argument : valeurs proposées
    FAVORITE = 'vava_codex:favorite',        -- nom, posé ? : signet
    RECENT = 'vava_codex:recent',            -- nom, sous-commande : une commande vient d'être lancée
    KEEP_OPEN = 'vava_codex:keepOpen',       -- rester ouvert après « Lancer » ?
}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaCodex.EVENTS = {
    NOTIFY = 'vava_codex:notify',            -- message, nature (info | warning | danger)
}
