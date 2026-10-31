--[[
    vava_chat/client/visibility.lua
    Rôle : le chat se cache sous le menu pause, pendant un écran noir et hors du jeu (sélection du personnage). État
           relu toutes les `visibilityMs` et envoyé à la page seulement quand il change : aucune boucle par image.
    Dépendances : config_client.lua, client/nui.lua
]]

local CreateThread, Wait, IsPauseMenuActive, IsScreenFadedOut = CreateThread, Wait, IsPauseMenuActive, IsScreenFadedOut

local nui = VavaChat.nui
local cfg = VavaChat.config

local visibility = {}
VavaChat.visibility = visibility

local playing = false
local shown = nil

local function update()
    local visible = playing and not IsPauseMenuActive() and not IsScreenFadedOut()
    if visible == shown then return end
    shown = visible
    nui.send('visible', { visible = visible })
end

---@param value boolean
function visibility.setPlaying(value)
    playing = value
    update()
end

nui.onReady(function()
    shown = nil
    update()
end)

CreateThread(function()
    while true do
        update()
        Wait(cfg.visibilityMs)
    end
end)
