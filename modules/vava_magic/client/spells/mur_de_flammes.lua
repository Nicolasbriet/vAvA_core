--[[
    vava_magic/client/spells/mur_de_flammes.lua
    Rôle : sort Mur de flammes côté client : clic gauche en visant le sol (mode magie) = incantation, le point visé
           part au début (aperçu au sol pendant la visée : longueur et largeur du niveau, perpendiculaire au regard).
           Sans visée, ou trop loin, rien ne part. Le serveur revérifie le point, calcule la ligne et la fait brûler ;
           son rendu est dans client/zones.lua.
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local casting = VavaMagic.casting
local controls = VavaMagic.controls
local messages = VavaMagic.messages
local NAME = 'mur_de_flammes'

--- Clic gauche en mode magie (ou /lancer) : le mur se dresse au point visé.
---@param info table  { aiming, point, inRange }
local function cast(info)
    if not info.aiming or not info.point or not info.inRange then
        messages.refuse('no_point')
        return
    end
    local point = info.point
    casting.start(NAME, { args = { point.x, point.y, point.z }, count = 3 })
end

controls.register(NAME, { cast = cast })
