--[[
    vava_crafting/config_client.lua
    Rôle : réglages de l'artisanat que lit le client : longueur d'un nom de chef-d'œuvre, durée du geste de réparation,
           distance d'interaction et annulation au mouvement, streaming des props, touche, types de stations (props,
           animation, libellés), animations. Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste
           (paliers, qualité, poinçons, garde, réparation, durées, tolérances du serveur, droits, débits, outils,
           stations placées, objets, recettes, textes) est dans config.lua, servi au seul serveur (T-132).
    Les modèles de props sont des EXEMPLES : à remplacer par les props du royaume.
    Dépendances : shared/constants.lua
]]

VavaCrafting.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.6.0)

    -- Chef-d'œuvre : longueur d'un nom de baptême (en lettres), montrée et contrôlée par la boîte du client avant
    -- l'envoi ; le serveur la revérifie. Le palier, la fenêtre et les lettres admises sont dans config.lua.
    masterpiece = {
        nameMin = 2, nameMax = 32,
    },

    -- Réparation : durée du geste. La part des ingrédients, la solidité perdue, le niveau requis et l'XP sont dans
    -- config.lua.
    repair = { durationMs = 4000 },

    -- Distance d'interaction (mètres) et déplacement qui annule un geste en cours. Les tolérances du serveur sont dans
    -- config.lua (interact.serverTolerance, expireMs, expireMarginMs, finishToleranceMs).
    interact = {
        distance = 2.5,
        moveCancel = 1.5,
    },

    -- Client : props des stations créés à portée (`radius`, mètres). Les stations sont groupées par case de `groupCell`
    -- mètres : seules celles d'une case à portée sont mesurées. Un passage toutes les `pollMs` près d'une case, toutes
    -- les `idlePollMs` quand aucune station ne peut être à moins de `radius` + `idleMargin` (la marge couvre le chemin
    -- d'un cavalier rapide pendant `idlePollMs`, pour que les props apparaissent comme avant). La zone de chaque
    -- station et son battement d'abonnement (`zoneRadius`, `subscribeSlack`) sont dans config.lua.
    streaming = {
        radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, groupCell = 200.0, modelTimeoutMs = 5000,
    },

    keys = { interact = 'E' },
    labels = { interact = 'Utiliser une station d\'artisanat' },

    -- Types de stations : compétences servies, combustible éventuel (objet, unités par pièce, réserve), animation.
    -- Entiers ici : le client les lit par type (prop, animation).
    stationTypes = {
        forge = { label = 'Forge', skills = { 'forge' }, fuel = { item = 'charbon', perCraft = 1, capacity = 20 }, anim = 'hammer', prop = 'prop_tool_bench02' },
        etabli = { label = 'Établi', skills = { 'menuiserie' }, anim = 'hammer', prop = 'prop_tool_bench02_ld' },
        metier_a_tisser = { label = 'Métier à tisser', skills = { 'tissage' }, anim = 'sew', prop = 'prop_table_03' },
        alambic = { label = 'Alambic', skills = { 'alchimie' }, anim = 'brew', prop = 'prop_table_04' },
        tannerie = { label = 'Tannerie', skills = { 'tannerie' }, anim = 'tan', prop = 'prop_rub_table_01' },
        fourneau = { label = 'Fourneau', skills = { 'cuisine' }, fuel = { item = 'bois_pin', perCraft = 1, capacity = 20 }, anim = 'cook', prop = 'prop_bbq_3' },
        table_arcanes = { label = 'Table d\'arcanes', skills = { 'arcanes' }, anim = 'study', prop = 'prop_table_08' },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        hammer = { scenario = 'WORLD_HUMAN_HAMMERING' },
        sew = { scenario = 'WORLD_HUMAN_SEAT_WALL' },
        brew = { scenario = 'WORLD_HUMAN_STAND_MOBILE' },
        tan = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        cook = { scenario = 'PROP_HUMAN_BBQ' },
        study = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    },
}
