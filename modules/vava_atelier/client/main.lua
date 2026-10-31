--[[
    vava_atelier/client/main.lua
    Rôle : l'Atelier côté joueur : touche (RegisterKeyMapping, réglable par le joueur, aucune boucle) et /atelier pour
           ouvrir ou fermer ; fermeture au déchargement du personnage ; souris et clavier rendus au jeu si la ressource
           s'arrête Atelier ouvert ; export `isOpen`. Le bouton de la page Outils du Registre est reporté.
           T-102 : la même touche, pendant l'essai joué, rend la page (`resume`) ; pendant la visée, ferme l'Atelier.
           Commande-touche `+vava_atelier_annuler` (Z, suit la disposition du clavier ; Ctrl tenu : annuler le dernier
           geste de la visée, rien hors visée), déclarée au registre core:commands par le serveur. Arrêt de la
           ressource : fantômes retirés, blocage de vava_pause levé, focus rendu.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/session.lua, client/placer.lua
]]

local RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName =
    RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local session, placer = VavaAtelier.session, VavaAtelier.placer
local undoKey = cfg.placement.undoKey

local RESOURCE = GetCurrentResourceName()

local function toggle()
    if session.isSuspended() then
        session.resume()
    elseif session.isOpen() then
        session.close(true)
    else
        session.open()
    end
end

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, cfg.labels.open, 'keyboard', cfg.keys.open)

-- Ctrl+Z de la visée : Z en commande-touche (la disposition du clavier est suivie, AZERTY compris), Ctrl lu par le jeu
RegisterCommand('+' .. undoKey.command, function() placer.undo() end, false)
RegisterCommand('-' .. undoKey.command, function() end, false)
RegisterKeyMapping('+' .. undoKey.command, undoKey.label, 'keyboard', undoKey.key)

core.hooks.after('core:character:unloaded', function()
    placer.release()
    session.close(true)
end)

-- Arrêt de la ressource Atelier ouvert : la page disparaît avec elle, mais la souris et le clavier resteraient pris ;
-- les fantômes (objets locaux) disparaîtraient avec elle, le blocage de vava_pause aussi (levé à l'arrêt de l'appelant)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    placer.release()
    session.release()
end)

--- Vrai si l'Atelier est ouvert chez ce joueur (faux pendant l'essai joué : le joueur joue).
exports('isOpen', function()
    return session.isOpen() and not session.isSuspended()
end)
