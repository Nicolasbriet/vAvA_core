--[[
    vava_atelier/config.lua
    Rôle : réglages de l'Atelier lus par le seul serveur (servi au seul serveur, jamais téléchargé par les joueurs) :
           familles de l'accueil et leur droit plancher, cartes « Bientôt », droits, bornes, journal, définitions
           gardées (fiches, brouillons, historique, essai, synchronisation, archives, lieux), débits, textes envoyés par
           le serveur. Complète la table ouverte par config_client.lua (touche, commande, textes affichés par le
           client) sans en réécrire une clé (T-132).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaAtelier.config

-- core.net.sendPacked, registre core:commands, core.db.transaction ; core.zones pour les modules (même version).
config.coreVersion = '0.11.0'
-- vava_admin (exports can, rankOf, log) : relu à chaque appel ; sans lui, l'Atelier refuse de s'ouvrir.
config.adminVersion = '1.8.0'

-- Familles de l'accueil, dans l'ordre. `floor` : droit minimal d'un atelier de la famille (un Sénéchal ne voit
-- que le monde ; la société et les arts sont au Souverain, sauf surcharge dans `rights.overrides`).
config.families = {
    { id = 'monde', label = 'Le monde', floor = 'metiers' },
    { id = 'societe', label = 'La société', floor = 'staff' },
    { id = 'arts', label = 'Les arts', floor = 'staff' },
}

config.rights = {
    -- Droits du Registre qu'un éditeur peut demander, du plus faible au plus fort (un rang qui a le second a
    -- toujours le premier) ; tout autre droit est refusé à la déclaration.
    allowed = { 'metiers', 'staff' },
    -- Droit pour ouvrir l'Atelier (le plus faible de `allowed`).
    open = 'metiers',
    -- Choix du porteur du projet : `['<éditeur>'] = 'metiers' | 'staff'`, prime sur le droit déclaré et le plancher.
    overrides = {},
}

-- Cartes montrées tant que leur éditeur n'est pas déclaré (« Bientôt »), dans l'ordre de chaque famille. Une carte
-- devient l'atelier réel dès qu'un éditeur de même identifiant est déclaré. Identifiants indicatifs : la tâche qui
-- crée l'éditeur reprend celui-ci ou corrige la ligne.
config.upcoming = {
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
}

config.limits = {
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
}

config.journal = {
    retentionDays = 365,                         -- lignes plus anciennes retirées au démarrage
    homeLines = 5,                               -- lignes du journal sur l'accueil
    pageLines = 25,                              -- lignes d'une page du journal entier
    flood = { lines = 60, windowMs = 10000 },    -- écritures au plus par ressource appelante et par fenêtre
    mirror = true,                               -- recopie de chaque ligne au journal du Registre
}

