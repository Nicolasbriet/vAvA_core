--[[
    vava_world/config.lua
    Rôle : configuration du monde (lue par le client et le serveur).
    Dépendances : shared/constants.lua
]]

VavaWorld.config = {
    coreVersion = '0.5.0',

    population = {
        -- false : aucun PNJ, véhicule, bateau, train, avion ni animal créé par le jeu
        enabled = false,
        -- instances à préparer au démarrage (0 = le monde commun) ; les modules qui créent des instances appellent
        -- l'export prepareBucket pour les leurs
        buckets = { 0 },
        -- au démarrage, retire ce que le jeu aurait déjà fait apparaître (module redémarré en cours de partie)
        cleanupOnStart = true,
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
