-- ========================================
-- VAVA STATUS - CLIENT MAIN
-- Gestion client des effets visuels et HUD
-- DÉLÈGUE TOUTE LA GESTION DE VIE AU MODULE EMS
-- ========================================

local CurrentHunger = 100
local CurrentThirst = 100
local CurrentEffects = {}
local ScreenEffectActive = nil
local LastEMSNotification = nil  -- Pour éviter le spam de notifications EMS
local EMSNotificationCooldown = 30000  -- 30 secondes entre chaque notification EMS

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

-- Protection contre la mort en boucle: réinitialiser les status au respawn
AddEventHandler('playerSpawned', function()
    print("^2[vAvA Status]^7 Joueur respawn détecté - demande de sync des status")
    -- Attendre un peu pour laisser le temps au serveur
    Wait(2000)
    -- Demander une synchronisation des status depuis le serveur
    TriggerServerEvent('vAvA_status:requestSync')
end)

-- ========================================
-- RECEIVE STATUS UPDATES
-- ========================================

RegisterNetEvent('vAvA_status:updateStatus')
AddEventHandler('vAvA_status:updateStatus', function(hunger, thirst)
    print(string.format("^6[Status DEBUG]^7 Réception status - Hunger: %.1f -> %.1f, Thirst: %.1f -> %.1f", 
        CurrentHunger, hunger, CurrentThirst, thirst))
    
    -- Mettre à jour les valeurs
    local oldHunger = CurrentHunger
    local oldThirst = CurrentThirst
    
    CurrentHunger = hunger
    CurrentThirst = thirst
    
    -- Envoyer au HUD central de vAvA_core de manière optimisée
    TriggerEvent('vAvA_hud:updateStatus', {
        hunger = hunger,
        thirst = thirst
    })
    
    -- Aussi déclencher un event pour le core si le module hud n'est pas présent
    TriggerEvent('vCore:status:updated', {
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
    elseif value > StatusConfig.Levels.critical.max then
        -- danger: 5-20 (valeur > 5 et < 20)
        return "danger"
    elseif value > 0 then
        -- critical: 0-5 (valeur > 0 et <= 5)
        return "critical"
    else
        -- collapse: exactement 0
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
    elseif worstLevel == "critical" then
        ApplyCriticalEffects()  -- Nouveau niveau
    elseif worstLevel == "collapse" then
        ApplyCollapseEffects()
    end
end

function GetWorstLevel(level1, level2)
    local levels = {"normal", "light", "warning", "danger", "critical", "collapse"}
    
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
    
    -- Notifier le module EMS que le joueur s'est rétabli (s'il était en danger avant)
    if LastEMSNotification then
        TriggerServerEvent('vAvA_status:emsNotify', {
            level = "recovered",
            hunger = CurrentHunger,
            thirst = CurrentThirst,
            condition = nil
        })
        print("^2[Status -> EMS]^7 Notification de récupération envoyée")
        LastEMSNotification = nil  -- Reset pour éviter les notifications en double
    end
end

function ApplyLightEffects()
    local effects = StatusConfig.Levels.light.effects
    
    -- Réduire légèrement la stamina max
    if effects.stamina then
        -- Utiliser SetRunSprintMultiplierForPlayer pour affecter la vitesse de sprint
        SetRunSprintMultiplierForPlayer(PlayerId(), effects.stamina)
    end
end

function ApplyWarningEffects()
    local effects = StatusConfig.Levels.warning.effects
    
    -- Réduire la stamina/sprint
    if effects.stamina then
        SetRunSprintMultiplierForPlayer(PlayerId(), effects.stamina)
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
    
    -- Réduire la stamina/sprint
    if effects.stamina then
        SetRunSprintMultiplierForPlayer(PlayerId(), effects.stamina)
    end
    
    -- Appliquer un effet d'écran léger
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
    
    -- PAS de perte de vie dans le niveau "danger" - déléguée au module EMS
    -- Notifier le module EMS du niveau danger
    NotifyEMS("danger", CurrentHunger, CurrentThirst)
end

-- ========================================
-- EMS NOTIFICATION SYSTEM
-- Délègue toute la gestion de vie au module EMS
-- ========================================

function NotifyEMS(level, hunger, thirst)
    -- Vérifier le cooldown pour éviter le spam
    local now = GetGameTimer()
    if LastEMSNotification and (now - LastEMSNotification) < EMSNotificationCooldown then
        return
    end
    
    LastEMSNotification = now
    
    -- Déterminer la condition médicale
    local condition = nil
    if StatusConfig.EMSIntegration and StatusConfig.EMSIntegration.medicalConditions then
        if level == "critical" then
            if hunger <= 5 and thirst <= 5 then
                condition = "malnutrition_severe"
            elseif hunger <= 5 then
                condition = "malnutrition_severe"
            else
                condition = "dehydration_severe"
            end
        elseif level == "danger" then
            if hunger <= 20 then
                condition = "malnutrition"
            else
                condition = "dehydration"
            end
        elseif level == "collapse" then
            condition = "malnutrition_severe"  -- Ou dehydration_severe selon le cas
        end
    end
    
    -- Envoyer l'event au serveur pour le module EMS
    -- On utilise toujours le même event, le serveur redistribuera aux modules concernés
    TriggerServerEvent('vAvA_status:emsNotify', {
        level = level,
        hunger = hunger,
        thirst = thirst,
        condition = condition
    })
    print(string.format("^5[Status -> EMS]^7 Notification envoyée: vAvA_status:emsNotify (level=%s, condition=%s)", level, condition or "none"))
end

function ApplyCriticalEffects()
    local ped = PlayerPedId()
    local effects = StatusConfig.Levels.critical and StatusConfig.Levels.critical.effects
    
    if not effects then return end
    
    -- Réduire fortement la stamina/sprint
    if effects.stamina then
        SetRunSprintMultiplierForPlayer(PlayerId(), effects.stamina)
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
    
    -- DÉLÉGATION AU MODULE EMS: Pas de gestion de vie ici
    -- Notifier le module EMS de l'état critique
    NotifyEMS("critical", CurrentHunger, CurrentThirst)
    
    -- Afficher un avertissement au joueur
    TriggerEvent('vAvA_core:showNotification', 'État critique ! Mangez/buvez rapidement ou consultez un médecin !', 'error', 5000)
end

function ApplyCollapseEffects()
    local ped = PlayerPedId()
    local effects = StatusConfig.Levels.collapse.effects
    
    -- PROTECTION: Ne pas appliquer si le joueur est déjà mort
    local currentHealth = GetEntityHealth(ped)
    if currentHealth <= 101 then
        print("^3[Status DEBUG]^7 ApplyCollapseEffects ignoré - joueur déjà mort ou en train de respawn")
        return
    end
    
    -- PROTECTION: Ne pas appliquer si le module est désactivé
    if not StatusConfig.Enabled then
        print("^3[Status DEBUG]^7 ApplyCollapseEffects ignoré - module désactivé")
        return
    end
    
    -- DÉLÉGATION AU MODULE EMS: Notifier de l'effondrement
    NotifyEMS("collapse", CurrentHunger, CurrentThirst)
    
    -- Effets visuels seulement (pas de mort)
    if effects and effects.screenEffect and StatusConfig.ScreenEffects[effects.screenEffect] then
        local screenEffect = StatusConfig.ScreenEffects[effects.screenEffect]
        StartScreenEffect(screenEffect.name, 0, true)
        ScreenEffectActive = screenEffect.name
    end
    
    -- Mettre le joueur en ragdoll temporaire (malaise)
    print("^5[Status -> EMS]^7 Joueur en état de collapse - délégué au module EMS")
    if effects and effects.knockout then
        SetPedToRagdoll(ped, 5000, 5000, 0, 0, 0, 0)
        TriggerEvent('vAvA_core:showNotification', 'Vous êtes gravement affaibli ! Appelez un médecin !', 'error', 5000)
    end
end

-- Commande pour diagnostiquer les levels de status (debug)
RegisterCommand('debug_status_levels', function()
    print("^6=== DEBUG STATUS LEVELS ===^7")
    print("^2[Status DEBUG]^7 Current Hunger:", string.format("%.1f", CurrentHunger))
    print("^2[Status DEBUG]^7 Current Thirst:", string.format("%.1f", CurrentThirst))
    
    local hungerLevel = GetStatusLevel(CurrentHunger)
    local thirstLevel = GetStatusLevel(CurrentThirst)
    local worstLevel = GetWorstLevel(hungerLevel, thirstLevel)
    
    print("^2[Status DEBUG]^7 Hunger Level:", hungerLevel)
    print("^2[Status DEBUG]^7 Thirst Level:", thirstLevel)
    print("^2[Status DEBUG]^7 Worst Level:", worstLevel)
    
    -- Tester les seuils manuellement
    print("^6[Status DEBUG]^7 Seuils test:")
    for levelName, config in pairs(StatusConfig.Levels) do
        if config.min and config.max then
            local hungerInRange = (CurrentHunger >= config.min and CurrentHunger <= config.max)
            local thirstInRange = (CurrentThirst >= config.min and CurrentThirst <= config.max)
            print(string.format("^2[Status DEBUG]^7 %s (%.0f-%.0f): Hunger=%s Thirst=%s", 
                levelName, config.min, config.max, hungerInRange, thirstInRange))
        end
    end
    
    print("^6=== FIN DEBUG STATUS LEVELS ===^7")
end, false)

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

function GetCurrentStatusLevel()
    local hungerLevel = GetStatusLevel(CurrentHunger)
    local thirstLevel = GetStatusLevel(CurrentThirst)
    return GetWorstLevel(hungerLevel, thirstLevel)
end

function IsPlayerCritical()
    local level = GetCurrentStatusLevel()
    return level == "critical" or level == "collapse"
end

function IsPlayerDanger()
    local level = GetCurrentStatusLevel()
    return level == "danger" or level == "critical" or level == "collapse"
end

-- ========================================
-- EXPORTS POUR MODULE EMS
-- ========================================

exports('GetCurrentHunger', GetCurrentHunger)
exports('GetCurrentThirst', GetCurrentThirst)
exports('GetCurrentStatusLevel', GetCurrentStatusLevel)
exports('IsPlayerCritical', IsPlayerCritical)
exports('IsPlayerDanger', IsPlayerDanger)

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
