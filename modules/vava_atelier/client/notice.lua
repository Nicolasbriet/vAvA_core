--[[
    vava_atelier/client/notice.lua
    Rôle : messages de l'Atelier hors de la page, livrés à tous (amorce, T-157) : notification (vava_hud, sinon celle du
           jeu), texte d'un refus, réponse d'une commande de l'Atelier (/atelier_archives) au seul membre qui la lance,
           qu'il ait ou non ouvert l'Atelier. Repris de client/session.lua 1.3.0 (feed, refusal, évènement say).
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local RegisterNetEvent, GetResourceState, TriggerEvent = RegisterNetEvent, GetResourceState, TriggerEvent
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local EVENTS = VavaAtelier.EVENTS

local HUD = 'vava_hud'
local CHAT, CHAT_EVENT = 'vava_chat', 'chat:addMessage'
local SAY_MAX = 480
local FEED_TEXT = 'STRING'

local notice = {}
VavaAtelier.notice = notice

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message hors de l'interface : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string  info | warning | danger
function notice.feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Texte d'un refus (code du serveur ou du transport) ; un code inconnu prend le texte « indisponible ».
---@param code any
---@return string
function notice.refusal(code)
    return texts.refused[code] or texts.refused.unavailable
end

-- Réponse d'une commande de l'Atelier (/atelier_archives) : au chat s'il est là, sinon en notification.
RegisterNetEvent(EVENTS.SAY, function(line)
    if type(line) ~= 'string' or #line > SAY_MAX then return end
    if GetResourceState(CHAT) == 'started' then
        TriggerEvent(CHAT_EVENT, { args = { texts.sayAuthor, line } })
    else
        notice.feed(line, 'info')
    end
end)
