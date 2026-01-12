--[[
    Test des corrections du module Jobs
    Ce fichier peut être utilisé pour tester les nouvelles fonctionnalités
]]

print('=== TEST DES CORRECTIONS JOBS MODULE ===')

-- Test de base: vérifier que vCore existe
CreateThread(function()
    Wait(2000)  -- Attendre le chargement
    
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    if vCore then
        print('^2[TEST] vCore correctement chargé^0')
        
        -- Test des fonctions vCore
        if vCore.GetPlayer then
            print('^2[TEST] Méthode GetPlayer disponible^0')
        else
            print('^1[TEST] ERREUR: Méthode GetPlayer introuvable^0')
        end
        
        if vCore.GetPlayers then
            print('^2[TEST] Méthode GetPlayers disponible^0')
            local players = vCore.GetPlayers()
            print('^3[TEST] Joueurs connectés: ' .. (type(players) == 'table' and #players or 'N/A') .. '^0')
        else
            print('^1[TEST] ERREUR: Méthode GetPlayers introuvable^0')
        end
    else
        print('^1[TEST] ERREUR: vCore non chargé^0')
    end
end)

-- Test de la nouvelle fonction GetValidPlayer
RegisterCommand('testjobfix', function(source, args)
    print('^3[TEST] Test de la fonction GetValidPlayer pour source: ' .. source .. '^0')
    
    -- Simuler la fonction GetValidPlayer
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    if not vCore then
        print('^1[TEST] ERREUR: vCore non initialisé^0')
        return
    end
    
    local player = vCore.GetPlayer(source)
    if not player then
        print('^1[TEST] ERREUR: Joueur introuvable pour source: ' .. source .. '^0')
        return
    end
    
    print('^2[TEST] Joueur trouvé, analyse de la structure:^0')
    
    -- Test des différentes méthodes d'accès au job
    local jobData = nil
    local method = "aucune"
    
    -- Méthode 1: Via GetJob()
    if type(player.GetJob) == 'function' then
        local success, result = pcall(function()
            return player:GetJob()
        end)
        if success and result then
            jobData = result
            method = "GetJob()"
        end
    end
    
    -- Méthode 2: Via PlayerData.job
    if not jobData and player.PlayerData and player.PlayerData.job then
        jobData = player.PlayerData.job
        method = "PlayerData.job"
    end
    
    -- Méthode 3: Accès direct
    if not jobData and player.job then
        jobData = player.job
        method = "job direct"
    end
    
    if jobData then
        print('^2[TEST] Job récupéré via: ' .. method .. '^0')
        print('^3[TEST] Job: ' .. (jobData.label or jobData.name or 'N/A') .. '^0')
        print('^3[TEST] Grade: ' .. (jobData.gradeLabel or jobData.grade_label or 'Grade ' .. (jobData.grade or 0)) .. '^0')
        print('^3[TEST] Salaire: $' .. (jobData.salary or 0) .. '^0')
    else
        print('^1[TEST] ERREUR: Impossible de récupérer les données job^0')
    end
end)

print('^2[TEST] Fichier de test chargé. Utilisez /testjobfix en jeu pour tester^0')