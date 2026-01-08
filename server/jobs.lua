--[[
    vAvA_core - Server Jobs
    Système de jobs/métiers
]]

vCore = vCore or {}
vCore.Jobs = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Récupère un job par nom
---@param jobName string
---@return table|nil
function vCore.Jobs.Get(jobName)
    return Config.Jobs.List[jobName]
end

---Récupère tous les jobs
---@return table
function vCore.Jobs.GetAll()
    return Config.Jobs.List
end

---Définit le job d'un joueur
---@param source number
---@param jobName string
---@param grade number
---@return boolean
function vCore.Jobs.SetJob(source, jobName, grade)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = vCore.Jobs.Get(jobName)
    if not job then
        vCore.Utils.Warn('Job inexistant:', jobName)
        return false
    end
    
    if not job.grades[grade] then
        vCore.Utils.Warn('Grade inexistant:', jobName, grade)
        return false
    end
    
    local oldJob = player:GetJob()
    local success = player:SetJob(jobName, grade)
    
    if success then
        -- Log
        vCore.Log('job', player:GetIdentifier(), 
            'Job changé: ' .. oldJob.name .. ' -> ' .. jobName,
            {oldJob = oldJob.name, newJob = jobName, grade = grade}
        )
        
        -- Notification
        local gradeLabel = job.grades[grade].label
        vCore.Notify(source, Lang('job_changed', job.label, gradeLabel), 'info')
    end
    
    return success
end

---Récupère le job d'un joueur
---@param source number
---@return table|nil
function vCore.Jobs.GetPlayerJob(source)
    local player = vCore.GetPlayer(source)
    if not player then return nil end
    
    return player:GetJob()
end

---Vérifie si un joueur a un job spécifique
---@param source number
---@param jobName string
---@return boolean
function vCore.Jobs.HasJob(source, jobName)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    return player:GetJob().name == jobName
end

---Vérifie si un joueur a un grade minimum
---@param source number
---@param jobName string
---@param minGrade number
---@return boolean
function vCore.Jobs.HasGrade(source, jobName, minGrade)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    return job.name == jobName and job.grade >= minGrade
end

---Vérifie si un joueur a une permission job
---@param source number
---@param permission string
---@return boolean
function vCore.Jobs.HasPermission(source, permission)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    return player:HasJobPermission(permission)
end

---Définit l'état de service
---@param source number
---@param onDuty boolean
function vCore.Jobs.SetDuty(source, onDuty)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    player:SetDuty(onDuty)
    
    if onDuty then
        vCore.Notify(source, Lang('job_on_duty'), 'success')
    else
        vCore.Notify(source, Lang('job_off_duty'), 'info')
    end
end

---Promeut un joueur
---@param source number
---@return boolean
function vCore.Jobs.Promote(source)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    local nextGrade = job.grade + 1
    
    local jobConfig = vCore.Jobs.Get(job.name)
    if not jobConfig or not jobConfig.grades[nextGrade] then
        return false
    end
    
    return vCore.Jobs.SetJob(source, job.name, nextGrade)
end

---Rétrograde un joueur
---@param source number
---@return boolean
function vCore.Jobs.Demote(source)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    local prevGrade = job.grade - 1
    
    if prevGrade < 0 then return false end
    
    return vCore.Jobs.SetJob(source, job.name, prevGrade)
end

---Licencie un joueur (retour au job par défaut)
---@param source number
---@return boolean
function vCore.Jobs.Fire(source)
    local success = vCore.Jobs.SetJob(source, Config.Jobs.DefaultJob, Config.Jobs.DefaultGrade)
    
    if success then
        vCore.Notify(source, Lang('job_fired'), 'error')
    end
    
    return success
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetJob', function(jobName)
    return vCore.Jobs.Get(jobName)
end)

exports('SetJob', function(source, jobName, grade)
    return vCore.Jobs.SetJob(source, jobName, grade)
end)

exports('GetJobGrade', function(source)
    local player = vCore.GetPlayer(source)
    if player then
        return player:GetJob().grade
    end
    return 0
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Toggle service
RegisterNetEvent('vCore:toggleDuty', function()
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    vCore.Jobs.SetDuty(source, not player:IsOnDuty())
end)

-- Définir job (admin)
RegisterNetEvent('vCore:setJob', function(targetSource, jobName, grade)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player or not player:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    local success = vCore.Jobs.SetJob(targetSource, jobName, grade)
    
    if success then
        vCore.Notify(source, Lang('admin_job_set'), 'success')
    end
end)
