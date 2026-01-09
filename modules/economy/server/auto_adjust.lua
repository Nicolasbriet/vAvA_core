-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy Auto-Adjustment System
-- Système d'ajustement automatique des prix et salaires
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- Démarrer le système auto-adaptatif
-- ══════════════════════════════════════════════════════════════════════════════

function StartAutoAdjustment()
    print('[vAvA_economy] Système auto-adaptatif démarré')
    
    CreateThread(function()
        while true do
            Wait(EconomyConfig.autoAdjust.interval * 1000)
            
            if EconomyConfig.autoAdjust.enabled then
                print('[vAvA_economy] Démarrage du recalcul automatique...')
                RecalculateEconomy('auto', nil, 'Ajustement automatique périodique')
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Recalculer l'économie complète
-- ══════════════════════════════════════════════════════════════════════════════

function RecalculateEconomy(source, adminIdentifier, reason)
    local startTime = os.time()
    
    -- Vérifier le cooldown
    if source == 'admin' and EconomyConfig.security.cooldownRecalculate > 0 then
        local timeSinceLastRecalc = startTime - EconomyServer.lastRecalculate
        if timeSinceLastRecalc < EconomyConfig.security.cooldownRecalculate then
            local remainingTime = EconomyConfig.security.cooldownRecalculate - timeSinceLastRecalc
            return false, ('Cooldown actif. Attendez encore %d secondes'):format(remainingTime)
        end
    end
    
    local changes = {
        items = 0,
        jobs = 0,
        inflation = 0
    }
    
    -- 1. Ajuster l'inflation
    changes.inflation = AdjustInflation()
    
    -- 2. Ajuster les prix des items
    changes.items = AdjustItemPrices()
    
    -- 3. Ajuster les salaires des jobs
    changes.jobs = AdjustJobSalaries()
    
    -- 4. Mettre à jour l'état global
    MySQL.update('UPDATE economy_state SET last_update = NOW(), updated_by = ? WHERE id = 1', {
        adminIdentifier or 'system'
    })
    
    -- 5. Logger le recalcul
    LogEconomyChange('recalculate', nil, nil, nil, source, adminIdentifier, reason)
    
    EconomyServer.lastRecalculate = startTime
    
    local duration = os.time() - startTime
    print(('[vAvA_economy] Recalcul terminé en %ds: %d items, %d jobs, inflation: %.4f'):format(
        duration,
        changes.items,
        changes.jobs,
        changes.inflation
    ))
    
    return true, changes
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Ajuster l'inflation
-- ══════════════════════════════════════════════════════════════════════════════

function AdjustInflation()
    if not EconomyConfig.inflation.enabled then return 0 end
    
    local oldInflation = Economy.State.inflation
    
    -- Calculer la nouvelle inflation basée sur l'activité
    local activityFactor = CalculateActivityFactor()
    local inflationChange = EconomyConfig.inflation.rate * activityFactor
    
    local newInflation = oldInflation + inflationChange
    
    -- Limiter l'inflation
    newInflation = math.max(EconomyConfig.inflation.minInflation, math.min(EconomyConfig.inflation.maxInflation, newInflation))
    
    -- Mettre à jour
    Economy.State.inflation = newInflation
    
    MySQL.update('UPDATE economy_state SET inflation = ? WHERE id = 1', {
        newInflation
    })
    
    -- Logger
    LogEconomyChange('inflation', 'global', oldInflation, newInflation, 'auto', nil, 'Ajustement automatique')
    
    return newInflation
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Ajuster les prix des items
-- ══════════════════════════════════════════════════════════════════════════════

function AdjustItemPrices()
    local adjustedCount = 0
    local maxVariation = EconomyConfig.autoAdjust.maxVariation
    
    for itemName, itemCache in pairs(EconomyServer.itemsCache) do
        local oldPrice = itemCache.currentPrice
        
        -- Calculer le taux d'achat/vente
        local totalTransactions = itemCache.buyCount + itemCache.sellCount
        if totalTransactions > 10 then -- Minimum 10 transactions pour ajuster
            local buyRate = itemCache.buyCount / totalTransactions
            local sellRate = itemCache.sellCount / totalTransactions
            
            -- Formule: nouveau_prix = prix_actuel × (1 + (taux_achat - taux_vente) × facteur)
            local priceChange = (buyRate - sellRate) * EconomyConfig.autoAdjust.factors.buyRate
            
            -- Limiter la variation
            priceChange = math.max(-maxVariation, math.min(maxVariation, priceChange))
            
            local newPrice = oldPrice * (1 + priceChange)
            
            -- Valider le prix
            local isValid, errorMsg = Economy.ValidatePrice(newPrice)
            if isValid then
                -- Mettre à jour en BDD
                MySQL.update('UPDATE economy_items SET current_price = ?, buy_count = 0, sell_count = 0 WHERE item_name = ?', {
                    newPrice,
                    itemName
                })
                
                -- Mettre à jour le cache
                itemCache.currentPrice = newPrice
                itemCache.buyCount = 0
                itemCache.sellCount = 0
                
                -- Logger si changement significatif (>5%)
                if math.abs(priceChange) > 0.05 then
                    LogEconomyChange('price', itemName, oldPrice, newPrice, 'auto', nil, 'Ajustement offre/demande')
                end
                
                adjustedCount = adjustedCount + 1
            end
        end
    end
    
    return adjustedCount
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Ajuster les salaires des jobs
-- ══════════════════════════════════════════════════════════════════════════════

function AdjustJobSalaries()
    local adjustedCount = 0
    local maxVariation = EconomyConfig.autoAdjust.maxVariation
    
    -- Obtenir le nombre de joueurs par job
    local jobPlayerCounts = GetJobPlayerCounts()
    
    for jobName, jobCache in pairs(EconomyServer.jobsCache) do
        local oldSalary = jobCache.currentSalary
        local activePlayers = jobPlayerCounts[jobName] or 0
        
        -- Ajuster selon le nombre de joueurs (jobs sous-représentés gagnent plus)
        local avgPlayers = CalculateAverageJobPlayers(jobPlayerCounts)
        local playerRatio = activePlayers / math.max(avgPlayers, 1)
        
        -- Jobs essentiels ont une variation réduite
        local variationFactor = jobCache.essential and 0.5 or 1.0
        
        -- Formule: nouveau_salaire = salaire_actuel × (1 + ajustement)
        local salaryChange = 0
        if playerRatio < 0.5 then
            salaryChange = maxVariation * variationFactor * 0.5 -- +5% si peu de joueurs
        elseif playerRatio > 2.0 then
            salaryChange = -maxVariation * variationFactor * 0.3 -- -3% si trop de joueurs
        end
        
        local newSalary = oldSalary * (1 + salaryChange)
        
        -- Valider le salaire
        local isValid, errorMsg = Economy.ValidateSalary(newSalary)
        if isValid then
            -- Mettre à jour en BDD
            MySQL.update('UPDATE economy_jobs SET current_salary = ?, active_players = ? WHERE job_name = ?', {
                newSalary,
                activePlayers,
                jobName
            })
            
            -- Mettre à jour le cache
            jobCache.currentSalary = newSalary
            jobCache.activePlayers = activePlayers
            
            -- Logger si changement significatif (>3%)
            if math.abs(salaryChange) > 0.03 then
                LogEconomyChange('salary', jobName, oldSalary, newSalary, 'auto', nil, 'Ajustement population')
            end
            
            adjustedCount = adjustedCount + 1
        end
    end
    
    return adjustedCount
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Calculer le facteur d'activité global
-- ══════════════════════════════════════════════════════════════════════════════

function CalculateActivityFactor()
    -- Compter les transactions des dernières 24h
    local result = MySQL.query.await('SELECT COUNT(*) as count FROM economy_transactions WHERE timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)')
    
    local transactionCount = result and result[1] and result[1].count or 0
    
    -- Normaliser (1.0 = activité normale = 1000 transactions/jour)
    local activityFactor = transactionCount / 1000
    
    -- Limiter entre 0.5 et 2.0
    return math.max(0.5, math.min(2.0, activityFactor))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Obtenir le nombre de joueurs par job
-- ══════════════════════════════════════════════════════════════════════════════

function GetJobPlayerCounts()
    local counts = {}
    
    -- Parcourir tous les joueurs connectés
    local xPlayers = vCore.GetPlayers()
    for _, playerId in ipairs(xPlayers) do
        local xPlayer = vCore.GetPlayerFromId(playerId)
        if xPlayer then
            local jobName = xPlayer.job and xPlayer.job.name or 'unemployed'
            counts[jobName] = (counts[jobName] or 0) + 1
        end
    end
    
    return counts
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Calculer la moyenne de joueurs par job
-- ══════════════════════════════════════════════════════════════════════════════

function CalculateAverageJobPlayers(jobPlayerCounts)
    local total = 0
    local count = 0
    
    for _, players in pairs(jobPlayerCounts) do
        total = total + players
        count = count + 1
    end
    
    return count > 0 and (total / count) or 1
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Export: Recalculer l'économie manuellement
-- ══════════════════════════════════════════════════════════════════════════════

exports('RecalculateEconomy', function(adminIdentifier, reason)
    return RecalculateEconomy('admin', adminIdentifier, reason or 'Recalcul manuel')
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Event: Recalculer l'économie (admin)
-- ══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_economy:recalculate', function()
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer then return end
    
    -- Vérifier les permissions
    if not xPlayer.getGroup or xPlayer.getGroup() < 3 then -- Admin minimum
        TriggerClientEvent('vcore:showNotification', source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    local success, result = RecalculateEconomy('admin', xPlayer.identifier, 'Recalcul manuel par admin')
    
    if success then
        TriggerClientEvent('vcore:showNotification', source, ('Économie recalculée: %d items, %d jobs'):format(result.items, result.jobs), 'success')
    else
        TriggerClientEvent('vcore:showNotification', source, result, 'error')
    end
end)
