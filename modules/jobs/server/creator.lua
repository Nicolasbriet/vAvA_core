--[[
    vAvA Core - Module Jobs
    Server - Job Creator (Création dynamique de jobs)
]]

---Crée un nouveau job
RegisterNetEvent('vCore:jobs:createJob', function(jobData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    -- Validation
    if not jobData.name or not jobData.label then
        Notify(source, 'Nom et label requis', 'error')
        return
    end
    
    -- Vérifier si le job existe déjà
    if GetJob(jobData.name) then
        Notify(source, 'Ce job existe déjà', 'error')
        return
    end
    
    -- Créer le job en base de données
    local success, jobId = CreateJobInDatabase(jobData)
    
    if success then
        -- Ajouter le grade par défaut si fourni
        if jobData.grades and #jobData.grades > 0 then
            for _, gradeData in ipairs(jobData.grades) do
                AddJobGrade(jobData.name, gradeData)
            end
        else
            -- Grade par défaut
            AddJobGrade(jobData.name, {
                grade = 0,
                name = 'employee',
                label = 'Employé',
                salary = jobData.default_salary or 0,
                permissions = {}
            })
        end
        
        -- Recharger les jobs
        LoadJobsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, JobsConfig.Notifications.job_created, 'success')
        LogJobAction(jobData.name, player:GetIdentifier(), 'job_created',
            ('Job créé: %s'):format(jobData.label))
    else
        Notify(source, 'Erreur lors de la création du job', 'error')
    end
end)

---Met à jour un job existant
RegisterNetEvent('vCore:jobs:updateJob', function(jobName, jobData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    if not GetJob(jobName) then
        Notify(source, 'Job inexistant', 'error')
        return
    end
    
    local success = UpdateJobInDatabase(jobName, jobData)
    
    if success then
        LoadJobsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, JobsConfig.Notifications.job_updated, 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'job_updated',
            ('Job mis à jour: %s'):format(jobData.label))
    else
        Notify(source, 'Erreur lors de la mise à jour', 'error')
    end
end)

---Supprime un job
RegisterNetEvent('vCore:jobs:deleteJob', function(jobName)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    -- Vérifier que ce n'est pas un job système
    local protectedJobs = {'unemployed', 'ambulance', 'police', 'mechanic'}
    for _, protected in ipairs(protectedJobs) do
        if jobName == protected then
            Notify(source, 'Impossible de supprimer ce job', 'error')
            return
        end
    end
    
    local success = DeleteJobFromDatabase(jobName)
    
    if success then
        Jobs[jobName] = nil
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, JobsConfig.Notifications.job_deleted, 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'job_deleted',
            ('Job supprimé: %s'):format(jobName))
    else
        Notify(source, 'Erreur lors de la suppression', 'error')
    end
end)

---Ajoute un grade à un job
RegisterNetEvent('vCore:jobs:addGrade', function(jobName, gradeData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    if not GetJob(jobName) then
        Notify(source, 'Job inexistant', 'error')
        return
    end
    
    local success = AddJobGrade(jobName, gradeData)
    
    if success then
        LoadJobsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, JobsConfig.Notifications.grade_added, 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'grade_added',
            ('Grade ajouté: %s (niveau %d)'):format(gradeData.label, gradeData.grade))
    else
        Notify(source, 'Erreur lors de l\'ajout du grade', 'error')
    end
end)

---Met à jour un grade
RegisterNetEvent('vCore:jobs:updateGrade', function(jobName, grade, gradeData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success = UpdateJobGrade(jobName, grade, gradeData)
    
    if success then
        LoadJobsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, 'Grade mis à jour', 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'grade_updated',
            ('Grade mis à jour: %s (niveau %d)'):format(gradeData.label, grade))
    else
        Notify(source, 'Erreur lors de la mise à jour', 'error')
    end
end)

---Supprime un grade
RegisterNetEvent('vCore:jobs:removeGrade', function(jobName, grade)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success = DeleteJobGrade(jobName, grade)
    
    if success then
        LoadJobsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncJobs', -1, Jobs)
        
        Notify(source, JobsConfig.Notifications.grade_removed, 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'grade_removed',
            ('Grade supprimé: niveau %d'):format(grade))
    else
        Notify(source, 'Erreur lors de la suppression', 'error')
    end
end)

---Ajoute un véhicule à un job
RegisterNetEvent('vCore:jobs:addVehicle', function(jobName, vehicleData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success = AddJobVehicle(jobName, vehicleData)
    
    if success then
        Notify(source, 'Véhicule ajouté', 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'vehicle_added',
            ('Véhicule ajouté: %s'):format(vehicleData.label))
    else
        Notify(source, 'Erreur lors de l\'ajout', 'error')
    end
end)

---Ajoute une tenue à un job
RegisterNetEvent('vCore:jobs:addOutfit', function(jobName, outfitData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success = AddJobOutfit(jobName, outfitData)
    
    if success then
        Notify(source, 'Tenue ajoutée', 'success')
        LogJobAction(jobName, player:GetIdentifier(), 'outfit_added',
            ('Tenue ajoutée: %s'):format(outfitData.label))
    else
        Notify(source, 'Erreur lors de l\'ajout', 'error')
    end
end)

---Ajoute un item farmable à une interaction
RegisterNetEvent('vCore:jobs:addFarmItem', function(interactionId, itemData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success, id = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_farm_items (interaction_id, item_name, amount_min, amount_max, chance, required_item, remove_required, time, animation)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            interactionId,
            itemData.item_name,
            itemData.amount_min or 1,
            itemData.amount_max or 3,
            itemData.chance or 100,
            itemData.required_item,
            itemData.remove_required and 1 or 0,
            itemData.time or 5000,
            json.encode(itemData.animation or {})
        })
    end)
    
    if success and id then
        Notify(source, 'Item farmable ajouté', 'success')
    else
        Notify(source, 'Erreur lors de l\'ajout', 'error')
    end
end)

---Ajoute une recette de craft
RegisterNetEvent('vCore:jobs:addCraftRecipe', function(interactionId, recipeData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success, id = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_craft_recipes (interaction_id, name, label, result_item, result_amount, ingredients, time, required_grade)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            interactionId,
            recipeData.name,
            recipeData.label,
            recipeData.result_item,
            recipeData.result_amount or 1,
            json.encode(recipeData.ingredients),
            recipeData.time or 10000,
            recipeData.required_grade or 0
        })
    end)
    
    if success and id then
        Notify(source, 'Recette ajoutée', 'success')
    else
        Notify(source, 'Erreur lors de l\'ajout', 'error')
    end
end)

---Ajoute un item vendable
RegisterNetEvent('vCore:jobs:addSellItem', function(interactionId, itemData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success, id = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_sell_items (interaction_id, item_name, price, label)
            VALUES (?, ?, ?, ?)
        ]], {
            interactionId,
            itemData.item_name,
            itemData.price,
            itemData.label
        })
    end)
    
    if success and id then
        Notify(source, 'Item vendable ajouté', 'success')
    else
        Notify(source, 'Erreur lors de l\'ajout', 'error')
    end
end)

---Liste tous les jobs (pour admin)
RegisterNetEvent('vCore:jobs:adminGetAllJobs', function()
    local source = source
    
    if not IsPlayerAdmin(source) then
        return
    end
    
    TriggerClientEvent('vCore:jobs:receiveAllJobs', source, Jobs)
end)
