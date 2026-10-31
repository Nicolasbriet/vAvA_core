--[[
    vava_example_combat/config_client.lua
    Rôle : réglages de la ressource d'essai de la chaîne de dégâts que lit le client : commandes du client (/arme,
           /explosion, /tricher), auteur des réponses, armes et explosion vanilla d'essai (provisoires). Téléchargé
           par chaque joueur (tant que la ressource tourne) ; le serveur le lit aussi. Le reste (accès, commandes du
           serveur, délais, chapitre, journal, raisons) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : aucune
]]

VavaExampleCombat = {
    config = {
        clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui : config.lua d'avant 1.2.0 signalé)

        -- Commandes du client ; celles du serveur (/frapper, /esquive, /bouclier, /resistance, /chaine,
        -- /frapper_arme) sont dans config.lua.
        commands = {
            weapon = 'arme', explosion = 'explosion', cheat = 'tricher',
        },
        chatAuthor = 'Combat',

        -- Armes et explosion vanilla d'essai, pour vérifier l'annulation des dégâts natifs entre joueurs.
        weapons = { pistolet = 'WEAPON_PISTOL', couteau = 'WEAPON_KNIFE' }, -- PLACEHOLDER : armes vanilla d'essai
        ammo = 60,
        explosion = { distance = 3.0, type = 2 }, -- PLACEHOLDER : explosion vanilla d'essai
    },
}
