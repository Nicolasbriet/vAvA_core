--[[
    vava_provisions/client/main.lua
    Rôle : assemblage côté joueur : touche d'interaction (réglable par le joueur, aucune boucle), avis du serveur (outre
           fendue ou perdue, réponse de /eau sans vava_chat), notifications par vava_hud sinon celles du jeu, invite
           cachée au déchargement, démarrage du suivi des points d'eau.
    Dépendances : shared/constants.lua, config_client.lua, shared/texts.lua, client/core.lua, client/nui.lua,
                  client/points.lua, client/interact.lua
]]

local tostring, pcall = tostring, pcall
local RegisterNetEvent, RegisterCommand, RegisterKeyMapping = RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaProvisions.core
if not core then return end

local cfg = VavaProvisions.config
local texts = VavaProvisions.texts
local EVENTS = VavaProvisions.EVENTS
local MAX_REPLY = VavaProvisions.MAX_REPLY
local points, interact = VavaProvisions.points, VavaProvisions.interact

-- même nom que server/commands.lua
local INTERACT_COMMAND = 'vava_provisions_interact'
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'

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

interact.setNotify(feed)

-- Touche d'interaction -----------------------------------------------------------------------------------------------

RegisterCommand(INTERACT_COMMAND, function()
    if not core.characters.current() or IsPauseMenuActive() then return end
    interact.press()
end, false)
RegisterKeyMapping(INTERACT_COMMAND, cfg.labels.interact, 'keyboard', cfg.keys.interact)

-- Évènements du serveur ----------------------------------------------------------------------------------------------

-- outre fendue ou abandonnée : texte de la config, toute autre valeur ignorée
RegisterNetEvent(EVENTS.NOTICE, function(code)
    if not core.characters.current() then return end
    local text = texts.noticeText(code)
    if text then feed(text, 'warning') end
end)

-- réponse de /eau au seul membre du Conseil qui l'a tapée, quand vava_chat manque
RegisterNetEvent(EVENTS.NOTIFY, function(message)
    local text = texts.cutText(message, MAX_REPLY)
    if text then feed(text, 'info') end
end)

core.hooks.after('core:character:unloaded', function() interact.reset() end)
core.hooks.after('core:character:selection', function() interact.reset() end)

points.start()
