--[[
    vava_combat/client/dummies.lua
    Rôle : mannequins d'entraînement chez le joueur (T-156) : props LOCAUX créés à portée et retirés en s'éloignant
           (boucle lente, personnage en jeu seulement), balancement au coup qui se redresse seul, éclats, chiffre et son
           chez l'attaquant (vava_combat:dummy). Affichage seulement : le serveur juge tout.
    Dépendances : shared/constants.lua, config_client.lua, shared/dummies.lua, client/core.lua, bridge/client.lua
]]

local type, pairs, ipairs, next, tostring = type, pairs, ipairs, next, tostring
local mathType, sqrt, sin, cos, rad, pi = math.type, math.sqrt, math.sin, math.cos, math.rad, math.pi
local CreateThread, Wait, GetGameTimer, AddEventHandler, RegisterNetEvent =
    CreateThread, Wait, GetGameTimer, AddEventHandler, RegisterNetEvent
local PlayerPedId, PlayerId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed =
    PlayerPedId, PlayerId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed
local GetEntityCoords, DoesEntityExist, DeleteObject = GetEntityCoords, DoesEntityExist, DeleteObject
local GetHashKey, IsModelValid, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded =
    GetHashKey, IsModelValid, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded
local CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, SetEntityRotation =
    CreateObjectNoOffset, SetEntityHeading, FreezeEntityPosition, SetEntityRotation
local HasNamedPtfxAssetLoaded, RequestNamedPtfxAsset, UseParticleFxAsset, StartParticleFxNonLoopedAtCoord =
    HasNamedPtfxAssetLoaded, RequestNamedPtfxAsset, UseParticleFxAsset, StartParticleFxNonLoopedAtCoord
local PlaySoundFrontend = PlaySoundFrontend

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local d = cfg.dummies
local effects = cfg.effects
local rules = VavaCombat.dummyRules
local bridge = VavaCombat.bridge
local EVENTS = VavaCombat.EVENTS
local MAX_PLAYER, TENTHS_MAX = VavaCombat.MAX_PLAYER, VavaCombat.TENTHS_MAX
local LOAD_POLL_MS = 50
local NEAR_MARGIN = 20.0
local OUTCOMES = {}
for _, outcome in pairs(VavaCombat.OUTCOMES) do OUTCOMES[outcome] = true end
local SOUND_OF = { hit = true, stagger = true }

local dummyProps = {}
VavaCombat.dummyProps = dummyProps

-- part client, lue clé par clé
local part = {
    label = d.label, model = d.model, fallbackModel = d.fallbackModel, modelTimeoutMs = d.modelTimeoutMs,
    streamRadius = d.streamRadius, keepRadius = d.keepRadius, nearPollMs = d.nearPollMs, farPollMs = d.farPollMs,
    centerHeight = d.centerHeight, anchorHeight = d.anchorHeight, wobble = d.wobble, fx = d.fx, list = d.list,
}
local entries = {}
local valid, invalidReason = rules.check(part)
if valid then
    entries = rules.index(part.list, part)
else
    core.log.warn('mannequins non montrés : %s', tostring(invalidReason))
end
local STREAM_SQ = valid and part.streamRadius * part.streamRadius or 0
local KEEP_SQ = valid and part.keepRadius * part.keepRadius or 0
local NEAR_SQ = valid and (part.keepRadius + NEAR_MARGIN) ^ 2 or 0
local wobbleCfg = part.wobble

-- props montrés : n → { entity, loading, failed }
local shown = {}
-- balancements en cours : n → { startedAt, dirX, dirY }
local wobbling = {}
local running, playing, wobbleRunning = false, false, false
local warnedModel = {}
local windowAt, windowCount, loadingFx = 0, 0, false

local function remove(n)
    local slot = shown[n]
    if not slot then return end
    shown[n] = nil
    wobbling[n] = nil
    if slot.entity and DoesEntityExist(slot.entity) then DeleteObject(slot.entity) end
