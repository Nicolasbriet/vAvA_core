--[[
    vava_time/config_client.lua
    Rôle : donnée de jeu du temps que lit le client (le serveur la lit aussi) : rythme de l'horloge, calendrier et
           saisons, ciels (seul endroit où paraissent les noms de météo de GTA), commandes, réglages du client, textes.
           Téléchargé par chaque joueur. `calendar`, `weather.types` et `messages` y sont entiers : le client les
           passe à shared/calendar.lua et shared/weather.lua. Ce que lit le seul serveur (décalage permis, cours des
           ciels, nuits de gel, Conseil, outil du Registre, pont du web, boucle, débits) est dans config.lua, servi au
           seul serveur (T-132). Durées en millisecondes sauf mention contraire.
    Dépendances : shared/constants.lua
]]

VavaTime.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.4.0)

    -- Heure du royaume : l'heure de Paris (heure d'été comprise, calculée depuis l'heure UTC du serveur : la machine
    -- n'a pas besoin d'être réglée sur Paris), au rythme réel. Le Conseil peut la décaler (borne : config.lua), la
    -- figer, puis la rendre.
    clock = {
        msPerGameMinute = 60000,    -- une minute du jeu dure une minute réelle
    },

    -- Calendrier. L'heure reste toujours l'heure réelle ; seules les saisons vont plus vite.
    -- `cycle` (par défaut) : chaque saison dure `cycle.seasonDays` jours réels (14 : une année du royaume dure huit
    -- semaines ; décimaux permis pour les essais), à partir de minuit (heure de Paris) du jour fixe `cycle.origin`, en
    -- commençant par `cycle.first` ; l'an change à chaque nouveau printemps. Avant l'origine : premier jour du cycle.
    -- `real` : saisons aux dates de `starts` du vrai calendrier (heure de Paris), l'an 1 commençant au premier printemps
    -- de `firstYear`. Dans les deux modes, `starts` donne l'ordre des saisons (la première ouvre l'année).
    calendar = {
        mode = 'cycle',
        cycle = { seasonDays = 14, origin = { year = 2026, month = 10, day = 26 }, first = 'printemps' },
        firstYear = 2026,
        starts = {
            { season = 'printemps', month = 3, day = 20 },
            { season = 'ete', month = 6, day = 21 },
            { season = 'automne', month = 9, day = 22 },
            { season = 'hiver', month = 12, day = 21 },
        },
        seasons = {
            printemps = { label = 'printemps', name = 'saison des semailles' },
            ete = { label = 'été', name = 'saison des moissons' },
            automne = { label = 'automne', name = 'saison des brumes' },
            hiver = { label = 'hiver', name = 'saison des frimas' },
        },
        -- Moments du jour (heure de début), pour les textes.
        moments = {
            { from = 0, label = 'la nuit' },
            { from = 6, label = 'l\'aube' },
            { from = 8, label = 'le matin' },
            { from = 12, label = 'midi' },
            { from = 14, label = 'l\'après-midi' },
            { from = 18, label = 'le soir' },
            { from = 22, label = 'la nuit' },
        },
    },

    -- Ciels. `gta` : nom de météo du jeu ; `phrase` : ce qu'en dit /date ; `snow` : neige (cours des ciels :
    -- config.lua) ; `tracks` : traces de pas et de roues dans la neige au sol. L'ordre est celui des interfaces.
    weather = {
        types = {
            { id = 'clair', gta = 'CLEAR', label = 'Ciel clair', phrase = 'le ciel est clair' },
            { id = 'soleil', gta = 'EXTRASUNNY', label = 'Grand soleil', phrase = 'le soleil brille sans un nuage' },
            { id = 'nuages', gta = 'CLOUDS', label = 'Nuages épars', phrase = 'quelques nuages passent' },
            { id = 'couvert', gta = 'OVERCAST', label = 'Ciel couvert', phrase = 'le ciel est couvert' },
            { id = 'eclaircies', gta = 'CLEARING', label = 'Éclaircies', phrase = 'le ciel s\'éclaircit' },
            { id = 'pluie', gta = 'RAIN', label = 'Pluie', phrase = 'il pleut' },
            { id = 'orage', gta = 'THUNDER', label = 'Orage', phrase = 'l\'orage gronde' },
            { id = 'brume', gta = 'SMOG', label = 'Brume', phrase = 'une brume pâle voile le ciel' },
            { id = 'brouillard', gta = 'FOGGY', label = 'Brouillard', phrase = 'le brouillard est tombé' },
            { id = 'neige_legere', gta = 'SNOWLIGHT', label = 'Neige légère', phrase = 'quelques flocons tombent', snow = true },
            { id = 'neige', gta = 'SNOW', label = 'Neige', phrase = 'il neige', snow = true },
            { id = 'tempete', gta = 'BLIZZARD', label = 'Tempête de neige', phrase = 'la tempête de neige fait rage', snow = true },
            { id = 'neige_au_sol', gta = 'XMAS', label = 'Neige au sol', phrase = 'la neige couvre le sol', snow = true, tracks = true },
        },
    },
    -- Commandes : /date pour tous ; /ciel et ses sous-commandes (noms à taper) pour le Conseil. `holdWord` : second mot
    -- de « imposer » pour figer le ciel imposé.
    commands = {
        date = 'date',
        council = 'ciel',
        actions = {
            set = 'heure', shift = 'decaler', freeze = 'figer', resume = 'reprendre', real = 'reelle',
            impose = 'imposer', hold = 'garder', release = 'rendre',
        },
        holdWord = 'figer',
    },
    client = {
        resyncMs = 60000,           -- horloge recalée localement (aucun réseau)
        epochResyncMs = 1800000,    -- heure du serveur redemandée
        retryMs = { 2000, 5000, 10000, 30000 },  -- première demande : module serveur pas encore prêt
        refreshMs = 2000,           -- outil ouvert : vue redemandée au plus une fois par intervalle
    },

    messages = {
        -- l'ère du royaume (seul endroit où elle est écrite : /date, interfaces, Chancellerie)
        year = 'an %d du royaume',
        -- une date : jour de la saison (1er, 2e…), nom et libellé de la saison, an (`year`)
        dateText = '%s jour de la %s (%s), %s',
        -- /date : heure, date (`dateText`), moment du jour, ce que fait le ciel
        date = 'Il est %s, le %s. C\'est %s : %s.',
        hour = '%d h %02d',
        frozen = 'Les astres restent immobiles dans le ciel.',
        -- /date, les jours où une nuit de gel est annoncée (du tirage, au premier passage du jour, jusqu'au gel)
        frostTonight = 'La nuit sera froide.',
        notReady = 'Le ciel du royaume n\'est pas encore connu : réessayez dans un instant.',
        -- au changement de saison, chez chaque joueur en jeu (lu sur l'état partagé, aucun envoi de plus)
        seasonStart = {
            printemps = 'La saison des semailles commence : la terre se réveille, les rivières se repeuplent.',
            ete = 'La saison des moissons commence : la terre a soif.',
            automne = 'La saison des brumes commence : le gibier abonde, le temps des provisions est venu.',
            hiver = 'La saison des frimas commence : la terre dort, les herbes se font rares, les nuits gèlent.',
        },
        -- réponses du Conseil (client) ; %s : heure, ciel
        clockSet = 'Heure du royaume : %s.',
        clockFrozen = 'L\'heure est figée à %s.',
        clockResumed = 'Le temps reprend son cours (%s).',
        clockReal = 'Le royaume retrouve l\'heure réelle (%s).',
        weatherImposed = 'Le ciel obéit : %s.',
        weatherFrozen = 'Le ciel est figé : %s.',
        weatherReleased = 'Le ciel reprend son cours.',
        -- ligne d'usage de /ciel : commande, puis les sous-commandes de `commands.actions` dans l'ordre set, shift,
        -- freeze, resume, real, impose, holdWord, hold, release
        usage = '/%s [%s <h> <min> | %s <heures> | %s | %s | %s | %s <ciel> [%s] | %s | %s]',
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
            release = 'Ciel rendu à son cours',
        },
        yes = 'oui',
        no = 'non',
    },
}
