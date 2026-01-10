# 🎯 Exemples Builder - vAvA_core

## Menu Builder

### Exemple simple

```lua
vCore.Menu('Mon Menu')
    :SetSubtitle('Choisissez une option')
    :AddElement('Option 1', 'opt1', 'Description option 1')
    :AddElement('Option 2', 'opt2', 'Description option 2')
    :AddElement('Option 3', 'opt3', 'Description option 3')
    :OnSelect(function(element)
        print('Sélectionné:', element.value)
    end)
    :OnClose(function()
        print('Menu fermé')
    end)
    :Show()  -- Client
    -- ou
    :Show(source)  -- Serveur -> envoie au joueur
```

### Menu dynamique

```lua
-- Récupérer véhicules du joueur
local vehicles = GetPlayerVehicles(identifier)

local menu = vCore.Menu('Mes Véhicules')
    :SetSubtitle('Sélectionnez un véhicule')

-- Ajouter éléments dynamiquement
for _, vehicle in ipairs(vehicles) do
    menu:AddElement(
        vehicle.model .. ' (' .. vehicle.plate .. ')',
        vehicle.id,
        'Carburant: ' .. vehicle.fuel .. '%'
    )
end

menu:OnSelect(function(element)
        -- Spawn véhicule sélectionné
        TriggerServerEvent('garage:spawnVehicle', element.value)
    end)
    :Show()
```

### Menu imbriqué

```lua
local mainMenu = vCore.Menu('Menu Principal')
    :AddElement('Véhicules', 'vehicles')
    :AddElement('Inventaire', 'inventory')
    :AddElement('Paramètres', 'settings')
    :OnSelect(function(element)
        if element.value == 'vehicles' then
            ShowVehicleMenu()
        elseif element.value == 'inventory' then
            ShowInventoryMenu()
        end
    end)
    :Show()

function ShowVehicleMenu()
    vCore.Menu('Véhicules')
        :AddElement('Sortir véhicule', 'spawn')
        :AddElement('Ranger véhicule', 'store')
        :AddElement('Retour', 'back')
        :OnSelect(function(element)
            if element.value == 'back' then
                mainMenu:Show()
            end
        end)
        :Show()
end
```

---

## Notification Builder

### Notifications simples

```lua
-- Succès
vCore.Notify('Opération réussie!')
    :Type('success')
    :Duration(3000)
    :Show()

-- Erreur
vCore.Notify('Une erreur est survenue')
    :Type('error')
    :Duration(5000)
    :Show(source)  -- Serveur

-- Warning
vCore.Notify('Attention!')
    :Type('warning')
    :Show()

-- Info
vCore.Notify('Information importante')
    :Type('info')
    :Duration(7000)
    :Show()
```

### Notification contextuelle

```lua
-- Lors d'une transaction
if player:HasMoney('cash', price) then
    player:RemoveMoney('cash', price, 'Achat article')
    
    vCore.Notify('Achat réussi!')
        :Type('success')
        :Duration(3000)
        :Show(source)
else
    vCore.Notify('Fonds insuffisants! Nécessaire: ' .. vCore.Utils.FormatMoney(price))
        :Type('error')
        :Duration(5000)
        :Show(source)
end
```

---

## Progress Builder

### Progress simple

```lua
vCore.Progress('Réparation en cours...', 5000)
    :CanCancel(true)
    :Animation('mini@repair', 'fixing_a_player')
    :OnComplete(function()
        print('Réparation terminée!')
    end)
    :OnCancel(function()
        print('Réparation annulée')
    end)
    :Show()
```

### Progress avec prop

```lua
vCore.Progress('Récolte...', 10000)
    :CanCancel(false)
    :Animation('amb@world_human_gardener_plant@male@base', 'base')
    :Prop('prop_tool_pickaxe', 60309, {
        x = 0.08, y = 0.0, z = -0.20
    }, {
        x = -90.0, y = 0.0, z = 0.0
    })
    :OnComplete(function()
        TriggerServerEvent('harvest:complete', 'weed')
    end)
    :Show()
```

### Progress complexe

```lua
-- Système de réparation véhicule
local repairSteps = {
    {label = 'Inspection...', duration = 3000},
    {label = 'Démontage...', duration = 5000},
    {label = 'Réparation moteur...', duration = 8000},
    {label = 'Remontage...', duration = 5000},
    {label = 'Test final...', duration = 3000}
}

local currentStep = 1

function RepairNextStep()
    if currentStep > #repairSteps then
        vCore.Notify('Réparation terminée!')
            :Type('success')
            :Show()
        return
    end
    
    local step = repairSteps[currentStep]
    
    vCore.Progress(step.label, step.duration)
        :CanCancel(true)
        :Animation('mini@repair', 'fixing_a_player')
        :OnComplete(function()
            currentStep = currentStep + 1
            RepairNextStep()
        end)
        :OnCancel(function()
            vCore.Notify('Réparation annulée!')
                :Type('warning')
                :Show()
        end)
        :Show()
end

RepairNextStep()
```

