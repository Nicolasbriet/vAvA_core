--[[
    vava_atelier/config_conseil.lua
    Rôle : réglages lus par le client des seuls membres du Conseil (livré dans le paquet, T-157) et relus par le
           serveur : outil de placement, textes de la séance. Complète la table ouverte par config_client.lua sans en
           réécrire une clé ; config.lua, chargé après lui, le complète à son tour. Part chez chaque membre : rien de
           secret ici. Le reste : config_client.lua (tous les joueurs), config.lua (serveur). Détail : README (Règles).
    Dépendances : shared/constants.lua, config_client.lua
]]

local config = VavaAtelier.config
local texts = config.texts

-- T-102 : outil de placement (client/placer.lua), repris tel quel de config_client.lua 1.3.0. Le serveur relit
-- `reach`, `polygonFactor` et `texts` : il revérifie chaque pose avec les mêmes règles (shared/placerules.lua) et rend
-- les mêmes textes ; `bucket` et `childrenMax`, du seul serveur, sont ajoutés par config.lua.
config.placement = {
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
    undoKey = {
        command = 'vava_atelier_annuler', key = 'Z', label = 'Atelier : annuler le dernier placement (avec Ctrl)',
    },
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
        refused = '%s — %s',
        area = '%s, rayon %s m',
        far = 'Trop loin de vous (%d m) : approchez-vous.',
        ground = 'Visez le sol.',
        inside = 'Hors de %s.',
        spacing = 'Trop près de « %s » (%s m).',
        radius = 'Rayon de %d à %d m.',
        vertices = 'De %d à %d sommets.',
        crossing = 'Le tracé se croise.',
        busy = 'Un instant…',
        undoNone = 'Rien à annuler.',
        undoFailed = 'Impossible d\'annuler : la fiche a changé.',
        picked = '%s : cliquez à sa nouvelle place',
        trace = 'Sommets posés : %d (Entrée pour fermer le tracé)',
        quitTrace = 'Appuyez encore sur Échap pour abandonner le tracé.',
        vehicle = 'Descendez de votre monture pour placer.',
        new = 'nouveau',
        removal = 'retiré',
    },
}

-- Textes de la séance (client/session.lua, client/relay.lua)
texts.modeLine = 'Mode édition : visible par vous seul'      -- bandeau du volet (message `mode`)
texts.revoked = 'Votre place au Conseil a changé : l\'Atelier se ferme.'
-- bandeau du volet pendant un essai, si l'éditeur n'a pas de texts.trialLine
texts.trialLineDefault = 'Mode essai : vous seul voyez ce changement en jeu'
texts.trialEndedFeed = 'L\'essai de « %s » a pris fin.'

-- Refus des RPC de la séance, montrés hors de l'interface ou relayés à la page (client/session.lua, client/relay.lua,
-- client/placer.lua) ; ceux que montre l'amorce sont dans config_client.lua (relecture réseau R-3 de T-157). Le serveur
-- les lit aussi (archives, appels des modules).
local refused = texts.refused
refused.not_open = 'L\'Atelier s\'est refermé : rouvrez-le.'
refused.unknown_editor = 'Cet atelier n\'existe plus.'
refused.unknown_kind = 'Ce genre de fiche n\'existe plus dans cet atelier.'
refused.unknown_entry = 'Cette fiche n\'existe plus.'
refused.unknown_field = 'Ce réglage n\'existe pas dans cette fiche.'
refused.editor_error = 'Cet atelier ne répond pas : prévenez un développeur.'
refused.db_error = 'Les registres de l\'Atelier ne répondent pas : réessayez dans un instant.'
refused.stale = 'Cette fiche a changé depuis que vous l\'avez ouverte : rouvrez-la pour voir la dernière version.'
refused.draft_taken = 'Un autre membre du Conseil tient déjà un brouillon de cette fiche : ouvrez-le pour le lire '
    .. 'ou le reprendre.'
refused.draft_open = 'Vous avez déjà un brouillon de cette fiche : abandonnez-le d\'abord.'
refused.not_holder = 'Ce brouillon est tenu par un autre membre du Conseil.'
refused.no_draft = 'Cette fiche n\'a pas de brouillon en cours.'
refused.not_stored = 'Cet atelier ne garde encore rien : on peut seulement y vérifier une fiche.'
refused.too_large = 'Cette fiche est trop lourde pour être gardée : raccourcissez ses textes.'
refused.full = 'Trop de fiches ou de brouillons : publiez ou abandonnez-en d\'abord.'
refused.parent_missing = 'Cette fiche dépend d\'une autre qui n\'est pas publiée : publiez-la ou rétablissez-la '
    .. 'd\'abord.'
refused.trial_busy = 'Vous avez déjà un essai en cours : arrêtez-le d\'abord.'
refused.no_trial = 'Cet atelier ne propose pas d\'essai.'
refused.syncing = 'L\'atelier se met à jour : réessayez dans un instant.'
refused.unknown_version = 'Cette version n\'existe plus.'
refused.not_archived = 'Seule une ancienne version peut être rétablie.'
refused.unchanged = 'Rien n\'a changé depuis la version publiée.'
refused.unreadable = 'Cette version ne peut plus être lue par cet atelier.'
refused.not_placeable = 'Cette fiche ne se place pas en jeu.'
refused.instance = 'Vous êtes hors du monde commun (intérieur, cachot…) : revenez-y pour placer.'
