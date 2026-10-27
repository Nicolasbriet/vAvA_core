--[[
    vava_hud/client/main.lua
    Rôle : exports (jauges, notifications), retrait de l'interface native de GTA, et visibilité des jauges :
           affichées quand un personnage est en jeu, masquées pendant la sélection, le menu pause et les fondus au
           noir (apparition, chargement).
    Dépendances : config.lua, client/core.lua, client/nui.lua, client/gauges.lua, client/native.lua, client/notify.lua
]]

local CreateThread, Wait, AddEventHandler = CreateThread, Wait, AddEventHandler
local IsPauseMenuActive, IsScreenFadedOut, IsScreenFadingOut = IsPauseMenuActive, IsScreenFadedOut, IsScreenFadingOut
local GetInvokingResource = GetInvokingResource

local core = VavaHud.core
if not core then return end

local cfg = VavaHud.config
local nui, gauges, native, notify = VavaHud.nui, VavaHud.gauges, VavaHud.native, VavaHud.notify

-- personnage en jeu (apparu), d'après les hooks du core
local playing = core.characters.current() ~= nil and not core.characters.awaitingSelection()
local visible = false

local function shouldShow()
    return playing and not IsPauseMenuActive() and not IsScreenFadedOut() and not IsScreenFadingOut()
end

local function refresh()
    native.apply()
    local show = shouldShow()
    if show == visible then return end
    visible = show
    nui.send('visible', { visible = show })
end

nui.onReady(function()
    return { position = cfg.position, gauges = gauges.all(), visible = visible, notifications = cfg.notifications }
end)

---@return string
local function caller()
    return GetInvokingResource() or VavaHud.resource
end

--- Déclare une jauge : id `<ressource>:<nom>`, options { label, icon = 'nui://…', order?, low?, critical? }.
exports('defineGauge', function(id, options) return gauges.define(caller(), id, options) end)
--- Met à jour une jauge (0 à 1).
exports('setGauge', function(id, value) return gauges.set(caller(), id, value) end)
--- Allume ou éteint la lueur de laiton d'une jauge (le joueur parle, un effet est en cours…).
exports('setGaugeActive', function(id, active) return gauges.setActive(caller(), id, active) end)
exports('removeGauge', function(id) return gauges.remove(caller(), id) end)
--- Notification à l'écran : kind = info (défaut), warning ou danger.
exports('notify', function(message, kind) return notify.push(message, kind) end)

core.hooks.after('core:character:spawning', function()
    playing = true
    refresh()
end)
core.hooks.after('core:character:selection', function()
    playing = false
    refresh()
end)
core.hooks.after('core:character:unloaded', function()
    playing = false
    refresh()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == VavaHud.resource then
        native.restore()
    else
        gauges.purgeOwner(resource)
    end
end)

native.apply()
CreateThread(function()
    while true do
        Wait(cfg.pollMs)
        refresh()
    end
end)
