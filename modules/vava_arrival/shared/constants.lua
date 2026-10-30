--[[
    vava_arrival/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : évènements ciblés, RPC, hook
           émis, états de la dotation, bornes et motifs de validation.
    Dépendances : aucune
]]

VavaArrival = {}

-- Évènements serveur → client, toujours vers le seul joueur concerné.
VavaArrival.EVENTS = {
    WELCOME = 'vava_arrival:welcome',   -- kitGiven (booléen) : accueil d'un nouveau personnage, ou rejoué par le Conseil
    NOTIFY = 'vava_arrival:notify',     -- message : réponse de /accueil au seul membre du Conseil, quand vava_chat manque
}

-- Intentions du client (RPC à schéma strict, débit limité).
VavaArrival.RPC = {
    WELCOMED = 'vava_arrival:welcomed', -- aucun argument : l'accueil reçu a été montré (accusé de lecture)
}

-- Hooks émis (phase after).
VavaArrival.HOOKS = {
    ARRIVED = 'vava_arrival:arrived',   -- { source, characterId, accountId, kit } : premier accueil d'un nouveau personnage
}

-- États de la dotation (colonne `kit` de la table vava_arrival).
VavaArrival.KIT = {
    DUE = 'due',               -- à donner
    CLAIMED = 'claimed',       -- réservée en base, échange en cours
    GIVEN = 'given',           -- donnée
    WITHHELD = 'withheld',     -- retenue : limite du compte atteinte
    UNCERTAIN = 'uncertain',   -- serveur tombé entre la réservation et la fin : à vérifier par le Conseil
    NONE = 'none',             -- personnage antérieur à l'accueil (ligne créée par /accueil rejouer)
}

-- Bornes de validation.
VavaArrival.MAX_KIT_ENTRIES = 8                 -- objets différents dans la dotation
VavaArrival.MAX_QUANTITY = 100                  -- quantité d'un objet de la dotation
VavaArrival.ID_PATTERN = '^[%w_%-%.:]+$'        -- objet, chapitre du Codex : même motif que les identifiants du core
VavaArrival.MAX_ID = 64                         -- longueur d'un identifiant (octets)
VavaArrival.MAX_PLAYER = 65535                  -- numéro de joueur accepté par /accueil
VavaArrival.MAX_NOTIFICATION = 200              -- octets d'une notification du HUD (au-delà, elle est coupée)
VavaArrival.MAX_REPLY = 512                     -- octets d'une réponse de /accueil reçue en notification (repli sans chat)
VavaArrival.MAX_JOURNAL_LABEL = 32              -- libellé du journal du Registre (vava_admin)
-- délai entre deux lignes de console pour un même objet de la dotation inconnu de l'inventaire (secondes)
VavaArrival.MISSING_ITEM_REPORT_S = 600
