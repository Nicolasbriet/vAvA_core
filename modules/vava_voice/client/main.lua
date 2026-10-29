--[[
    vava_voice/client/main.lua
    Rôle : assemblage côté client :
      - en jeu (apparition du personnage, ou module redémarré en cours de partie) : salon vocal rejoint, portée
        appliquée, médaillon, zones demandées au serveur (avec quelques essais, la limite de portée revient au
        passage) ; hors du jeu (sélection) : plus de voix ni de médaillon, éditeur fermé ;
      - touche de portée (réglable), commande de l'éditeur, outil du Registre ;
      - à intervalle : joueurs à portée, lueur du médaillon quand le joueur parle, zone de voix où il se trouve ;
      - ordres du serveur : limite de portée, zones changées ;
      - arrêt de la ressource éditeur ouvert : clavier et souris rendus au jeu.
    Dépendances : shared/, config.lua, tous les fichiers client/ du module
]]

local type, mathType = type, math.type
local CreateThread, Wait = CreateThread, Wait
local RegisterCommand, RegisterKeyMapping, RegisterNetEvent, AddEventHandler =
    RegisterCommand, RegisterKeyMapping, RegisterNetEvent, AddEventHandler
local PlayerId, PlayerPedId, GetEntityCoords, NetworkIsPlayerTalking = PlayerId, PlayerPedId, GetEntityCoords, NetworkIsPlayerTalking

local core = VavaVoice.core
if not core then return end

local cfg = VavaVoice.config
local EVENTS = VavaVoice.EVENTS
local RPC = VavaVoice.RPC
local ADMIN = VavaVoice.ADMIN
local hud, mumble, zones, range, editor = VavaVoice.hud, VavaVoice.mumble, VavaVoice.zones, VavaVoice.range, VavaVoice.editor

local playing = false
local talking = false
-- numéro de la demande des zones : une demande plus ancienne s'arrête d'elle-même
local fetching = 0

--- Liste des zones, demandée au serveur à chaque apparition et au redémarrage du module ; le serveur renvoie au passage
--- la limite de portée du moment. Nouvel essai si le module du serveur n'est pas encore prêt (RPC inconnu, délai).
---@param run integer
local function fetchZones(run)
    for _ = 1, cfg.client.syncTries do
        if run ~= fetching or not playing then return end
        local ok, success, list = core.rpc.call(RPC.ZONES)
        if run ~= fetching or not playing then return end
        if ok and success then
            zones.replace(list)
            editor.refresh()
            return
        end
        Wait(cfg.client.syncRetryMs)
    end
    VavaVoice.log.warn('zones de voix non reçues : elles seront redemandées à la prochaine apparition')
end

local function start()
    if playing then return end
    playing = true
    mumble.enable()
    range.apply(false)
    fetching = fetching + 1
    local run = fetching
    CreateThread(function() fetchZones(run) end)
end

local function stop()
    if not playing then return end
    playing = false
    talking = false
    mumble.disable()
    hud.hide()
    editor.close()
end

core.hooks.after('core:character:spawning', start)
core.hooks.after('core:character:selection', stop)
core.hooks.after('core:character:unloaded', stop)

-- outil « Zones de voix » ouvert depuis le Registre du Conseil
core.hooks.after(ADMIN.OPENED, function(payload)
    if type(payload) == 'table' and payload.key == ADMIN.TOOL then CreateThread(editor.open) end
end)

RegisterNetEvent(EVENTS.LIMIT, function(value)
    if mathType(value) == 'integer' then range.setCap(value) end
end)

RegisterNetEvent(EVENTS.ZONE, function(action, payload)
    if action == 'set' then
        zones.set(payload)
    elseif action == 'remove' then
        zones.remove(payload)
    else
        return
    end
    editor.refresh()
end)

RegisterCommand(cfg.command, function()
    if playing and not editor.isOpen() then range.cycle() end
end, false)
RegisterKeyMapping(cfg.command, cfg.keyLabel, 'keyboard', cfg.key)

RegisterCommand(cfg.zones.command, function()
    if playing then CreateThread(editor.open) end
end, false)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= hud.RESOURCE then return end
    hud.restarted()
    if playing then
        range.apply(false)
        hud.setActive(talking)
    end
end)

-- arrêt du module éditeur ouvert : l'interface disparaît avec lui, le clavier et la souris reviennent au jeu
AddEventHandler('onClientResourceStop', function(resource)
    if resource == VavaVoice.resource then editor.release() end
end)

-- joueurs à portée
CreateThread(function()
    while true do
        Wait(cfg.client.targetsPollMs)
        if playing then mumble.refresh() end
    end
end)

-- lueur du médaillon : seulement quand l'état change
CreateThread(function()
    while true do
        Wait(cfg.client.talkingPollMs)
        if playing then
            local now = NetworkIsPlayerTalking(PlayerId()) == true
            if now ~= talking then
                talking = now
                hud.setActive(now)
            end
        end
    end
end)

-- zone de voix où se trouve le joueur
CreateThread(function()
    while true do
        Wait(cfg.client.zonesPollMs)
        if playing then range.setMultiplier((zones.at(GetEntityCoords(PlayerPedId())))) end
    end
end)

--- Portée du joueur local : { index, name, label, distance }, ou nil hors du jeu.
exports('getRange', function()
    if not playing then return nil end
    return range.current()
end)

exports('isTalking', function()
    return playing and talking
end)

-- module redémarré en cours de partie
if core.characters.current() and not core.characters.awaitingSelection() then start() end
