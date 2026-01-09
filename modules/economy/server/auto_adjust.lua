-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy Auto-Adjustment System
-- Système d'ajustement automatique des prix et salaires
-- ══════════════════════════════════════════════════════════════════════════════

-- Attendre que vCore soit disponible
local vCore = nil
CreateThread(function()
    while not vCore do
        vCore = exports['vAvA_core']:GetCoreObject()
        if not vCore then 
            Wait(100) 
        end
    end
end)

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

-- ══════════════════════════════════════════════════════════════════════════════
-- Système de Monitoring
-- ══════════════════════════════════════════════════════════════════════════════

local MonitoringData = {
    transactions = {},
    alerts = {},
    lastReport = 0
}

function StartMonitoring()
    print('[vAvA_economy] Système de monitoring démarré')
    
    -- Thread de collecte des métriques
    CreateThread(function()
        while true do
            Wait((EconomyConfig.monitoring.interval or 300) * 1000) -- Par défaut 5 minutes
            
            if EconomyConfig.monitoring.enabled then
                CollectMonitoringMetrics()
            end
        end
    end)
    
    -- Thread de génération de rapports
    CreateThread(function()
        while true do
            Wait((EconomyConfig.monitoring.reportInterval or 3600) * 1000) -- Par défaut 1 heure
            
            if EconomyConfig.monitoring.enabled then
                GenerateEconomyReport()
            end
        end
    end)
    
    -- Thread de détection d'anomalies
    CreateThread(function()
        while true do
            Wait(60000) -- Vérifier toutes les minutes
            
            if EconomyConfig.monitoring.enabled and EconomyConfig.monitoring.alertsEnabled then
                DetectAnomalies()
            end
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Collecter les métriques de monitoring
-- ══════════════════════════════════════════════════════════════════════════════

function CollectMonitoringMetrics()
    local metrics = {
        timestamp = os.time(),
        playerCount = #vCore.GetPlayers(),
        totalTransactions = 0,
        totalVolume = 0,
        inflation = Economy.State.inflation,
        baseMultiplier = Economy.State.baseMultiplier
    }
    
    -- Compter les transactions récentes
    local result = MySQL.query.await([[
        SELECT 
            COUNT(*) as count,
            COALESCE(SUM(price * quantity), 0) as volume
        FROM economy_transactions 
        WHERE timestamp > DATE_SUB(NOW(), INTERVAL 5 MINUTE)
    ]])
    
    if result and result[1] then
        metrics.totalTransactions = result[1].count or 0
        metrics.totalVolume = result[1].volume or 0
    end
    
    -- Sauvegarder les métriques
    table.insert(MonitoringData.transactions, metrics)
    
    -- Garder seulement les 100 dernières entrées
    if #MonitoringData.transactions > 100 then
        table.remove(MonitoringData.transactions, 1)
    end
    
    if EconomyConfig.debug then
        print(('[vAvA_economy MONITOR] Players: %d | Transactions: %d | Volume: $%d'):format(
            metrics.playerCount,
            metrics.totalTransactions,
            metrics.totalVolume
        ))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Générer un rapport économique
-- ══════════════════════════════════════════════════════════════════════════════

function GenerateEconomyReport()
    local report = {
        generatedAt = os.time(),
        period = 'hourly',
        summary = {},
        topItems = {},
        alerts = MonitoringData.alerts
    }
    
    -- Résumé des transactions
    local summary = MySQL.query.await([[
        SELECT 
            transaction_type,
            COUNT(*) as count,
            COALESCE(SUM(price * quantity), 0) as total_volume,
            COALESCE(AVG(price), 0) as avg_price
        FROM economy_transactions 
        WHERE timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
        GROUP BY transaction_type
    ]])
    
    if summary then
        for _, row in ipairs(summary) do
            report.summary[row.transaction_type] = {
                count = row.count,
                volume = row.total_volume,
                avgPrice = row.avg_price
            }
        end
    end
    
    -- Top items échangés
    local topItems = MySQL.query.await([[
        SELECT 
            item_name,
            COUNT(*) as transaction_count,
            COALESCE(SUM(quantity), 0) as total_quantity,
            COALESCE(SUM(price * quantity), 0) as total_volume
        FROM economy_transactions 
        WHERE timestamp > DATE_SUB(NOW(), INTERVAL 1 HOUR)
        GROUP BY item_name
        ORDER BY transaction_count DESC
        LIMIT 10
    ]])
    
    if topItems then
        report.topItems = topItems
    end
    
    -- Sauvegarder le rapport en BDD
    MySQL.insert([[
        INSERT INTO economy_reports (report_type, report_data, generated_at)
        VALUES (?, ?, NOW())
    ]], { 'hourly', json.encode(report) })
    
    -- Réinitialiser les alertes après le rapport
    MonitoringData.alerts = {}
    MonitoringData.lastReport = os.time()
    
    print('[vAvA_economy] Rapport économique généré')
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Détecter les anomalies économiques
-- ══════════════════════════════════════════════════════════════════════════════

function DetectAnomalies()
    local alerts = {}
    
    -- Détecter les variations de prix anormales
    local priceAnomalies = MySQL.query.await([[
        SELECT 
            item_name,
            current_price,
            base_price,
            ((current_price - base_price) / base_price * 100) as variation
        FROM economy_items
        WHERE ABS((current_price - base_price) / base_price * 100) > 50
    ]])
    
    if priceAnomalies then
        for _, item in ipairs(priceAnomalies) do
            table.insert(alerts, {
                type = 'price_anomaly',
                item = item.item_name,
                variation = item.variation,
                message = ('Prix anormal: %s (%.1f%% de variation)'):format(item.item_name, item.variation),
                severity = math.abs(item.variation) > 100 and 'high' or 'medium',
                timestamp = os.time()
            })
        end
    end
    
    -- Détecter les transactions suspectes (volume inhabituel)
    local suspiciousTransactions = MySQL.query.await([[
        SELECT 
            player_identifier,
            COUNT(*) as transaction_count,
            SUM(price * quantity) as total_volume
        FROM economy_transactions
        WHERE timestamp > DATE_SUB(NOW(), INTERVAL 10 MINUTE)
        GROUP BY player_identifier
        HAVING transaction_count > 50 OR total_volume > 100000
    ]])
    
    if suspiciousTransactions then
        for _, tx in ipairs(suspiciousTransactions) do
            table.insert(alerts, {
                type = 'suspicious_activity',
                player = tx.player_identifier,
                transactionCount = tx.transaction_count,
                volume = tx.total_volume,
                message = ('Activité suspecte: %d transactions / $%d en 10min'):format(tx.transaction_count, tx.total_volume),
                severity = 'high',
                timestamp = os.time()
            })
        end
    end
    
    -- Détecter l'inflation excessive
    if Economy.State.inflation > EconomyConfig.inflation.maxInflation * 0.9 then
        table.insert(alerts, {
            type = 'high_inflation',
            value = Economy.State.inflation,
            message = ('Inflation élevée: %.2f'):format(Economy.State.inflation),
            severity = 'medium',
            timestamp = os.time()
        })
    end
    
    -- Ajouter les alertes
    for _, alert in ipairs(alerts) do
        table.insert(MonitoringData.alerts, alert)
        
        -- Logger les alertes de haute sévérité
        if alert.severity == 'high' then
            LogEconomyChange('alert', alert.type, nil, nil, 'monitoring', nil, alert.message)
            
            -- Notifier les admins en ligne
            NotifyAdmins(alert)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Notifier les admins des alertes critiques
-- ══════════════════════════════════════════════════════════════════════════════

function NotifyAdmins(alert)
    local xPlayers = vCore.GetPlayers()
    
    for _, playerId in ipairs(xPlayers) do
        local xPlayer = vCore.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.getGroup and xPlayer.getGroup() >= 3 then
            TriggerClientEvent('vcore:showNotification', playerId, 
                '[ÉCONOMIE] ' .. alert.message, 
                'warning'
            )
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Exports Monitoring
-- ══════════════════════════════════════════════════════════════════════════════

exports('GetMonitoringData', function()
    return MonitoringData
end)

exports('GetEconomyAlerts', function()
    return MonitoringData.alerts
end)

exports('GenerateReport', function()
    GenerateEconomyReport()
    return true
end)
