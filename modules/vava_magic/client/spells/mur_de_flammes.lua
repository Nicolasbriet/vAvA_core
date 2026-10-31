--[[
    vava_magic/client/spells/mur_de_flammes.lua
    Rôle : sort Mur de flammes côté client : clic gauche en visant le sol (mode magie) = incantation, le point visé
           part au début (aperçu au sol pendant la visée : longueur et largeur du niveau, perpendiculaire au regard).
           Sans visée, ou trop loin, rien ne part. Le serveur revérifie le point, calcule la ligne et la fait brûler ;
           son rendu est dans client/zones.lua.
    Dépendances : shared/, config_client.lua, client/controls.lua
]]

VavaMagic.controls.registerPoint('mur_de_flammes')
