--[[
    vava_pause/client/intercept.lua
    Rôle : interception d'Échap et de P (et Start à la manette) à la place du menu pause de GTA.
      - LA boucle par image du module, exception décidée par le porteur du projet (T-145) : personnage apparu et aucun
        menu natif ouvert par la bannière, elle bloque les deux contrôles, empêche le menu de GTA de s'ouvrir, et sur un
        appui (bannière fermée) lance l'ouverture dans un autre fil. Rien d'autre. Hors jeu ou pendant un menu natif,
        elle attend à intervalle.
      - Guet du focus (100 ms) : le dernier moment où une interface avait le focus ; un Échap qui ferme une autre
        interface n'ouvre pas la bannière dans la foulée (délai de grâce, shared/gate.lua).
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/native.lua
]]

local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local DisableControlAction, IsDisabledControlJustPressed, SetPauseMenuActive, IsNuiFocused =
    DisableControlAction, IsDisabledControlJustPressed, SetPauseMenuActive, IsNuiFocused

local cfg = VavaPause.config.intercept
local native = VavaPause.native
local P_START, ESCAPE = cfg.controls[1], cfg.controls[2]
local IDLE_MS, FOCUS_MS = cfg.idleMs, cfg.focusWatchMs
local HOLD_PAUSE_MENU = cfg.holdPauseMenu ~= false

local intercept = {}
VavaPause.intercept = intercept

local armed = false
local lastFocusAt = nil
local isOpen = function() return false end
local trigger = function() end

--- Arme (personnage apparu) ou désarme (sélection, déchargement) l'interception.
---@param on boolean
function intercept.arm(on)
    armed = on == true
end

---@return boolean
function intercept.armed()
    return armed
end

--- Note qu'une interface vient d'avoir le focus (fermeture de la bannière comprise).
function intercept.touch()
    lastFocusAt = GetGameTimer()
end

---@return integer|nil
function intercept.lastFocusAt()
    return lastFocusAt
end

--- Branche la bannière : `opened()` (bannière déployée ?) et `onPress()` (appui sur Échap ou P, bannière fermée).
---@param opened fun(): boolean
---@param onPress fun()
function intercept.bind(opened, onPress)
    isOpen, trigger = opened, onPress
end

CreateThread(function()
    while true do
        if armed and not native.active() then
            DisableControlAction(0, P_START, true)
            DisableControlAction(0, ESCAPE, true)
            if HOLD_PAUSE_MENU then SetPauseMenuActive(false) end
            if not isOpen() and (IsDisabledControlJustPressed(0, ESCAPE) or IsDisabledControlJustPressed(0, P_START)) then
                trigger()
            end
            Wait(0) -- audit: ok (T-145 : blocage d'Échap et de P par image, exception décidée par le porteur du projet ; aucune autre logique)
        else
            -- menu natif ouvert : relu vite, pour que le blocage reprenne dès sa fermeture
            Wait(armed and FOCUS_MS or IDLE_MS)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(armed and FOCUS_MS or IDLE_MS)
        if armed and IsNuiFocused() then lastFocusAt = GetGameTimer() end
    end
end)
