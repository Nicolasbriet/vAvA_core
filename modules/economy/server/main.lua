-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy Server Main
-- Logique serveur principale du système économique
-- ══════════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════════
-- État local
-- ══════════════════════════════════════════════════════════════════════════════

local EconomyServer = {
    loaded = false,
    lastRecalculate = 0,
    itemsCache = {},
    jobsCache = {},
    transactionStats = {}
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Initialisation
-- ══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(1000) -- Attendre que vCore soit chargé
    
    print('[vAvA_economy] Initialisation du système économique...')
    
    -- Charger l'état de l'économie depuis la BDD
    LoadEconomyState()
    
    -- Initialiser les items en BDD
    InitializeItems()
    
    -- Initialiser les jobs en BDD
    InitializeJobs()
    
    -- Charger les caches
    LoadItemsCache()
    LoadJobsCache()
    
    -- Démarrer le système auto-adaptatif
    if EconomyConfig.autoAdjust.enabled then
        StartAutoAdjustment()
    end
    
    -- Démarrer le monitoring
    if EconomyConfig.monitoring.enabled then
        StartMonitoring()
    end
    
    EconomyServer.loaded = true
    print('[vAvA_economy] Système économique chargé!')
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Charger l'état de l'économie
-- ══════════════════════════════════════════════════════════════════════════════

function LoadEconomyState()
    local result = MySQL.query.await('SELECT * FROM economy_state ORDER BY id DESC LIMIT 1')
    
    if result and result[1] then
        Economy.State.inflation = tonumber(result[1].inflation) or 1.0
        Economy.State.baseMultiplier = tonumber(result[1].base_multiplier) or 1.0
        Economy.State.lastUpdate = result[1].last_update or os.time()
        
        print(('[vAvA_economy] État chargé: Inflation=%.2f, Multiplicateur=%.2f'):format(
            Economy.State.inflation,
            Economy.State.baseMultiplier
        ))
    else
        -- Créer l'état par défaut
        MySQL.insert('INSERT INTO economy_state (inflation, base_multiplier, profile) VALUES (?, ?, ?)', {
            1.0,
            EconomyConfig.baseMultiplier,
            'normal'
        })
        
        Economy.State.inflation = 1.0
        Economy.State.baseMultiplier = EconomyConfig.baseMultiplier
        print('[vAvA_economy] État créé avec valeurs par défaut')
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Initialiser les items en BDD
-- ══════════════════════════════════════════════════════════════════════════════

function InitializeItems()
    local count = 0
    
    for itemName, itemData in pairs(EconomyConfig.itemsRarity) do
        local basePrice = itemData.basePrice or (itemData.rarity * EconomyConfig.baseUnit)
        local currentPrice = Economy.GetPrice(itemName)
        
        MySQL.insert('INSERT INTO economy_items (item_name, base_price, current_price, rarity, category) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE base_price = VALUES(base_price), rarity = VALUES(rarity), category = VALUES(category)', {
            itemName,
            basePrice,
            currentPrice,
            itemData.rarity,
            itemData.category
        })
        
        count = count + 1
    end
    
    print(('[vAvA_economy] %d items initialisés en BDD'):format(count))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Initialiser les jobs en BDD
-- ══════════════════════════════════════════════════════════════════════════════

function InitializeJobs()
    local count = 0
    
    for jobName, jobData in pairs(EconomyConfig.jobs) do
        local currentSalary = Economy.GetSalary(jobName, 0)
        
        MySQL.insert('INSERT INTO economy_jobs (job_name, base_salary, current_salary, bonus, essential) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE base_salary = VALUES(base_salary), bonus = VALUES(bonus), essential = VALUES(essential)', {
            jobName,
            jobData.baseSalary,
            currentSalary,
            jobData.bonus,
            jobData.essential and 1 or 0
        })
        
        count = count + 1
    end
    
    print(('[vAvA_economy] %d jobs initialisés en BDD'):format(count))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Charger le cache des items
-- ══════════════════════════════════════════════════════════════════════════════

function LoadItemsCache()
    local result = MySQL.query.await('SELECT * FROM economy_items')
    
    if result then
        for _, item in ipairs(result) do
            EconomyServer.itemsCache[item.item_name] = {
                basePrice = tonumber(item.base_price),
                currentPrice = tonumber(item.current_price),
                rarity = item.rarity,
                category = item.category,
                buyCount = item.buy_count,
                sellCount = item.sell_count
            }
        end
        
        print(('[vAvA_economy] %d items chargés en cache'):format(#result))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Charger le cache des jobs
-- ══════════════════════════════════════════════════════════════════════════════

function LoadJobsCache()
    local result = MySQL.query.await('SELECT * FROM economy_jobs')
    
    if result then
        for _, job in ipairs(result) do
            EconomyServer.jobsCache[job.job_name] = {
                baseSalary = tonumber(job.base_salary),
                currentSalary = tonumber(job.current_salary),
                bonus = tonumber(job.bonus),
                essential = job.essential == 1,
                activePlayers = job.active_players
            }
        end
        
        print(('[vAvA_economy] %d jobs chargés en cache'):format(#result))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Enregistrer une transaction
-- ══════════════════════════════════════════════════════════════════════════════

function RegisterTransaction(itemName, transactionType, quantity, price, shop, playerIdentifier)
    if not itemName or not transactionType then return end
    
    -- Insérer en BDD
    MySQL.insert('INSERT INTO economy_transactions (item_name, transaction_type, quantity, price, shop, player_identifier) VALUES (?, ?, ?, ?, ?, ?)', {
        itemName,
        transactionType,
        quantity or 1,
        price or 0,
        shop,
        playerIdentifier
    })
    
    -- Mettre à jour les compteurs
    if transactionType == 'buy' then
        MySQL.update('UPDATE economy_items SET buy_count = buy_count + ? WHERE item_name = ?', {
            quantity or 1,
            itemName
        })
    elseif transactionType == 'sell' then
        MySQL.update('UPDATE economy_items SET sell_count = sell_count + ? WHERE item_name = ?', {
            quantity or 1,
            itemName
        })
    end
    
    -- Mettre à jour le cache local
    if EconomyServer.itemsCache[itemName] then
        if transactionType == 'buy' then
            EconomyServer.itemsCache[itemName].buyCount = (EconomyServer.itemsCache[itemName].buyCount or 0) + (quantity or 1)
        else
            EconomyServer.itemsCache[itemName].sellCount = (EconomyServer.itemsCache[itemName].sellCount or 0) + (quantity or 1)
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Logger un changement économique
-- ══════════════════════════════════════════════════════════════════════════════

function LogEconomyChange(logType, itemOrJob, oldValue, newValue, source, adminIdentifier, reason)
    if not EconomyConfig.security.logAllChanges then return end
    
    local variation = 0
    if oldValue and newValue and oldValue > 0 then
        variation = ((newValue - oldValue) / oldValue) * 100
    end
    
    MySQL.insert('INSERT INTO economy_logs (log_type, item_or_job, old_value, new_value, variation_percent, source, admin_identifier, reason) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        logType,
        itemOrJob,
        oldValue,
        newValue,
        variation,
        source or 'auto',
        adminIdentifier,
        reason
    })
    
    if EconomyConfig.debug then
        print(('[vAvA_economy LOG] %s: %s | %.2f -> %.2f (%.2f%%)'):format(
            logType,
            itemOrJob or 'N/A',
            oldValue or 0,
            newValue or 0,
            variation
        ))
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Exports Server
-- ══════════════════════════════════════════════════════════════════════════════

-- Obtenir le prix d'un item
exports('GetPrice', function(itemName, shop, quantity)
    return Economy.GetPrice(itemName, shop, quantity)
end)

-- Obtenir le salaire d'un job
exports('GetSalary', function(jobName, grade)
    return Economy.GetSalary(jobName, grade)
end)

-- Obtenir le multiplicateur d'un shop
exports('GetShopMultiplier', function(shopName)
    return Economy.GetShopMultiplier(shopName)
end)

-- Appliquer une taxe
exports('ApplyTax', function(taxType, amount)
    return Economy.ApplyTax(taxType, amount)
end)

-- Obtenir l'état de l'économie
exports('GetEconomyState', function()
    return Economy.GetState()
end)

-- Enregistrer une transaction
exports('RegisterTransaction', function(itemName, transactionType, quantity, price, shop, playerIdentifier)
    RegisterTransaction(itemName, transactionType, quantity, price, shop, playerIdentifier)
end)

-- Obtenir le prix de vente
exports('GetSellPrice', function(itemName, shop, quantity)
    return Economy.GetSellPrice(itemName, shop, quantity)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Callbacks
-- ══════════════════════════════════════════════════════════════════════════════

vCore.RegisterServerCallback('vAvA_economy:getState', function(source, cb)
    cb(Economy.GetState())
end)

vCore.RegisterServerCallback('vAvA_economy:getItemInfo', function(source, cb, itemName)
    cb(Economy.GetItemInfo(itemName))
end)

vCore.RegisterServerCallback('vAvA_economy:getJobInfo', function(source, cb, jobName)
    cb(Economy.GetJobInfo(jobName))
end)

vCore.RegisterServerCallback('vAvA_economy:getAllItems', function(source, cb)
    local items = MySQL.query.await('SELECT * FROM economy_items ORDER BY category, item_name')
    cb(items or {})
end)

vCore.RegisterServerCallback('vAvA_economy:getAllJobs', function(source, cb)
    local jobs = MySQL.query.await('SELECT * FROM economy_jobs ORDER BY job_name')
    cb(jobs or {})
end)

vCore.RegisterServerCallback('vAvA_economy:getLogs', function(source, cb)
    local logs = MySQL.query.await('SELECT * FROM economy_logs ORDER BY timestamp DESC LIMIT 100')
    cb(logs or {})
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Events Admin
-- ══════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_economy:setMultiplier', function(multiplier)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() < 3 then return end
    
    local oldMultiplier = Economy.State.baseMultiplier
    Economy.State.baseMultiplier = multiplier
    
    MySQL.update('UPDATE economy_state SET base_multiplier = ?, updated_by = ? WHERE id = 1', {
        multiplier,
        xPlayer.identifier
    })
    
    LogEconomyChange('override', 'base_multiplier', oldMultiplier, multiplier, 'admin', xPlayer.identifier, 'Changement manuel multiplicateur')
    TriggerClientEvent('vcore:showNotification', source, 'Multiplicateur global modifié', 'success')
end)

RegisterNetEvent('vAvA_economy:updateItemPrice', function(itemName, newPrice)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() < 3 then return end
    
    local isValid, errorMsg = Economy.ValidatePrice(newPrice)
    if not isValid then
        TriggerClientEvent('vcore:showNotification', source, errorMsg, 'error')
        return
    end
    
    local result = MySQL.query.await('SELECT current_price FROM economy_items WHERE item_name = ?', {itemName})
    if result and result[1] then
        local oldPrice = result[1].current_price
        
        MySQL.update('UPDATE economy_items SET current_price = ? WHERE item_name = ?', {
            newPrice,
            itemName
        })
        
        LogEconomyChange('override', itemName, oldPrice, newPrice, 'admin', xPlayer.identifier, 'Modification manuelle prix')
        TriggerClientEvent('vcore:showNotification', source, ('Prix de %s modifié'):format(itemName), 'success')
    end
end)

RegisterNetEvent('vAvA_economy:updateJobSalary', function(jobName, newSalary)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() < 3 then return end
    
    local isValid, errorMsg = Economy.ValidateSalary(newSalary)
    if not isValid then
        TriggerClientEvent('vcore:showNotification', source, errorMsg, 'error')
        return
    end
    
    local result = MySQL.query.await('SELECT current_salary FROM economy_jobs WHERE job_name = ?', {jobName})
    if result and result[1] then
        local oldSalary = result[1].current_salary
        
        MySQL.update('UPDATE economy_jobs SET current_salary = ? WHERE job_name = ?', {
            newSalary,
            jobName
        })
        
        LogEconomyChange('override', jobName, oldSalary, newSalary, 'admin', xPlayer.identifier, 'Modification manuelle salaire')
        TriggerClientEvent('vcore:showNotification', source, ('Salaire de %s modifié'):format(jobName), 'success')
    end
end)

RegisterNetEvent('vAvA_economy:updateTax', function(taxType, newRate)
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() < 3 then return end
    
    MySQL.update('UPDATE economy_taxes SET rate = ? WHERE tax_type = ?', {
        newRate,
        taxType
    })
    
    EconomyConfig.taxes[taxType] = newRate
    LogEconomyChange('tax', taxType, nil, newRate, 'admin', xPlayer.identifier, 'Modification manuelle taxe')
    TriggerClientEvent('vcore:showNotification', source, ('Taxe %s modifiée'):format(taxType), 'success')
end)

RegisterNetEvent('vAvA_economy:reset', function()
    local source = source
    local xPlayer = vCore.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() < 4 then return end -- Superadmin seulement
    
    -- Réinitialiser l'état
    MySQL.update('UPDATE economy_state SET inflation = 1.0, base_multiplier = 1.0, profile = "normal" WHERE id = 1')
    
    -- Réinitialiser les items
    InitializeItems()
    
    -- Réinitialiser les jobs
    InitializeJobs()
    
    -- Recharger les caches
    LoadItemsCache()
    LoadJobsCache()
    
    Economy.State.inflation = 1.0
    Economy.State.baseMultiplier = 1.0
    
    LogEconomyChange('recalculate', 'RESET', nil, nil, 'admin', xPlayer.identifier, 'Réinitialisation complète économie')
    TriggerClientEvent('vcore:showNotification', source, 'Économie réinitialisée', 'success')
end)
