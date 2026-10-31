--[[
    vava_gathering/config_client.lua
    Rôle : réglages de la récolte que lit le client : distance d'invite et annulation au mouvement, streaming des
           props, carte (blips), genres de zone d'eau, touches, outils (leur genre), ressources (libellé, outil, geste,
           modèles), animations. Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste (zones et nœuds,
           graine de l'Atelier depuis 1.8.0 : leur partie client arrive par l'état de zone ; part serveur des
           ressources et des outils ; bandes de vitalité, cicatrice, réaction de la terre, saisons, tolérances du
           serveur, durée et qualité d'une récolte, pêche ; journal, droits, débits, objets déclarés, éditeur de
           l'Atelier, textes) est dans config.lua, servi au seul serveur (T-132, T-102).
    Les modèles de props et d'accessoires sont ceux du jeu de base : à ajuster avec les packs médiévaux.
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
    -- translucide de son rayon (`ring`). Depuis 1.8.0, la liste des zones est demandée au serveur à l'apparition et
    -- gardée en stockage local (rien n'est poussé à tous). Le panneau des zones pose le repère de la carte sur une zone.
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

    -- Genres de zone d'eau (type de lieu d'une zone) : leurs textes parlent de l'eau, non de la terre (échec de la
    -- bande, épuisement, invite).
    waterKinds = { eau = true },

    keys = { interact = 'E', zones = 'O' },
    labels = { interact = 'Récolter (nœud proche)', zones = 'Ouvrir le panneau des zones de récolte' },

    -- Outils : objet de l'inventaire → genre (requis par les ressources), pour l'invite. Puissance, bonus et usure :
    -- `toolStats` de config.lua (mêmes objets, lus par le seul serveur).
    tools = {
        hache_fer = { kind = 'hache' },
        pioche_fer = { kind = 'pioche' },
        faucille_fer = { kind = 'faucille' },
        couteau_fer = { kind = 'couteau' },
        canne_a_peche = { kind = 'canne' },
    },

    -- Ressources : ce qu'un nœud produit, vu du joueur. `tool` : genre d'outil requis en main (nil : à la main). `anim` :
    -- clé de `anims`. `prop` : modèles du nœud, normal et épuisé (l'apparence d'un point est celle de sa ressource).
    -- Objet, compétence, difficulté, XP, rendement, durée, pêche, pièce en plus : `resourceStats` de config.lua.
    resources = {
        chene = { label = 'Chêne', tool = 'hache', anim = 'chop',
            prop = { model = 'prop_tree_oak_01', depleted = 'prop_tree_stump_01' } },        -- PLACEHOLDER
        pin = { label = 'Pin', tool = 'hache', anim = 'chop',
            prop = { model = 'prop_tree_pine_01', depleted = 'prop_tree_stump_01' } },       -- PLACEHOLDER
        fer = { label = 'Filon de fer', tool = 'pioche', anim = 'mine',
            prop = { model = 'prop_rock_1_a', depleted = 'prop_rock_1_f' } },                -- PLACEHOLDER
        cuivre = { label = 'Filon de cuivre', tool = 'pioche', anim = 'mine',
            prop = { model = 'prop_rock_1_b', depleted = 'prop_rock_1_f' } },                -- PLACEHOLDER
        pierre = { label = 'Roche', tool = 'pioche', anim = 'mine',
            prop = { model = 'prop_rock_1_c', depleted = 'prop_rock_1_f' } },                -- PLACEHOLDER
        lavande = { label = 'Lavande', anim = 'pick',
            prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },              -- PLACEHOLDER
        sauge = { label = 'Sauge', tool = 'faucille', anim = 'pick',
            prop = { model = 'prop_plant_01a', depleted = 'prop_plant_01b' } },              -- PLACEHOLDER
        truite = { label = 'Banc de truites', tool = 'canne', anim = 'fish',
            prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },       -- PLACEHOLDER
        brochet = { label = 'Banc de brochets', tool = 'canne', anim = 'fish',
            prop = { model = 'prop_dock_float_1', depleted = 'prop_dock_float_1b' } },       -- PLACEHOLDER
        piste_lievre = { label = 'Piste de lièvre', tool = 'couteau', anim = 'skin',
            prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },          -- PLACEHOLDER
        piste_cerf = { label = 'Piste de cerf', tool = 'couteau', anim = 'skin',
            prop = { model = 'prop_bush_lrg_02', depleted = 'prop_bush_med_03' } },          -- PLACEHOLDER
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
