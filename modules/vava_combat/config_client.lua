--[[
    vava_combat/config_client.lua
    Rôle : réglages lus par le client (le serveur les lit aussi) ; le reste est dans config.lua, jamais téléchargé
           (T-132). Valeurs de départ, à régler à la porte T-119 ; modèles, gestes et effets en -- PLACEHOLDER.
           Détail de chaque réglage : README.md.
    Dépendances : shared/constants.lua
]]

VavaCombat.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer

    -- Classe des armes (clé = objet) : catégorie et famille ; la fiche est dans config.lua → weapons.
    weaponClasses = {
        epee_courte = { category = 'une_main', family = 'epee' },   -- objet de vava_crafting
        epee_longue = { category = 'deux_mains', family = 'epee' },
        hache_d_armes = { category = 'une_main', family = 'hache' },
        masse_d_armes = { category = 'une_main', family = 'masse' },
        dague = { category = 'dague', family = 'dague' },
        baton_ferre = { category = 'baton', family = 'baton' },
        bouclier_rond = { category = 'bouclier', family = 'bouclier' },
    },

    -- Bouclier accroché, part du client (délais du serveur : config.lua).
    shield = {
        armWith = { 'une_main', 'dague' },  -- catégories qui font porter le bouclier au bras
        armWithEmptyHand = false,           -- mains vides : au bras (true) ou dans le dos (false)
        pollMs = 1000,                      -- boucle lente, seulement tant qu'un bouclier est suivi
        showRadius = 120.0,                 -- montré à cette distance au plus (m)
        awaitPedMs = 10000,                 -- attente bornée d'un ped annoncé par son statebag
        modelTimeoutMs = 5000,              -- attente maximale du chargement d'un modèle
    },
    -- Placement des boucliers (clé = objet) : os 61163 avant-bras gauche, 24818 haut du dos.
    shields = {
        bouclier_rond = { model = 'prop_ballistic_shield', -- PLACEHOLDER
            arm = { bone = 61163, offset = { 0.05, 0.05, 0.0 }, rotation = { 0.0, 90.0, 0.0 } },
            back = { bone = 24818, offset = { -0.1, -0.18, 0.0 }, rotation = { 0.0, 90.0, 180.0 } } },
    },

    -- Combat natif de GTA coupé, sans boucle par image.
    natives = {
        disableMelee = true,         -- drapeau de ped « corps à corps désactivé »
        meleeFlag = 122,             -- CPED_CONFIG_FLAG_DisableMelee
        blockSwitch = true,          -- SetPedCanSwitchWeapon(ped, false)
        stripWeapons = true,         -- armes GTA retirées
        pollMs = 1000,               -- cadence du contrôle
        restoreOnStop = true,        -- rendus à GTA à l'arrêt
    },

    -- Techniques (COMBAT_V1.md § 3) : phases en ms, hit.range en m, hit.angle = ouverture totale ; voir README.md.
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
        -- défense (T-113) : blocage = garde tenue (active : tenue minimale), parade (active : fenêtre), esquive
        -- (active : invulnérable) ; hit.angle = arc protégé ; stamina (T-114) = coût d'un coup léger bloqué (lourd × 2,
        -- au bouclier × 0,67 : config.lua → endurance.block ; il faut l'avoir pour lever la garde), d'une parade tentée
        -- (lever la garde commence par une), d'un pas
        garde_epee = {
            label = 'Garde', style = 'epee_une_main', type = 'blocage',
            gesture = { dict = 'anim@melee@machete@streamed_core@', clip = 'plyr_block_idle', flag = 49 }, -- PLACEHOLDER
            phases = { windup = 100, active = 200, recovery = 250 },
            hit = { angle = 120 }, stamina = 25, chain = {},
            learn = { skill = 'armes_une_main', level = 0 },
        },
        parade_epee = {
            label = 'Parade', style = 'epee_une_main', type = 'parade',
            gesture = { dict = 'anim@melee@machete@streamed_core@', clip = 'plyr_block_react', flag = 48 }, -- PLACEHOLDER
            phases = { windup = 0, active = 200, recovery = 250 },
            hit = { angle = 120 }, stamina = 6, chain = { 'garde_epee' },
            learn = { skill = 'armes_une_main', level = 10 },
        },
        pas_de_cote = {
            label = 'Pas de côté', style = 'epee_une_main', type = 'esquive',
            gesture = { dict = 'move_strafe@roll', clip = 'combatroll_bwd_p1_180', flag = 0 }, -- PLACEHOLDER
            phases = { windup = 50, active = 250, recovery = 350 },
            stamina = 20, chain = {},
            learn = { skill = 'armes_une_main', level = 0 },
        },
    },

    -- Styles (<famille>_<catégorie> de l'arme tenue) : technique qui ouvre chaque touche.
    styles = {
        epee_une_main = { label = 'Épée à une main', keys = {
            legere = 'taille_descendante', lourde = 'fendant',
            blocage = 'garde_epee', parade = 'parade_epee', esquive = 'pas_de_cote',
        } },
    },

    -- Défense, part du client (config.lua y ajoute sa part).
    defense = {
        guardBrokenMs = 1200,  -- garde brisée : chancellement, ni garde ni parade
        dodgeCooldownMs = 1500, -- entre le départ de deux pas de côté (0 à 10 000 ; ≤ 17 % du temps invulnérable)
        brokenGesture = { dict = 'reaction@shove', clip = 'shoved_back', flag = 0 },   -- PLACEHOLDER
        guardBlocked = { 21 }, -- contrôles coupés pendant la garde (21 : sprint) ; 8 au plus
        -- pas de côté selon la direction tenue à l'appui (sinon le geste de la technique)
        dodgeGestures = {
            avant = { dict = 'move_strafe@roll', clip = 'combatroll_fwd_p1_00', flag = 0 },    -- PLACEHOLDER
            gauche = { dict = 'move_strafe@roll', clip = 'combatroll_fwd_p1_-90', flag = 0 },  -- PLACEHOLDER
            droite = { dict = 'move_strafe@roll', clip = 'combatroll_fwd_p1_90', flag = 0 },   -- PLACEHOLDER
        },
    },

    -- Dégainer et rengainer (durées tenues par le serveur).
    draw = {
        drawMs = 800,          -- aucune technique avant ce délai après la prise en main
        sheatheMs = 1500,      -- arme rangée : mains prises ce délai (pas de sort)
        drawGesture = { dict = 'reaction@intimidation@1h', clip = 'intro', flag = 48 },   -- PLACEHOLDER
        sheatheGesture = { dict = 'reaction@intimidation@1h', clip = 'outro', flag = 48 }, -- PLACEHOLDER
    },

    -- Chancellement d'un coup `staggers`.
    stagger = {
        durationMs = 900,
        gesture = { dict = 'reaction@shove', clip = 'shoved_back', flag = 0 }, -- PLACEHOLDER
    },

    -- Mode combat (éveillé par une touche du combat, arme en main).
    mode = {
        idleMs = 10000,        -- endormi après ce délai sans coup ni appui sur le verrou
        conditionsMs = 200,    -- relevé des conditions (arme, à pied, debout, aucune interface)
        bufferMs = 250,        -- touche pressée au plus ce temps trop tôt : gardée
        faceCamera = true,     -- sans verrou, tourné vers la caméra au départ du coup
        faceMaxDeg = 90,       -- au plus ce virage au départ du coup
        noticeMs = 3000,       -- un même refus n'est pas redit avant ce délai
        gestureTimeoutMs = 1000, -- attente maximale du chargement d'un dictionnaire d'animation
        -- contrôles coupés en mode actif (jamais 199, 200, 322 : Échap et P de vava_pause ; 32 au plus)
        blocked = { 24, 25, 37, 140, 141, 142, 257, 263, 264, 14, 15, 16, 17, 22, 45 },
    },

    -- Touches (réglables dans Paramètres > Raccourcis > FiveM).
    keys = {
        legere = { command = 'vava_combat_legere', device = 'MOUSE_BUTTON', key = 'MOUSE_LEFT', label = 'Combat : attaque légère', display = 'Clic gauche' },
        lourde = { command = 'vava_combat_lourde', device = 'MOUSE_BUTTON', key = 'MOUSE_RIGHT', label = 'Combat : attaque lourde', display = 'Clic droit' },
        cible = { command = 'vava_combat_verrou', device = 'MOUSE_BUTTON', key = 'MOUSE_MIDDLE', label = 'Combat : verrouiller un adversaire (maintenir : relâcher)', hold = true, display = 'Clic molette' },
        garde = { command = 'vava_combat_garde', device = 'keyboard', key = 'R', hold = true, display = 'R',
            label = 'Combat : parer (appui bref) ou se garder (maintenir)' },
        esquive = { command = 'vava_combat_esquive', device = 'keyboard', key = 'SPACE', display = 'Espace',
            label = 'Combat : pas de côté (mode combat actif)' },
    },

    -- Verrou d'un adversaire (local, rien sur le réseau avant un coup).
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

    -- Effets d'un coup chez chacun (locaux).
    effects = {
        flinch = { dict = 'melee@unarmed@streamed_variations', clip = 'victim_takedown_front_slap', flag = 48, ms = 400 }, -- PLACEHOLDER
        impact = { asset = 'core', name = 'blood_stab', scale = 0.6, bone = 24818 },          -- PLACEHOLDER
        guarded = { asset = 'core', name = 'bang_sparks', scale = 0.5, bone = 24818 },        -- PLACEHOLDER (blocage, parade)
        sounds = {},           -- { hit = { name, set } } ; vide : aucun son
        maxPerSecond = 12,     -- effets montrés par seconde au plus
        shakeName = 'SMALL_EXPLOSION_SHAKE', -- PLACEHOLDER : secousse de caméra vanilla
        shakeHit = 0.15, shakeStagger = 0.4, -- secousse de caméra chez la cible (0 : aucune)
    },

    -- Mannequins d'entraînement (T-156). v1 : posés ici ; plus tard, définitions de l'Atelier (cette liste en sera la
    -- version 1, la base fera foi). Le client lit modèles et places (props LOCAUX créés à portée) ; le serveur lit les
    -- mêmes places pour juger les coups (part du serveur : config.lua). Aucun mannequin ne tombe, ne pare ni ne garde
    -- quoi que ce soit. Contrôlé au démarrage par le serveur ; détail : README.md.
    dummies = {
        model = 'prop_beach_punchbag',      -- PLACEHOLDER : sac de frappe de GTA, en attendant le mannequin de paille
        fallbackModel = 'prop_haybale_03',  -- PLACEHOLDER : botte de foin, si le premier modèle est inconnu
        modelTimeoutMs = 5000,              -- attente maximale du chargement d'un modèle (500 à 30 000)
        streamRadius = 60.0,                -- prop créé à cette distance du joueur…
        keepRadius = 70.0,                  -- … retiré au-delà (pas de clignotement en bordure, T-137)
        nearPollMs = 500,                   -- passage de la boucle quand un mannequin est à moins de keepRadius + 20 m…
        farPollMs = 2000,                   -- … sinon
        centerHeight = 1.0,                 -- point visé au-dessus du pied (comme le centre d'un ped)
        anchorHeight = 1.9,                 -- chiffre posé à cette hauteur au-dessus du pied
        wobble = { ms = 900, angle = 14.0, cycles = 2 },  -- balancement : s'écarte de l'attaquant, se redresse seul
        fx = { asset = 'core', name = 'ent_dst_wood_splinter', scale = 0.6 },  -- PLACEHOLDER : éclats (paille plus tard) ; false : aucun
        list = {
            -- PLACEHOLDER : cour d'armes provisoire derrière le poste de Paleto Bay ; à replacer sur la carte médiévale
            { id = 'paleto_1', x = -437.5, y = 6011.0, z = 31.49, heading = 45.0 },
            { id = 'paleto_2', x = -440.0, y = 6013.5, z = 31.49, heading = 45.0 },
            { id = 'paleto_3', x = -442.5, y = 6016.0, z = 31.49, heading = 45.0 },
        },
    },

    -- Jauge d'endurance dans vava_hud (T-114) : montrée en mode combat éveillé, ou tant qu'elle n'est pas pleine.
    gauge = {
        label = 'Endurance',
        icon = 'nui://vava_combat/web/icons/endurance.svg',
        order = 60,          -- après santé (5), faim (10), soif (20), voix (40) : apparaître ne décale aucun médaillon
        low = 0.25,          -- anneau ambre : moins qu'un coup bloqué (plus de quoi lever la garde)
        critical = 0.10,     -- anneau rouge, lueur : moins qu'une attaque légère
        lingerMs = 3000,     -- reste affichée ce délai après être redevenue pleine, mode combat endormi (0 à 30 000)
        margin = 2,          -- points : une demande part si la jauge vue du client en manque au plus autant (0 à 10)
    },

    -- Refus montrés (code du serveur → texte ; absent : `default` ; `false` : rien).

    refusals = {
        busy = false, chain_limit = false, rate_limited = false,
        guarding = false, parry_cooldown = false, dodge_cooldown = false, no_guard = false,
        guard_broken = 'Votre garde est brisée.',
        drawing = 'Vous n\'avez pas encore l\'arme en garde.',
        staggered = 'Vous chancelez.',
        controlled = 'Vous ne pouvez pas frapper ainsi.',
        no_style = 'Vous ne connaissez aucune technique pour cette arme.',
        downed = 'Vous êtes à terre.',
        vehicle = 'Descendez d\'abord.',
        exhausted = 'Vous êtes à bout de souffle.',
        refused = 'Votre geste est retenu.',
        default = 'Coup impossible pour le moment.',
    },
}
