# 🎯 Guide Création Module - vAvA_core

## 🚀 Démarrage Rapide (5 minutes)

### Étape 1: Copier le template

```bash
cp templates/module_template.lua modules/my_module/my_module.lua
```

### Étape 2: Configuration de base

```lua
local MODULE_NAME = 'my_module'  -- Nom unique

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'Votre Nom',
    description = 'Description du module',
    dependencies = {},  -- Dépendances optionnelles
    config = {
        debug = true,
        enabled = true
        -- Vos paramètres
    }
}
```

### Étape 3: Implémenter les fonctions

```lua
function Module.onLoad(self)
    -- Initialisation
end

function Module.onStart(self)
    -- Enregistrer events/commandes
    self:RegisterEvents()
end
```

### Étape 4: Ajouter au fxmanifest

```lua
-- Dans fxmanifest.lua
server_scripts {
    -- ...
    'modules/my_module/my_module.lua'
}
```

---

## 📚 API Module Base

### Lifecycle

```lua
-- Hooks disponibles
function Module.onLoad(self)
    -- Appelé au chargement
end

function Module.onStart(self)
    -- Appelé au démarrage
end

function Module.onStop(self)
    -- Appelé à l'arrêt
end

-- Serveur uniquement
function Module.onPlayerLoaded(self, player)
    -- Joueur connecté
end

function Module.onPlayerUnloaded(self, player)
    -- Joueur déconnecté
end
```

### Événements

```lua
-- Enregistrer un événement
self:RegisterEvent('eventName', function(source, data)
    -- Traitement
end)

-- Déclencher événement
self:TriggerEvent('eventName', data)
self:TriggerClientEvent(source, 'eventName', data)
self:TriggerServerEvent('eventName', data)
```

### Callbacks

```lua
-- Enregistrer callback (serveur)
self:RegisterCallback('callbackName', function(source, cb, param)
    -- Traitement
    cb(result)
end)

-- Appeler callback (client)
self:TriggerCallback('callbackName', function(result)
    print(result)
end, param)
```

### Commandes

```lua
self:RegisterCommand('commandname', {
    help = 'Description',
    params = {
        {name = 'param', help = 'Aide', required = true}
    },
    minLevel = vCore.PermissionLevel.ADMIN,
    restricted = true
}, function(source, args)
    -- Traitement
end)
```

### Exports

```lua
-- Créer export
function Module:MyExport(param)
    return result
end

self:RegisterExport('MyExport', function(param)
    return Module:MyExport(param)
end)

-- Utiliser depuis autre ressource
local result = exports.resource_name:MyExport(param)
```

### Base de données

```lua
-- Query multiple
local results = self:Query('SELECT * FROM table WHERE id = ?', {id})

-- Query single
local row = self:QuerySingle('SELECT * FROM table WHERE id = ?', {id})

-- Insert
local insertId = self:Insert('INSERT INTO table (col) VALUES (?)', {value})

-- Update/Delete
local affected = self:Execute('UPDATE table SET col = ? WHERE id = ?', {value, id})
```

### Configuration

```lua
-- Lire config
local value = self:GetConfig('key.nested', defaultValue)

-- Modifier config
self:SetConfig('key.nested', newValue)
```

### Notifications

```lua
-- Types: success, error, warning, info
self:Notify(source, 'Message', 'success', 5000)

-- Menu
self:ShowMenu(source, {
    title = 'Titre',
    elements = {
        {label = 'Option 1', value = 'opt1'}
    }
})

-- Progress bar
self:ShowProgressBar(source, 'Action...', 5000, {
    canCancel = true,
    animation = {dict = 'dict', name = 'anim'}
})
```

### Logs

```lua
-- Console
self:Log('Message')
self:Debug('Debug message')  -- Si config.debug = true
self:Error('Erreur!')

-- Base de données
self:LogDB('type', source, 'Message', {data})
```

### Players (Serveur)

```lua
-- Obtenir joueur
local player = self:GetPlayer(source)

-- Tous les joueurs
local players = self:GetPlayers()

-- Permissions
if self:HasPermission(source, vCore.PermissionLevel.ADMIN) then
    -- Admin seulement
end
```

---

## 🎨 Exemples Pratiques

### Module Simple (Téléportation)

