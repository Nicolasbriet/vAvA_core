--[[
    vAvA_core - Server Jobs
    Système de jobs/métiers avec intégration economy
]]

vCore = vCore or {}
vCore.Jobs = {}

-- Vérifier si le module economy est chargé
local EconomyEnabled = false
CreateThread(function()
    Wait(5000)  -- Attendre que tous les modules soient chargés
    if GetResourceState('vAvA_economy') == 'started' then
        EconomyEnabled = true
        print('^2[vCore:Jobs]^7 Module economy détecté et activé')
    else
        print('^3[vCore:Jobs]^7 Module economy non trouvé - Salaires fixes utilisés')
    end
end)

---Obtenir le salaire d'un job via le système economy
---@param jobName string
---@param grade number
---@return number
local function GetJobSalary(jobName, grade)
    if not EconomyEnabled then
        -- Salaires fixes si economy non disponible
        local defaultSalaries = {
            unemployed = 100,
            police = 500,
            ambulance = 450,
            mechanic = 400,
            taxi = 350,
            realestateagent = 300
        }
        return defaultSalaries[jobName] or 100
    end
    
    -- Utiliser le système economy
    return exports['vAvA_economy']:GetSalary(jobName, grade)
end

---Appliquer une taxe sur les salaires
---@param amount number
---@return number
local function ApplyTax(amount)
    if not EconomyEnabled then
        -- Taxe fixe de 10% si economy non disponible
        return math.floor(amount * 0.9)
    end
    
    return exports['vAvA_economy']:ApplyTax('salaire', amount)
end

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

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE PAIE AUTOMATIQUE (Intégration Economy)
-- ═══════════════════════════════════════════════════════════════════════════

---Verser un salaire à un joueur
---@param source number
---@return boolean
function vCore.Jobs.PaySalary(source)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    if not job then return false end
    
    -- Ne pas payer les chômeurs
    if job.name == 'unemployed' then return false end
    
    -- Obtenir le salaire depuis le système economy
    local baseSalary = GetJobSalary(job.name, job.grade)
    
    -- Appliquer la taxe sur le salaire
    local netSalary = ApplyTax(baseSalary)
    
    -- Ajouter l'argent au joueur
    if player.Functions.AddMoney then
        player.Functions.AddMoney('bank', netSalary, 'salary-payment')
    end
    
    -- Notifier le joueur
    vCore.Notify(source, '💰 Salaire reçu: $' .. netSalary .. ' (' .. job.label .. ')', 'success')
    
    -- Log
    vCore.Log('salary', player:GetIdentifier(), 
        'Salaire payé: $' .. netSalary,
        {job = job.name, grade = job.grade, baseSalary = baseSalary, netSalary = netSalary}
    )
    
    -- Enregistrer la transaction dans economy (si disponible)
    if EconomyEnabled then
        exports['vAvA_economy']:RegisterTransaction(
            'salaire',
            job.name,
            'job',
            1,
            netSalary
        )
    end
    
    return true
end

-- Thread de paie automatique (toutes les 30 minutes)
CreateThread(function()
    while true do
        Wait(1800000) -- 30 minutes
        
        local players = vCore.GetPlayers()
        for _, playerId in ipairs(players) do
            local player = vCore.GetPlayer(playerId)
            if player and player:IsOnDuty() then
                vCore.Jobs.PaySalary(playerId)
            end
        end
        
        print('^2[vCore:Jobs]^7 Salaires versés à ' .. #players .. ' joueurs')
    end
end)

-- Commande manuelle pour payer un salaire (admin)
RegisterCommand('paysalary', function(source, args)
    if source > 0 and not IsPlayerAceAllowed(source, 'command') then return end
    
    local targetId = tonumber(args[1]) or source
    
    if vCore.Jobs.PaySalary(targetId) then
        if source > 0 then
            vCore.Notify(source, 'Salaire versé au joueur ' .. targetId, 'success')
        end
        print('^2[vCore:Jobs]^7 Salaire versé à ' .. targetId)
    else
        if source > 0 then
            vCore.Notify(source, 'Impossible de verser le salaire', 'error')
        end
        print('^1[vCore:Jobs]^7 Échec du paiement pour ' .. targetId)
    end
end, true)

-- Commande pour voir son salaire
RegisterCommand('salary', function(source)
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local job = player:GetJob()
    if job.name == 'unemployed' then
        vCore.Notify(source, 'Vous êtes au chômage', 'info')
        return
    end
    
    local baseSalary = GetJobSalary(job.name, job.grade)
    local netSalary = ApplyTax(baseSalary)
    
    vCore.Notify(source, '💼 Job: ' .. job.label .. ' (Grade ' .. job.grade .. ')~n~💰 Salaire: $' .. netSalary .. ' / 30min', 'info')
end, false)