end

local function removeAll()
    for n in pairs(shown) do remove(n) end
end

-- modèle du mannequin, sinon le repli ; une ligne par modèle inconnu
local function modelOf(entry)
    for _, name in ipairs({ entry.model, part.fallbackModel }) do
        local hash = GetHashKey(name)
        if IsModelValid(hash) then return hash end
        if not warnedModel[name] then
            warnedModel[name] = true
            core.log.warn("mannequin '%s' : modèle inconnu '%s'", entry.id, name)
        end
    end
    return nil
end

-- prop LOCAL (jamais réseau), attente bornée du modèle
local function spawn(entry)
    local slot = { entity = nil, loading = true }
    shown[entry.n] = slot
    CreateThread(function()
        local hash = modelOf(entry)
        if not hash then
            -- gardé sans prop tant qu'on reste à portée
            slot.loading, slot.failed = false, true
            return
        end
        RequestModel(hash)
        local deadline = GetGameTimer() + part.modelTimeoutMs
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
        if shown[entry.n] ~= slot or not HasModelLoaded(hash) then
            if shown[entry.n] == slot then shown[entry.n] = nil end
            SetModelAsNoLongerNeeded(hash)
            return
        end
        local entity = CreateObjectNoOffset(hash, entry.x, entry.y, entry.z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if not entity or entity == 0 then
            shown[entry.n] = nil
            return
        end
        SetEntityHeading(entity, entry.heading)
        FreezeEntityPosition(entity, true)
        slot.entity, slot.loading = entity, false
    end)
end

-- un passage : créé à streamRadius, retiré au-delà de keepRadius ; rend l'intervalle suivant
function dummyProps.step()
    local coords = GetEntityCoords(PlayerPedId())
    local px, py, pz = coords.x, coords.y, coords.z
    local near = false
    for n, entry in pairs(entries) do
        local dx, dy, dz = entry.x - px, entry.y - py, entry.z - pz
        local gap = dx * dx + dy * dy + dz * dz
        if gap <= NEAR_SQ then near = true end
        if gap <= STREAM_SQ then
            if not shown[n] then spawn(entry) end
        elseif gap > KEEP_SQ and shown[n] then
            remove(n)
        end
    end
    return near and part.nearPollMs or part.farPollMs
end

local function loop()
    while playing do
        Wait(dummyProps.step())
    end
    removeAll()
    running = false
end

function dummyProps.setPlaying(flag)
    playing = flag == true
    if not playing then
        removeAll()
        return
    end
    if not running and next(entries) ~= nil then
        running = true
        CreateThread(loop)
    end
end

function dummyProps.entity(n)
    local slot = shown[n]
    return slot and slot.entity or nil
end

-- une seule boucle de balancement pour tous, puis remis droit exactement
local function wobbleLoop()
    local period = wobbleCfg.ms
    while next(wobbling) ~= nil do
        local now = GetGameTimer()
        for n, w in pairs(wobbling) do
            local entry, slot = entries[n], shown[n]
            local entity = slot and slot.entity
            if not entity or not DoesEntityExist(entity) then
                wobbling[n] = nil
            else
                local t = (now - w.startedAt) / period
                if t >= 1 then
                    SetEntityRotation(entity, 0.0, 0.0, entry.heading, 2, true)
                    wobbling[n] = nil
                else
                    local tilt = wobbleCfg.angle * (1 - t) * sin(2 * pi * wobbleCfg.cycles * t)
                    local h = rad(entry.heading)
                    local along = w.dirX * -sin(h) + w.dirY * cos(h)
                    local side = w.dirX * cos(h) + w.dirY * sin(h)
                    SetEntityRotation(entity, -tilt * along, tilt * side, entry.heading, 2, true)
                end
            end
        end
        Wait(0) -- audit: ok — balancement en cours (état actif qui dessine) ; fin dès qu'aucun mannequin ne bouge (≤ wobble.ms)
    end
    wobbleRunning = false
end

-- s'écarte de l'attaquant (vu), sinon vers l'arrière du mannequin
local function wobble(entry, src)
    local slot = shown[entry.n]
    if not slot or not slot.entity or wobbleCfg.ms <= 0 or wobbleCfg.angle <= 0 then return end
    local h = rad(entry.heading)
    local dirX, dirY = sin(h), -cos(h)
    local client = GetPlayerFromServerId(src)
    if client and client ~= -1 then
        local ped = GetPlayerPed(client)
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local at = GetEntityCoords(ped)
            local dx, dy = entry.x - at.x, entry.y - at.y
            local length = sqrt(dx * dx + dy * dy)
            if length > 0.01 then dirX, dirY = dx / length, dy / length end
        end
    end
    wobbling[entry.n] = { startedAt = GetGameTimer(), dirX = dirX, dirY = dirY }
    if not wobbleRunning then
        wobbleRunning = true
        CreateThread(wobbleLoop)
    end
end

local function allowFx(now)
    if now - windowAt >= 1000 then windowAt, windowCount = now, 0 end
    if windowCount >= effects.maxPerSecond then return false end
    windowCount = windowCount + 1
    return true
end

local function splinters(entry)
    local fx = part.fx
    if not fx or not allowFx(GetGameTimer()) then return end
    if not HasNamedPtfxAssetLoaded(fx.asset) then
        if loadingFx then return end
        loadingFx = true
        RequestNamedPtfxAsset(fx.asset)
        CreateThread(function()
            local deadline = GetGameTimer() + part.modelTimeoutMs
            while not HasNamedPtfxAssetLoaded(fx.asset) and GetGameTimer() < deadline do Wait(LOAD_POLL_MS) end
            loadingFx = false
        end)
        return
    end
    local c = entry.center
    UseParticleFxAsset(fx.asset)
    StartParticleFxNonLoopedAtCoord(fx.name, c.x, c.y, c.z, 0.0, 0.0, 0.0, fx.scale, false, false, false)
end

-- vava_combat:dummy(n, attaquant[, issue, dixièmes|false]) ; valeurs relues
function dummyProps.receive(n, src, issue, tenths)
    if mathType(n) ~= 'integer' or mathType(src) ~= 'integer' or src < 1 or src > MAX_PLAYER then return end
    local entry = entries[n]
    if not entry then return end
    if issue ~= nil and (type(issue) ~= 'string' or not OUTCOMES[issue]) then return end
    wobble(entry, src)
    splinters(entry)
    if issue == nil or src ~= GetPlayerServerId(PlayerId()) then return end
    if SOUND_OF[issue] then
        local sound = effects.sounds.hit
        if type(sound) == 'table' and type(sound.name) == 'string' then PlaySoundFrontend(-1, sound.name, sound.set, true) end
    end
    -- 4e valeur absente : chiffres coupés par le serveur ; false : le mot seul
    if tenths == false then
        bridge.HitText('dealt', { x = entry.x, y = entry.y, z = entry.z + part.anchorHeight }, issue, nil)
    elseif mathType(tenths) == 'integer' and tenths >= 0 and tenths <= TENTHS_MAX then
        bridge.HitText('dealt', { x = entry.x, y = entry.y, z = entry.z + part.anchorHeight }, issue, tenths)
    end
end

function dummyProps.start()
    RegisterNetEvent(EVENTS.DUMMY, dummyProps.receive)
    core.hooks.after('core:character:spawning', function() dummyProps.setPlaying(true) end)
    core.hooks.after('core:character:selection', function() dummyProps.setPlaying(false) end)
    core.hooks.after('core:character:unloaded', function() dummyProps.setPlaying(false) end)
    if core.characters.current() and not core.characters.awaitingSelection() then dummyProps.setPlaying(true) end
end

-- arrêt du module : aucun prop ne doit rester dans le monde
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaCombat.resource then return end
    playing = false
    wobbling = {}
    removeAll()
end)
