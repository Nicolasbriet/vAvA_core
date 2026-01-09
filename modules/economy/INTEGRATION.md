# 🔗 Guide d'Intégration Economy - Modules vAvA

> Ce guide explique comment adapter chaque module existant pour utiliser le système économique.

---

## 📦 Module: INVENTORY

### Fichiers à modifier
- `modules/inventory/server/main.lua`
- `modules/inventory/config.lua` (optionnel)

### Modifications requises

#### 1. Supprimer les prix en dur

**AVANT:**
```lua
-- config.lua
Config.Items = {
    bread = { label = 'Pain', price = 5 },
    water = { label = 'Eau', price = 2 }
}
```

**APRÈS:**
```lua
-- config.lua  
Config.Items = {
    bread = { label = 'Pain' }, -- Prix géré par economy
    water = { label = 'Eau' }
}
```

#### 2. Utiliser Economy.GetPrice()

**AVANT:**
```lua
-- server/main.lua
RegisterNetEvent('vAvA_inventory:buyItem', function(itemName, quantity)
    local itemConfig = Config.Items[itemName]
    local price = itemConfig.price * quantity
    
    if xPlayer.getMoney() >= price then
        xPlayer.removeMoney(price)
        -- Ajouter item
    end
end)
```

**APRÈS:**
```lua
-- server/main.lua
RegisterNetEvent('vAvA_inventory:buyItem', function(itemName, quantity, shop)
    -- Obtenir le prix depuis economy
    local basePrice = exports['economy']:GetPrice(itemName, shop, quantity)
    
    -- Appliquer la taxe d'achat
    local finalPrice, taxAmount = exports['economy']:ApplyTax('achat', basePrice)
    
    if xPlayer.getMoney() >= finalPrice then
        xPlayer.removeMoney(finalPrice)
        -- Ajouter item
        
        -- Enregistrer la transaction pour l'auto-ajustement
        exports['economy']:RegisterTransaction(
            itemName,
            'buy',
            quantity,
            finalPrice,
            shop,
            xPlayer.identifier
        )
    end
end)
```

#### 3. Prix de vente

**APRÈS:**
```lua
RegisterNetEvent('vAvA_inventory:sellItem', function(itemName, quantity)
    -- Prix de vente = 75% du prix d'achat
    local sellPrice = exports['economy']:GetSellPrice(itemName, nil, quantity)
    
    -- Appliquer la taxe de vente
    local finalPrice, taxAmount = exports['economy']:ApplyTax('vente', sellPrice)
    
    xPlayer.addMoney(finalPrice)
    -- Retirer item
    
    -- Enregistrer la transaction
    exports['economy']:RegisterTransaction(
        itemName,
        'sell',
        quantity,
        finalPrice,
        nil,
        xPlayer.identifier
    )
end)
```

---

## 💼 Module: JOBS

### Fichiers à modifier
- `modules/jobs/server/main.lua`

### Modifications requises

#### Utiliser Economy.GetSalary() pour les paychecks

**AVANT:**
```lua
-- server/main.lua
function ProcessPaychecks()
    for _, playerId in ipairs(vCore.GetPlayers()) do
        local xPlayer = vCore.GetPlayerFromId(playerId)
        if xPlayer then
            local jobConfig = JobsConfig.jobs[xPlayer.job.name]
            local salary = jobConfig.grades[xPlayer.job.grade].salary or 100
            
            xPlayer.addAccountMoney('bank', salary)
        end
    end
end
```

**APRÈS:**
```lua
-- server/main.lua
function ProcessPaychecks()
    for _, playerId in ipairs(vCore.GetPlayers()) do
        local xPlayer = vCore.GetPlayerFromId(playerId)
        if xPlayer then
            -- Obtenir le salaire depuis economy
            local baseSalary = exports['economy']:GetSalary(xPlayer.job.name, xPlayer.job.grade)
            
            -- Appliquer la taxe sur salaire
            local finalSalary, taxAmount = exports['economy']:ApplyTax('salaire', baseSalary)
            
            xPlayer.addAccountMoney('bank', finalSalary)
            
            -- Notifier le joueur
            TriggerClientEvent('vcore:showNotification', playerId, 
                ('Salaire reçu: %s $ (Taxe: %s $)'):format(finalSalary, taxAmount),
                'success'
            )
        end
    end
end
```

