--[[
    vava_magic/config.lua
    Rôle : configuration de la magie (lue par le client et le serveur) : mana, progression, incantation, éléments et
           roue des sorts, contrôles du mode magie, sorts et leurs niveaux, effets (budget et niveau de détail),
           sigils, registre, objets, combat, touches, commandes, limites de débit, et TOUS les textes vus par les
           joueurs (l'interface reçoit les siens d'ici).
    Ajouter un sort : créer server/spells/<nom>.lua et client/spells/<nom>.lua, les lister dans le fxmanifest, et
           déclarer ici spells.<nom> (mêmes champs communs que les sorts ci-dessous) ; la roue, le grimoire et les
           commandes du Conseil le prennent d'eux-mêmes. Son icône : web/img/spells/<icon>.svg.
    Animations et particules : noms tirés de GTA V, À VÉRIFIER EN JEU (voir README).
    Dépendances : shared/constants.lua
]]

VavaMagic.config = {
    coreVersion = '0.5.0',

    -- Mana : gérée par le serveur, jamais sauvegardée (pleine à la connexion). Régénération : `regenPoints` points
    -- toutes les `regenMs` ms ; la page anime la remontée elle-même (aucun envoi périodique). Avec des recharges
    -- courtes, c'est la mana qui borne le combat : les coûts des sorts sont réglés en conséquence.
    mana = {
        max = 100,
        regenPoints = 3,
        regenMs = 5000,
        -- barre de mana : montrée quand la mana n'est pas pleine, en mode magie, et `lingerMs` après un sort
        hud = { lingerMs = 4000 },
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
        globalCooldownMs = 1000,   -- délai entre deux sorts, quels qu'ils soient
        maxMove = 1.0,             -- mètres parcourus au plus (sorts sans `moveSpeed`)
        moveMargin = 0.5,          -- marge du serveur sur la distance (positions réseau)
        finishToleranceMs = 300,   -- fin acceptée un peu avant la durée (latence)
        graceMs = 4000,            -- au-delà de la durée, une incantation sans fin est abandonnée
        checkMs = 100,             -- contrôles du client (chute, blessure, déplacement) hors déplacement lent
        castBarMinMs = 500,        -- en deçà, pas de barre d'incantation (projectiles quasi instantanés)
        animLoadMs = 2000,         -- attente du chargement d'une animation
    },

    -- Fiche : écrite dans le personnage (le core la sauvegarde par lots) au plus toutes les `flushMs`, et au départ.
    persistence = { flushMs = 15000 },

    -- Éléments : couleur du réticule et de l'interface, particules dans les mains pendant l'incantation (vues de
    -- tous), groupe de la roue. L'élément d'un sort sert à l'affichage, aux combinaisons et, plus tard, aux affinités.
    elements = {
        feu = {
            label = 'Feu', group = 'feu', color = { r = 255, g = 132, b = 52 },
            hands = { asset = 'core', name = 'ent_amb_torch_fire', scale = 0.25 },
        },
        eau = {
            label = 'Eau', group = 'eau', color = { r = 96, g = 176, b = 255 },
            hands = { asset = 'core', name = 'ent_amb_waterfall_splash_p', scale = 0.12 },
        },
        terre = {
            label = 'Terre', group = 'terre', color = { r = 200, g = 156, b = 98 },
            hands = { asset = 'core', name = 'ent_dst_dust', scale = 0.3 },
        },
        lumiere = { label = 'Lumière', group = 'utilitaires', color = { r = 255, g = 224, b = 150 } },
        esprit = { label = 'Esprit', group = 'utilitaires', color = { r = 190, g = 164, b = 255 } },
    },

    -- Roue des sorts : anneau intérieur, dans cet ordre (seuls les groupes d'un sort connu s'affichent) ; l'anneau
    -- extérieur montre les sorts du groupe survolé.
    wheel = {
        groups = {
            { id = 'feu', label = 'Feu', icon = 'feu' },
            { id = 'eau', label = 'Eau', icon = 'eau' },
            { id = 'terre', label = 'Terre', icon = 'terre' },
            { id = 'utilitaires', label = 'Utilitaires', icon = 'utilitaires' },
        },
    },

    -- Mode magie : un sort choisi, mains vides, à pied, debout, et le bridge le permet. Tant qu'il est actif, l'attaque
    -- et la visée de GTA sont coupées (boucle par image) ; il s'endort après `idleMs` sans viser ni lancer, et le
    -- clic droit le réveille. Sortir une arme ou monter en véhicule le coupe, sans perdre le sort choisi.
    controls = {
        idleMs = 20000,
        conditionsMs = 200,     -- conditions (arme, véhicule, chute) relues à cet intervalle, pas à chaque image
        aimMoveBlend = 1.5,     -- allure permise en visant (1 marche, 2 course) : un peu ralentie
        scrollSpells = true,    -- molette en mode magie : sort suivant ou précédent de l'élément choisi
        -- aperçu des zones au sol à l'endroit visé, vu du seul lanceur
        preview = { alpha = 110, height = 0.06, groundOffset = 0.02, pointSize = 0.25, feetOffset = 0.98 },
    },

    -- Effets : niveau de détail selon la distance, plafonds pour que plusieurs mages restent fluides.
    effects = {
        fullDistance = 30.0,     -- en deçà : effets complets ; au-delà, simplifiés (pas de particules secondaires)
        maxDistance = 150.0,     -- au-delà : rien n'est dessiné
        maxLights = 24,          -- lumières dynamiques dessinées par image
        maxLooped = 40,          -- particules en boucle actives en même temps
        assetLoadMs = 3000,      -- attente du chargement d'un lot de particules
        releaseMs = 60000,       -- un lot inutilisé depuis ce délai est libéré
    },

    -- Sorts. Champs communs :
    --   order (grimoire et roue), label, summary, element (clé de `elements`), type (projectile, zone, utilitaire),
    --   icon (web/img/spells/<icon>.svg), baseCost, xp (succès), hitXp (bonus quand le sort touche une cible),
    --   moveSpeed (m/s permis pendant l'incantation ; absent = immobile), interruptOnHurt (une blessure brise
    --   l'incantation, vrai par défaut), lockOn (suit la cible verrouillée), aim (visée : kind = projectile, point,
    --   self ou none ; reach = portée du point visé ; minLevel = niveau dès lequel la visée sert), anims (start, loop,
    --   release : { dict, clip, flag, ms }), ambientText (texte vu à 15 m), runes (runes au-dessus des mains),
    --   levelScale (taille des effets selon le niveau), levels (5 niveaux : castMs, cooldownMs, description du
    --   niveau, unlock = ce que le niveau apporte, puis les valeurs propres au sort).
    spells = {
        boule_de_feu = {
            order = 1,
            label = 'Boule de feu',
            summary = 'Rassembler les flammes et les jeter sur un adversaire.',
            element = 'feu',
            type = 'projectile',
            icon = 'boule_de_feu',
            baseCost = 14,
            xp = 20,
            hitXp = 10,
            moveSpeed = 1.2,      -- le lanceur peut marcher pendant l'incantation
            lockOn = true,        -- se lance sur la cible verrouillée (voir `targeting`)
            aim = { kind = 'projectile' },
            -- haut du corps seulement : on peut se déplacer en lançant
            anims = {
                start = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'enter', flag = 48, ms = 250 },
                loop = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'idle_a', flag = 49 },
                release = { dict = 'weapons@projectile@grenade_str', clip = 'throw_m_fb_stand', flag = 48, ms = 900 },
            },
            ambientText = 'rassemble des flammes entre ses mains',
            levelScale = { 0.75, 0.85, 1.0, 1.15, 1.4 },
            -- speed (m/s) · range (m) · damage (points de vie) · fizzle (chance qu'elle s'éteigne) · size (taille du
            -- feu) · aoeRadius/aoeShare (zone d'effet, dégâts réduits aux cibles secondaires) · burn (brûlure :
            -- durée, intervalle, points de vie par intervalle) · homing (degrés par seconde dont elle s'incurve vers la
            -- cible verrouillée ; 0 : elle part droit vers elle)
            levels = {
                {
                    castMs = 450, cooldownMs = 4000, speed = 14.0, range = 20.0, damage = 8, fizzle = 0.20, size = 0.6,
                    aoeRadius = 0, aoeShare = 0, burn = false, homing = 0,
                    description = 'Une petite boule de feu, lente et peu sûre : elle s\'éteint une fois sur cinq. Portée : vingt mètres.',
                    unlock = 'Vous savez lancer une petite boule de feu.',
                },
                {
                    castMs = 400, cooldownMs = 3500, speed = 17.0, range = 26.0, damage = 12, fizzle = 0.10, size = 0.7,
                    aoeRadius = 0, aoeShare = 0, burn = false, homing = 0,
                    description = 'Plus brûlante et plus lointaine (vingt-six mètres) ; elle ne s\'éteint plus qu\'une fois sur dix.',
                    unlock = 'Votre boule de feu frappe plus fort et plus loin.',
                },
                {
                    castMs = 350, cooldownMs = 3000, speed = 20.0, range = 32.0, damage = 15, fizzle = 0.06, size = 0.8,
                    aoeRadius = 2.5, aoeShare = 0.5, burn = false, homing = 0,
                    description = 'Elle éclate à l\'impact et lèche ceux qui se tiennent à deux pas et demi de la cible.',
                    unlock = 'Votre boule de feu éclate à l\'impact et touche ceux qui entourent la cible.',
                },
                {
                    castMs = 300, cooldownMs = 2500, speed = 24.0, range = 38.0, damage = 17, fizzle = 0.03, size = 0.9,
                    aoeRadius = 2.5, aoeShare = 0.5, burn = { durationMs = 4000, tickMs = 1000, damage = 2 }, homing = 35,
                    description = 'La cible touchée brûle encore quelques instants, et la boule s\'incurve un peu vers la cible verrouillée.',
                    unlock = 'La cible touchée brûle encore quelques instants ; votre boule s\'incurve vers la cible verrouillée.',
                },
                {
                    castMs = 250, cooldownMs = 2000, speed = 32.0, range = 45.0, damage = 22, fizzle = 0.01, size = 1.1,
                    aoeRadius = 3.5, aoeShare = 0.6, burn = { durationMs = 5000, tickMs = 1000, damage = 3 }, homing = 70,
                    description = 'Un trait de feu rapide et sûr, à quarante-cinq mètres, qui éclate largement, embrase sa cible et la suit de près.',
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
                trail = 'ent_amb_torch_fire', impact = 'ent_sht_flame', fizzle = 'ent_sht_steam',
                impactScale = 1.2, fizzleScale = 0.8,
            },
            light = { r = 255, g = 140, b = 40, range = 6.0, intensity = 6.0 },
            projectile = { model = 'prop_golf_ball', handBone = 57005, radius = 0.25 },
        },

        mur_de_flammes = {
            order = 2,
            label = 'Mur de flammes',
            summary = 'Dresser au sol une ligne de feu, en travers du chemin de l\'adversaire.',
            element = 'feu',
            type = 'zone',
            icon = 'mur_de_flammes',
            baseCost = 24,
            xp = 25,
            hitXp = 10,
            -- placé au point visé, perpendiculaire à la direction du regard (aperçu au sol : sa longueur et sa largeur)
            aim = { kind = 'point', shape = 'line', length = 'length', width = 'width' },
            -- corps entier : bras levés, puis rabattus vers le sol
            anims = {
                start = { dict = 'anim@mp_player_intuppersurrender', clip = 'enter', flag = 0, ms = 400 },
                loop = { dict = 'anim@mp_player_intuppersurrender', clip = 'idle_a', flag = 1 },
                release = { dict = 'anim@mp_player_intuppersurrender', clip = 'exit', flag = 0, ms = 600 },
            },
            ambientText = 'lève les mains, et le sol se met à rougeoyer',
            levelScale = { 0.8, 0.9, 1.0, 1.15, 1.35 },
            -- reach (m entre le lanceur et le point visé) · length, width (m) · durationMs · damage (points de vie à
            -- chaque passage) · burn (brûlure laissée à qui le traverse)
            levels = {
                {
                    castMs = 1200, cooldownMs = 14000, reach = 12.0, length = 3.0, width = 1.2, durationMs = 4000, damage = 6,
                    burn = { durationMs = 3000, tickMs = 1000, damage = 2 },
                    description = 'Une ligne de feu de trois mètres, qui brûle quatre secondes. La traverser coûte quelques flammes.',
                    unlock = 'Vous savez dresser un mur de flammes.',
                },
                {
                    castMs = 1100, cooldownMs = 13000, reach = 13.0, length = 4.5, width = 1.2, durationMs = 5000, damage = 7,
                    burn = { durationMs = 3000, tickMs = 1000, damage = 2 },
                    description = 'Quatre mètres et demi de flammes, cinq secondes durant.',
                    unlock = 'Votre mur s\'allonge et dure plus longtemps.',
                },
                {
                    castMs = 1000, cooldownMs = 12000, reach = 14.0, length = 6.0, width = 1.3, durationMs = 6000, damage = 8,
                    burn = { durationMs = 3000, tickMs = 1000, damage = 3 },
                    description = 'Six mètres, six secondes ; ceux qui le traversent brûlent plus fort.',
                    unlock = 'Votre mur barre six mètres et brûle plus fort.',
                },
                {
                    castMs = 900, cooldownMs = 10000, reach = 15.0, length = 8.0, width = 1.4, durationMs = 7000, damage = 10,
                    burn = { durationMs = 4000, tickMs = 1000, damage = 3 },
                    description = 'Huit mètres de feu pour sept secondes, et une brûlure tenace.',
                    unlock = 'Votre mur barre huit mètres, et sa brûlure tient plus longtemps.',
                },
                {
                    castMs = 800, cooldownMs = 9000, reach = 16.0, length = 10.0, width = 1.5, durationMs = 8000, damage = 12,
                    burn = { durationMs = 4000, tickMs = 1000, damage = 4 },
                    description = 'Une muraille de feu de dix mètres, huit secondes durant, qui marque durement ceux qui la franchissent.',
                    unlock = 'Votre mur de flammes atteint dix mètres et sa pleine fureur.',
                },
            },
            maxPerCaster = 2,         -- au-delà, le plus ancien s'éteint
            hitCooldownMs = 1000,     -- un même joueur n'est blessé qu'une fois par intervalle par un même mur
            heightMargin = 6.0,       -- écart de hauteur permis entre le lanceur et le point visé (m)
            fx = {
                asset = 'core', flame = 'ent_amb_torch_fire', ignite = 'ent_sht_flame', smother = 'ent_sht_steam',
                spacing = 1.0, reducedSpacing = 2.5, scale = 1.6, igniteScale = 1.0,
            },
            light = { r = 255, g = 118, b = 36, range = 5.5, intensity = 4.5, count = 3 },
        },

        nova_ardente = {
            order = 3,
            label = 'Nova ardente',
            summary = 'Libérer d\'un coup les flammes tout autour de soi.',
            element = 'feu',
            type = 'zone',
            icon = 'nova_ardente',
            baseCost = 30,
            xp = 25,
            hitXp = 10,
            -- centrée sur le lanceur (aperçu au sol : son rayon), qui n'en souffre pas
            aim = { kind = 'self', shape = 'circle', radius = 'radius' },
            anims = {
                start = { dict = 'anim@mp_player_intcelebrationmale@jazz_hands', clip = 'jazz_hands', flag = 0, ms = 500 },
                loop = { dict = 'anim@mp_player_intuppersurrender', clip = 'idle_a', flag = 1 },
                release = { dict = 'anim@mp_player_intcelebrationmale@jazz_hands', clip = 'jazz_hands', flag = 0, ms = 800 },
            },
            ambientText = 'rassemble une chaleur qui fait trembler l\'air autour de lui',
            levelScale = { 0.8, 0.9, 1.0, 1.15, 1.4 },
            -- radius (m) · damage (points de vie) · knockback (m/s du recul, 0 : aucun) · burn
            levels = {
                {
                    castMs = 1100, cooldownMs = 15000, radius = 3.0, damage = 10, knockback = 0, burn = false,
                    description = 'Une gerbe de flammes jaillit autour de vous, sur trois mètres.',
                    unlock = 'Vous savez libérer une nova ardente.',
                },
                {
                    castMs = 1000, cooldownMs = 14000, radius = 3.5, damage = 12, knockback = 0, burn = false,
                    description = 'La gerbe s\'élargit à trois mètres et demi et brûle plus fort.',
                    unlock = 'Votre nova porte plus loin et frappe plus fort.',
                },
                {
                    castMs = 1000, cooldownMs = 13000, radius = 4.0, damage = 14, knockback = 4.0, burn = false,
                    description = 'Quatre mètres de flammes, dont le souffle repousse ceux qu\'il touche.',
                    unlock = 'Le souffle de votre nova repousse ceux qu\'il touche.',
                },
                {
                    castMs = 900, cooldownMs = 12000, radius = 5.0, damage = 16, knockback = 5.0,
                    burn = { durationMs = 3000, tickMs = 1000, damage = 3 },
                    description = 'Cinq mètres de feu qui repoussent et laissent brûler ceux qu\'ils touchent.',
                    unlock = 'Ceux que votre nova touche brûlent encore un moment.',
                },
                {
                    castMs = 800, cooldownMs = 10000, radius = 6.0, damage = 20, knockback = 6.0,
                    burn = { durationMs = 4000, tickMs = 1000, damage = 3 },
                    description = 'Un brasier de six mètres, qui repousse, embrase et laisse la terre noircie.',
                    unlock = 'Votre nova atteint six mètres et sa pleine fureur.',
                },
            },
            broadcastRadius = 120.0,  -- joueurs qui voient la nova
            fx = { asset = 'core', burst = 'ent_sht_flame', points = 12, scale = 1.4, ring = 25, ringMs = 450 },
            light = { r = 255, g = 132, b = 44, range = 9.0, intensity = 9.0, flashMs = 450 },
        },

        lueur = {
            order = 10,
            label = 'Lueur',
            summary = 'Faire naître la lumière, au creux de la main puis en orbe.',
            element = 'lumiere',
            type = 'utilitaire',
            icon = 'lueur',
            baseCost = 8,
            xp = 10,
            hitXp = 0,
            -- visée seulement pour ancrer un orbe (niveau 4) : clic gauche en visant
            aim = { kind = 'point', reach = 8.0, minLevel = 4 },
            anims = {
                loop = { dict = 'amb@world_human_stand_fire@male@base', clip = 'base', flag = 49 },
            },
            ambientText = 'fait naître une lueur au creux de sa main',
            levelScale = { 0.8, 0.9, 1.0, 1.1, 1.25 },
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
                    description = 'Un orbe de sept minutes ; en visant, vous pouvez aussi en ancrer un en un lieu pour cinq minutes.',
                    unlock = 'En visant, vous pouvez ancrer un orbe en un lieu, où il brille sans vous.',
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

        murmure = {
            order = 11,
            label = 'Murmure',
            summary = 'Confier quelques mots au vent, jusqu\'à ceux dont on garde le sigil.',
            element = 'esprit',
            type = 'utilitaire',
            icon = 'murmure',
            baseCost = 12,
            xp = 20,
            hitXp = 0,
            aim = { kind = 'none' },  -- clic gauche : le parchemin d'écriture s'ouvre
            anims = {
                loop = { dict = 'anim@mp_player_intupperair_synth', clip = 'idle_a', flag = 49 },
            },
            ambientText = 'trace des runes dans l\'air',
            runes = true,
            levelScale = { 1.0, 1.0, 1.0, 1.0, 1.0 },
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
    },

    -- Verrouillage d'une cible, pour les sorts d'attaque (`lockOn = true`) : le clic molette prend le joueur le plus
    -- proche du centre de l'écran, à portée du sort et en vue ; un nouveau clic passe au suivant ; maintenu, il
    -- relâche. Rien ne passe par le réseau tant qu'on ne lance pas ; la cible est revérifiée par le serveur au lancer.
    targeting = {
        coneDeg = 25,          -- écart permis entre le centre de l'écran et la cible
        holdMs = 600,          -- clic maintenu au moins ce temps : verrou relâché
        idleMs = 20000,        -- verrou relâché après ce délai sans attaque
        checkMs = 250,         -- revérification de la portée et de la vue
        lostChecks = 4,        -- vérifications de suite sans la voir avant de la perdre (1 s)
        rangeMargin = 2.0,     -- marge sur la portée, côté client comme serveur
        warnMs = 2200,         -- durée du frisson chez la cible (bord de l'écran qui rougit)
        -- anneau sous la cible, vu du seul lanceur
        ring = { marker = 25, size = 1.2, r = 200, g = 64, b = 40, alpha = 210, groundOffset = 0.95, spin = 90.0 },
    },

    -- États élémentaires posés sur les joueurs, décidés par le serveur et vus de tous (state bag du ped) :
    --   burn (Brûlure : dégâts sur la durée) · wet (Mouillé : aucun effet direct, sert aux combinaisons) ·
    --   slow (Ralenti : allure réduite, le plus fort l'emporte) · stagger (Chancelant : déséquilibre, impossible
    --   d'incanter) · knockdown (Renversé : chute courte) · frozen (Gelé : immobilisé).
    -- Après un contrôle dur (`hard`), la cible en est protégée `hardImmunityMs` ; les dégâts, eux, s'appliquent toujours.
    states = {
        hard = { stagger = true, knockdown = true, frozen = true },
        hardImmunityMs = 6000,
        order = { 'burn', 'wet', 'slow', 'stagger', 'knockdown', 'frozen' },  -- ordre des icônes
        durations = { burn = 3000, wet = 12000, slow = 3000, stagger = 1500, knockdown = 1800, frozen = 2000 },
        slowMinRate = 0.35,           -- allure gardée au pire (part de la normale)
        stagger = { clipset = 'move_m@drunk@verydrunk', shake = 'DRUNK_SHAKE', shakeAmplitude = 0.7 },
        -- particules sur le joueur affecté (vues de tous, dans la limite de distance des effets)
        fx = {
            burn = { asset = 'core', name = 'ent_amb_torch_fire', bone = 24818, scale = 0.6 },
            wet = { asset = 'core', name = 'ent_sht_water', bone = 24818, scale = 0.4 },
            frozen = { asset = 'core', name = 'ent_sht_steam', bone = 24818, scale = 0.5 },
            stagger = { asset = 'core', name = 'ent_dst_dust', bone = 24818, scale = 0.4 },
        },
        burnLight = { r = 255, g = 140, b = 40, range = 3.0, intensity = 3.0 },
    },

    -- Zones au sol (mur de flammes ; plus tard brume, sol mouillé, boue, vapeur), décidées par le serveur : forme,
    -- position, élément, fin. Le serveur vérifie toutes les `tickMs` qui s'y trouve (ou les a traversées) ; chaque
    -- zone n'est envoyée qu'aux joueurs à moins de `syncRadius`, y compris ceux qui s'en approchent après coup.
    zones = { tickMs = 500, syncRadius = 150.0, maxActive = 60 },

    -- Combat entre joueurs. Dégâts des sorts en points de vie, sur `healthPoints` pour un personnage en pleine santé.
    combat = {
        pvp = true, -- false : les sorts offensifs se voient et se lancent, mais ne blessent personne
        healthPoints = 100,
        -- réaction de la cible touchée : geste bref (haut du corps) et effet d'écran selon l'élément
        reactions = {
            feu = { anim = { dict = 'anim@mp_player_intupperface_palm', clip = 'idle_a', flag = 48, ms = 700 }, screen = 'burn' },
        },
        knockbackMs = 250,  -- durée de la poussée d'un recul
        -- zones où l'on ne lance aucun sort offensif (cercle au sol, en mètres) et où personne n'en est blessé :
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

    -- Touches et boutons (réglables par le joueur dans Paramètres > Raccourcis > FiveM). FiveM nomme les touches par
    -- leur place sur un clavier QWERTY : celles-ci sont au même endroit en AZERTY. Changer une commande remet la
    -- touche par défaut. `hold` : touche maintenue (commandes +/-). `display` : nom montré si GTA ne le donne pas.
    keys = {
        roue = { command = 'vava_magic_roue', device = 'keyboard', key = 'TAB', label = 'Magie : roue des sorts (maintenir)', hold = true, display = 'Tab' },
        viser = { command = 'vava_magic_viser', device = 'MOUSE_BUTTON', key = 'MOUSE_RIGHT', label = 'Magie : viser (maintenir)', hold = true, display = 'Clic droit' },
        lancer = { command = 'vava_magic_lancer', device = 'MOUSE_BUTTON', key = 'MOUSE_LEFT', label = 'Magie : lancer le sort choisi', display = 'Clic gauche' },
        cible = { command = 'vava_magic_verrou', device = 'MOUSE_BUTTON', key = 'MOUSE_MIDDLE', label = 'Magie : verrouiller une cible (maintenir : relâcher)', hold = true, display = 'Clic molette' },
        annuler = { command = 'vava_magic_annuler', device = 'keyboard', key = 'X', label = 'Magie : interrompre l\'incantation', display = 'X' },
        suivant = { command = 'vava_magic_suivant', device = 'MOUSE_WHEEL', key = 'IOM_WHEEL_DOWN', label = 'Magie : sort suivant de l\'élément', display = 'Molette' },
        precedent = { command = 'vava_magic_precedent', device = 'MOUSE_WHEEL', key = 'IOM_WHEEL_UP', label = 'Magie : sort précédent de l\'élément', display = 'Molette' },
    },

    -- Commandes du chat (et leurs sous-commandes).
    commands = {
        grimoire = 'grimoire',
        sort = 'sort',
        lancer = 'lancer',
        murmure = 'murmure',
        lueur = 'lueur',
        sigils = 'sigils',
        sigil = 'sigil',
        admin = 'magie',
        none = 'aucun',
        sigilActions = { offer = 'offrir', rename = 'renommer', forget = 'oublier', scramble = 'brouiller' },
        lightActions = { anchor = 'ancrer', color = 'couleur', off = 'eteindre', dispel = 'dissiper' },
        adminActions = {
            mage = 'mage', learn = 'apprendre', forget = 'oublier', level = 'niveau', xp = 'xp',
            all = 'tous', master = 'maitrise', clear = 'vider', mana = 'mana', cooldowns = 'recharges',
            sheet = 'fiche', give = 'donner', cleanup = 'nettoyer',
        },
        yes = 'oui',
        no = 'non',
    },

    rateLimits = {
        sheet = { capacity = 3, refillPerSecond = 0.2 },
        select = { capacity = 8, refillPerSecond = 2 },
        cast = { capacity = 8, refillPerSecond = 2 },
        cancel = { capacity = 10, refillPerSecond = 2 },
        sigils = { capacity = 6, refillPerSecond = 1 },
        offer = { capacity = 3, refillPerSecond = 0.2 },
        answer = { capacity = 6, refillPerSecond = 1 },
        edit = { capacity = 6, refillPerSecond = 1 },
        scramble = { capacity = 2, refillPerSecond = 0.05 },
        light = { capacity = 6, refillPerSecond = 1 },
        impact = { capacity = 8, refillPerSecond = 3 },
        register = { capacity = 6, refillPerSecond = 1 },
    },

    -- Textes vus par les joueurs (français, univers médiéval).
    texts = {
        -- refus et erreurs, par code renvoyé par le serveur
        errors = {
            not_ready = 'La magie ne répond pas encore : réessayez dans un instant.',
            not_mage = 'La magie ne vous a jamais répondu.',
            unknown_spell = 'Vous ignorez ce sort.',
            no_spell = 'Aucun sort n\'est prêt dans vos mains : choisissez-en un dans la roue.',
            level_too_low = 'Votre maîtrise de ce sort ne va pas encore jusque-là.',
            no_mana = 'Votre mana est trop faible.',
            cooldown = 'Le sort n\'est pas encore prêt (%d s).',
            global_cooldown = 'Laissez la magie retomber un instant.',
            busy = 'Vous incantez déjà.',
            downed = 'Vous êtes à terre.',
            cannot_cast = 'Vous ne pouvez pas incanter ainsi.',
            in_vehicle = 'Impossible d\'incanter ainsi installé.',
            protected_zone = 'Une paix sacrée règne en ce lieu : la magie offensive ne vous obéit pas.',
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
            staggered = 'Vous chancelez : impossible d\'incanter.',
            knocked = 'Vous êtes renversé : impossible d\'incanter.',
            frozen = 'Le gel vous fige : impossible d\'incanter.',
            no_point = 'Visez le sol, à portée.',
            zone_limit = 'Trop de sortilèges marquent déjà le sol du royaume.',
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
            allLearned = 'Tous les sorts s\'éveillent en vous.',
            allForgotten = 'Tous vos sorts s\'effacent de votre mémoire.',
            becameMage = 'La magie s\'éveille en vous.',
            lostMagic = 'La magie s\'est retirée de vous.',
            manaRefilled = 'Votre mana est pleine.',
            cooldownsReset = 'Vos sorts sont tous prêts.',
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
            immune = 'Vous reprenez pied : plus rien ne vous déséquilibre un moment.',
            selected = 'Sort prêt : %s.',
            deselected = 'Vous rangez votre magie.',
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
            spellUsage = 'Usage : /sort <nom> | aucun. Sorts connus : %s',
            adminUsage = 'Usage : /magie <action> [id] … — mage [id] <oui|non> · apprendre [id] <sort> · oublier [id] <sort> · niveau [id] <sort> <1-5> · xp [id] <sort> <xp> · tous [id] · maitrise [id] · vider [id] · mana [id] · recharges [id] · fiche [id] · donner [id] <grimoire|registre> · nettoyer',
            adminForbidden = 'Ces commandes sont réservées au Conseil.',
            adminNoTarget = 'Aucun personnage en jeu sous ce numéro.',
            adminUnknownSpell = 'Sort inconnu. Sorts : %s',
            adminDone = 'C\'est fait.',
            adminCleaned = 'Nettoyé : %d effet(s) retiré(s) du monde.',
            adminFailed = 'Échec : %s',
            sheetTitle = 'Fiche magie de %s (joueur n° %d)',
            sheetMage = 'Mage : %s · sort choisi : %s',
            sheetSpell = '— %s : niveau %d (%d XP)',
            sheetNoSpell = '— aucun sort',
            sheetSigils = 'Sigils gardés : %d · mana : %d / %d',
            yes = 'oui',
            no = 'non',
            none = 'aucun',
        },
        -- suggestions du chat
        suggestions = {
            grimoire = 'Ouvrir votre grimoire',
            sort = { help = 'Choisir le sort prêt dans vos mains', params = { { name = 'sort', help = 'nom du sort, ou « aucun »' } } },
            lancer = { help = 'Lancer le sort choisi (sans visée)', params = { { name = 'sort', help = 'facultatif : un autre sort connu' } } },
            murmure = { help = 'Écrire un murmure', params = { { name = 'n°', help = 'facultatif : numéros des contacts, séparés par des virgules' }, { name = 'message', help = 'facultatif : le message' } } },
            lueur = { help = 'Lueur : allumer ou éteindre', params = { { name = 'action', help = 'ancrer, couleur <nom>, eteindre ou dissiper' } } },
            sigils = 'Lister les sigils que vous gardez',
            sigil = { help = 'Gérer vos sigils', params = { { name = 'action', help = 'offrir, renommer <n°> <nom>, oublier <n°> ou brouiller' } } },
            admin = { help = 'Magie (Conseil)', params = { { name = 'action', help = 'mage, apprendre, oublier, niveau, xp, tous, maitrise, vider, mana, recharges, fiche, donner, nettoyer' }, { name = 'id', help = 'facultatif : numéro du joueur (sinon vous)' } } },
        },
        -- journal du Registre du Conseil (32 signes au plus)
        logs = {
            mage = 'Magie : mage', learn = 'Magie : sort appris', forget = 'Magie : sort retiré', level = 'Magie : niveau de sort',
            xp = 'Magie : XP de sort', all = 'Magie : tous les sorts', master = 'Magie : maîtrise de tout',
            clear = 'Magie : sorts retirés', mana = 'Magie : mana remplie', cooldowns = 'Magie : recharges effacées',
            sheet = 'Magie : fiche consultée', give = 'Magie : objet donné', cleanup = 'Magie : nettoyage du monde',
        },
        -- interface (envoyée à la page une fois prête)
        ui = {
            cast = { interrupted = 'Incantation brisée' },
            -- cible verrouillée par un sort d'attaque : le bord de son écran rougit, avec ce texte
            threat = { text = 'Un frisson vous parcourt…' },
            -- roue des sorts
            wheel = {
                cancel = 'Annuler', deselect = 'Ranger la magie', cost = '%d', cooldown = '%d s', noSpell = 'Aucun sort',
                level = 'Niveau %d',
            },
            -- barre de mana et sort prêt
            hud = { mana = 'Mana', asleep = 'Mains au repos' },
            -- états montrés au joueur affecté
            states = {
                burn = 'Brûlure', wet = 'Mouillé', slow = 'Ralenti', stagger = 'Chancelant', knockdown = 'Renversé',
                frozen = 'Gelé', immune = 'Protégé',
            },
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
                cost = 'Mana : %d', cooldown = 'Recharge : %s s', cast = 'Incantation : %s s', instant = 'Incantation : instantanée',
                element = 'Élément : %s', lock = 'Verrouiller : %s', controls = 'Roue : %s · viser : %s · lancer : %s',
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
