--[[
    vava_combat/config_client.lua
    Rôle : réglages des armes que lit le client (le serveur les lit aussi) : classe des armes (catégorie, famille de
           l'arme en main), bouclier accroché (position au bras ou dans le dos, cadences du client) et placement de
           chaque bouclier, contrôles natifs coupés ; techniques et styles (format de docs/plan/COMBAT_V1.md § 3),
           dégainer et rengainer, chancellement, mode combat, touches, verrouillage, effets et refus montrés.
           Téléchargé par chaque joueur. `weaponClasses`, `techniques`, `styles` et `keys` y sont entiers : le client
           les lit par une clé variable. Tout le reste (fiches des armes, délais du serveur du bouclier, catégories,
           objets, recettes, qualité, usure, `strike`, cycle d'un coup, tolérances, commandes du Conseil, journal,
           textes du serveur) est dans config.lua, servi au seul serveur (T-132).
    Les modèles, gestes, effets et placements sont des remplaçants vanilla (-- PLACEHOLDER,
    docs/plan/ASSETS_PLACEHOLDERS.md) : le jour où les boucliers et les animations médiévales arrivent, seuls
    `shields[…]`, les `gesture` et `effects` changent ici (`items[…].held.model` et `provisional` dans config.lua). Un
    geste ou un effet absent n'empêche jamais un coup : rien n'est joué, une ligne de console par nom et par minute.
    Les chiffres sont des valeurs de départ, à régler à la porte T-119.
    Dépendances : shared/constants.lua
]]

VavaCombat.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.1.0)

    -- Ce que le client lit d'une arme (clé = nom de l'objet d'inventaire) : catégorie et famille (style, place du
    -- bouclier, armed()). Le reste de la fiche (type de dégâts, dégâts, portée, solidité, blocage, modèle provisoire)
    -- est dans config.lua → weapons, pour les mêmes objets.
    weaponClasses = {
        epee_courte = { category = 'une_main', family = 'epee' },   -- adoptée : objet et recette de vava_crafting
        epee_longue = { category = 'deux_mains', family = 'epee' },
        hache_d_armes = { category = 'une_main', family = 'hache' },
        masse_d_armes = { category = 'une_main', family = 'masse' },
        dague = { category = 'dague', family = 'dague' },
        baton_ferre = { category = 'baton', family = 'baton' },
        bouclier_rond = { category = 'bouclier', family = 'bouclier' },
    },

    -- Bouclier accroché : part du client. Les délais du serveur (toggleMs, verifyMs, missesToDrop, pedCheckMs,
    -- guard*) sont ajoutés par config.lua.
    shield = {
        armWith = { 'une_main', 'dague' },  -- catégories de l'arme en main qui font porter le bouclier au bras
        armWithEmptyHand = false,           -- mains vides : au bras (true) ou dans le dos (false)
        pollMs = 1000,                      -- boucle lente, seulement tant qu'un bouclier est suivi
        showRadius = 120.0,                 -- mètres au-delà desquels un bouclier suivi n'est pas montré
        awaitPedMs = 10000,                 -- attente bornée d'un ped annoncé par son statebag
        modelTimeoutMs = 5000,              -- attente maximale du chargement d'un modèle
    },
    -- Placement des boucliers (clé = objet) : avant-bras gauche (SKEL_L_Forearm, 61163) et haut du dos (SKEL_Spine3,
    -- 24818). Lu par chaque client dans SA config, jamais dans le statebag.
    shields = {
        bouclier_rond = { model = 'prop_ballistic_shield', -- PLACEHOLDER : bouclier balistique de GTA, placements à régler en jeu
            arm = { bone = 61163, offset = { 0.05, 0.05, 0.0 }, rotation = { 0.0, 90.0, 0.0 } },
            back = { bone = 24818, offset = { -0.1, -0.18, 0.0 }, rotation = { 0.0, 90.0, 180.0 } } },
    },

    -- Contrôles natifs coupés côté client, sans boucle par image (bascules réappliquées à 1 Hz).
    natives = {
        disableMelee = true,         -- drapeau de ped « corps à corps désactivé »
        meleeFlag = 122,             -- CPED_CONFIG_FLAG_DisableMelee
        blockSwitch = true,          -- SetPedCanSwitchWeapon(ped, false)
        stripWeapons = true,         -- arme GTA en main (autre que les poings) → toutes retirées
        pollMs = 1000,               -- cadence du contrôle
        restoreOnStop = true,        -- arrêt du module : drapeau et changement d'arme rendus à GTA
    },

    -- Techniques (format de docs/plan/COMBAT_V1.md § 3, identique dans l'Atelier, T-121). Clé = identifiant
    -- (^[a-z0-9_]+$, 32 octets). `phases` en ms (préparation, frappe, récupération) ; `hit.range` en mètres (plus le
    -- bonus de portée de l'arme) ; `hit.angle` : ouverture TOTALE de l'arc, centrée sur l'avant ; `damage` :
    -- multiplicateur des dégâts de l'arme ; `stamina` : lu par T-114 ; `chain` : techniques du même style qui peuvent
    -- partir pendant la récupération ; `learn` : lu par T-115, jamais appliqué ici. Contrôlées au démarrage.
    techniques = {
        taille_descendante = {
            label = 'Taille descendante', style = 'epee_une_main', type = 'legere',
            gesture = { dict = 'melee@large_wpn@streamed_core', clip = 'short_0_attack', flag = 0 }, -- PLACEHOLDER
            phases = { windup = 320, active = 160, recovery = 420 },
            hit = { range = 2.2, angle = 70 },
            damage = 1.0, stamina = 12,
            parryable = true, staggers = false, chain = { 'estoc_rapide', 'fendant' },
            learn = { skill = 'armes_une_main', level = 0 },
        },
        estoc_rapide = {
            label = 'Estoc rapide', style = 'epee_une_main', type = 'legere',
            gesture = { dict = 'melee@knife@streamed_core', clip = 'knife_short_range_0', flag = 0 }, -- PLACEHOLDER
            phases = { windup = 220, active = 120, recovery = 380 },
            hit = { range = 2.4, angle = 40 },
            damage = 0.8, stamina = 9,
            parryable = true, staggers = false, chain = { 'revers', 'fendant' },
            learn = { skill = 'armes_une_main', level = 10 },
        },
        revers = {
            label = 'Revers', style = 'epee_une_main', type = 'legere',
            gesture = { dict = 'melee@large_wpn@streamed_core', clip = 'short_90_attack', flag = 0 }, -- PLACEHOLDER
            phases = { windup = 280, active = 160, recovery = 460 },
            hit = { range = 2.1, angle = 90 },
            damage = 0.9, stamina = 11,
            parryable = true, staggers = false, chain = { 'taille_descendante', 'fendant' },
            learn = { skill = 'armes_une_main', level = 25 },
        },
        fendant = {
            label = 'Fendant', style = 'epee_une_main', type = 'lourde',
            gesture = { dict = 'melee@large_wpn@streamed_core', clip = 'long_0_attack', flag = 0 }, -- PLACEHOLDER
            phases = { windup = 650, active = 200, recovery = 700 },
            hit = { range = 2.3, angle = 60 },
            damage = 1.8, stamina = 25,
            parryable = false, staggers = true, chain = {},
            learn = { skill = 'armes_une_main', level = 15 },
        },
    },

    -- Styles : style = <famille>_<catégorie> de l'arme tenue. `keys` : technique qui ouvre, par touche (legere,
    -- lourde) ; les suivantes viennent de `chain`. T-115 ajoutera les autres styles.
    styles = {
        epee_une_main = { label = 'Épée à une main', keys = { legere = 'taille_descendante', lourde = 'fendant' } },
    },

    -- Dégainer et rengainer : durées tenues par le serveur, gestes joués par le client au changement de main.
    draw = {
        drawMs = 800,          -- arme prise en main : aucune technique avant ce délai (décision du porteur du projet)
        sheatheMs = 1500,      -- arme rangée : armed() dit encore « mains prises » pendant ce délai (pas de sort)
        drawGesture = { dict = 'reaction@intimidation@1h', clip = 'intro', flag = 48 },   -- PLACEHOLDER
        sheatheGesture = { dict = 'reaction@intimidation@1h', clip = 'outro', flag = 48 }, -- PLACEHOLDER
    },

    -- Chancellement d'un coup `staggers` : durée (le serveur la tient, le client la joue).
    stagger = {
        durationMs = 900,
        gesture = { dict = 'reaction@shove', clip = 'shoved_back', flag = 0 }, -- PLACEHOLDER
    },

    -- Mode combat : éveillé par une touche du combat l'arme en main, endormi sans coup ni geste du verrou.
    mode = {
        idleMs = 10000,        -- endormi après ce délai sans coup ni appui sur le verrou
        conditionsMs = 200,    -- relevé des conditions (arme, à pied, debout, aucune interface)
        bufferMs = 250,        -- une touche pressée au plus ce temps avant d'être permise est gardée et jouée à temps
        faceCamera = true,     -- sans cible verrouillée, le personnage se tourne vers la caméra au départ du coup
        faceMaxDeg = 90,       -- au plus ce virage au départ du coup
        noticeMs = 3000,       -- un même refus n'est pas redit avant ce délai
        gestureTimeoutMs = 1000, -- attente maximale du chargement d'un dictionnaire d'animation
        -- contrôles de GTA coupés à chaque image en mode actif : attaque, visée, corps à corps, roue et changement
        -- d'arme (jamais Échap ni P, lus par vava_pause)
        blocked = { 24, 25, 37, 140, 141, 142, 257, 263, 264, 14, 15, 16, 17 },
    },

    -- Touches (réglables dans Paramètres > Raccourcis > FiveM ; QWERTY). Mêmes boutons que la magie : le mode magie est
    -- endormi arme en main (T-140), le mode combat ne s'éveille qu'arme en main.
    keys = {
        legere = { command = 'vava_combat_legere', device = 'MOUSE_BUTTON', key = 'MOUSE_LEFT', label = 'Combat : attaque légère', display = 'Clic gauche' },
        lourde = { command = 'vava_combat_lourde', device = 'MOUSE_BUTTON', key = 'MOUSE_RIGHT', label = 'Combat : attaque lourde', display = 'Clic droit' },
        cible = { command = 'vava_combat_verrou', device = 'MOUSE_BUTTON', key = 'MOUSE_MIDDLE', label = 'Combat : verrouiller un adversaire (maintenir : relâcher)', hold = true, display = 'Clic molette' },
    },

    -- Verrouillage (patron de vava_magic `targeting`) : vu du seul joueur, rien ne passe par le réseau avant un coup.
    lock = {
        range = 6.0,           -- mètres
        coneDeg = 30,          -- écart au centre de l'écran
        holdMs = 600,          -- appui maintenu : relâcher
        checkMs = 250,         -- relevé du verrou (portée, vue)
        lostChecks = 4,        -- relevés hors de vue de suite avant de relâcher
        rangeMargin = 1.0,     -- mètres au-delà de la portée avant de relâcher
        turnDegPerSec = 540,   -- virage vers la cible pendant la préparation et la frappe
        ring = { marker = 25, size = 1.0, r = 200, g = 64, b = 40, alpha = 200, groundOffset = 0.95, spin = 90.0 },
    },

    -- Effets d'un coup chez chacun (local, jamais réseau).
    effects = {
        flinch = { dict = 'melee@unarmed@streamed_variations', clip = 'victim_takedown_front_slap', flag = 48, ms = 400 }, -- PLACEHOLDER
        impact = { asset = 'core', name = 'blood_stab', scale = 0.6, bone = 24818 },          -- PLACEHOLDER
        guarded = { asset = 'core', name = 'bang_sparks', scale = 0.5, bone = 24818 },        -- PLACEHOLDER (blocage, parade)
        sounds = {},           -- { hit = { name, set }, … } ; vide : aucun son (aucun son vanilla retenu)
        maxPerSecond = 12,     -- effets montrés par seconde au plus chez un joueur
        shakeName = 'SMALL_EXPLOSION_SHAKE', -- PLACEHOLDER : secousse de caméra vanilla
        shakeHit = 0.15, shakeStagger = 0.4, -- secousse de caméra chez la cible (0 : aucune)
    },

    -- Refus montrés par le client (code du serveur → texte) ; un code absent : `default` ; `false` : rien.
    refusals = {
        busy = false, chain_limit = false, rate_limited = false,
        drawing = 'Vous n\'avez pas encore l\'arme en garde.',
        staggered = 'Vous chancelez.',
        controlled = 'Vous ne pouvez pas frapper ainsi.',
        no_style = 'Vous ne connaissez aucune technique pour cette arme.',
        downed = 'Vous êtes à terre.',
        vehicle = 'Descendez d\'abord.',
        refused = 'Votre geste est retenu.',
        default = 'Coup impossible pour le moment.',
    },
}
