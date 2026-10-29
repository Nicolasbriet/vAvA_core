--[[
    vava_time/config.lua
    Rôle : toute la donnée de jeu du temps (lue par le client et le serveur) : heure du royaume, calendrier et saisons,
           ciels (seul endroit où paraissent les noms de météo de GTA) et leur cycle, Conseil, outil du Registre,
           commandes, débits, textes. Modifiable sans toucher au code. Durées en millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua
]]

VavaTime.config = {
    coreVersion = '0.7.0',          -- registre des commandes core:commands

    -- Heure du royaume : l'heure de Paris (heure d'été comprise, calculée depuis l'heure UTC du serveur : la machine
    -- n'a pas besoin d'être réglée sur Paris), au rythme réel. Le Conseil peut la décaler, la figer, puis la rendre.
    clock = {
        maxShiftMinutes = 720,      -- décalage permis : ± 12 h
        msPerGameMinute = 60000,    -- une minute du jeu dure une minute réelle
    },

    -- Calendrier. `real` : saisons aux dates de `starts` (heure de Paris), dans l'ordre de l'année du royaume (la
    -- première ouvre l'année) ; `cycle` : chaque saison dure `cycle.seasonDays` jours réels (décimaux permis, pour les
    -- essais), à partir de minuit (Paris) du jour `cycle.origin`, en commençant par `cycle.first`.
    calendar = {
        mode = 'real',
        firstYear = 2026,           -- l'an 1 du royaume commence au premier printemps de cette année
        starts = {
            { season = 'printemps', month = 3, day = 20 },
            { season = 'ete', month = 6, day = 21 },
            { season = 'automne', month = 9, day = 22 },
            { season = 'hiver', month = 12, day = 21 },
        },
        cycle = { seasonDays = 7, origin = { year = 2026, month = 10, day = 26 }, first = 'automne' },
        seasons = {
            printemps = { label = 'printemps', name = 'saison des semailles' },
            ete = { label = 'été', name = 'saison des moissons' },
            automne = { label = 'automne', name = 'saison des brumes' },
            hiver = { label = 'hiver', name = 'saison des frimas' },
        },
        -- Moments du jour (heure de début), pour les textes.
        moments = {
            { from = 0, label = 'la nuit' },
            { from = 5, label = 'l\'aube' },
            { from = 8, label = 'le matin' },
            { from = 12, label = 'midi' },
            { from = 14, label = 'l\'après-midi' },
            { from = 18, label = 'le soir' },
            { from = 22, label = 'la nuit' },
        },
    },

    -- Ciels. `gta` : nom de météo du jeu ; `phrase` : ce qu'en dit /date ; `snow` : neige (le cycle n'en tire qu'en
    -- hiver, et jamais si `snow = false`) ; `tracks` : traces de pas et de roues dans la neige au sol. L'ordre est celui
    -- des interfaces.
    weather = {
        types = {
            { id = 'clair', gta = 'CLEAR', label = 'Ciel clair', phrase = 'le ciel est clair' },
            { id = 'soleil', gta = 'EXTRASUNNY', label = 'Grand soleil', phrase = 'le soleil cogne' },
            { id = 'nuages', gta = 'CLOUDS', label = 'Nuages épars', phrase = 'quelques nuages passent' },
            { id = 'couvert', gta = 'OVERCAST', label = 'Ciel couvert', phrase = 'le ciel est couvert' },
            { id = 'eclaircies', gta = 'CLEARING', label = 'Éclaircies', phrase = 'le ciel s\'éclaircit' },
            { id = 'pluie', gta = 'RAIN', label = 'Pluie', phrase = 'il pleut' },
            { id = 'orage', gta = 'THUNDER', label = 'Orage', phrase = 'l\'orage gronde' },
            { id = 'brume', gta = 'SMOG', label = 'Brume de chaleur', phrase = 'une brume de chaleur flotte' },
            { id = 'brouillard', gta = 'FOGGY', label = 'Brouillard', phrase = 'le brouillard est tombé' },
            { id = 'neige_legere', gta = 'SNOWLIGHT', label = 'Neige légère', phrase = 'quelques flocons tombent', snow = true },
            { id = 'neige', gta = 'SNOW', label = 'Neige', phrase = 'il neige', snow = true },
            { id = 'tempete', gta = 'BLIZZARD', label = 'Tempête de neige', phrase = 'la tempête de neige fait rage', snow = true },
            { id = 'neige_au_sol', gta = 'XMAS', label = 'Neige au sol', phrase = 'la neige couvre le sol', snow = true, tracks = true },
        },
        -- Ciels qui peuvent suivre chacun (le même compris : il dure alors une durée de plus). Si aucun n'est de saison,
        -- le cycle tire parmi tous les ciels de la saison.
        next = {
            clair = { 'clair', 'soleil', 'nuages', 'brume', 'brouillard' },
            soleil = { 'soleil', 'clair', 'nuages', 'brume' },
            nuages = { 'nuages', 'clair', 'couvert', 'eclaircies', 'brouillard' },
            couvert = { 'couvert', 'nuages', 'pluie', 'brouillard', 'neige_legere' },
            eclaircies = { 'eclaircies', 'clair', 'nuages' },
            pluie = { 'pluie', 'couvert', 'orage', 'eclaircies' },
            orage = { 'pluie', 'eclaircies', 'couvert' },
            brume = { 'brume', 'clair', 'nuages' },
            brouillard = { 'brouillard', 'nuages', 'clair', 'couvert' },
            neige_legere = { 'neige_legere', 'neige', 'couvert', 'nuages' },
            neige = { 'neige', 'neige_legere', 'tempete', 'couvert' },
            tempete = { 'neige', 'neige_legere' },
            neige_au_sol = { 'neige_au_sol', 'neige_legere', 'couvert' },
        },
        -- Poids de chaque ciel par saison ; absent ou 0 : jamais tiré par le cycle dans cette saison.
        seasons = {
            printemps = { clair = 3, soleil = 1, nuages = 3, couvert = 2, eclaircies = 2, pluie = 3, orage = 1, brouillard = 1 },
            ete = { clair = 4, soleil = 4, nuages = 2, couvert = 1, eclaircies = 1, pluie = 1, orage = 1, brume = 1 },
            automne = { clair = 2, nuages = 3, couvert = 3, eclaircies = 1, pluie = 3, orage = 1, brouillard = 2, brume = 1 },
            hiver = { clair = 2, nuages = 2, couvert = 3, pluie = 1, brouillard = 2, neige_legere = 2, neige = 1, tempete = 0.3 },
        },
        snow = true,
        durationMinutes = { 25, 50 },                       -- durée d'un ciel, tirée dans la fourchette
        durations = { orage = { 10, 20 }, tempete = { 10, 20 } },
        fadeSeconds = 90,                                   -- transition d'un ciel à l'autre (cycle)
    },

    -- Conseil : droit vava_admin de l'outil, de /ciel et des actions faites depuis la Chancellerie (la lecture y
    -- demande `view`, vérifié par le pont) ; transition d'un ciel imposé (s).
    council = { permission = 'tools', fadeSeconds = 20 },
    tool = {
        label = 'Ciel et heure',
        hint = 'Heure du royaume, saison et météo : décaler ou figer l\'heure, imposer un ciel, rendre la main.',
    },
    commands = { date = 'date', council = 'ciel' },

    -- Chancellerie (panneau web) : seule ressource admise aux exports web*.
    web = { bridge = 'vava_chancellerie' },

    server = { tickMs = 15000 },    -- boucle lente : fin d'un ciel, changement de jour ou de saison
    client = {
        resyncMs = 60000,           -- horloge recalée localement (aucun réseau)
        epochResyncMs = 1800000,    -- heure du serveur redemandée
        retryMs = { 2000, 5000, 10000, 30000 },  -- première demande : module serveur pas encore prêt
        refreshMs = 2000,           -- outil ouvert : vue redemandée au plus une fois par intervalle
    },

    rateLimits = {
        sync = { capacity = 6, refillPerSecond = 0.1 },
        open = { capacity = 5, refillPerSecond = 1 },
        clock = { capacity = 6, refillPerSecond = 0.5 },
        weather = { capacity = 6, refillPerSecond = 0.5 },
    },

    messages = {
        -- /date : heure, jour de la saison, nom et libellé de la saison, an, moment du jour, ce que fait le ciel
        date = 'Il est %s, le %s jour de la %s (%s), an %d du royaume. C\'est %s : %s.',
        hour = '%d h %02d',
        frozen = 'Le temps s\'est arrêté sur le royaume.',
        notReady = 'Le ciel du royaume n\'est pas encore connu : réessayez dans un instant.',
        -- réponses du Conseil (client) ; %s : heure, ciel
        clockSet = 'Heure du royaume : %s.',
        clockFrozen = 'L\'heure est figée à %s.',
        clockResumed = 'Le temps reprend son cours (%s).',
        clockReal = 'Le royaume retrouve l\'heure réelle (%s).',
        weatherImposed = 'Le ciel obéit : %s.',
        weatherFrozen = 'Le ciel est figé : %s.',
        weatherReleased = 'Le ciel est rendu à son cours.',
        usage = '/ciel [heure <h> <min> | decaler <heures> | figer | reprendre | reelle | meteo <ciel> [figer] | garder | cycle]',
        errors = {
            forbidden = 'Ce pouvoir revient au Conseil.',
            invalid_value = 'Valeur refusée.',
            unknown_weather = 'Ce ciel n\'existe pas.',
            not_ready = 'Le ciel du royaume n\'est pas encore prêt.',
            rate_limited = 'Doucement : le ciel ne change pas si vite.',
        },
        -- journal du Registre (32 octets au plus)
        log = {
            set = 'Heure du royaume réglée',
            shift = 'Heure du royaume décalée',
            freeze = 'Heure du royaume figée',
            resume = 'Heure du royaume reprise',
            real = 'Heure réelle rendue',
            impose = 'Ciel imposé',
            weatherFreeze = 'Ciel figé',
            release = 'Ciel rendu au cycle',
        },
        yes = 'oui',
        no = 'non',
    },
}
