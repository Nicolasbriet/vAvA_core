--[[
    vava_magic/config.lua
    Rôle : configuration de la magie (lue par le client et le serveur) : mana, progression, incantation, sorts et
           leurs niveaux, sigils, registre, objets, combat, effets visibles, touches, commandes, limites de débit, et
           TOUS les textes vus par les joueurs (l'interface reçoit les siens d'ici).
    Ajouter un sort : créer server/spells/<nom>.lua et client/spells/<nom>.lua, les lister dans le fxmanifest, et
           déclarer ici spells.<nom> (mêmes champs communs que les sorts ci-dessous).
    Animations et particules : noms tirés de GTA V, À VÉRIFIER EN JEU (voir README).
    Dépendances : shared/constants.lua
]]

VavaMagic.config = {
    coreVersion = '0.5.0',

    -- Mana : gérée par le serveur, jamais sauvegardée (pleine à la connexion). Régénération : `regenPoints` points
    -- toutes les `regenMs` ms ; le client anime la remontée lui-même (aucun envoi périodique).
    mana = {
        max = 100,
        regenPoints = 3,
        regenMs = 5000,
        -- médaillon de vava_hud : montré quand la mana n'est pas pleine ou juste après un sort, puis retiré
        hud = { label = 'Mana', icon = 'nui://vava_magic/web/img/mana.svg', order = 50, low = 0.3, critical = 0.12, lingerMs = 4000 },
    },

    -- Progression : 5 niveaux par sort ; seuils d'XP pour atteindre chaque niveau (le premier vaut 0).
    progression = {
        thresholds = { 0, 100, 300, 700, 1500 },
        costMultipliers = { 1.0, 0.9, 0.8, 0.7, 0.6 }, -- coût en mana selon le niveau du sort
        failureShare = 0.5,                           -- un échec rapporte cette part de l'XP
        antiFarmMs = 20000,                           -- un même sort ne rapporte de l'XP qu'une fois par intervalle
    },

    -- Incantation commune à tous les sorts.
    casting = {
        maxMove = 1.0,             -- mètres parcourus au plus (sorts sans `moveSpeed`)
        moveMargin = 0.5,          -- marge du serveur sur la distance (positions réseau)
        finishToleranceMs = 300,   -- fin acceptée un peu avant la durée (latence)
        graceMs = 4000,            -- au-delà de la durée, une incantation sans fin est abandonnée
        checkMs = 100,             -- contrôles du client (chute, blessure, déplacement) hors déplacement lent
        animLoadMs = 2000,         -- attente du chargement d'une animation
    },

    -- Fiche : écrite dans le personnage (le core la sauvegarde par lots) au plus toutes les `flushMs`, et au départ.
    persistence = { flushMs = 15000 },

    -- Sorts. Champs communs : order (grimoire), label, summary, baseCost, xp (XP d'un succès), moveSpeed (m/s permis
    -- pendant l'incantation ; absent = règle du mètre), anim (incantation), ambientText (texte vu à 15 m, facultatif),
    -- runes (runes au-dessus des mains), key (touche, voir `keys`), levels (5 niveaux : castMs, cooldownMs,
    -- description du niveau, unlock = ce que le niveau apporte, puis les valeurs propres au sort).
    spells = {
        murmure = {
            order = 1,
            label = 'Murmure',
            summary = 'Confier quelques mots au vent, jusqu\'à ceux dont on garde le sigil.',
            baseCost = 12,
            xp = 20,
            anim = { dict = 'anim@mp_player_intupperair_synth', clip = 'idle_a', flag = 49 },
            ambientText = 'trace des runes dans l\'air',
            runes = true,
            key = 'murmure',
            refundShare = 0.5,    -- mana rendue pour un destinataire injoignable (part du coût, au prorata du cercle)
            readMs = 15000,       -- affichage du message reçu
            textMaxBytes = 1400,  -- borne réseau du message (octets) ; la longueur réelle est comptée en signes
            -- range : mètres entre lanceur et destinataire (0 = sans limite) · fragmentShare/fragmentMax : part et
            -- nombre maximal de mots montrés au-dessus des mains · distortion : chance qu'un mot arrive en « … » ·
            -- sigils : sigils mémorisables · circle : destinataires d'un envoi · waypoint : position jointe
            levels = {
                {
                    castMs = 6000, cooldownMs = 20000, maxLength = 60, range = 300.0, fragmentShare = 0.5, fragmentMax = 99,
                    distortion = 0.30, sigils = 10, circle = 1, waypoint = false,
                    description = 'Soixante signes vers un seul contact, à moins de trois cents mètres. Le lien est fragile : près d\'un mot sur trois se perd, et la moitié de vos mots luisent au-dessus de vos mains.',
                    unlock = 'Vous savez confier quelques mots au vent.',
                },
                {
                    castMs = 5500, cooldownMs = 18000, maxLength = 100, range = 1000.0, fragmentShare = 0.33, fragmentMax = 99,
                    distortion = 0.15, sigils = 15, circle = 1, waypoint = false,
                    description = 'Cent signes, jusqu\'à un kilomètre. Un mot sur sept se perd ; un tiers de vos mots se trahit dans l\'air.',
                    unlock = 'Vos murmures portent jusqu\'à un kilomètre et se perdent moins.',
                },
                {
                    castMs = 5000, cooldownMs = 16000, maxLength = 160, range = 0, fragmentShare = 0.15, fragmentMax = 4,
                    distortion = 0.07, sigils = 25, circle = 1, waypoint = true,
                    description = 'Cent soixante signes, sans limite de distance. Quelques mots seulement se trahissent, et vous pouvez joindre votre position.',
                    unlock = 'Vos murmures traversent le royaume, et vous pouvez y joindre votre position.',
                },
                {
                    castMs = 4500, cooldownMs = 14000, maxLength = 220, range = 0, fragmentShare = 0.08, fragmentMax = 2,
                    distortion = 0.03, sigils = 40, circle = 4, waypoint = true,
                    description = 'Deux cent vingt signes, à un cercle de quatre contacts à la fois. Un ou deux mots à peine se laissent lire.',
                    unlock = 'Vous pouvez murmurer à un cercle de quatre contacts en un seul envoi.',
                },
                {
                    castMs = 4000, cooldownMs = 12000, maxLength = 300, range = 0, fragmentShare = 0, fragmentMax = 0,
                    distortion = 0, sigils = 60, circle = 8, waypoint = true,
                    description = 'Trois cents signes, à un cercle de huit contacts. Rien ne se perd, rien ne se lit au-dessus de vos mains.',
                    unlock = 'Vos murmures sont parfaits : rien ne se perd, rien ne se trahit, et votre cercle compte huit contacts.',
                },
            },
        },

        lueur = {
            order = 2,
            label = 'Lueur',
            summary = 'Faire naître la lumière, au creux de la main puis en orbe.',
            baseCost = 8,
            xp = 10,
            anim = { dict = 'amb@world_human_stand_fire@male@base', clip = 'base', flag = 49 },
            ambientText = 'fait naître une lueur au creux de sa main',
            key = 'lueur',
            -- mode : 'hand' (dans la main) ou 'orb' (près de l'épaule) · durationMs · range (mètres éclairés) ·
            -- intensity · flicker (amplitude du scintillement) · anchor (orbe ancré permis, anchorMs : sa durée) ·
            -- colors (choix de la couleur)
            levels = {
                {
                    castMs = 2500, cooldownMs = 4000, durationMs = 60000, mode = 'hand', range = 4.0, intensity = 1.5, flicker = 0.35,
                    anchor = false, colors = false,
                    description = 'Une flamme pâle au creux de la main, qui vacille et s\'éteint au bout d\'une minute.',
                    unlock = 'Vous savez faire naître une lueur au creux de votre main.',
                },
                {
                    castMs = 2200, cooldownMs = 4000, durationMs = 180000, mode = 'hand', range = 6.0, intensity = 2.5, flicker = 0.15,
                    anchor = false, colors = false,
                    description = 'Une lumière plus franche et plus stable, trois minutes durant.',
                    unlock = 'Votre lueur se stabilise, éclaire plus loin et dure trois minutes.',
                },
                {
                    castMs = 2000, cooldownMs = 4000, durationMs = 300000, mode = 'orb', range = 8.0, intensity = 3.0, flicker = 0.08,
                    anchor = false, colors = false,
                    description = 'Un orbe flotte près de votre épaule et vous laisse les mains libres, cinq minutes.',
                    unlock = 'Votre lueur devient un orbe qui flotte près de votre épaule : vos mains sont libres.',
                },
                {
                    castMs = 1800, cooldownMs = 4000, durationMs = 420000, mode = 'orb', range = 9.0, intensity = 3.5, flicker = 0.06,
                    anchor = true, anchorMs = 300000, colors = false,
                    description = 'Un orbe de sept minutes, que vous pouvez aussi ancrer en un lieu pour cinq minutes.',
                    unlock = 'Vous pouvez ancrer un orbe en un lieu, où il brille sans vous.',
                },
                {
                    castMs = 1500, cooldownMs = 4000, durationMs = 600000, mode = 'orb', range = 10.0, intensity = 4.0, flicker = 0.05,
                    anchor = true, anchorMs = 600000, colors = true,
                    description = 'Dix minutes de lumière, dans la couleur de votre choix ; vos orbes ancrés durent autant.',
                    unlock = 'Vous choisissez la couleur de votre lumière.',
                },
            },
            -- orbe ancré : objet invisible créé par le serveur, vu des seuls joueurs proches
            anchor = { reach = 8.0, costShare = 1.5, perCaster = 1, max = 40, model = 'prop_golf_ball' },
            -- couleurs (niveau 5) ; `defaultColor` sert avant le niveau 5 et tant qu'aucune n'est choisie
            colors = {
                { name = 'ambre', label = 'Ambre', r = 255, g = 196, b = 128 },
                { name = 'lune', label = 'Clair de lune', r = 190, g = 210, b = 255 },
                { name = 'aube', label = 'Aube rosée', r = 255, g = 170, b = 150 },
                { name = 'sylve', label = 'Sylve', r = 160, g = 240, b = 170 },
                { name = 'flamme', label = 'Flamme', r = 255, g = 140, b = 60 },
                { name = 'arcane', label = 'Arcane', r = 190, g = 150, b = 255 },
            },
            defaultColor = 'ambre',
            render = {
                distance = 60.0,                              -- lumières dessinées jusqu'à cette distance
                handBone = 57005,                             -- SKEL_R_Hand
                handOffset = { x = 0.12, y = 0.02, z = 0.0 },
                orbOffset = { x = 0.35, y = -0.15, z = 0.65 }, -- près de l'épaule droite
                bob = 0.04, bobSpeed = 1.2,                   -- flottement de l'orbe
                flickerSpeed = 1.0,                           -- vitesse du scintillement (fluide, jamais aléatoire)
                marker = 28, markerScale = 0.07, markerAlpha = 190,
            },
        },

        boule_de_feu = {
            order = 3,
            label = 'Boule de feu',
            summary = 'Rassembler les flammes et les jeter sur un adversaire.',
            baseCost = 25,
            xp = 25,
            moveSpeed = 1.2,      -- le lanceur peut marcher lentement pendant l'incantation
            lockOn = true,        -- sort d'attaque : se lance sur la cible verrouillée (voir `targeting`)
            anim = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'idle_a', flag = 49 },
            throwAnim = { dict = 'weapons@projectile@grenade_str', clip = 'throw_m_fb_stand', flag = 48, ms = 900 },
            ambientText = 'rassemble des flammes entre ses mains',
            key = 'feu',
            -- speed (m/s) · range (m) · damage (part de la vie) · fizzle (chance qu'elle s'éteigne) · size (taille du
            -- feu) · aoeRadius/aoeShare (zone d'effet, dégâts réduits aux cibles secondaires) · burn (brûlure) ·
            -- homing (degrés par seconde dont elle s'incurve vers la cible verrouillée ; 0 : elle part droit vers elle)
            levels = {
                {
                    castMs = 1600, cooldownMs = 30000, speed = 12.0, range = 20.0, damage = 0.10, fizzle = 0.20, size = 0.6,
                    aoeRadius = 0, aoeShare = 0, burn = false, homing = 0,
                    description = 'Une petite boule de feu, lente et peu sûre : elle s\'éteint une fois sur cinq. Portée : vingt mètres.',
                    unlock = 'Vous savez lancer une petite boule de feu.',
                },
                {
                    castMs = 1500, cooldownMs = 28000, speed = 15.0, range = 28.0, damage = 0.15, fizzle = 0.10, size = 0.7,
                    aoeRadius = 0, aoeShare = 0, burn = false, homing = 0,
                    description = 'Plus brûlante et plus lointaine (vingt-huit mètres) ; elle ne s\'éteint plus qu\'une fois sur dix.',
                    unlock = 'Votre boule de feu frappe plus fort et plus loin.',
                },
                {
                    castMs = 1400, cooldownMs = 26000, speed = 18.0, range = 34.0, damage = 0.18, fizzle = 0.06, size = 0.8,
                    aoeRadius = 2.5, aoeShare = 0.5, burn = false, homing = 0,
                    description = 'Elle éclate à l\'impact et lèche ceux qui se tiennent à deux pas et demi de la cible.',
                    unlock = 'Votre boule de feu éclate à l\'impact et touche ceux qui entourent la cible.',
                },
                {
                    castMs = 1300, cooldownMs = 24000, speed = 20.0, range = 40.0, damage = 0.20, fizzle = 0.04, size = 0.9,
                    aoeRadius = 2.5, aoeShare = 0.5, burn = { durationMs = 4000, tickMs = 1000, damage = 0.02 }, homing = 35,
                    description = 'La cible touchée brûle encore quelques instants, et la boule s\'incurve un peu vers la cible verrouillée.',
                    unlock = 'La cible touchée brûle encore quelques instants ; votre boule s\'incurve vers la cible verrouillée.',
                },
                {
                    castMs = 1000, cooldownMs = 20000, speed = 30.0, range = 50.0, damage = 0.25, fizzle = 0.01, size = 1.1,
                    aoeRadius = 3.5, aoeShare = 0.6, burn = { durationMs = 5000, tickMs = 1000, damage = 0.025 }, homing = 70,
                    description = 'Un trait de feu rapide et sûr, à cinquante mètres, qui éclate largement, embrase sa cible et la suit de près.',
                    unlock = 'Votre boule de feu file, frappe et embrase au plus fort, et suit de près la cible verrouillée.',
                },
            },
            burnEnabled = true,   -- brûlure du niveau 4 (false : jamais de dégâts sur la durée)
            -- contrôles du serveur à l'impact (positions lues côté serveur)
            hit = {
                angleDeg = 25,           -- écart permis entre la direction du lancer et la cible
                targetMargin = 2.5,      -- mètres entre le point d'impact annoncé et la cible
                rangeMargin = 2.0,       -- mètres au-delà de la portée
                timeMarginMs = 450,      -- avance permise sur le temps de vol (latence)
                broadcastRadius = 150.0, -- joueurs qui voient le lancer
                launchGraceMs = 3000,    -- délai d'un impact après la fin du vol
                originHeight = 0.6,      -- hauteur des mains au-dessus de la position du ped
                targetHeight = 0.3,      -- cible verrouillée : visée au torse, au-dessus de la position du ped
            },
            fx = {
                asset = 'core',
                trail = 'ent_amb_torch_fire', impact = 'ent_sht_flame', fizzle = 'ent_sht_steam', burn = 'ent_amb_torch_fire',
                impactScale = 1.2, fizzleScale = 0.8, burnScale = 0.6, burnBone = 24818, -- SKEL_Spine3
            },
            light = { r = 255, g = 140, b = 40, range = 6.0, intensity = 6.0 },
            projectile = { model = 'prop_golf_ball', handBone = 57005, radius = 0.25, renderDistance = 200.0 },
        },
    },

    -- Verrouillage d'une cible, pour les sorts d'attaque (`lockOn = true`) : la touche prend le joueur le plus proche du
    -- centre de l'écran, à portée du sort et en vue ; un nouvel appui passe au suivant ; la touche maintenue relâche.
    -- Rien ne passe par le réseau tant qu'on ne lance pas ; la cible est revérifiée par le serveur au lancer.
    targeting = {
        coneDeg = 25,          -- écart permis entre le centre de l'écran et la cible
        holdMs = 600,          -- touche maintenue au moins ce temps : verrou relâché
        idleMs = 20000,        -- verrou relâché après ce délai sans attaque
        checkMs = 250,         -- revérification de la portée et de la vue
        lostChecks = 4,        -- vérifications de suite sans la voir avant de la perdre (1 s)
        rangeMargin = 2.0,     -- marge sur la portée, côté client comme serveur
        warnMs = 2200,         -- durée du frisson chez la cible (bord de l'écran qui rougit)
        -- anneau sous la cible, vu du seul lanceur
        ring = { marker = 25, size = 1.2, r = 200, g = 64, b = 40, alpha = 210, groundOffset = 0.95, spin = 90.0 },
    },

    -- Combat entre joueurs.
    combat = {
        pvp = true, -- false : la boule de feu se voit et se lance, mais ne blesse personne
        -- zones où l'on ne lance pas de boule de feu (cercle au sol, en mètres) et où personne n'en est blessé :
        -- { label = 'Chapelle de la Grâce', x = 0.0, y = 0.0, radius = 40.0 },
        protectedZones = {},
        -- journal des dégâts infligés par les sorts (pour le Conseil) : écrit par lots en base
        log = { flushMs = 10000, batch = 50 },
    },

    -- Sigils : chaque personnage en a un, mage ou non.
    sigils = {
        spell = 'murmure',     -- sort qui gouverne les sigils : leur nombre selon son niveau, le brouillage
        length = 12,
        alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ',
        nonMageLimit = 10,     -- sigils mémorisables sans ce sort (ou sans être mage)
        nameMax = 24,          -- signes du nom donné à un contact
        offerRange = 3.0,      -- échange face à face (mètres)
        rangeMargin = 0.5,
        offerMs = 30000,       -- délai pour accepter ou refuser
        retries = 5,           -- tirages d'un sigil libre
        scramble = { cost = 60, cooldownMs = 21600000 }, -- brouiller (mage connaissant le sort) : 6 h de recharge
    },

    -- Registre des murmures (objet) : l'historique suit l'objet ; il est en base sous le numéro du registre.
    registers = { maxPages = 200, contactMax = 160 },

    -- Objets déclarés dans vava_inventory.
    items = {
        grimoire = {
            name = 'grimoire', label = 'Grimoire', category = 'divers',
            description = 'Un livre de cuir sombre aux fermoirs de laiton ; ses pages ne parlent qu\'aux mages.',
            width = 2, height = 2, weight = 900, stack = 1, image = 'nui://vava_magic/web/items/grimoire.svg',
        },
        registre = {
            name = 'registre', label = 'Registre des murmures', category = 'divers',
            description = 'Un carnet relié où se couchent d\'eux-mêmes les murmures échangés.',
            width = 1, height = 2, weight = 450, stack = 1, image = 'nui://vava_magic/web/items/registre.svg',
        },
    },

    -- Effets vus par les autres joueurs.
    ambient = {
        distance = 15.0,          -- textes d'ambiance et runes
        fragmentDistance = 3.0,   -- fragments lisibles du Murmure
        glowMs = 5000,            -- yeux qui s'illuminent
        glowText = 'ses yeux s\'illuminent un bref instant',
        textFormat = '* %s *',    -- mise en forme des textes d'ambiance (comme une action décrite)
        scanMs = 250,             -- recherche des effets proches (le dessin par image ne tourne que s'il y en a)
        headOffset = 0.38,        -- texte au-dessus de la tête
        handsOffset = 0.22,       -- runes et fragments au-dessus des mains
        text = { font = 4, scale = 0.36, r = 232, g = 218, b = 186, alpha = 230 },
        fragments = { font = 4, scale = 0.42, r = 255, g = 214, b = 120, alpha = 245, lineWords = 4, lineHeight = 0.09 },
        runes = { txd = 'vava_magic', texture = 'runes', file = 'web/img/runes.png', size = 0.11, alpha = 210, r = 255, g = 214, b = 140, spin = 40.0 },
        glowLight = { r = 150, g = 190, b = 255, range = 1.6, intensity = 5.0 },
    },

    -- Commandes du Conseil : droit vava_admin (sans vava_admin : permission ACE `ace`).
    admin = { permission = 'tools', ace = 'magie.admin' },

    -- Touches (réglables par le joueur dans Paramètres > Raccourcis > FiveM). FiveM nomme les touches par leur place
    -- sur un clavier QWERTY : celles-ci sont au même endroit en AZERTY. Changer une commande remet la touche par défaut.
    keys = {
        murmure = { command = 'vava_magic_murmure', key = 'N', label = 'Magie : écrire un murmure' },
        lueur = { command = 'vava_magic_lueur', key = 'L', label = 'Magie : Lueur (allumer, éteindre)' },
        ancre = { command = 'vava_magic_ancre', key = 'J', label = 'Magie : ancrer un orbe de Lueur' },
        feu = { command = 'vava_magic_feu', key = 'K', label = 'Magie : Boule de feu' },
        -- touche maintenue (commande +/-) : appui court = verrouiller ou cible suivante, long = relâcher
        cible = { command = 'vava_magic_cible', key = 'TAB', label = 'Magie : verrouiller une cible (sorts d\'attaque)', hold = true },
        annuler = { command = 'vava_magic_annuler', key = 'X', label = 'Magie : interrompre l\'incantation' },
    },

    -- Commandes du chat (et leurs sous-commandes).
    commands = {
        grimoire = 'grimoire',
        murmure = 'murmure',
        lueur = 'lueur',
        feu = 'bouledefeu',
        sigils = 'sigils',
        sigil = 'sigil',
        admin = 'magie',
        sigilActions = { offer = 'offrir', rename = 'renommer', forget = 'oublier', scramble = 'brouiller' },
        lightActions = { anchor = 'ancrer', color = 'couleur', off = 'eteindre', dispel = 'dissiper' },
        adminActions = {
            mage = 'mage', learn = 'apprendre', forget = 'oublier', level = 'niveau', xp = 'xp',
            mana = 'mana', sheet = 'fiche', give = 'donner',
        },
        yes = 'oui',
        no = 'non',
    },

    rateLimits = {
        sheet = { capacity = 3, refillPerSecond = 0.2 },
        cast = { capacity = 6, refillPerSecond = 1 },
        cancel = { capacity = 10, refillPerSecond = 2 },
        sigils = { capacity = 6, refillPerSecond = 1 },
        offer = { capacity = 3, refillPerSecond = 0.2 },
        answer = { capacity = 6, refillPerSecond = 1 },
        edit = { capacity = 6, refillPerSecond = 1 },
        scramble = { capacity = 2, refillPerSecond = 0.05 },
        light = { capacity = 6, refillPerSecond = 1 },
        impact = { capacity = 6, refillPerSecond = 2 },
        register = { capacity = 6, refillPerSecond = 1 },
    },

    -- Textes vus par les joueurs (français, univers médiéval).
    texts = {
        -- refus et erreurs, par code renvoyé par le serveur
        errors = {
            not_ready = 'La magie ne répond pas encore : réessayez dans un instant.',
            not_mage = 'La magie ne vous a jamais répondu.',
            unknown_spell = 'Vous ignorez ce sort.',
            level_too_low = 'Votre maîtrise de ce sort ne va pas encore jusque-là.',
            no_mana = 'Votre mana est trop faible.',
            cooldown = 'Le sort n\'est pas encore prêt (%d s).',
            busy = 'Vous incantez déjà.',
            downed = 'Vous êtes à terre.',
            in_vehicle = 'Impossible d\'incanter ainsi installé.',
            protected_zone = 'Une paix sacrée règne en ce lieu : le feu ne vous obéit pas.',
            refused = 'Quelque chose empêche votre incantation.',
            no_cast = 'Aucune incantation en cours.',
            too_soon = 'L\'incantation n\'était pas achevée.',
            expired = 'L\'incantation s\'est dissipée.',
            moved = 'Vous avez bougé : l\'incantation se brise.',
            hurt = 'La douleur brise votre concentration.',
            ragdoll = 'Votre chute brise l\'incantation.',
            cancelled = 'Vous laissez l\'incantation s\'éteindre.',
            no_position = 'Votre position est introuvable.',
            invalid = 'Votre demande est mal formée.',
            rate_limited = 'Doucement : laissez la magie respirer.',
            no_target = 'Choisissez au moins un contact.',
            too_many_targets = 'Votre cercle ne compte pas autant de contacts à ce niveau.',
            unknown_sigil = 'Ce sigil n\'est pas dans votre mémoire.',
            empty_message = 'Votre message est vide.',
            no_waypoint = 'Joindre sa position demande le niveau 3.',
            too_far = 'C\'est trop loin.',
            anchor_limit = 'Trop d\'orbes brillent déjà dans le royaume.',
            no_light = 'Aucune lueur à éteindre.',
            unknown_color = 'Cette couleur vous est inconnue.',
            no_launch = 'Cette boule de feu n\'existe plus.',
            no_lock_target = 'Aucune cible en vue.',
            invalid_target = 'Votre cible vous échappe.',
            invalid_impact = 'Impact refusé.',
            nobody_near = 'Personne ne se tient assez près de vous.',
            offer_pending = 'Un sigil attend déjà une réponse.',
            no_offer = 'Cette offre n\'existe plus.',
            sigils_full = 'Votre mémoire ne peut garder davantage de sigils.',
            their_sigils_full = 'Sa mémoire ne peut garder davantage de sigils.',
            name_invalid = 'Ce nom ne convient pas (24 signes au plus).',
            unknown_index = 'Aucun sigil sous ce numéro.',
            no_register = 'Vous n\'avez pas ce registre sur vous.',
            unknown_page = 'Cette page n\'existe plus.',
            db_error = 'Les archives ne répondent pas : réessayez plus tard.',
            unknown = 'La magie se dérobe (%s).',
        },
        -- messages au joueur
        notify = {
            levelUp = '%s, niveau %d : %s',
            learned = 'Un savoir nouveau s\'éveille en vous : %s.',
            forgotten = 'Le sort %s s\'efface de votre mémoire.',
            becameMage = 'La magie s\'éveille en vous.',
            lostMagic = 'La magie s\'est retirée de vous.',
            manaRefilled = 'Votre mana est pleine.',
            murmurDelivered = 'Votre murmure a trouvé son chemin.',
            murmurPartial = 'Votre murmure a trouvé %d destinataire(s) sur %d.',
            murmurSilent = 'Le lien reste silencieux.',
            murmurTooFar = 'Le lien ne porte pas si loin.',
            refund = '%d de mana vous reviennent.',
            murmurWaypoint = 'Un point de passage est marqué sur votre carte.',
            registerFull = 'Votre registre est plein : ce murmure n\'y est pas consigné.',
            pageTorn = 'Vous arrachez la page.',
            sigilOffered = 'Vous tendez votre sigil.',
            sigilAccepted = 'Votre sigil a été accepté.',
            sigilRefused = 'Votre sigil a été refusé.',
            sigilExpired = 'L\'offre de sigil est restée sans réponse.',
            sigilKept = 'Vous gardez ce sigil sous le nom « %s ».',
            sigilRenamed = 'Sigil renommé : « %s ».',
            sigilForgotten = 'Vous oubliez le sigil « %s ».',
            sigilScrambled = 'Votre sigil se brouille : l\'ancien n\'existe plus.',
            lightOff = 'Votre lueur s\'éteint.',
            anchored = 'L\'orbe se fige en ce lieu.',
            dispelled = 'Vos orbes se dissipent.',
            colorSet = 'Votre lumière prend la couleur « %s ».',
            fizzle = 'La boule de feu s\'éteint entre vos mains.',
            burning = 'Les flammes vous mordent !',
        },
        chat = {
            prefix = 'Arcanes',
            sigilsTitle = 'Vos sigils (%d / %d) :',
            sigilLine = '%d. %s',
            sigilsNone = 'Vous ne gardez aucun sigil.',
            sigilsHint = '/sigil offrir · /sigil renommer <n°> <nom> · /sigil oublier <n°> · /sigil brouiller',
            sigilUsage = 'Usage : /sigil offrir | renommer <n°> <nom> | oublier <n°> | brouiller',
            lightUsage = 'Usage : /lueur [ancrer | couleur <nom> | eteindre | dissiper]',
            colorsList = 'Couleurs : %s',
            murmurUsage = 'Usage : /murmure, ou /murmure <n°[,n°…]> <message>',
            adminUsage = 'Usage : /magie mage <id> <oui|non> · apprendre <id> <sort> · oublier <id> <sort> · niveau <id> <sort> <1-5> · xp <id> <sort> <xp> · mana <id> · fiche <id> · donner <id> <grimoire|registre>',
            adminForbidden = 'Ces commandes sont réservées au Conseil.',
            adminNoTarget = 'Aucun personnage en jeu sous ce numéro.',
            adminUnknownSpell = 'Sort inconnu. Sorts : %s',
            adminDone = 'C\'est fait.',
            adminFailed = 'Échec : %s',
            sheetTitle = 'Fiche magie de %s (joueur n° %d)',
            sheetMage = 'Mage : %s',
            sheetSpell = '— %s : niveau %d (%d XP)',
            sheetNoSpell = '— aucun sort',
            sheetSigils = 'Sigils gardés : %d · mana : %d / %d',
            yes = 'oui',
            no = 'non',
        },
        -- suggestions du chat
        suggestions = {
            grimoire = 'Ouvrir votre grimoire',
            murmure = { help = 'Écrire un murmure', params = { { name = 'n°', help = 'facultatif : numéros des contacts, séparés par des virgules' }, { name = 'message', help = 'facultatif : le message' } } },
            lueur = { help = 'Lueur : allumer ou éteindre', params = { { name = 'action', help = 'ancrer, couleur <nom>, eteindre ou dissiper' } } },
            feu = 'Lancer une boule de feu',
            sigils = 'Lister les sigils que vous gardez',
            sigil = { help = 'Gérer vos sigils', params = { { name = 'action', help = 'offrir, renommer <n°> <nom>, oublier <n°> ou brouiller' } } },
            admin = { help = 'Magie (Conseil)', params = { { name = 'action', help = 'mage, apprendre, oublier, niveau, xp, mana, fiche, donner' }, { name = 'id', help = 'numéro du joueur' } } },
        },
        -- journal du Registre du Conseil (32 signes au plus)
        logs = {
            mage = 'Magie : mage', learn = 'Magie : sort appris', forget = 'Magie : sort retiré', level = 'Magie : niveau de sort',
            xp = 'Magie : XP de sort', mana = 'Magie : mana remplie', sheet = 'Magie : fiche consultée', give = 'Magie : objet donné',
        },
        -- interface (envoyée à la page une fois prête)
        ui = {
            cast = { interrupted = 'Incantation brisée' },
            -- cible verrouillée par un sort d'attaque : le bord de son écran rougit, avec ce texte
            threat = { text = 'Un frisson vous parcourt…' },
            composer = {
                title = 'Murmure', to = 'Destinataires', circle = 'Votre cercle : %d contact(s) au plus',
                noContacts = 'Vous ne gardez encore aucun sigil : échangez-en face à face (/sigil offrir).',
                message = 'Votre message', placeholder = 'Quelques mots à confier au vent…', count = '%d / %d signes',
                position = 'Joindre ma position', positionLocked = 'Joindre sa position : niveau 3',
                send = 'Murmurer', close = 'Fermer', cost = 'Mana : %d',
            },
            murmur = { from = 'De %s', unknown = 'Une présence inconnue', waypoint = 'Un point de passage est marqué sur votre carte.' },
            offer = {
                title = 'Un sigil vous est tendu',
                body = 'La personne en face de vous vous confie son sigil. Sous quel nom le garderez-vous ?',
                name = 'Nom du contact', giveBack = 'Lui confier mon sigil en retour',
                accept = 'Accepter', refuse = 'Refuser', remaining = '%d s',
            },
            naming = {
                title = 'Un sigil en retour', body = 'On vous confie un sigil en retour. Sous quel nom le garderez-vous ?',
                name = 'Nom du contact', accept = 'Garder', refuse = 'Refuser', remaining = '%d s',
            },
            confirm = {
                scrambleTitle = 'Brouiller votre sigil',
                scrambleBody = 'Un nouveau sigil remplacera l\'ancien : tous ceux qui le connaissaient perdront le lien. Votre propre liste vous reste. Coût : %d de mana.',
                confirm = 'Brouiller', cancel = 'Renoncer',
            },
            grimoire = {
                title = 'Grimoire',
                sealed = 'Les pages restent illisibles : les signes se dérobent à votre regard, comme si le livre refusait de vous parler.',
                empty = 'Aucun sort n\'est encore couché dans ces pages.',
                level = 'Niveau %d', mastered = 'Maîtrise achevée', xp = '%d / %d XP', xpMax = '%d XP',
                cost = 'Mana : %d', cooldown = 'Recharge : %d s', key = 'Touche : %s', noKey = 'aucune', lock = 'Verrouiller : %s',
                current = 'Ce que vous savez', next = 'Au niveau suivant', sigils = 'Sigils mémorisables : %d',
                colors = 'Couleur de la lumière', close = 'Fermer',
            },
            register = {
                title = 'Registre des murmures', empty = 'Ce registre est vierge.', sent = 'À %s', received = 'De %s',
                unknown = 'D\'une présence inconnue',
                tear = 'Arracher la page', count = '%d / %d pages', close = 'Fermer',
                months = { 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre' },
                date = 'Le %d %s, à %dh%s',
            },
        },
    },
}
