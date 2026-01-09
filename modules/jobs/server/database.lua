--[[
    vAvA Core - Module Jobs
    Server - Database Functions
]]

---Crée un nouveau job en base de données
---@param jobData table
---@return boolean, number|nil
function CreateJobInDatabase(jobData)
    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO jobs_config (name, label, icon, description, type, default_salary, whitelisted, society_account, blip, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            jobData.name,
            jobData.label,
            jobData.icon or 'briefcase',
            jobData.description,
            jobData.type or 'custom',
            jobData.default_salary or 0,
            jobData.whitelisted and 1 or 0,
            jobData.society_account and 1 or 0,
            json.encode(jobData.blip or {}),
            json.encode(jobData.metadata or {})
        })
    end)
    
    if success and result then
        -- Créer le compte société si nécessaire
        if jobData.society_account then
            MySQL.insert('INSERT IGNORE INTO job_accounts (job_name, money) VALUES (?, ?)', {
                jobData.name,
                0
            })
        end
        
        return true, result
    end
    
    return false, nil
end

---Met à jour un job en base de données
---@param jobName string
---@param jobData table
---@return boolean
function UpdateJobInDatabase(jobName, jobData)
    local success, affected = pcall(function()
        return MySQL.update.await([[
            UPDATE jobs_config SET 
                label = ?, 
                icon = ?, 
                description = ?, 
                default_salary = ?, 
                whitelisted = ?,
                blip = ?,
                metadata = ?
            WHERE name = ?
        ]], {
            jobData.label,
            jobData.icon,
            jobData.description,
            jobData.default_salary,
            jobData.whitelisted and 1 or 0,
            json.encode(jobData.blip or {}),
            json.encode(jobData.metadata or {}),
            jobName
        })
    end)
    
    return success and affected > 0
end

---Supprime un job de la base de données
---@param jobName string
---@return boolean
function DeleteJobFromDatabase(jobName)
    local success, affected = pcall(function()
        return MySQL.update.await('DELETE FROM jobs_config WHERE name = ?', {jobName})
    end)
    
    return success and affected > 0
end

---Ajoute un grade à un job
---@param jobName string
---@param gradeData table
---@return boolean
function AddJobGrade(jobName, gradeData)
    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_grades (job_name, grade, name, label, salary, permissions, metadata)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ]], {
            jobName,
            gradeData.grade,
            gradeData.name,
            gradeData.label,
            gradeData.salary or 0,
            json.encode(gradeData.permissions or {}),
            json.encode(gradeData.metadata or {})
        })
    end)
    
    return success and result ~= nil
end

---Met à jour un grade
---@param jobName string
---@param grade number
---@param gradeData table
---@return boolean
function UpdateJobGrade(jobName, grade, gradeData)
    local success, affected = pcall(function()
        return MySQL.update.await([[
            UPDATE job_grades SET 
                name = ?, 
                label = ?, 
                salary = ?, 
                permissions = ?,
                metadata = ?
            WHERE job_name = ? AND grade = ?
        ]], {
            gradeData.name,
            gradeData.label,
            gradeData.salary,
            json.encode(gradeData.permissions or {}),
            json.encode(gradeData.metadata or {}),
            jobName,
            grade
        })
    end)
    
    return success and affected > 0
end

---Supprime un grade
---@param jobName string
---@param grade number
---@return boolean
function DeleteJobGrade(jobName, grade)
    local success, affected = pcall(function()
        return MySQL.update.await('DELETE FROM job_grades WHERE job_name = ? AND grade = ?', {jobName, grade})
    end)
    
    return success and affected > 0
end

---Récupère les véhicules d'un job
---@param jobName string
---@param minGrade number|nil
---@return table
function GetJobVehicles(jobName, minGrade)
    local query = 'SELECT * FROM job_vehicles WHERE job_name = ? AND enabled = 1'
    local params = {jobName}
    
    if minGrade then
        query = query .. ' AND min_grade <= ?'
        table.insert(params, minGrade)
    end
    
    query = query .. ' ORDER BY category, min_grade'
    
    local result = MySQL.query.await(query, params)
    return result or {}
end

---Ajoute un véhicule à un job
---@param jobName string
---@param vehicleData table
---@return boolean
function AddJobVehicle(jobName, vehicleData)
    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_vehicles (job_name, category, model, label, price, min_grade, livery, extras)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            jobName,
            vehicleData.category or 'service',
            vehicleData.model,
            vehicleData.label,
            vehicleData.price or 0,
            vehicleData.min_grade or 0,
            vehicleData.livery,
            json.encode(vehicleData.extras or {})
        })
    end)
    
    return success and result ~= nil
end

---Récupère les tenues d'un job
---@param jobName string
---@param gender string
---@param grade number|nil
---@return table
function GetJobOutfits(jobName, gender, grade)
    local query = 'SELECT * FROM job_outfits WHERE job_name = ? AND gender = ? AND enabled = 1'
    local params = {jobName, gender}
    
    if grade then
        query = query .. ' AND grade <= ?'
        table.insert(params, grade)
    end
    
    query = query .. ' ORDER BY grade'
    
    local result = MySQL.query.await(query, params)
    
    if result then
        for _, outfit in ipairs(result) do
            outfit.outfit = json.decode(outfit.outfit)
        end
    end
    
    return result or {}
end

---Ajoute une tenue à un job
---@param jobName string
---@param outfitData table
---@return boolean
function AddJobOutfit(jobName, outfitData)
    local success, result = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_outfits (job_name, gender, grade, label, outfit)
            VALUES (?, ?, ?, ?, ?)
        ]], {
            jobName,
            outfitData.gender,
            outfitData.grade or 0,
            outfitData.label,
            json.encode(outfitData.outfit)
        })
    end)
    
    return success and result ~= nil
end

exports('CreateJobInDatabase', CreateJobInDatabase)
exports('UpdateJobInDatabase', UpdateJobInDatabase)
exports('DeleteJobFromDatabase', DeleteJobFromDatabase)
exports('AddJobGrade', AddJobGrade)
exports('UpdateJobGrade', UpdateJobGrade)
exports('DeleteJobGrade', DeleteJobGrade)
exports('GetJobVehicles', GetJobVehicles)
exports('AddJobVehicle', AddJobVehicle)
exports('GetJobOutfits', GetJobOutfits)
exports('AddJobOutfit', AddJobOutfit)