```lua
local MODULE_NAME = 'teleport'

local Module = vCore.CreateModule(MODULE_NAME, {
    version = '1.0.0',
    config = {
        locations = {
            spawn = {x = 195.0, y = -933.0, z = 30.0},
            garage = {x = 215.0, y = -810.0, z = 30.0}
        }
    }
})

function Module.onStart(self)
    if not IsDuplicityVersion() then return end
    
    self:RegisterCommand('tp', {
        help = 'Téléporter à un lieu',
        params = {{name = 'lieu', help = 'spawn/garage', required = true}},
        minLevel = vCore.PermissionLevel.ADMIN,
        restricted = true
    }, function(source, args)
        local location = self:GetConfig('locations.' .. args[1])
        
        if not location then
            self:NotifyError(source, 'Lieu invalide!')
            return
        end
        
        TriggerClientEvent('vCore:teleport', source, location)
        self:NotifySuccess(source, 'Téléporté à ' .. args[1])
    end)
end

Module:Load()
Module:Start()
```

### Module Économie (Banque)

```lua
local MODULE_NAME = 'bank'

local Module = vCore.CreateModule(MODULE_NAME, {
    version = '1.0.0',
    config = {
        transferFee = 5,  -- 5% de frais
        maxTransfer = 100000
    }
})

function Module.onStart(self)
    if not IsDuplicityVersion() then return end
    
    -- Callback: Transférer argent
    self:RegisterCallback('transfer', function(source, cb, targetId, amount)
        local player = self:GetPlayer(source)
        local target = self:GetPlayer(targetId)
        
        if not player or not target then
            cb({success = false, message = 'Joueur invalide'})
            return
        end
        
        -- Validation
        local valid, err = vCore.Validation.IsAmount(amount)
        if not valid then
            cb({success = false, message = err})
            return
        end
        
        if amount > self:GetConfig('maxTransfer') then
            cb({success = false, message = 'Montant trop élevé'})
            return
        end
        
        -- Vérifier fonds
        if not player:HasMoney('bank', amount) then
            cb({success = false, message = 'Fonds insuffisants'})
            return
        end
        
        -- Calculer frais
        local fee = vCore.Helpers.ApplyPercentage(amount, self:GetConfig('transferFee'))
        local total = amount + fee
        
        -- Transaction
        player:RemoveMoney('bank', total, 'Transfer + frais')
        target:AddMoney('bank', amount, 'Transfer reçu')
        
        -- Notifications
        self:NotifySuccess(source, 'Transfert réussi: ' .. vCore.Utils.FormatMoney(amount))
        self:NotifyInfo(targetId, 'Vous avez reçu ' .. vCore.Utils.FormatMoney(amount))
        
        -- Log
        self:LogDB('transfer', source, 'Transfer to ' .. targetId, {
            amount = amount,
            fee = fee,
            target = targetId
        })
        
        cb({success = true, fee = fee})
    end)
end

Module:Load()
Module:Start()
```

### Module Client (Markers)

```lua
local MODULE_NAME = 'markers'

local Module = vCore.CreateModule(MODULE_NAME, {
    version = '1.0.0',
    config = {
        markers = {
            {
                coords = vector3(195.0, -933.0, 30.0),
                type = 1,
                color = {r = 255, g = 0, b = 0},
                action = 'test'
            }
        }
    }
})

function Module.onStart(self)
    if IsDuplicityVersion() then return end
    
    Citizen.CreateThread(function()
        while self.enabled do
            local playerCoords = vCore.Helpers.GetPlayerCoords()
            
            for _, marker in ipairs(self:GetConfig('markers', {})) do
                local distance = #(playerCoords - marker.coords)
                
                if distance < 50.0 then
                    local color = marker.color
                    DrawMarker(marker.type, marker.coords.x, marker.coords.y, marker.coords.z - 1.0,
                        0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0,
                        color.r, color.g, color.b, 200,
                        false, true, 2, false, nil, nil, false)
                    
                    if distance < 2.0 then
                        vCore.UI.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~')
                        
                        if IsControlJustPressed(0, 38) then
                            self:TriggerServerEvent(MODULE_NAME .. ':interact', marker.action)
                        end
                    end
                end
            end
            
            Citizen.Wait(0)
        end
    end)
end

Module:Load()
Module:Start()
```

---

## 🛠️ Helpers Disponibles

### Player Helpers

```lua
-- Obtenir identifier
local identifier = vCore.Helpers.GetIdentifier(source)

-- Obtenir nom
local name = vCore.Helpers.GetPlayerName(source)

-- Argent
local cash = vCore.Helpers.GetMoney(source, 'cash')
local hasMoney = vCore.Helpers.HasMoney(source, 'cash', 1000)

-- Job
local job = vCore.Helpers.GetJob(source)
local isPolice = vCore.Helpers.HasJob(source, 'police', 2)  -- Grade min 2
local onDuty = vCore.Helpers.IsOnDuty(source)

-- Joueurs avec job
local cops = vCore.Helpers.GetJobPlayers('police')
local onDutyCops = vCore.Helpers.GetOnDutyJobPlayers('police')

-- Items
local hasItem = vCore.Helpers.HasItem(source, 'bread', 1)
local count = vCore.Helpers.GetItemCount(source, 'bread')
local canCarry = vCore.Helpers.CanCarry(source, 500)  -- 500g
```

