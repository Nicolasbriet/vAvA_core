--[[
    vava_example_combat/config.lua
    Rôle : réglages de la ressource d'essai de la chaîne de dégâts que lit le seul serveur (servi au seul serveur,
           jamais téléchargé par les joueurs) : version du core, accès, commandes du serveur (dont /frapper_arme,
           T-111), délais, chapitre du Codex, libellés du journal, raisons. Complète la table ouverte par
           config_client.lua (commandes du client, armes et explosion d'essai) sans en réécrire une clé (T-132).
    Dépendances : config_client.lua
]]

local config = VavaExampleCombat.config

config.coreVersion = '0.10.0'

-- Qui peut s'en servir (le serveur revérifie à chaque appel) : droit vava_admin `permission`, ou ACE `ace`.
-- Le mode développement (`set vava_env dev`) est exigé en plus.
config.access = { permission = 'staff', ace = 'vava.dev' }
-- accord demandé par le client avant /arme, /explosion, /tricher
config.accessRateLimit = { capacity = 2, refillPerSecond = 1 }
config.cooldownMs = 500           -- délai entre deux commandes d'un même joueur

-- Commandes du serveur (celles du client, /arme, /explosion, /tricher, sont dans config_client.lua).
local commands = config.commands
commands.hit, commands.dodge, commands.shield = 'frapper', 'esquive', 'bouclier'
commands.resistance, commands.chain = 'resistance', 'chaine'
-- coup de l'arme tenue en main par exports.vava_combat:strike (vava_combat ≥ 1.0.0, facultatif)
commands.weaponHit = 'frapper_arme'
config.chapter = 'Essais de combat'

config.defaultKind = 'tranchant'  -- type d'un coup de /frapper sans type
config.dodgeMs = 3000             -- fenêtre ouverte par /esquive

-- Libellés du journal du Registre (vava_admin:log, 32 signes au plus) ; sans Registre, console du serveur.
config.journal = {
    hit = 'Essai de combat : coup porté',
    modifier = 'Essai de combat : protection',
    weaponHit = 'Essai de combat : coup d\'arme',
}

-- Raisons d'annulation montrées au lanceur (les autres s'affichent telles quelles).
config.reasons = { downed = 'à terre', esquive = 'esquive', pvp_off = 'combats entre joueurs coupés',
    no_weapon = 'aucune arme en main', too_far = 'trop loin' }
