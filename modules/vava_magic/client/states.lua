--[[
    vava_magic/client/states.lua
    Rôle : états élémentaires du joueur local, d'après le serveur (qui décide de tout) :
      - icônes et minuteries dans la page, effets d'écran (bord rougi par la brûlure, givre au gel) ;
      - ce qui touche à son ped (sa vie et son mouvement lui appartiennent dans GTA) : allure bridée (Ralenti), figé
        (Gelé, le serveur le fige aussi), démarche chancelante et caméra qui tangue (Chancelant), chute (Renversé) ;
      - impossible d'incanter pendant un contrôle dur (pré-vérification : le serveur refuse de toute façon) ;
      - réactions : geste bref et effet d'écran à chaque coup (selon l'élément du sort), recul d'une nova.
    La boucle par image ne tourne que tant que le joueur est ralenti, gelé ou chancelant, ou pendant un recul.
    Dépendances : shared/, config.lua, client/nui.lua, client/casting.lua, client/fx.lua
]]

local type, ipairs, pairs, max = type, ipairs, pairs, math.max
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local PlayerPedId, IsPedRagdoll, IsEntityDead, GetEntityVelocity, SetEntityVelocity =
    PlayerPedId, IsPedRagdoll, IsEntityDead, GetEntityVelocity, SetEntityVelocity
local SetPedMoveRateOverride, DisableControlAction, FreezeEntityPosition, SetPedToRagdoll =
    SetPedMoveRateOverride, DisableControlAction, FreezeEntityPosition, SetPedToRagdoll
local RequestAnimSet, HasAnimSetLoaded, SetPedMovementClipset, ResetPedMovementClipset, ShakeGameplayCam, StopGameplayCamShaking =
    RequestAnimSet, HasAnimSetLoaded, SetPedMovementClipset, ResetPedMovementClipset, ShakeGameplayCam, StopGameplayCamShaking

local nui = VavaMagic.nui
local casting = VavaMagic.casting
local cfg = VavaMagic.config
local statesCfg = cfg.states
local combatCfg = cfg.combat
local EVENTS = VavaMagic.EVENTS
local CONTROL_SPRINT, CONTROL_JUMP, CONTROL_ATTACK, CONTROL_AIM = 21, 22, 24, 25
local CLIPSET_BLEND = 0.25
local CLIPSET_POLL_MS, CLIPSET_TRIES = 20, 50
-- part du Ralenti dès laquelle la course est interdite
local NO_SPRINT_FROM = 0.5
-- états qui bloquent l'incantation, et leur code de refus
local BLOCKS = { { 'stagger', 'staggered' }, { 'knockdown', 'knocked' }, { 'frozen', 'frozen' } }

local conditions = {}
VavaMagic.conditions = conditions

---@type table<string, { untilMs: integer, strength: number|nil }>
local active = {}
local looping = false
local pushUntil, pushX, pushY, pushSpeed = 0, 0, 0, 0

---@param name string
---@return boolean
function conditions.has(name)
    local entry = active[name]
    return entry ~= nil and GetGameTimer() < entry.untilMs
end

local function needsLoop()
    return conditions.has('slow') or conditions.has('frozen') or conditions.has('stagger') or GetGameTimer() < pushUntil
end

local function run()
    if looping then return end
    looping = true
    CreateThread(function()
        -- boucle par image justifiée : seulement ralenti, gelé, chancelant, ou pendant un recul
        while needsLoop() do
            local ped = PlayerPedId()
            local slow = active.slow
            if slow and conditions.has('slow') then
                SetPedMoveRateOverride(ped, max(statesCfg.slowMinRate, 1 - (slow.strength or 0)))
                if (slow.strength or 0) >= NO_SPRINT_FROM then DisableControlAction(0, CONTROL_SPRINT, true) end
            end
            if conditions.has('frozen') then
                for _, control in ipairs({ CONTROL_SPRINT, CONTROL_JUMP, CONTROL_ATTACK, CONTROL_AIM }) do DisableControlAction(0, control, true) end
            end
            if conditions.has('stagger') then
                DisableControlAction(0, CONTROL_SPRINT, true)
                DisableControlAction(0, CONTROL_JUMP, true)
            end
            if GetGameTimer() < pushUntil then
                local velocity = GetEntityVelocity(ped)
                SetEntityVelocity(ped, pushX * pushSpeed, pushY * pushSpeed, velocity.z)
            end
            Wait(0)
        end
        looping = false
    end)
