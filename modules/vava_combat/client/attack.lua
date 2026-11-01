--[[
    vava_combat/client/attack.lua
    Rôle : un geste côté client (coup ou défense), prédiction sans décision : technique choisie (et payable, d'après
           la jauge reçue), geste aussitôt, demande `vava_combat:use`, refus et attente du serveur respectés, état de la
           jauge lu dans la réponse, touche gardée, virage vers la cible.
    Dépendances : shared/constants.lua, config_client.lua, shared/heading.lua, shared/techniques.lua, client/core.lua,
                  bridge/client.lua, client/endurance.lua, client/hands.lua, client/targeting.lua
]]

local type, ipairs, sub = type, ipairs, string.sub
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
local headingTo = VavaCombat.heading.to
local techniques = VavaCombat.techniques
local gaugeView = VavaCombat.gaugeView
local hands = VavaCombat.hands
local targeting = VavaCombat.targeting
local RPC = VavaCombat.RPC
local MAX_NOTIFICATION = VavaCombat.MAX_NOTIFICATION
local ROTATION_ORDER = 2
-- en deçà (degrés), le personnage n'est pas retourné
local TURN_EPSILON = 0.5
local ATTACKS = {}
for _, kind in ipairs(VavaCombat.ATTACK_TYPES) do ATTACKS[kind] = true end

local attack = {}
VavaCombat.attack = attack

-- geste en cours : { id, def, gesture, startedAt, openAt, closeAt, endAt, chainCount, cut?, onRefused? }, ou nil ; `cut` :
-- coupé par un chancellement, cycle toujours compté (comme le serveur) ; garde ouverte : ni closeAt ni endAt
local current = nil
---@type { slot: string, at: integer }|nil  touche gardée (une seule, la dernière)
local buffered = nil
-- attente donnée par le serveur (busy, chain_limit…) : aucune demande avant
local waitUntil = 0
-- attentes propres à une touche (parade ratée, pas de côté, souffle) : une touche moins chère n'est pas retenue
local slotUntil = {}
local SLOT_OF = { parry_cooldown = 'parade', dodge_cooldown = 'esquive' }
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
        want = headingTo(GetEntityCoords(ped), GetEntityCoords(targetPed))
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
        local transport, accepted, code, detail, value, restIn, rate = core.rpc.call(RPC.USE, swing.id, locked)
        if transport and accepted == true then
            -- état de la jauge après la dépense : valeur, ms avant la recharge, pente (code, detail, value en place)
            gaugeView.apply(code, detail, value)
            return
        end
        if not transport then code, detail = accepted, nil end
        if code == 'exhausted' then gaugeView.apply(value, restIn, rate) end
        if mathType(detail) == 'integer' and detail > 0 then
            local slot = code == 'exhausted' and swing.def.type or SLOT_OF[code]
            if slot then
                slotUntil[slot] = max(slotUntil[slot] or 0, GetGameTimer() + detail)
            else
                waitUntil = max(waitUntil, GetGameTimer() + detail)
            end
        end
        if current == swing then
            hands.stopGesture(swing.gesture)
            current = nil
        end
        if swing.onRefused then swing.onRefused() end
        if code == 'refused' and type(detail) == 'string' and detail ~= '' then
            attack.notice(code, sub(detail, 1, MAX_NOTIFICATION))
        else
            attack.notice(type(code) == 'string' and code or nil)
        end
    end)
end

--- Lance une technique : orientation, geste aussitôt (`gesture`, sinon celui de la technique ; dictionnaire déjà
--- chargé, sinon aucun geste, la demande part quand même), cycle local, demande (cible verrouillée : attaques seules).
--- Rend le geste local.
---@param id string
---@param now integer
---@param gesture? table
---@return table swing
function attack.start(id, now, gesture)
    local def = cfg.techniques[id]
    local ped = PlayerPedId()
    faceAtStart(ped)
    gesture = gesture or def.gesture
    local plan = techniques.plan(def, now)
    hands.playNow(gesture, plan.endAt and plan.endAt - now or -1)
    local chainCount = (current and current.endAt and now < current.endAt) and current.chainCount + 1 or 0
    local swing = { id = id, def = def, gesture = gesture, startedAt = plan.startedAt, openAt = plan.openAt,
        closeAt = plan.closeAt, endAt = plan.endAt, chainCount = chainCount }
    current = swing
    request(swing, ATTACKS[def.type] and targeting.current() or 0)
    return swing
