--[[
    vava_combat/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole : évènement ciblé, statebag du
           bouclier accroché, champ de personnage, hooks émis, catégories d'armes (liste fermée de COMBAT_V1), noms des
           états de l'inventaire lus par le client, bornes et motifs de validation.
    Dépendances : aucune
]]

VavaCombat = {}

-- Évènement serveur → client, toujours vers le seul joueur concerné (core.net.send, compté).
VavaCombat.EVENTS = {
    NOTIFY = 'vava_combat:notify',      -- texte, nature : seuil d'usure franchi, réponse de /armes sans vava_chat
}

-- Statebag du ped du porteur d'un bouclier accroché : { id, item } ou rien, écrit et gardé par le serveur.
VavaCombat.SHIELD_STATE = 'vava_combat:shield'
-- Champ de personnage privé : numéro de la pile du bouclier accroché (retrouvé à la reconnexion).
VavaCombat.SHIELD_FIELD = 'vava_combat:hungShield'

-- Hooks émis.
VavaCombat.HOOKS = {
    SHIELD_HANG = 'vava_combat:shieldHang',  -- before (accroche seule, annulable) puis after (accroche et décrochage)
    DULLED = 'vava_combat:dulled',           -- after : une arme vient d'atteindre 0 de solidité
}

-- Catégories d'armes : liste fermée (docs/plan/COMBAT_V1.md § 2). Les clés de config.categories doivent être
-- exactement celles-ci.
VavaCombat.CATEGORIES = { 'une_main', 'deux_mains', 'dague', 'baton', 'bouclier' }
VavaCombat.SHIELD_CATEGORY = 'bouclier'

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
