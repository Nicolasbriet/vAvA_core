-- ========================================
-- VAVA STATUS - CLIENT MAIN
-- Gestion client des effets visuels et HUD
-- ========================================

local CurrentHunger = 100
local CurrentThirst = 100
local CurrentEffects = {}
local ScreenEffectActive = nil

-- ========================================
-- INITIALISATION
-- ========================================

CreateThread(function()
    print("^2[vAvA Status]^7 Client initialisé")
    
    -- Attendre que le joueur soit chargé
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    -- Le HUD est géré par vAvA_core, pas besoin d'initialiser ici
    
    -- Démarrer la boucle d'effets
    StartEffectsLoop()
end)

-- ========================================
-- RECEIVE STATUS UPDATES
-- ========================================

RegisterNetEvent('vAvA_status:updateStatus')
AddEventHandler('vAvA_status:updateStatus', function(hunger, thirst)
    -- Mettre à jour les valeurs
    local oldHunger = CurrentHunger
    local oldThirst = CurrentThirst
    
    CurrentHunger = hunger
    CurrentThirst = thirst
    
    -- Envoyer au HUD central de vAvA_core
    TriggerEvent('vAvA_hud:updateStatus', {
        hunger = hunger,
        thirst = thirst
    })
    
    -- Vérifier si on change de niveau
    CheckLevelChange(oldHunger, hunger, 'hunger')
    CheckLevelChange(oldThirst, thirst, 'thirst')
    
    -- Appliquer les nouveaux effets
    ApplyEffects()
end)

-- ========================================
-- LEVEL CHANGE DETECTION
-- ========================================

function CheckLevelChange(oldValue, newValue, type)
    local oldLevel = GetStatusLevel(oldValue)
    local newLevel = GetStatusLevel(newValue)
    
    if oldLevel ~= newLevel then
        -- Afficher un message RP si nécessaire
        ShowRPMessage(newLevel, type)
    end
end

function GetStatusLevel(value)
    if value >= StatusConfig.Levels.normal.min then
        return "normal"
    elseif value >= StatusConfig.Levels.light.min then
        return "light"
    elseif value >= StatusConfig.Levels.warning.min then
        return "warning"
    elseif value > StatusConfig.Levels.danger.min then
        return "danger"
    else
        return "collapse"
    end
end

