--[[
    vava_cameras/config_client.lua
    Rôle : réglages des caméras que lit le client : qualités (plafond des parts de débit reçues), spectateurs par
           joueur et taille d'une offre, commande et rythme du mur. Téléchargé par chaque joueur ; le serveur le lit
           aussi. Ce que lit le seul serveur (droit, capture, budget, adresses STUN, bornes des caméras, débits,
           textes du journal) est dans config.lua, servi au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaCameras.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.5.0)

    -- Qualités de chaque spectateur (taille, images par seconde, débit visé). bitrateKbps : plafond, atteint quand le
    -- budget (config.lua) le permet ; minKbps : plancher, garanti à chaque spectateur admis.
    qualities = {
        tile = { scale = 2, fps = 10, bitrateKbps = 250, minKbps = 120 },    -- case d'un mur : 480 × 270
        full = { scale = 1, fps = 20, bitrateKbps = 1200, minKbps = 600 },   -- vue en grand : 960 × 540
    },

    -- Les autres bornes des caméras (caméras ouvertes, durée, réponse, débit des offres) sont dans config.lua.
    limits = {
        viewersPerPlayer = 6,      -- membres du Conseil regardant le même joueur en même temps
        sdpMax = 20000,
    },

    -- Mur en jeu : joueurs relus à intervalle. Dispositions, durée d'un mur et outil du Registre : config.lua.
    wall = {
        command = 'cameras',
        refreshMs = 5000,
        -- cases ouvertes l'une après l'autre : un mur 4 × 4 reste sous la limite de messages du core (20 par seconde)
        staggerMs = 150,
    },
}
