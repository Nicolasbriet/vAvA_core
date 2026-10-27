--[[
    vava_admin/client/notify.lua
    Rôle : messages au joueur (avertissement, message du Conseil, suite d'un signalement…) : notification de vava_hud,
           sinon celle de GTA.
    Dépendances : client/core.lua
]]

local pcall, tostring = pcall, tostring
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local HUD = 'vava_hud'
local FEED_TEXT = 'STRING'

local notify = {}
VavaAdmin.notify = notify

local function hudNotify(text, kind)
    return exports[HUD]:notify(text, kind)
end

---@param text string
---@param kind? string   info, warning ou danger
---@param title? string  préfixe (« Message du Conseil »)
function notify.show(text, kind, title)
    if title then text = title .. ' : ' .. text end
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, text, kind)
        if called and ok then return end
        if not called then VavaAdmin.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end
