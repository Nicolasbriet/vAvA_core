--[[
    vava_codex/config.lua
    Rôle : configuration du Codex (lue par le client et le serveur) : touche et commande d'ouverture, signets et
           dernières pages, commandes non décrites montrées au Conseil, droits sans vava_admin, pages de lecture
           (1.5.0 : interrupteur, textes des erreurs du format, commande de console), débits, textes. Le texte des
           pages n'est pas ici (fichier partagé avec le client) : il vit dans content/*.lua, côté serveur.
    Dépendances : shared/constants.lua
]]

VavaCodex.config = {
    coreVersion = '0.7.0',

    -- Touche par défaut, réglable par le joueur (Paramètres > Raccourcis > FiveM), et commande du chat.
    keys = { open = 'F1' },
    labels = { open = 'Ouvrir le Codex (commandes et touches)' },
    command = 'codex',

    -- Préférences par personnage : signets (favoris) et dernières pages (commandes lancées, du Codex ou du chat).
    favorites = { max = 24 },
    recent = { max = 12 },

    -- Commandes enregistrées auprès du jeu mais absentes du registre : montrées au Conseil seulement, pour les
    -- ressources dont le nom répond à `resources`, sauf celles qui répondent à `hidden` (touches +/−, internes).
    undeclared = { enabled = true, resources = { '^vava', '^vAvA' }, hidden = { '^[%+%-]', '^_' } },

    -- Sans vava_admin : qui est du Conseil (permission ACE). Avec lui : ses rangs et ses droits.
    staff = { ace = 'vava_codex.staff' },

    -- Arguments « joueur » (dont /mp) : hors du Conseil, seuls les joueurs proches sont proposés, à portée de voix
    -- (mètres ; positions lues par le serveur, même instance). Défaut : la portée « Parler » de vava_voice (5 m), à
    -- ajuster ici si elle change. Le Conseil a la liste complète ; un numéro tapé à la main reste permis.
    players = { nearbyRadius = 5.0 },

    -- Après « Lancer » : rester ouvert, sauf réglage contraire du joueur ; une commande qui ouvre une interface
    -- (`ui = true` dans sa déclaration) ferme toujours le Codex d'abord.
    keepOpenDefault = true,

    -- Codex « en panneau » (1.6.0) : seule ressource qui peut ouvrir le livre dans un rectangle de son écran, sans voile
    -- (exports client openDocked et closeDocked) ; la bannière du royaume (vava_pause) l'ouvre à droite de ses rubriques.
    docked = { host = 'vava_pause' },

    -- Pages de lecture (1.5.0) : onglet « Lecture » du livre. Le texte vit dans content/*.lua, côté serveur seulement ;
    -- les bornes du format sont en tête de shared/pages.lua (serveur seul). `false` : ni onglet, ni index envoyé, et le RPC
    -- `page` répond `disabled` ; le reste du Codex est inchangé.
    reading = {
        enabled = true,
        -- texte de chaque code d'erreur du format (console du serveur au chargement ; l'Atelier plus tard)
        errors = {
            bad_utf8 = 'texte illisible (UTF-8 invalide)',
            bad_char = 'caractère interdit (« < », « > » hors d\'une note, ou caractère de contrôle)',
            too_long = 'texte trop long',
            empty_body = 'page vide',
            bad_heading = 'intertitre mal formé : « ## », une espace, puis le texte, sans jeton',
            bad_token = 'jeton mal formé (voir le format : [[F1]], [[touche:…]], [[commande:…]], [[page:…]])',
            too_many_tokens = 'trop de jetons dans la page',
            too_many_blocks = 'trop de paragraphes, listes ou notes',
            too_many_items = 'liste trop longue',
            too_long_block = 'paragraphe, élément de liste ou intertitre trop long',
            too_large = 'page trop lourde pour un envoi',
            bad_link = 'lien vers une page absente, ou réservée au Conseil depuis une page publique',
            bad_id = 'identifiant invalide (minuscules, chiffres, « _ », 32 au plus, jamais « vava… »)',
            id_taken = 'identifiant déjà pris (page ou chapitre)',
            unknown_field = 'champ inconnu',
            bad_chapter = 'chapitre inconnu',
            bad_order = 'rang invalide (entier de 0 à 999)',
            bad_title = 'titre invalide',
            bad_summary = 'résumé invalide',
            bad_label = 'nom de chapitre invalide',
            bad_audience = 'public invalide',
            bad_permission = 'droit invalide',
            bad_requires = 'module invalide',
            too_many_pages = 'trop de pages',
            too_many_chapters = 'trop de chapitres',
        },
    },

    -- Commande de la console du serveur : bilan des pages (poids, public, touches et commandes citées introuvables).
    pagesCommand = 'vava_codex_pages',

    rateLimits = {
        open = { capacity = 3, refillPerSecond = 0.5 },
        options = { capacity = 10, refillPerSecond = 3 },
        prefs = { capacity = 10, refillPerSecond = 2 },   -- signets, dernières pages, réglage
        -- six pages d'affilée, puis une par seconde ; une page lue reste gardée par la page
        page = { capacity = 6, refillPerSecond = 1 },
    },

    messages = {
        unavailable = 'Le Codex est indisponible pour le moment.',
        unknown = 'Cette commande n\'est pas dans le Codex.',
        refused = 'Cette commande ne vous est pas ouverte.',
        consoleOnly = 'Cette commande ne se lance que depuis la console du serveur.',
        favoritesFull = 'Vous avez déjà %d signets : retirez-en un.',
        -- console du serveur (pages de lecture)
        pages = {
            loaded = 'pages de lecture : %d chargées, %d refusées',
            refused = 'page « %s » refusée : %s (ligne %d)',          -- ligne 0 : hors du corps
            chapterRefused = 'chapitre « %s » refusé : %s',
            line = '%s (%s) : %d octets, %s',                        -- id, chapitre, poids réseau, public
            missing = 'page « %s » : %s introuvable au registre (%s)', -- id, touche ou commande, module requis
            noSeed = 'pages de lecture : aucune graine (content/chapters.lua absent du manifeste ?), aucune page',
            failed = 'pages de lecture : erreur au chargement, aucune page (%s)',
        },
    },
}