---

## Query Builder

### SELECT simple

```lua
-- SELECT * FROM users WHERE identifier = ?
local users = vCore.Query('users')
    :Where('identifier', '=', identifier)
    :Execute()

-- Premier résultat
local user = vCore.Query('users')
    :Where('identifier', '=', identifier)
    :First()
```

### SELECT avec ORDER et LIMIT

```lua
-- Top 10 des joueurs les plus riches
local richPlayers = vCore.Query('characters')
    :Select('firstname', 'lastname', 'money')
    :OrderBy('money', 'DESC')
    :Limit(10)
    :Execute()

for _, player in ipairs(richPlayers) do
    print(player.firstname, player.lastname, player.money)
end
```

### Conditions multiples

```lua
-- Joueurs police en service
local cops = vCore.Query('characters')
    :Where('job', '=', 'police')
    :Where('job_grade', '>=', 2)
    :Where('on_duty', '=', 1)
    :Execute()
```

### Avec pagination

```lua
-- Page 2, 20 résultats par page
local page = 2
local perPage = 20
local offset = (page - 1) * perPage

local vehicles = vCore.Query('vehicles')
    :Where('owner', '=', identifier)
    :OrderBy('created_at', 'DESC')
    :Limit(perPage)
    :Offset(offset)
    :Execute()
```

---

## Command Builder

### Commande admin simple

```lua
vCore.Command('heal')
    :Help('Soigne un joueur')
    :Param('id', 'ID du joueur', true)
    :MinLevel(vCore.PermissionLevel.MODERATOR)
    :Handler(function(source, args)
        local targetId = tonumber(args[1])
        
        if not targetId then
            vCore.Notify('ID invalide')
                :Type('error')
                :Show(source)
            return
        end
        
        local target = vCore.GetPlayer(targetId)
        if not target then
            vCore.Notify('Joueur non trouvé')
                :Type('error')
                :Show(source)
            return
        end
        
        -- Heal player (client event)
        TriggerClientEvent('esx_ambulancejob:heal', targetId, 'full')
        
        vCore.Notify('Joueur soigné!')
            :Type('success')
            :Show(source)
    end)
    :Register()
```

### Commande avec multiples paramètres

```lua
vCore.Command('setmoney')
    :Help('Définit l\'argent d\'un joueur')
    :Param('id', 'ID du joueur', true)
    :Param('type', 'Type (cash/bank/black)', true)
    :Param('amount', 'Montant', true)
    :MinLevel(vCore.PermissionLevel.ADMIN)
    :Handler(function(source, args)
        local targetId = tonumber(args[1])
        local moneyType = args[2]
        local amount = tonumber(args[3])
        
        -- Validation
        local valid, err = vCore.Validation.IsMoneyType(moneyType)
        if not valid then
            vCore.Notify(err):Type('error'):Show(source)
            return
        end
        
        valid, err = vCore.Validation.IsAmount(amount)
        if not valid then
            vCore.Notify(err):Type('error'):Show(source)
            return
        end
        
        local player = vCore.GetPlayer(targetId)
        if not player then
            vCore.Notify('Joueur non trouvé'):Type('error'):Show(source)
            return
        end
        
        -- Appliquer
        player:SetMoney(moneyType, amount, 'Admin setmoney')
        
        vCore.Notify('Argent défini: ' .. vCore.Utils.FormatMoney(amount))
            :Type('success')
            :Show(source)
            
        -- Log
        vCore.DB.AddLog('admin', source, 'SetMoney: ' .. amount .. ' ' .. moneyType .. ' to ' .. targetId)
    end)
    :Register()
```

### Commande joueur

```lua
vCore.Command('me')
    :Help('Action RP visible')
    :Param('texte', 'Texte de l\'action', true)
    :Handler(function(source, args)
        local text = table.concat(args, ' ')
        local playerName = GetPlayerName(source)
        
        -- Valider longueur
        local valid, err = vCore.Validation.IsString(text, 1, 150)
        if not valid then
            vCore.Notify(err):Type('error'):Show(source)
            return
        end
        
        -- Sanitize
        text = vCore.Validation.SanitizeHTML(text)
        
        -- Envoyer à tous les joueurs proches
        TriggerClientEvent('chat:addMeAction', -1, source, playerName, text)
    end)
    :Register()
```

