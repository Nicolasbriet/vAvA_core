--[[
    vava_combat/client/mode.lua
    Rôle : le mode combat (patron de vava_magic/client/controls.lua : éveillé / actif) et les touches du combat.
      - Éveil : seulement par une touche du combat (attaque légère, lourde, verrou) quand l'arme en main a un style.
        Arme sans technique : « Vous ne connaissez aucune technique pour cette arme. », une fois par arme sortie. Arme
        en main sans rien presser : RIEN ne tourne.
      - Actif : arme en garde ou non, à pied, debout, pas à terre, pas ligoté, aucune interface au focus, pas de menu
        natif (relevé toutes les `mode.conditionsMs` tant qu'il est éveillé, jamais à chaque image).
      - Sommeil : `mode.idleMs` sans coup ni appui sur le verrou ; aussitôt quand la main change (rengainer, autre
        arme) ou que le personnage est déchargé. Endormi : verrou relâché, touche gardée oubliée, boucle terminée.
      - Boucle : la seule du module qui tourne à chaque image, et seulement éveillée ET active : contrôles de GTA
        coupés (`mode.blocked` : attaque, visée, corps à corps, roue et changement d'arme ; jamais Échap ni P, lus par
        vava_pause), anneau sous la cible verrouillée, relevé du verrou, touche gardée, virage vers la cible. Éveillée
        mais inactive : relevé toutes les `conditionsMs`.
    Le serveur revérifie tout : le mode ne fait que montrer et demander.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, bridge/client.lua, client/hands.lua,
                  client/keys.lua, client/targeting.lua, client/attack.lua
]]

local ipairs = ipairs
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, IsEntityDead, IsPedInAnyVehicle, IsPedRagdoll, IsPedFalling, IsPedCuffed =
    PlayerPedId, IsEntityDead, IsPedInAnyVehicle, IsPedRagdoll, IsPedFalling, IsPedCuffed
local IsNuiFocused, IsPauseMenuActive, DisableControlAction = IsNuiFocused, IsPauseMenuActive, DisableControlAction

local core = VavaCombat.core
if not core then return end

local cfg = VavaCombat.config
local modeCfg = cfg.mode
local bridge = VavaCombat.bridge
local hands = VavaCombat.hands
local keys = VavaCombat.keys
local targeting = VavaCombat.targeting
local attack = VavaCombat.attack

local mode = {}
VavaCombat.mode = mode

local awake, active, running = false, false, false
local lastActivity = 0
-- refus « aucune technique pour cette arme » déjà dit pour l'arme sortie
local noStyleNoticed = false

--- Vrai si l'arme en main a des techniques (style connu de la config).
---@return boolean
local function hasStyle()
    local style = hands.style()
    return style ~= nil and cfg.styles[style] ~= nil
end

---@param ped integer
---@return boolean
local function conditionsMet(ped)
    local armed = hands.armed()
    if not armed or armed.sheathing or not hasStyle() then return false end
    if ped == 0 or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsPedFalling(ped)
        or IsPedCuffed(ped) then
        return false
    end
    if IsNuiFocused() or IsPauseMenuActive() then return false end
    return not bridge.IsDowned()
end

---@param value boolean
local function setActive(value)
    if active == value then return end
    active = value
    if not value then attack.reset() end
end

local function run()
    if running then return end
    running = true
    CreateThread(function()
        local nextCheck = GetGameTimer() + modeCfg.conditionsMs
        local nextLock = 0
        while awake do
            local now = GetGameTimer()
            if now - lastActivity > modeCfg.idleMs and not attack.busy(now) then
                awake = false
                break
            end
            local ped = PlayerPedId()
            if now >= nextCheck then
                nextCheck = now + modeCfg.conditionsMs
                setActive(conditionsMet(ped))
            end
            if active then
                -- boucle par image justifiée : mode combat éveillé et actif (touches de GTA coupées, anneau, virage)
                for _, control in ipairs(modeCfg.blocked) do DisableControlAction(0, control, true) end
                if now >= nextLock then
                    nextLock = now + cfg.lock.checkMs
                    targeting.check()
                end
                targeting.draw(now)
                attack.tick(now, ped)
                Wait(0)
            else
                Wait(modeCfg.conditionsMs)
            end
        end
        setActive(false)
        targeting.release()
        attack.reset()
        running = false
    end)
end

--- Réveille le mode combat (touche du combat). Rend faux sans arme en garde ou sans technique pour l'arme (dit une fois
--- par arme sortie).
---@return boolean
function mode.wake()
    local armed = hands.armed()
    if not armed or armed.sheathing then return false end
    if not hasStyle() then
        if not noStyleNoticed then
            noStyleNoticed = true
            attack.notice('no_style')
        end
        return false
    end
    lastActivity = GetGameTimer()
    if not awake then
        awake = true
        setActive(conditionsMet(PlayerPedId()))
        run()
    end
    return true
end

--- Endort le mode combat (main changée, personnage déchargé) : la boucle se termine d'elle-même.
function mode.sleep()
    awake = false
    targeting.release()
    attack.reset()
end

--- Vrai si le mode combat est éveillé et actif (export client inCombatMode).
---@return boolean
function mode.isActive()
    return awake and active
end

---@param slot string
local function onAttack(slot)
    if not mode.wake() or not active then return end
    attack.press(slot)
end

-- la main change (rengainer, autre arme, déchargement) : le mode s'endort, le refus « sans technique » pourra être redit
hands.onChange(function()
    noStyleNoticed = false
    if awake then mode.sleep() end
end)

keys.bind('legere', function() onAttack('legere') end)
keys.bind('lourde', function() onAttack('lourde') end)
keys.bindHold('cible', function()
    if mode.wake() and active then targeting.pressed() end
end, function()
    targeting.released()
end)
