--[[
    vava_voice/client/main.lua
    Rôle : assemblage côté client :
      - en jeu (apparition du personnage) : salon vocal rejoint, portée appliquée, médaillon, zones reçues ; hors du
        jeu (sélection) : plus de voix ni de médaillon, éditeur fermé ;
      - touche de portée (réglable), commande de l'éditeur, outil du Registre ;
      - à intervalle : joueurs à portée, lueur du médaillon quand le joueur parle, zone de voix où il se trouve ;
      - ordres du serveur : limite de portée, zones changées.
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

--- Liste des zones, demandée au serveur à chaque apparition.
local function fetchZones()
    local ok, success, list = core.rpc.call(RPC.ZONES)
    if ok and success then
        zones.replace(list)
        editor.refresh()
    end
end

local function start()
    if playing then return end
    playing = true
    mumble.enable()
    range.apply(false)
    CreateThread(fetchZones)
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
