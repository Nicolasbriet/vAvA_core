--[[
    vava_appearance/config.lua
    Rôle : configuration de l'apparence (lue par le client et le serveur).
    Dépendances : shared/constants.lua
]]

VavaAppearance.config = {
    coreVersion = '0.3.0',

    -- Emplacements de vêtements proposés (id GTA) : haut, sous-haut, bras, bas, chaussures.
    -- Les vêtements GTA servent en attendant les packs médiévaux : seule cette liste et les défauts changeront.
    components = { 11, 8, 3, 4, 6 },
    -- Accessoires proposés (id GTA) : chapeau, lunettes, oreilles.
    props = { 0, 1, 2 },

    -- Bornes de validation côté serveur (le client connaît les vraies limites du modèle). Larges pour accepter
    -- les packs de vêtements ajoutés plus tard.
    maxDrawable = 2000,
    maxTexture = 255,

    createRateLimit = { capacity = 2, refillPerSecond = 0.05 },

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
