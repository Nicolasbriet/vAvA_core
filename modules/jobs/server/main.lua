--[[
    vAvA Core - Module Jobs
    Server - Main
]]

local vCore = nil
local Jobs = {}
local Interactions = {}
local OnlinePlayers = {}

-- Initialisation
CreateThread(function()
    TriggerEvent('vCore:getSharedObject', function(obj) vCore = obj end)
    
    if not vCore then
        local success, result = pcall(function()
            return exports['vAvA_core']:GetCoreObject()
        end)
        if success then
            vCore = result
        end
    end
    
    -- Attendre que vCore soit correctement chargé
    local timeout = 0
    while (not vCore or not vCore.GetPlayer) and timeout < 100 do
        print('[vCore:Jobs] Attente de l\'initialisation de vCore... (' .. timeout .. '/100)')
        Wait(500)
        timeout = timeout + 1
        
        if not vCore then
            local success, result = pcall(function()
                return exports['vAvA_core']:GetCoreObject()
            end)
            if success and result then
                vCore = result
            end
        end
    end
    
    if vCore and vCore.GetPlayer then
        print('^2[vCore:Jobs] vCore correctement initialisé^0')
    else
        print('^1[vCore:Jobs] ERREUR: Impossible d\'initialiser vCore^0')
    end
    
    Wait(2000)
    LoadJobsFromDatabase()
    LoadInteractionsFromDatabase()
    StartPaycheckLoop()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si vCore et le player sont valides et récupère le job de manière sûre
---@param source number
---@return vPlayer|nil, string|nil, table|nil
local function GetValidPlayer(source)
    if not vCore then 
        return nil, '[vCore:Jobs] ERREUR: vCore non initialisé', nil
    end
    
    if not vCore.GetPlayer then
        return nil, '[vCore:Jobs] ERREUR: Méthode GetPlayer non trouvée', nil
    end
    
    local player = vCore.GetPlayer(source)
    if not player then 
        return nil, '[vCore:Jobs] ERREUR: Joueur introuvable pour source: ' .. source, nil
    end
    
    -- Récupérer le job avec plusieurs méthodes fallback
    local jobData = nil
    
    -- Méthode 1: Via la méthode GetJob() si disponible
    if type(player.GetJob) == 'function' then
        local success, result = pcall(function()
            return player:GetJob()
        end)
        if success and result then
            jobData = result
        end
    end
    
    -- Méthode 2: Via PlayerData.job (pattern utilisé dans d'autres modules)
    if not jobData and player.PlayerData and player.PlayerData.job then
        jobData = player.PlayerData.job
    end
    
    -- Méthode 3: Accès direct job
    if not jobData and player.job then
        jobData = player.job
    end
    
    if not jobData then
        return nil, '[vCore:Jobs] ERREUR: Impossible de récupérer les données job pour source: ' .. source, nil
    end
    
    return player, nil, jobData
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Charge tous les jobs depuis la base de données
function LoadJobsFromDatabase()
    local result = MySQL.query.await([[
        SELECT jc.*, 
               GROUP_CONCAT(
                   CONCAT(jg.grade, ':', jg.name, ':', jg.label, ':', jg.salary, ':', IFNULL(jg.permissions, '[]'))
                   ORDER BY jg.grade SEPARATOR '|'
               ) as grades_data
        FROM jobs_config jc
        LEFT JOIN job_grades jg ON jc.name = jg.job_name
        WHERE jc.enabled = 1
        GROUP BY jc.id
    ]])
    
    if result then
        for _, row in ipairs(result) do
            local job = {
                name = row.name,
                label = row.label,
                icon = row.icon,
                description = row.description,
                type = row.type,
                whitelisted = row.whitelisted == 1,
                society_account = row.society_account == 1,
                default_salary = row.default_salary,
                blip = json.decode(row.blip or '{}'),
                offduty_name = row.offduty_name,
                metadata = json.decode(row.metadata or '{}'),
                grades = {}
            }
            
            -- Parse grades
            if row.grades_data then
                for gradeData in string.gmatch(row.grades_data, '([^|]+)') do
                    local parts = {}
                    for part in string.gmatch(gradeData, '([^:]+)') do
                        table.insert(parts, part)
                    end
                    
                    if #parts >= 5 then
                        local grade = tonumber(parts[1])
                        job.grades[grade] = {
                            name = parts[2],
                            label = parts[3],
                            salary = tonumber(parts[4]),
                            permissions = json.decode(parts[5] or '[]')
                        }
                    end
                end
            end
            
            Jobs[row.name] = job
        end
        
        print(('[vCore:Jobs] %d jobs chargés depuis la base de données'):format(#result))
    end
end

---Charge toutes les interactions depuis la base de données
function LoadInteractionsFromDatabase()
    local result = MySQL.query.await('SELECT * FROM job_interactions WHERE enabled = 1')
    
    if result then
        Interactions = {}
        for _, row in ipairs(result) do
            local interaction = {
                id = row.id,
                job_name = row.job_name,
                type = row.type,
                name = row.name,
                label = row.label,
                position = json.decode(row.position),
                heading = row.heading,
                marker = json.decode(row.marker or '{}'),
                blip = json.decode(row.blip or '{}'),
                config = json.decode(row.config or '{}'),
                min_grade = row.min_grade,
                enabled = row.enabled == 1
            }
            
            if not Interactions[row.job_name] then
                Interactions[row.job_name] = {}
            end
            
            table.insert(Interactions[row.job_name], interaction)
        end
        
        print(('[vCore:Jobs] %d points d\'interaction chargés'):format(#result))
    end
end

---Récupère un job
---@param jobName string
---@return table|nil
function GetJob(jobName)
    return Jobs[jobName]
end

---Récupère tous les jobs
---@return table
function GetAllJobs()
    return Jobs
end

---Récupère les interactions d'un job
---@param jobName string
---@return table
function GetJobInteractions(jobName)
    return Interactions[jobName] or {}
end

---Vérifie si un joueur a la permission
---@param source number
---@param permission string
---@return boolean
function HasJobPermission(source, permission)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    if not job then return false end
    
    local jobConfig = GetJob(job.name)
    if not jobConfig or not jobConfig.grades[job.grade] then return false end
    
    local permissions = jobConfig.grades[job.grade].permissions or {}
    
    -- Check si permission 'all'
    for _, perm in ipairs(permissions) do
        if perm == 'all' or perm == permission then
            return true
        end
    end
    
    return false
end

---Change le job d'un joueur
---@param source number
---@param jobName string
---@param grade number
---@return boolean
function SetPlayerJob(source, jobName, grade)
    -- S'assurer que vCore est initialisé
    if not vCore then 
        print('[vCore:Jobs] ERREUR: vCore non initialisé')
        return false
    end
    
    local player = vCore.GetPlayer(source)
    if not player then
        print('[vCore:Jobs] ERREUR: Joueur introuvable pour source:', source)
        return false
    end
    
    local job = GetJob(jobName)
    if not job then
        print(('[vCore:Jobs] Job inexistant: %s'):format(jobName))
        return false
    end
    
    if not job.grades[grade] then
        print(('[vCore:Jobs] Grade inexistant: %s/%d'):format(jobName, grade))
        return false
    end
    
    -- Utiliser la fonction du core si disponible
    if vCore.Jobs and vCore.Jobs.SetJob then
        return vCore.Jobs.SetJob(source, jobName, grade)
    end
    
    -- Fallback - vérifier que les méthodes existent
    if not player.GetJob or not player.SetJob then
        print('[vCore:Jobs] ERREUR: Méthodes GetJob ou SetJob non trouvées sur l\'objet player')
        return false
    end
    
    local oldJob = player:GetJob()
    local success = player:SetJob(jobName, grade)
    
    if success then
        TriggerClientEvent('vCore:jobs:updateJob', source, {
            name = jobName,
            grade = grade,
            label = job.label,
            grade_label = job.grades[grade].label
        })
        
        -- Log
        LogJobAction(jobName, player:GetIdentifier(), 'job_changed', 
            ('Job changé de %s à %s (grade %d)'):format(oldJob.name, jobName, grade))
    end
    
    return success
end

---Met en service / hors service
---@param source number
---@param onDuty boolean
function SetPlayerDuty(source, onDuty)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if vCore.Jobs and vCore.Jobs.SetDuty then
        vCore.Jobs.SetDuty(source, onDuty)
    else
        player:SetDuty(onDuty)
    end
    
    TriggerClientEvent('vCore:jobs:updateDuty', source, onDuty)
    
    local message = onDuty and JobsConfig.Notifications.now_on_duty or JobsConfig.Notifications.now_off_duty
    Notify(source, message, 'info')
end

---Récupère le compte société d'un job
---@param jobName string
---@return number
function GetSocietyAccount(jobName)
    local result = MySQL.scalar.await('SELECT money FROM job_accounts WHERE job_name = ?', {jobName})
    return result or 0
end

---Ajoute de l'argent au compte société
---@param jobName string
---@param amount number
---@return boolean
function AddSocietyMoney(jobName, amount)
    if amount <= 0 then return false end
    
    local affected = MySQL.update.await([[
        INSERT INTO job_accounts (job_name, money) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE money = money + ?
    ]], {jobName, amount, amount})
    
    return affected > 0
end

---Retire de l'argent du compte société
---@param jobName string
---@param amount number
---@return boolean
function RemoveSocietyMoney(jobName, amount)
    if amount <= 0 then return false end
    
    local currentMoney = GetSocietyAccount(jobName)
    if currentMoney < amount then return false end
    
    local affected = MySQL.update.await('UPDATE job_accounts SET money = money - ? WHERE job_name = ?', {amount, jobName})
    return affected > 0
end

---Log une action job
---@param jobName string
---@param identifier string
---@param action string
---@param description string
---@param data table|nil
function LogJobAction(jobName, identifier, action, description, data)
    MySQL.insert('INSERT INTO job_logs (job_name, player_identifier, action, description, data) VALUES (?, ?, ?, ?, ?)', {
        jobName,
        identifier,
        action,
        description,
        data and json.encode(data) or nil
    })
end

---Notification
---@param source number
---@param message string
---@param type string
function Notify(source, message, type)
    if vCore and vCore.Notify then
        vCore.Notify(source, message, type or 'info')
    else
        TriggerClientEvent('vCore:Notify', source, message, type or 'info')
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SALAIRES AUTOMATIQUES
-- ═══════════════════════════════════════════════════════════════════════════

function StartPaycheckLoop()
    if not JobsConfig.EnablePaycheck then return end
    
    CreateThread(function()
        while true do
            Wait(JobsConfig.PaycheckInterval)
            ProcessPaychecks()
        end
    end)
end

function ProcessPaychecks()
    for _, source in ipairs(GetPlayers()) do
        local player = vCore.GetPlayer(tonumber(source))
        if player then
            local job = player:GetJob()
            if job and job.name ~= 'unemployed' then
                local jobConfig = GetJob(job.name)
                if jobConfig and jobConfig.grades[job.grade] then
                    local salary = jobConfig.grades[job.grade].salary or 0
                    
                    if salary > 0 then
                        player:AddMoney('bank', salary, 'Salaire ' .. jobConfig.label)
                        Notify(source, ('Vous avez reçu votre salaire: %s$'):format(salary), 'success')
                        
                        LogJobAction(job.name, player:GetIdentifier(), 'paycheck', 
                            ('Salaire reçu: %s$'):format(salary), {salary = salary})
                    end
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:jobs:requestData', function()
    local source = source
    local player, error = GetValidPlayer(source)
    if not player then
        if error then print(error) end
        return
    end
    
    local job = player:GetJob()
    if not job then
        print('[vCore:Jobs] ERREUR: Job non trouvé pour le joueur')
        return
    end
    
    local interactions = GetJobInteractions(job.name)
    
    TriggerClientEvent('vCore:jobs:receiveData', source, {
        job = job,
        jobConfig = GetJob(job.name),
        interactions = interactions
    })
end)

RegisterNetEvent('vCore:jobs:toggleDuty', function()
    local source = source
    
    -- S'assurer que vCore est initialisé
    if not vCore then 
        print('[vCore:Jobs] ERREUR: vCore non initialisé')
        return 
    end
    
    local player = vCore.GetPlayer(source)
    if not player then 
        print('[vCore:Jobs] ERREUR: Joueur introuvable pour source:', source)
        return 
    end
    SetPlayerDuty(source, not onDuty)
end)

RegisterNetEvent('vCore:jobs:requestSocietyMoney', function()
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local job = player:GetJob()
    local money = GetSocietyAccount(job.name)
    
    TriggerClientEvent('vCore:jobs:receiveSocietyMoney', source, money)
end)

-- Commande pour voir son job actuel
RegisterCommand('myjob', function(source, args, rawCommand)
    local player, error, jobData = GetValidPlayer(source)
    if not player then
        if error then print(error) end
        vCore.Notify(source, 'Erreur lors de la récupération des informations job', 'error')
        return
    end
    
    local jobConfig = GetJob(jobData.name)
    
    -- Compter les collègues en ligne
    local colleagues = 0
    for _, otherPlayer in pairs(vCore.GetPlayers()) do
        if otherPlayer then
            local _, _, otherJobData = GetValidPlayer(otherPlayer.source)
            if otherJobData and otherJobData.name == jobData.name and otherPlayer.source ~= source then
                colleagues = colleagues + 1
            end
        end
    end
    
    -- Préparer les données job
    local jobDisplayData = {
        name = jobData.name,
        label = jobData.label,
        gradeLabel = jobData.gradeLabel or jobData.grade_label,
        salary = jobData.salary or 0,
        onDuty = jobData.onDuty or false,
        colleagues = colleagues,
        permissions = jobData.permissions or {}
    }
    
    -- Ouvrir la carte d'informations job
    TriggerClientEvent('vCore:jobs:openJobInfo', source, jobDisplayData)
end, false)

-- Commande alternative
RegisterCommand('job', function(source, args, rawCommand)
    local player, error, jobData = GetValidPlayer(source)
    if not player then
        if error then print(error) end
        return
    end
    
    local jobConfig = GetJob(jobData.name)
    local isOnDuty = jobData.onDuty and "En service" or "Hors service"
    
    -- Affichage simple dans le chat
    local message = string.format(
        "^3[JOB INFO]^0\n" ..
        "^2Métier:^0 %s\n" .. 
        "^2Grade:^0 %s\n" ..
        "^2Salaire:^0 $%s\n" ..
        "^2Statut:^0 %s",
        jobData.label or jobData.name,
        jobData.gradeLabel or jobData.grade_label or "Grade " .. (jobData.grade or 0),
        (jobData.salary or 0),
        isOnDuty
    )
    
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 255},
        multiline = true,
        args = {message}
    })
end, false)

-- Commande pour afficher les stats détaillées
RegisterCommand('jobstats', function(source, args, rawCommand)
    local player, error, jobData = GetValidPlayer(source)
    if not player then
        if error then print(error) end
        return
    end
    
    local jobConfig = GetJob(jobData.name)
    
    -- Compter les collègues en ligne
    local colleagues = 0
    for _, otherPlayer in pairs(vCore.GetPlayers()) do
        if otherPlayer then
            local _, _, otherJobData = GetValidPlayer(otherPlayer.source)
            if otherJobData and otherJobData.name == jobData.name and otherPlayer.source ~= source then
                colleagues = colleagues + 1
            end
        end
    end
    
    -- Préparer les données job complètes avec plus d'informations
    local jobDisplayData = {
        name = jobData.name,
        label = jobData.label,
        gradeLabel = jobData.gradeLabel or jobData.grade_label,
        salary = jobData.salary or 0,
        onDuty = jobData.onDuty or false,
        colleagues = colleagues,
        permissions = jobData.permissions or {},
        -- Ajouter des informations supplémentaires si disponibles
        society_money = GetSocietyAccount(jobData.name) or 0
    }
    
    -- Ouvrir la carte d'informations job détaillée
    TriggerClientEvent('vCore:jobs:openJobInfo', source, jobDisplayData)
end, false)

RegisterNetEvent('vCore:jobs:withdrawMoney', function(amount)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not HasJobPermission(source, 'withdraw') then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local job = player:GetJob()
    
    if RemoveSocietyMoney(job.name, amount) then
        player:AddMoney('cash', amount, 'Retrait société')
        Notify(source, JobsConfig.Notifications.money_withdrawn:format(amount), 'success')
        
        LogJobAction(job.name, player:GetIdentifier(), 'withdraw', 
            ('Retrait: %s$'):format(amount), {amount = amount})
    else
        Notify(source, JobsConfig.Notifications.insufficient_society_funds, 'error')
    end
end)

RegisterNetEvent('vCore:jobs:depositMoney', function(amount)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if player:GetMoney('cash') < amount then
        Notify(source, 'Argent insuffisant', 'error')
        return
    end
    
    local job = player:GetJob()
    
    if AddSocietyMoney(job.name, amount) then
        player:RemoveMoney('cash', amount, 'Dépôt société')
        Notify(source, JobsConfig.Notifications.money_deposited:format(amount), 'success')
        
        LogJobAction(job.name, player:GetIdentifier(), 'deposit', 
            ('Dépôt: %s$'):format(amount), {amount = amount})
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Fonction pour obtenir les grades d'un job
local function GetJobGrades(jobName)
    if not jobName then return nil end
    local job = GetJob(jobName)
    if not job then return nil end
    return job.grades or {}
end

exports('GetJob', GetJob)
exports('GetJobs', GetAllJobs)  -- Alias pour compatibilité tests
exports('GetAllJobs', GetAllJobs)
exports('GetJobGrades', GetJobGrades)
exports('GetJobInteractions', GetJobInteractions)
exports('SetPlayerJob', SetPlayerJob)
exports('SetPlayerDuty', SetPlayerDuty)
exports('HasJobPermission', HasJobPermission)
exports('GetSocietyAccount', GetSocietyAccount)
exports('AddSocietyMoney', AddSocietyMoney)
exports('RemoveSocietyMoney', RemoveSocietyMoney)
exports('LogJobAction', LogJobAction)
