--[[
    vava_pause/client/native.lua
    Rôle : menus natifs ouverts depuis la bannière (carte de GTA, paramètres du jeu, raccourcis de FiveM) : le menu est
           demandé, sa fermeture guettée à intervalle (pas par image), puis la bannière revient. Un menu demandé qui ne
           s'ouvre pas (nom inconnu du jeu) laisse la place au suivant de la liste, sinon la bannière revient seule.
           Pendant ce temps, la boucle de blocage d'Échap se tait (sinon Échap ne pourrait plus refermer le menu).
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local ipairs = ipairs
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local ActivateFrontendMenu, PauseMenuceptionGoDeeper, IsPauseMenuActive, GetHashKey =
    ActivateFrontendMenu, PauseMenuceptionGoDeeper, IsPauseMenuActive, GetHashKey

local cfg = VavaPause.config.native

local native = {}
VavaPause.native = native

-- menus essayés dans l'ordre pour chaque demande de la page
local CHAINS = {
    map = { cfg.map },
    settings = { cfg.settings },
    keymapping = { cfg.keymapping, cfg.settings },
}

local active = false

--- Vrai pendant qu'un menu natif demandé par la bannière est ouvert (ou en cours d'ouverture).
---@return boolean
function native.active()
    return active
end

--- Attend que le menu de GTA s'ouvre, au plus `openTimeoutMs`.
---@return boolean opened
local function awaitOpen()
    local deadline = GetGameTimer() + cfg.openTimeoutMs
    while GetGameTimer() < deadline do
        if IsPauseMenuActive() then return true end
        Wait(cfg.watchMs)
    end
    return IsPauseMenuActive()
end

--- Ouvre un menu natif (`map`, `settings` ou `keymapping`) ; `onReturn(opened)` est appelé une fois le menu refermé
--- (ou jamais ouvert), après `returnDelayMs`.
---@param kind string
---@param onReturn fun(opened: boolean)
---@return boolean started  false : demande inconnue ou menu déjà en cours
function native.open(kind, onReturn)
    local chain = CHAINS[kind]
    if not chain or active then return false end
    active = true
    CreateThread(function()
        local opened = false
        for _, menu in ipairs(chain) do
            ActivateFrontendMenu(GetHashKey(menu.menu), false, -1)
            if menu.deeper then
                Wait(menu.deeperDelayMs)
                PauseMenuceptionGoDeeper(0)
            end
            opened = awaitOpen()
            if opened then break end
        end
        while IsPauseMenuActive() do Wait(cfg.watchMs) end
        Wait(cfg.returnDelayMs)
        active = false
        onReturn(opened)
    end)
    return true
end
