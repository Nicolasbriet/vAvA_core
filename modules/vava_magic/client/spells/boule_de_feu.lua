--[[
    vava_magic/client/spells/boule_de_feu.lua
    Rôle : sort Boule de feu côté client, sur le noyau des projectiles (client/projectiles.lua) : clic gauche en mode
           magie (ou /lancer), vers la cible verrouillée ou là où l'on vise. Rendu d'après sa config : flammes portées
           par un objet caché, lueur qui suit sa taille, flammes à l'impact, vapeur quand elle s'éteint entre les mains.
    Dépendances : shared/, config_client.lua, client/projectiles.lua
]]

VavaMagic.projectiles.define('boule_de_feu')
