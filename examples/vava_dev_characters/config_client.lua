--[[
    vava_dev_characters/config_client.lua
    Rôle : réglages du module de test que lit le client : noms des commandes, textes des refus, sexes et leurs
           libellés, auteur des réponses au chat. Téléchargé par chaque joueur (tant que la ressource tourne) ; le
           serveur le lit aussi. Le reste (accès, débits, quantité donnée, journal) est dans config.lua, servi au
           seul serveur (T-132).
    Dépendances : aucune
]]

VavaDevCharacters = {
    config = {
        clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui : config.lua d'avant 1.4.0 signalé)

        command = 'perso',
        respawnCommand = 'respawn',
        giveCommand = 'objet',
        needsCommand = 'besoins',
        healthCommand = 'vie',
        downCommand = 'aterre',

        -- Réponses du serveur traduites pour le joueur (les autres codes s'affichent tels quels).
        refusals = {
            not_allowed = 'réservé au Conseil (droit staff) ou à l\'ACE vava.dev',
            unknown_rpc = 'outils de développement inactifs sur ce serveur (mode développement absent)',
        },

        -- saisie du joueur → valeur attendue par le core
        sexes = { h = 'm', m = 'm', f = 'f' },
        sexLabels = { m = 'homme', f = 'femme' },
        chatAuthor = 'vAvA',
    },
}
