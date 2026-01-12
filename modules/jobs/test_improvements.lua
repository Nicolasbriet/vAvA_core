--[[
    Script de test pour les améliorations Jobs
    Commandes de test disponibles après restart du module jobs
]]

-- Test des nouvelles commandes
RegisterCommand('testjobs', function(source, args)
    if source == 0 then return end
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {0, 255, 0},
        args = {'[TEST JOBS]', 'Commandes disponibles:'}
    })
    
    local commands = {
        '/myjob - Ouvre la carte d\'informations job (interface moderne)',
        '/job - Affichage simple du job dans le chat',
        '/jobstats - Informations détaillées avec argent société',
        '/setjob [id] [job] [grade] - Changer le job d\'un joueur (admin)'
    }
    
    for _, cmd in pairs(commands) do
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 255, 255},
            args = {'', cmd}
        })
    end
end, false)

print('^2[vAvA Jobs] Améliorations chargées!^0')
print('^3[INFO] Utilisez /testjobs pour voir les nouvelles commandes^0')