---

## 🚗 Module: CONCESS (Concessionnaire)

### Fichiers à modifier
- `modules/concess/server/main.lua`
- `modules/concess/vehicles.json` (optionnel)

### Modifications requises

#### 1. Ajouter les véhicules dans economy

**Dans `modules/economy/config/economy.lua`:**
```lua
EconomyConfig.itemsRarity = {
    -- Véhicules
    vehicle_adder = { rarity = 9, category = 'vehicle', basePrice = 50000 },
    vehicle_buffalo = { rarity = 5, category = 'vehicle', basePrice = 15000 },
    vehicle_faggio = { rarity = 2, category = 'vehicle', basePrice = 1500 }
}
```

#### 2. Utiliser Economy.GetPrice() + Economy.ApplyTax()

**AVANT:**
```lua
RegisterNetEvent('vAvA_concess:buyVehicle', function(vehicleModel)
    local vehicleConfig = Config.Vehicles[vehicleModel]
    local price = vehicleConfig.price
    
    if xPlayer.getAccount('bank').money >= price then
        xPlayer.removeAccountMoney('bank', price)
        -- Créer véhicule
    end
end)
```

**APRÈS:**
```lua
RegisterNetEvent('vAvA_concess:buyVehicle', function(vehicleModel, shopName)
    -- Obtenir prix depuis economy
    local itemName = 'vehicle_' .. vehicleModel
    local basePrice = exports['economy']:GetPrice(itemName, shopName)
    
    -- Appliquer taxe véhicule (10%)
    local finalPrice, taxAmount = exports['economy']:ApplyTax('vehicule', basePrice)
    
    if xPlayer.getAccount('bank').money >= finalPrice then
        xPlayer.removeAccountMoney('bank', finalPrice)
        -- Créer véhicule
        
        -- Enregistrer transaction
        exports['economy']:RegisterTransaction(
            itemName,
            'buy',
            1,
            finalPrice,
            shopName,
            xPlayer.identifier
        )
        
        TriggerClientEvent('vcore:showNotification', source, 
            ('Véhicule acheté: %s $ + Taxe: %s $'):format(basePrice, taxAmount),
            'success'
        )
    end
end)
```

---

## 🏠 Module: GARAGE

### Fichiers à modifier
- `modules/garage/server/main.lua`

### Modifications requises

#### Utiliser Economy.ApplyTax() pour la fourrière

**AVANT:**
```lua
RegisterNetEvent('vAvA_garage:payImpound', function(vehiclePlate)
    local impoundFee = 500
    
    if xPlayer.getMoney() >= impoundFee then
        xPlayer.removeMoney(impoundFee)
        -- Sortir véhicule
    end
end)
```

**APRÈS:**
```lua
RegisterNetEvent('vAvA_garage:payImpound', function(vehiclePlate)
    local baseImpoundFee = 500
    
    -- Appliquer une taxe de service (transfert par exemple)
    local finalFee, taxAmount = exports['economy']:ApplyTax('transfert', baseImpoundFee)
    
    if xPlayer.getMoney() >= finalFee then
        xPlayer.removeMoney(finalFee)
        -- Sortir véhicule
        
        TriggerClientEvent('vcore:showNotification', source, 
            ('Fourrière payée: %s $ (+ Taxe: %s $)'):format(baseImpoundFee, taxAmount),
            'success'
        )
    end
end)
```

---

## 🏪 Module: JOBSHOP

### Fichiers à modifier
- `modules/jobshop/server/main.lua`

### Modifications requises

#### Utiliser Economy.GetPrice() avec shop multiplier

**AVANT:**
```lua
RegisterNetEvent('vAvA_jobshop:buyItem', function(itemName, quantity)
    local shopConfig = Config.Shops[currentShop]
    local itemPrice = shopConfig.items[itemName].price
    local totalPrice = itemPrice * quantity
    
    if xPlayer.getMoney() >= totalPrice then
        xPlayer.removeMoney(totalPrice)
        -- Ajouter item
    end
end)
```

