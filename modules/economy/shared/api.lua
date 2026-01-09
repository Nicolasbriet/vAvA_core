-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy API (Shared)
-- API publique pour tous les modules
-- ══════════════════════════════════════════════════════════════════════════════

Economy = {}
Economy.State = {
    inflation = 1.0,
    baseMultiplier = 1.0,
    lastUpdate = 0
}

-- ══════════════════════════════════════════════════════════════════════════════
-- 💰 Obtenir le prix final d'un item
-- ══════════════════════════════════════════════════════════════════════════════
-- @param itemName string - Nom de l'item
-- @param shop string (optional) - Nom du shop (pour appliquer le multiplicateur shop)
-- @param quantity number (optional) - Quantité (défaut: 1)
-- @return number - Prix final calculé
--
-- Formule: prix_final = basePrice × rarity × baseMultiplier × shopMultiplier × inflation × taxes

function Economy.GetPrice(itemName, shop, quantity)
    if not itemName then return 0 end
    
    local item = EconomyConfig.itemsRarity[itemName]
    if not item then
        if EconomyConfig.debug then
            print(('[vAvA_economy] Item non trouvé: %s'):format(itemName))
        end
        return 0
    end
    
    -- Prix de base
    local basePrice = item.basePrice or (item.rarity * EconomyConfig.baseUnit)
    
    -- Multiplicateur global
    local globalMultiplier = Economy.State.baseMultiplier or EconomyConfig.baseMultiplier
    
    -- Multiplicateur shop
    local shopMultiplier = 1.0
    if shop and EconomyConfig.shops[shop] then
        shopMultiplier = EconomyConfig.shops[shop]
    end
    
    -- Inflation
    local inflation = Economy.State.inflation or 1.0
    
    -- Quantité
    local qty = quantity or 1
    
    -- Calcul final
    local finalPrice = basePrice * globalMultiplier * shopMultiplier * inflation * qty
    
    -- Arrondir à 2 décimales
    return math.floor(finalPrice * 100 + 0.5) / 100
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 💼 Obtenir le salaire final d'un job
-- ══════════════════════════════════════════════════════════════════════════════
-- @param jobName string - Nom du job
-- @param grade number (optional) - Grade du job (défaut: 0)
-- @return number - Salaire final calculé
--
-- Formule: salaire_final = baseSalary × bonus × baseMultiplier × inflation

function Economy.GetSalary(jobName, grade)
    if not jobName then return 0 end
    
    local job = EconomyConfig.jobs[jobName]
    if not job then
        if EconomyConfig.debug then
            print(('[vAvA_economy] Job non trouvé: %s'):format(jobName))
        end
        return 0
    end
    
    -- Salaire de base
    local baseSalary = job.baseSalary or 0
    
    -- Bonus job
    local bonus = job.bonus or 1.0
    
    -- Multiplicateur global
    local globalMultiplier = Economy.State.baseMultiplier or EconomyConfig.baseMultiplier
    
    -- Inflation
    local inflation = Economy.State.inflation or 1.0
    
    -- Bonus grade (10% par grade)
    local gradeBonus = 1.0 + ((grade or 0) * 0.1)
    
    -- Calcul final
    local finalSalary = baseSalary * bonus * globalMultiplier * inflation * gradeBonus
    
    -- Arrondir
    return math.floor(finalSalary + 0.5)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛍️ Obtenir le multiplicateur d'un shop
-- ══════════════════════════════════════════════════════════════════════════════
-- @param shopName string - Nom du shop
-- @return number - Multiplicateur du shop

function Economy.GetShopMultiplier(shopName)
    if not shopName then return 1.0 end
    return EconomyConfig.shops[shopName] or 1.0
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 💳 Appliquer une taxe
-- ══════════════════════════════════════════════════════════════════════════════
-- @param taxType string - Type de taxe (achat, vente, salaire, transfert, vehicule, immobilier)
-- @param amount number - Montant de base
-- @return number - Montant avec taxe
-- @return number - Montant de la taxe

function Economy.ApplyTax(taxType, amount)
    if not taxType or not amount then return amount, 0 end
    
    local tax = EconomyConfig.taxes[taxType] or 0
    local taxAmount = amount * tax
    local finalAmount = amount + taxAmount
    
    return math.floor(finalAmount * 100 + 0.5) / 100, math.floor(taxAmount * 100 + 0.5) / 100
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🎯 Obtenir la rareté d'un item
-- ══════════════════════════════════════════════════════════════════════════════
-- @param itemName string - Nom de l'item
-- @return number - Rareté (1-10)

