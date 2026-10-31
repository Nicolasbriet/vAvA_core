--[[
    vava_atelier/config_client.lua
    Rôle : réglages de l'Atelier que lit le client : touche, commande, outil de placement (T-102 : portée, visée,
           fantômes, pas de la molette, couleurs, contrôles, barre des touches, textes de l'aperçu et des refus, relus
           par le serveur), textes affichés hors de la page (refus, bandeaux
           du volet, fin d'essai, auteur des réponses au chat). Téléchargé par chaque joueur ; le serveur le lit aussi.
           Tout le reste est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaAtelier.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.2.0)

    -- Touche par défaut, réglable par le joueur (Paramètres › Raccourcis › FiveM), et commande du chat.
    keys = { open = 'F9' },
    labels = { open = 'Ouvrir l\'Atelier du Conseil' },
    command = 'atelier',

    -- Textes affichés par le client hors de la page (l'interface a les siens : web/js/strings.js) ; le serveur lit
    -- aussi les refus. Les autres textes sont dans config.lua (texts.*).
    texts = {
        modeLine = 'Mode édition : visible par vous seul',      -- bandeau du volet (message `mode`)
        revoked = 'Votre place au Conseil a changé : l\'Atelier se ferme.',
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
            db_error = 'Les registres de l\'Atelier ne répondent pas : réessayez dans un instant.',
            rate_limited = 'Doucement : patientez un instant.',
            unavailable = 'L\'Atelier est indisponible pour le moment.',
            stale = 'Cette fiche a changé depuis que vous l\'avez ouverte : rouvrez-la pour voir la dernière version.',
            draft_taken = 'Un autre membre du Conseil tient déjà un brouillon de cette fiche : ouvrez-le pour le lire '
                .. 'ou le reprendre.',
            draft_open = 'Vous avez déjà un brouillon de cette fiche : abandonnez-le d\'abord.',
            not_holder = 'Ce brouillon est tenu par un autre membre du Conseil.',
            no_draft = 'Cette fiche n\'a pas de brouillon en cours.',
            not_stored = 'Cet atelier ne garde encore rien : on peut seulement y vérifier une fiche.',
            too_large = 'Cette fiche est trop lourde pour être gardée : raccourcissez ses textes.',
            full = 'Trop de fiches ou de brouillons : publiez ou abandonnez-en d\'abord.',
            parent_missing = 'Cette fiche dépend d\'une autre qui n\'est pas publiée : publiez-la ou rétablissez-la '
                .. 'd\'abord.',
            trial_busy = 'Vous avez déjà un essai en cours : arrêtez-le d\'abord.',
            no_trial = 'Cet atelier ne propose pas d\'essai.',
            syncing = 'L\'atelier se met à jour : réessayez dans un instant.',
            unknown_version = 'Cette version n\'existe plus.',
            not_archived = 'Seule une ancienne version peut être rétablie.',
            unchanged = 'Rien n\'a changé depuis la version publiée.',
            unreadable = 'Cette version ne peut plus être lue par cet atelier.',
            -- T-102 (outil de placement)
            not_placeable = 'Cette fiche ne se place pas en jeu.',
            instance = 'Vous êtes dans une instance : revenez dans le royaume pour placer.',
            bad_request = 'Demande mal formée.',
        },
        -- bandeau du volet pendant un essai, si l'éditeur n'a pas de texts.trialLine
        trialLineDefault = 'Mode essai : vous seul voyez ce changement en jeu',
        trialEndedFeed = 'L\'essai de « %s » a pris fin.',
        -- nom des réponses de /atelier_archives dans le chat du membre (ancien texts.archives.author)
        sayAuthor = 'Atelier',
    },

    -- T-102 : outil de placement (client/placer.lua). Le serveur relit `reach`, `polygonFactor` et `texts` : il
    -- revérifie chaque pose avec les mêmes règles (shared/placerules.lua) et rend les mêmes textes.
    placement = {
        reach = 60.0,                -- distance au plus (m, 3D) entre le personnage et le lieu posé (centre, point)
        polygonFactor = 2.0,         -- un sommet de tracé peut être à reach × polygonFactor (au sol)
        -- visée depuis la caméra : longueur (m) et drapeaux du lancer de rayon (1 sol + 16 objets)
        aim = { distance = 80.0, flags = 17 },
        labels = { distance = 40.0, max = 12 },   -- étiquettes : les 12 plus proches à moins de 40 m
        -- fantômes des enfants pas encore publiés (et du candidat) : objets locaux, jamais réseau
        ghosts = { distance = 60.0, max = 12, alpha = 160, loadTimeoutMs = 3000 },
        -- un cran de molette ; Maj tenue : pas fin
        steps = { heading = 15.0, headingFine = 1.0, radius = 5.0, radiusFine = 0.5 },
        pickRadius = 2.5,            -- clic droit : élément de la fiche le plus proche du point visé, à 2,5 m au plus
        undoMax = 20,                -- gestes annulables par Ctrl+Z dans une visée
        refreshMs = 100,             -- règles réévaluées au plus toutes les 100 ms (ou dès que le candidat bouge)
        sortMs = 500,                -- tri des éléments proches (étiquettes, fantômes)
        quitConfirmMs = 2000,        -- tracé commencé : un second Échap dans ce délai l'abandonne
        -- teintes (maquette Recolte : vert #7fc46a, rouge #e8a48f, laiton #dcc08a)
        colors = {
            valid = { 127, 196, 106 }, refused = { 232, 164, 143 }, area = { 220, 192, 138 },
            child = { 244, 232, 204 }, picked = { 214, 224, 230 },
        },
        ringAlpha = 70,              -- opacité des anneaux (cylindre de 1,5 m de haut)
        markers = { area = 1, point = 2, vertex = 1 },   -- types de DrawMarker (cylindre, chevron)
        -- contrôles lus (indépendants de la disposition du clavier)
        controls = { place = 24, pick = 25, wheelUp = 15, wheelDown = 14, fine = 21, ctrl = 36, quit = 200, close = 191 },
        -- contrôles neutralisés pendant la visée (tir, visée, roue des armes, course, accroupi, couverture, mêlée, pause)
        disabled = { 24, 25, 14, 15, 16, 17, 37, 21, 36, 44, 140, 141, 142, 199, 200, 257, 263 },
        -- Z en commande-touche (suit la disposition du clavier), avec Ctrl ; déclarée au registre core:commands
        undoKey = { command = 'vava_atelier_annuler', key = 'Z', label = 'Atelier : annuler le dernier placement (avec Ctrl)' },
        -- barre des touches par mode (maquette Recolte)
        keybar = {
            children = {
                { keys = 'Clic', label = 'Poser ici' }, { keys = 'Molette', label = 'Tourner' },
                { keys = 'Maj', label = 'Placement précis' }, { keys = 'Clic droit', label = 'Choisir un point' },
                { keys = 'Ctrl Z', label = 'Annuler' }, { keys = 'Échap', label = 'Quitter' },
            },
            picked = {
                { keys = 'Clic', label = 'Déplacer ici' }, { keys = 'Molette', label = 'Tourner' },
                { keys = 'Maj', label = 'Placement précis' }, { keys = 'Clic droit', label = 'Lâcher le point' },
                { keys = 'Ctrl Z', label = 'Annuler' }, { keys = 'Échap', label = 'Quitter' },
            },
            circle = {
                { keys = 'Clic', label = 'Poser ici' }, { keys = 'Molette', label = 'Rayon' },
                { keys = 'Maj', label = 'Réglage fin' }, { keys = 'Ctrl Z', label = 'Annuler' },
                { keys = 'Échap', label = 'Quitter' },
            },
            point = {
                { keys = 'Clic', label = 'Poser ici' }, { keys = 'Ctrl Z', label = 'Annuler' },
                { keys = 'Échap', label = 'Quitter' },
            },
            oriented = {
                { keys = 'Clic', label = 'Poser ici' }, { keys = 'Molette', label = 'Tourner' },
                { keys = 'Maj', label = 'Placement précis' }, { keys = 'Ctrl Z', label = 'Annuler' },
                { keys = 'Échap', label = 'Quitter' },
            },
            polygon = {
                { keys = 'Clic', label = 'Ajouter un sommet' }, { keys = 'Entrée', label = 'Fermer le tracé' },
                { keys = 'Clic droit', label = 'Choisir un sommet' }, { keys = 'Ctrl Z', label = 'Retirer le dernier' },
                { keys = 'Échap', label = 'Quitter' },
            },
        },
        -- textes de l'aperçu et des refus (le serveur rend les mêmes)
        texts = {
            valid = '%s, emplacement valide',
            refused = '%s : %s',
            area = '%s, rayon %s m',
            far = 'Trop loin de vous : approchez-vous (%d m).',
            ground = 'Visez le sol.',
            inside = 'Hors de %s.',
            spacing = 'Trop près de « %s » (%s m).',
            radius = 'Rayon de %d à %d m.',
            vertices = 'De %d à %d sommets.',
            crossing = 'Le tracé se croise.',
            busy = 'Un instant…',
            undoNone = 'Rien à annuler.',
            undoFailed = 'Impossible d\'annuler : la fiche a changé.',
            picked = '%s : cliquez pour le déplacer',
            trace = 'Tracé : %d sommets (Entrée pour fermer)',
            quitTrace = 'Échap encore pour abandonner le tracé.',
            vehicle = 'Descendez de votre monture pour placer.',
            suspended = 'Mode essai : vous seul voyez ces points · %s : revenir à l\'Atelier',
            editLine = 'Mode édition : les cercles et étiquettes ne sont visibles que par vous',
            new = 'nouveau',
            removal = 'retiré',
        },
    },
}
