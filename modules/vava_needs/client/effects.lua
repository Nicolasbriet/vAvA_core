--[[
    vava_needs/client/effects.lua
    Rôle : effets des besoins sur le joueur local, déduits des valeurs reçues (aucun échange réseau en plus) :
      - message au franchissement d'un palier vers le bas (bas, critique, épuisé), par vava_hud si présent ;
      - endurance maximale réduite tant qu'un besoin est critique (native persistante : aucune boucle) ;
      - perte de vie demandée par le serveur (plancher configuré tant qu'aucun module ne gère la mise à terre) ;
      - geste de consommation (animation du haut du corps, sans accessoire).
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local ipairs, ceil, max = ipairs, math.ceil, math.max
local CreateThread, Wait, GetGameTimer, GetResourceState = CreateThread, Wait, GetGameTimer, GetResourceState
local PlayerId, PlayerPedId, IsEntityDead = PlayerId, PlayerPedId, IsEntityDead
local GetEntityHealth, GetEntityMaxHealth, SetEntityHealth = GetEntityHealth, GetEntityMaxHealth, SetEntityHealth
local GetPlayerMaxStamina, SetPlayerMaxStamina = GetPlayerMaxStamina, SetPlayerMaxStamina
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict, TaskPlayAnim = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict, TaskPlayAnim

local cfg = VavaNeeds.config
local thresholds = cfg.thresholds
local health = cfg.health
local animation = cfg.animation
local log = VavaNeeds.log

-- module qui gère la mise à terre : avec lui, un besoin épuisé peut faire tomber le joueur
local DEATH_SYSTEM = 'vava_health'
-- paliers, du moins grave au plus grave ; 0 = besoin satisfait
local LEVELS = { 'low', 'critical', 'empty' }
local KINDS = { 'info', 'warning', 'danger' }
local CRITICAL = 2

local effects = {}
VavaNeeds.effects = effects

---@param value number
---@return integer level  0 à 3
local function levelOf(value)
    if value <= 0 then return 3 end
    if value <= thresholds.critical then return 2 end
    if value <= thresholds.low then return 1 end
    return 0
end

-- Endurance ------------------------------------------------------------------------------------------------

-- endurance maximale habituelle, lue avant la première réduction
local baseline = nil
local weakened = false

---@param enabled boolean
local function setWeakened(enabled)
    if enabled == weakened then return end
    local player = PlayerId()
    if enabled then
        baseline = baseline or GetPlayerMaxStamina(player)
        SetPlayerMaxStamina(player, baseline * cfg.criticalStamina)
    elseif baseline then
        SetPlayerMaxStamina(player, baseline)
    end
    weakened = enabled
end

---@param values table<string, number>
---@return boolean
local function anyCritical(values)
    for _, need in ipairs(cfg.needs) do
        if levelOf(values[need.name]) >= CRITICAL then return true end
    end
    return false
end

--- Nouvelles valeurs : messages des paliers franchis vers le bas, endurance.
---@param values table<string, number>
---@param previous table<string, number>|nil  nil au chargement du personnage : les paliers déjà atteints sont annoncés
function effects.update(values, previous)
    for _, need in ipairs(cfg.needs) do
        local level = levelOf(values[need.name])
        local before = previous and levelOf(previous[need.name]) or 0
        -- client/hud.lua est chargé après ce fichier : lu au moment de l'appel
        if level > before then VavaNeeds.hud.notify(need.messages[LEVELS[level]], KINDS[level]) end
    end
    setWeakened(anyCritical(values))
end

--- Après une apparition : le jeu a pu remettre l'endurance d'origine (changement de modèle).
---@param values table<string, number>|nil
function effects.refresh(values)
    if weakened and baseline then SetPlayerMaxStamina(PlayerId(), baseline) end
    weakened = false
    if values then setWeakened(anyCritical(values)) end
end

--- Personnage déchargé ou module arrêté : endurance d'origine rendue.
function effects.reset()
    setWeakened(false)
    baseline = nil
end

-- Vie et gestes --------------------------------------------------------------------------------------------------

--- Perte de vie d'un besoin épuisé. Sans système de mise à terre, jamais sous le plancher (part de la vie au-dessus
--- du seuil de mise à terre) ; avec vava_health, le joueur peut tomber, puis être relevé.
---@param amount number
function effects.starve(amount)
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return end
    local down = health.downThreshold
    local floorRatio = GetResourceState(DEATH_SYSTEM) == 'started' and 0 or health.floor
    local minimum = ceil(down + floorRatio * (GetEntityMaxHealth(ped) - down))
    local current = GetEntityHealth(ped)
    if current <= minimum then return end
    SetEntityHealth(ped, max(minimum, current - amount))
end

--- Joue un geste de consommation (manger, boire). Le chargement de l'animation est borné dans le temps.
---@param name string
function effects.gesture(name)
    local gesture = cfg.gestures[name]
    if not gesture then return end
    CreateThread(function()
        local dict = gesture.dict
        RequestAnimDict(dict)
        local deadline = GetGameTimer() + animation.loadTimeoutMs
        while not HasAnimDictLoaded(dict) do
            if GetGameTimer() > deadline then
                log.warn("animation '%s' non chargée", dict)
                return
            end
            Wait(animation.loadPollMs)
        end
        local ped = PlayerPedId()
        if not IsEntityDead(ped) then
            TaskPlayAnim(ped, dict, gesture.clip, animation.blendIn, animation.blendOut, cfg.consumption.cooldownMs,
                animation.flag, 0.0, false, false, false)
        end
        RemoveAnimDict(dict)
    end)
end
