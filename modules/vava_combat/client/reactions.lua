--[[
    vava_combat/client/reactions.lua
    Rôle : ce que voit chacun d'un coup qui porte (`vava_combat:hit`) : réaction de la cible (garde brisée comprise),
           attaquant paré qui chancelle, son de l'attaquant, effet d'impact local borné. Aucune boucle.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/hands.lua, client/attack.lua
]]

local type, ipairs, tostring = type, ipairs, tostring
local tointeger = math.tointeger
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local PlayerId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed, DoesEntityExist =
    PlayerId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed, DoesEntityExist
local HasNamedPtfxAssetLoaded, RequestNamedPtfxAsset, UseParticleFxAsset, StartParticleFxNonLoopedOnPedBone =
    HasNamedPtfxAssetLoaded, RequestNamedPtfxAsset, UseParticleFxAsset, StartParticleFxNonLoopedOnPedBone
local ShakeGameplayCam, PlaySoundFrontend = ShakeGameplayCam, PlaySoundFrontend

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local effects = cfg.effects
local stagger = cfg.stagger
local guardCfg = cfg.defense
local hands = VavaCombat.hands
local attack = VavaCombat.attack
local EVENTS = VavaCombat.EVENTS
local MAX_PLAYER = VavaCombat.MAX_PLAYER
-- issue → effet montré sur la cible (nil : aucun)
local FX_OF = { hit = 'impact', stagger = 'impact', down = 'impact', block = 'guarded', parry = 'guarded',
    ['break'] = 'guarded' }
-- issue → son de touche chez l'attaquant
local SOUND_OF = { hit = true, stagger = true, down = true }
local OUTCOMES = {}
for _, outcome in ipairs(VavaCombat.OUTCOMES) do OUTCOMES[outcome] = true end
local ASSET_POLL_MS = 20
-- une ligne de console par actif et par minute au plus
local WARN_MS = 60000

-- fenêtre d'une seconde des effets montrés
local windowAt, windowCount = 0, 0
-- actif de particules → en cours de chargement
local loading = {}
local warnedAt = {}

---@param value any
---@return integer|nil
local function player(value)
    local int = type(value) == 'number' and tointeger(value) or nil
    if not int or int < 1 or int > MAX_PLAYER then return nil end
    return int
end

---@param amount number
local function shake(amount)
    if type(amount) == 'number' and amount > 0 then ShakeGameplayCam(effects.shakeName, amount) end
end

--- Vrai si un effet de plus peut être montré dans la seconde (`effects.maxPerSecond`).
---@param now integer
---@return boolean
local function allowFx(now)
    if now - windowAt >= 1000 then windowAt, windowCount = now, 0 end
    if windowCount >= effects.maxPerSecond then return false end
    windowCount = windowCount + 1
    return true
end

---@param ped integer
---@param fx { asset: string, name: string, scale: number, bone: integer }
local function startFx(ped, fx)
    if not DoesEntityExist(ped) then return end
    UseParticleFxAsset(fx.asset)
    StartParticleFxNonLoopedOnPedBone(fx.name, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, fx.bone, fx.scale, false, false, false)
end

--- Effet non bouclé sur le ped ; actif de particules demandé une fois, attente bornée.
---@param ped integer
---@param fx table
local function particle(ped, fx)
    if HasNamedPtfxAssetLoaded(fx.asset) then
        startFx(ped, fx)
        return
    end
    if loading[fx.asset] then return end
    loading[fx.asset] = true
    RequestNamedPtfxAsset(fx.asset)
    CreateThread(function()
        local deadline = GetGameTimer() + cfg.mode.gestureTimeoutMs
        while not HasNamedPtfxAssetLoaded(fx.asset) and GetGameTimer() < deadline do Wait(ASSET_POLL_MS) end
        loading[fx.asset] = nil
        if HasNamedPtfxAssetLoaded(fx.asset) then
            startFx(ped, fx)
            return
        end
        local now = GetGameTimer()
        if not warnedAt[fx.asset] or now - warnedAt[fx.asset] >= WARN_MS then
            warnedAt[fx.asset] = now
            VavaCombat.log.warn("effet d'impact : actif de particules '%s' non chargé", tostring(fx.asset))
        end
    end)
end

RegisterNetEvent(EVENTS.HIT, function(attackerId, targetId, outcome)
    local attacker, target = player(attackerId), player(targetId)
    if not attacker or not target or type(outcome) ~= 'string' or not OUTCOMES[outcome] then return end
    local me = GetPlayerServerId(PlayerId())
    local now = GetGameTimer()
    if target == me then
        if outcome == 'stagger' then
            attack.stagger(now + stagger.durationMs)
            hands.play(stagger.gesture, stagger.durationMs)
            shake(effects.shakeStagger)
        elseif outcome == 'hit' then
            if not attack.busy(now) then hands.play(effects.flinch, effects.flinch.ms) end
            shake(effects.shakeHit)
        elseif outcome == 'break' then
            -- garde brisée : chancellement, garde tombée (le serveur l'a fermée : rien à demander)
            attack.stagger(now + guardCfg.guardBrokenMs)
            hands.play(guardCfg.brokenGesture, guardCfg.guardBrokenMs)
            shake(effects.shakeStagger)
            attack.notice('guard_broken')
        end
    end
    if attacker == me and outcome == 'parry' then
        attack.stagger(now + stagger.durationMs)
        hands.play(stagger.gesture, stagger.durationMs)
        shake(effects.shakeStagger)
    end
    if attacker == me and SOUND_OF[outcome] then
        local sound = effects.sounds.hit
        if type(sound) == 'table' and type(sound.name) == 'string' then
            PlaySoundFrontend(-1, sound.name, sound.set, true)
        end
    end
    local fx = FX_OF[outcome] and effects[FX_OF[outcome]]
    if not fx then return end
    local client = GetPlayerFromServerId(target)
    if not client or client == -1 then return end
    local ped = GetPlayerPed(client)
    if not ped or ped == 0 or not allowFx(now) then return end
    particle(ped, fx)
end)
