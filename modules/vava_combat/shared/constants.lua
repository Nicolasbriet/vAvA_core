--[[
    vava_combat/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : RPC des techniques, évènements
           ciblés, statebag du bouclier accroché, champ de personnage, hooks émis, catégories d'armes (liste fermée de
           COMBAT_V1), types de techniques et issues d'un coup, noms des états de l'inventaire lus par le client, bornes
           et motifs de validation.
    Dépendances : aucune
]]

VavaCombat = {}

-- RPC client → serveur (core.rpc : schéma borné, limite de débit) : le seul du module.
VavaCombat.RPC = {
    USE = 'vava_combat:use',            -- (technique, cible verrouillée ou 0) : un coup, jugé par le serveur
}

-- Évènements serveur → client, toujours ciblés (core.net, comptés) : jamais à tous.
VavaCombat.EVENTS = {
    NOTIFY = 'vava_combat:notify',      -- texte, nature : au seul joueur concerné (usure, /armes, coup retenu)
    HIT = 'vava_combat:hit',            -- attaquant, cible, issue : aux joueurs à 30 m de la cible, même instance
}

-- Statebag du ped du porteur d'un bouclier accroché : { id, item } ou rien, écrit et gardé par le serveur.
VavaCombat.SHIELD_STATE = 'vava_combat:shield'
-- Champ de personnage privé : numéro de la pile du bouclier accroché (retrouvé à la reconnexion).
VavaCombat.SHIELD_FIELD = 'vava_combat:hungShield'

-- Hooks émis.
VavaCombat.HOOKS = {
    SHIELD_HANG = 'vava_combat:shieldHang',  -- before (accroche seule, annulable) puis after (accroche et décrochage)
    DULLED = 'vava_combat:dulled',           -- after : une arme vient d'atteindre 0 de solidité
    USING = 'vava_combat:using',             -- before (annulable) : une technique va partir (prison, ligotage, trêve)
}

-- Catégories d'armes : liste fermée (docs/plan/COMBAT_V1.md § 2). Les clés de config.categories doivent être
-- exactement celles-ci.
VavaCombat.CATEGORIES = { 'une_main', 'deux_mains', 'dague', 'baton', 'bouclier' }
VavaCombat.SHIELD_CATEGORY = 'bouclier'

-- Techniques (docs/plan/COMBAT_V1.md § 3) : types admis par le format, et ceux qui frappent (T-112). Les types de
-- défense (T-113) passent le contrôle et sont refusés à l'usage (not_attack).
VavaCombat.TECHNIQUE_TYPES = { 'legere', 'lourde', 'parade', 'blocage', 'esquive', 'garde' }
VavaCombat.ATTACK_TYPES = { 'legere', 'lourde' }
-- identifiant de technique : inclus dans REF_PATTERN (paquet de vava_health), 32 octets au plus
VavaCombat.TECHNIQUE_PATTERN = '^[a-z0-9_]+$'
VavaCombat.TECHNIQUE_MAX = 32
-- Issue d'un coup qui porte, envoyée aux proches (vava_combat:hit).
VavaCombat.OUTCOMES = { 'hit', 'stagger', 'down', 'block', 'parry', 'dodge', 'absorb' }

-- Parties du corps admises dans un coup (liste de vava_health).
VavaCombat.PARTS = { 'tete', 'torse', 'bras', 'jambes' }

-- États de vava_inventory lus par ce module (jamais écrits) : objet tenu, sur le statebag du ped, et champ `owner` du
-- personnage local.
VavaCombat.INVENTORY_HELD_STATE = 'vava_inventory:inHand'
VavaCombat.INVENTORY_HANDS_FIELD = 'vava_inventory:hands'

-- Bornes de validation (protocole).
VavaCombat.ITEM_MAX = 64                       -- octets d'un nom d'objet (schéma du registre des objets)
VavaCombat.REF_MAX = 64                        -- octets d'un identifiant de technique (paquet de vava_health)
-- identifiant de technique : classes ASCII explicites (jamais %w, qui suit la locale), `<éditeur>:<id>` admis
VavaCombat.REF_PATTERN = '^[A-Za-z0-9_%-%.:]+$'
VavaCombat.ID_PATTERN = '^[a-z0-9_]+$'         -- arme, catégorie, famille, type (config)
VavaCombat.MAX_ID = 9007199254740991           -- numéro de pile le plus grand (2^53 - 1)
VavaCombat.MAX_AMOUNT = 200                    -- plafond d'un coup (paquet de vava_health)
VavaCombat.MAX_TAGS = 3                        -- étiquettes qu'un appelant de strike peut ajouter
VavaCombat.MAX_NOTIFICATION = 200              -- octets d'une notification du HUD
VavaCombat.MAX_JOURNAL_LABEL = 32              -- libellé du journal du Registre (vava_admin)
VavaCombat.MODEL_MAX = 64                      -- octets d'un nom de modèle
VavaCombat.MAX_PLAYER = 65535                  -- plus grand numéro de joueur (cible d'un coup, évènement HIT)
VavaCombat.MAX_REASON = 120                    -- octets d'une raison de refus d'un crochet, montrée au joueur
