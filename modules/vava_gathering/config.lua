--[[
    vava_gathering/config.lua
    Rôle : donnée de jeu de la récolte lue par le seul serveur (servi au seul serveur, jamais téléchargé par les
           joueurs) : bandes de vitalité et leurs effets, cicatrice, réaction de la terre, saisons, tolérances des
           gestes, durée et qualité d'une récolte, pêche (touche, tolérances, prise), battement d'abonnement des zones,
           journal, droits, débits, solidité par défaut d'un outil, objets déclarés à l'inventaire, textes. Complète la
           table ouverte par config_client.lua (invite, barre de tension, streaming, carte, touches, outils, ressources,
           zones et nœuds, animations) sans en réécrire une clé (T-132). Modifiable sans toucher au code. Durées en
           millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaGathering.config

config.coreVersion = '0.11.0'   -- abonnements de zone (core.zones)
config.dependencies = { vava_inventory = '1.4.0', vava_skills = '1.0.0' }

-- Vitalité d'une zone (0 à 100). Au-dessus de `normal` : plein rendement ; entre `reduced` et `normal` : rendement
-- et qualité réduits, chance d'échec ; sous `reduced` : zone épuisée (props remplacés), rendement effondré ;
-- à 0 : cicatrice, régénération multipliée par `scar.regenFactor` pendant `scarHours` de la zone.
config.bands = {
    normal = 60,
    reduced = 25,
    effects = {
        normal = { yield = 1.0, tierMalus = 0, failure = 0.0 },
        reduced = { yield = 0.6, tierMalus = 1, failure = 0.25 },
        depleted = { yield = 0.2, tierMalus = 2, failure = 0.5 },
    },
}
config.scar = { regenFactor = 0.2 }
-- épuisements répétés (cicatrices) dans la fenêtre → hook vava_gathering:earthReaction (contenu plus tard)
config.earthReaction = { depletions = 3, windowDays = 7 }

-- Saisons du royaume (vava_time, facultatif : sans lui, aucun effet). Facteurs par saison et par compétence de la
-- ressource : `regen` vitesse à laquelle les nœuds rendent leurs charges (0 : rien ne repousse et le temps ne
-- compte pas), `yield` unités récoltées (au moins une). Absent : 1. Le minage ne dépend d'aucune saison.
config.seasons = {
    regen = {
        printemps = { herboristerie = 1.25, chasse = 1.25, peche = 1.25 },
        automne = { herboristerie = 0.75, chasse = 1.25 },
        hiver = { herboristerie = 0.25, peche = 0.5, chasse = 0.5, bucheronnage = 0.75 },
    },
    yield = {
        automne = { chasse = 1.25 },
        hiver = { herboristerie = 0.5 },
    },
}

-- Tolérances des gestes, lues par le seul serveur : ajoutées à `interact` (config_client.lua), dont le client lit la
-- distance d'invite et l'annulation au mouvement (relecture sécurité S-5 de T-132).
config.interact.serverTolerance = 1.5      -- marge ajoutée côté serveur (centre du prop, latence) : distance + tolérance
config.interact.cooldownMs = 1500          -- entre deux récoltes d'un même joueur
config.interact.finishToleranceMs = 400    -- avance tolérée du client sur la durée annoncée (latence)
config.interact.expireMs = 30000           -- une récolte commencée et jamais finie est oubliée

-- Durée d'un geste : base de la ressource × (1 − niveau × skillFactor) ÷ puissance de l'outil, bornée.
config.duration = { skillFactor = 0.004, minMs = 1200 }

-- Qualité : score 0–100 = niveau × skill + qualité de l'outil (0–100, 50 sans qualité connue) × tool
-- + vitalité × vitality ± jitter, puis palier 1 à 5 selon `tiers` (bornes basses des paliers 2 à 5), moins le
-- malus de la bande. `origin` : écrire le nom de la zone dans les métadonnées (les piles ne se mélangent alors
-- pas d'une zone à l'autre).
config.quality = {
    weights = { skill = 0.5, tool = 0.3, vitality = 0.2 },
    jitter = 8,
    tiers = { 20, 40, 60, 85 },
    defaultToolQuality = 50,
    origin = true,
}

-- Pêche : la ligne est lancée (begin) ; le serveur tire le moment de la touche, prévient le client, qui tient la
-- tension (`fishing.tension`, config_client.lua) dans la zone pendant `durationMs` ; `reel` dit si la tenue a réussi.
-- La barre ne peut que faire rater : ligne tenue, le serveur tire encore la prise (`catch`). Un raté n'use aucune
-- charge. Lus par le seul serveur : ajoutés à `fishing`.
local fishing = config.fishing
fishing.biteMinMs = 4000
fishing.biteMaxMs = 14000
fishing.reelToleranceMs = 500      -- avance tolérée sur la durée de la barre
fishing.reelGraceMs = 4000         -- retard toléré (au-delà : la prise s'est échappée)
-- Prise tirée par le serveur quand la ligne a tenu : chance que le poisson se décroche, de `novice` au niveau 0
-- de Pêche à `master` au niveau `masterLevel` (linéaire entre les deux), plus le supplément de la bande de la
-- zone (`bands`). Parts de 0 à 1. L'échec de la bande (`bands.effects.failure`) s'applique ensuite, comme à
-- toute récolte. Décision du 30 octobre 2026 (une seule cause par message) : supplément à 0 partout, le
-- décrochage ne dépend que du niveau ; l'état de l'eau ne joue que par l'échec de la bande. Réglage gardé pour
-- pouvoir le remettre (essai d'avant : reduced = 0.05, depleted = 0.10).
fishing.catch = {
    novice = 0.25,
    master = 0.02,
    masterLevel = 100,
    bands = { normal = 0.0, reduced = 0.0, depleted = 0.0 },
}

-- État des zones et des nœuds (bande, cicatrice, charges) : envoyé par le core aux seuls joueurs à moins de
-- `streaming.radius` (config_client.lua) + `subscribeSlack` mètres du cercle qui englobe les nœuds d'une zone
-- (abonnements de zone) : il est là avant que le premier prop puisse apparaître ; seuls les nœuds des zones reçues sont
-- mesurés. Une zone reçue fait aussitôt un passage : `subscribeSlack` ne couvre que l'attente du passage du core, il
-- doit valoir au moins vitesse maximale × `zones.passMs` du core + 5 m (20 m : cavalier au galop, ~15 m/s, avec
-- passMs = 1000 ; à passer à 35 m avec passMs = 2000 ou pour une monture plus rapide). `radius` + `subscribeSlack` :
-- 500 m au plus. Lu par le seul serveur : ajouté à `streaming`.
config.streaming.subscribeSlack = 20.0

config.persistence = { flushMs = 10000 }   -- écriture groupée des zones et nœuds modifiés
config.logRetentionDays = 90

config.admin = {
    permission = 'metiers',         -- droit vava_admin ; sans lui, ACE
    ace = 'metiers.admin',
    command = 'recolte',
}

config.rateLimits = {
    begin = { capacity = 4, refillPerSecond = 1 },
    cancel = { capacity = 4, refillPerSecond = 1 },
    finish = { capacity = 4, refillPerSecond = 1 },
    reel = { capacity = 4, refillPerSecond = 1 },
    zones = { capacity = 3, refillPerSecond = 0.5 },
}

-- Un outil sans solidité connue (donné par le Conseil, antérieur à l'artisanat) en reçoit une au premier usage.
config.toolDefaults = { durability = 100 }

-- Objets déclarés à l'inventaire par ce module (matières premières et outils de base). Images : web/items/<nom>.svg.
-- `held` : accessoire tenu en main (os main droite par défaut, décalages à régler modèle par modèle).
config.items = {
    bois_chene = { label = 'Bûche de chêne', description = 'Bois dur et serré, prisé des menuisiers.', width = 1, height = 2, weight = 900, stack = 20, category = 'materiau' },
    bois_pin = { label = 'Bûche de pin', description = 'Bois tendre et résineux.', width = 1, height = 2, weight = 700, stack = 20, category = 'materiau' },
    minerai_fer = { label = 'Minerai de fer', description = 'Roche lourde veinée de rouille.', width = 1, height = 1, weight = 800, stack = 30, category = 'materiau' },
    minerai_cuivre = { label = 'Minerai de cuivre', description = 'Roche aux reflets verts.', width = 1, height = 1, weight = 750, stack = 30, category = 'materiau' },
    pierre = { label = 'Pierre', description = 'Un bloc brut, bon pour les murs.', width = 1, height = 1, weight = 1200, stack = 30, category = 'materiau' },
    lavande = { label = 'Lavande', description = 'Brins violets au parfum entêtant.', width = 1, height = 1, weight = 50, stack = 40, category = 'materiau' },
    sauge = { label = 'Sauge', description = 'Feuilles grises, amères et bienfaisantes.', width = 1, height = 1, weight = 50, stack = 40, category = 'materiau' },
    truite = { label = 'Truite', description = 'Encore frétillante.', width = 2, height = 1, weight = 600, stack = 10, category = 'nourriture' },
    brochet = { label = 'Brochet', description = 'Long, nerveux, aux dents fines.', width = 3, height = 1, weight = 2000, stack = 5, category = 'nourriture' },
    viande_lievre = { label = 'Viande de lièvre', description = 'Maigre et goûteuse.', width = 1, height = 1, weight = 400, stack = 10, category = 'nourriture' },
    viande_cerf = { label = 'Viande de cerf', description = 'Une pièce sombre et ferme.', width = 2, height = 1, weight = 1500, stack = 10, category = 'nourriture' },
    peau_lievre = { label = 'Peau de lièvre', description = 'Fine, à tanner sans attendre.', width = 1, height = 1, weight = 200, stack = 10, category = 'materiau' },
    peau_cerf = { label = 'Peau de cerf', description = 'Épaisse, pour le cuir.', width = 2, height = 2, weight = 1800, stack = 5, category = 'materiau' },
    hache_fer = { label = 'Hache de bûcheron', description = 'Fer large emmanché de frêne.', width = 1, height = 3, weight = 2200, stack = 1, category = 'outil',
        held = { model = 'prop_tool_fireaxe', offset = { 0.1, 0.02, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    pioche_fer = { label = 'Pioche', description = 'Pointe de fer sur un manche court.', width = 1, height = 3, weight = 2500, stack = 1, category = 'outil',
        held = { model = 'prop_tool_pickaxe', offset = { 0.1, 0.02, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    faucille_fer = { label = 'Faucille', description = 'Lame courbe pour les herbes.', width = 1, height = 2, weight = 600, stack = 1, category = 'outil',
        held = { model = 'prop_tool_hammer', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    couteau_fer = { label = 'Couteau de chasse', description = 'Pour dépecer et dépouiller.', width = 1, height = 2, weight = 400, stack = 1, category = 'outil',
        held = { model = 'w_me_knife_01', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
    canne_a_peche = { label = 'Canne à pêche', description = 'Noisetier souple, ligne de crin.', width = 1, height = 4, weight = 800, stack = 1, category = 'outil',
        held = { model = 'prop_fishing_rod_01', offset = { 0.1, 0.0, 0.0 }, rotation = { 0.0, 0.0, 0.0 } } },
}

-- Textes des notifications (serveur → joueur). %s : libellé, %d : nombre.
config.messages = {
    harvested = '%s : %d × %s (%s).',                     -- ressource, quantité, objet, palier
    harvestedExtra = 'Et aussi : %s.',
    failed = 'La récolte échoue : la terre est fatiguée ici.',
    failedWater = 'Ces eaux sont fatiguées : le poisson vous échappe.',     -- zone d'eau (`waterKinds`)
    escaped = 'La prise s\'est échappée.',
    slipped = 'Au dernier moment, le poisson se décroche.',
    noTool = 'Il vous faut %s en main.',                  -- genre d'outil (libellé)
    brokenTool = 'Votre outil est brisé.',
    noCharges = 'Il n\'y a plus rien à prendre ici pour le moment.',
    depleted = '%s est épuisée : la terre a besoin de repos.',
    depletedWater = '%s est épuisée : l\'eau a besoin de repos.',          -- zone d'eau (`waterKinds`)
    scarred = '%s porte une cicatrice : elle mettra longtemps à se remettre.',
    toolWorn = 'Votre %s s\'use (%d).',
    toolBroken = 'Votre %s se brise !',
    noSpace = 'Vous ne pouvez rien porter de plus.',
    tiers = { 'grossier', 'commun', 'soigné', 'excellent', 'chef-d\'œuvre' },
    toolKinds = { hache = 'une hache', pioche = 'une pioche', faucille = 'une faucille', couteau = 'un couteau', canne = 'une canne à pêche' },
}