### Notification Helpers

```lua
vCore.Helpers.NotifySuccess(source, 'Message')
vCore.Helpers.NotifyError(source, 'Erreur')
vCore.Helpers.NotifyWarning(source, 'Attention')
vCore.Helpers.NotifyInfo(source, 'Info')

-- À tous
vCore.Helpers.NotifyAll('Message serveur', 'info')

-- À un job
vCore.Helpers.NotifyJob('police', 'Appel reçu', 'warning')
```

### Distance Helpers

```lua
-- Client uniquement
local coords = vCore.Helpers.GetPlayerCoords()
local isNear = vCore.Helpers.IsPlayerNearby(targetCoords, 10.0)

-- Véhicule
local vehicle = vCore.Helpers.GetPlayerVehicle()
local inVeh = vCore.Helpers.IsInVehicle()
local isDriver = vCore.Helpers.IsDriver()
```

### Math Helpers

```lua
local percent = vCore.Helpers.Percentage(50, 100)  -- 50%
local result = vCore.Helpers.ApplyPercentage(1000, 10)  -- 100
local lerp = vCore.Helpers.Lerp(0, 100, 0.5)  -- 50
local rand = vCore.Helpers.RandomFloat(1.0, 10.0)
```

### String Helpers

```lua
local cap = vCore.Helpers.Capitalize('hello')  -- Hello
local title = vCore.Helpers.TitleCase('hello world')  -- Hello World
local starts = vCore.Helpers.StartsWith('hello', 'he')  -- true
local ends = vCore.Helpers.EndsWith('hello', 'lo')  -- true
```

### Table Helpers

```lua
local filtered = vCore.Helpers.Filter({1,2,3,4}, function(v) return v > 2 end)  -- {3,4}
local mapped = vCore.Helpers.Map({1,2,3}, function(v) return v * 2 end)  -- {2,4,6}
local sum = vCore.Helpers.Reduce({1,2,3}, function(acc, v) return acc + v end, 0)  -- 6
local found = vCore.Helpers.Find({1,2,3}, function(v) return v == 2 end)  -- 2
local shuffled = vCore.Helpers.Shuffle({1,2,3,4,5})
```

---

## ✅ Checklist Module Complet

- [ ] Configuration dans MODULE_CONFIG
- [ ] onLoad() implémenté
- [ ] onStart() implémenté
- [ ] Événements enregistrés
- [ ] Commandes enregistrées (si nécessaire)
- [ ] Callbacks enregistrés (si nécessaire)
- [ ] Exports créés (si nécessaire)
- [ ] Validation des données
- [ ] Gestion erreurs
- [ ] Logs appropriés
- [ ] Permissions vérifiées
- [ ] Tests effectués
- [ ] Documentation ajoutée
- [ ] Ajouté au fxmanifest.lua

---

## 🎓 Bonnes Pratiques

### 1. Validation des entrées

```lua
-- Toujours valider
local valid, err = vCore.Validation.IsString(input, 1, 50)
if not valid then
    self:NotifyError(source, err)
    return
end
```

### 2. Gestion erreurs

```lua
local success, err = pcall(function()
    -- Code risqué
end)

if not success then
    self:Error('Erreur:', err)
end
```

### 3. Permissions

```lua
-- Vérifier avant toute action sensible
if not self:HasPermission(source, vCore.PermissionLevel.ADMIN) then
    self:NotifyError(source, Lang('no_permission'))
    return
end
```

### 4. Logs

```lua
-- Logger actions importantes
self:LogDB('action', source, 'Action effectuée', {data})
```

### 5. Configuration

```lua
-- Utiliser GetConfig avec valeurs par défaut
local value = self:GetConfig('settings.value', 100)
```

---

## 🚀 Publication Module

### Structure dossier

```
modules/my_module/
├── my_module.lua          # Code principal
├── config.lua             # Config (optionnel)
├── README.md              # Documentation
├── sql/
│   └── install.sql        # Tables SQL
└── locales/
    ├── en.lua
    └── fr.lua
```

### README.md module

```markdown
# Module Name

Description courte

## Installation

1. Copier dossier dans resources/
2. Importer SQL: `sql/install.sql`
3. Ajouter au server.cfg: `ensure my_module`

## Configuration

Config dans config.lua

## Commandes

- `/command` - Description

## Exports

- `ExportName(param)` - Description
```

---

*Guide complet v1.0.0 - Créez des modules professionnels facilement!*