**APRÈS:**
```lua
RegisterNetEvent('vAvA_jobshop:buyItem', function(itemName, quantity, shopName)
    -- Le shopName détermine le multiplicateur
    -- Ex: 'ambulance_pharmacy' pourrait avoir un multiplier de 1.2
    local basePrice = exports['economy']:GetPrice(itemName, shopName, quantity)
    
    -- Appliquer taxe achat
    local finalPrice, taxAmount = exports['economy']:ApplyTax('achat', basePrice)
    
    if xPlayer.getMoney() >= finalPrice then
        xPlayer.removeMoney(finalPrice)
        -- Ajouter item
        
        -- Enregistrer transaction
        exports['economy']:RegisterTransaction(
            itemName,
            'buy',
            quantity,
            finalPrice,
            shopName,
            xPlayer.identifier
        )
    end
end)
```

---

## 🎯 Checklist Complète par Module

### ✅ INVENTORY
- [ ] Supprimer prix en dur dans config
- [ ] Remplacer par `Economy.GetPrice()`
- [ ] Ajouter `Economy.ApplyTax('achat')`
- [ ] Implémenter `Economy.GetSellPrice()`
- [ ] Ajouter `Economy.RegisterTransaction()`
- [ ] Tester achat/vente
- [ ] Vérifier que les prix s'ajustent

### ✅ JOBS
- [ ] Modifier système de paycheck
- [ ] Utiliser `Economy.GetSalary()`
- [ ] Ajouter `Economy.ApplyTax('salaire')`
- [ ] Tester avec différents grades
- [ ] Vérifier notifications joueurs

### ✅ CONCESS
- [ ] Ajouter véhicules dans economy config
- [ ] Remplacer prix par `Economy.GetPrice()`
- [ ] Ajouter `Economy.ApplyTax('vehicule')`
- [ ] Ajouter `Economy.RegisterTransaction()`
- [ ] Tester avec différents shops

### ✅ GARAGE
- [ ] Modifier frais fourrière
- [ ] Utiliser `Economy.ApplyTax()`
- [ ] Tester sortie fourrière

### ✅ JOBSHOP
- [ ] Configurer shops avec multipliers
- [ ] Utiliser `Economy.GetPrice()` avec shop
- [ ] Ajouter `Economy.ApplyTax()`
- [ ] Ajouter `Economy.RegisterTransaction()`
- [ ] Tester avec différents métiers

---

## 🧪 Tests Recommandés

### Test 1: Prix dynamiques
1. Acheter 50x le même item
2. Vérifier dans dashboard que le prix a augmenté
3. Vendre 50x le même item
4. Vérifier que le prix a diminué

### Test 2: Salaires
1. Vérifier salaire avec grade 0
2. Promouvoir au grade 2
3. Vérifier que salaire a augmenté de ~20%

### Test 3: Taxes
1. Acheter item à 100$
2. Vérifier que le montant débité est 105$ (taxe 5%)
3. Vérifier les logs dans le dashboard

### Test 4: Multiplicateur global
1. Mettre baseMultiplier à 0.5
2. Vérifier que TOUS les prix sont divisés par 2
3. Remettre à 1.0

### Test 5: Shops
1. Acheter dans un shop "pauvre" (multiplier 0.8)
2. Acheter le même item dans un shop "luxe" (multiplier 2.0)
3. Vérifier la différence de prix

---

## 💡 Bonnes Pratiques

### ✅ À FAIRE
- Toujours utiliser `exports['economy']:GetPrice()`
- Toujours appliquer les taxes appropriées
- Toujours enregistrer les transactions importantes
- Notifier le joueur du prix final + taxes
- Tester avec différents profils économiques

### ❌ À NE PAS FAIRE
- Ne jamais coder les prix en dur
- Ne pas oublier d'enregistrer les transactions
- Ne pas bypass les taxes
- Ne pas modifier directement la BDD economy
- Ne pas oublier le paramètre `shop` si applicable

---

## 📞 Support

Si un module ne fonctionne pas après intégration:
1. Vérifier les logs serveur
2. Vérifier que `vAvA_economy` est bien chargé avant le module
3. Vérifier que l'item existe dans `EconomyConfig.itemsRarity`
4. Consulter le dashboard admin pour voir les logs

---

**© 2026 vAvA - Guide d'Intégration Economy v1.0**
