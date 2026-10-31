--[[
    vava_magic/client/casting.lua
    Rôle : incantation côté client, commune à tous les sorts. Le client affiche et demande ; le serveur décide.
      - Pré-vérification (mage, sort connu, niveau, mana prédite, délai global, recharge, à terre, en véhicule, arme en
        main (vava_combat), droit d'incanter du bridge, empêchements d'autres fichiers) pour éviter une incantation
        inutile, puis demande au serveur.
      - Pendant la durée : animation en trois phases (début, maintien en boucle, relâchement au succès), barre
        d'incantation au-delà de `castBarMinMs`, lueur de la barre de mana. Interrompue par une chute, une blessure
        (sorts qui le disent), un déplacement au-delà de ce que le sort permet, une arme prise en main, ou la touche
        d'annulation : le serveur est prévenu, aucune mana n'est consommée.
      - Sort qui permet de marcher (projectiles) : pas de course ni de saut, allure bridée ; c'est la seule boucle
        par image du fichier, et seulement pendant l'incantation. Sinon les contrôles ont lieu toutes les 100 ms
        (`checkMs`) ; l'arme en main, toutes les 200 ms (`armedCheckMs`).
      - À la fin : arguments de fin du sort (direction visée…), demande au serveur, temps de recharge et délai global
        notés.
    Dépendances : shared/, config_client.lua, client/core.lua, bridge/client.lua, client/nui.lua, client/state.lua,
                  client/fx.lua, client/hud.lua, client/messages.lua, client/keys.lua
]]

local type, ipairs, pcall, unpack = type, ipairs, pcall, table.unpack
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, GetEntityCoords, GetEntityHealth, IsPedRagdoll, IsPedFalling, IsEntityDead, IsPedInAnyVehicle =
    PlayerPedId, GetEntityCoords, GetEntityHealth, IsPedRagdoll, IsPedFalling, IsEntityDead, IsPedInAnyVehicle
local TaskPlayAnim, StopAnimTask = TaskPlayAnim, StopAnimTask
local DisableControlAction, SetPedMaxMoveBlendRatio = DisableControlAction, SetPedMaxMoveBlendRatio
local RegisterNetEvent = RegisterNetEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local fx = VavaMagic.fx
local hud = VavaMagic.hud
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

local casting = {}
VavaMagic.casting = casting

-- incantation en cours : { spell, id?, pending, cancelled, startedAt, ms, move, origin, health, anim, opts }
local active = nil
---@type (fun(): string|nil)[]  empêchements d'incanter (renvoient un code de refus)
local blockers = {}

---@return boolean
function casting.isCasting()
    return active ~= nil
end

--- Empêchement tenu par un autre fichier (état « chancelant »…) : `check()` renvoie un code de refus, ou nil.
---@param check fun(): string|nil
function casting.addBlocker(check)
    blockers[#blockers + 1] = check
end

--- Joue une animation { dict, clip, flag, ms? } (bloque le thread le temps de la charger). Renvoie vrai si elle part.
---@param anim table|nil
---@return boolean
function casting.playAnim(anim)
    if type(anim) ~= 'table' or not fx.useAnim(anim.dict) then return false end
    TaskPlayAnim(PlayerPedId(), anim.dict, anim.clip, ANIM_BLEND_IN, ANIM_BLEND_OUT, anim.ms or -1, anim.flag or 0, 0.0, false, false, false)
    return true
end

---@param anim table|nil
function casting.stopAnim(anim)
    if type(anim) ~= 'table' then return end
    StopAnimTask(PlayerPedId(), anim.dict, anim.clip, ANIM_STOP_BLEND)
    fx.releaseAnim(anim.dict)
end

--- Joue une animation ponctuelle (relâchement) et la libère à la fin de sa durée.
---@param anim table|nil
function casting.playOnce(anim)
    if type(anim) ~= 'table' then return end
    CreateThread(function()
        if not casting.playAnim(anim) then return end
        Wait(anim.ms or MS_PER_SECOND)
        fx.releaseAnim(anim.dict)
    end)
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
    if not bridge.CanUseMagic() then return false, 'cannot_cast' end
    if bridge.IsArmed() then return false, 'armed' end
    for _, check in ipairs(blockers) do
        local ok, code = pcall(check)
        if ok and type(code) == 'string' then return false, code end
    end
    if state.globalLeft() > 0 then return false, 'global_cooldown' end
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
    hud.casting(false)
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
    if cast.bar then nui.send('cast:interrupted') end
    messages.refuse(code)
    if cast.opts.onAbort then cast.opts.onAbort(code) end
end

--- Raison d'interrompre l'incantation, ou nil.
---@param cast table
---@param ped integer
---@return string|nil
local function brokenBy(cast, ped)
    if IsEntityDead(ped) then return 'hurt' end
    if cast.hurtBreaks and GetEntityHealth(ped) < cast.health then return 'hurt' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) then return 'ragdoll' end
    local coords = GetEntityCoords(ped)
    if geometry.distance(cast.origin, coords) > cast.move then return 'moved' end
    return nil
