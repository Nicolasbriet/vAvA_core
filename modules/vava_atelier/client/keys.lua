--[[
    vava_atelier/client/keys.lua
    Rôle : Ctrl+Z de la visée, livré dans le paquet du Conseil (dernier fichier, T-157 : un habitant n'a pas cette
           liaison dans ses réglages) : Z en commande-touche (la disposition du clavier est suivie, AZERTY compris),
           Ctrl lu par le jeu. Repris de client/main.lua 1.3.0 ; la touche reste déclarée au registre core:commands par
           le serveur.
    Dépendances : config_conseil.lua, client/placer.lua
]]

local RegisterCommand, RegisterKeyMapping = RegisterCommand, RegisterKeyMapping

local placer = VavaAtelier.placer
if not placer then return end

local undoKey = VavaAtelier.config.placement.undoKey

RegisterCommand('+' .. undoKey.command, function() placer.undo() end, false)
RegisterCommand('-' .. undoKey.command, function() end, false)
RegisterKeyMapping('+' .. undoKey.command, undoKey.label, 'keyboard', undoKey.key)