end

--- Garde une touche pressée un peu tôt, si l'attente ne dépasse pas `mode.bufferMs`.
---@param slot string
---@param now integer
---@param wait integer
local function keep(slot, now, wait)
    if wait <= modeCfg.bufferMs then buffered = { slot = slot, at = now + wait } end
end

--- Technique d'une touche si elle peut partir à `now` (chancellement, dégainer, style, attente du serveur, cycle en
--- cours, endurance) : son identifiant, ou `nil[, attente]` ; `quiet` : aucun texte (sauf le souffle : une touche
--- maintenue sans effet ne reste pas muette ; texte borné à un par `noticeMs`).
---@param slot string
---@param now integer
---@param quiet? boolean
---@return string|nil id
---@return integer|nil wait
function attack.choose(slot, now, quiet)
    local refusal = (now < staggeredUntil and 'staggered') or (not hands.ready(now) and 'drawing')
        or (not cfg.styles[hands.style()] and 'no_style')
    if refusal then
        if not quiet then attack.notice(refusal) end
        return nil
    end
    local until_ = max(waitUntil, slotUntil[slot] or 0)
    if now < until_ then return nil, until_ - now end
    local id, wait = techniques.pick(cfg.styles[hands.style()], slot, current, current and current.def, now,
        cfg.techniques)
    -- technique que la jauge vue d'ici ne paie pas : aucune demande (le serveur la refuserait)
    if id and not gaugeView.allows(cfg.techniques[id].stamina, now) then
        attack.notice('exhausted')
        return nil
    end
    return id, wait
end

--- Appui sur une touche d'attaque (`legere`, `lourde`), le mode combat éveillé et actif.
---@param slot string
function attack.press(slot)
    local now = GetGameTimer()
    local id, wait = attack.choose(slot, now)
    if not id then
        if wait then keep(slot, now, wait) end
        return
    end
    buffered = nil
    attack.start(id, now)
end

--- Geste en cours (table du module : à ne pas modifier), ou nil.
---@return table|nil
function attack.current()
    return current
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
    if not current or current.cut or not current.closeAt or now >= current.closeAt
        or current.def.type == 'esquive' then
        return
    end
    local targetPed = targeting.ped()
    if not targetPed or not DoesEntityExist(targetPed) then return end
    local want = headingTo(GetEntityCoords(ped), GetEntityCoords(targetPed))
    if not want then return end
    local heading = GetEntityHeading(ped)
    local step = cfg.lock.turnDegPerSec * elapsed / 1000
    local delta = max(-step, min(step, wrap(want - heading)))
    if abs(delta) > TURN_EPSILON then SetEntityHeading(ped, (heading + delta) % 360) end
end

--- Vrai pendant un geste (de la demande à la fin de la récupération ; garde ouverte comprise).
---@param now integer
---@return boolean
function attack.busy(now)
    return current ~= nil and (current.endAt == nil or now < current.endAt)
end

--- Coupe le geste du coup en cours et la touche gardée. Le cycle du coup reste compté (récupération, enchaînement) :
--- le serveur le garde aussi, la prédiction suivante attend donc comme lui.
function attack.cancel()
    if current and not current.cut then
        hands.stopGesture(current.gesture)
        current.cut = true
    end
    buffered = nil
end

--- Chancellement reçu du serveur : coup en cours coupé, garde tombée (le serveur l'a fermée), aucune technique avant
--- `untilMs`.
---@param untilMs integer
function attack.stagger(untilMs)
    staggeredUntil = untilMs
    attack.cancel()
    local defense = VavaCombat.stance
    if defense then defense.drop(false) end
end

--- Mode endormi ou inactif : touche gardée oubliée, horloge du virage remise à zéro.
function attack.reset()
    buffered, lastTick = nil, nil
end
