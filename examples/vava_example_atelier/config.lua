--[[
    vava_example_atelier/config.lua
    Rôle : configuration de l'exemple de l'Atelier (serveur uniquement) : garde du mode développement, commande de
           démonstration du journal, panneaux, affiches et proclamations de départ (gardés en mémoire, jamais écrits
           en base), quartiers proposés, modèles provisoires.
    Dépendances : aucune
]]

VavaExampleAtelier = {
    config = {
        coreVersion = '0.11.0',

        -- Commande de démonstration du journal (Conseil) : /atelier_exemple journal <panneaux|proclamations> <texte>.
        command = 'atelier_exemple',
        commandRight = 'metiers',

        -- Données de départ, gardées en mémoire. Durées en secondes ; hauteur et distance en mètres.
        boards = {
            {
                id = 'place_du_marche', titre = 'Panneau de la place', texte = 'Foire d\'automne au marché, dès l\'aube.',
                langue = 'commun', matiere = 'bois', quartier = 'marche', taille = 1.5, portee = 3, eclaire = true,
                duree = 7 * 86400, offrande = '', modele = 'prop_sign_road_01a',
            },
            {
                id = 'porte_nord', titre = 'Pancarte de la porte nord', texte = 'Les voyageurs se présentent à la garde.',
                langue = 'commun', matiere = 'pierre', quartier = 'remparts', taille = 2.2, portee = 5, eclaire = false,
                duree = 30 * 86400, offrande = '', modele = 'prop_sign_road_03a',
            },
        },
        posters = {
            { id = 'foire', titre = 'Foire d\'automne', couleur = 'ocre', duree = 3 * 86400 },
        },
        proclamations = {
            { id = 'couronnement', titre = 'Proclamation du couronnement',
                texte = 'Que tout le royaume se rassemble au château au premier jour de la saison.', solennelle = true },
        },

        -- Source `quartiers` du réglage « Quartier » (liste rendue par la fonction `options` de l'éditeur).
        districts = {
            { value = 'marche', label = 'Le marché' },
            { value = 'remparts', label = 'Les remparts' },
            { value = 'port', label = 'Le port' },
            { value = 'chateau', label = 'Le château' },
        },

        -- Choix du réglage « Apparence » : modèles vanilla en attendant les modèles médiévaux.
        models = {
            { value = 'prop_sign_road_01a', label = 'Panneau de bois', provisional = true },   -- PLACEHOLDER
            { value = 'prop_sign_road_03a', label = 'Pancarte de pierre', provisional = true }, -- PLACEHOLDER
        },
    },
}
