--[[
    vava_time/client/main.lua
    Rôle : assemblage côté joueur :
      - au démarrage (connexion, ou ressource relancée) : heure du serveur, ciel et horloge appliqués ;
      - état partagé (GlobalState) qui change : horloge recalée, transition du ciel, outil du Conseil à jour, nouvelle
        saison annoncée au joueur en jeu (lue sur l'état partagé, aucun envoi de plus) ;
      - recalage lent de l'horloge (une minute, calcul local, aucun réseau) et heure du serveur redemandée de loin en
        loin ;
      - /date : l'heure, le jour, la saison et le ciel en mots du jeu (lus sans réseau) ; /ciel et l'outil du Registre ;
      - à l'arrêt : horloge et météo rendues au jeu, outil fermé ;
      - exports : heure, saison, ciel.
    Dépendances : shared/, config.lua, tous les fichiers client/ du module
]]

local type, tostring, pcall = type, tostring, pcall
local CreateThread, Wait, RegisterCommand, AddEventHandler, AddStateBagChangeHandler, GlobalState =
    CreateThread, Wait, RegisterCommand, AddEventHandler, AddStateBagChangeHandler, GlobalState
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaTime.core
if not core then return end

local world, tool, nui = VavaTime.world, VavaTime.tool, VavaTime.nui
local calendar = VavaTime.calendar
local rules = VavaTime.weatherRules
local cfg = VavaTime.config
local STATE = VavaTime.STATE
local ADMIN = VavaTime.ADMIN
local HUD = 'vava_hud'
local FEED_TEXT = 'STRING'

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message au joueur : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string info | warning | danger
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

tool.setNotifier(feed)

-- État partagé ------------------------------------------------------------------------------------------------------

AddStateBagChangeHandler(STATE.CLOCK, 'global', function(_, _, value)
    if type(value) == 'table' then
        -- le serveur publie l'heure : il est prêt, l'heure du serveur peut être demandée si elle manque encore
        if world.synced() then world.applyClock(value) else world.start(value) end
    end
    tool.changed()
end)

AddStateBagChangeHandler(STATE.WEATHER, 'global', function(_, _, value)
    if type(value) == 'table' then world.applyWeather(value) end
    tool.changed()
end)

-- saison connue chez ce joueur : son changement est annoncé (rien à l'arrivée ni au redémarrage du module)
local knownSeason = type(GlobalState[STATE.CALENDAR]) == 'table' and GlobalState[STATE.CALENDAR].season or nil

AddStateBagChangeHandler(STATE.CALENDAR, 'global', function(_, _, value)
    if type(value) == 'table' and type(value.season) == 'string' then
        local text = knownSeason and value.season ~= knownSeason and cfg.messages.seasonStart[value.season]
        knownSeason = value.season
        if text and core.characters.current() then feed(text, 'info') end
    end
    tool.changed()
end)

-- recalage lent : l'horloge du jeu ne dérive pas, l'heure du serveur est redemandée toutes les 30 min
CreateThread(function()
    while true do
        Wait(cfg.client.resyncMs)
        world.applyClock()
        world.maybeResync()
    end
end)

-- Commandes ---------------------------------------------------------------------------------------------------------

--- Texte de /date, ou nil si l'état n'est pas encore connu.
---@return string|nil
local function dateText()
    local clockState, weather, date = GlobalState[STATE.CLOCK], GlobalState[STATE.WEATHER], GlobalState[STATE.CALENDAR]
    local now = world.now()
    if type(clockState) ~= 'table' or type(date) ~= 'table' or not now then return nil end
    local def = type(weather) == 'table' and rules.get(weather.id)
    return calendar.describe(calendar.clock(now, clockState), clockState.frozen and true or false, date, def and def.phrase or '…')
end

RegisterCommand(cfg.commands.date, function()
    feed(dateText() or cfg.messages.notReady, 'info')
end, false)

RegisterCommand(cfg.commands.council, function(_, args)
    if #args == 0 then
        CreateThread(tool.open)
    else
        CreateThread(function() tool.command(args) end)
    end
end, false)

-- outil « Ciel et heure » ouvert depuis le Registre du Conseil
core.hooks.after(ADMIN.OPENED, function(payload)
    if type(payload) == 'table' and payload.key == ADMIN.TOOL then CreateThread(tool.open) end
end)

-- Arrêt ---------------------------------------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaTime.resource then return end
    if tool.isOpen() then nui.setFocus(false) end
    world.restore()
end)

-- Exports -------------------------------------------------------------------------------------------------------------

--- Heure du royaume chez ce joueur : { hour, minute, frozen }, ou nil avant la première réponse du serveur.
exports('getClock', function()
    local state, now = GlobalState[STATE.CLOCK], world.now()
    if type(state) ~= 'table' or not now then return nil end
    local hour, minute = calendar.hms(calendar.clock(now, state))
    return { hour = hour, minute = minute, frozen = state.frozen and true or false }
end)

--- Saison du royaume, ou nil.
exports('getSeason', function()
    local date = GlobalState[STATE.CALENDAR]
    return type(date) == 'table' and date.season or nil
end)

--- Ciel du royaume (identifiant de la config), ou nil.
exports('getWeather', function()
    local weather = GlobalState[STATE.WEATHER]
    return type(weather) == 'table' and weather.id or nil
end)

world.start()