---

## Exemples Combinés

### Menu avec callback serveur

```lua
-- CLIENT
vCore.Menu('Boutique')
    :AddElement('Pain - 5$', 'bread')
    :AddElement('Eau - 3$', 'water')
    :AddElement('Téléphone - 500$', 'phone')
    :OnSelect(function(element)
        -- Appeler serveur
        vCore.TriggerCallback('shop:buy', function(success, message)
            if success then
                vCore.Notify(message):Type('success'):Show()
            else
                vCore.Notify(message):Type('error'):Show()
            end
        end, element.value)
    end)
    :Show()

-- SERVER
vCore.RegisterCallback('shop:buy', function(source, cb, itemName)
    local player = vCore.GetPlayer(source)
    if not player then
        cb(false, 'Erreur joueur')
        return
    end
    
    local prices = {bread = 5, water = 3, phone = 500}
    local price = prices[itemName]
    
    if not price then
        cb(false, 'Article invalide')
        return
    end
    
    if not player:HasMoney('cash', price) then
        cb(false, 'Fonds insuffisants')
        return
    end
    
    player:RemoveMoney('cash', price, 'Achat ' .. itemName)
    -- Ajouter item (système inventaire)
    
    cb(true, 'Achat réussi!')
end)
```

### System de craft avec progress

```lua
-- CLIENT
function StartCrafting(recipe)
    -- Vérifier ingrédients côté serveur
    vCore.TriggerCallback('craft:canCraft', function(canCraft, missing)
        if not canCraft then
            vCore.Notify('Ingrédients manquants: ' .. table.concat(missing, ', '))
                :Type('error')
                :Show()
            return
        end
        
        -- Démarrer progress
        vCore.Progress('Fabrication de ' .. recipe.label .. '...', recipe.duration)
            :CanCancel(true)
            :Animation('anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector')
            :OnComplete(function()
                -- Terminer craft côté serveur
                TriggerServerEvent('craft:complete', recipe.name)
            end)
            :OnCancel(function()
                vCore.Notify('Fabrication annulée'):Type('warning'):Show()
            end)
            :Show()
    end, recipe.name)
end

-- SERVER
vCore.RegisterCallback('craft:canCraft', function(source, cb, recipeName)
    local player = vCore.GetPlayer(source)
    local recipe = Recipes[recipeName]
    
    if not recipe then
        cb(false, {})
        return
    end
    
    local missing = {}
    for _, ingredient in ipairs(recipe.ingredients) do
        if not player:HasItem(ingredient.name, ingredient.amount) then
            table.insert(missing, ingredient.name)
        end
    end
    
    cb(#missing == 0, missing)
end)

RegisterServerEvent('craft:complete')
AddEventHandler('craft:complete', function(recipeName)
    local source = source
    local player = vCore.GetPlayer(source)
    local recipe = Recipes[recipeName]
    
    -- Retirer ingrédients
    for _, ingredient in ipairs(recipe.ingredients) do
        player:RemoveItem(ingredient.name, ingredient.amount)
    end
    
    -- Ajouter résultat
    player:AddItem(recipe.result, recipe.resultAmount)
    
    vCore.Notify('Vous avez fabriqué ' .. recipe.label .. '!')
        :Type('success')
        :Show(source)
end)
```

---

## Best Practices

### 1. Chaînage fluide

```lua
-- ✅ Bon
vCore.Menu('Menu')
    :AddElement('A', 'a')
    :AddElement('B', 'b')
    :OnSelect(handler)
    :Show()

-- ❌ Éviter
local menu = vCore.Menu('Menu')
menu:AddElement('A', 'a')
menu:AddElement('B', 'b')
menu:OnSelect(handler)
menu:Show()
```

### 2. Validation systématique

```lua
vCore.Command('givemoney')
    :Handler(function(source, args)
        -- Toujours valider les entrées
        local amount = tonumber(args[1])
        local valid, err = vCore.Validation.IsAmount(amount)
        
        if not valid then
            vCore.Notify(err):Type('error'):Show(source)
            return
        end
        
        -- Suite du code...
    end)
    :Register()
```

### 3. Feedback utilisateur clair

```lua
-- ✅ Messages clairs
vCore.Notify('Véhicule réparé avec succès!')
    :Type('success')
    :Show()

vCore.Notify('Impossible de réparer: véhicule trop endommagé')
    :Type('error')
    :Duration(7000)
    :Show()

-- ❌ Messages vagues
vCore.Notify('OK'):Show()
vCore.Notify('Erreur'):Show()
```

---

*Exemples Builder v1.0.0 - Développez plus vite avec les builders!*
