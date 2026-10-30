--[[
    vava_health/client/body.lua
    Rôle : le ped du joueur local : vie fixée (0 à 1), mise à terre (vie GTA à 0, jamais arrêtée sur le seuil), relève
           sur place, réglages de mort de GTA (pas de fondu ni de retour automatique à l'hôpital, pas de récupération
           automatique de la vie), tir ami coupé (confort : la garantie est l'annulation des coups natifs par le
           serveur) et geste pour relever quelqu'un. Les réglages sont des bascules (aucune boucle) ; le changement de
           modèle en remet certains à zéro : ils sont réappliqués à chaque apparition.
    Dépendances : shared/constants.lua, config.lua, shared/vitality.lua, client/core.lua
]]

local CreateThread, Wait, GetGameTimer, SetTimeout = CreateThread, Wait, GetGameTimer, SetTimeout
local PlayerId, PlayerPedId, IsEntityDead = PlayerId, PlayerPedId, IsEntityDead
local GetEntityHealth, GetEntityMaxHealth, SetEntityHealth = GetEntityHealth, GetEntityMaxHealth, SetEntityHealth
local GetEntityCoords, GetEntityHeading = GetEntityCoords, GetEntityHeading
local NetworkResurrectLocalPlayer, ClearPedTasksImmediately = NetworkResurrectLocalPlayer, ClearPedTasksImmediately
local SetPlayerHealthRechargeMultiplier = SetPlayerHealthRechargeMultiplier
local SetFadeOutAfterDeath, SetFadeInAfterDeathArrest = SetFadeOutAfterDeath, SetFadeInAfterDeathArrest
local PauseDeathArrestRestart, IgnoreNextRestart, AnimpostfxStopAll = PauseDeathArrestRestart, IgnoreNextRestart, AnimpostfxStopAll
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict
local TaskPlayAnim, StopAnimTask = TaskPlayAnim, StopAnimTask
local NetworkSetFriendlyFireOption, SetCanAttackFriendly = NetworkSetFriendlyFireOption, SetCanAttackFriendly

local cfg = VavaHealth.config
local vitality = VavaHealth.vitality
local animation = cfg.client.animation
local gesture = cfg.assist.gesture
local DOWN = cfg.downThreshold

local body = {}
VavaHealth.body = body

--- Vie actuelle du ped local (0 à 1).
---@return number
function body.ratio()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return 0 end
    local maxHealth = GetEntityMaxHealth(ped)
    if maxHealth <= DOWN then return 0 end
    local value = (GetEntityHealth(ped) - DOWN) / (maxHealth - DOWN)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Couche le ped (mise à terre décidée par le serveur) : vie GTA à 0, qu'il soit debout ou déjà tombé. Un ped laissé
--- exactement au seuil peut rester debout selon GTA ; à 0, il tombe toujours, et le serveur le lit couché.
function body.kill()
    local ped = PlayerPedId()
    if GetEntityHealth(ped) > 0 then SetEntityHealth(ped, 0) end
end

--- Fixe la vie (0 à 1) d'un ped debout ; 0 le fait tomber (couché aussitôt, sans s'arrêter sur le seuil).
---@param ratio number
function body.apply(ratio)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    local health = vitality.toGame(ratio, GetEntityMaxHealth(ped), DOWN)
    if health == 0 then
        body.kill()
        return
    end
    SetEntityHealth(ped, health)
end

--- Coupe les effets de mort de GTA (écran voilé), une fois qu'ils ont démarré.
function body.clearDeathEffects()
    AnimpostfxStopAll()
    SetTimeout(cfg.client.postFxDelayMs, AnimpostfxStopAll)
end

--- Relève le ped sur place avec la vie donnée.
---@param ratio number
function body.resurrect(ratio)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), 0, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    body.apply(ratio)
    AnimpostfxStopAll()
    IgnoreNextRestart(true)
end

--- Tir ami coupé : un client honnête ne tente même pas un coup natif sur un autre joueur (le serveur l'annulerait).
function body.protect()
    if not cfg.client.protect then return end
    NetworkSetFriendlyFireOption(false)
    SetCanAttackFriendly(PlayerPedId(), false, false)
end

--- Réglages de mort et de récupération (à chaque apparition : le changement de modèle en remet à zéro).
function body.configure()
    if not cfg.naturalRegen then SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0) end
    SetFadeOutAfterDeath(false)
    SetFadeInAfterDeathArrest(false)
    PauseDeathArrestRestart(true)
    IgnoreNextRestart(true)
    body.protect()
end

--- Geste de celui qui relève, pour la durée donnée (chargement de l'animation borné dans le temps).
---@param durationMs integer
function body.startGesture(durationMs)
    CreateThread(function()
        RequestAnimDict(gesture.dict)
        local deadline = GetGameTimer() + animation.loadTimeoutMs
        while not HasAnimDictLoaded(gesture.dict) do
            if GetGameTimer() > deadline then
                VavaHealth.log.warn("animation '%s' non chargée", gesture.dict)
                return
            end
            Wait(animation.loadPollMs)
        end
        TaskPlayAnim(PlayerPedId(), gesture.dict, gesture.clip, animation.blendIn, animation.blendOut, durationMs,
            gesture.flag, 0.0, false, false, false)
        RemoveAnimDict(gesture.dict)
    end)
end

function body.stopGesture()
    StopAnimTask(PlayerPedId(), gesture.dict, gesture.clip, 1.0)
end
