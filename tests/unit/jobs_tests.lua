--[[
    vAvA_jobs - Tests Unitaires
    Tests du système de jobs
]]

return {
    {
        name = 'test_jobs_initialization',
        type = 'critical',
        description = 'Vérifie que le module jobs est initialisé',
        run = function(ctx)
            local hasExport = pcall(function()
                exports['vAvA_jobs']:GetJobs()
            end)
            
            ctx.assert.isTrue(hasExport, 'Le module jobs doit avoir des exports')
        end
    },
    
    {
        name = 'test_get_jobs',
        type = 'unit',
        description = 'Vérifie la récupération de la liste des jobs',
        run = function(ctx)
            local jobs = exports['vAvA_jobs']:GetJobs()
            
            ctx.assert.isNotNil(jobs, 'La liste des jobs ne doit pas être nil')
            ctx.assert.isType(jobs, 'table', 'La liste doit être une table')
            ctx.assert.isTrue(#jobs > 0, 'Il doit y avoir au moins 1 job')
        end
    },
    
    {
        name = 'test_default_jobs_exist',
        type = 'critical',
        description = 'Vérifie que les jobs par défaut existent',
        run = function(ctx)
            local jobs = exports['vAvA_jobs']:GetJobs()
            local hasUnemployed = false
            local hasPolice = false
            
            for _, job in pairs(jobs) do
                if job.name == 'unemployed' then hasUnemployed = true end
                if job.name == 'police' then hasPolice = true end
            end
            
            ctx.assert.isTrue(hasUnemployed, 'Le job unemployed doit exister')
            ctx.assert.isTrue(hasPolice, 'Le job police doit exister')
        end
    },
    
    {
        name = 'test_job_grades',
        type = 'unit',
        description = 'Vérifie le système de grades',
        run = function(ctx)
            -- Vérifier que l'export existe
            local hasExport = pcall(function()
                return exports['vAvA_jobs']:GetJobGrades
            end)
            
            if not hasExport then
                ctx.skip('Export GetJobGrades non disponible')
                return
            end
            
            local grades = exports['vAvA_jobs']:GetJobGrades('police')
            
            if not grades then
                ctx.skip('Aucun grade trouvé pour police')
                return
            end
            
            ctx.assert.isType(grades, 'table', 'Les grades doivent être une table')
        end
    },
    
    {
        name = 'test_set_job',
        type = 'integration',
        description = 'Vérifie l\'attribution d\'un job',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Attribuer un job
            local success = exports['jobs']:SetJob(testPlayer, 'police', 0)
            
            ctx.assert.isTrue(success, 'Le job doit être attribué')
        end
    },
    
    {
        name = 'test_get_player_job',
        type = 'unit',
        description = 'Vérifie la récupération du job d\'un joueur',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Attribuer puis récupérer
            exports['jobs']:SetJob(testPlayer, 'police', 1)
            local job = exports['jobs']:GetPlayerJob(testPlayer)
            
            ctx.assert.isNotNil(job, 'Le job ne doit pas être nil')
            ctx.assert.equals(job.name, 'police', 'Le nom du job doit être police')
            ctx.assert.equals(job.grade, 1, 'Le grade doit être 1')
        end
    },
    
    {
        name = 'test_job_salary',
        type = 'integration',
        description = 'Vérifie le système de salaire',
        run = function(ctx)
            -- Récupérer le salaire pour un job/grade
            local salary = exports['jobs']:GetSalary('police', 1)
            
            ctx.assert.isNotNil(salary, 'Le salaire ne doit pas être nil')
            ctx.assert.isType(salary, 'number', 'Le salaire doit être un nombre')
            ctx.assert.isTrue(salary >= 0, 'Le salaire doit être >= 0')
        end
    },
    
    {
        name = 'test_job_permissions',
        type = 'security',
        description = 'Vérifie le système de permissions par job',
        run = function(ctx)
            local testPlayer = 'test_player_' .. os.time()
            
            -- Attribuer un job
            exports['jobs']:SetJob(testPlayer, 'police', 2)
            
            -- Vérifier une permission
            local hasPerm = exports['jobs']:HasJobPermission(testPlayer, 'arrest')
            
            ctx.assert.isType(hasPerm, 'boolean', 'La permission doit retourner un booléen')
        end
    }
}
