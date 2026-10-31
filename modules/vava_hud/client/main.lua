--[[
    vava_hud/client/main.lua
    Rôle : exports (jauges, notifications, progression), retrait de l'interface native de GTA, et visibilité du HUD :
           affiché quand un personnage est en jeu, masqué pendant la sélection, le menu pause et les fondus au noir
           (apparition, chargement). Une progression en cours est interrompue au retour à la sélection.
    Dépendances : config_client.lua, client/core.lua, client/nui.lua, client/gauges.lua, client/native.lua,
                  client/notify.lua, client/progress.lua
]]

local CreateThread, Wait, AddEventHandler = CreateThread, Wait, AddEventHandler
local IsPauseMenuActive, IsScreenFadedOut, IsScreenFadingOut = IsPauseMenuActive, IsScreenFadedOut, IsScreenFadingOut
local GetInvokingResource = GetInvokingResource

local core = VavaHud.core
if not core then return end

local cfg = VavaHud.config
local nui, gauges, native, notify, progress = VavaHud.nui, VavaHud.gauges, VavaHud.native, VavaHud.notify, VavaHud.progress

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
    return {
        position = cfg.position, gauges = gauges.all(), visible = visible, notifications = cfg.notifications,
        progress = progress.snapshot(),
    }
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
--- Barre de progression d'une action longue, une seule à la fois : id `<ressource>:<nom>`, options
--- { label, durationMs, cancelable? }. Purement visuelle : le serveur reste maître du temps.
exports('progress', function(id, options) return progress.start(caller(), id, options) end)
--- Interrompt la progression en cours ; seule la ressource qui l'a lancée le peut.
exports('cancelProgress', function(id) return progress.cancel(caller(), id) end)
--- Progression en cours : { id, label, endsAt } (horloge GetGameTimer), ou nil.
exports('currentProgress', function() return progress.current() end)

core.hooks.after('core:character:spawning', function()
    playing = true
    refresh()
end)
core.hooks.after('core:character:selection', function()
    playing = false
    progress.hide()
    refresh()
end)
core.hooks.after('core:character:unloaded', function()
    playing = false
    progress.hide()
    refresh()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == VavaHud.resource then
        native.restore()
    else
        gauges.purgeOwner(resource)
        progress.purgeOwner(resource)
    end
end)

native.apply()
CreateThread(function()
    while true do
        Wait(cfg.pollMs)
        refresh()
    end
end)
