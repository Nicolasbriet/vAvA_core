--[[
    vava_atelier/client/main.lua
    Rôle : touche et commande de l'Atelier (F9 rend aussi la page après un essai joué), Ctrl+Z de la visée, fermeture au
           déchargement, arrêt de la ressource, export isOpen.
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
