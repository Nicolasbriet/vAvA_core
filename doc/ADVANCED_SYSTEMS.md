# 🚀 vAvA_core - Systèmes Avancés

Ce document présente les systèmes avancés qui rendent la création de modules **extrêmement simple**.

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Hooks System](#hooks-system)
3. [Decorators](#decorators)
4. [Middleware](#middleware)
5. [State Manager](#state-manager)
6. [Exemples Complets](#exemples-complets)

---

## 🎯 Vue d'Ensemble

### Philosophie

Le framework vAvA_core est conçu pour que **créer des modules soit un jeu d'enfant**. Avec ces systèmes avancés, vous pouvez :

- ✅ **Hooks** : Étendre les fonctionnalités sans modifier le code
- ✅ **Decorators** : Ajouter des comportements (retry, cache, validation) sans boilerplate
- ✅ **Middleware** : Pipeline de traitement pour requêtes/commandes
- ✅ **State Manager** : État global réactif avec observers

### Architecture

```
Module Simple
    ↓
+ Hooks (extensibilité)
    ↓
+ Decorators (comportements)
    ↓
+ Middleware (pipeline)
    ↓
+ State (réactivité)
    ↓
Module Professionnel et Robuste ✨
```

---

## 🪝 Hooks System

### Concept

Les hooks permettent d'**exécuter du code** à des moments précis sans modifier le code source.

### Types de Hooks

#### 1. Trigger (Action Hooks)
Exécute tous les callbacks enregistrés.

```lua
-- Enregistrer un hook
vCore.Hooks.Register('vCore:playerLoaded', function(playerId, playerData)
    print('Joueur chargé:', playerId)
    -- Votre code ici
end)

-- Déclencher le hook
vCore.Hooks.Trigger('vCore:playerLoaded', source, player)
```

#### 2. Filter Hooks
Modifie une valeur en passant par tous les hooks.

```lua
-- Enregistrer un filter
vCore.Hooks.Register('vCore:beforeMoneyAdd', function(amount, source)
    -- Ajouter un bonus de 10%
    return amount * 1.1
end)

-- Appliquer les filters
local finalAmount = vCore.Hooks.Filter('vCore:beforeMoneyAdd', 1000, source)
-- finalAmount = 1100
```

#### 3. Stoppable Hooks
Un hook peut arrêter la chaîne d'exécution.

```lua
-- Hook qui peut bloquer une action
vCore.Hooks.Register('vCore:beforeCommand', function(source, command, args)
    if BannedCommands[command] then
        return true  -- Stoppe l'exécution
    end
end)

-- Vérifier si stoppé
local stopped = vCore.Hooks.TriggerStoppable('vCore:beforeCommand', source, 'ban', args)
if stopped then
    print('Commande bloquée par un hook')
    return
end
```

### Hooks Prédéfinis

```lua
-- Player
vCore.Hooks.PLAYER_CONNECTING
vCore.Hooks.PLAYER_LOADED
vCore.Hooks.PLAYER_DISCONNECTED

-- Money
vCore.Hooks.BEFORE_MONEY_ADD
vCore.Hooks.AFTER_MONEY_ADD
vCore.Hooks.BEFORE_MONEY_REMOVE

-- Jobs
vCore.Hooks.BEFORE_JOB_CHANGE
vCore.Hooks.AFTER_JOB_CHANGE

-- Items
vCore.Hooks.BEFORE_ITEM_ADD
vCore.Hooks.ITEM_USED

-- Vehicles
vCore.Hooks.VEHICLE_SPAWNED
vCore.Hooks.VEHICLE_STORED

-- System
vCore.Hooks.SERVER_READY
vCore.Hooks.MODULE_LOADED
```

### Priorités

```lua
-- Plus petit = exécuté en premier
vCore.Hooks.Register('myHook', callback1, 1)   -- Exécuté en 1er
vCore.Hooks.Register('myHook', callback2, 5)   -- Exécuté en 2e
vCore.Hooks.Register('myHook', callback3, 10)  -- Exécuté en 3e (défaut)
```

### Exemple Complet : Système de Bonus

```lua
-- Module: vAvA_bonus
local Module = vCore.CreateModule('bonus', {
    weekendBonus = 1.5,
    vipBonus = 1.2
})

-- Hook sur l'ajout d'argent
vCore.Hooks.Register(vCore.Hooks.BEFORE_MONEY_ADD, function(amount, source, account)
    local player = vCore.GetPlayer(source)
    if not player then return amount end
    
    local bonus = amount
    
    -- Bonus weekend
    if os.date('%w') == '0' or os.date('%w') == '6' then
        bonus = bonus * Module:GetConfig('weekendBonus')
    end
    
    -- Bonus VIP
    if player.group == 'vip' then
        bonus = bonus * Module:GetConfig('vipBonus')
    end
    
    return math.floor(bonus)
end, 5)  -- Priorité 5

-- Maintenant TOUS les ajouts d'argent dans le serveur ont les bonus !
```

---

## 🎨 Decorators

### Concept

Les décorateurs **enveloppent une fonction** pour lui ajouter des comportements sans modifier son code.

### Décorateurs Disponibles

#### 1. Retry - Réessayer en cas d'échec

```lua
local robustQuery = vCore.Decorators.Retry(function()
    return MySQL.Sync.fetchAll('SELECT * FROM users')
end, 3, 1000)  -- 3 tentatives, 1000ms entre chaque

local users = robustQuery()  -- Réessaie automatiquement si échec
```

#### 2. Cache - Mettre en cache les résultats

```lua
local cachedQuery = vCore.Decorators.Cache(function(identifier)
    return MySQL.Sync.fetchAll('SELECT * FROM users WHERE identifier = ?', {identifier})
end, 60)  -- Cache pendant 60 secondes

local user = cachedQuery('license:123')  -- 1ère fois: requête DB
local user2 = cachedQuery('license:123') -- 2e fois: depuis cache
```

#### 3. Memoize - Cache permanent

```lua
local expensiveCalc = vCore.Decorators.Memoize(function(n)
    -- Calcul très long
    return n * n * n
end)

local result = expensiveCalc(100)  -- Calcule
local result2 = expensiveCalc(100) -- Retourne cache instantanément
```

#### 4. Throttle - Limiter la fréquence

```lua
local throttledSave = vCore.Decorators.Throttle(function()
    MySQL.Async.execute('UPDATE users SET ...')
end, 5000)  -- Maximum 1 fois toutes les 5 secondes

-- Appelé 10 fois rapidement, mais n'exécute que toutes les 5 secondes
for i = 1, 10 do
    throttledSave()
end
```

#### 5. Debounce - Attendre la fin des appels

```lua
local debouncedSearch = vCore.Decorators.Debounce(function(query)
    -- Recherche dans la DB
    print('Searching:', query)
end, 500)

-- L'utilisateur tape "hello"
debouncedSearch('h')     -- Annulé
debouncedSearch('he')    -- Annulé
debouncedSearch('hel')   -- Annulé
debouncedSearch('hell')  -- Annulé
debouncedSearch('hello') -- Exécuté après 500ms d'inactivité
```

#### 6. Validate - Valider les arguments

```lua
local validatedTransfer = vCore.Decorators.Validate(function(source, amount, target)
    -- Code du transfert
end, {
    function(source) return vCore.Validation.IsNumber(source, 1, 1024) end,
    function(amount) return vCore.Validation.IsNumber(amount, 1, 999999) end,
    function(target) return vCore.Validation.IsNumber(target, 1, 1024) end
})

validatedTransfer(1, 5000, 2)     -- OK
validatedTransfer(1, -100, 2)     -- Erreur: amount invalide
validatedTransfer('abc', 100, 2)  -- Erreur: source invalide
```

#### 7. RequirePermission - Vérifier permissions (serveur)

```lua
local adminFunction = vCore.Decorators.RequirePermission(function(source)
    -- Code admin
    print('Admin action:', source)
end, vCore.PermissionLevel.ADMIN)

adminFunction(1)  -- OK si admin, sinon erreur
```

#### 8. Time - Mesurer performance

```lua
local timedFunction = vCore.Decorators.Time(function()
    -- Code à mesurer
    Citizen.Wait(1000)
end, 'MyFunction')

timedFunction()  -- Affiche: "MyFunction executed in 1001 ms"
```

#### 9. Safe - Exécution sécurisée

```lua
local safeFunction = vCore.Decorators.Safe(function()
    error('Oops!')
end, function(err)
    print('Erreur attrapée:', err)
    return 'default value'
end)

local result = safeFunction()  -- Ne crash pas, retourne 'default value'
```

#### 10. Once - Exécuter une seule fois

```lua
local initFunction = vCore.Decorators.Once(function()
    print('Initialisation...')
    return 'initialized'
end)

initFunction()  -- Affiche "Initialisation..."
initFunction()  -- Ne fait rien
initFunction()  -- Ne fait rien
```

### Chaîner Plusieurs Décorateurs

```lua
local complexFunction = vCore.Decorators.Chain(function(source, data)
    -- Code métier
    return processData(data)
end, {
    function(f) return vCore.Decorators.RequirePermission(f, vCore.PermissionLevel.ADMIN) end,
    function(f) return vCore.Decorators.Retry(f, 3, 1000) end,
    function(f) return vCore.Decorators.Cache(f, 60) end,
    function(f) return vCore.Decorators.Time(f, 'ComplexFunction') end,
    function(f) return vCore.Decorators.Safe(f) end
})

-- Cette fonction est maintenant:
-- - Sécurisée (Safe)
-- - Mesurée (Time)
-- - Cachée (Cache)
-- - Retry automatique (Retry)
-- - Protégée par permissions (RequirePermission)
```

---

## 🔄 Middleware

### Concept

Les middlewares créent un **pipeline de traitement** pour les requêtes/commandes.

### Structure

```lua
function(context, next)
    -- Code avant
    local result = next()  -- Appelle le middleware suivant
    -- Code après
    return result
end
```

### Middlewares Prédéfinis

#### 1. Logger

```lua
vCore.Middleware.Register('logger', vCore.Middleware.Logger, 1)
-- Logs automatiques de toutes les actions
```

#### 2. ValidateSource

```lua
vCore.Middleware.Register('validateSource', vCore.Middleware.ValidateSource, 5)
-- Vérifie que source est valide
```

#### 3. RequirePermission

```lua
vCore.Middleware.Register('adminOnly', vCore.Middleware.RequirePermission(vCore.PermissionLevel.ADMIN), 10)
-- Bloque si pas admin
```

#### 4. RequireJob

```lua
vCore.Middleware.Register('policeOnly', vCore.Middleware.RequireJob('police', 2), 10)
-- Bloque si pas police grade 2+
```

#### 5. RateLimit

```lua
vCore.Middleware.Register('rateLimit', vCore.Middleware.RateLimit(5, 60), 15)
-- Maximum 5 appels par minute
```

#### 6. ValidateData

```lua
vCore.Middleware.Register('validateTransfer', vCore.Middleware.ValidateData({
    amount = {
        required = true,
        validate = function(v) return vCore.Validation.IsNumber(v, 1, 999999) end
    },
    target = {
        required = true,
        validate = function(v) return vCore.Validation.IsNumber(v, 1, 1024) end
    }
}), 20)
```

#### 7. Sanitize

```lua
vCore.Middleware.Register('sanitize', vCore.Middleware.Sanitize, 25)
-- Nettoie les caractères dangereux
```

#### 8. Cache

```lua
vCore.Middleware.Register('cache', vCore.Middleware.Cache(60), 30)
-- Cache les résultats pendant 60 secondes
```

### Utilisation

#### Middleware Global

```lua
-- S'applique à TOUTES les actions
vCore.Middleware.Register('logger', vCore.Middleware.Logger, 1)
vCore.Middleware.Register('sanitize', vCore.Middleware.Sanitize, 10)

vCore.Middleware.Execute({
    source = source,
    action = 'transfer',
    data = transferData
}, function(context)
    -- Handler final
    executeTransfer(context.data)
    return true
end)
```

#### Middleware Spécifique (Group)

```lua
-- Groupe de middlewares pour une action spécifique
local transferMiddleware = vCore.Middleware.Group({
    vCore.Middleware.ValidateSource,
    vCore.Middleware.RequirePermission(vCore.PermissionLevel.USER),
    vCore.Middleware.RateLimit(5, 60),
    vCore.Middleware.ValidateData({
        amount = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 999999) end
        },
        target = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 1024) end
        }
    }),
    vCore.Middleware.Sanitize
})

-- Utiliser le groupe
RegisterNetEvent('vCore:transferMoney', function(data)
    transferMiddleware({
        source = source,
        action = 'transfer',
        data = data
    }, function(ctx)
        -- Tous les middlewares sont passés ✅
        local success = TransferMoney(ctx.source, ctx.data.amount, ctx.data.target)
        return success
    end)
end)
```

### Middleware Personnalisé

```lua
local myCustomMiddleware = function(context, next)
    print('Avant:', context.action)
    
    -- Modifier le context
    context.startTime = GetGameTimer()
    
    -- Appeler le suivant
    local result = next()
    
    -- Code après
    local duration = GetGameTimer() - context.startTime
    print('Après:', context.action, 'en', duration, 'ms')
    
    return result
end

vCore.Middleware.Register('custom', myCustomMiddleware, 15)
```

---

## 💾 State Manager

### Concept

Un gestionnaire d'**état global réactif** avec observers.

### Utilisation Basique

```lua
-- Définir une valeur
vCore.State.Set('playerMoney', 5000)

-- Obtenir une valeur
local money = vCore.State.Get('playerMoney', 0)

-- Valeurs imbriquées
vCore.State.SetNested('player.inventory.water', 5)
local water = vCore.State.GetNested('player.inventory.water', 0)
```

### Observers (Watch)

```lua
-- Observer les changements
vCore.State.Watch('playerMoney', function(newMoney, oldMoney)
    print('Money changed:', oldMoney, '->', newMoney)
    
    -- Mettre à jour l'UI
    SendNUIMessage({
        action = 'updateMoney',
        money = newMoney
    })
end)
```

### Valeurs Computed

```lua
-- Définir des valeurs qui se recalculent automatiquement
vCore.State.Set('price', 100)
vCore.State.Set('quantity', 5)

vCore.State.Computed('total', {'price', 'quantity'}, function()
    local price = vCore.State.Get('price', 0)
    local quantity = vCore.State.Get('quantity', 0)
    return price * quantity
end)

print(vCore.State.Get('total'))  -- 500

-- Changer price ou quantity recalcule automatiquement total
vCore.State.Set('price', 200)
print(vCore.State.Get('total'))  -- 1000 (automatiquement recalculé!)
```

### Batch Updates

```lua
-- Grouper les mises à jour (1 seule notification)
vCore.State.Update({
    playerMoney = 10000,
    playerJob = 'police',
    playerGrade = 3,
    playerName = 'John'
})
```

### Historique et Undo

```lua
vCore.State.Set('test', 1)
vCore.State.Set('test', 2)
vCore.State.Set('test', 3)

-- Voir l'historique
local history = vCore.State.GetHistory('test')
-- [{key: 'test', oldValue: nil, newValue: 1, timestamp: ...}, ...]

-- Annuler le dernier changement
vCore.State.Undo()  -- Retour à test = 2
```

### Persistence (Serveur)

```lua
-- Sauvegarder le state
vCore.State.Save('player:' .. identifier)

-- Charger le state
vCore.State.Load('player:' .. identifier, function(loadedState)
    print('State chargé:', json.encode(loadedState))
end)
```

---

## 🎯 Exemples Complets

### Exemple 1 : Module Bank avec Tous les Systèmes

```lua
-- modules/bank/shared.lua
local Module = vCore.CreateModule('bank', {
    transferFee = 0.02,  -- 2% de frais
    maxTransfer = 50000,
    minTransfer = 1
})

-- ════════════════════════════════════════════════════════════════════════════
-- HOOKS - Système de bonus sur les transferts
-- ════════════════════════════════════════════════════════════════════════════

vCore.Hooks.Register('bank:beforeTransfer', function(amount, source, target)
    -- Bonus si transfert > 10000
    if amount >= 10000 then
        return amount * 1.05  -- +5% bonus
    end
    return amount
end)

-- ════════════════════════════════════════════════════════════════════════════
-- DECORATORS - Fonctions robustes
-- ════════════════════════════════════════════════════════════════════════════

-- Fonction de transfert avec retry et cache
local ExecuteTransfer = vCore.Decorators.Chain(function(source, amount, target)
    -- Code métier
    local sourcePlayer = vCore.GetPlayer(source)
    local targetPlayer = vCore.GetPlayer(target)
    
    if not sourcePlayer or not targetPlayer then
        return false, 'Joueur introuvable'
    end
    
    if not vCore.RemoveMoney(source, amount, 'bank') then
        return false, 'Fonds insuffisants'
    end
    
    vCore.AddMoney(target, amount, 'bank')
    
    return true, 'Transfert réussi'
end, {
    function(f) return vCore.Decorators.Retry(f, 3, 1000) end,
    function(f) return vCore.Decorators.Time(f, 'BankTransfer') end,
    function(f) return vCore.Decorators.Safe(f) end
})

-- ════════════════════════════════════════════════════════════════════════════
-- MIDDLEWARE - Pipeline de validation
-- ════════════════════════════════════════════════════════════════════════════

local transferMiddleware = vCore.Middleware.Group({
    vCore.Middleware.ValidateSource,
    vCore.Middleware.RequirePermission(vCore.PermissionLevel.USER),
    vCore.Middleware.RateLimit(10, 60),  -- 10 transferts/minute max
    vCore.Middleware.ValidateData({
        amount = {
            required = true,
            validate = function(v)
                return vCore.Validation.IsNumber(v,
                    Module:GetConfig('minTransfer'),
                    Module:GetConfig('maxTransfer')
                )
            end
        },
        target = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 1024) end
        }
    }),
    vCore.Middleware.Sanitize
})

-- ════════════════════════════════════════════════════════════════════════════
-- STATE - État réactif du compte
-- ════════════════════════════════════════════════════════════════════════════

-- Observer le solde pour logs automatiques
vCore.State.Watch('bank:balance', function(newBalance, oldBalance)
    local diff = newBalance - oldBalance
    if diff > 0 then
        Module:Log('info', 'Dépôt de', diff)
    else
        Module:Log('info', 'Retrait de', math.abs(diff))
    end
end)

-- Computed: Total avec intérêts
vCore.State.Computed('bank:totalWithInterest', {'bank:balance'}, function()
    local balance = vCore.State.Get('bank:balance', 0)
    return balance * 1.02  -- +2% intérêts
end)

-- ════════════════════════════════════════════════════════════════════════════
-- EVENT - Transfert d'argent
-- ════════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:bank:transfer', function(data)
    transferMiddleware({
        source = source,
        action = 'bank:transfer',
        data = data
    }, function(ctx)
        local amount = ctx.data.amount
        local target = ctx.data.target
        
        -- Appliquer les hooks (bonus)
        local finalAmount = vCore.Hooks.Filter('bank:beforeTransfer', amount, source, target)
        
        -- Appliquer les frais
        local fee = finalAmount * Module:GetConfig('transferFee')
        local totalCost = finalAmount + fee
        
        -- Exécuter (avec decorators: retry, time, safe)
        local success, message = ExecuteTransfer(source, totalCost, target)
        
        if success then
            -- Mettre à jour state
            vCore.State.Set('bank:lastTransfer', {
                from = source,
                to = target,
                amount = finalAmount,
                fee = fee,
                timestamp = os.time()
            })
            
            -- Notifier
            Module:Notify(source, 'Transfert de ' .. finalAmount .. '$ (frais: ' .. fee .. '$)', 'success')
            Module:Notify(target, 'Vous avez reçu ' .. finalAmount .. '$', 'success')
            
            -- Trigger hook after
            vCore.Hooks.Trigger('bank:afterTransfer', source, target, finalAmount)
        else
            Module:Notify(source, message, 'error')
        end
        
        return success
    end)
end)
```

### Exemple 2 : Module Shop avec Cache et Rate Limit

```lua
-- modules/shop/server.lua
local Module = vCore.CreateModule('shop', {
    items = {
        water = { price = 5, label = 'Eau' },
        bread = { price = 3, label = 'Pain' }
    }
})

-- Fonction pour obtenir les items avec cache
local GetShopItems = vCore.Decorators.Cache(function()
    return Module:GetConfig('items')
end, 300)  -- Cache 5 minutes

-- Middleware pour les achats
local purchaseMiddleware = vCore.Middleware.Group({
    vCore.Middleware.ValidateSource,
    vCore.Middleware.RateLimit(20, 60),  -- 20 achats/minute max
    vCore.Middleware.ValidateData({
        item = {
            required = true,
            validate = function(v) return vCore.Validation.IsString(v, 1, 50) end
        },
        quantity = {
            required = true,
            validate = function(v) return vCore.Validation.IsNumber(v, 1, 100) end
        }
    })
})

RegisterNetEvent('vCore:shop:buy', function(data)
    purchaseMiddleware({
        source = source,
        action = 'shop:buy',
        data = data
    }, function(ctx)
        local items = GetShopItems()  -- Depuis cache
        local item = items[ctx.data.item]
        
        if not item then
            Module:Notify(source, 'Article introuvable', 'error')
            return false
        end
        
        local totalPrice = item.price * ctx.data.quantity
        
        if not vCore.RemoveMoney(source, totalPrice, 'money') then
            Module:Notify(source, 'Argent insuffisant', 'error')
            return false
        end
        
        vCore.AddItem(source, ctx.data.item, ctx.data.quantity)
        Module:Notify(source, 'Achat de ' .. ctx.data.quantity .. 'x ' .. item.label, 'success')
        
        return true
    end)
end)
```

---

## 🎓 Résumé : Pourquoi C'est Puissant

### Avant

```lua
-- Code spaghetti, répété partout
RegisterNetEvent('myEvent', function(data)
    -- Validation manuelle
    if not data or not data.amount then return end
    if type(data.amount) ~= 'number' then return end
    if data.amount < 1 or data.amount > 999999 then return end
    
    -- Vérification permission manuelle
    if not IsPlayerAceAllowed(source, 'user') then return end
    
    -- Rate limiting manuel
    if lastCall[source] and GetGameTimer() - lastCall[source] < 5000 then return end
    lastCall[source] = GetGameTimer()
    
    -- Sanitization manuelle
    data.reason = data.reason:gsub('[<>\'"]', '')
    
    -- Retry manuel
    local success = false
    local attempts = 0
    while not success and attempts < 3 do
        success = DoSomething(data)
        attempts = attempts + 1
        if not success then Citizen.Wait(1000) end
    end
    
    -- 50+ lignes de boilerplate... 😫
end)
```

### Après (avec vAvA_core)

```lua
-- Code propre et lisible ✨
local middleware = vCore.Middleware.Group({
    vCore.Middleware.ValidateSource,
    vCore.Middleware.RequirePermission(vCore.PermissionLevel.USER),
    vCore.Middleware.RateLimit(1, 5000),
    vCore.Middleware.ValidateData({
        amount = { required = true, validate = function(v) return vCore.Validation.IsNumber(v, 1, 999999) end }
    }),
    vCore.Middleware.Sanitize
})

local DoSomethingRobust = vCore.Decorators.Retry(DoSomething, 3, 1000)

RegisterNetEvent('myEvent', function(data)
    middleware({ source = source, data = data }, function(ctx)
        return DoSomethingRobust(ctx.data)
    end)
end)
```

### Bénéfices

- ✅ **90% moins de code**
- ✅ **Lisible et maintenable**
- ✅ **Réutilisable** partout
- ✅ **Testable** facilement
- ✅ **Sécurisé** par défaut
- ✅ **Performant** (cache, throttle)
- ✅ **Extensible** (hooks)

---

## 📚 Ressources

- [MODULE_CREATION_GUIDE.md](MODULE_CREATION_GUIDE.md) - Guide de création de modules
- [BUILDER_EXAMPLES.md](BUILDER_EXAMPLES.md) - Exemples de builders
- [templates/module_template.lua](../templates/module_template.lua) - Template de module

---

**Avec ces systèmes, créer un module complet, robuste et professionnel prend 15 minutes au lieu de 2 jours.** 🚀
