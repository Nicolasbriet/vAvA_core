--[[
    vava_admin/client/main.lua
    Rôle : touche et commande d'ouverture du Registre et touche du vol libre (réglables, aucune boucle), messages du
           Conseil au joueur, annonces, alertes de signalement pour le personnel, commande /signaler pour tous.
    Dépendances : shared/constants.lua, config.lua, tous les fichiers client/ du module
]]

local type, concat = type, table.concat
local CreateThread, RegisterCommand, RegisterKeyMapping, RegisterNetEvent, AddEventHandler =
    CreateThread, RegisterCommand, RegisterKeyMapping, RegisterNetEvent, AddEventHandler

local core = VavaAdmin.core
if not core then return end

local cfg = VavaAdmin.config
local EVENTS = VavaAdmin.EVENTS
local PREFIX = VavaAdmin.PREFIX
local nui, notify, tools, panel = VavaAdmin.nui, VavaAdmin.notify, VavaAdmin.tools, VavaAdmin.panel
local MAX_TEXT = VavaAdmin.MAX_TEXT

local KINDS = { info = true, warning = true, danger = true }

-- Ouvrir le Registre ; pendant une observation, la même touche ramène à sa place.
RegisterCommand(cfg.openCommand, function()
    if tools.isSpectating() then
        tools.stopSpectate()
        return
    end
    if panel.isOpen() then
        panel.close()
        return
    end
    CreateThread(panel.open)
end, false)
RegisterKeyMapping(cfg.openCommand, cfg.labels.open, 'keyboard', cfg.keys.open)

-- Vol libre d'une touche : le serveur vérifie le droit et l'inscrit au journal ; sans droit, la touche ne fait rien.
local noclipPending = false
RegisterCommand(cfg.noclipCommand, function()
    if noclipPending or tools.isSpectating() or not core.characters.current() then return end
    noclipPending = true
    CreateThread(function()
        local enable = not tools.state().noclip
        local ok, success = core.rpc.call(PREFIX .. 'tool', 'noclip', enable)
        noclipPending = false
        if not ok or not success then return end
        tools.set('noclip', enable)
        notify.show(enable and cfg.messages.noclipOn or cfg.messages.noclipOff, 'info')
    end)
end, false)
RegisterKeyMapping(cfg.noclipCommand, cfg.labels.noclip, 'keyboard', cfg.keys.noclip)

-- /signaler <message> : pour tous les joueurs
RegisterCommand(cfg.reportCommand, function(_, args)
    local text = concat(args, ' ')
    if #text == 0 then
        notify.show(cfg.messages.reportUsage:format(cfg.reportCommand), 'warning')
        return
    end
    if #text > MAX_TEXT then text = text:sub(1, MAX_TEXT) end
    CreateThread(function() core.rpc.call(PREFIX .. 'report', text) end)
end, false)

RegisterNetEvent(EVENTS.NOTIFY, function(payload)
    if type(payload) ~= 'table' or type(payload.text) ~= 'string' then return end
    notify.show(payload.text, KINDS[payload.kind] and payload.kind or 'info', type(payload.title) == 'string' and payload.title or nil)
end)

RegisterNetEvent(EVENTS.ANNOUNCE, function(payload)
    if type(payload) ~= 'table' or type(payload.text) ~= 'string' then return end
    if nui.isReady() then
        nui.send('announce', { text = payload.text, author = payload.author, durationMs = cfg.announcementMs })
    else
        notify.show(payload.text, 'info')
    end
end)

RegisterNetEvent(EVENTS.REPORT, function(payload)
    if type(payload) ~= 'table' or type(payload.text) ~= 'string' then return end
    notify.show(payload.text, 'warning')
    if panel.isOpen() then nui.send('reportsChanged') end
end)

core.hooks.after('core:character:spawning', tools.reapply)
core.hooks.after('core:character:unloaded', function()
    panel.close()
    tools.reset()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= VavaAdmin.resource then return end
    panel.close()
    tools.reset()
end)
