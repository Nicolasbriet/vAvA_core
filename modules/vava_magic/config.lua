--[[
    vava_magic/config.lua
    Rôle : configuration de la magie (lue par le client et le serveur) : mana, progression, incantation, éléments et
           roue des sorts, contrôles du mode magie, effets (budget et niveau de détail), projectiles, sorts et leurs
           niveaux, états, zones, combinaisons entre éléments, combat, sigils, registre, objets, touches, commandes,
           limites de débit, et TOUS les textes vus par les joueurs (l'interface reçoit les siens d'ici).
    Ajouter un sort : créer server/spells/<nom>.lua et client/spells/<nom>.lua, les lister dans le fxmanifest, et
           déclarer ici spells.<nom> (mêmes champs communs que les sorts ci-dessous) ; la roue, le grimoire et les
           commandes du Conseil le prennent d'eux-mêmes. Son icône : web/img/spells/<icon>.svg.
    Animations, particules et objets : noms tirés de GTA V, À VÉRIFIER EN JEU (voir README).
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
        armedNoticeMs = 5000,   -- arme ou bouclier en main (vava_combat) : « rangez votre arme » au plus une fois par
                                -- intervalle quand on presse viser ou lancer (la touche peut aussi servir à l'arme)
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
        -- traces temporaires au sol, vues de chaque client : sol noirci après le feu (mur, nova), fissure après la
        -- secousse ; disques sombres qui s'effacent en fondu (ms = 0 : aucune)
        traces = { ms = 20000, alpha = 90, r = 38, g = 28, b = 20, spacing = 1.2, size = 1.4 },
    },

    -- Sons. Ceux de l'interface sont fabriqués à la volée (Web Audio) : chime (murmure reçu), whoosh (lancer), impact,
    -- fizzle (boule éteinte), shatter (glace brisée), splash (vague), crack (sol qui se fend), rumble (grondement), hiss
    -- (vapeur). Un fichier .ogg déposé dans web/sounds/ et déclaré dans `files` remplace le son fabriqué du même nom
    -- (volume selon la distance, plusieurs lectures à la fois). Un son natif de GTA déclaré dans `native` ({ name, set },
    -- joué au point de l'effet par PlaySoundFromCoord) remplace le son de l'interface. Aucun fichier n'est fourni :
    -- tout fonctionne sans. Noms des sons natifs À VÉRIFIER EN JEU.
    sounds = {
        hearing = 60.0,  -- au-delà de cette distance, plus rien ne s'entend (m)
        files = {
            -- whoosh = 'sounds/whoosh.ogg',
        },
        native = {
            -- impact = { name = 'Explosion_Shake', set = 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
        },
    },

    -- Projectiles (boule de feu, trait de glace, projectile de roche) : contrôles du serveur à l'impact, communs à
    -- tous (positions lues côté serveur) ; un sort peut en changer certains dans son propre `hit`.
    projectiles = {
        angleDeg = 25,           -- écart permis entre la direction du lancer et le point d'impact
        targetMargin = 2.5,      -- mètres entre le point d'impact annoncé et la cible
        rangeMargin = 2.0,       -- mètres au-delà de la portée
        timeMarginMs = 450,      -- avance permise sur le temps de vol (latence)
        broadcastRadius = 150.0, -- joueurs qui voient le lancer
        launchGraceMs = 3000,    -- délai d'un impact après la fin du vol
        originHeight = 0.6,      -- hauteur des mains au-dessus de la position du ped
        targetHeight = 0.3,      -- cible verrouillée : visée au torse, au-dessus de la position du ped
        handBone = 57005,        -- SKEL_R_Hand : le projectile part de la main droite
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
            -- rendu du vol (voir client/projectiles.lua) : objet porteur (caché, seules ses particules se voient),
            -- rayon du test de collision, traînée, impact, extinction, lumière, sons
            projectile = { model = 'prop_golf_ball', visible = false, radius = 0.25 },
            fx = {
                asset = 'core',
                trail = 'ent_amb_torch_fire', impact = 'ent_sht_flame', fizzle = 'ent_sht_steam',
                impactScale = 1.2, fizzleScale = 0.8,
            },
            light = { r = 255, g = 140, b = 40, range = 6.0, intensity = 6.0 },
            sounds = { launch = 'whoosh', impact = 'impact', fizzle = 'fizzle' },
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

        trait_de_glace = {
            order = 4,
            label = 'Trait de glace',
            summary = 'Darder un éclat de glace qui transit l\'adversaire et alourdit ses pas.',
            element = 'eau',
            type = 'projectile',
            icon = 'trait_de_glace',
            baseCost = 12,
            xp = 20,
            hitXp = 10,
            moveSpeed = 1.2,
            lockOn = true,
            reaction = 'glace',   -- réaction de la cible (`combat.reactions`) : givre plutôt qu'éclaboussure
            aim = { kind = 'projectile' },
            anims = {
                start = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'enter', flag = 48, ms = 200 },
                loop = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'idle_a', flag = 49 },
                release = { dict = 'weapons@projectile@grenade_str', clip = 'throw_m_fb_stand', flag = 48, ms = 700 },
            },
            ambientText = 'condense entre ses doigts un éclat de givre',
            levelScale = { 0.8, 0.9, 1.0, 1.1, 1.25 },
            -- speed (m/s) · range (m) · damage (points de vie) · size · slow (Ralenti : force, part de l'allure
            -- retirée, et durée) · wetMs (durée de Mouillé) · homing (degrés par seconde vers la cible verrouillée)
            levels = {
                {
                    castMs = 300, cooldownMs = 3000, speed = 30.0, range = 25.0, damage = 5, size = 0.7,
                    slow = { strength = 0.25, durationMs = 2000 }, wetMs = 8000, homing = 0,
                    description = 'Un éclat de glace rapide qui mord à peine, mais alourdit les pas de la cible deux secondes et la laisse trempée.',
                    unlock = 'Vous savez darder un trait de glace.',
                },
                {
                    castMs = 280, cooldownMs = 2800, speed = 33.0, range = 28.0, damage = 6, size = 0.8,
                    slow = { strength = 0.3, durationMs = 2500 }, wetMs = 9000, homing = 0,
                    description = 'Plus vif et plus froid : la cible ralentit davantage, deux secondes et demie.',
                    unlock = 'Votre trait de glace ralentit plus fort et plus longtemps.',
                },
                {
                    castMs = 250, cooldownMs = 2500, speed = 36.0, range = 32.0, damage = 8, size = 0.9,
                    slow = { strength = 0.35, durationMs = 3000 }, wetMs = 10000, homing = 0,
                    description = 'Trente-deux mètres de portée ; la cible perd un tiers de son allure trois secondes.',
                    unlock = 'Votre trait porte plus loin et mord davantage.',
                },
                {
                    castMs = 220, cooldownMs = 2200, speed = 40.0, range = 36.0, damage = 10, size = 1.0,
                    slow = { strength = 0.45, durationMs = 3500 }, wetMs = 12000, homing = 20,
                    description = 'La cible perd près de la moitié de son allure, trois secondes et demie ; le trait s\'incurve un peu vers la cible verrouillée.',
                    unlock = 'Votre trait ralentit presque de moitié et s\'incurve vers la cible verrouillée.',
                },
                {
                    castMs = 200, cooldownMs = 2000, speed = 45.0, range = 40.0, damage = 12, size = 1.15,
                    slow = { strength = 0.5, durationMs = 4000 }, wetMs = 14000, homing = 40,
                    description = 'Un dard de givre à quarante mètres : la cible ne peut plus courir, quatre secondes, et le trait la suit de près.',
                    unlock = 'Votre trait de glace atteint sa pleine morsure : la cible ne peut plus courir.',
                },
            },
            projectile = { model = 'prop_golf_ball', visible = false, radius = 0.2, marker = { r = 200, g = 236, b = 255, alpha = 220, size = 0.16 } },
            fx = {
                asset = 'core', trail = 'ent_sht_steam', impact = 'ent_sht_water',
                trailScale = 0.6, impactScale = 1.0,
            },
            light = { r = 150, g = 210, b = 255, range = 4.0, intensity = 4.0 },
            sounds = { launch = 'whoosh', impact = 'shatter' },
        },

        vague = {
            order = 5,
            label = 'Vague',
            summary = 'Lever une vague qui balaie tout devant soi, éteint les flammes et détrempe le sol.',
            element = 'eau',
            type = 'zone',
            icon = 'vague',
            baseCost = 26,
            xp = 25,
            hitXp = 10,
            -- cône devant le lanceur, dans la direction du regard (aperçu au sol : sa portée et son ouverture)
            aim = { kind = 'self', shape = 'cone', radius = 'range', angle = 'halfAngle' },
            -- corps entier : bras levés, puis poussés devant soi
            anims = {
                start = { dict = 'anim@mp_player_intuppersurrender', clip = 'enter', flag = 0, ms = 400 },
                loop = { dict = 'anim@mp_player_intuppersurrender', clip = 'idle_a', flag = 1 },
                release = { dict = 'anim@mp_player_intcelebrationmale@bro_love', clip = 'bro_love', flag = 0, ms = 700 },
            },
            ambientText = 'rassemble l\'eau de l\'air entre ses bras',
            levelScale = { 0.8, 0.9, 1.0, 1.15, 1.35 },
            -- range (m) · halfAngle (demi-ouverture du cône, degrés) · knockback (m/s du recul) · knockdownMs (Renversé,
            -- 0 : aucun) · wetMs (Mouillé) · groundMs (sol mouillé laissé devant soi, 0 : aucun)
            levels = {
                {
                    castMs = 1000, cooldownMs = 12000, range = 4.0, halfAngle = 30, knockback = 3.0, knockdownMs = 0,
                    wetMs = 10000, groundMs = 6000,
                    description = 'Une vague de quatre mètres qui repousse, trempe et éteint les flammes devant vous.',
                    unlock = 'Vous savez lever une vague.',
                },
                {
                    castMs = 950, cooldownMs = 11000, range = 5.5, halfAngle = 32, knockback = 4.0, knockdownMs = 0,
                    wetMs = 11000, groundMs = 7000,
                    description = 'Cinq mètres et demi d\'eau, qui repoussent plus fort.',
                    unlock = 'Votre vague porte plus loin et repousse plus fort.',
                },
                {
                    castMs = 900, cooldownMs = 10000, range = 7.0, halfAngle = 35, knockback = 5.0, knockdownMs = 0,
                    wetMs = 12000, groundMs = 8000,
                    description = 'Sept mètres, plus larges ; le sol reste trempé plus longtemps.',
                    unlock = 'Votre vague s\'élargit et détrempe le sol plus longtemps.',
                },
                {
                    castMs = 850, cooldownMs = 9000, range = 8.5, halfAngle = 38, knockback = 6.0, knockdownMs = 1500,
                    wetMs = 13000, groundMs = 10000,
                    description = 'Huit mètres et demi : ceux qu\'elle frappe sont renversés.',
                    unlock = 'Votre vague renverse ceux qu\'elle frappe.',
                },
                {
                    castMs = 800, cooldownMs = 8000, range = 10.0, halfAngle = 40, knockback = 7.0, knockdownMs = 1800,
                    wetMs = 14000, groundMs = 12000,
                    description = 'Un raz-de-marée de dix mètres, qui renverse, noie les flammes et laisse un sol ruisselant.',
                    unlock = 'Votre vague atteint dix mètres et sa pleine force.',
                },
            },
            broadcastRadius = 120.0,  -- joueurs qui voient la vague
            fx = { asset = 'core', splash = 'ent_sht_water', rows = 4, perRow = 5, scale = 1.4, sweepMs = 450 },
        },

        brume = {
            order = 6,
            label = 'Brume',
            summary = 'Faire monter une brume épaisse où nul ne voit plus à deux pas.',
            element = 'eau',
            type = 'zone',
            icon = 'brume',
            baseCost = 22,
            xp = 20,
            hitXp = 5,
            aim = { kind = 'point', shape = 'circle', radius = 'radius' },
            anims = {
                start = { dict = 'anim@mp_player_intuppersurrender', clip = 'enter', flag = 0, ms = 400 },
                loop = { dict = 'anim@mp_player_intuppersurrender', clip = 'idle_a', flag = 1 },
                release = { dict = 'anim@mp_player_intuppersurrender', clip = 'exit', flag = 0, ms = 600 },
            },
            ambientText = 'souffle une haleine blanche qui roule au sol',
            levelScale = { 0.8, 0.9, 1.0, 1.15, 1.3 },
            -- reach (m) · radius (m) · durationMs · density (voile à l'écran de qui s'y tient, 0 à 1) · wetMs
            -- (Mouillé de qui s'y tient, 0 : aucun) · groundMs (sol mouillé laissé à sa fin, 0 : aucun)
            levels = {
                {
                    castMs = 1500, cooldownMs = 15000, reach = 15.0, radius = 4.0, durationMs = 8000, density = 0.7,
                    wetMs = 0, groundMs = 0,
                    description = 'Une brume de quatre mètres, huit secondes durant : qui s\'y tient n\'y voit plus guère.',
                    unlock = 'Vous savez faire monter la brume.',
                },
                {
                    castMs = 1400, cooldownMs = 14000, reach = 16.0, radius = 5.5, durationMs = 10000, density = 0.75,
                    wetMs = 0, groundMs = 0,
                    description = 'Cinq mètres et demi de brume, dix secondes.',
                    unlock = 'Votre brume s\'étend et dure plus longtemps.',
                },
                {
                    castMs = 1300, cooldownMs = 13000, reach = 18.0, radius = 7.0, durationMs = 12000, density = 0.8,
                    wetMs = 8000, groundMs = 8000,
                    description = 'Une brume lourde de sept mètres qui trempe ceux qui s\'y tiennent et laisse le sol mouillé.',
                    unlock = 'Votre brume trempe ceux qu\'elle enveloppe et laisse le sol mouillé.',
                },
                {
                    castMs = 1200, cooldownMs = 12000, reach = 20.0, radius = 8.5, durationMs = 14000, density = 0.85,
                    wetMs = 10000, groundMs = 10000,
                    description = 'Huit mètres et demi, quatorze secondes : un banc de brume où l\'on se perd.',
                    unlock = 'Votre brume s\'épaissit encore.',
                },
                {
                    castMs = 1100, cooldownMs = 11000, reach = 22.0, radius = 10.0, durationMs = 16000, density = 0.9,
                    wetMs = 12000, groundMs = 12000,
                    description = 'Un brouillard de dix mètres, seize secondes durant, où nul ne voit sa propre main.',
                    unlock = 'Votre brume atteint sa pleine épaisseur.',
                },
            },
            maxPerCaster = 1,          -- une nouvelle brume dissipe la précédente
            heightMargin = 6.0,        -- écart de hauteur permis entre le lanceur et le point visé (m)
            refreshMs = 4000,          -- Mouillé reposé au plus à cet intervalle sur un même joueur (réseau)
            -- à l'écran de qui s'y tient : voile de la page, et filtre de GTA ('' : aucun) à la force de `density`
            screen = { timecycle = 'hud_def_blur' },
            -- nappes réparties sur le disque : une par carré de `spacing` mètres de côté, au plus `maxPoints` (de près)
            -- ou `reducedPoints` (de loin)
            fx = { asset = 'core', cloud = 'exp_grd_bzgas_smoke', spacing = 5.0, maxPoints = 12, reducedPoints = 5, scale = 1.5 },
        },

        projectile_de_roche = {
            order = 7,
            label = 'Projectile de roche',
            summary = 'Arracher un bloc au sol et le projeter de toutes ses forces.',
            element = 'terre',
            type = 'projectile',
            icon = 'projectile_de_roche',
            baseCost = 18,
            xp = 22,
            hitXp = 10,
            moveSpeed = 0.8,
            lockOn = true,
            aim = { kind = 'projectile' },
            anims = {
                start = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'enter', flag = 48, ms = 300 },
                loop = { dict = 'anim@mp_player_intupperknuckle_crunch', clip = 'idle_a', flag = 49 },
                release = { dict = 'weapons@projectile@grenade_str', clip = 'throw_m_fb_stand', flag = 48, ms = 900 },
            },
            ambientText = 'arrache au sol un bloc de pierre qui flotte entre ses mains',
            levelScale = { 0.85, 0.9, 1.0, 1.1, 1.25 },
            -- speed (m/s, lent : on peut l'esquiver) · range (m) · damage (points de vie) · size · staggerMs
            -- (Chancelant, 0 : aucun) · aoeRadius/aoeShare (éclats autour de l'impact) · homing
            levels = {
                {
                    castMs = 500, cooldownMs = 4000, speed = 12.0, range = 18.0, damage = 14, size = 0.8,
                    staggerMs = 0, aoeRadius = 0, aoeShare = 0, homing = 0,
                    description = 'Un bloc lourd et lent, qui frappe fort qui ne l\'esquive pas. Portée : dix-huit mètres.',
                    unlock = 'Vous savez projeter un bloc de roche.',
                },
                {
                    castMs = 470, cooldownMs = 3800, speed = 13.0, range = 20.0, damage = 17, size = 0.9,
                    staggerMs = 0, aoeRadius = 0, aoeShare = 0, homing = 0,
                    description = 'Un bloc plus gros, à vingt mètres.',
                    unlock = 'Votre roche frappe plus fort.',
                },
                {
                    castMs = 440, cooldownMs = 3500, speed = 14.0, range = 22.0, damage = 20, size = 1.0,
                    staggerMs = 1200, aoeRadius = 0, aoeShare = 0, homing = 0,
                    description = 'Le choc fait chanceler la cible : elle ne peut plus incanter un instant.',
                    unlock = 'Votre roche fait chanceler ceux qu\'elle frappe.',
                },
                {
                    castMs = 400, cooldownMs = 3200, speed = 15.0, range = 25.0, damage = 23, size = 1.1,
                    staggerMs = 1500, aoeRadius = 0, aoeShare = 0, homing = 0,
                    description = 'Vingt-cinq mètres, et un déséquilibre plus long.',
                    unlock = 'Votre roche porte plus loin et ébranle plus longtemps.',
                },
                {
                    castMs = 360, cooldownMs = 3000, speed = 16.0, range = 28.0, damage = 26, size = 1.25,
                    staggerMs = 1800, aoeRadius = 2.5, aoeShare = 0.5, homing = 0,
                    description = 'Un rocher qui éclate à l\'impact : ses éclats blessent ceux qui se tiennent à deux pas et demi.',
                    unlock = 'Votre roche éclate à l\'impact et blesse ceux qui entourent la cible.',
                },
            },
            -- objet vu en vol, qui tournoie (degrés par seconde ; modèle de GTA à vérifier) ; tremblement de la caméra
            -- des joueurs proches de l'impact
            projectile = { model = 'prop_rock_1_b', visible = true, radius = 0.35, spin = 240.0 },
            fx = {
                asset = 'core', trail = 'ent_dst_dust', impact = 'ent_dst_rocks',
                trailScale = 0.5, impactScale = 1.2,
                shake = { name = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.15, radius = 12.0 },
            },
            light = false,
            sounds = { launch = 'whoosh', impact = 'impact' },
        },

        secousse = {
            order = 8,
            label = 'Secousse',
            summary = 'Fendre le sol sous les pieds de l\'adversaire, qui vacille et tombe.',
            element = 'terre',
            type = 'zone',
            icon = 'secousse',
            baseCost = 24,
            xp = 22,
            hitXp = 10,
            aim = { kind = 'point', shape = 'circle', radius = 'radius' },
            -- corps entier : un genou à terre, la main frappe le sol
            anims = {
                start = { dict = 'amb@world_human_gardener_plant@male@enter', clip = 'enter', flag = 0, ms = 700 },
                loop = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
                release = { dict = 'amb@world_human_gardener_plant@male@exit', clip = 'exit', flag = 0, ms = 900 },
            },
            ambientText = 'pose la main au sol, qui se met à gronder',
            levelScale = { 0.8, 0.9, 1.0, 1.15, 1.3 },
            -- reach (m) · radius (m) · delayMs (le sol se fend et gronde avant de frapper : le temps de fuir) ·
            -- damage (points de vie) · control (contrôle infligé : stagger ou knockdown) · controlMs
            levels = {
                {
                    castMs = 1200, cooldownMs = 14000, reach = 14.0, radius = 3.0, delayMs = 1400, damage = 4,
                    control = 'stagger', controlMs = 1200,
                    description = 'Le sol se fend sur trois mètres et, après un grondement, ébranle ceux qui s\'y tiennent.',
                    unlock = 'Vous savez faire trembler le sol.',
                },
                {
                    castMs = 1100, cooldownMs = 13000, reach = 15.0, radius = 3.5, delayMs = 1300, damage = 5,
                    control = 'stagger', controlMs = 1400,
                    description = 'Trois mètres et demi, et un grondement plus bref.',
                    unlock = 'Votre secousse s\'élargit et frappe plus vite.',
                },
                {
                    castMs = 1000, cooldownMs = 12000, reach = 16.0, radius = 4.0, delayMs = 1200, damage = 6,
                    control = 'stagger', controlMs = 1500,
                    description = 'Quatre mètres ; ceux qu\'elle ébranle chancellent plus longtemps.',
                    unlock = 'Votre secousse ébranle plus longtemps.',
                },
                {
                    castMs = 950, cooldownMs = 11000, reach = 18.0, radius = 4.5, delayMs = 1100, damage = 7,
                    control = 'knockdown', controlMs = 1500,
                    description = 'Le sol se dérobe : ceux qui s\'y tiennent sont renversés.',
                    unlock = 'Votre secousse renverse ceux qu\'elle frappe.',
                },
                {
                    castMs = 900, cooldownMs = 10000, reach = 20.0, radius = 5.0, delayMs = 1000, damage = 8,
                    control = 'knockdown', controlMs = 1800,
                    description = 'Cinq mètres de terre qui se soulève en une seconde à peine, et jette tout le monde au sol.',
                    unlock = 'Votre secousse atteint sa pleine violence.',
                },
            },
            heightMargin = 6.0,        -- écart de hauteur permis entre le lanceur et le point visé (m)
            broadcastRadius = 120.0,   -- joueurs qui voient le sol se soulever
            -- présage au sol (anneau qui se resserre, poussière) puis choc : éclats de roche, caméra qui tremble
            fx = {
                asset = 'core', dust = 'ent_dst_dust', burst = 'ent_dst_rocks', dustPoints = 6, burstPoints = 8,
                scale = 1.2, ring = 25, ringAlpha = 200, fillAlpha = 70,
                shake = { name = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.3, radii = 2.5 },
            },
            color = { r = 200, g = 156, b = 98 },
        },

        rempart = {
            order = 9,
            label = 'Rempart',
            summary = 'Faire surgir du sol un mur de pierre qui arrête les pas et les sorts.',
            element = 'terre',
            type = 'utilitaire',
            icon = 'rempart',
            baseCost = 28,
            xp = 25,
            hitXp = 0,
            -- face au lanceur, au point visé (aperçu au sol : sa longueur, sa largeur, ses deux bras au niveau 5)
            aim = { kind = 'point', shape = 'line', length = 'length', width = 'width', segments = 'segments', bend = 'bendDeg' },
            anims = {
                start = { dict = 'amb@world_human_gardener_plant@male@enter', clip = 'enter', flag = 0, ms = 700 },
                loop = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base', flag = 1 },
                release = { dict = 'anim@mp_player_intuppersurrender', clip = 'enter', flag = 0, ms = 700 },
            },
            ambientText = 'enfonce les mains dans la terre, qui se met à remuer',
            levelScale = { 1.0, 1.0, 1.0, 1.0, 1.0 },
            -- reach (m) · length (m d'un segment) · width (épaisseur, m) · height (m : ce qui passe au-dessus n'est pas
            -- arrêté) · pieces (blocs par segment) · segments (1, ou 2 : un chevron) · durationMs
            levels = {
                {
                    castMs = 1400, cooldownMs = 15000, reach = 10.0, length = 3.0, width = 1.2, height = 1.8, pieces = 2,
                    segments = 1, durationMs = 8000,
                    description = 'Un mur de pierre de trois mètres surgit du sol, huit secondes durant.',
                    unlock = 'Vous savez faire surgir un rempart.',
                },
                {
                    castMs = 1300, cooldownMs = 15000, reach = 11.0, length = 4.0, width = 1.2, height = 2.0, pieces = 3,
                    segments = 1, durationMs = 10000,
                    description = 'Quatre mètres de pierre, dix secondes.',
                    unlock = 'Votre rempart s\'allonge et tient plus longtemps.',
                },
                {
                    castMs = 1200, cooldownMs = 15000, reach = 12.0, length = 5.0, width = 1.3, height = 2.2, pieces = 3,
                    segments = 1, durationMs = 12000,
                    description = 'Cinq mètres, plus haut : il arrête aussi ce qu\'on jette par-dessus.',
                    unlock = 'Votre rempart s\'élève plus haut.',
                },
                {
                    castMs = 1100, cooldownMs = 15000, reach = 13.0, length = 6.0, width = 1.4, height = 2.4, pieces = 4,
                    segments = 1, durationMs = 14000,
                    description = 'Six mètres de muraille, quatorze secondes durant.',
                    unlock = 'Votre rempart barre six mètres.',
                },
                {
                    castMs = 1000, cooldownMs = 15000, reach = 14.0, length = 4.0, width = 1.4, height = 2.4, pieces = 3,
                    segments = 2, durationMs = 16000,
                    description = 'Deux pans de quatre mètres en chevron, qui couvrent aussi vos flancs, seize secondes durant.',
                    unlock = 'Votre rempart se dresse en deux pans qui couvrent vos flancs.',
                },
            },
            bendDeg = 25,              -- deux segments : chaque bras se rabat d'autant vers le lanceur
            model = 'prop_rock_4_c',   -- bloc de pierre de GTA (à vérifier en jeu : taille, assise)
            sink = 0.3,                -- blocs enfoncés d'autant dans le sol (terrain en pente)
            rise = { ms = 800, steps = 8, depth = 2.5 },  -- montée du sol (pas du serveur), et descente à la fin
            maxPerCaster = 1,          -- un nouveau rempart fait tomber le précédent
            maxPieces = 48,            -- blocs debout dans tout le royaume
            heightMargin = 4.0,        -- écart de hauteur permis entre le lanceur et le point visé (m)
            -- jamais sur un joueur ni sur un véhicule (marges autour de la ligne du mur, en mètres)
            placement = { playerMargin = 0.8, vehicleMargin = 2.5, heightMargin = 3.0 },
            broadcastRadius = 120.0,
            fx = {
                asset = 'core', dust = 'ent_dst_rocks', scale = 1.3,
                shake = { name = 'SMALL_EXPLOSION_SHAKE', amplitude = 0.12, radius = 15.0 },
            },
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
        warnIntervalMs = 3000, -- un frisson au plus par lanceur et par cible pendant ce délai (incantation acceptée)
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

    -- Zones au sol (mur de flammes, brume, sol mouillé, présage d'une secousse ; plus tard boue, vapeur), décidées
    -- par le serveur : forme, position, élément, fin. Le serveur vérifie toutes les `tickMs` qui s'y trouve (ou les a traversées) ; chaque
    -- zone n'est envoyée qu'aux joueurs à moins de `syncRadius`, y compris ceux qui s'en approchent après coup.
    zones = { tickMs = 500, syncRadius = 150.0, maxActive = 60 },

    -- Sol mouillé (laissé par la Vague et la Brume) : qui s'y tient est Mouillé, reposé au plus toutes les
    -- `refreshMs` sur un même joueur ; reflet d'eau au sol et gouttes à sa naissance.
    wetGround = {
        wetMs = 6000, refreshMs = 4000,
        render = { r = 70, g = 110, b = 150, alpha = 55, height = 0.03, groundOffset = 0.02 },
        fx = { asset = 'core', splash = 'ent_sht_water', points = 5, scale = 0.8 },
    },

    -- Combinaisons entre éléments, détectées et décidées par le serveur (server/combos.lua). Chacune :
    --   trigger : ce qui touche quoi. `spell` (un sort précis) ou `element` (tout sort de cet élément) ; `on` = 'zone'
    --     (le sort touche une zone au sol du genre `zone`) ou 'target' (il touche un joueur dans l'état `state`) ;
    --     `projectile` : seulement sur le trajet d'un projectile.
    --   result : `remove` (la zone touchée s'éteint), `zone` (une zone de ce genre naît à sa place : steam, mud),
    --     `state` (état posé sur la cible, soumis à l'immunité), `consume` (état retiré), `damageShare` (part des
    --     dégâts gardée), `noBurn` (pas de brûlure ce coup-ci), `carry` (le projectile emporte l'effet jusqu'à
    --     l'impact : dégâts bonus, brûlure, traînée de feu).
    --   label, notify (mot bref montré au lanceur), summary, triggerText, resultText : textes du grimoire, où la
    --     combinaison s'inscrit la première fois que le joueur la déclenche ; elements : icônes du grimoire.
    --   fx, sound : effet et son vus des joueurs proches (false : aucun).
    -- Ajouter une combinaison : une entrée ici suffit si son déclencheur et son résultat sont de ces sortes.
    combos = {
        vapeur = {
            order = 1, label = 'Vapeur', notify = 'Vapeur !', elements = { 'eau', 'feu' },
            summary = 'L\'eau jetée sur les flammes les étouffe en un nuage brûlant.',
            triggerText = 'Une vague ou un trait de glace touche un mur de flammes.',
            resultText = 'Le mur s\'éteint et laisse un nuage de vapeur qui cache la vue et brûle légèrement ceux qui s\'y tiennent.',
            trigger = { element = 'eau', on = 'zone', zone = 'flames' },
            result = { remove = true, zone = 'steam', element = 'eau', durationMs = 7000, damage = 1, tickMs = 1000, density = 0.6 },
            fx = { asset = 'core', name = 'ent_sht_steam', scale = 2.5, points = 6 }, sound = 'hiss',
            -- nappes de vapeur (voir `spells.brume.fx`) et flou à l'écran de qui s'y tient
            cloud = { asset = 'core', cloud = 'ent_sht_steam', spacing = 3.0, maxPoints = 10, reducedPoints = 4, scale = 1.8 },
            screen = { timecycle = 'hud_def_blur' },
        },
        dissipation = {
            order = 2, label = 'Dissipation', notify = 'Dissipée !', elements = { 'feu', 'eau' },
            summary = 'Le feu qui traverse la brume la chasse d\'un souffle.',
            triggerText = 'Une boule de feu traverse une brume.',
            resultText = 'La brume se dissipe aussitôt.',
            trigger = { element = 'feu', on = 'zone', zone = 'mist', projectile = true },
            result = { remove = true },
            fx = { asset = 'core', name = 'ent_sht_steam', scale = 1.5, points = 8 }, sound = 'whoosh',
        },
        boue = {
            order = 3, label = 'Boue', notify = 'Boue !', elements = { 'terre', 'eau' },
            summary = 'La terre remuée sous l\'eau devient un bourbier.',
            triggerText = 'Une secousse frappe un sol mouillé.',
            resultText = 'Une boue épaisse s\'étale et ralentit fortement ceux qui s\'y enfoncent, trente secondes durant.',
            trigger = { spell = 'secousse', on = 'zone', zone = 'wet' },
            -- Ralenti reposé au plus toutes les `refreshMs` sur qui s'y tient, sans trou : chaque pose dure `durationMs`
            -- + `refreshMs` − une vérification des zones ; à la sortie, il en reste de `durationMs` à `durationMs` +
            -- `refreshMs`, moins une vérification (1 à 3 s ici)
            result = { remove = true, zone = 'mud', element = 'terre', durationMs = 30000, slow = { strength = 0.6, durationMs = 1500, refreshMs = 2000 } },
            fx = { asset = 'core', name = 'ent_sht_water', scale = 1.2, points = 6 }, sound = 'splash',
            render = { r = 96, g = 66, b = 34, alpha = 150, height = 0.05, groundOffset = 0.02 },
        },
        gel = {
            order = 4, label = 'Gel', notify = 'Gelé !', elements = { 'eau', 'eau' },
            summary = 'La glace prend sur un corps trempé.',
            triggerText = 'Un trait de glace touche une cible mouillée.',
            resultText = 'La cible est gelée sur place (contrôle dur : elle en est protégée ensuite).',
            trigger = { spell = 'trait_de_glace', on = 'target', state = 'wet' },
            result = { state = 'frozen', durationMs = 2500, consume = 'wet' },
            fx = { asset = 'core', name = 'ent_sht_steam', scale = 1.0, points = 3 }, sound = 'shatter',
        },
        sechage = {
            order = 5, label = 'Séchage', notify = 'Séché !', elements = { 'feu', 'eau' },
            summary = 'Le feu s\'étouffe sur un corps trempé, qui en ressort sec.',
            triggerText = 'Un sort de feu touche une cible mouillée.',
            resultText = 'Les dégâts du feu sont réduits de moitié, la cible n\'est plus mouillée, et elle ne prend pas feu ce coup-ci.',
            trigger = { element = 'feu', on = 'target', state = 'wet' },
            result = { damageShare = 0.5, consume = 'wet', noBurn = true },
            fx = { asset = 'core', name = 'ent_sht_steam', scale = 1.2, points = 3 }, sound = 'hiss',
        },
        extinction = {
            order = 6, label = 'Extinction', notify = 'Éteint !', elements = { 'eau', 'feu' },
            summary = 'L\'eau noie les flammes qui mordaient encore.',
            triggerText = 'Un sort d\'eau touche une cible en brûlure.',
            resultText = 'La brûlure s\'éteint.',
            trigger = { element = 'eau', on = 'target', state = 'burn' },
            result = { consume = 'burn' },
            fx = { asset = 'core', name = 'ent_sht_steam', scale = 1.2, points = 3 }, sound = 'hiss',
        },
        roche_ardente = {
            order = 7, label = 'Roche ardente', notify = 'Roche ardente !', elements = { 'terre', 'feu' },
            summary = 'La pierre qui traverse les flammes s\'embrase et frappe comme un brandon.',
            triggerText = 'Un projectile de roche traverse un mur de flammes.',
            resultText = 'Le bloc enflammé inflige des dégâts de feu en plus et laisse sa cible en brûlure.',
            trigger = { spell = 'projectile_de_roche', on = 'zone', zone = 'flames', projectile = true },
            result = {
                carry = {
                    damage = 8, burn = { durationMs = 3000, tickMs = 1000, damage = 2 },
                    -- rendu du bloc enflammé, vu de tous (le client le prédit en vol, le serveur décide à l'impact)
                    asset = 'core', trail = 'ent_amb_torch_fire', trailScale = 0.8, impact = 'ent_sht_flame', impactScale = 1.2,
                    light = { r = 255, g = 140, b = 40, range = 5.0, intensity = 5.0 }, sound = 'whoosh',
                },
            },
            fx = false, sound = false,
        },
    },

    -- Combat entre joueurs. Dégâts des sorts en points de vie, sur `healthPoints` pour un personnage en pleine santé
    -- (un coup ne retire jamais plus d'une vie pleine). Chaque coup passe par la chaîne de dégâts de vava_health
    -- (exports.vava_health:hit) : son interrupteur `chain.pvp` et ses modificateurs (parades, boucliers, résistances)
    -- s'appliquent aux sorts comme aux lames. Sans vava_health, aucun sort ne blesse personne. Un projectile, ses
    -- éclats et le présage d'une Secousse lancés debout blessent encore si le lanceur tombe avant l'impact
    -- (vava_health ≥ 1.4.0 : `chain.launchedMaxMs`).
    combat = {
        -- false : les sorts offensifs se voient et se lancent, mais ne blessent ni ne poussent, gèlent ou ralentissent
        -- personne (filtre de la magie) ; `chain.pvp = false` de vava_health (≥ 1.4.0) fait de même
        pvp = true,
        healthPoints = 100,
        -- type de dégât de la chaîne pour chaque élément (vava_health `chain.kinds`) ; un élément absent frappe `pur`
        -- (ignoré des résistances). La glace (Trait de glace) est de l'eau ; une brûlure mord toujours par le feu.
        kinds = { feu = 'feu', eau = 'eau', terre = 'terre', lumiere = 'lumiere', esprit = 'esprit' },
        -- réaction de la cible touchée : geste bref (haut du corps) et effet d'écran, selon l'élément du sort (ou son
        -- champ `reaction`)
        reactions = {
            feu = { anim = { dict = 'anim@mp_player_intupperface_palm', clip = 'idle_a', flag = 48, ms = 700 }, screen = 'burn' },
            eau = { anim = { dict = 'anim@mp_player_intupperface_palm', clip = 'idle_a', flag = 48, ms = 600 }, screen = 'water' },
            glace = { anim = { dict = 'anim@mp_player_intupperface_palm', clip = 'idle_a', flag = 48, ms = 500 }, screen = 'frost' },
            terre = { anim = { dict = 'anim@mp_player_intupperface_palm', clip = 'idle_a', flag = 48, ms = 700 }, screen = 'earth' },
        },
        knockbackMs = 250,  -- durée de la poussée d'un recul
        -- zones de paix (cercle au sol, en mètres) : on n'y lance aucun sort offensif, personne n'y est blessé, ni
        -- par un sort ni par une lame, et personne n'en blesse un autre depuis l'intérieur (modificateur
        -- `vava_magic:zones` de la chaîne, déclaré s'il y en a une) :
        -- { label = 'Chapelle de la Grâce', x = 0.0, y = 0.0, radius = 40.0 },
        protectedZones = {},
        -- ancien journal des dégâts des sorts (`vava_magic_damage_log`) : plus écrit depuis 2.9.0 (les coups sont au
        -- journal de vava_health, `vava_health_hits`) ; ses lignes plus anciennes que `retentionDays` jours sont retirées
        -- au démarrage du module, puis une fois par jour (0 : jamais)
        log = { retentionDays = 30 },
    },

    -- Protections magiques, tenues par le serveur et portées par la chaîne de dégâts de vava_health : un bouclier
    -- absorbe les coups (sorts et lames) jusqu'à sa réserve (modificateur `vava_magic:protections`, étape bouclier) ;
    -- une résistance retire une part des dégâts d'un type, une faiblesse en ajoute une (`vava_magic:resistances`,
    -- étape resistance ; la plus forte de chaque sens l'emporte, jamais cumulées). Aucun des onze sorts n'en pose
    -- encore (sorts de protection à venir) ; le Conseil en pose pour l'essai (`/magie proteger`).
    protections = {
        maxShields = 4,              -- boucliers en cours sur un même joueur (au-delà : refusé)
        maxResistances = 4,          -- résistances et faiblesses en cours sur un même joueur
        maxPoints = 200,             -- réserve d'un bouclier, en points de vie (deux vies pleines)
        defaultDurationMs = 60000,   -- durée d'une protection posée sans durée
        maxDurationMs = 600000,      -- durée la plus longue (10 min)
        kinds = { 'feu', 'eau', 'terre', 'lumiere', 'esprit' }, -- types auxquels on peut résister (vava_health `chain.kinds`)
        ignoredKinds = { privation = true }, -- ni bouclier ni zone de paix contre la faim et la soif
        -- noms des modificateurs (console, journal des coups, /chaine de l'exemple de combat ; 48 octets au plus)
        labels = { zones = 'Zones de paix (magie)', shields = 'Boucliers de la magie', resistances = 'Résistances de la magie' },
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
        refusedMs = 60000,     -- après un refus, délai avant de tendre de nouveau son sigil au même joueur
        retries = 5,           -- tirages d'un sigil libre
        scramble = { cost = 60, cooldownMs = 21600000 }, -- brouiller (mage connaissant le sort) : 6 h de recharge
    },

    -- Registre des murmures (objet) : l'historique suit l'objet ; il est en base sous le numéro du registre.
    -- Il s'envoie par lots, les pages les plus récentes d'abord : à l'ouverture le premier lot, puis un lot de plus
    -- chaque fois que le lecteur feuillette vers les plus anciennes (le serveur revérifie qu'il porte le registre).
    registers = {
        maxPages = 200,
        contactMax = 160,
        pageSize = 20,     -- pages par lot (au plus)
        -- poids d'un lot (octets, estimé : correspondant + texte + 52 par page) ; un lot s'arrête avant de le
        -- dépasser (au moins une page) : reste sous 8 Ko (seuil de T-013, taille réelle à mesurer en jeu)
        pageBytes = 7500,
    },

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
            sheet = 'fiche', give = 'donner', cleanup = 'nettoyer', protect = 'proteger',
        },
        -- `/magie proteger [id] bouclier <points> [secondes]` · `resistance <type> <pour cent> [secondes]` (négatif :
        -- faiblesse) · `aucune`
        protectWords = { shield = 'bouclier', resistance = 'resistance', none = 'aucune' },
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
        registerPages = { capacity = 5, refillPerSecond = 1 },
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
            armed = 'Il vous faut les mains libres pour incanter : rangez votre arme.',
            shielded = 'Votre bouclier vous charge le bras : décrochez-le pour incanter.',
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
            no_launch = 'Ce projectile n\'existe plus.',
            no_lock_target = 'Aucune cible en vue.',
            staggered = 'Vous chancelez : impossible d\'incanter.',
            knocked = 'Vous êtes renversé : impossible d\'incanter.',
            frozen = 'Le gel vous fige : impossible d\'incanter.',
            no_point = 'Visez le sol, à portée.',
            zone_limit = 'Trop de sortilèges marquent déjà le sol du royaume.',
            blocked_spot = 'Quelqu\'un ou quelque chose occupe cet endroit : la pierre ne peut s\'y dresser.',
            rampart_limit = 'Trop de remparts se dressent déjà dans le royaume.',
            invalid_target = 'Votre cible vous échappe.',
            invalid_impact = 'Impact refusé.',
            nobody_near = 'Personne ne se tient assez près de vous.',
            offer_pending = 'Un sigil attend déjà une réponse.',
            offer_refused = 'Cette personne vient de refuser votre sigil : attendez %d s avant de le lui tendre à nouveau.',
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
            comboDiscovered = 'Une combinaison s\'inscrit dans votre grimoire : %s.',
            -- sans vava_health : le lanceur le sait, au plus une fois par minute
            noHarm = 'Votre magie gronde sans mordre : en ce moment, nul ne peut en être blessé.',
            shieldBroken = 'Votre bouclier de magie se brise.',
            protected = 'Une protection magique vous enveloppe.',
            unprotected = 'Vos protections magiques se dissipent.',
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
            adminUsage = 'Usage : /magie <action> [id] … — mage [id] <oui|non> · apprendre [id] <sort> · oublier [id] <sort> · niveau [id] <sort> <1-5> · xp [id] <sort> <xp> · tous [id] · maitrise [id] · vider [id] · mana [id] · recharges [id] · fiche [id] · donner [id] <grimoire|registre> · proteger [id] <bouclier <points> [s] | resistance <type> <pour cent> [s] | aucune> · nettoyer',
            adminForbidden = 'Ces commandes sont réservées au Conseil.',
            adminNoTarget = 'Aucun personnage en jeu sous ce numéro.',
            adminUnknownSpell = 'Sort inconnu. Sorts : %s',
            adminDone = 'C\'est fait.',
            adminCleaned = 'Nettoyé : %d effet(s) retiré(s) du monde.',
            -- échec d'une commande : texte par code (le code brut ne va qu'à la console du serveur)
            adminFailed = 'La commande n\'a pas abouti.',
            adminErrors = {
                not_mage = 'Ce personnage n\'est pas mage.',
                db_error = 'Les archives ne répondent pas : réessayez plus tard.',
                no_space = 'Sa besace n\'a plus la place.',
                too_heavy = 'Sa besace est trop lourde.',
                no_character = 'Aucun personnage en jeu sous ce numéro.',
                inventory_unavailable = 'L\'inventaire ne répond pas.',
                not_ready = 'L\'inventaire n\'est pas encore prêt.',
                unknown_item = 'L\'inventaire ne connaît pas cet objet.',
                too_many = 'Ce personnage porte déjà autant de protections qu\'il se peut.',
                -- /magie proteger : rangs du Registre
                outranked = 'Ce personnage siège au Conseil à votre rang ou au-dessus : ses protections ne vous regardent pas.',
                staff_only = 'Vous protéger vous-même ou affaiblir autrui est réservé au Souverain.',
            },
            sheetTitle = 'Fiche magie de %s (joueur n° %d)',
            sheetMage = 'Mage : %s · sort choisi : %s',
            sheetSpell = '— %s : niveau %d (%d XP)',
            sheetNoSpell = '— aucun sort',
            sheetSigils = 'Sigils gardés : %d · mana : %d / %d',
            sheetCombos = 'Combinaisons découvertes : %d / %d',
            sheetProtections = 'Protections : %d bouclier(s), %s points · %d résistance(s) ou faiblesse(s)',
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
            admin = { help = 'Magie (Conseil)', params = { { name = 'action', help = 'mage, apprendre, oublier, niveau, xp, tous, maitrise, vider, mana, recharges, fiche, donner, proteger, nettoyer' }, { name = 'id', help = 'facultatif : numéro du joueur (sinon vous)' } } },
        },
        -- journal du Registre du Conseil (32 signes au plus)
        logs = {
            mage = 'Magie : mage', learn = 'Magie : sort appris', forget = 'Magie : sort retiré', level = 'Magie : niveau de sort',
            xp = 'Magie : XP de sort', all = 'Magie : tous les sorts', master = 'Magie : maîtrise de tout',
            clear = 'Magie : sorts retirés', mana = 'Magie : mana remplie', cooldowns = 'Magie : recharges effacées',
            sheet = 'Magie : fiche consultée', give = 'Magie : objet donné', cleanup = 'Magie : nettoyage du monde',
            protect = 'Magie : protection',
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
            -- barre de mana et sort prêt ; `combo` : mot bref d'une combinaison réussie (le texte vient de `combos`)
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
                -- page des combinaisons : seules les découvertes s'y lisent
                combos = 'Combinaisons', comboTrigger = 'Déclencheur', comboResult = 'Résultat', comboElements = 'Éléments : %s',
                combosHidden = '%d combinaison(s) restent à découvrir.',
                combosNone = 'Aucune combinaison découverte : mêlez les éléments, et ces pages s\'écriront d\'elles-mêmes.',
            },
            register = {
                title = 'Registre des murmures', empty = 'Ce registre est vierge.', sent = 'À %s', received = 'De %s',
                unknown = 'D\'une présence inconnue',
                tear = 'Arracher la page', count = '%d / %d pages', close = 'Fermer',
                more = 'tourner les pages plus anciennes', loading = 'Les pages tournent…',
                months = { 'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre' },
                date = 'Le %d %s, à %dh%s',
            },
        },
    },
}
