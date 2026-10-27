--[[
    vava_magic/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : évènements, intentions du
           client, clés des state bags, hooks, liens avec les autres modules.
    Dépendances : aucune
]]

VavaMagic = {}

-- Événements serveur → client (toujours ciblés : jamais à tout le serveur).
VavaMagic.EVENTS = {
    NOTIFY = 'vava_magic:notify',           -- (texte, nature) au joueur concerné
    SHEET = 'vava_magic:sheetChanged',      -- vue de la fiche { isMage, spells, sigilCount, sigilLimit, lightColor }
    MANA = 'vava_magic:mana',               -- (valeur, max, points, périodeMs, écouléMs) au seul mage
    CAST_ABORT = 'vava_magic:castAbort',    -- (idIncantation, code) incantation arrêtée par le serveur
    FRAGMENTS = 'vava_magic:fragments',     -- (lanceur, idIncantation, mots, duréeMs) aux seuls joueurs à < 3 m
    MURMUR = 'vava_magic:murmur',           -- message reçu { from?, text, waypoint? }
    SIGIL_OFFER = 'vava_magic:sigilOffered', -- (idOffre, secondes) : on vous tend un sigil
    SIGIL_NAMING = 'vava_magic:sigilNaming', -- (idOffre, secondes) : nommer le sigil reçu en retour
    SIGIL_CLOSED = 'vava_magic:sigilClosed', -- (idOffre) offre close (expirée, refusée, conclue)
    FIREBALL = 'vava_magic:fireball',       -- lancer { id, caster, dx, dy, dz, speed, range, level, fizzle? }
    FIREBALL_END = 'vava_magic:fireballEnd', -- (id, x, y, z) impact validé par le serveur
    DAMAGE = 'vava_magic:damage',           -- (part de vie) sans vava_health : la victime applique la blessure
    GRIMOIRE = 'vava_magic:openGrimoire',   -- grimoire utilisé
    REGISTER = 'vava_magic:openRegister',   -- { id, pages, count, max } registre utilisé
    CHAT = 'vava_magic:chat',               -- lignes de réponse d'une commande
    ADMIN = 'vava_magic:admin',             -- le joueur peut se servir des commandes du Conseil (suggestions)
}

-- Intentions du client (RPC du core). Chaque sort a en plus les siennes : BEGIN_PREFIX .. sort, FINISH_PREFIX .. sort.
VavaMagic.RPC = {
    SHEET = 'vava_magic:sheet',
    CANCEL = 'vava_magic:castCancel',
    SIGILS = 'vava_magic:sigils',
    SIGIL_OFFER = 'vava_magic:sigilOffer',
    SIGIL_ANSWER = 'vava_magic:sigilAnswer',
    SIGIL_NAME = 'vava_magic:sigilName',
    SIGIL_RENAME = 'vava_magic:sigilRename',
    SIGIL_FORGET = 'vava_magic:sigilForget',
    SIGIL_SCRAMBLE = 'vava_magic:sigilScramble',
    LIGHT_OFF = 'vava_magic:lightOff',
    LIGHT_COLOR = 'vava_magic:lightColor',
    FIREBALL_IMPACT = 'vava_magic:fireballImpact',
    REGISTER_TEAR = 'vava_magic:registerTear',
}
VavaMagic.BEGIN_PREFIX = 'vava_magic:begin:'
VavaMagic.FINISH_PREFIX = 'vava_magic:finish:'

-- Clés des state bags, posés par le serveur sur le ped d'un joueur (ou l'objet d'un orbe) : reçus par les seuls
-- joueurs proches. Valeurs : tables à clés nommées uniquement (msgpack perd les clés d'une table mixte).
VavaMagic.STATES = {
    CASTING = 'vava_magic:casting', -- { spell } incantation en cours
    GLOW = 'vava_magic:glow',       -- true : ses yeux s'illuminent (murmure reçu)
    LIGHT = 'vava_magic:light',     -- { mode, r, g, b, range, intensity, flicker } lumière portée
    ORB = 'vava_magic:orb',         -- mêmes champs : orbe ancré (objet créé par le serveur)
    BURN = 'vava_magic:burn',       -- true : la cible brûle
}

-- Hooks déclenchés par le module.
VavaMagic.HOOKS = {
    CASTING = 'vava_magic:castStarting',          -- before : { source, characterId, spell, level } — refus possible
    CAST = 'vava_magic:castDone',                 -- after : { source, characterId, spell, level, success }
    LEVEL = 'vava_magic:levelUp',                 -- after : { source, characterId, spell, level }
    MAGE = 'vava_magic:mageChanged',              -- after : { source, characterId, isMage }
    UNREACHABLE = 'vava_magic:murmur:unreachable', -- before : { source, characterId, reason, text } — un refus
                                                   -- `false, 'handled'` signifie qu'un autre module prend le message
                                                   -- en charge (pigeon, relais…)
}

-- Registre du core où d'autres modules déclarent des sorts (clé = nom du sort).
VavaMagic.SPELLS_REGISTRY = 'vava_magic:spells'

-- Champ du personnage qui porte la fiche magie (privé : jamais envoyé au client).
VavaMagic.SHEET_FIELD = 'vava_magic:sheet'

-- Sens d'une page du registre.
VavaMagic.DIRECTION = { SENT = 1, RECEIVED = 2 }

-- Liens avec les autres modules (par leurs exports, hooks et registres) : isolés dans bridge/.
VavaMagic.LINKS = {
    INVENTORY = 'vava_inventory',
    ITEMS_REGISTRY = 'vava_inventory:items',
    ADMIN = 'vava_admin',
    HEALTH = 'vava_health',
    HUD = 'vava_hud',
    CHAT = 'chat',
}
