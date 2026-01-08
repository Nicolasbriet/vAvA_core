--[[
    vAvA_core - Server Economy
    Système économique complet
]]

vCore = vCore or {}
vCore.Economy = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Ajoute de l'argent à un joueur
---@param source number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vCore.Economy.AddMoney(source, moneyType, amount, reason)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    amount = math.floor(amount)
    if amount <= 0 then return false end
    
    -- Vérifier le type d'argent
    if not vCore.Utils.TableContains(Config.Economy.MoneyTypes, moneyType) then
        return false
    end
    
    local success = player:AddMoney(moneyType, amount, reason)
    
    if success then
        -- Log
        if Config.Economy.LogTransactions then
            vCore.Log('economy', player:GetIdentifier(), 
                'AddMoney: ' .. moneyType .. ' +' .. amount, 
                {type = moneyType, amount = amount, reason = reason}
            )
        end
        
        -- Notification
        if moneyType == vCore.MoneyType.CASH then
            vCore.Notify(source, Lang('money_received', vCore.Utils.FormatNumber(amount)), 'success')
        elseif moneyType == vCore.MoneyType.BANK then
            vCore.Notify(source, Lang('money_bank_received', vCore.Utils.FormatNumber(amount)), 'success')
        end
    end
    
    return success
end

---Retire de l'argent à un joueur
---@param source number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vCore.Economy.RemoveMoney(source, moneyType, amount, reason)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    amount = math.floor(amount)
    if amount <= 0 then return false end
    
    -- Vérifier le type d'argent
    if not vCore.Utils.TableContains(Config.Economy.MoneyTypes, moneyType) then
        return false
    end
    
    -- Vérifier les fonds
    if player:GetMoney(moneyType) < amount then
        vCore.Notify(source, Lang('money_not_enough'), 'error')
        return false
    end
    
    local success = player:RemoveMoney(moneyType, amount, reason)
    
    if success then
        -- Log
        if Config.Economy.LogTransactions then
            vCore.Log('economy', player:GetIdentifier(), 
                'RemoveMoney: ' .. moneyType .. ' -' .. amount, 
                {type = moneyType, amount = amount, reason = reason}
            )
        end
        
        -- Notification
        if moneyType == vCore.MoneyType.CASH then
            vCore.Notify(source, Lang('money_removed', vCore.Utils.FormatNumber(amount)), 'info')
        elseif moneyType == vCore.MoneyType.BANK then
            vCore.Notify(source, Lang('money_bank_removed', vCore.Utils.FormatNumber(amount)), 'info')
        end
    end
    
    return success
end

---Définit l'argent d'un joueur
---@param source number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vCore.Economy.SetMoney(source, moneyType, amount, reason)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    amount = math.floor(amount)
    if amount < 0 then amount = 0 end
    
    -- Vérifier le type d'argent
    if not vCore.Utils.TableContains(Config.Economy.MoneyTypes, moneyType) then
        return false
    end
    
    local success = player:SetMoney(moneyType, amount, reason)
    
    if success then
        -- Log
        if Config.Economy.LogTransactions then
            vCore.Log('economy', player:GetIdentifier(), 
                'SetMoney: ' .. moneyType .. ' = ' .. amount, 
                {type = moneyType, amount = amount, reason = reason}
            )
        end
    end
    
    return success
end

---Retourne l'argent d'un joueur
---@param source number
---@param moneyType string
---@return number
function vCore.Economy.GetMoney(source, moneyType)
    local player = vCore.GetPlayer(source)
    if not player then return 0 end
    
    return player:GetMoney(moneyType)
end

---Transfère de l'argent entre deux joueurs
---@param sourcePlayer number
---@param targetPlayer number
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vCore.Economy.Transfer(sourcePlayer, targetPlayer, moneyType, amount, reason)
    local source = vCore.GetPlayer(sourcePlayer)
    local target = vCore.GetPlayer(targetPlayer)
    
    if not source or not target then return false end
    
    amount = math.floor(amount)
    if amount <= 0 then return false end
    
    -- Vérifier les fonds
    if source:GetMoney(moneyType) < amount then
        vCore.Notify(sourcePlayer, Lang('money_not_enough'), 'error')
        return false
    end
    
    -- Effectuer le transfert
    if source:RemoveMoney(moneyType, amount, reason) then
        target:AddMoney(moneyType, amount, reason)
        
        -- Notifications
        vCore.Notify(sourcePlayer, Lang('money_transfer'), 'success')
        vCore.Notify(targetPlayer, Lang('money_transfer_received', vCore.Utils.FormatNumber(amount)), 'success')
        
        -- Log
        if Config.Economy.LogTransactions then
            vCore.Log('economy', source:GetIdentifier(), 
                'Transfer to ' .. target:GetName() .. ': ' .. moneyType .. ' ' .. amount,
                {type = moneyType, amount = amount, target = target:GetIdentifier()}
            )
        end
        
        return true
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddMoney', function(source, moneyType, amount, reason)
    return vCore.Economy.AddMoney(source, moneyType, amount, reason)
end)

exports('RemoveMoney', function(source, moneyType, amount, reason)
    return vCore.Economy.RemoveMoney(source, moneyType, amount, reason)
end)

exports('SetMoney', function(source, moneyType, amount, reason)
    return vCore.Economy.SetMoney(source, moneyType, amount, reason)
end)

exports('GetMoney', function(source, moneyType)
    return vCore.Economy.GetMoney(source, moneyType)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Paiement de salaire
RegisterNetEvent('vCore:paySalary', function()
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    if not player:IsOnDuty() then return end
    
    local job = player:GetJob()
    local salary = job.salary or 0
    
    if salary > 0 then
        vCore.Economy.AddMoney(source, vCore.MoneyType.BANK, salary, 'Salaire ' .. job.label)
        vCore.Notify(source, Lang('job_salary_received', vCore.Utils.FormatNumber(salary)), 'success')
    end
end)

-- Thread de paiement des salaires (toutes les heures IG)
CreateThread(function()
    while true do
        Wait(1000 * 60 * 60) -- 1 heure réelle ou ajustable
        
        local players = vCore.GetPlayers()
        for source, player in pairs(players) do
            if player:IsOnDuty() then
                local job = player:GetJob()
                local salary = job.salary or 0
                
                if salary > 0 then
                    vCore.Economy.AddMoney(source, vCore.MoneyType.BANK, salary, 'Salaire')
                end
            end
        end
    end
end)