-- Définitions gardées (T-101) : poids et nombre de fiches.
config.definitions = {
    maxBytes = 16384,        -- poids au plus d'une fiche gardée (JSON de data + lieu) ; au-delà : too_large
    perKind = 1000,          -- fiches vivantes (publiées, ou brouillons jamais publiés) par type ; = limits.indexEntries
}
config.drafts = {
    perMember = 20,          -- brouillons tenus au plus par un membre, tous ateliers confondus
    homeLines = 5,           -- brouillons montrés sur l'accueil
}
config.history = {
    keep = 20,               -- versions figées gardées par fiche (la publiée et la dernière d'une fiche retirée toujours)
    pageLines = 20,          -- lignes d'une page d'historique
    purgeOnStart = true,     -- purge au démarrage, dans un fil (sans le retarder)
    purgeDelayMs = 60000,    -- attente de cette purge après editorsReady (les synchronisations des ateliers d'abord)
}
config.trial = {
    maxMinutes = 30,         -- durée au plus d'un essai ; ensuite il prend fin (« délai passé »)
    perMember = 1,           -- essais en cours au plus par membre
}
config.bundle = {
    maxChildren = 200,       -- fiches enfants au plus dans une publication groupée
}
config.sync = {
    sliceMs = 4,             -- travail au plus (ms) entre deux pauses d'un fil de synchronisation ou d'archives (serveur)
    retryMs = 10000,         -- nouvel essai d'une synchronisation en échec (registres muets)
    retries = 3,             -- essais au plus ; ensuite l'atelier reste « à synchroniser »
}
config.archives = {
    command = 'atelier_archives',
    folder = 'echanges',     -- dossier de la ressource (jamais dans `files` : rien n'est servi aux joueurs)
    maxBytes = 4194304,      -- fichier lu au plus (4 Mo)
    confirmMs = 60000,       -- délai pour « confirmer » une opération résumée
    cooldownMs = 2000,       -- délai entre deux commandes d'un membre
    exportCooldownMs = 60000, -- délai entre deux exports, tous membres confondus (fichiers sur le disque)
}
-- Lieux d'une fiche (formes du § 5.4 de la spec T-101), aux bornes de core.zones.
config.place = {
    maxXY = 50000.0,
    maxZ = 5000.0,
    maxRadius = 500.0,
    polygonPoints = { min = 3, max = 32 },
}

config.rateLimits = {
    home = { capacity = 4, refillPerSecond = 0.5 },     -- ouverture et retour à l'accueil
    editor = { capacity = 6, refillPerSecond = 1 },     -- descripteur d'un atelier
    read = { capacity = 12, refillPerSecond = 3 },      -- liste, fiche, journal
    check = { capacity = 5, refillPerSecond = 1 },      -- « Vérifier »
    lookup = { capacity = 10, refillPerSecond = 3 },    -- valeurs proposées, recherche
    close = { capacity = 5, refillPerSecond = 1 },      -- fermeture
    write = { capacity = 4, refillPerSecond = 0.5 },    -- enregistrer, essayer, arrêter, abandonner, retirer, reprendre
    preview = { capacity = 5, refillPerSecond = 1 },    -- résumé avant publication ou retour en arrière
    publish = { capacity = 2, refillPerSecond = 0.2 },  -- publier, revenir à une version
}

-- Textes vus par les membres (l'interface a les siens : web/js/strings.js), lus par le seul serveur. Ceux que lit le
-- client (refus, bandeaux du volet, fin d'essai, auteur des réponses au chat) sont dans config_client.lua (texts.*).
local texts = config.texts
texts.title = 'L\'Atelier du Conseil'
texts.subtitle = 'Créez et modifiez le royaume en jeu, sans redémarrer le serveur. Chaque changement est inscrit au journal.'
texts.footnote = 'Chaque atelier n\'apparaît qu\'aux rangs qui y ont droit. Un Sénéchal ne voit que le monde ; un Souverain voit tout.'
texts.noDrafts = 'Aucun brouillon en cours.'
texts.checkHint = 'Vérifier contrôle les réglages sans rien changer au royaume.'
texts.checkOk = 'Tout est en ordre.'
texts.check = 'Vérifier'
texts.stateLive = 'En vigueur'
texts.stateNew = 'Rien d\'enregistré'
texts.searchWorkshop = 'Atelier'
-- description de /atelier dans le Codex (registre core:commands)
texts.codex = 'Créer et régler le royaume en jeu, sans redémarrer : zones, stations, parcelles… selon votre rang.'
texts.console = 'Console'
texts.editorGone = 'Cet atelier vient d\'être retiré : réessayez plus tard.'
-- erreurs d'un champ (« Vérifier ») ; %s : valeurs mises en forme par le serveur (virgule, unité, durée)
texts.fields = {
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
}
-- début d'une ligne du journal : verbe, puis article et nom du type (« A publié la station »)
texts.verbs = {
    created = 'A créé', saved = 'A enregistré le brouillon de', trial = 'A mis à l\'essai',
    published = 'A publié', archived = 'A archivé', restored = 'A restauré', removed = 'A retiré',
    imported = 'A rétabli l\'original de', placed = 'A placé', moved = 'A déplacé', note = 'A annoté',
    discarded = 'A abandonné le brouillon de', taken = 'A repris le brouillon de',
    seeded = 'A posé les premières fiches de', refused = 'A tenté de publier',
    trial_ended = 'A fini l\'essai de', exported = 'A copié aux archives', received = 'A repris des archives',
}
-- libellés de la recopie au journal du Registre (32 caractères au plus, bornes de vava_admin)
texts.mirror = {
    created = 'Atelier : créé', saved = 'Atelier : brouillon', trial = 'Atelier : mis à l\'essai',
    published = 'Atelier : publié', archived = 'Atelier : archivé', restored = 'Atelier : restauré',
    removed = 'Atelier : retiré', imported = 'Atelier : original rétabli', placed = 'Atelier : placé',
    moved = 'Atelier : déplacé', note = 'Atelier : annoté',
    discarded = 'Atelier : brouillon abandonné', taken = 'Atelier : brouillon repris',
    seeded = 'Atelier : premières fiches', refused = 'Atelier : refusé en jeu',
    trial_ended = 'Atelier : fin d\'essai', exported = 'Atelier : copié aux archives',
    received = 'Atelier : repris des archives',
}
-- nom des lignes du journal qui portent sur un atelier entier (« A rétabli l'original de l'atelier Récolte »)
texts.workshop = 'atelier'

-- T-101 : fiches gardées. Étiquette d'état d'une fiche (`state` : { label, tone, line? }) ; %d : version.
texts.states = {
    draft = 'Brouillon', trial = 'Essai, version %d', live = 'Version %d, publiée',
    archived = 'Version %d, archivée', removal = 'Retrait en attente', refused = 'Publiée, mais refusée en jeu',
    holder = 'Brouillon de %s, enregistré %s',
    stale = 'Une autre version a été publiée depuis le début de ce brouillon.',
    unreadable = 'Version illisible par cet atelier.',
}
-- boutons du pied de fiche (essai et publication : ceux de l'éditeur, texts.trial et texts.publish)
texts.buttons = {
    save = 'Enregistrer le brouillon', endTrial = 'Arrêter l\'essai', history = 'Historique',
    discard = 'Abandonner le brouillon', retire = 'Retirer du royaume', take = 'Reprendre le brouillon',
    restore = 'Revenir à cette version', publishRemoval = 'Publier le retrait',
    discardRemoval = 'Renoncer au retrait', check = 'Vérifier',
}
-- indice d'une ligne de liste (60 octets au plus) ; %s : nom du tenant, âge
texts.hints = {
    mine = 'Votre brouillon', other = 'Brouillon de %s', trial = 'En essai', removal = 'Retrait en attente',
    new = 'Votre brouillon, jamais publié', refused = 'Publiée, mais refusée en jeu',
    retired = { masculine = 'retiré %s', feminine = 'retirée %s' },
}
-- ligne d'un brouillon sur l'accueil (« Vos brouillons ») ; %s : newLabel, résumé, nom du type
texts.drafts = {
    new = { masculine = '%s, pas encore publié', feminine = '%s, pas encore publiée' },
    changes = { one = '%s, pas encore publié', many = '%s, pas encore publiés' },
    unchanged = 'Rien de changé, pas encore publié',
    trial = {
        masculine = '%s en essai, vous seul le voyez en jeu', feminine = '%s en essai, vous seul la voyez en jeu',
    },
    removal = 'Retrait %s, pas encore publié',
}
-- résumés d'un changement (shared/changes.lua) ; accords : `e` (féminin) et `s` (pluriel) ajoutés au participe
texts.changes = {
    added = 'ajouté', removed = 'retiré', changed = 'changé',
    setting = 'réglage', settingPlural = 'réglages',
    settings = '%d réglages changés', settingsList = '%d réglages changés : %s', retouched = 'Retouché : %s',
    fromTo = '%s de %s à %s', choice = '%s : %s', yes = 'oui', no = 'non',
    versionNext = 'La version %d sera archivée ; celle-ci deviendra la version %d.',
    first = 'Ce sera la version 1.',
    restoreFrom = 'La version %d sera rétablie et deviendra la version %d.',
    removal = 'Retrait %s', removalChildren = 'et de ses %d %s', removedWith = 'et ses %d %s',
    titled = '%s : %s',
}
-- résumés des lignes du journal, avertissements des résumés
-- compteurs accordés : %d avec `one` pour 0 et 1, `many` au-delà (shared/changes.lua › count)
texts.counts = {
    fiches = { one = '%d fiche', many = '%d fiches' },
    changed = { one = '%d fiche changée', many = '%d fiches changées' },
    revived = { one = '%d rétablie', many = '%d rétablies' },
    new = { one = '%d nouvelle', many = '%d nouvelles' },
    same = { one = '%d identique à l\'original', many = '%d identiques à l\'original' },
    taken = { one = '%d fiche reprise', many = '%d fiches reprises' },
    unchanged = { one = '%d inchangée', many = '%d inchangées' },
    toTake = { one = '%d à reprendre', many = '%d à reprendre' },
    published = { one = '%d publiée', many = '%d publiées' },
    drafts = { one = '%d brouillon', many = '%d brouillons' },
    trials = { one = '%d en essai', many = '%d en essai' },
    retired = { one = '%d retirée', many = '%d retirées' },
    refusedInGame = { one = '%d refusée en jeu', many = '%d refusées en jeu' },
    seeded = { one = '%d fiche reprise de l\'original', many = '%d fiches reprises de l\'original' },
    otherRefusals = { one = '… et %d autre refus.', many = '… et %d autres refus.' },
}
texts.summaries = {
    removalPrepared = 'retrait préparé',
    restored = 'version %d rétablie',
    restoredInto = 'version %d rétablie, devenue la version %d',
    takenFrom = 'de %s',
    reimported = '%s, %s, %s',          -- counts.changed, revived, new
    exported = '%s, %s',                -- nom du fichier, counts.fiches
    received = '%s, %s',                -- counts.taken, unchanged
    reset = 'Des réglages ont repris leur valeur de départ : %s.',
    otherDrafts = 'Des brouillons d\'autres membres sur des fiches liées ne sont pas compris.',
    child = '%s « %s » : %s',
}
texts.invalid = 'Quelques réglages sont à corriger avant de continuer.'
texts.warningsSaved = 'Brouillon enregistré. À corriger avant de publier :'
texts.tagTrial = '%d en essai'              -- étiquette d'une carte de l'accueil pendant un essai
-- raison de la fin d'un essai (résumé de la ligne du journal) ; %s : qui l'a repris
texts.trialReasons = {
    session = 'fin de la séance', dropped = 'départ', timeout = 'délai passé', taken = 'repris par %s',
    editor = 'atelier retiré', stop = 'arrêté', publish = 'publié', discard = 'abandonné',
}
-- réponses de /atelier_archives (§ 10.4 de la spec T-101), dans le chat du membre ou la console
texts.archives = {
    usage = 'usage : /%s etat [atelier] | original <atelier> | original_fiche <atelier> <type> <fiche> | '
        .. 'exporter <atelier|tout> | importer <fichier> | confirmer',
    codex = 'État des ateliers, retour à l\'original, archives : copier et reprendre les fiches publiées.',
    -- libellés du Codex (registre core:commands)
    labels = {
        command = 'Archives de l\'Atelier', etat = 'État des ateliers',
        original = 'Rétablir l\'original d\'un atelier', original_fiche = 'Rétablir l\'original d\'une fiche',
        exporter = 'Copier aux archives', importer = 'Reprendre des archives',
        confirmer = 'Confirmer l\'opération résumée', exporterHint = 'un atelier, ou « tout »',
        importerHint = 'nom du fichier (.json)',
    },
    denied = 'Refusé : réservé au Souverain.',
    deniedEditor = 'Refusé : cet atelier ne vous est pas ouvert.',
    notReady = 'Le Registre du Conseil s\'éveille : réessayez dans un instant.',
    cooldown = 'Doucement : patientez un instant.',
    unknownEditor = 'Atelier inconnu, ou qui ne garde rien : %s.',
    unknownKind = 'Genre de fiche inconnu dans cet atelier : %s.',
    unknownEntry = 'Fiche absente de l\'original : %s.',
    state = '%s : %s, %s, %s, %s%s',    -- counts.published, drafts, trials, retired
    stateSyncing = ', en mise à jour', stateFailed = ', pas à jour en jeu', stateRefused = ', %s',
    nothing = 'Aucun atelier ne garde de fiches.',
    originalPlan = '%s : %s, %s, %s, %s.',   -- counts.changed, revived, new, same
    -- ce qui arrivera à une fiche quand rien de ses réglages ne change (retour à l'original d'une fiche)
    actions = { new = 'nouvelle', changed = 'changée', revived = 'rétablie' },
    originalSame = 'Identique à l\'original : rien à faire.',
    entryPlan = '%s « %s » : %s',
    refusedPlan = '%s : refusé — %s',
    confirmHint = 'Tapez /%s confirmer sous %d s pour l\'appliquer.',
    noPending = 'Rien à confirmer.',
    expired = 'Le délai est passé : relancez la commande.',
    changed = 'Les fiches ont changé depuis le résumé : relancez la commande.',
    done = '%s : fait (%s).',
    failed = '%s : rien n\'a changé (%s).',
    exported = 'Archives écrites : %s (%s).',
    exportFailed = 'Archives non écrites : %s.',
    exportTooLarge = 'plus de %d Mo, que l\'import refuserait : copiez les ateliers un par un',
    exportCooldown = 'Une copie aux archives vient d\'être faite : réessayez dans %d s.',
    running = 'La commande précédente n\'est pas finie : patientez un instant.',
    unwritable = 'fichier illisible à l\'écriture',
    upgradeRefused = 'données d\'une forme plus ancienne que cet atelier ne sait plus lire',
    tooManyEditors = 'plus de %d ateliers dans le fichier',
    tooManyEntries = 'plus de %d fiches pour un même genre',
    badName = 'Nom de fichier refusé : lettres, chiffres, _ et - seulement, terminé par .json (64 octets au '
        .. 'plus).',
    unreadableFile = 'Fichier illisible : %s.',
    badValue = 'valeur refusée pour « %s » (hors des bornes ou choix inconnu)',
    importPlan = '%s : %s, %s',      -- counts.toTake, unchanged
    busy = 'L\'atelier %s se met à jour : réessayez dans un instant.',
    dbError = 'Les registres de l\'Atelier ne répondent pas : réessayez dans un instant.',
}
