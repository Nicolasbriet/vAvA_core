--[[
    vava_magic/client/mana.lua
    Rôle : médaillon de mana (vava_hud, par le bridge), discret : montré seulement quand la mana n'est pas pleine ou
           juste après un sort, puis retiré. La remontée est prédite d'après le dernier envoi du serveur ; la boucle ne
           tourne que médaillon visible.
    Dépendances : config.lua, bridge/client.lua, client/state.lua
]]

local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer

local bridge = VavaMagic.bridge
local state = VavaMagic.state
local hudCfg = VavaMagic.config.mana.hud
-- rafraîchissement du médaillon tant qu'il est visible
local POLL_MS = 250

local gauge = {}
VavaMagic.manaGauge = gauge

local lingerUntil = 0
local running = false

---@return boolean
local function wanted()
    if not state.isMage() then return false end
    local value, max = state.mana()
    return value < max or GetGameTimer() < lingerUntil
end

local function run()
    if running then return end
    running = true
    CreateThread(function()
        while wanted() do
            local value, max = state.mana()
            bridge.GaugeSet(max > 0 and value / max or 0)
            Wait(POLL_MS)
        end
        bridge.GaugeHide()
        running = false
    end)
end

--- À appeler quand la mana ou la fiche change.
function gauge.refresh()
    if wanted() then run() elseif not running then bridge.GaugeHide() end
end

--- Juste après un sort : le médaillon reste un moment, même mana pleine.
function gauge.flash()
    lingerUntil = GetGameTimer() + hudCfg.lingerMs
    run()
end

--- Lueur du médaillon pendant une incantation.
---@param active boolean
function gauge.casting(active)
    if active then gauge.flash() end
    bridge.GaugeActive(active)
end

--- vava_hud a redémarré : médaillon redéclaré s'il doit être visible.
function gauge.restarted()
    bridge.HudRestarted()
    gauge.refresh()
end

state.onChange(gauge.refresh)
