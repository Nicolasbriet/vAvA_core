--[[
    vava_voice/client/main.lua
    Rôle : assemblage côté client :
      - en jeu (apparition du personnage, ou module redémarré en cours de partie) : salon vocal rejoint, portée
        appliquée, médaillon, limite de portée redemandée au serveur (avec quelques essais) ; hors du jeu
        (sélection) : plus de voix ni de médaillon, éditeur fermé ;
      - touche de portée (réglable), commande de l'éditeur, outil du Registre ;
      - à intervalle : joueurs à portée, lueur du médaillon quand le joueur parle, zone de voix où il se trouve ;
      - ordres du serveur : limite de portée ; zones de voix proches reçues, changées et quittées par les
        abonnements de zone du core (core.zones.watch, 1.3.0) ;
      - arrêt de la ressource éditeur ouvert : clavier et souris rendus au jeu.
    Dépendances : shared/, config.lua, tous les fichiers client/ du module
]]

local type, mathType, tonumber, tostring, pcall = type, math.type, tonumber, tostring, pcall
local CreateThread, Wait, GetResourceState = CreateThread, Wait, GetResourceState
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
-- numéro de la demande de la limite : une demande plus ancienne s'arrête d'elle-même
local fetching = 0

--- Limite de portée du moment, redemandée au serveur à chaque apparition et au redémarrage du module (elle revient par
--- son évènement). Nouvel essai si le module du serveur n'est pas encore prêt (RPC inconnu, délai).
---@param run integer
local function syncLimit(run)
    for _ = 1, cfg.client.syncTries do
        if run ~= fetching or not playing then return end
        local ok, success = core.rpc.call(RPC.ZONES)
        if run ~= fetching or not playing then return end
        if ok and success then return end
        Wait(cfg.client.syncRetryMs)
    end
    VavaVoice.log.warn('limite de portée non reçue : elle sera redemandée à la prochaine apparition')
end

local function start()
    if playing then return end
    playing = true
    mumble.enable()
    range.apply(false)
    fetching = fetching + 1
    local run = fetching
    CreateThread(function() syncLimit(run) end)
end

--- Zones de voix proches, envoyées par le core (nom local « z<numéro> », état { zone = … }) : la zone où se tient le
--- joueur en dépend ; l'éditeur suit les changements faits par un autre membre du Conseil.
---@param kind string  'enter' | 'change' | 'leave'
---@param id string
---@param data table|nil  état (enter) ou valeurs changées (change)
local function onZone(kind, id, data)
    if kind == 'leave' then
        zones.remove(tonumber(type(id) == 'string' and id:sub(2) or nil))
        return
    end
    local raw = type(data) == 'table' and data.zone or nil
    if raw == nil then return end
    zones.set(raw)
    editor.track(kind, raw)
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

-- zones de voix proches (abonnements de zone du core, vAvA_core 0.11.0)
if core.zones then
    local watched, watchErr = core.zones.watch(onZone)
    if not watched then VavaVoice.log.error('zones de voix non suivies : %s', tostring(watchErr)) end
else
    VavaVoice.log.error('zones de voix indisponibles : vAvA_core 0.11.0 au moins est requis')
end

RegisterCommand(cfg.command, function()
    if playing and not editor.isOpen() then range.cycle() end
end, false)
RegisterKeyMapping(cfg.command, cfg.keyLabel, 'keyboard', cfg.key)

RegisterCommand(cfg.zones.command, function()
    if playing then CreateThread(editor.open) end
end, false)

-- Réglage « Cercle de portée au sol » de la bannière du royaume (1.4.0) : lu chez vava_pause (export isolé) au
-- démarrage et quand elle démarre, suivi par son crochet ; sans elle, le cercle se montre comme avant.
local PAUSE = cfg.pauseResource
local CIRCLE_KEY = 'voice.circle'

local function readCircle()
    return exports[PAUSE]:setting(CIRCLE_KEY)
end

local function loadCircle()
    if type(PAUSE) ~= 'string' or GetResourceState(PAUSE) ~= 'started' then
        range.setRing(true)
        return
    end
    local ok, value = pcall(readCircle)
    if not ok then VavaVoice.log.warn('%s.setting en erreur : %s', PAUSE, tostring(value)) end
    range.setRing(not ok or value ~= false)
end

core.hooks.after('vava_pause:settingChanged', function(payload)
    if type(payload) == 'table' and payload.key == CIRCLE_KEY then range.setRing(payload.value ~= false) end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == PAUSE then loadCircle() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == PAUSE then range.setRing(true) end
end)

loadCircle()

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
