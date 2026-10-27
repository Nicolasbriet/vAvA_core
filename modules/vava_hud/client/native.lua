--[[
    vava_hud/client/native.lua
    Rôle : retrait de l'interface native de GTA (minimap, HUD et ses notifications). Les natives utilisées sont des
           bascules qui gardent leur effet : aucun appel par image ; le jeu pouvant les réactiver (changement de
           ped, cinématique), elles sont revérifiées à chaque passage de la boucle de visibilité.
    Dépendances : config.lua
]]

local IsRadarHidden, IsHudHidden, DisplayRadar, DisplayHud = IsRadarHidden, IsHudHidden, DisplayRadar, DisplayHud

local cfg = VavaHud.config.native

local native = {}
VavaHud.native = native

--- Masque ce qui doit l'être (sans effet si c'est déjà le cas).
function native.apply()
    if cfg.hideRadar and not IsRadarHidden() then DisplayRadar(false) end
    if cfg.hideHud and not IsHudHidden() then DisplayHud(false) end
end

--- Rend l'interface native (arrêt du module).
function native.restore()
    if cfg.hideRadar then DisplayRadar(true) end
    if cfg.hideHud then DisplayHud(true) end
end
