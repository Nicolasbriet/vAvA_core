# 📚 Guide Complet - Création de Modules vAvA_core

> **Version:** 1.0.0  
> **Date:** Janvier 2026  
> **Auteur:** vAvA Team

---

## 📑 Table des Matières

1. [Introduction](#introduction)
2. [Prérequis](#prérequis)
3. [Architecture d'un Module](#architecture-dun-module)
4. [Création Pas-à-Pas](#création-pas-à-pas)
5. [API du ModuleBase](#api-du-modulebase)
6. [Systèmes Avancés](#systèmes-avancés)
7. [Bonnes Pratiques](#bonnes-pratiques)
8. [Exemples Complets](#exemples-complets)
9. [Débogage et Tests](#débogage-et-tests)
10. [FAQ](#faq)

---

## 🎯 Introduction

### Qu'est-ce qu'un module vAvA_core ?

Un module vAvA_core est une extension autonome qui s'intègre au framework. Chaque module hérite de la classe `ModuleBase` et bénéficie automatiquement de :

✅ **Lifecycle complet** (onLoad, onStart, onStop)  
✅ **Gestion événements** centralisée  
✅ **Système de callbacks** intégré  
✅ **Commandes admin** avec permissions  
✅ **Validation de données** automatique  
✅ **Logging et debug** standardisé  
✅ **Exports** vers autres ressources  
✅ **Gestion joueurs** avec hooks  

### Pourquoi créer un module ?

- 🔌 **Modularité** : Ajoutez des fonctionnalités sans modifier le core
- 🔒 **Isolation** : Chaque module fonctionne indépendamment
- ♻️ **Réutilisabilité** : Partagez vos modules entre serveurs
- 🛡️ **Sécurité** : Validation et permissions intégrées
- 📦 **Maintenance** : Mises à jour simplifiées

---

## 🔧 Prérequis

### Connaissances requises

- ✅ Lua 5.4 (bases et POO)
- ✅ FiveM/CitizenFX (événements, natives)
- ✅ SQL/MySQL (requêtes de base)
- ✅ Structure vAvA_core

### Outils nécessaires

- Visual Studio Code (recommandé)
- Extension Lua Language Server
- MySQL Workbench (pour la BDD)
- Git (versioning)

### Vérifier l'installation

```lua
-- Testez dans F8 (serveur)
print(vCore and "vCore OK" or "vCore manquant")
print(vCore.CreateModule and "ModuleBase OK" or "ModuleBase manquant")
```

---

## 🏗️ Architecture d'un Module

### Structure de fichiers

```
modules/
└── votre_module/
    ├── fxmanifest.lua         # Manifest du module (optionnel si externe)
    ├── config.lua              # Configuration
    ├── README.md               # Documentation
    ├── client/
    │   ├── main.lua           # Logique client
    │   └── ui.lua             # Interface utilisateur
    ├── server/
    │   ├── main.lua           # Logique serveur
    │   └── callbacks.lua      # Callbacks serveur
    ├── shared/
    │   └── config.lua         # Config partagée
    ├── html/                   # UI (NUI)
    │   ├── index.html
    │   ├── style.css
    │   └── script.js
    ├── locales/
    │   ├── fr.lua
    │   └── en.lua
    └── sql/
        └── install.sql         # Tables BDD
```

### Structure d'un fichier module

```lua
--[[
    MODULE: nom_module
    DESCRIPTION: Description du module
    VERSION: 1.0.0
    AUTEUR: Votre Nom
]]

-- ══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ══════════════════════════════════════════════════════════════════════════

local MODULE_NAME = 'nom_module'

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'Votre Nom',
    description = 'Description du module',
    dependencies = {},
    config = {}
}

-- ══════════════════════════════════════════════════════════════════════════
-- CRÉATION MODULE
-- ══════════════════════════════════════════════════════════════════════════

local Module = vCore.CreateModule(MODULE_NAME, MODULE_CONFIG)

-- ══════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ══════════════════════════════════════════════════════════════════════════

function Module.onLoad(self)
    -- Initialisation
end

function Module.onStart(self)
    -- Démarrage
end

-- ══════════════════════════════════════════════════════════════════════════
-- LOGIQUE MÉTIER
-- ══════════════════════════════════════════════════════════════════════════

-- Vos fonctions ici
```

---

## 🚀 Création Pas-à-Pas

### Étape 1 : Copier le Template

```bash
# PowerShell
Copy-Item -Path "templates\module_template.lua" -Destination "modules\mon_module\mon_module.lua"
```

Ou manuellement :
1. Naviguez vers `vAvA_core/templates/`
2. Copiez `module_template.lua`
3. Collez dans `modules/mon_module/`
4. Renommez en `mon_module.lua`

### Étape 2 : Configuration de Base

Ouvrez votre fichier et modifiez :

```lua
-- 🔴 MODIFIER CES VALEURS
local MODULE_NAME = 'mon_module'  -- Nom unique (pas d'espaces)

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'Votre Nom',
    description = 'Mon super module qui fait X',
    
    -- Modules requis (si besoin)
    dependencies = {
        -- 'economy',  -- Exemple : si besoin du module économie
        -- 'inventory'
    },
    
    -- Configuration personnalisée
    config = {
        debug = true,  -- Mode debug (à désactiver en production)
        enabled = true,
        
        -- Vos paramètres
        maxDistance = 5.0,
        cooldown = 60000,  -- 60 secondes
        
        -- Positions
        locations = {
            {x = 100.0, y = 200.0, z = 30.0, label = "Point A"}
        }
    }
}
```

### Étape 3 : Implémenter le Lifecycle

#### onLoad - Initialisation

```lua
function Module.onLoad(self)
    self:Log('Chargement du module...')
    
    -- 1. Vérifier la configuration
    if not self.config.enabled then
        self:Warn('Module désactivé dans la config')
        return false
    end
    
    -- 2. Initialiser variables locales
    self.cache = {}
    self.activeUsers = {}
    
    -- 3. Charger données depuis BDD (serveur uniquement)
    if IsDuplicityVersion() then
        self:LoadDatabase()
    end
    
    -- 4. Charger les locales
    if Locales then
        self.locales = Locales[Config.Locale] or Locales['fr']
    end
    
    self:Log('Module chargé avec succès!')
    return true
end
```

#### onStart - Démarrage

```lua
function Module.onStart(self)
    self:Log('Démarrage du module...')
    
    -- 1. Enregistrer les événements
    self:RegisterEvents()
    
    -- 2. Enregistrer les commandes (serveur)
    if IsDuplicityVersion() then
        self:RegisterCommands()
        self:RegisterCallbacks()
    end
    
    -- 3. Démarrer threads client
    if not IsDuplicityVersion() then
        self:StartClientThreads()
    end
    
    -- 4. Exports publics
    self:RegisterExports()
    
    self:Log('Module démarré!')
    return true
end
```

#### onStop - Arrêt

```lua
function Module.onStop(self)
    self:Log('Arrêt du module...')
    
    -- 1. Sauvegarder données importantes
    if IsDuplicityVersion() then
        self:SaveDatabase()
    end
    
    -- 2. Nettoyer les timers/threads
    self:CleanupThreads()
    
    -- 3. Notifier les joueurs actifs
    for source, _ in pairs(self.activeUsers) do
        self:NotifyInfo(source, 'Module arrêté pour maintenance')
    end
    
    self:Log('Module arrêté')
end
```

### Étape 4 : Enregistrer les Événements

```lua
function Module:RegisterEvents()
    -- Événement personnalisé
    self:RegisterEvent(MODULE_NAME .. ':doAction', function(source, data)
        self:Debug('Event reçu:', json.encode(data))
        
        if IsDuplicityVersion() then
            -- CÔTÉ SERVEUR
            local player = self:GetPlayer(source)
            if not player then return end
            
            -- Validation
            local valid, err = vCore.Validation.IsString(data.param, 1, 50)
            if not valid then
                self:NotifyError(source, err)
                return
            end
            
            -- Traitement
            self:HandleAction(source, data)
        else
            -- CÔTÉ CLIENT
            self:HandleActionClient(data)
        end
    end)
    
    -- Écouter événements core (serveur uniquement)
    if IsDuplicityVersion() then
        -- Joueur connecté
        self:RegisterEvent(vCore.Events.PLAYER_LOADED, function(source)
            local player = self:GetPlayer(source)
            self:Log('Joueur connecté:', player:GetName())
            self:InitializePlayer(source)
        end)
        
        -- Joueur déconnecté
        self:RegisterEvent(vCore.Events.PLAYER_DISCONNECTED, function(source)
            self:Log('Joueur déconnecté:', source)
            self:CleanupPlayer(source)
        end)
    end
end
```

### Étape 5 : Créer les Commandes (Serveur)

```lua
function Module:RegisterCommands()
    if not IsDuplicityVersion() then return end
    
    -- Commande admin
    self:RegisterCommand('mycommand', {
        help = 'Description de la commande',
        params = {
            {name = 'target', help = 'ID du joueur cible', required = true},
            {name = 'amount', help = 'Montant (optionnel)', required = false}
        },
        minLevel = vCore.PermissionLevel.ADMIN,  -- Niveau requis
        restricted = true  -- Seulement staff
    }, function(source, args)
        local player = self:GetPlayer(source)
        if not player then return end
        
        -- Récupérer arguments
        local targetId = tonumber(args[1])
        local amount = tonumber(args[2]) or 100
        
        -- Validation
        if not targetId then
            self:NotifyError(source, 'ID invalide')
            return
        end
        
        local target = self:GetPlayer(targetId)
        if not target then
            self:NotifyError(source, 'Joueur introuvable')
            return
        end
        
        -- Traitement
        self:ExecuteCommand(source, targetId, amount)
        
        -- Notification
        self:NotifySuccess(source, 'Commande exécutée avec succès!')
    end)
    
    -- Commande joueur (sans restrictions)
    self:RegisterCommand('myinfo', {
        help = 'Afficher vos informations',
        params = {},
        restricted = false
    }, function(source, args)
        local player = self:GetPlayer(source)
        if not player then return end
        
        local info = {
            name = player:GetName(),
            money = player:GetMoney('bank'),
            job = player:GetJob().label
        }
        
        TriggerClientEvent(MODULE_NAME .. ':showInfo', source, info)
    end)
end
```

### Étape 6 : Créer les Callbacks (Serveur)

```lua
function Module:RegisterCallbacks()
    if not IsDuplicityVersion() then return end
    
    -- Callback simple
    self:RegisterCallback('getData', function(source, cb, params)
        local player = self:GetPlayer(source)
        if not player then
            cb(nil)
            return
        end
        
        -- Validation
        if params and params.type then
            local valid = vCore.Validation.IsString(params.type, 1, 20)
            if not valid then
                cb(nil)
                return
            end
        end
        
        -- Récupérer données
        local data = self:FetchData(source, params)
        
        cb(data)
    end)
    
    -- Callback avec BDD
    self:RegisterCallback('getFromDB', function(source, cb, id)
        MySQL.query('SELECT * FROM my_table WHERE id = ?', {id}, function(result)
            if result and result[1] then
                cb(result[1])
            else
                cb(nil)
            end
        end)
    end)
end

-- Appeler depuis le client
-- vCore.TriggerCallback('mon_module:getData', function(data)
--     print(json.encode(data))
-- end, {type = 'example'})
```

### Étape 7 : Ajouter au fxmanifest.lua

```lua
-- Dans vAvA_core/fxmanifest.lua

-- SERVEUR
server_scripts {
    -- ... autres scripts ...
    'modules/mon_module/server/*.lua',  -- Tous les fichiers serveur
}

-- CLIENT
client_scripts {
    -- ... autres scripts ...
    'modules/mon_module/client/*.lua',  -- Tous les fichiers client
}

-- PARTAGÉ (si vous avez des fichiers shared)
shared_scripts {
    -- ... autres scripts ...
    'modules/mon_module/shared/*.lua',
}
```

### Étape 8 : Créer la Base de Données (si nécessaire)

Créez `sql/install.sql` :

```sql
-- ══════════════════════════════════════════════════════════════════════════
-- TABLE: mon_module_data
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `mon_module_data` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `data` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    INDEX `idx_identifier` (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ══════════════════════════════════════════════════════════════════════════
-- TABLE: mon_module_logs
-- ══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS `mon_module_logs` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(50) NOT NULL,
    `action` VARCHAR(100) NOT NULL,
    `details` TEXT,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Puis exécutez dans MySQL Workbench ou via oxmysql :

```lua
-- Dans onLoad
function Module.onLoad(self)
    if IsDuplicityVersion() then
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `mon_module_data` (
                -- votre schéma ici
            )
        ]])
    end
end
```

### Étape 9 : Tester le Module

1. **Redémarrer le serveur** : `restart vAvA_core`
2. **Vérifier les logs** :
   ```
   [vAvA_core] Module chargé: mon_module v1.0.0
   [mon_module] Chargement du module...
   [mon_module] Module chargé avec succès!
   ```
3. **Tester les commandes** : `/mycommand 1 500`
4. **Tester le callback** : Depuis le client

---

## 🔌 API du ModuleBase

### Propriétés

```lua
Module.name          -- string : Nom du module
Module.version       -- string : Version
Module.author        -- string : Auteur
Module.config        -- table : Configuration
Module.loaded        -- boolean : État chargement
Module.enabled       -- boolean : État activation
```

### Lifecycle

```lua
-- Hooks appelés automatiquement
Module.onLoad(self)                    -- Au chargement
Module.onStart(self)                   -- Au démarrage
Module.onStop(self)                    -- À l'arrêt
Module.onPlayerLoaded(self, player)    -- Joueur connecté (serveur)
Module.onPlayerUnloaded(self, player)  -- Joueur déconnecté (serveur)
```

### Événements

```lua
-- Enregistrer un événement
self:RegisterEvent(eventName, callback)

-- Exemples
self:RegisterEvent('mon_module:test', function(source, data)
    print('Event reçu:', data)
end)

-- Déclencher événements
self:TriggerEvent(eventName, ...)              -- Local
self:TriggerClientEvent(target, eventName, ...) -- Vers client (serveur)
self:TriggerServerEvent(eventName, ...)         -- Vers serveur (client)
```

### Callbacks

```lua
-- SERVEUR : Enregistrer
self:RegisterCallback('getName', function(source, cb, param)
    local player = self:GetPlayer(source)
    cb(player:GetName())
end)

-- CLIENT : Appeler
vCore.TriggerCallback('mon_module:getName', function(name)
    print('Nom:', name)
end, paramètre)
```

### Commandes

```lua
self:RegisterCommand(name, data, callback)

-- data = {
--     help = "Description",
--     params = {{name = 'param', help = 'desc', required = true}},
--     minLevel = vCore.PermissionLevel.ADMIN,
--     restricted = true
-- }
```

### Exports

```lua
-- Enregistrer un export
self:RegisterExport('myFunction', function(param)
    return 'result: ' .. param
end)

-- Appeler depuis autre ressource
exports['vAvA_core']:myFunction('test')
```

### Joueurs (Serveur)

```lua
-- Obtenir joueur
local player = self:GetPlayer(source)

-- Vérifier existence
if not player then
    self:NotifyError(source, 'Joueur introuvable')
    return
end

-- Méthodes joueur
player:GetName()                    -- Nom
player:GetIdentifier()              -- Identifier
player:GetMoney(type)               -- Argent (cash/bank/black)
player:AddMoney(type, amount)       -- Ajouter
player:RemoveMoney(type, amount)    -- Retirer
player:GetJob()                     -- Job {name, label, grade}
player:SetJob(jobName, grade)       -- Changer job
player:IsOnDuty()                   -- En service?
```

### Notifications

```lua
-- Serveur (envoie au client)
self:NotifySuccess(source, 'Message de succès')
self:NotifyError(source, 'Message d\'erreur')
self:NotifyInfo(source, 'Message d\'information')
self:NotifyWarning(source, 'Message d\'avertissement')

-- Client (affiche localement)
self:NotifySuccess('Succès!')
```

### Logging

```lua
self:Log('Message normal')             -- Blanc
self:Debug('Message debug')            -- Gris (si debug = true)
self:Warn('Message avertissement')     -- Jaune
self:Error('Message erreur')           -- Rouge
self:Success('Message succès')         -- Vert
```

### Validation

```lua
-- Nombre
local valid, err = vCore.Validation.IsNumber(value, min, max)

-- Chaîne
local valid, err = vCore.Validation.IsString(value, minLength, maxLength)

-- Email
local valid, err = vCore.Validation.IsEmail(email)

-- Téléphone
local valid, err = vCore.Validation.IsPhone(phone)

-- Plaque
local valid, err = vCore.Validation.IsPlate(plate)

-- Utilisation
if not valid then
    self:NotifyError(source, err)
    return
end
```

### Helpers

```lua
-- Obtenir identifier
local identifier = vCore.Helpers.GetIdentifier(source)

-- Vérifier argent
if vCore.Helpers.HasMoney(source, 'cash', 1000) then
    -- Le joueur a assez
end

-- Vérifier job
if vCore.Helpers.HasJob(source, 'police', 2) then
    -- Le joueur est police grade 2+
end

-- Obtenir joueurs en ligne d'un job
local cops = vCore.Helpers.GetJobPlayers('police')
print('Policiers en ligne:', #cops)
```

### Base de Données

```lua
-- SELECT
MySQL.query('SELECT * FROM my_table WHERE id = ?', {id}, function(result)
    if result and result[1] then
        print('Trouvé:', json.encode(result[1]))
    end
end)

-- SELECT Async (await)
local result = MySQL.query.await('SELECT * FROM my_table WHERE id = ?', {id})

-- INSERT
MySQL.insert('INSERT INTO my_table (name, value) VALUES (?, ?)', {
    'Test',
    100
}, function(insertId)
    print('ID inséré:', insertId)
end)

-- UPDATE
MySQL.update('UPDATE my_table SET value = ? WHERE id = ?', {200, 1})

-- Transaction
MySQL.transaction({
    {query = 'UPDATE accounts SET balance = balance - ? WHERE id = ?', values = {100, 1}},
    {query = 'UPDATE accounts SET balance = balance + ? WHERE id = ?', values = {100, 2}}
}, function(success)
    print('Transaction:', success)
end)
```

---

## 🎨 Systèmes Avancés

### Builder Pattern

Le framework inclut des builders pour créer facilement des structures complexes.

#### Menu Builder

```lua
-- Menu simple
vCore.Builder.Menu('Mon Menu')
    :SetSubtitle('Sélectionnez une option')
    :AddElement('Option 1', 'opt1', 'Description')
    :AddElement('Option 2', 'opt2', 'Description')
    :OnSelect(function(element)
        print('Sélectionné:', element.value)
    end)
    :Show()  -- Client

-- Menu dynamique avec données BDD
function Module:ShowVehicleMenu(source)
    local identifier = vCore.Helpers.GetIdentifier(source)
    local vehicles = MySQL.query.await(
        'SELECT * FROM owned_vehicles WHERE owner = ?',
        {identifier}
    )
    
    local menu = vCore.Builder.Menu('Mes Véhicules')
        :SetSubtitle('Garage Personnel')
    
    for _, vehicle in ipairs(vehicles) do
        menu:AddElement(
            vehicle.model .. ' (' .. vehicle.plate .. ')',
            vehicle.plate,
            'Carburant: ' .. vehicle.fuel .. '%'
        )
    end
    
    menu:OnSelect(function(element)
            TriggerServerEvent('garage:spawnVehicle', element.value)
        end)
        :OnClose(function()
            print('Menu fermé')
        end)
        :Show(source)
end
```

### State Manager

Gestion d'état réactive pour synchroniser les données.

```lua
-- Créer un state
local myState = vCore.State.Create({
    count = 0,
    name = 'Test',
    data = {}
})

-- Observer changements
myState:Watch('count', function(oldValue, newValue)
    print('Count changé:', oldValue, '->', newValue)
end)

-- Modifier
myState:Set('count', 5)  -- Déclenche le watch

-- Obtenir
local count = myState:Get('count')

-- Commit (batch update)
myState:Commit({
    count = 10,
    name = 'Nouveau nom'
})
```

### Middleware System

Chaîne de traitement pour les requêtes.

```lua
-- Définir middleware
local authMiddleware = function(source, next, data)
    local player = vCore.GetPlayer(source)
    if not player then
        return false, 'Non authentifié'
    end
    next()
end

local permissionMiddleware = function(source, next, data)
    if not vCore.Helpers.HasJob(source, 'police') then
        return false, 'Permission refusée'
    end
    next()
end

-- Appliquer middleware
self:RegisterEvent('mon_module:secureAction', vCore.Middleware.Chain(
    authMiddleware,
    permissionMiddleware
)(function(source, data)
    -- Si tous les middleware passent, exécuter
    print('Action autorisée pour', source)
end))
```

### Hook System

Permet d'intercepter et modifier le comportement.

```lua
-- Enregistrer un hook
vCore.Hooks.Register('playerSpawn', function(playerId, coords)
    print('Joueur spawn:', playerId, 'à', coords)
    
    -- Modifier coords
    return vector3(coords.x + 10, coords.y, coords.z)
end)

-- Déclencher hook
local newCoords = vCore.Hooks.Trigger('playerSpawn', playerId, coords)
```

### Décorateurs

Ajoute des fonctionnalités aux fonctions.

```lua
-- Limiter les appels (rate limiting)
local myFunction = vCore.Decorators.RateLimit(function(source)
    print('Fonction appelée pour', source)
end, 5000)  -- Max 1 appel par 5 secondes

-- Avec cache
local expensiveFunction = vCore.Decorators.Cache(function(param)
    -- Opération coûteuse
    return MySQL.query.await('SELECT * FROM huge_table WHERE id = ?', {param})
end, 60000)  -- Cache pendant 60 secondes

-- Logger automatiquement
local loggedFunction = vCore.Decorators.Log(function(a, b)
    return a + b
end, 'Addition')
```

---

## ✅ Bonnes Pratiques

### Structure du Code

```lua
-- ✅ BON : Code organisé en sections
-- ══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ══════════════════════════════════════════════════════════════════════════

local CONFIG = {}

-- ══════════════════════════════════════════════════════════════════════════
-- VARIABLES LOCALES
-- ══════════════════════════════════════════════════════════════════════════

local cache = {}

-- ══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRIVÉES
-- ══════════════════════════════════════════════════════════════════════════

local function privateFunction()
end

-- ══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PUBLIQUES
-- ══════════════════════════════════════════════════════════════════════════

function Module:PublicFunction()
end

-- ❌ MAUVAIS : Tout mélangé
local a = 1
function test() end
local b = 2
```

### Nommage

```lua
-- ✅ BON
local MODULE_NAME = 'my_module'          -- Constantes en MAJUSCULE
local privateVariable = 'value'          -- Privé en camelCase
function Module:PublicMethod() end       -- Public en PascalCase
local function privateHelper() end       -- Helper en camelCase

-- ❌ MAUVAIS
local module_name = 'test'               -- Pas de snake_case
local PRIVATE = 'value'                  -- Majuscule réservé aux constantes
function module:public_method() end      -- Pas de snake_case
```

### Validation des Données

```lua
-- ✅ BON : Toujours valider
function Module:SetAmount(source, amount)
    -- 1. Valider type
    local valid, err = vCore.Validation.IsNumber(amount, 1, 1000000)
    if not valid then
        self:NotifyError(source, err)
        return false
    end
    
    -- 2. Valider joueur
    local player = self:GetPlayer(source)
    if not player then
        return false
    end
    
    -- 3. Traiter
    player:SetMoney('bank', amount)
    return true
end

-- ❌ MAUVAIS : Pas de validation
function Module:SetAmount(source, amount)
    local player = self:GetPlayer(source)
    player:SetMoney('bank', amount)  -- Peut crasher!
end
```

### Gestion des Erreurs

```lua
-- ✅ BON : pcall pour code à risque
function Module:LoadData()
    local success, result = pcall(function()
        return MySQL.query.await('SELECT * FROM table')
    end)
    
    if not success then
        self:Error('Erreur chargement:', result)
        return nil
    end
    
    return result
end

-- ✅ BON : Vérifier nil
local player = self:GetPlayer(source)
if not player then
    self:Warn('Joueur introuvable:', source)
    return
end

-- ❌ MAUVAIS : Pas de vérification
local player = self:GetPlayer(source)
player:AddMoney('cash', 100)  -- Crash si player = nil
```

### Performance

```lua
-- ✅ BON : Cache les résultats coûteux
function Module:GetVehicleData(plate)
    -- Vérifier cache
    if self.vehicleCache[plate] then
        return self.vehicleCache[plate]
    end
    
    -- Requête BDD
    local data = MySQL.query.await('SELECT * FROM vehicles WHERE plate = ?', {plate})
    
    -- Mettre en cache
    self.vehicleCache[plate] = data
    
    return data
end

-- ✅ BON : Limiter les threads
CreateThread(function()
    while true do
        Wait(1000)  -- Pas de Wait(0)!
        
        if not self.enabled then break end  -- Condition sortie
        
        self:UpdateData()
    end
end)

-- ❌ MAUVAIS : Pas de Wait
CreateThread(function()
    while true do
        self:UpdateData()  -- Va bloquer le serveur!
    end
end)
```

### Sécurité

```lua
-- ✅ BON : Vérifier permissions
RegisterNetEvent('module:adminAction')
AddEventHandler('module:adminAction', function(data)
    local source = source
    
    -- Vérifier permission
    if not vCore.Permissions.HasPermission(source, vCore.PermissionLevel.ADMIN) then
        self:Warn('Tentative accès non autorisé:', source)
        DropPlayer(source, 'Action non autorisée')
        return
    end
    
    -- Valider données
    local valid = vCore.Validation.IsString(data.param, 1, 100)
    if not valid then
        return
    end
    
    -- Exécuter
    self:ExecuteAdminAction(source, data)
end)

-- ❌ MAUVAIS : Pas de vérification
RegisterNetEvent('module:adminAction')
AddEventHandler('module:adminAction', function(data)
    self:ExecuteAdminAction(source, data)  -- N'importe qui peut appeler!
end)
```

### Documentation

```lua
-- ✅ BON : Documenter les fonctions
---Ajoute de l'argent à un joueur
---@param source number ID du joueur
---@param accountType string Type de compte (cash/bank/black)
---@param amount number Montant à ajouter
---@return boolean success Si l'opération a réussi
function Module:AddMoney(source, accountType, amount)
    -- Implémentation
end

-- ✅ BON : Commenter sections complexes
-- Calculer le bonus selon le temps de service
local bonus = 0
if serviceTime > 3600 then  -- Plus d'1 heure
    bonus = baseSalary * 0.5
elseif serviceTime > 1800 then  -- Plus de 30 min
    bonus = baseSalary * 0.25
end
```

---

## 📋 Exemples Complets

### Exemple 1 : Module Simple (Points de Collecte)

```lua
--[[
    MODULE: harvest
    Système de récolte de ressources
]]

local MODULE_NAME = 'harvest'

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'vAvA',
    description = 'Système de récolte de ressources',
    dependencies = {},
    config = {
        debug = false,
        
        -- Zones de récolte
        zones = {
            {
                name = 'Pommes',
                coords = vector3(2345.67, 4567.89, 34.12),
                item = 'apple',
                amount = {min = 1, max = 3},
                duration = 5000,
                cooldown = 10000
            },
            {
                name = 'Bois',
                coords = vector3(1234.56, 5678.90, 45.23),
                item = 'wood',
                amount = {min = 2, max = 5},
                duration = 8000,
                cooldown = 15000
            }
        }
    }
}

local Module = vCore.CreateModule(MODULE_NAME, MODULE_CONFIG)

-- ══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ══════════════════════════════════════════════════════════════════════════

local playerCooldowns = {}

-- ══════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ══════════════════════════════════════════════════════════════════════════

function Module.onLoad(self)
    self:Log('Chargement des zones de récolte...')
    
    -- Vérifier config
    if #self.config.zones == 0 then
        self:Error('Aucune zone configurée!')
        return false
    end
    
    self:Log(#self.config.zones, 'zones chargées')
    return true
end

function Module.onStart(self)
    self:RegisterEvents()
    
    if IsDuplicityVersion() then
        self:RegisterCommands()
    else
        self:StartClientThreads()
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- CLIENT
-- ══════════════════════════════════════════════════════════════════════════

if not IsDuplicityVersion() then
    function Module:StartClientThreads()
        -- Thread marqueurs
        CreateThread(function()
            while self.enabled do
                Wait(0)
                
                local playerCoords = GetEntityCoords(PlayerPedId())
                
                for _, zone in ipairs(self.config.zones) do
                    local distance = #(playerCoords - zone.coords)
                    
                    if distance < 50.0 then
                        -- Afficher marqueur
                        DrawMarker(
                            1, zone.coords.x, zone.coords.y, zone.coords.z - 1.0,
                            0, 0, 0, 0, 0, 0,
                            1.5, 1.5, 1.0,
                            0, 255, 0, 200,
                            false, true, 2, false, nil, nil, false
                        )
                        
                        if distance < 2.0 then
                            -- Afficher texte
                            vCore.UI.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~ pour récolter ' .. zone.name)
                            
                            if IsControlJustPressed(0, 38) then  -- E
                                self:StartHarvest(zone)
                            end
                        end
                    end
                end
            end
        end)
    end
    
    function Module:StartHarvest(zone)
        -- Vérifier si déjà en action
        if self.isHarvesting then
            return
        end
        
        self.isHarvesting = true
        
        -- Animation
        TaskStartScenarioInPlace(PlayerPedId(), 'PROP_HUMAN_BUM_BIN', 0, true)
        
        -- Barre de progression
        vCore.UI.ShowProgress('Récolte en cours...', zone.duration)
        
        Wait(zone.duration)
        
        -- Arrêter animation
        ClearPedTasks(PlayerPedId())
        
        -- Envoyer au serveur
        TriggerServerEvent(MODULE_NAME .. ':collect', zone.name)
        
        self.isHarvesting = false
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- SERVER
-- ══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    function Module:RegisterEvents()
        self:RegisterEvent(MODULE_NAME .. ':collect', function(source, zoneName)
            self:ProcessHarvest(source, zoneName)
        end)
    end
    
    function Module:ProcessHarvest(source, zoneName)
        local player = self:GetPlayer(source)
        if not player then return end
        
        -- Trouver la zone
        local zone = nil
        for _, z in ipairs(self.config.zones) do
            if z.name == zoneName then
                zone = z
                break
            end
        end
        
        if not zone then
            self:Warn('Zone introuvable:', zoneName)
            return
        end
        
        -- Vérifier cooldown
        local identifier = player:GetIdentifier()
        if playerCooldowns[identifier] and playerCooldowns[identifier][zoneName] then
            local remaining = playerCooldowns[identifier][zoneName] - os.time()
            if remaining > 0 then
                self:NotifyError(source, 'Attendez ' .. remaining .. ' secondes')
                return
            end
        end
        
        -- Calculer quantité
        local amount = math.random(zone.amount.min, zone.amount.max)
        
        -- Donner item (via module inventory)
        local success = exports['vAvA_core']:AddItem(source, zone.item, amount)
        
        if success then
            self:NotifySuccess(source, 'Vous avez récolté ' .. amount .. 'x ' .. zone.name)
            
            -- Appliquer cooldown
            if not playerCooldowns[identifier] then
                playerCooldowns[identifier] = {}
            end
            playerCooldowns[identifier][zoneName] = os.time() + (zone.cooldown / 1000)
        else
            self:NotifyError(source, 'Inventaire plein')
        end
    end
    
    function Module:RegisterCommands()
        -- Commande admin pour reset cooldowns
        self:RegisterCommand('harvestreset', {
            help = 'Reset les cooldowns de récolte d\'un joueur',
            params = {{name = 'id', help = 'ID du joueur', required = true}},
            minLevel = vCore.PermissionLevel.MODERATOR,
            restricted = true
        }, function(source, args)
            local targetId = tonumber(args[1])
            local target = self:GetPlayer(targetId)
            
            if not target then
                self:NotifyError(source, 'Joueur introuvable')
                return
            end
            
            local identifier = target:GetIdentifier()
            playerCooldowns[identifier] = nil
            
            self:NotifySuccess(source, 'Cooldowns réinitialisés pour ' .. target:GetName())
        end)
    end
end

-- ══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ══════════════════════════════════════════════════════════════════════════

function Module:GetZones()
    return self.config.zones
end

self:RegisterExport('GetZones', function()
    return Module:GetZones()
end)
```

### Exemple 2 : Module avec UI (Shop)

Créez une structure complète :

**Structure:**
```
modules/shop/
├── client/
│   ├── main.lua
│   └── ui.lua
├── server/
│   └── main.lua
├── html/
│   ├── index.html
│   ├── style.css
│   └── script.js
├── config.lua
└── sql/
    └── install.sql
```

**server/main.lua:**
```lua
local MODULE_NAME = 'shop'

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'vAvA',
    description = 'Système de magasin',
    dependencies = {'economy'},
    config = {
        shops = {
            {
                name = '24/7',
                coords = vector3(25.7, -1347.3, 29.49),
                items = {
                    {name = 'bread', label = 'Pain', price = 10},
                    {name = 'water', label = 'Eau', price = 5}
                }
            }
        }
    }
}

local Module = vCore.CreateModule(MODULE_NAME, MODULE_CONFIG)

function Module.onStart(self)
    self:RegisterCallbacks()
end

function Module:RegisterCallbacks()
    -- Obtenir items du shop
    self:RegisterCallback('getShopItems', function(source, cb, shopName)
        for _, shop in ipairs(self.config.shops) do
            if shop.name == shopName then
                cb(shop.items)
                return
            end
        end
        cb(nil)
    end)
    
    -- Acheter item
    self:RegisterCallback('buyItem', function(source, cb, data)
        local player = self:GetPlayer(source)
        if not player then
            cb({success = false, message = 'Joueur introuvable'})
            return
        end
        
        -- Validation
        local valid = vCore.Validation.IsNumber(data.price, 1, 1000000)
        if not valid then
            cb({success = false, message = 'Prix invalide'})
            return
        end
        
        -- Vérifier argent
        if not vCore.Helpers.HasMoney(source, 'cash', data.price) then
            cb({success = false, message = 'Pas assez d\'argent'})
            return
        end
        
        -- Retirer argent
        player:RemoveMoney('cash', data.price)
        
        -- Ajouter item
        local added = exports['vAvA_core']:AddItem(source, data.item, data.quantity)
        
        if added then
            cb({success = true, message = 'Achat réussi'})
        else
            -- Rembourser
            player:AddMoney('cash', data.price)
            cb({success = false, message = 'Inventaire plein'})
        end
    end)
end
```

**client/main.lua:**
```lua
local Module = nil

CreateThread(function()
    while not vCore do
        vCore = exports['vAvA_core']:GetCoreObject()
        Wait(100)
    end
    
    Module = {
        config = {
            shops = {
                {
                    name = '24/7',
                    coords = vector3(25.7, -1347.3, 29.49),
                    blip = {sprite = 52, color = 2, scale = 0.8}
                }
            }
        }
    }
    
    CreateBlips()
    StartThreads()
end)

function CreateBlips()
    for _, shop in ipairs(Module.config.shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, shop.blip.sprite)
        SetBlipColour(blip, shop.blip.color)
        SetBlipScale(blip, shop.blip.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(shop.name)
        EndTextCommandSetBlipName(blip)
    end
end

function StartThreads()
    CreateThread(function()
        while true do
            Wait(0)
            
            local playerCoords = GetEntityCoords(PlayerPedId())
            local inRange = false
            
            for _, shop in ipairs(Module.config.shops) do
                local distance = #(playerCoords - shop.coords)
                
                if distance < 2.0 then
                    inRange = true
                    vCore.UI.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~ pour ouvrir le magasin')
                    
                    if IsControlJustPressed(0, 38) then
                        OpenShop(shop.name)
                    end
                end
            end
            
            if not inRange then
                Wait(500)
            end
        end
    end)
end

function OpenShop(shopName)
    vCore.TriggerCallback('shop:getShopItems', function(items)
        if items then
            -- Ouvrir UI
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = 'openShop',
                shopName = shopName,
                items = items
            })
        end
    end, shopName)
end

-- Recevoir events depuis NUI
RegisterNUICallback('buyItem', function(data, cb)
    vCore.TriggerCallback('shop:buyItem', function(result)
        if result.success then
            vCore.ShowNotification('success', result.message)
        else
            vCore.ShowNotification('error', result.message)
        end
        cb('ok')
    end, data)
end)

RegisterNUICallback('closeShop', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)
```

**html/index.html:**
```html
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Shop</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div id="shop-container" style="display: none;">
        <div class="shop-header">
            <h1 id="shop-name">Magasin</h1>
            <button id="close-btn">&times;</button>
        </div>
        
        <div id="items-grid"></div>
    </div>
    
    <script src="https://code.jquery.com/jquery-3.6.0.min.js"></script>
    <script src="script.js"></script>
</body>
</html>
```

**html/script.js:**
```javascript
$(document).ready(function() {
    window.addEventListener('message', function(event) {
        const data = event.data;
        
        if (data.action === 'openShop') {
            openShop(data.shopName, data.items);
        }
    });
    
    $('#close-btn').click(function() {
        closeShop();
    });
    
    document.onkeyup = function(e) {
        if (e.key === 'Escape') {
            closeShop();
        }
    };
});

function openShop(name, items) {
    $('#shop-name').text(name);
    $('#shop-container').fadeIn(300);
    
    const grid = $('#items-grid');
    grid.empty();
    
    items.forEach(item => {
        const itemDiv = $(`
            <div class="shop-item" data-item="${item.name}">
                <img src="img/items/${item.name}.png" alt="${item.label}">
                <h3>${item.label}</h3>
                <p class="price">$${item.price}</p>
                <input type="number" class="quantity" value="1" min="1" max="99">
                <button class="buy-btn">Acheter</button>
            </div>
        `);
        
        itemDiv.find('.buy-btn').click(function() {
            const quantity = parseInt(itemDiv.find('.quantity').val());
            buyItem(item.name, quantity, item.price);
        });
        
        grid.append(itemDiv);
    });
}

function buyItem(itemName, quantity, unitPrice) {
    const totalPrice = quantity * unitPrice;
    
    $.post('https://vAvA_core/buyItem', JSON.stringify({
        item: itemName,
        quantity: quantity,
        price: totalPrice
    }));
}

function closeShop() {
    $('#shop-container').fadeOut(300);
    $.post('https://vAvA_core/closeShop', JSON.stringify({}));
}
```

**html/style.css:**
```css
* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    background: transparent;
}

#shop-container {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 800px;
    max-height: 600px;
    background: rgba(0, 0, 0, 0.95);
    border-radius: 10px;
    overflow: hidden;
    box-shadow: 0 0 50px rgba(255, 30, 30, 0.5);
}

.shop-header {
    padding: 20px;
    background: linear-gradient(135deg, #FF1E1E, #8B0000);
    display: flex;
    justify-content: space-between;
    align-items: center;
}

.shop-header h1 {
    color: white;
    font-size: 24px;
}

#close-btn {
    background: none;
    border: none;
    color: white;
    font-size: 32px;
    cursor: pointer;
    transition: transform 0.2s;
}

#close-btn:hover {
    transform: scale(1.2);
}

#items-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 20px;
    padding: 20px;
    max-height: 500px;
    overflow-y: auto;
}

.shop-item {
    background: rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 15px;
    text-align: center;
    transition: transform 0.2s;
}

.shop-item:hover {
    transform: translateY(-5px);
    background: rgba(255, 255, 255, 0.15);
}

.shop-item img {
    width: 80px;
    height: 80px;
    object-fit: contain;
}

.shop-item h3 {
    color: white;
    margin: 10px 0;
    font-size: 16px;
}

.price {
    color: #4CAF50;
    font-size: 18px;
    font-weight: bold;
    margin: 10px 0;
}

.quantity {
    width: 60px;
    padding: 5px;
    border: 2px solid #FF1E1E;
    background: rgba(255, 255, 255, 0.1);
    color: white;
    border-radius: 4px;
    text-align: center;
    margin: 10px 0;
}

.buy-btn {
    width: 100%;
    padding: 10px;
    background: linear-gradient(135deg, #FF1E1E, #8B0000);
    border: none;
    color: white;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    font-weight: bold;
    transition: all 0.3s;
}

.buy-btn:hover {
    background: linear-gradient(135deg, #8B0000, #FF1E1E);
    transform: scale(1.05);
}

/* Scrollbar */
#items-grid::-webkit-scrollbar {
    width: 8px;
}

#items-grid::-webkit-scrollbar-track {
    background: rgba(255, 255, 255, 0.05);
}

#items-grid::-webkit-scrollbar-thumb {
    background: #FF1E1E;
    border-radius: 4px;
}
```

---

## 🐛 Débogage et Tests

### Mode Debug

Activez le debug dans votre module :

```lua
config = {
    debug = true
}

-- Utilisez self:Debug() au lieu de print()
self:Debug('Variable:', json.encode(myVar))
```

### Console F8

```lua
-- Tester un callback
vCore.TriggerCallback('mon_module:getData', function(data)
    print(json.encode(data))
end, {param = 'test'})

-- Déclencher événement
TriggerEvent('mon_module:test', {data = 'test'})

-- Obtenir module
local module = vCore.Modules['mon_module']
print(module.loaded)
```

### Logs

Vérifiez les logs serveur :
- `[mon_module] Module chargé` = OK
- `[ERROR]` = Problème

### Erreurs Courantes

| Erreur | Cause | Solution |
|--------|-------|----------|
| `attempt to index nil value (local 'player')` | Joueur pas trouvé | Vérifier avec `if not player then return end` |
| `attempt to call nil value` | Fonction inexistante | Vérifier le nom et que vCore est chargé |
| `MySQL error: Table doesn't exist` | Table BDD absente | Exécuter `sql/install.sql` |
| `Module déjà chargé` | Doublon dans fxmanifest | Vérifier fxmanifest.lua |

---

## ❓ FAQ

### Comment obtenir l'argent d'un joueur ?

```lua
-- Serveur
local player = self:GetPlayer(source)
local cash = player:GetMoney('cash')
local bank = player:GetMoney('bank')

-- Avec helper
local cash = vCore.Helpers.GetMoney(source, 'cash')
```

### Comment vérifier si un joueur a un job ?

```lua
if vCore.Helpers.HasJob(source, 'police', 2) then
    -- Joueur est police grade 2+
end
```

### Comment créer un blip ?

```lua
-- Client
local blip = AddBlipForCoord(x, y, z)
SetBlipSprite(blip, 52)  -- Icône
SetBlipColour(blip, 2)   -- Couleur verte
SetBlipScale(blip, 0.8)
SetBlipAsShortRange(blip, true)
BeginTextCommandSetBlipName('STRING')
AddTextComponentString('Mon Blip')
EndTextCommandSetBlipName(blip)
```

### Comment afficher une notification ?

```lua
-- Serveur vers client
self:NotifySuccess(source, 'Message de succès')
self:NotifyError(source, 'Message d\'erreur')

-- Client local
vCore.ShowNotification('success', 'Message')
```

### Comment créer un marqueur au sol ?

```lua
-- Client, dans un thread
DrawMarker(
    1,                        -- Type (1 = cylindre)
    x, y, z - 1.0,           -- Position
    0, 0, 0,                 -- Direction
    0, 0, 0,                 -- Rotation
    1.5, 1.5, 1.0,           -- Scale
    0, 255, 0, 200,          -- RGBA (vert transparent)
    false,                    -- Bob up/down
    true,                     -- Face camera
    2,                        -- Rotate
    false,                    -- Texture
    nil, nil, false
)
```

### Comment sauvegarder des données joueur ?

```lua
-- Serveur
MySQL.update('UPDATE users SET data = ? WHERE identifier = ?', {
    json.encode(playerData),
    identifier
})

-- Avec async
MySQL.update.await('UPDATE users SET data = ? WHERE identifier = ?', {
    json.encode(playerData),
    identifier
})
```

### Comment créer un menu contextuel ?

```lua
-- Utiliser le Builder
vCore.Builder.Menu('Mon Menu')
    :AddElement('Option 1', 'opt1')
    :AddElement('Option 2', 'opt2')
    :OnSelect(function(element)
        if element.value == 'opt1' then
            print('Option 1 sélectionnée')
        end
    end)
    :Show(source)  -- Serveur
```

### Comment appeler un export d'un autre module ?

```lua
-- Depuis votre module
local result = self:GetExport('inventory', 'AddItem')
if result then
    result(source, 'bread', 1)
end

-- Depuis autre ressource
exports['vAvA_core']:NomExport(param)
```

### Comment créer une animation ?

```lua
-- Client
TaskStartScenarioInPlace(PlayerPedId(), 'WORLD_HUMAN_SMOKING', 0, true)

-- Ou avec dictionnaire
RequestAnimDict('anim@heists@ornate_bank@grab_cash')
while not HasAnimDictLoaded('anim@heists@ornate_bank@grab_cash') do
    Wait(10)
end
TaskPlayAnim(PlayerPedId(), 'anim@heists@ornate_bank@grab_cash', 'grab', 8.0, -8.0, -1, 1, 0, false, false, false)
```

### Comment détecter une touche ?

```lua
-- Client, dans thread
if IsControlJustPressed(0, 38) then  -- E
    print('Touche E pressée')
end

-- Liste touches communes :
-- 38 = E
-- 47 = G
-- 74 = H
-- 246 = Y
-- 249 = N
```

---

## 📞 Support

### Ressources

- 📖 Documentation complète : `/doc/`
- 💬 Discord : [Votre Discord]
- 🐛 Issues : [GitHub]
- 📝 Exemples : `/modules/`

### Contribuer

1. Fork le projet
2. Créez votre module
3. Testez complètement
4. Soumettez une Pull Request
5. Documentez votre code

---

## 📜 Licence

vAvA_core © 2026 - Tous droits réservés

---

**🎉 Vous êtes maintenant prêt à créer des modules vAvA_core !**

> 💡 **Conseil** : Commencez par un module simple (comme l'exemple harvest) avant de passer à des modules complexes avec UI.

> ⚠️ **Important** : Testez toujours votre module sur un serveur de développement avant de le déployer en production.

> 🚀 **Bon développement !**
