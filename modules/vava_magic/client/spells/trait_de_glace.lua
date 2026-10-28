--[[
    vava_magic/client/spells/trait_de_glace.lua
    Rôle : sort Trait de glace côté client, sur le noyau des projectiles (client/projectiles.lua) : clic gauche en
           mode magie (ou /lancer), vers la cible verrouillée ou là où l'on vise. Rendu d'après sa config : éclat de
           givre (marqueur clair), traînée de vapeur, lueur bleutée, éclaboussure et son de glace brisée à l'impact.
    Dépendances : shared/, config.lua, client/projectiles.lua
]]

VavaMagic.projectiles.define('trait_de_glace')
