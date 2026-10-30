--[[
    vava_atelier/client/main.lua
    Rôle : l'Atelier côté joueur : touche (RegisterKeyMapping, réglable par le joueur, aucune boucle) et /atelier pour
           ouvrir ou fermer ; fermeture au déchargement du personnage ; souris et clavier rendus au jeu si la ressource
           s'arrête Atelier ouvert ; export `isOpen`. Le bouton de la page Outils du Registre est reporté.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/session.lua
]]

local RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName =
    RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local session = VavaAtelier.session

local RESOURCE = GetCurrentResourceName()

local function toggle()
    if session.isOpen() then session.close(true) else session.open() end
end

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, cfg.labels.open, 'keyboard', cfg.keys.open)

core.hooks.after('core:character:unloaded', function()
    session.close(true)
end)

-- Arrêt de la ressource Atelier ouvert : la page disparaît avec elle, mais la souris et le clavier resteraient pris.
AddEventHandler('onClientResourceStop', function(resource)
    if resource == RESOURCE then session.release() end
end)

--- Vrai si l'Atelier est ouvert chez ce joueur.
exports('isOpen', function()
    return session.isOpen()
end)
