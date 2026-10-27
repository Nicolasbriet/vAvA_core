--[[
    vava_magic/client/casting.lua
    Rôle : incantation côté client, commune à tous les sorts. Le client affiche et demande ; le serveur décide.
      - Pré-vérification (mage, sort connu, niveau, mana prédite, recharge, à terre, en véhicule) pour éviter une
        incantation inutile, puis demande au serveur.
      - Pendant la durée : barre d'incantation, animation du sort, médaillon de mana lumineux. Interrompue par une
        chute, une blessure, un déplacement au-delà de ce que le sort permet, ou la touche d'annulation : le
        serveur est prévenu, aucune mana n'est consommée.
      - Sort qui permet de marcher (Boule de feu) : pas de course ni de saut, allure bridée ; c'est la seule boucle
        par image du fichier, et seulement pendant l'incantation. Sinon les contrôles ont lieu toutes les 100 ms.
      - À la fin : arguments de fin du sort (direction de la caméra…), demande au serveur, temps de recharge noté.
    Dépendances : shared/, config.lua, client/core.lua, bridge/client.lua, client/nui.lua, client/state.lua,
                  client/mana.lua, client/messages.lua, client/keys.lua
]]

local type, unpack = type, table.unpack
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, GetEntityCoords, GetEntityHealth, IsPedRagdoll, IsPedFalling, IsEntityDead, IsPedInAnyVehicle =
    PlayerPedId, GetEntityCoords, GetEntityHealth, IsPedRagdoll, IsPedFalling, IsEntityDead, IsPedInAnyVehicle
local RequestAnimDict, HasAnimDictLoaded, TaskPlayAnim, StopAnimTask, RemoveAnimDict =
    RequestAnimDict, HasAnimDictLoaded, TaskPlayAnim, StopAnimTask, RemoveAnimDict
local DisableControlAction, SetPedMaxMoveBlendRatio = DisableControlAction, SetPedMaxMoveBlendRatio
local RegisterNetEvent = RegisterNetEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local gauge = VavaMagic.manaGauge
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.casting
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local BEGIN_PREFIX, FINISH_PREFIX = VavaMagic.BEGIN_PREFIX, VavaMagic.FINISH_PREFIX
local MS_PER_SECOND = 1000
-- vitesse de marche (m/s) quand l'allure vaut 1 dans GTA : sert à brider l'allure d'un sort qui permet de marcher
local WALK_SPEED = 1.5
local CONTROL_SPRINT, CONTROL_JUMP = 21, 22
local ANIM_BLEND_IN, ANIM_BLEND_OUT, ANIM_STOP_BLEND = 8.0, -8.0, 1.0
local ANIM_LOAD_POLL_MS = 10

local casting = {}
VavaMagic.casting = casting

-- incantation en cours : { spell, id?, pending, cancelled, startedAt, ms, move, origin, health, anim, opts }
local active = nil

---@return boolean
function casting.isCasting()
    return active ~= nil
end

---@param dict string
---@return boolean
local function loadAnim(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + cfg.animLoadMs
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then return false end
        Wait(ANIM_LOAD_POLL_MS)
    end
    return true
end

--- Joue une animation { dict, clip, flag, ms? } (bloque le thread le temps de la charger).
---@param anim table|nil
---@return boolean
function casting.playAnim(anim)
    if type(anim) ~= 'table' or not loadAnim(anim.dict) then return false end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, ANIM_BLEND_IN, ANIM_BLEND_OUT, anim.ms or -1, anim.flag or 0, 0.0, false, false, false)
    return true
end

---@param anim table|nil
function casting.stopAnim(anim)
    if type(anim) ~= 'table' then return end
    StopAnimTask(PlayerPedId(), anim.dict, anim.clip, ANIM_STOP_BLEND)
    RemoveAnimDict(anim.dict)
end

--- Pré-vérification locale. Renvoie true, ou false, code[, secondes].
---@param spell string
---@param opts table  { minLevel?, costShare? }
---@return boolean ok
---@return string|nil code
---@return integer|nil extra
function casting.check(spell, opts)
    if not state.ready() then return false, 'not_ready' end
    if not state.isMage() then return false, 'not_mage' end
    local level = state.level(spell)
    if not level then return false, 'unknown_spell' end
    if opts.minLevel and level < opts.minLevel then return false, 'level_too_low' end
    if active then return false, 'busy' end
    if bridge.IsDowned() then return false, 'downed' end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false, 'in_vehicle' end
    local left = state.cooldownLeft(spell)
    if left > 0 then return false, 'cooldown', (left + MS_PER_SECOND - 1) // MS_PER_SECOND end
    local cost = state.cost(spell, opts.costShare)
    if not cost or state.mana() < cost then return false, 'no_mana' end
    return true
end

---@param cast table
local function release(cast)
    if active == cast then active = nil end
    casting.stopAnim(cast.anim)
    gauge.casting(false)
