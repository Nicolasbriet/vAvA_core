--[[
    vava_combat/client/attack.lua
    Rôle : un coup, côté client : prédiction sans décision (docs/plan/specs/T-112.md § 8.4). À l'appui d'une touche
           (mode combat éveillé et actif) : technique choisie d'après le style de l'arme et le coup en cours
           (shared/techniques.lua), personnage tourné vers la cible verrouillée ou la caméra (virage borné), geste joué
           AUSSITÔT, puis demande au serveur (`vava_combat:use`, dans un thread). Refus ou transport en échec : geste
           coupé, texte du refus (au plus un par code et par `mode.noticeMs`), attente donnée par le serveur respectée.
           Une touche pressée un peu tôt (au plus `mode.bufferMs`) est gardée et jouée à son heure. Pendant la
           préparation et la frappe, virage vers la cible verrouillée. Le client ne calcule ni portée, ni touché, ni
           dégâts : « touché » n'arrive que par l'évènement vava_combat:hit (client/reactions.lua). Aucune boucle propre :
           `attack.tick` est appelé par la boucle du mode combat.
    Dépendances : shared/constants.lua, config_client.lua, shared/geometry.lua, shared/techniques.lua, client/core.lua,
                  bridge/client.lua, client/hands.lua, client/targeting.lua
]]

local type, sub = type, string.sub
local mathType, max, min, abs = math.type, math.max, math.min, math.abs
local CreateThread, GetGameTimer = CreateThread, GetGameTimer
local PlayerPedId, DoesEntityExist, GetEntityCoords, GetEntityHeading, SetEntityHeading, GetGameplayCamRot =
    PlayerPedId, DoesEntityExist, GetEntityCoords, GetEntityHeading, SetEntityHeading, GetGameplayCamRot

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local modeCfg = cfg.mode
local refusals = cfg.refusals
local bridge = VavaCombat.bridge
local geometry = VavaCombat.geometry
local techniques = VavaCombat.techniques
local hands = VavaCombat.hands
local targeting = VavaCombat.targeting
local RPC = VavaCombat.RPC
local MAX_NOTIFICATION = VavaCombat.MAX_NOTIFICATION
local ROTATION_ORDER = 2
-- en deçà (degrés), le personnage n'est pas retourné
local TURN_EPSILON = 0.5

local attack = {}
VavaCombat.attack = attack

-- coup en cours : { id, def, startedAt, openAt, closeAt, endAt, chainCount }, ou nil
local current = nil
---@type { slot: string, at: integer }|nil  touche gardée (une seule, la dernière)
local buffered = nil
-- attente donnée par le serveur (busy, chain_limit…) : aucune demande avant
local waitUntil = 0
-- chancellement reçu du serveur : aucune technique avant
local staggeredUntil = 0
-- code → instant du dernier texte montré
local noticeAt = {}
local lastTick = nil

--- Écart de cap ramené entre −180 et 180 degrés.
---@param delta number
---@return number
local function wrap(delta)
    return (delta + 540) % 360 - 180
end