end

--- Démarche chancelante (jeu de mouvements de GTA chargé à la demande).
local function stagger()
    local clipset = statesCfg.stagger.clipset
    CreateThread(function()
        RequestAnimSet(clipset)
        for _ = 1, CLIPSET_TRIES do
            if HasAnimSetLoaded(clipset) then break end
            Wait(CLIPSET_POLL_MS)
        end
        if conditions.has('stagger') and HasAnimSetLoaded(clipset) then SetPedMovementClipset(PlayerPedId(), clipset, CLIPSET_BLEND) end
    end)
    ShakeGameplayCam(statesCfg.stagger.shake, statesCfg.stagger.shakeAmplitude)
end

--- Un état commence (`started`) ou finit sur le ped local.
---@param name string
---@param started boolean
---@param ms integer
local function toggle(name, started, ms)
    local ped = PlayerPedId()
    if name == 'frozen' then
        FreezeEntityPosition(ped, started)
    elseif name == 'stagger' then
        if started then
            stagger()
        else
            ResetPedMovementClipset(ped, CLIPSET_BLEND)
            StopGameplayCamShaking(false)
        end
    elseif name == 'knockdown' and started and not IsEntityDead(ped) then
        SetPedToRagdoll(ped, ms, ms, 0, false, false, false)
    end
end

--- Durées reçues du serveur : { { name, ms, strength? } } (liste vide : plus aucun état).
---@param timers table
function conditions.set(timers)
    local now = GetGameTimer()
    local wanted = {}
    for _, timer in ipairs(timers) do
        if type(timer) == 'table' and type(timer.name) == 'string' and type(timer.ms) == 'number' then
            wanted[timer.name] = { untilMs = now + timer.ms, strength = type(timer.strength) == 'number' and timer.strength or nil, ms = timer.ms }
        end
    end
    -- les états sont connus avant d'agir sur le ped (une démarche chargée plus tard le vérifie)
    local previous = active
    active = wanted
    for name in pairs(previous) do
        if not wanted[name] then toggle(name, false, 0) end
    end
    for name, entry in pairs(wanted) do
        if not previous[name] then toggle(name, true, entry.ms) end
    end
    local list = {}
    for _, name in ipairs(statesCfg.order) do
        local entry = active[name]
        if entry then list[#list + 1] = { name = name, ms = entry.ms } end
    end
    if active.immune then list[#list + 1] = { name = 'immune', ms = active.immune.ms } end
    nui.send('states', { list = list })
    nui.send('screen', { burn = active.burn ~= nil, frost = active.frozen ~= nil })
    if needsLoop() then run() end
end

--- Départ du personnage, arrêt du module : tout revient à la normale.
function conditions.reset()
    conditions.set({})
    pushUntil = 0
end

RegisterNetEvent(EVENTS.CONDITIONS, function(timers)
    if type(timers) == 'table' then conditions.set(timers) end
end)

-- coup reçu : geste bref (si l'on n'est ni à terre ni en train d'incanter) et effet d'écran de l'élément
RegisterNetEvent(EVENTS.HIT, function(element)
    local reaction = type(element) == 'string' and combatCfg.reactions[element]
    if not reaction then return end
    local ped = PlayerPedId()
    if not casting.isCasting() and not IsPedRagdoll(ped) and not IsEntityDead(ped) then casting.playOnce(reaction.anim) end
    if reaction.screen then nui.send('screen:hit', { kind = reaction.screen }) end
end)

-- recul (nova) : poussé dans la direction donnée par le serveur, le temps de `combat.knockbackMs`
RegisterNetEvent(EVENTS.PUSH, function(dx, dy, speed)
    if type(dx) ~= 'number' or type(dy) ~= 'number' or type(speed) ~= 'number' or speed <= 0 or speed > 20 then return end
    pushX, pushY, pushSpeed = dx, dy, speed
    pushUntil = GetGameTimer() + combatCfg.knockbackMs
    run()
end)

casting.addBlocker(function()
    for _, block in ipairs(BLOCKS) do
        if conditions.has(block[1]) then return block[2] end
    end
    return nil
end)