function Economy.GetItemRarity(itemName)
    if not itemName then return 1 end
    
    local item = EconomyConfig.itemsRarity[itemName]
    if not item then return 1 end
    
    return item.rarity or 1
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📊 Obtenir l'état de l'économie
-- ══════════════════════════════════════════════════════════════════════════════
-- @return table - État complet de l'économie

function Economy.GetState()
    return {
        inflation = Economy.State.inflation,
        baseMultiplier = Economy.State.baseMultiplier,
        lastUpdate = Economy.State.lastUpdate,
        profile = Economy.GetCurrentProfile()
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📈 Obtenir le profil économique actuel
-- ══════════════════════════════════════════════════════════════════════════════
-- @return string - Nom du profil

function Economy.GetCurrentProfile()
    local multiplier = Economy.State.baseMultiplier
    
    for profileName, profileMultiplier in pairs(EconomyConfig.profiles) do
        if math.abs(multiplier - profileMultiplier) < 0.01 then
            return profileName
        end
    end
    
    return 'custom'
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📊 Calculer le prix de vente (75% du prix d'achat par défaut)
-- ══════════════════════════════════════════════════════════════════════════════
-- @param itemName string - Nom de l'item
-- @param shop string (optional) - Nom du shop
-- @param quantity number (optional) - Quantité
-- @return number - Prix de vente

function Economy.GetSellPrice(itemName, shop, quantity)
    local buyPrice = Economy.GetPrice(itemName, shop, quantity)
    return math.floor(buyPrice * 0.75 * 100 + 0.5) / 100
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🔧 Formater un montant en devise
-- ══════════════════════════════════════════════════════════════════════════════
-- @param amount number - Montant
-- @return string - Montant formaté (ex: "1 234.56 $")

function Economy.FormatMoney(amount)
    if not amount then return '0 $' end
    
    local formatted = tostring(math.floor(amount * 100 + 0.5) / 100)
    local int, dec = formatted:match('([^.]+)%.?([^.]*)')
    
    -- Ajouter espaces tous les 3 chiffres
    int = int:reverse():gsub('(%d%d%d)', '%1 '):reverse()
    if int:sub(1, 1) == ' ' then int = int:sub(2) end
    
    if dec and dec ~= '' then
        return int .. '.' .. dec .. ' $'
    else
        return int .. ' $'
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 📦 Obtenir les informations complètes d'un item
-- ══════════════════════════════════════════════════════════════════════════════
-- @param itemName string - Nom de l'item
-- @return table - Informations de l'item

function Economy.GetItemInfo(itemName)
    if not itemName then return nil end
    
    local item = EconomyConfig.itemsRarity[itemName]
    if not item then return nil end
    
    return {
        name = itemName,
        rarity = item.rarity,
        category = item.category,
        basePrice = item.basePrice,
        currentPrice = Economy.GetPrice(itemName),
        sellPrice = Economy.GetSellPrice(itemName)
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 💼 Obtenir les informations complètes d'un job
-- ══════════════════════════════════════════════════════════════════════════════
-- @param jobName string - Nom du job
-- @return table - Informations du job

function Economy.GetJobInfo(jobName)
    if not jobName then return nil end
    
    local job = EconomyConfig.jobs[jobName]
    if not job then return nil end
    
    return {
        name = jobName,
        baseSalary = job.baseSalary,
        bonus = job.bonus,
        essential = job.essential,
        currentSalary = Economy.GetSalary(jobName, 0)
    }
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛡️ Valider un prix
-- ══════════════════════════════════════════════════════════════════════════════
-- @param price number - Prix à valider
-- @return boolean - Valide ou non
-- @return string - Message d'erreur

function Economy.ValidatePrice(price)
    if not price or type(price) ~= 'number' then
        return false, 'Prix invalide'
    end
    
    if price < EconomyConfig.autoAdjust.minPrice then
        return false, 'Prix trop bas'
    end
    
    if price > EconomyConfig.autoAdjust.maxPrice then
        return false, 'Prix trop élevé'
    end
    
    return true, ''
end

-- ══════════════════════════════════════════════════════════════════════════════
-- 🛡️ Valider un salaire
-- ══════════════════════════════════════════════════════════════════════════════
-- @param salary number - Salaire à valider
-- @return boolean - Valide ou non
-- @return string - Message d'erreur

function Economy.ValidateSalary(salary)
    if not salary or type(salary) ~= 'number' then
        return false, 'Salaire invalide'
    end
    
    if salary < EconomyConfig.autoAdjust.minSalary then
        return false, 'Salaire trop bas'
    end
    
    if salary > EconomyConfig.autoAdjust.maxSalary then
        return false, 'Salaire trop élevé'
    end
    
    return true, ''
end