function ShowRPMessage(level, type)
    local messages = nil
    
    if level == "light" then
        messages = type == 'hunger' and StatusConfig.RPMessages.light_hunger or StatusConfig.RPMessages.light_thirst
    elseif level == "warning" then
        messages = type == 'hunger' and StatusConfig.RPMessages.warning_hunger or StatusConfig.RPMessages.warning_thirst
    elseif level == "danger" then
        messages = type == 'hunger' and StatusConfig.RPMessages.danger_hunger or StatusConfig.RPMessages.danger_thirst
    end
    
    if messages and #messages > 0 then
        local message = messages[math.random(#messages)]
        
        -- Afficher via le système de notification de vAvA_core
        TriggerEvent('vAvA_core:showNotification', message, 'warning', 5000)
        
        -- Fallback si pas de système de notification
        if not HasSystemNotification() then
            SetNotificationTextEntry('STRING')
            AddTextComponentString(message)
            DrawNotification(false, true)
        end
    end
end

function HasSystemNotification()
    -- Vérifier si vAvA_core a un système de notification
    return exports['vAvA_core'] and exports['vAvA_core'].showNotification ~= nil
end

-- ========================================
-- EFFECTS APPLICATION
-- ========================================

function StartEffectsLoop()
    CreateThread(function()
        while true do
            Wait(5000) -- Vérifier toutes les 5 secondes
            
            ApplyEffects()
        end
    end)
end

function ApplyEffects()
    local ped = PlayerPedId()
    
    -- Déterminer le niveau le plus critique
    local hungerLevel = GetStatusLevel(CurrentHunger)
    local thirstLevel = GetStatusLevel(CurrentThirst)
    
    -- Prendre le niveau le plus grave
    local worstLevel = GetWorstLevel(hungerLevel, thirstLevel)
    
    -- Appliquer les effets du niveau
    if worstLevel == "normal" then
        RemoveAllEffects()
    elseif worstLevel == "light" then
        ApplyLightEffects()
    elseif worstLevel == "warning" then
        ApplyWarningEffects()
    elseif worstLevel == "danger" then
        ApplyDangerEffects()
    elseif worstLevel == "collapse" then
        ApplyCollapseEffects()
    end
end

function GetWorstLevel(level1, level2)
    local levels = {"normal", "light", "warning", "danger", "collapse"}
    
    local index1 = 1
    local index2 = 1
    
    for i, level in ipairs(levels) do
        if level == level1 then index1 = i end
        if level == level2 then index2 = i end
    end
    
    return levels[math.max(index1, index2)]
end

function RemoveAllEffects()
    local ped = PlayerPedId()
    
    -- Restaurer la stamina normale
    ResetPlayerStamina(PlayerId())
    
    -- Retirer les effets d'écran
    if ScreenEffectActive then
        StopScreenEffect(ScreenEffectActive)
        ScreenEffectActive = nil
    end
    
    -- Restaurer la vitesse de marche
    ResetPedMovementClipset(ped, 0)
end

function ApplyLightEffects()
    local effects = StatusConfig.Levels.light.effects
    
    -- Réduire légèrement la stamina
    if effects.stamina then
        SetPlayerStaminaRechargeMultiplier(PlayerId(), effects.stamina)
    end
end

function ApplyWarningEffects()
    local effects = StatusConfig.Levels.warning.effects
    
    -- Réduire la stamina
    if effects.stamina then
        SetPlayerStaminaRechargeMultiplier(PlayerId(), effects.stamina)
    end
    
    -- Appliquer un léger flou
    if effects.screenEffect and StatusConfig.ScreenEffects[effects.screenEffect] then
        local screenEffect = StatusConfig.ScreenEffects[effects.screenEffect]
        
        if ScreenEffectActive ~= screenEffect.name then
            if ScreenEffectActive then
                StopScreenEffect(ScreenEffectActive)
            end
            
            StartScreenEffect(screenEffect.name, 0, true)
            ScreenEffectActive = screenEffect.name
        end
    end
end

function ApplyDangerEffects()
    local ped = PlayerPedId()
    local effects = StatusConfig.Levels.danger.effects
    
    -- Réduire fortement la stamina
    if effects.stamina then
        SetPlayerStaminaRechargeMultiplier(PlayerId(), effects.stamina)
    end
    
    -- Appliquer un flou important
    if effects.screenEffect and StatusConfig.ScreenEffects[effects.screenEffect] then
        local screenEffect = StatusConfig.ScreenEffects[effects.screenEffect]
        
        if ScreenEffectActive ~= screenEffect.name then
            if ScreenEffectActive then
                StopScreenEffect(ScreenEffectActive)
            end
            
            StartScreenEffect(screenEffect.name, 0, true)
            ScreenEffectActive = screenEffect.name
        end
    end
    
    -- Ralentir la marche
    if effects.walkSpeed then
        SetPedMoveRateOverride(ped, effects.walkSpeed)
    end
    
    -- Perte de vie progressive
    if effects.health and effects.health < 0 then
        CreateThread(function()
            while GetWorstLevel(GetStatusLevel(CurrentHunger), GetStatusLevel(CurrentThirst)) == "danger" do
                Wait(5000) -- Toutes les 5 secondes
                
                local currentHealth = GetEntityHealth(ped)
                if currentHealth > 100 then -- Ne pas tuer si déjà mort
                    SetEntityHealth(ped, currentHealth + effects.health)
                end
            end
        end)
    end
end

function ApplyCollapseEffects()
    local ped = PlayerPedId()
    local effects = StatusConfig.Levels.collapse.effects
    
    if effects.knockout then
        -- Mettre le joueur K.O.
        SetPedToRagdoll(ped, 10000, 10000, 0, 0, 0, 0)
        
        -- Réduire la vie à 0
        SetEntityHealth(ped, 0)
        
        -- Notification
        TriggerEvent('vAvA_core:showNotification', 'Vous êtes mort de faim/soif !', 'error', 10000)
    end
end

-- ========================================
-- ANIMATIONS
-- ========================================

RegisterNetEvent('vAvA_status:playAnimation')
AddEventHandler('vAvA_status:playAnimation', function(animType)
    if StatusConfig.TestMode and StatusConfig.TestConfig.skipAnimations then
        return
    end
    
    local animData = StatusConfig.Animations[animType]
    if not animData then return end
    
    local ped = PlayerPedId()
    
    -- Charger le dictionnaire d'animation
    RequestAnimDict(animData.dict)
    while not HasAnimDictLoaded(animData.dict) do
        Wait(100)
    end
    
    -- Jouer l'animation
    TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, -8.0, animData.duration, animData.flags, 0, false, false, false)
    
    -- Libérer le dictionnaire après utilisation
    Wait(animData.duration)
    RemoveAnimDict(animData.dict)
end)

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

function GetCurrentHunger()
    return CurrentHunger
end

function GetCurrentThirst()
    return CurrentThirst
end

-- ========================================
-- EXPORTS
-- ========================================

exports('GetCurrentHunger', GetCurrentHunger)
exports('GetCurrentThirst', GetCurrentThirst)

-- ========================================
-- DEBUG COMMANDS (si activé)
-- ========================================

if StatusConfig.Logging.enabled then
    RegisterCommand('debugstatus', function()
        print(string.format("^3[vAvA Status Debug]^7 Faim: %d, Soif: %d", CurrentHunger, CurrentThirst))
        print(string.format("^3[vAvA Status Debug]^7 Niveau Faim: %s, Niveau Soif: %s", 
            GetStatusLevel(CurrentHunger), GetStatusLevel(CurrentThirst)))
    end, false)
end
