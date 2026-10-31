--[[
    vava_gathering/config_client.lua
    Rôle : réglages de la récolte que lit le client : distance d'invite et annulation au mouvement, streaming des
           props, carte (blips), genres de zone d'eau, touches, outils, ressources, zones et nœuds, animations.
           Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste (bandes de vitalité, cicatrice,
           réaction de la terre, saisons, tolérances du serveur, durée et qualité d'une récolte, pêche : barre de
           tension envoyée à la touche, tolérances, prise ; journal, droits, débits, objets déclarés, textes) est dans
           config.lua, servi au seul serveur (T-132).
    Les zones et nœuds ci-dessous sont des EXEMPLES autour du point d'apparition par défaut : à remplacer par les lieux du
    royaume. Les modèles de props et d'accessoires sont ceux du jeu de base : à ajuster avec les packs médiévaux.
    Dépendances : shared/constants.lua
]]

VavaGathering.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.7.0)

    -- Distance d'invite et déplacement qui annule un geste en cours. Les tolérances, le délai entre deux récoltes et
    -- l'oubli d'une récolte jamais finie sont dans config.lua (lus par le seul serveur).
    interact = {
        distance = 2.5,             -- distance maximale au nœud (m) pour l'invite côté client
        moveCancel = 1.5,           -- client : se déplacer de plus de 1,5 m interrompt le geste
    },

    -- Client : props des nœuds créés à portée (`radius`, mètres), remplacés par le modèle « épuisé » quand la zone l'est.
    -- Les nœuds sont regroupés par zone : seuls ceux d'une zone à portée sont mesurés. Un passage toutes les `pollMs`
    -- près d'une zone, toutes les `idlePollMs` quand aucun nœud ne peut être à moins de `radius` + `idleMargin` (la
    -- marge couvre le chemin d'un cavalier rapide pendant `idlePollMs`, pour que les props apparaissent comme avant).
    -- Le battement d'abonnement des zones (`subscribeSlack`) est dans config.lua (lu par le seul serveur).
    streaming = { radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, modelTimeoutMs = 5000 },

    -- Carte : un blip par zone (icône `sprite` et couleur `colour` du jeu selon le genre, liste sur docs.fivem.net →
    -- Blips), nommé comme elle, à courte portée (petite carte à l'approche, toujours sur la grande), et le cercle
    -- translucide de son rayon (`ring`). Posés par le client depuis cette config : rien ne circule. Le panneau des
    -- zones pose le repère de la carte sur une zone.
    map = {
        blips = true,
        scale = 0.85,
        ring = { show = true, alpha = 64 },         -- cercle du rayon sur la grande carte (alpha 0 à 255)
        kinds = {
            foret = { sprite = 141, colour = 25 },      -- gibier, vert forêt
            mine = { sprite = 319, colour = 40 },       -- foreuse, gris sombre
            prairie = { sprite = 496, colour = 46 },    -- feuille, or
            eau = { sprite = 410, colour = 3 },         -- barque, bleu
        },
        default = { sprite = 1, colour = 0 },           -- genre sans icône : point blanc
    },

    -- Genres de zone d'eau (`zones[].kind`) : leurs textes parlent de l'eau, non de la terre (échec de la bande,
    -- épuisement, invite).
    waterKinds = { eau = true },

    keys = { interact = 'E', zones = 'O' },
    labels = { interact = 'Récolter (nœud proche)', zones = 'Ouvrir le panneau des zones de récolte' },

    -- Outils : objet de l'inventaire → genre (requis par les ressources), puissance (divise la durée), bonus de
    -- rendement (unités) et de qualité (points de score), usure par usage (points de solidité). Ils sont aussi
    -- déclarés comme objets dans config.lua (`items`) et tenus en main (`held`).
    tools = {
        hache_fer = { kind = 'hache', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
        pioche_fer = { kind = 'pioche', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 2 },
        faucille_fer = { kind = 'faucille', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
        couteau_fer = { kind = 'couteau', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
        canne_a_peche = { kind = 'canne', power = 1.0, yieldBonus = 0, qualityBonus = 0, wear = 1 },
    },

    -- Ressources : ce qu'un nœud produit. `tool` : genre d'outil requis en main (nil : à la main). `fishing` : nœud
    -- d'eau, mini-jeu de tension. `yield` : { min, max } unités avant bonus. `anim` : clé de `anims`.
    resources = {
        chene = { label = 'Chêne', item = 'bois_chene', skill = 'bucheronnage', tool = 'hache', difficulty = 15, xp = 12, yield = { 2, 4 }, durationMs = 5000, anim = 'chop' },
        pin = { label = 'Pin', item = 'bois_pin', skill = 'bucheronnage', tool = 'hache', difficulty = 5, xp = 8, yield = { 2, 4 }, durationMs = 4500, anim = 'chop' },
        fer = { label = 'Filon de fer', item = 'minerai_fer', skill = 'minage', tool = 'pioche', difficulty = 25, xp = 14, yield = { 1, 3 }, durationMs = 6000, anim = 'mine' },
        cuivre = { label = 'Filon de cuivre', item = 'minerai_cuivre', skill = 'minage', tool = 'pioche', difficulty = 10, xp = 10, yield = { 1, 3 }, durationMs = 5500, anim = 'mine' },
        pierre = { label = 'Roche', item = 'pierre', skill = 'minage', tool = 'pioche', difficulty = 0, xp = 6, yield = { 2, 5 }, durationMs = 4000, anim = 'mine' },
        lavande = { label = 'Lavande', item = 'lavande', skill = 'herboristerie', tool = nil, difficulty = 5, xp = 8, yield = { 1, 3 }, durationMs = 3500, anim = 'pick' },
        sauge = { label = 'Sauge', item = 'sauge', skill = 'herboristerie', tool = 'faucille', difficulty = 20, xp = 12, yield = { 1, 3 }, durationMs = 4000, anim = 'pick' },
        truite = { label = 'Banc de truites', item = 'truite', skill = 'peche', tool = 'canne', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 0, anim = 'fish', fishing = true },
        brochet = { label = 'Banc de brochets', item = 'brochet', skill = 'peche', tool = 'canne', difficulty = 35, xp = 16, yield = { 1, 1 }, durationMs = 0, anim = 'fish', fishing = true },
        piste_lievre = { label = 'Piste de lièvre', item = 'viande_lievre', skill = 'chasse', tool = 'couteau', difficulty = 10, xp = 10, yield = { 1, 2 }, durationMs = 5000, anim = 'skin', extra = { item = 'peau_lievre', chance = 0.5 } },
        piste_cerf = { label = 'Piste de cerf', item = 'viande_cerf', skill = 'chasse', tool = 'couteau', difficulty = 40, xp = 18, yield = { 2, 3 }, durationMs = 7000, anim = 'skin', extra = { item = 'peau_cerf', chance = 0.7 } },
    },

    -- Zones : `cost` vitalité perdue par récolte réussie, `regenPerHour` points rendus par heure, `scarHours` durée
    -- de la cicatrice. EXEMPLES autour du point d'apparition par défaut.
    -- Entières ici, comme les nœuds, ressources, outils et animations : le client les lit par identifiant ou les parcourt
    -- (props, blips, invite).
    zones = {
        { id = 'foret_brume', label = 'Forêt de Brume', kind = 'foret', x = -320.0, y = -880.0, z = 31.0, radius = 120.0, cost = 2.0, regenPerHour = 4.0, scarHours = 48 },
        { id = 'mine_du_val', label = 'Mine du Val', kind = 'mine', x = -180.0, y = -1010.0, z = 29.0, radius = 80.0, cost = 2.5, regenPerHour = 3.0, scarHours = 72 },
        { id = 'prairie_haute', label = 'Prairie Haute', kind = 'prairie', x = -380.0, y = -1060.0, z = 31.0, radius = 100.0, cost = 1.5, regenPerHour = 6.0, scarHours = 24 },
        { id = 'riviere_claire', label = 'Rivière Claire', kind = 'eau', x = -120.0, y = -880.0, z = 29.0, radius = 60.0, cost = 2.0, regenPerHour = 5.0, scarHours = 36 },
    },

    -- Nœuds : `charges` maximum, `regenMs` par charge rendue, `prop` modèles normal et épuisé (créés par le client).
    nodes = {
        { id = 'foret_brume_chene_1', zone = 'foret_brume', resource = 'chene', x = -300.0, y = -900.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 600000, prop = { model = 'prop_tree_oak_01', depleted = 'prop_tree_stump_01' } },
        { id = 'foret_brume_chene_2', zone = 'foret_brume', resource = 'chene', x = -330.0, y = -870.0, z = 31.0, heading = 40.0, charges = 3, regenMs = 600000, prop = { model = 'prop_tree_oak_01', depleted = 'prop_tree_stump_01' } },
        { id = 'foret_brume_pin_1', zone = 'foret_brume', resource = 'pin', x = -350.0, y = -910.0, z = 31.0, heading = 90.0, charges = 4, regenMs = 480000, prop = { model = 'prop_tree_pine_01', depleted = 'prop_tree_stump_01' } },
        { id = 'mine_du_val_fer_1', zone = 'mine_du_val', resource = 'fer', x = -190.0, y = -1000.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000, prop = { model = 'prop_rock_1_a', depleted = 'prop_rock_1_f' } },
        { id = 'mine_du_val_cuivre_1', zone = 'mine_du_val', resource = 'cuivre', x = -170.0, y = -1020.0, z = 29.0, heading = 0.0, charges = 3, regenMs = 900000, prop = { model = 'prop_rock_1_b', depleted = 'prop_rock_1_f' } },
        { id = 'mine_du_val_pierre_1', zone = 'mine_du_val', resource = 'pierre', x = -200.0, y = -1030.0, z = 29.0, heading = 0.0, charges = 5, regenMs = 600000, prop = { model = 'prop_rock_1_c', depleted = 'prop_rock_1_f' } },
        { id = 'prairie_haute_lavande_1', zone = 'prairie_haute', resource = 'lavande', x = -370.0, y = -1050.0, z = 31.0, heading = 0.0, charges = 4, regenMs = 420000, prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },
        { id = 'prairie_haute_sauge_1', zone = 'prairie_haute', resource = 'sauge', x = -395.0, y = -1075.0, z = 31.0, heading = 0.0, charges = 3, regenMs = 540000, prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },
        { id = 'prairie_haute_lievre_1', zone = 'prairie_haute', resource = 'piste_lievre', x = -400.0, y = -1040.0, z = 31.0, heading = 0.0, charges = 2, regenMs = 1200000, prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },
        { id = 'prairie_haute_cerf_1', zone = 'prairie_haute', resource = 'piste_cerf', x = -360.0, y = -1090.0, z = 31.0, heading = 0.0, charges = 1, regenMs = 2400000, prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },
        { id = 'riviere_claire_truite_1', zone = 'riviere_claire', resource = 'truite', x = -110.0, y = -870.0, z = 29.0, heading = 0.0, charges = 4, regenMs = 600000, prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },
        { id = 'riviere_claire_brochet_1', zone = 'riviere_claire', resource = 'brochet', x = -130.0, y = -895.0, z = 29.0, heading = 0.0, charges = 2, regenMs = 1200000, prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        chop = { dict = 'melee@large_wpn@streamed_core', anim = 'ground_attack_on_spot', flag = 1 },
        mine = { scenario = 'WORLD_HUMAN_HAMMERING' },
        pick = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        fish = { scenario = 'WORLD_HUMAN_STAND_FISHING' },
        skin = { dict = 'amb@medic@standing@kneel@base', anim = 'base', flag = 1 },
    },
}
