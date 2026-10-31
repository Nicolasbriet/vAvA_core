--[[
    vava_appearance/config_client.lua
    Rôle : réglages de l'apparence que lit le client : emplacements de vêtements et accessoires proposés, apparences
           de départ (lues par shared/appearance.lua des deux côtés). Téléchargé par chaque joueur ; le serveur le lit
           aussi. Ce que lit le seul serveur (bornes du schéma, débit des créations) est dans config.lua, servi au
           seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

VavaAppearance.config = {
    clientFile = true,  -- posé par ce fichier, ne pas changer (sans lui, le serveur signale un config.lua d'avant 1.1.0)

    -- Emplacements de vêtements proposés (id GTA) : haut, sous-haut, bras, bas, chaussures.
    -- Les vêtements GTA servent en attendant les packs médiévaux : seule cette liste et les défauts changeront.
    components = { 11, 8, 3, 4, 6 },
    -- Accessoires proposés (id GTA) : chapeau, lunettes, oreilles.
    props = { 0, 1, 2 },

    -- Apparence de départ par sexe ; tout ce qui n'est pas précisé vaut 0 (aucun pour les overlays et accessoires).
    defaults = {
        m = {
            heritage = { mother = 21, father = 0, shapeMix = 0.5, skinMix = 0.5 },
            hair = { style = 4, texture = 0, color = 0, highlight = 0 },
            eyeColor = 0,
            overlays = { [2] = { style = 0, opacity = 1.0, color = 0 } },  -- sourcils
            components = { [11] = 0, [8] = 15, [3] = 0, [4] = 0, [6] = 1 },
        },
        f = {
            heritage = { mother = 21, father = 0, shapeMix = 0.0, skinMix = 0.5 },
            hair = { style = 4, texture = 0, color = 0, highlight = 0 },
            eyeColor = 0,
            overlays = { [2] = { style = 0, opacity = 1.0, color = 0 } },
            components = { [11] = 0, [8] = 14, [3] = 0, [4] = 0, [6] = 1 },
        },
    },
}
