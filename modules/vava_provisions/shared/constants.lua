--[[
    vava_provisions/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : RPC, évènements ciblés, hooks
           émis, actions, codes de refus, avis, bornes et motifs de validation.
    Dépendances : aucune
]]

VavaProvisions = {}

-- Intentions du client (RPC à schéma strict, débit limité).
VavaProvisions.RPC = {
    DRAW = 'vava_provisions:draw',      -- point : puiser ou boire au point d'eau désigné (le serveur choisit)
}

-- Évènements serveur → client, toujours vers le seul joueur concerné (core.net.send).
VavaProvisions.EVENTS = {
    NOTICE = 'vava_provisions:notice',  -- code (torn | lost) : l'outre du buveur s'est fendue ou n'a pas trouvé place
    NOTIFY = 'vava_provisions:notify',  -- texte : réponse de /eau au seul membre du Conseil, quand vava_chat manque
}

-- Hooks émis.
VavaProvisions.HOOKS = {
    DRAWING = 'vava_provisions:drawing',  -- before, annulable : { source, characterId, point, kind, action, count }
    DRAWN = 'vava_provisions:drawn',      -- after : le même payload, plus `reserve` (sortes à réserve seulement)
}

-- Ce que le serveur décide de faire au point d'eau.
VavaProvisions.ACTIONS = {
    FILL = 'fill',     -- remplir des outres vides
    DRINK = 'drink',   -- boire quelques gorgées sur place
}

-- Avis serveur → client (évènement NOTICE).
VavaProvisions.NOTICES = {
    TORN = 'torn',     -- l'outre s'est fendue
    LOST = 'lost',     -- besace pleine : l'outre vide est abandonnée
}

-- Codes de refus du RPC DRAW (le client les traduit d'après la config).
VavaProvisions.CODES = {
    NO_CHARACTER = 'no_character', DOWNED = 'downed', UNKNOWN_POINT = 'unknown_point', TOO_FAR = 'too_far',
    WAIT = 'wait', BUSY = 'busy', NOT_THIRSTY = 'not_thirsty', NO_CONTAINER = 'no_container', NO_SPACE = 'no_space',
    TOO_HEAVY = 'too_heavy', UNAVAILABLE = 'unavailable', DRY = 'dry', REFUSED = 'refused',
}

-- Bornes de validation (protocole).
VavaProvisions.ID_PATTERN = '^[a-z0-9_]+$'     -- point d'eau, sorte, objet (motif ancré, ASCII seulement)
VavaProvisions.ID_MAX = 32                     -- octets d'un identifiant de point ou de sorte (argument du RPC)
VavaProvisions.LABEL_MAX = 48                  -- octets du nom d'un point (lu par le client, montré dans l'invite)
VavaProvisions.KIND_LABEL_MAX = 24             -- octets du nom d'une sorte
VavaProvisions.MODEL_MAX = 64                  -- octets d'un nom de modèle
VavaProvisions.MAX_COORD = 50000               -- |x|, |y| d'un point (borne de core.zones)
VavaProvisions.MAX_Z = 5000                    -- |z| d'un point
VavaProvisions.MAX_NOTIFICATION = 200          -- octets d'une notification du HUD, d'un texte « à sec », d'une raison
VavaProvisions.MAX_JOURNAL_LABEL = 32          -- libellé du journal du Registre (vava_admin)
VavaProvisions.MAX_REPLY = 512                 -- octets d'une réponse de /eau reçue en notification (repli sans chat)
VavaProvisions.MAX_POINTS = 1024               -- plafond de maxPoints (zones du core par module)
