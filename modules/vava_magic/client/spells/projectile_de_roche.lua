--[[
    vava_magic/client/spells/projectile_de_roche.lua
    Rôle : sort Projectile de roche côté client, sur le noyau des projectiles (client/projectiles.lua) : clic gauche
           en mode magie (ou /lancer), vers la cible verrouillée ou là où l'on vise. Rendu d'après sa config : bloc de
           pierre visible qui tournoie, traînée de poussière, éclats à l'impact et caméra qui tremble chez les
           joueurs proches.
    Dépendances : shared/, config_client.lua, client/projectiles.lua
]]

VavaMagic.projectiles.define('projectile_de_roche')
