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
    SHEET = 'vava_magic:sheetChanged',      -- vue de la fiche { isMage, spells, selected, sigilCount, sigilLimit, lightColor }
    MANA = 'vava_magic:mana',               -- (valeur, max, points, périodeMs, écouléMs) au seul mage
    CAST_ABORT = 'vava_magic:castAbort',    -- (idIncantation, code) incantation arrêtée par le serveur
    FRAGMENTS = 'vava_magic:fragments',     -- (lanceur, idIncantation, mots, duréeMs) aux seuls joueurs à < 3 m
    MURMUR = 'vava_magic:murmur',           -- message reçu { from?, text, waypoint? }
    SIGIL_OFFER = 'vava_magic:sigilOffered', -- (idOffre, secondes) : on vous tend un sigil
    SIGIL_NAMING = 'vava_magic:sigilNaming', -- (idOffre, secondes) : nommer le sigil reçu en retour
    SIGIL_CLOSED = 'vava_magic:sigilClosed', -- (idOffre) offre close (expirée, refusée, conclue)
    PROJECTILE = 'vava_magic:projectile',   -- lancer { id, spell, caster, dx, dy, dz, speed, range, level, fizzle?,
                                            -- target?, homing? } aux joueurs proches
    PROJECTILE_END = 'vava_magic:projectileEnd', -- (id, x, y, z, sort) impact validé par le serveur
    TARGETED = 'vava_magic:targeted',       -- () à la seule cible verrouillée d'un sort d'attaque : un frisson
    DAMAGE = 'vava_magic:damage',           -- (part de vie) sans vava_health : la victime applique la blessure
    GRIMOIRE = 'vava_magic:openGrimoire',   -- grimoire utilisé
    REGISTER = 'vava_magic:openRegister',   -- { id, pages, count, max } registre utilisé
    CHAT = 'vava_magic:chat',               -- lignes de réponse d'une commande
    ADMIN = 'vava_magic:admin',             -- le joueur peut se servir des commandes du Conseil (suggestions)
    COOLDOWNS = 'vava_magic:cooldowns',     -- () recharges effacées par le Conseil
    CONDITIONS = 'vava_magic:conditions',   -- { état = durée en ms } au seul joueur affecté (minuteries de ses icônes)
    HIT = 'vava_magic:hit',                 -- (élément) à la seule victime d'un sort : geste de réaction, effet d'écran
    PUSH = 'vava_magic:push',               -- (dx, dy, vitesse) à la seule victime d'un recul
    ZONE = 'vava_magic:zone',               -- zone au sol { id, kind, element, spell, level, shape, … } aux joueurs proches
    ZONE_END = 'vava_magic:zoneEnd',        -- (id) zone éteinte, à ceux qui la connaissaient
    BURST = 'vava_magic:burst',             -- effet instantané { spell, caster, x, y, z, level, … } aux joueurs proches
                                            -- (nova, vague, secousse, rempart qui se dresse ou s'effondre)
}

-- Intentions du client (RPC du core). Chaque sort a en plus les siennes : BEGIN_PREFIX .. sort, FINISH_PREFIX .. sort.
VavaMagic.RPC = {
    SHEET = 'vava_magic:sheet',
    SELECT = 'vava_magic:select',         -- (nom du sort | '') sort prêt dans les mains, gardé dans la fiche
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
    PROJECTILE_IMPACT = 'vava_magic:projectileImpact', -- (lancer, cible, x, y, z) impact vu par le client du lanceur
    REGISTER_TEAR = 'vava_magic:registerTear',
}
VavaMagic.BEGIN_PREFIX = 'vava_magic:begin:'
VavaMagic.FINISH_PREFIX = 'vava_magic:finish:'

-- Clés des state bags, posés par le serveur sur le ped d'un joueur (ou l'objet d'un orbe) : reçus par les seuls
-- joueurs proches. Valeurs : tables à clés nommées uniquement (msgpack perd les clés d'une table mixte).
VavaMagic.STATES = {
    CASTING = 'vava_magic:casting', -- { spell, level } incantation en cours (effets des mains selon l'élément et le niveau)
    GLOW = 'vava_magic:glow',       -- true : ses yeux s'illuminent (murmure reçu)
    LIGHT = 'vava_magic:light',     -- { mode, r, g, b, range, intensity, flicker } lumière portée
    ORB = 'vava_magic:orb',         -- mêmes champs : orbe ancré (objet créé par le serveur)
    CONDITIONS = 'vava_magic:conditions', -- { burn?, wet?, slow? (force), stagger?, knockdown?, frozen?, immune? } états du joueur
}

-- Hooks déclenchés par le module.
VavaMagic.HOOKS = {
    CASTING = 'vava_magic:castStarting',          -- before : { source, characterId, spell, level } — refus possible
    CAST = 'vava_magic:castDone',                 -- after : { source, characterId, spell, level, success }
    LEVEL = 'vava_magic:levelUp',                 -- after : { source, characterId, spell, level }
    MAGE = 'vava_magic:mageChanged',              -- after : { source, characterId, isMage }
    STATE = 'vava_magic:stateApplying',           -- before : { source, state, durationMs, caster?, spell? } — refus
                                                   -- possible (résistance, objet protecteur…)
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

-- Types de sort et visées comprises par le noyau.
VavaMagic.SPELL_TYPES = { projectile = true, zone = true, utilitaire = true }
VavaMagic.CONDITION_NAMES = { burn = true, wet = true, slow = true, stagger = true, knockdown = true, frozen = true }
VavaMagic.AIM_KINDS = { projectile = true, point = true, self = true, none = true }
-- formes de l'aperçu au sol : disque, ligne (un ou deux segments), cône devant le lanceur
VavaMagic.AIM_SHAPES = { circle = true, line = true, cone = true }

-- Liens avec les autres modules (par leurs exports, hooks et registres) : isolés dans bridge/.
VavaMagic.LINKS = {
    INVENTORY = 'vava_inventory',
    ITEMS_REGISTRY = 'vava_inventory:items',
    ADMIN = 'vava_admin',
    HEALTH = 'vava_health',
    HUD = 'vava_hud',
    CHAT = 'vava_chat',
}
