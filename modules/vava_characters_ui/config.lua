--[[
    vava_characters_ui/config.lua
    Rôle : configuration de l'écran de personnages (client) : scène, caméras, temporisations.
    Dépendances : aucune
]]

VavaCharactersUi = {
    config = {
        appearanceResource = 'vava_appearance',
        createRpc = 'vava_appearance:create',

        -- Modèles d'aperçu : doivent correspondre à spawn.models de vAvA_core (config/server.lua).
        models = { m = 'mp_m_freemode_01', f = 'mp_f_freemode_01' },

        -- Emplacement du ped d'aperçu, à remplacer par la scène médiévale du serveur. Le ped est local :
        -- aucun autre joueur ne le voit, et plusieurs joueurs peuvent créer au même endroit.
        scene = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 },
        clearRadius = 25.0,          -- passants retirés autour de la scène à l'ouverture

        -- Caméras, relatives au ped : distance devant lui, hauteur, décalage latéral (place le ped à droite de
        -- l'écran, le panneau occupant la gauche), hauteur visée, champ de vision.
        cameras = {
            overview = { distance = 4.2, height = 0.9, aim = 1.1, target = 0.4, fov = 45.0 },
            body = { distance = 3.1, height = 0.35, aim = 0.75, target = 0.05, fov = 42.0 },
            face = { distance = 0.95, height = 0.68, aim = 0.22, target = 0.64, fov = 30.0 },
        },
        cameraTransitionMs = 550,
        fadeMs = 500,

        rotationMaxStep = 45.0,      -- degrés maximum appliqués par message de rotation
        modelTimeoutMs = 10000,
        collisionTimeoutMs = 4000,
        pollMs = 50,
    },
}
