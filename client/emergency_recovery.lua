-- ========================================
-- COMMANDE D'URGENCE - RÉCUPÉRATION VIE
-- À exécuter immédiatement pour récupérer
-- ========================================

-- Commande pour récupérer immédiatement
RegisterCommand('emergency_heal', function()
    -- Récupérer la vie complètement
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    
    -- Récupérer la faim et la soif
    TriggerServerEvent('vAvA_status:requestSync')
    
    if GetResourceState('vAvA_status') == 'started' then
        -- Forcer des valeurs élevées via le serveur
        TriggerServerEvent('vCore:admin:setHunger', 100)
        TriggerServerEvent('vCore:admin:setThirst', 100)
    end
    
    print("^2[URGENCE]^7 Vie, faim et soif récupérées !")
    TriggerEvent('chat:addMessage', {
        args = { "^2[URGENCE]", "Vie récupérée ! Mangez/buvez pour éviter que ça se reproduise." }
    })
end, false)

-- DEBUG: Monitorer la santé en temps réel pour trouver la source des dégâts
local healthMonitorActive = false
RegisterCommand('debug_health_monitor', function()
    healthMonitorActive = not healthMonitorActive
    
    if healthMonitorActive then
        print("^3[DEBUG]^7 Monitoring santé ACTIVÉ - Regardez la console F8")
        local lastHealth = GetEntityHealth(PlayerPedId())
        
        CreateThread(function()
            while healthMonitorActive do
                local ped = PlayerPedId()
                local currentHealth = GetEntityHealth(ped)
                
                if currentHealth ~= lastHealth then
                    local diff = currentHealth - lastHealth
                    local color = diff < 0 and "^1" or "^2"
                    print(string.format("%s[HEALTH CHANGE]^7 %d -> %d (diff: %s%d^7)", 
                        color, lastHealth, currentHealth, color, diff))
                    lastHealth = currentHealth
                end
                
                Wait(100) -- Check every 100ms
            end
        end)
    else
        print("^3[DEBUG]^7 Monitoring santé DÉSACTIVÉ")
    end
end, false)

-- Commande pour obtenir des items de survie
RegisterCommand('emergency_food', function()
    -- Ajouter des items via le serveur
    for i = 1, 10 do
        TriggerServerEvent('vCore:giveItem', 'bread')
        TriggerServerEvent('vCore:giveItem', 'water')
    end
    
    print("^2[URGENCE]^7 Items de survie ajoutés !")
    TriggerEvent('chat:addMessage', {
        args = { "^2[URGENCE]", "10 pains et 10 bouteilles d'eau ajoutés à votre inventaire !" }
    })
end, false)

-- Commande pour tester et synchroniser le HUD
RegisterCommand('testhudstatus', function()
    print("^2[TEST HUD]^7 Test de synchronisation HUD...")
    
    -- Vérifier l'état des modules
    print("^3[TEST HUD]^7 État vAvA_core:", GetResourceState('vAvA_core'))
    print("^3[TEST HUD]^7 État vAvA_hud:", GetResourceState('vAvA_hud'))
    print("^3[TEST HUD]^7 État vAvA_status:", GetResourceState('vAvA_status'))
    
    -- Demander une synchronisation
    if GetResourceState('vAvA_status') == 'started' then
        TriggerServerEvent('vAvA_status:requestSync')
        print("^2[TEST HUD]^7 Synchronisation demandée au module status")
    end
    
    -- Tester les exports
    if GetResourceState('vAvA_status') == 'started' then
        local hunger = exports['vAvA_status']:GetCurrentHunger()
        local thirst = exports['vAvA_status']:GetCurrentThirst()
        print(string.format("^3[TEST HUD]^7 Valeurs directes - Hunger: %s, Thirst: %s", 
            tostring(hunger), tostring(thirst)))
    end
    
    -- Vérifier vCore
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.PlayerData and vCore.PlayerData.status then
        print(string.format("^3[TEST HUD]^7 vCore status - Hunger: %s, Thirst: %s",
            tostring(vCore.PlayerData.status.hunger), tostring(vCore.PlayerData.status.thirst)))
    else
        print("^1[TEST HUD]^7 Aucune donnée status dans vCore")
    end
end, false)

print("^2[URGENCE]^7 Commandes d'urgence chargées :")
print("^3[URGENCE]^7 /emergency_heal - Récupère vie + faim/soif")
print("^3[URGENCE]^7 /emergency_food - Donne des items de survie")