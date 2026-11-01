--[[
    vava_atelier/client/main.lua
    Rôle : touche et commande de l'Atelier (amorce livrée à tous, T-157) : le premier appui fait charger le code du
           Conseil (client/loader.lua) puis ouvre l'Atelier ; ensuite, ouvrir, fermer, ou rendre la page après un essai
           joué. Fermeture au déchargement, arrêt de la ressource, export isOpen : chacun sans erreur tant que le
           paquet n'est pas chargé. Ctrl+Z de la visée : client/keys.lua (paquet).
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/loader.lua
]]

local RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName, CreateThread =
    RegisterCommand, RegisterKeyMapping, AddEventHandler, GetCurrentResourceName, CreateThread

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local loader = VavaAtelier.loader

local RESOURCE = GetCurrentResourceName()

--- Séance du paquet, seulement s'il est chargé et sa page amorcée.
local function loadedSession()
    return loader.isReady() and VavaAtelier.session or nil
end

local function toggle()
    local session = loadedSession()
    if not session then
        -- chargement dans un fil (RPC, attente de la page) ; F9 pendant le chargement : rien (loader.ensure)
        CreateThread(function()
            if loader.ensure() and VavaAtelier.session then VavaAtelier.session.open() end
        end)
    elseif session.isSuspended() then
        session.resume()
    elseif session.isOpen() then
        session.close(true)
    else
        session.open()
    end
end

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, cfg.labels.open, 'keyboard', cfg.keys.open)

core.hooks.after('core:character:unloaded', function()
    local placer, session = VavaAtelier.placer, VavaAtelier.session
    if placer then placer.release() end
    if session then session.close(true) end
end)

-- Arrêt de la ressource Atelier ouvert : la page disparaît avec elle, mais la souris et le clavier resteraient pris ;
-- les fantômes (objets locaux) disparaîtraient avec elle, le blocage de vava_pause aussi (levé à l'arrêt de l'appelant)
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    local placer, session = VavaAtelier.placer, VavaAtelier.session
    if placer then placer.release() end
    if session then session.release() end
end)

--- Vrai si l'Atelier est ouvert chez ce joueur (faux pendant l'essai joué : le joueur joue ; faux tant que le paquet
--- n'est pas chargé).
exports('isOpen', function()
    local session = loadedSession()
    return session ~= nil and session.isOpen() and not session.isSuspended()
end)
