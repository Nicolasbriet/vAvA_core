--[[
    vava_pause/client/gamepad.lua
    Rôle : la manette, bannière ouverte seulement : boucle par image qui se termine à la fermeture ; à chaque appui
           (jamais en continu), la direction est rendue à client/main.lua (page, ou Codex en panneau). Inactive au
           clavier (IsUsingKeyboard).
    Dépendances : shared/constants.lua, config_client.lua
]]

local pairs = pairs
local CreateThread, Wait = CreateThread, Wait
local IsUsingKeyboard, IsDisabledControlJustPressed, IsControlJustPressed =
    IsUsingKeyboard, IsDisabledControlJustPressed, IsControlJustPressed

local cfg = VavaPause.config.gamepad
local PAD = 2

local gamepad = {}
VavaPause.gamepad = gamepad

local running = false

--- Lance la lecture de la manette tant que `opened()` est vrai ; `onNav(direction)` à chaque appui.
---@param opened fun(): boolean
---@param onNav fun(direction: string)
---@param paused fun(): boolean  menu natif ou Codex en panneau : relu toutes les `pausedMs` (relecture réseau R-8)
function gamepad.start(opened, onNav, paused)
    if running or not cfg.enabled then return end
    running = true
    CreateThread(function()
        while opened() do
            if paused and paused() then
                Wait(cfg.pausedMs)
            else
                if not IsUsingKeyboard(PAD) then
                    for direction, control in pairs(cfg.controls) do
                        if IsDisabledControlJustPressed(PAD, control) or IsControlJustPressed(PAD, control) then
                            onNav(direction)
                        end
                    end
                end
                Wait(0) -- audit: ok (bannière ouverte : manette, se termine à la fermeture)
            end
        end
        running = false
    end)
end

--- Vrai si le joueur joue à la manette en ce moment.
---@return boolean
function gamepad.inUse()
    return not IsUsingKeyboard(PAD)
end