end

--- Lance un sort. `opts` : args (arguments du début), count (leur nombre), finishArgs (fonction → arguments de la
--- fin), minLevel, costShare, beforeRelease() (juste avant le geste de relâchement), onFinish(info), onAbort(code).
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
        local anims = type(spellCfg.anims) == 'table' and spellCfg.anims or {}
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
        cast.hurtBreaks = spellCfg.interruptOnHurt ~= false
        cast.startedAt = GetGameTimer()
        cast.bar = cast.ms >= cfg.castBarMinMs
        if cast.bar then nui.send('cast:start', { label = spellCfg.label, ms = cast.ms }) end
        hud.casting(true)
        -- début puis maintien : le maintien prend la suite à la fin du début
        local loopAt = cast.startedAt
        if anims.start and casting.playAnim(anims.start) then
            fx.releaseAnim(anims.start.dict)
            loopAt = cast.startedAt + (anims.start.ms or 0)
        end
        local looping = false

        local slow = spellCfg.moveSpeed
        local blend = slow and slow / WALK_SPEED
        local nextCheck, nextArmed = 0, 0
        while active == cast do
            local now = GetGameTimer()
            if now - cast.startedAt >= cast.ms then break end
            if not looping and now >= loopAt then
                looping = true
                if casting.playAnim(anims.loop) then cast.anim = anims.loop end
            end
            ped = PlayerPedId()
            if now >= nextCheck then
                nextCheck = now + cfg.checkMs
                local reason = brokenBy(cast, ped)
                -- arme prise en main (le serveur brise aussi l'incantation) : relevé plus lent, l'export lit le personnage
                if not reason and now >= nextArmed then
                    nextArmed = now + cfg.armedCheckMs
                    if bridge.IsArmed() then reason = 'armed' end
                end
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
            if cast.bar then nui.send('cast:interrupted') end
            messages.refuse(done and result or finished)
            if opts.onAbort then opts.onAbort(done and result or finished) end
            return
        end
        if cast.bar then nui.send('cast:end') end
        state.setCooldown(spell, result.cooldownMs or 0)
        state.setGlobal(result.globalMs or 0)
        hud.flash()
        if result.success ~= false then
            if opts.beforeRelease then opts.beforeRelease(result) end
            casting.playOnce(anims.release)
        end
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
    if cast.bar then nui.send('cast:interrupted') end
    messages.refuse(code)
    if cast.opts.onAbort then cast.opts.onAbort(code) end
end

--- Départ du personnage : l'incantation s'éteint sans bruit.
function casting.reset()
    local cast = active
    if not cast then return end
    if cast.id and not cast.finishing then core.rpc.emit(RPC.CANCEL, cast.id) end
    release(cast)
    if cast.bar then nui.send('cast:end') end
end

RegisterNetEvent(EVENTS.CAST_ABORT, function(id, code)
    if type(id) == 'number' then casting.serverAbort(id, code) end
end)

keys.bind('annuler', casting.cancel)
