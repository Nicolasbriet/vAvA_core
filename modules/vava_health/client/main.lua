--[[
    vava_health/client/main.lua
    Rôle : assemblage côté client. L'état (à terre ou non, temps passé à terre) vient du champ du personnage et des
           ordres du serveur ; le client applique, il ne décide pas :
      - apparition : réglages de mort, vie enregistrée appliquée, ou ped recouché s'il était à terre ;
      - mise à terre (lue par le serveur) : écran à terre, effets de mort de GTA coupés ;
      - relève, retour au lieu de soins, soins et blessures : ordres du serveur ;
      - jauge « Santé » : vie lue localement à intervalle régulier (0 à terre), envoyée à vava_hud seulement quand elle
        change ; redéclarée après un redémarrage, à terre compris.
    Dépendances : shared/, config.lua, tous les fichiers client/ du module
]]

local type, floor = type, math.floor
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local RegisterNetEvent, AddEventHandler = RegisterNetEvent, AddEventHandler

local core = VavaHealth.core
if not core then return end

local cfg = VavaHealth.config
local FIELD = VavaHealth.FIELD
local EVENTS = VavaHealth.EVENTS
local body, screen, hud, keys = VavaHealth.body, VavaHealth.screen, VavaHealth.hud, VavaHealth.keys
-- deux décimales : la jauge ne bouge que d'un pour cent au moins
local GAUGE_PRECISION = 100

---@class vAvA.HealthStatus
---@field downed boolean
---@field downedFor integer  ms passées à terre, à la réception
---@field receivedAt integer
---@field health number
local status = { downed = false, downedFor = 0, receivedAt = 0, health = cfg.initial }
VavaHealth.status = status

local playing = false
local shownGauge = nil

---@param raw any
local function read(raw)
    if type(raw) ~= 'table' then raw = {} end
    status.health = type(raw.health) == 'number' and raw.health or cfg.initial
    status.downed = raw.downed == true
    status.downedFor = type(raw.downedFor) == 'number' and raw.downedFor or 0
    status.receivedAt = GetGameTimer()
end

local function showDowned()
    local downed = cfg.downed
    local since = status.downedFor + (GetGameTimer() - status.receivedAt)
    local giveUpIn, autoIn = downed.giveUpAfterMs - since, downed.autoRespawnMs - since
    -- touche relue à chaque affichage : le joueur a pu la changer dans ses raccourcis
    screen.downed(giveUpIn > 0 and giveUpIn or 0, autoIn > 0 and autoIn or 0, keys.giveUpLabel())
end

---@param value number
local function gauge(value)
    local rounded = floor(value * GAUGE_PRECISION + 0.5) / GAUGE_PRECISION
    if rounded == shownGauge then return end
    shownGauge = rounded
    hud.set(rounded)
end

--- Nouvel état reçu (champ du personnage) : passage à terre ou retour debout.
---@param raw any
local function onState(raw)
    local wasDowned = status.downed
    read(raw)
    if status.downed then
        if not wasDowned then
            body.clearDeathEffects()
            gauge(0)
        end
        showDowned()
    elseif wasDowned then
        keys.release()
        screen.up()
    end
end

core.hooks.after('core:character:loaded', function(character)
    playing = false
    status.downed = false
    read(character.fields and character.fields[FIELD])
end)

core.hooks.after('core:character:spawning', function()
    playing = true
    body.configure()
    if status.downed then
        body.kill()
        body.clearDeathEffects()
        showDowned()
    else
        body.apply(status.health)
        screen.up()
    end
end)

core.hooks.after('core:character:fieldChanged', function(change)
    if change.field == FIELD then onState(change.value) end
end)

core.hooks.after('core:character:unloaded', function()
    playing = false
    status.downed = false
    keys.release()
    screen.up()
    hud.hide()
    shownGauge = nil
end)

RegisterNetEvent(EVENTS.SET, function(health)
    if playing and type(health) == 'number' and not status.downed then body.apply(health) end
end)

RegisterNetEvent(EVENTS.DOWN, function()
    if playing then body.kill() end
end)

RegisterNetEvent(EVENTS.REVIVE, function(health)
    if not playing or type(health) ~= 'number' then return end
    status.downed, status.downedFor, status.health = false, 0, health
    keys.release()
    body.resurrect(health)
    screen.up()
    hud.notify(cfg.messages.revived)
end)

-- arrive avant l'ordre d'apparition du core : à l'arrivée, le ped ne doit pas être recouché
RegisterNetEvent(EVENTS.RESPAWN, function(health)
    if type(health) ~= 'number' then return end
    status.downed, status.downedFor, status.health = false, 0, health
    keys.release()
    screen.up()
end)

RegisterNetEvent(EVENTS.CHANNEL, function(payload)
    if not playing or type(payload) ~= 'table' then return end
    local role, state = payload.role, payload.state
    if role == 'helper' then
        if state == 'start' and type(payload.durationMs) == 'number' then
            body.startGesture(payload.durationMs)
            screen.channel('helper', 'start', payload.durationMs)
        elseif state == 'cancel' or state == 'done' then
            body.stopGesture()
            screen.channel('helper', 'end')
            hud.notify(state == 'done' and cfg.messages.helped or cfg.messages.cancelled, state == 'done' and 'info' or 'warning')
        end
    elseif role == 'patient' then
        if state == 'start' and type(payload.durationMs) == 'number' then
            screen.channel('patient', 'start', payload.durationMs)
        elseif state == 'cancel' then
            screen.channel('patient', 'end')
        end
    end
end)

RegisterNetEvent(EVENTS.MESSAGE, function(key)
    local text = type(key) == 'string' and cfg.messages[key]
    if text then hud.notify(text) end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= hud.RESOURCE then return end
    hud.restarted()
    shownGauge = nil
end)

-- à terre, la jauge reste à 0 sans lire le ped : elle revient d'elle-même après un redémarrage de ce module ou de
-- vava_hud (aucun envoi tant qu'elle ne change pas)
CreateThread(function()
    while true do
        Wait(cfg.client.gaugePollMs)
        if playing then gauge(status.downed and 0 or body.ratio()) end
    end
end)

--- État du joueur local : { health, downed } (copie), ou nil hors personnage.
exports('get', function()
    if not core.characters.current() then return nil end
    return { health = status.downed and 0 or body.ratio(), downed = status.downed }
end)

-- module redémarré en cours de partie
local character = core.characters.current()
if character then
    read(character.fields and character.fields[FIELD])
    playing = not core.characters.awaitingSelection()
    if playing then
        body.configure()
        if status.downed then showDowned() end
    end
end
