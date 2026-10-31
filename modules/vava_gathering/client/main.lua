--[[
    vava_gathering/client/main.lua
    Rôle : assemblage côté joueur : touche d'interaction (commande +/− pour l'appui et le relâchement, réglable par
           le joueur, aucune boucle), panneau des zones (touche, RPC, interface, repère de la carte posé sur une zone),
           évènements du serveur (touche de pêche, notifications par vava_hud sinon celles du jeu), retours de
           l'interface, fermeture au déchargement du personnage.
           T-102 : essai de l'Atelier (`vava_gathering:trial`, `trialEnd`, envoyés au seul auteur) montré par
           client/props.lua ; liste de la carte demandée à l'apparition (client/blips.lua).
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua, client/props.lua, client/blips.lua,
                  client/interact.lua, client/fishing.lua
]]

local type, tostring, pcall = type, tostring, pcall
local match = string.match
local CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local RPC = VavaGathering.RPC
local EVENTS = VavaGathering.EVENTS
local nui, props, blips, interact, fishing =
    VavaGathering.nui, VavaGathering.props, VavaGathering.blips, VavaGathering.interact, VavaGathering.fishing

local INTERACT_COMMAND = 'vava_gathering_interact'
local ZONES_COMMAND = 'vava_gathering_zones'
local ID_PATTERN = VavaGathering.ID_PATTERN
local ZONE_ID_MAX = 48
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'

local zonesOpen = false

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message au joueur : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string  info | warning | danger
local function feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

-- Panneau des zones ----------------------------------------------------------------------------------------------------

local function closeZones()
    if not zonesOpen then return end
    zonesOpen = false
    nui.send('zonesClose')
    nui.setFocus(false)
end

local function openZones()
    if zonesOpen or not core.characters.current() or IsPauseMenuActive() then return end
    CreateThread(function()
        local ok, success, list = core.rpc.call(RPC.ZONES)
        if not ok or not success or type(list) ~= 'table' then
            interact.report(ok, success, list)
            return
        end
        if zonesOpen or not core.characters.current() then return end
        zonesOpen = true
        nui.send('zones', { zones = list, key = cfg.keys.zones })
        nui.setFocus(true)
    end)
end

-- Touche d'interaction : appui et relâchement -------------------------------------------------------------------------

RegisterCommand('+' .. INTERACT_COMMAND, function()
    if not core.characters.current() or IsPauseMenuActive() or zonesOpen then return end
    if interact.press() then fishing.hold(true) end
end, false)
RegisterCommand('-' .. INTERACT_COMMAND, function()
    if fishing.active() then fishing.hold(false) end
end, false)
RegisterKeyMapping('+' .. INTERACT_COMMAND, cfg.labels.interact, 'keyboard', cfg.keys.interact)

RegisterCommand(ZONES_COMMAND, function()
    if zonesOpen then closeZones() else openZones() end
end, false)
RegisterKeyMapping(ZONES_COMMAND, cfg.labels.zones, 'keyboard', cfg.keys.zones)

-- Évènements du serveur ----------------------------------------------------------------------------------------------

RegisterNetEvent(EVENTS.BITE, function(payload)
    fishing.onBite(payload)
end)

RegisterNetEvent(EVENTS.NOTIFY, function(message, kind)
    if type(message) == 'string' then feed(message, kind) end
end)

-- essai de l'Atelier (auteur seul) : zone et points montrés à la place de l'état publié, puis rendus
RegisterNetEvent(EVENTS.TRIAL, function(payload)
    props.trial(payload)
end)

RegisterNetEvent(EVENTS.TRIAL_END, function(zoneId)
    props.trialEnd(zoneId)
end)

-- Retours de l'interface --------------------------------------------------------------------------------------------

nui.on('tensionDone', function(d)
    fishing.done(d)
    return { ok = true }
end)
nui.on('zonesRefresh', function()
    local ok, success, list = core.rpc.call(RPC.ZONES)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(list) } end
    return { ok = true, zones = list }
end)
-- repère de la carte sur une zone : le panneau se ferme pour laisser ouvrir la carte
nui.on('zonesWaypoint', function(d)
    local zoneId = d.zone
    if type(zoneId) ~= 'string' or #zoneId > ZONE_ID_MAX or not match(zoneId, ID_PATTERN) or not blips.waypoint(zoneId) then
        return { ok = false, error = 'unknown_zone' }
    end
    closeZones()
    return { ok = true }
end)
nui.on('close', function()
    closeZones()
    return { ok = true }
end)

core.hooks.after('core:character:unloaded', function()
    fishing.stop()
    interact.cancel()
    closeZones()
end)

props.start()
blips.start()