--- Texte d'un refus (`refusals[code]`, sinon `default` ; `false` : rien), au plus un par code et par `noticeMs`.
---@param code string|nil
---@param text? string  texte donné par le serveur (raison d'un crochet)
function attack.notice(code, text)
    local key = code or 'default'
    local message = text
    if message == nil then
        message = refusals[key]
        if message == nil then message = refusals.default end
    end
    if not message then return end
    local now = GetGameTimer()
    local last = noticeAt[key]
    if last and now - last < modeCfg.noticeMs then return end
    noticeAt[key] = now
    bridge.Notify(message, 'info')
end

--- Tourne le personnage au départ du coup : vers la cible verrouillée, sinon vers la caméra (`mode.faceCamera`), au plus
--- `mode.faceMaxDeg`.
---@param ped integer
local function faceAtStart(ped)
    local want = nil
    local targetPed = targeting.ped()
    if targetPed and DoesEntityExist(targetPed) then
        want = geometry.headingTo(GetEntityCoords(ped), GetEntityCoords(targetPed))
    elseif modeCfg.faceCamera then
        want = GetGameplayCamRot(ROTATION_ORDER).z % 360
    end
    if not want then return end
    local heading = GetEntityHeading(ped)
    local delta = max(-modeCfg.faceMaxDeg, min(modeCfg.faceMaxDeg, wrap(want - heading)))
    if abs(delta) > TURN_EPSILON then SetEntityHeading(ped, (heading + delta) % 360) end
end

--- Demande au serveur, dans un thread. Refus : geste coupé si c'est toujours ce coup, attente respectée, texte.
---@param swing table
---@param locked integer
local function request(swing, locked)
    CreateThread(function()
        local transport, accepted, code, detail = core.rpc.call(RPC.USE, swing.id, locked)
        if transport and accepted == true then return end
        if not transport then code, detail = accepted, nil end
        if mathType(detail) == 'integer' and detail > 0 then waitUntil = max(waitUntil, GetGameTimer() + detail) end
        if current == swing then
            hands.stopGesture(swing.def.gesture)
            current = nil
        end
        if code == 'refused' and type(detail) == 'string' and detail ~= '' then
            attack.notice(code, sub(detail, 1, MAX_NOTIFICATION))
        else
            attack.notice(type(code) == 'string' and code or nil)
        end
    end)
end

--- Lance une technique : orientation, geste aussitôt (dictionnaire déjà chargé ; sinon aucun geste, la demande part
--- quand même), cycle local, demande.
---@param id string
---@param now integer
local function start(id, now)
    local def = cfg.techniques[id]
    local ped = PlayerPedId()
    faceAtStart(ped)
    local p = def.phases
    hands.playNow(def.gesture, p.windup + p.active + p.recovery)
    local chainCount = (current and now < current.endAt) and current.chainCount + 1 or 0
    local plan = techniques.plan(def, now)
    local swing = { id = id, def = def, startedAt = plan.startedAt, openAt = plan.openAt, closeAt = plan.closeAt,
        endAt = plan.endAt, chainCount = chainCount }
    current = swing
    request(swing, targeting.current() or 0)
end

--- Garde une touche pressée un peu tôt, si l'attente ne dépasse pas `mode.bufferMs`.
---@param slot string
---@param now integer
---@param wait integer
local function keep(slot, now, wait)
    if wait <= modeCfg.bufferMs then buffered = { slot = slot, at = now + wait } end
end

--- Appui sur une touche d'attaque (`legere`, `lourde`), le mode combat éveillé et actif.
---@param slot string
function attack.press(slot)
    local now = GetGameTimer()
    if now < staggeredUntil then
        attack.notice('staggered')
        return
    end
    if not hands.ready(now) then
        attack.notice('drawing')
        return
    end
    local style = cfg.styles[hands.style()]
    if not style then
        attack.notice('no_style')
        return
    end
    if now < waitUntil then
        keep(slot, now, waitUntil - now)
        return
    end
    local id, wait = techniques.pick(style, slot, current, current and current.def, now, cfg.techniques)
    if not id then
        if wait then keep(slot, now, wait) end
        return
    end
    buffered = nil
    start(id, now)
end

--- Une image du mode combat actif : touche gardée jouée à son heure, virage vers la cible pendant la préparation et la
--- frappe (`lock.turnDegPerSec`).
---@param now integer
---@param ped integer
function attack.tick(now, ped)
    local elapsed = lastTick and now - lastTick or 0
    lastTick = now
    if buffered and now >= buffered.at then
        local slot = buffered.slot
        buffered = nil
        attack.press(slot)
    end
    if not current or now >= current.closeAt then return end
    local targetPed = targeting.ped()
    if not targetPed or not DoesEntityExist(targetPed) then return end
    local want = geometry.headingTo(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not want then return end
    local heading = GetEntityHeading(ped)
    local step = cfg.lock.turnDegPerSec * elapsed / 1000
    local delta = max(-step, min(step, wrap(want - heading)))
    if abs(delta) > TURN_EPSILON then SetEntityHeading(ped, (heading + delta) % 360) end
end

--- Vrai pendant un coup (de la demande à la fin de la récupération).
---@param now integer
---@return boolean
function attack.busy(now)
    return current ~= nil and now < current.endAt
end

--- Coupe le coup en cours (geste arrêté) et la touche gardée.
function attack.cancel()
    if current then hands.stopGesture(current.def.gesture) end
    current, buffered = nil, nil
end

--- Chancellement reçu du serveur : coup en cours coupé, aucune technique avant `untilMs`.
---@param untilMs integer
function attack.stagger(untilMs)
    staggeredUntil = untilMs
    attack.cancel()
end

--- Mode endormi ou inactif : touche gardée oubliée, horloge du virage remise à zéro.
function attack.reset()
    buffered, lastTick = nil, nil
end
