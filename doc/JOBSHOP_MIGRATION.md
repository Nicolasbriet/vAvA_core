# 🔄 Migration vAvA_jobshop vers vAvA_core

## 📋 Étapes de Migration

### 1. Modifier fxmanifest.lua

```lua
fx_version 'cerulean'
game 'gta5'

name 'vAvA_jobshop'
description 'Système de boutiques pour jobs avec gestion admin/patron'
version '2.0.0'  -- Version mise à jour
author 'vAvA'

-- CHANGEMENT : Utiliser vAvA_core au lieu de qb-core
shared_scripts {
    '@vAvA_core/shared/locale.lua',
    'shared/config.lua'
}

client_scripts {
    'client/main.lua',
    'client/menus.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/commands.lua'
}

-- AJOUT : Dépendance explicite
dependencies {
    'vAvA_core'
}
```

### 2. Modifier server/main.lua

```lua
-- AVANT
local QBCore = exports['qb-core']:GetCoreObject()

-- APRÈS
vCore = vCore or exports['vAvA_core']:GetCoreObject()

-- Fonction de récupération joueur
local function GetPlayer(source)
    return vCore.GetPlayer(source)
end

-- Fonction de vérification admin
local function IsAdmin(source)
    local player = GetPlayer(source)
    return player and player:IsAdmin()
end

-- Remplacer toutes les occurrences
-- QBCore.Functions.GetPlayer(src) -> GetPlayer(src)
-- QBCore.Functions.HasPermission(src, group) -> IsAdmin(src)
```

### 3. Intégration avec le Système Jobs

```lua
-- Nouvelle fonction pour vérifier si un joueur peut gérer une boutique
local function CanManageShop(source, jobName)
    local player = GetPlayer(source)
    if not player then return false end
    
    local job = player:GetJob()
    
    -- Vérifier si c'est le bon job
    if job.name ~= jobName then return false end
    
    -- Vérifier les permissions (boss ou manage)
    return job.permissions and (job.permissions.manage or job.permissions.withdraw)
end

-- Utilisation de la commande setjob native
local function SetPlayerJob(targetId, jobName, grade)
    -- Utiliser la fonction native de vAvA_core
    return vCore.Jobs.SetJob(targetId, jobName, grade)
end
```

### 4. Notifications Système

```lua
-- AVANT
TriggerClientEvent('QBCore:Notify', src, message, type)

-- APRÈS  
vCore.Notify(src, message, type)
```

## 🎯 Bénéfices de la Migration

1. **Intégration Native** avec le système jobs de vAvA_core
2. **Cohérence** avec l'architecture serveur
3. **Performances** améliorées (un seul framework)
4. **Maintenance** facilitée
5. **Évolutivité** avec les futures mises à jour vAvA_core