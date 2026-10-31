--[[
    vava_farming/config_client.lua
    Rôle : réglages de l'agriculture que lit le client : gestes (durée et animation), distance d'interaction et
           annulation au mouvement, streaming des props, touche, cultures (props par stade, libellés), puits,
           animations. Téléchargé par chaque joueur ; le serveur le lit aussi. Tout le reste (croissance, saisons, gel,
           fertilité, qualité, graines, seau, compost, outils, tolérances du serveur, droits, débits, objets, parcelles,
           composteur, textes) est dans config.lua, servi au seul serveur (T-132).
    Les puits et modèles de props sont des EXEMPLES autour du point d'apparition par défaut ; les durées de croissance
    (`crops`) sont courtes pour les essais (minutes) : à rallonger pour le royaume.
    Dépendances : shared/constants.lua
]]

VavaFarming.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.8.0)

    -- Gestes : durée du geste (le serveur applique à la fin) et animation. La faucille en main accélère la récolte.
    actions = {
        plant = { durationMs = 3000, anim = 'plant' },
        water = { durationMs = 2500, anim = 'water' },
        fertilize = { durationMs = 2500, anim = 'plant' },
        harvest = { durationMs = 4500, anim = 'harvest', sickleFactor = 0.6 },
        clear = { durationMs = 3000, anim = 'plant' },
        cover = { durationMs = 3000, anim = 'plant' },
    },

    -- Distance d'interaction (mètres) et déplacement qui annule un geste en cours. Les tolérances du serveur sont dans
    -- config.lua (interact.serverTolerance, expireMs, finishToleranceMs).
    interact = {
        distance = 2.0,
        moveCancel = 1.5,
    },

    -- Client : props des plantes, puits et greniers créés à portée (`radius`, mètres). Une parcelle et son grenier forment
    -- un groupe, les puits sont groupés par case de `groupCell` mètres : seules les cibles d'un groupe à portée sont
    -- mesurées. Un passage toutes les `pollMs` près d'un groupe, toutes les `idlePollMs` quand aucune cible ne peut être
    -- à moins de `radius` + `idleMargin` (la marge couvre le chemin d'un cavalier rapide pendant `idlePollMs`, pour que
    -- les props apparaissent comme avant). Le battement d'abonnement (`subscribeSlack`) est dans config.lua.
    streaming = { radius = 80.0, pollMs = 1000, idlePollMs = 2500, idleMargin = 60.0, groupCell = 200.0, modelTimeoutMs = 5000 },

    keys = { interact = 'E' },
    labels = { interact = 'Cultiver (emplacement, puits ou grenier proche)' },

    -- Cultures : graine → produit ; durée (minutes), eau consommée par heure (points d'humidité), coût de fertilité par
    -- récolte, famille (rotation), rendement, XP, difficulté, props par stade (du semis au mûr ; le dernier n'apparaît qu'à
    -- maturité), prop flétri, prop mort ; `frostHardy` : résiste aux nuits de gel (vava_time) sans être couverte.
    -- Entières ici : le client les lit par culture (props, libellé, nombre de stades).
    crops = {
        ble = { label = 'Blé', family = 'cereale', seed = 'graine_ble', product = 'ble', growMinutes = 90, waterPerHour = 20, fertilityCost = 15,
            yield = { 3, 6 }, xp = 14, difficulty = 15,
            stages = { 'prop_plant_01b', 'prop_veg_crop_01', 'prop_veg_crop_tr_01' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
        carotte = { label = 'Carotte', family = 'racine', seed = 'graine_carotte', product = 'carotte', growMinutes = 30, waterPerHour = 25, fertilityCost = 10,
            yield = { 2, 5 }, xp = 8, difficulty = 5,
            stages = { 'prop_plant_01b', 'prop_veg_crop_04_leaf' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
        chou = { label = 'Chou', family = 'feuille', seed = 'graine_chou', product = 'chou', growMinutes = 45, waterPerHour = 30, fertilityCost = 12,
            yield = { 1, 3 }, xp = 10, difficulty = 10,
            stages = { 'prop_plant_01b', 'prop_veg_crop_03_cab' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02',
            frostHardy = true },
        lin = { label = 'Lin', family = 'fibre', seed = 'graine_lin', product = 'lin', growMinutes = 60, waterPerHour = 15, fertilityCost = 20,
            yield = { 2, 4 }, xp = 12, difficulty = 20,
            stages = { 'prop_plant_01b', 'prop_veg_crop_05', 'prop_veg_crop_tr_02' }, wilted = 'prop_veg_crop_02', dead = 'prop_veg_crop_02' },
    },

    -- Puits : remplissent le seau tenu en main.
    wells = {
        { id = 'puits_bourg', label = 'Puits du bourg', x = -236.0, y = -897.0, z = 31.2, prop = 'prop_barrel_01a' },
    },

    -- Animations côté client : scénario du jeu, ou dictionnaire + animation en boucle.
    anims = {
        plant = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        water = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        harvest = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
        fill = { scenario = 'WORLD_HUMAN_GARDENER_PLANT' },
    },
}
