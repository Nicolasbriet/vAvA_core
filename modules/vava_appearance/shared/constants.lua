--[[
    vava_appearance/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes techniques de GTA : bornes des index,
           overlays de tête et leur type de couleur.
    Dépendances : aucune
]]

VavaAppearance = {}

-- Champ de personnage déclaré auprès du core.
VavaAppearance.FIELD = 'vava_appearance:data'

-- Bornes fixées par le jeu (modèles freemode).
VavaAppearance.LIMITS = {
    parents = 45,          -- visages d'héritage : 0 à 45
    features = 20,         -- traits du visage : SetPedFaceFeature 0 à 19
    eyeColors = 31,
    colors = 63,           -- palettes de couleurs de cheveux et de maquillage
    overlayNone = 255,     -- style d'overlay « aucun »
    componentId = 11,      -- emplacements de vêtements : 0 à 11
    propId = 7,            -- accessoires : 0 à 7
    overlayId = 12,
}

VavaAppearance.HAIR_COMPONENT = 2

-- Type de couleur d'un overlay pour SetPedHeadOverlayColor.
VavaAppearance.COLOR_NONE = 0
VavaAppearance.COLOR_HAIR = 1
VavaAppearance.COLOR_MAKEUP = 2

-- Overlays de tête exposés, dans l'ordre d'application.
VavaAppearance.OVERLAYS = {
    { id = 0, colorType = 0 },   -- imperfections
    { id = 1, colorType = 1 },   -- barbe
    { id = 2, colorType = 1 },   -- sourcils
    { id = 3, colorType = 0 },   -- rides
    { id = 4, colorType = 0 },   -- maquillage des yeux
    { id = 5, colorType = 2 },   -- fard à joues
    { id = 6, colorType = 0 },   -- teint
    { id = 7, colorType = 0 },   -- dommages du soleil
    { id = 8, colorType = 2 },   -- rouge à lèvres
    { id = 9, colorType = 0 },   -- taches de rousseur
    { id = 10, colorType = 1 },  -- pilosité du torse
}
