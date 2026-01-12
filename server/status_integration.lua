-- ========================================
-- VAVA CORE - MODULE STATUS INTEGRATION
-- Initialisation automatique du module status
-- ========================================

CreateThread(function()
    print("^2[vAvA Core]^7 Vérification de l'intégration du module status...")
    
    -- Attendre jusqu'à 30 secondes que le module status soit disponible
    local timeout = 0
    local maxTimeout = 30 * 1000 -- 30 secondes
    
    while GetResourceState('vAvA_status') ~= 'started' and timeout < maxTimeout do
        print("^3[vAvA Core]^7 En attente du module status... (" .. timeout/1000 .. "s)")
        Wait(1000)
        timeout = timeout + 1000
    end
    
    if GetResourceState('vAvA_status') == 'started' then
        print("^2[vAvA Core]^7 Module status détecté et intégré avec succès !")
        
        -- Tester l'API
        local testResult = pcall(function()
            return exports['vAvA_status']:GetConsumableItems()
        end)
        
        if testResult then
            print("^2[vAvA Core]^7 API du module status opérationnelle")
        else
            print("^1[vAvA Core]^7 ERREUR: API du module status non fonctionnelle")
        end
    else
        print("^1[vAvA Core]^7 ATTENTION: Module status non disponible après 30s")
        print("^3[vAvA Core]^7 Assurez-vous que vAvA_status est ajouté dans server.cfg")
        print("^3[vAvA Core]^7 Fonctionnalités de faim/soif limitées en mode fallback")
    end
end)

-- Event pour synchroniser les status au chargement du joueur
RegisterNetEvent('vCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        -- Attendre que le joueur soit complètement chargé
        Wait(2000)
        
        if GetResourceState('vAvA_status') == 'started' then
            -- Demander une synchronisation des status
            TriggerServerEvent('vAvA_status:requestSync')
        end
    end)
end)