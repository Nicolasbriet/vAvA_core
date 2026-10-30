--[[
    vava_example_atelier/shared/forms.lua
    Rôle : formulaires des deux éditeurs d'exemple, pure donnée tirée de la config (les modèles provisoires) : le
           panneau (les huit widgets, trois groupes dont un replié, deux champs côte à côte), l'affiche (mise en page
           « volet ») et la proclamation (droit `staff`). Aucune ligne d'interface : l'Atelier les dessine.
           Contrôlés par tests/spec/atelier_formschema_spec.lua (acceptés tels quels par le registre).
    Dépendances : config.lua
]]

local cfg = VavaExampleAtelier.config

local HOUR, DAY = 3600, 86400

local forms = {}
VavaExampleAtelier.forms = forms

forms.panneau = {
    titleField = 'titre',
    groups = {
        { id = 'ecrit', label = 'Ce qui est écrit' },
        { id = 'allure', label = 'Son allure', help = 'Ce que voient les passants avant même de lire.' },
        { id = 'reglages', label = 'Réglages', folded = true },
    },
    fields = {
        { id = 'titre', widget = 'text', charset = 'name', min = 3, max = 40, group = 'ecrit',
            label = 'Nom du panneau', help = 'Le nom que le Conseil verra dans ses listes.' },
        { id = 'texte', widget = 'text', charset = 'free', multiline = true, min = 0, max = 300, optional = true,
            group = 'ecrit', label = 'Ce qui est écrit', help = 'Quelques lignes que les passants pourront lire.' },
        { id = 'langue', widget = 'select', group = 'ecrit', default = 'commun',
            label = 'Langue', help = 'La langue des lettres ; tous ne savent pas lire les runes.',
            options = {
                { value = 'commun', label = 'Langue commune' },
                { value = 'ancien', label = 'Ancien parler' },
                { value = 'runes', label = 'Runes' },
            } },
        { id = 'matiere', widget = 'segmented', group = 'allure', default = 'bois',
            label = 'Matière', help = 'Change l\'allure du panneau, pas ce qu\'il dit.',
            options = {
                { value = 'bois', label = 'Bois' },
                { value = 'pierre', label = 'Pierre' },
                { value = 'parchemin', label = 'Parchemin cloué' },
            } },
        { id = 'quartier', widget = 'select', source = 'quartiers', default = 'marche', group = 'allure',
            label = 'Quartier', help = 'Le quartier où le panneau se dresse.' },
        { id = 'taille', widget = 'slider', min = 0.5, max = 3, step = 0.1, decimals = 1, unit = 'm', default = 1.5,
            width = 'half', group = 'allure', label = 'Hauteur', help = 'Plus haut, il se voit de plus loin.' },
        { id = 'portee', widget = 'slider', integer = true, min = 1, max = 10, step = 1, unit = 'm', default = 3,
            width = 'half', group = 'allure', label = 'Distance de lecture',
            help = 'La distance d\'où l\'on peut encore le lire.' },
        { id = 'eclaire', widget = 'toggle', default = false, group = 'reglages',
            label = 'Éclairé la nuit', help = 'Une lanterne à son pied, allumée au crépuscule.' },
        { id = 'duree', widget = 'duration', min = HOUR, max = 30 * DAY, units = { 'h', 'j' }, default = 7 * DAY,
            group = 'reglages', label = 'Reste affiché', help = 'Passé ce délai, le panneau est retiré.' },
        { id = 'offrande', widget = 'item', optional = true, group = 'reglages',
            label = 'Objet au pied du panneau', help = 'Un objet posé là pour le décor : nul ne peut l\'emporter.' },
        { id = 'modele', widget = 'model', choices = cfg.models, default = cfg.models[1].value, group = 'allure',
            label = 'Apparence', help = 'Le modèle utilisé en jeu.' },
    },
}

forms.affiche = {
    titleField = 'titre',
    fields = {
        { id = 'titre', widget = 'text', charset = 'name', min = 3, max = 40,
            label = 'Nom de l\'affiche', help = 'Le nom que le Conseil verra dans ses listes.' },
        { id = 'couleur', widget = 'segmented', default = 'ocre',
            label = 'Couleur', help = 'La teinte du papier, pour attirer l\'œil.',
            options = {
                { value = 'rouge', label = 'Rouge' },
                { value = 'bleu', label = 'Bleu' },
                { value = 'vert', label = 'Vert' },
                { value = 'ocre', label = 'Ocre' },
            } },
        { id = 'duree', widget = 'duration', min = HOUR, max = 7 * DAY, units = { 'h', 'j' }, default = 3 * DAY,
            label = 'Reste affichée', help = 'Passé ce délai, l\'affiche est décollée.' },
    },
}

forms.proclamation = {
    titleField = 'titre',
    fields = {
        { id = 'titre', widget = 'text', charset = 'name', min = 3, max = 40,
            label = 'Nom de la proclamation', help = 'Le nom que le Conseil verra dans ses listes.' },
        { id = 'texte', widget = 'text', charset = 'free', multiline = true, min = 10, max = 300,
            label = 'Texte proclamé', help = 'Ce que le héraut lira sur la place.' },
        { id = 'solennelle', widget = 'toggle', default = true,
            label = 'Solennelle', help = 'Lue au son des trompes, devant la garde assemblée.' },
    },
}