end

--- Interruption décidée par le client : le serveur est prévenu, rien n'est consommé.
---@param code string
local function interrupt(code)
    local cast = active
    if not cast then return end
    if cast.pending then
        cast.cancelled = true
        return
    end
    core.rpc.emit(RPC.CANCEL, cast.id)
    release(cast)
    nui.send('cast:interrupted')
    messages.refuse(code)
    if cast.opts.onAbort then cast.opts.onAbort(code) end
end

--- Raison d'interrompre l'incantation, ou nil.
---@param cast table
---@param ped integer
---@return string|nil
local function brokenBy(cast, ped)
    if IsEntityDead(ped) or GetEntityHealth(ped) < cast.health then return 'hurt' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) then return 'ragdoll' end
    local coords = GetEntityCoords(ped)
    if geometry.distance(cast.origin, coords) > cast.move then return 'moved' end
    return nil
end

--- Lance un sort. `opts` : args (arguments du début), finishArgs (fonction → arguments de la fin), minLevel,
--- costShare, onFinish(info), onAbort(code).
---@param spell string
---@param opts? table
function casting.start(spell, opts)
    opts = opts or {}
    CreateThread(function()
        local ok, code, extra = casting.check(spell, opts)
        if not ok then
            messages.refuse(code, extra)
            return
        end
        local spellCfg = state.spellConfig(spell)
        local cast = { spell = spell, pending = true, cancelled = false, opts = opts }
        active = cast
        local args = opts.args or {}
        local transport, success, info, more = core.rpc.call(BEGIN_PREFIX .. spell, unpack(args, 1, opts.count or #args))
        if active ~= cast then return end
        if not transport or not success then
            active = nil
            if transport then messages.refuse(info, more) else messages.refuse(success) end
            return
        end
        cast.pending = false
        cast.id, cast.ms, cast.move = info.id, info.ms, info.move
        if cast.cancelled then
            core.rpc.emit(RPC.CANCEL, cast.id)
            active = nil
            return
        end
        local ped = PlayerPedId()
        cast.origin = GetEntityCoords(ped)
        cast.health = GetEntityHealth(ped)
        cast.startedAt = GetGameTimer()
        nui.send('cast:start', { label = spellCfg.label, ms = cast.ms })
        gauge.casting(true)
        if casting.playAnim(spellCfg.anim) then cast.anim = spellCfg.anim end

        local slow = spellCfg.moveSpeed
        local blend = slow and slow / WALK_SPEED
        local nextCheck = 0
        while active == cast do
            local now = GetGameTimer()
            if now - cast.startedAt >= cast.ms then break end
            ped = PlayerPedId()
            if now >= nextCheck then
                nextCheck = now + cfg.checkMs
                local reason = brokenBy(cast, ped)
                if reason then
                    interrupt(reason)
                    return
                end
            end
            if slow then
                -- boucle par image justifiée : seulement pendant l'incantation d'un sort qui permet de marcher
                DisableControlAction(0, CONTROL_SPRINT, true)
                DisableControlAction(0, CONTROL_JUMP, true)
                SetPedMaxMoveBlendRatio(ped, blend)
                Wait(0)
            else
                Wait(cfg.checkMs)
            end
        end
        if active ~= cast then return end

        local finishArgs = opts.finishArgs and opts.finishArgs() or {}
        cast.finishing = true
        local done, finished, result = core.rpc.call(FINISH_PREFIX .. spell, cast.id, unpack(finishArgs, 1, #finishArgs))
        release(cast)
        if not done or not finished then
            nui.send('cast:interrupted')
            messages.refuse(done and result or finished)
            if opts.onAbort then opts.onAbort(done and result or finished) end
            return
        end
        nui.send('cast:end')
        state.setCooldown(spell, result.cooldownMs or 0)
        gauge.flash()
        if opts.onFinish then opts.onFinish(result) end
    end)
end

--- Touche d'annulation.
function casting.cancel()
    if active and not active.finishing then interrupt('cancelled') end
end

--- Le serveur a arrêté l'incantation (délai dépassé, sort retiré…).
---@param id integer
---@param code string
function casting.serverAbort(id, code)
    local cast = active
    if not cast or cast.id ~= id or cast.finishing then return end
    release(cast)
    nui.send('cast:interrupted')
    messages.refuse(code)
    if cast.opts.onAbort then cast.opts.onAbort(code) end
end

--- Départ du personnage : l'incantation s'éteint sans bruit.
function casting.reset()
    local cast = active
    if not cast then return end
    if cast.id and not cast.finishing then core.rpc.emit(RPC.CANCEL, cast.id) end
    release(cast)
    nui.send('cast:end')
end

RegisterNetEvent(EVENTS.CAST_ABORT, function(id, code)
    if type(id) == 'number' then casting.serverAbort(id, code) end
end)

keys.bind('annuler', casting.cancel)
