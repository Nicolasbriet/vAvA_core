--[[
    vava_example_atelier/config.lua
    Rôle : configuration de l'exemple de l'Atelier (serveur uniquement) : garde du mode développement, commande de
           démonstration, panneaux, affiches et proclamations de départ (la graine : l'Atelier les importe en version 1
           au premier démarrage, puis la base fait foi), lieux des panneaux, zone du core d'un panneau, annonces du chat,
           quartiers proposés, modèles provisoires.
    Dépendances : aucune
]]

VavaExampleAtelier = {
    config = {
        coreVersion = '0.11.0',

        -- Commande de démonstration (/atelier_exemple journal … pour le Conseil, /atelier_exemple lire pour tous).
        command = 'atelier_exemple',
        commandRight = 'metiers',
        readCooldownMs = 2000,       -- délai entre deux « lire » d'un joueur

        -- Données de départ (la graine). Durées en secondes ; hauteur et distance en mètres ; `place` : lieu du panneau
        -- (cap en degrés), `parent` : panneau où l'affiche est collée.
        boards = {
            {
                id = 'place_du_marche', titre = 'Panneau de la place', texte = 'Foire d\'automne au marché, dès l\'aube.',
                langue = 'commun', matiere = 'bois', quartier = 'marche', taille = 1.5, portee = 3, eclaire = true,
                duree = 7 * 86400, offrande = '', modele = 'prop_sign_road_01a',
                place = { x = -250.0, y = -930.0, z = 31.2, h = 90.0 },   -- PLACEHOLDER (près de la forge d'exemple)
            },
            {
                id = 'porte_nord', titre = 'Pancarte de la porte nord', texte = 'Les voyageurs se présentent à la garde.',
                langue = 'commun', matiere = 'pierre', quartier = 'remparts', taille = 2.2, portee = 5, eclaire = false,
                duree = 30 * 86400, offrande = '', modele = 'prop_sign_road_03a',
                place = { x = -300.0, y = -870.0, z = 31.0, h = 0.0 },    -- PLACEHOLDER
            },
        },
        posters = {
            { id = 'foire', titre = 'Foire d\'automne', couleur = 'ocre', duree = 3 * 86400, parent = 'place_du_marche' },
        },
        proclamations = {
            { id = 'couronnement', titre = 'Proclamation du couronnement',
                texte = 'Que tout le royaume se rassemble au château au premier jour de la saison.', solennelle = true },
        },

        -- Zone du core d'un panneau qui a un lieu : rayon = sa distance de lecture (1 à 10 m), plus cette marge.
        zone = {
            margin = 40.0,
            readRadius = 10.0,       -- « lire » : panneaux à moins de ce rayon du joueur (position lue par le serveur)
        },

        -- Annonces du chat : aux abonnés de la zone du panneau, ou à l'auteur seul pour l'essai.
        announce = {
            author = 'Panneau',
            published = 'Le panneau « %s » porte désormais : « %s »',
            removed = 'Le panneau « %s » a été retiré.',
            trial = '[Essai] Le panneau « %s » porterait : « %s »',
            trialPoster = '[Essai] L\'affiche « %s » serait collée.',
            trialEnded = '[Essai] Fin de l\'essai du panneau « %s ».',
            read = '« %s » : %s',
            readTrial = '[Essai] « %s » : %s',
            readNone = 'Aucun panneau à portée de lecture.',
            cooldown = 'Doucement : patientez un instant.',
            refused = 'Refus d\'essai demandé.',
        },

        -- Résumé d'un panneau dont seul le texte change (fonction diff de l'atelier)
        repainted = 'Texte repeint',

        -- Mode développement seulement : `set vava_example_refuse 1` fait refuser chaque `apply` (test du retour en
        -- arrière de la base quand un module refuse).
        refuseConvar = 'vava_example_refuse',

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
