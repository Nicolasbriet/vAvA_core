--[[
    vava_world/config_client.lua
    Rôle : réglages du monde lus par le client (et le serveur) : population, avis de recherche, sons coupés. Le
           reste : config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaWorld.config = {
    clientFile = true,  -- ne pas changer (sans lui : config.lua d'avant 1.2.0 signalé)

    population = {
        -- false : aucun PNJ, véhicule, bateau, train, avion ni animal créé par le jeu
        enabled = false,
    },

    -- Chez chaque joueur : pas d'avis de recherche, ni police ni secours.
    client = {
        wantedLevel = 0,
    },

    -- Sons de la ville moderne coupés chez chaque joueur (réglés une fois, et à chaque apparition) :
    audio = {
        -- scènes de mixage de GTA : celle-ci coupe l'ambiance de la ville (bruit de circulation, rumeur de foule) ;
        -- si elle coupait aussi la nature (oiseaux, vent), la retirer d'ici
        scenes = { 'FBI_HEIST_H5_MUTE_AMBIENCE_SCENE' },
        -- drapeaux audio de GTA posés à vrai
        flags = { 'PoliceScannerDisabled', 'WantedMusicDisabled', 'DisableFlightMusic', 'DisableBarks' },
        -- véhicules lointains (lumières et bruit de la circulation au loin), sirènes au loin
        distantCars = false,
        distantSirens = false,
        -- émetteurs fixes à couper, par nom (musique de bâtiments, radios…)
        staticEmitters = {},
    },
}
