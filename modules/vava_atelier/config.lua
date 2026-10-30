--[[
    vava_atelier/config.lua
    Rôle : configuration de l'Atelier du Conseil (lue par le client et le serveur) : familles de l'accueil et leur
           droit plancher, cartes « Bientôt », droits, touche et commande, bornes, journal, débits, textes vus par les
           membres du Conseil.
    Dépendances : shared/constants.lua
]]

VavaAtelier.config = {
    -- core.net.sendPacked et registre core:commands (T-101 aura besoin de core.zones, même version).
    coreVersion = '0.11.0',
    -- vava_admin (exports can, rankOf, log) : relu à chaque appel ; sans lui, l'Atelier refuse de s'ouvrir.
    adminVersion = '1.8.0',

    -- Touche par défaut, réglable par le joueur (Paramètres › Raccourcis › FiveM), et commande du chat.
    keys = { open = 'F9' },
    labels = { open = 'Ouvrir l\'Atelier du Conseil' },
    command = 'atelier',

    -- Familles de l'accueil, dans l'ordre. `floor` : droit minimal d'un atelier de la famille (un Sénéchal ne voit
    -- que le monde ; la société et les arts sont au Souverain, sauf surcharge dans `rights.overrides`).
    families = {
        { id = 'monde', label = 'Le monde', floor = 'metiers' },
        { id = 'societe', label = 'La société', floor = 'staff' },
        { id = 'arts', label = 'Les arts', floor = 'staff' },
    },

    rights = {
        -- Droits du Registre qu'un éditeur peut demander, du plus faible au plus fort (un rang qui a le second a
        -- toujours le premier) ; tout autre droit est refusé à la déclaration.
        allowed = { 'metiers', 'staff' },
        -- Droit pour ouvrir l'Atelier (le plus faible de `allowed`).
        open = 'metiers',
        -- Choix du porteur du projet : `['<éditeur>'] = 'metiers' | 'staff'`, prime sur le droit déclaré et le plancher.
        overrides = {},
    },

    -- Cartes montrées tant que leur éditeur n'est pas déclaré (« Bientôt »), dans l'ordre de chaque famille. Une carte
    -- devient l'atelier réel dès qu'un éditeur de même identifiant est déclaré. Identifiants indicatifs : la tâche qui
    -- crée l'éditeur reprend celui-ci ou corrige la ligne.
    upcoming = {
        { id = 'vava_gathering:zones', family = 'monde', label = 'Récolte', icon = 'recolte',
            description = 'Forêts, mines, prairies et coins de pêche, arbres et filons un par un.' },
        { id = 'vava_farming:parcelles', family = 'monde', label = 'Agriculture', icon = 'agriculture',
            description = 'Parcelles communales ou privées, puits, greniers et composteurs.' },
        { id = 'vava_crafting:stations', family = 'monde', label = 'Artisanat', icon = 'artisanat',
            description = 'Forges, établis, métiers à tisser : où ils sont, ce qu\'on peut y faire.' },
        { id = 'vava_doors:portes', family = 'monde', label = 'Portes et clés', icon = 'porte',
            description = 'Viser une porte, la déclarer, la verrouiller, créer ses clés.' },
        { id = 'vava_guilds:confreries', family = 'societe', label = 'Confréries', icon = 'confrerie',
            description = 'La Garde, les Guérisseurs, les guildes : grades, droits, coffres, lieux.' },
        { id = 'vava_housing:logis', family = 'societe', label = 'Logis', icon = 'logis',
            description = 'Maisons et chambres attribuées par le Conseil, coffres privés.' },
        { id = 'vava_emotes:gestes', family = 'arts', label = 'Gestes', icon = 'geste',
            description = 'Animations et accessoires pour les émotes et les métiers.' },
        { id = 'vava_combat:techniques', family = 'arts', label = 'Techniques de combat', icon = 'combat',
            description = 'Coups, parades, esquives : animation, timing et zone touchée.' },
        { id = 'vava_magic:effets', family = 'arts', label = 'Effets', icon = 'effet',
            description = 'Particules, lumières et sons réutilisables partout.' },
        { id = 'vava_magic:sorts', family = 'arts', label = 'Sorts', icon = 'sort',
            description = 'Assembler un sort : type, valeurs, geste et effets.' },
    },

    limits = {
        editors = 32,            -- éditeurs au plus dans le registre
        indexEntries = 1000,     -- entrées gardées d'un `index` de module (au-delà : tronqué, avertissement console)
        pageSize = 50,           -- lignes d'une page de liste
        optionsPage = 30,        -- valeurs proposées par page (select à source, item, model)
        optionsMax = 500,        -- valeurs gardées d'une source de module
        searchHits = 20,         -- résultats d'une recherche
        cacheMs = 5000,          -- durée de vie d'un `index` ou d'une source lus chez un module
        slowCallbackMs = 50,     -- fonction d'un éditeur signalée en console au-delà
        refusalLogMs = 60000,    -- une ligne de refus (droit) en console au plus par joueur et par intervalle
        descriptorBytes = 32768, -- descripteur d'un atelier (codage canonique) : au-delà, atelier refusé au chargement
        busyMs = 10000,          -- verrou d'une lecture tenu au-delà (appel resté en suspens) : repris, ligne en console
    },

    journal = {
        retentionDays = 365,                         -- lignes plus anciennes retirées au démarrage
        homeLines = 5,                               -- lignes du journal sur l'accueil
        pageLines = 25,                              -- lignes d'une page du journal entier
        flood = { lines = 60, windowMs = 10000 },    -- écritures au plus par ressource appelante et par fenêtre
        mirror = true,                               -- recopie de chaque ligne au journal du Registre
    },

    rateLimits = {
        home = { capacity = 4, refillPerSecond = 0.5 },     -- ouverture et retour à l'accueil
        editor = { capacity = 6, refillPerSecond = 1 },     -- descripteur d'un atelier
        read = { capacity = 12, refillPerSecond = 3 },      -- liste, fiche, journal
        check = { capacity = 5, refillPerSecond = 1 },      -- « Vérifier »
        lookup = { capacity = 10, refillPerSecond = 3 },    -- valeurs proposées, recherche
        close = { capacity = 5, refillPerSecond = 1 },      -- fermeture
    },

    -- Textes vus par les membres (l'interface a les siens : web/js/strings.js).
    texts = {
        title = 'L\'Atelier du Conseil',
        subtitle = 'Créez et modifiez le royaume en jeu, sans redémarrer le serveur. Chaque changement est inscrit au journal.',
        footnote = 'Chaque atelier n\'apparaît qu\'aux rangs qui y ont droit. Un Sénéchal ne voit que le monde ; un Souverain voit tout.',
        noDrafts = 'Aucun brouillon en cours.',
        checkHint = 'Vérifier contrôle les réglages sans rien changer au royaume.',
        checkOk = 'Tout est en ordre.',
        check = 'Vérifier',
        stateLive = 'En vigueur',
        stateNew = 'Rien d\'enregistré',
        searchWorkshop = 'Atelier',
        modeLine = 'Mode édition : visible par vous seul',      -- bandeau du volet (message `mode`)
        -- description de /atelier dans le Codex (registre core:commands)
        codex = 'Créer et régler le royaume en jeu, sans redémarrer : zones, stations, parcelles… selon votre rang.',
        console = 'Console',
        revoked = 'Votre place au Conseil a changé : l\'Atelier se ferme.',
        editorGone = 'Cet atelier vient d\'être retiré : réessayez plus tard.',
        -- refus d'un RPC (codes du § 6.2 de la spec), montrés hors de l'interface quand elle ne peut pas s'ouvrir
        refused = {
            not_ready = 'Le Registre du Conseil s\'éveille : réessayez dans un instant.',
            no_character = 'Choisissez d\'abord un personnage.',
            not_allowed = 'L\'Atelier est réservé au Conseil.',
            not_open = 'L\'Atelier s\'est refermé : rouvrez-le.',
            unknown_editor = 'Cet atelier n\'existe plus.',
            unknown_kind = 'Ce genre de fiche n\'existe plus dans cet atelier.',
            unknown_entry = 'Cette fiche n\'existe plus.',
            unknown_field = 'Ce réglage n\'existe pas dans cette fiche.',
            busy = 'Un instant : la demande précédente n\'est pas finie.',
            editor_error = 'Cet atelier ne répond pas : prévenez un développeur.',
            db_error = 'Le journal ne répond pas pour le moment.',
            rate_limited = 'Doucement : patientez un instant.',
            unavailable = 'L\'Atelier est indisponible pour le moment.',
        },
        -- erreurs d'un champ (« Vérifier ») ; %s : valeurs mises en forme par le serveur (virgule, unité, durée)
        fields = {
            required = 'À remplir.',
            range = 'Entre %s et %s.',
            step = 'Par pas de %s.',
            integer = 'Un nombre entier est attendu.',
            number = 'Un nombre est attendu.',
            choice = 'Ce choix n\'est pas proposé.',
            length = 'Entre %d et %d caractères.',
            lines = '%d lignes au plus.',
            spaces = 'Jamais deux espaces de suite.',
            control = 'Un caractère invisible s\'est glissé : retirez-le.',
            charset = {
                name = 'Lettres, chiffres, espaces, apostrophes, traits d\'union, virgules et points seulement.',
                id = 'Minuscules sans accent, chiffres et traits bas (_) seulement.',
                free = 'Les signes « < » et « > » ne sont pas permis.',
            },
            item = 'Cet objet n\'existe pas dans le royaume.',
            itemCategory = 'Cet objet n\'est pas de la sorte demandée.',
            itemUnavailable = 'La liste des objets du royaume ne répond pas : impossible de vérifier cet objet.',
            model = 'Ce modèle n\'est pas proposé.',
            type = 'Valeur d\'une autre nature que celle attendue.',
        },
        -- début d'une ligne du journal : verbe, puis article et nom du type (« A publié la station »)
        verbs = {
            created = 'A créé', saved = 'A enregistré le brouillon de', trial = 'A mis à l\'essai',
            published = 'A publié', archived = 'A archivé', restored = 'A restauré', removed = 'A retiré',
            imported = 'A rétabli l\'original de', placed = 'A placé', moved = 'A déplacé', note = 'A annoté',
        },
        -- libellés de la recopie au journal du Registre (32 caractères au plus, bornes de vava_admin)
        mirror = {
            created = 'Atelier : créé', saved = 'Atelier : brouillon', trial = 'Atelier : mis à l\'essai',
            published = 'Atelier : publié', archived = 'Atelier : archivé', restored = 'Atelier : restauré',
            removed = 'Atelier : retiré', imported = 'Atelier : original rétabli', placed = 'Atelier : placé',
            moved = 'Atelier : déplacé', note = 'Atelier : annoté',
        },
    },
}
