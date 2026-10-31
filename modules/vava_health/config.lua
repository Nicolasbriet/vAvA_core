--[[
    vava_health/config.lua
    Rôle : réglages de la santé, de la mise à terre et de la réanimation que lit le seul serveur (servi au seul
           serveur, jamais téléchargé par les joueurs). Vie exprimée de 0 à 1 : part de la vie située au-dessus du
           seuil de mise à terre. Relevés de la vie, chaîne de dégâts, envoi de la vie, apparition, contrôles natifs,
           journal, portée et vie de la réanimation, lieux de soins, soins, débits. Complète la table ouverte par
           config_client.lua (seuil, délais à terre, geste, touches, messages, jauge) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaHealth.config

config.coreVersion = '0.10.0'     -- core.net.send : tous les envois du module sont comptés (/vava_reseau)

-- Serveur : la vie de référence est celle du serveur ; le ped de chaque joueur est lu (une native par joueur) pour
-- les pertes natives (chute, noyade…) et pour corriger un client qui garde plus de vie qu'il n'en a.
config.pollMs = 500
config.sampleMs = 10000           -- écriture différée de la vie dans le personnage après des coups ou des pertes
config.sampleEpsilon = 0.01       -- écart minimal pour la réécrire
config.graceMs = 3000             -- après une apparition ou une réanimation, la vie lue côté serveur peut être en retard

-- Chaîne de dégâts (export hit) : tous les coups et les sorts passent par elle (docs/plan/COMBAT_V1.md § 1).
config.chain = {
    healthPoints = 100,     -- points d'une vie pleine : échelle des paquets (amount = 25 : un quart de la vie)
    maxAmount = 200,        -- plafond d'un coup, avant et après modificateurs (deux vies pleines)
    -- types de dégâts admis (liste fermée, choix des éditeurs de l'Atelier) ; `pur` : ignoré par les résistances
    -- par convention ; `monde` : réservé aux pertes natives lues par le serveur
    kinds = { 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur', 'privation',
        'monde' },
    parts = { 'tete', 'torse', 'bras', 'jambes' },  -- partie du corps touchée (facultative)
    -- étiquettes admises dans `tags` (liste fermée : conditions de l'Atelier)
    tags = { 'melee', 'ranged', 'spell', 'area', 'overTime', 'native', 'legacy', 'reflected', 'parryable',
        'unblockable', 'undodgeable', 'launched' },
    maxTags = 8,
    pvp = true,             -- false : tout coup venu d'un autre joueur est annulé (pvp_off)
    -- coup déjà lancé (étiquette `launched` et `launchedAt` posés par le module serveur qui frappe : projectile en
    -- vol, présage d'un sort) : il porte encore si sa source tombe à terre après le lancement, pendant ce délai au
    -- plus (le plus long vol ou présage, plus la latence du signalement d'impact) ; au-delà, annulé source_downed
    launchedMaxMs = 4000,
    maxHitsPerSecond = 20,  -- coups traités par cible et par seconde ; au-delà : too_many_hits
    maxDepth = 2,           -- un coup lancé pendant un autre (renvoi) est permis une fois ; au-delà : too_deep
    maxModifiers = 32,      -- entrées du registre vava_health:modifiers
    slowModifierMs = 5,     -- modificateur plus lent : signalé (une ligne par minute et par modificateur)
    slowHitMs = 15,         -- coup entier plus lent : signalé (une ligne par minute)
    errorLogMs = 60000,     -- intervalle des lignes d'erreur d'un même modificateur
}

-- Lecture du ped après un ordre du serveur.
config.sync = {
    tolerance = 0.02,       -- écart toléré entre le ped lu et la valeur du serveur (≈ 2 points GTA sur 100)
    applyMs = 1500,         -- après un envoi de vie, la lecture du ped est ignorée ce temps…
    maxPingMs = 1000,       -- … plus deux fois le ping du joueur, au plus cette valeur
    resendMs = 2000,        -- ped au-dessus de la valeur du serveur : vie renvoyée au plus toutes les 2 s…
    maxResendMs = 30000,    -- … délai doublé après chaque correction sans effet, jusqu'à 30 s (2 s dès l'accord)
    logEvery = 10,          -- console à la 1re correction d'un joueur, puis toutes les 10
}

-- Apparition non confirmée par le client : ped lu d'office ce délai après l'ordre, s'il existe.
config.spawn = { confirmTimeoutMs = 20000 }

-- Dégâts natifs de GTA venus d'un joueur, annulés côté serveur (évènements du moteur OneSync).
config.natives = {
    weaponDamage = true,    -- coup d'arme ou de poing d'un joueur sur un autre joueur
    unresolved = true,      -- … ou sur une victime introuvable côté serveur
    explosions = true,      -- toute explosion lancée par un joueur (aucun module n'en crée)
    fires = true,           -- tout feu lancé par un joueur
    projectiles = true,     -- tout projectile lancé par un joueur (à revoir avec les arcs, hors v1)
    logMs = 60000,          -- au plus une ligne de console par joueur et par minute
}

-- Journal des coups (table vava_health_hits) : coups venus d'un autre joueur et mises à terre.
config.journal = {
    flushMs = 10000,
    batch = 50,             -- lignes par requête
    queueMax = 2000,        -- lignes gardées si la base ne répond pas ; au-delà, abandonnées (console)
    retentionDays = 30,     -- purge au démarrage puis chaque jour (0 : jamais)
}

-- Relever quelqu'un (le geste joué par le client est dans config_client.lua).
local assist = config.assist
assist.distance = 2.0             -- portée (m) pour relever quelqu'un, lue côté serveur
assist.tolerance = 1.0            -- marge (m) acceptée à la fin du geste
assist.durationMs = 8000
assist.health = 0.25              -- vie après une réanimation
assist.item = nil                 -- objet requis et consommé (ex. 'bandage') ; nil : aucun, en attendant les métiers

-- Rendre l'âme (la touche à maintenir est dans config_client.lua).
local respawn = config.respawn
respawn.health = 0.5              -- vie après avoir rendu l'âme
-- Lieux de soins, provisoires en attendant la carte médiévale : le plus proche est choisi.
respawn.points = {
    { x = 298.6, y = -584.5, z = 43.26, heading = 70.0 },
    { x = 1839.0, y = 3672.9, z = 34.28, heading = 210.0 },
}

config.healing = { fullAt = 0.98 }  -- au-delà, un objet de soin est refusé (rien n'est gaspillé)

config.rateLimits = {
    assist = { capacity = 3, refillPerSecond = 0.5 },
    giveUp = { capacity = 2, refillPerSecond = 0.2 },
}
