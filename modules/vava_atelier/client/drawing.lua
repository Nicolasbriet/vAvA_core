--[[
    vava_atelier/client/drawing.lua
    Rôle : ce que l'outil de placement dessine dans le monde, avec les natives du jeu (décision du porteur du projet :
           étiquettes en texte du jeu, jamais en HTML) : anneau d'une zone (cylindre de 1,5 m), poteau d'un sommet,
           segment d'un tracé, chevron d'un point sans fantôme, étiquette au-dessus d'un lieu, ligne d'aide au bas de
           l'écran. Appelé seulement par la boucle de la visée (client/placer.lua), chez le seul membre qui place :
           rien n'est envoyé à personne.
    Dépendances : shared/constants.lua, config_client.lua
]]

local DrawMarker, DrawLine, DrawRect = DrawMarker, DrawLine, DrawRect
local SetDrawOrigin, ClearDrawOrigin = SetDrawOrigin, ClearDrawOrigin
local BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText =
    BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText
local SetTextScale, SetTextFont, SetTextColour, SetTextCentre, SetTextOutline =
    SetTextScale, SetTextFont, SetTextColour, SetTextCentre, SetTextOutline

local placement = VavaAtelier.config.placement
local markers = placement.markers
local RING_ALPHA = placement.ringAlpha

local HEIGHT = 1.5          -- hauteur des anneaux et des poteaux (m)
local POST = 0.3            -- diamètre d'un poteau de sommet
local CHEVRON = 0.6
local LINE_ALPHA = 230
local TEXT = 'STRING'
local FONT = 4
local SCALE = 0.35
local LABEL_LIFT = 1.2      -- étiquette au-dessus du sol (m)

local drawing = {}
VavaAtelier.drawing = drawing

--- Anneau d'une zone (cylindre transparent) de rayon `r`.
---@param x number
---@param y number
---@param z number
---@param r number
---@param color integer[]
function drawing.ring(x, y, z, r, color)
    local diameter = r * 2.0
    DrawMarker(markers.area, x, y, z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, diameter, diameter, HEIGHT, color[1], color[2],
        color[3], RING_ALPHA, false, false, 2, false, nil, nil, false)
end

--- Poteau d'un sommet de tracé.
function drawing.post(x, y, z, color)
    DrawMarker(markers.vertex, x, y, z - 0.2, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, POST, POST, HEIGHT, color[1], color[2],
        color[3], 200, false, false, 2, false, nil, nil, false)
end

--- Chevron d'un point (orienté : tourné selon son cap) quand il n'a pas de fantôme.
function drawing.chevron(x, y, z, heading, color)
    DrawMarker(markers.point, x, y, z + 1.0, 0.0, 0.0, 0.0, 0.0, 180.0, heading or 0.0, CHEVRON, CHEVRON, CHEVRON,
        color[1], color[2], color[3], 220, false, false, 2, false, nil, nil, false)
end

--- Côté d'un tracé : deux lignes, au sol et en haut des poteaux.
function drawing.segment(ax, ay, bx, by, z, color)
    DrawLine(ax, ay, z, bx, by, z, color[1], color[2], color[3], LINE_ALPHA)
    DrawLine(ax, ay, z + HEIGHT, bx, by, z + HEIGHT, color[1], color[2], color[3], LINE_ALPHA)
end

--- Texte du jeu, centré, à la position courante de dessin.
local function text(line, color, x, y)
    SetTextScale(SCALE, SCALE)
    SetTextFont(FONT)
    SetTextColour(color[1], color[2], color[3], 255)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText(TEXT)
    AddTextComponentSubstringPlayerName(line)
    EndTextCommandDisplayText(x, y)
end

--- Étiquette au-dessus d'un lieu (texte du jeu sur un fond sombre léger).
---@param x number
---@param y number
---@param z number
---@param line string
---@param color integer[]
function drawing.label(x, y, z, line, color)
    SetDrawOrigin(x, y, z + LABEL_LIFT, 0)
    DrawRect(0.0, 0.0125, 0.012 + #line * 0.0042, 0.03, 20, 16, 12, 150)
    text(line, color, 0.0, 0.0)
    ClearDrawOrigin()
end

--- Ligne d'aide au bas de l'écran (« Visez le sol. », « Échap encore pour abandonner le tracé. »).
---@param line string
---@param color integer[]
function drawing.screen(line, color)
    text(line, color, 0.5, 0.82)
end
