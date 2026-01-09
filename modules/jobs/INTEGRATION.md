# Intégration du Module Jobs avec vAvA Core

## Structure Finale du Projet

```
vAvA_core/
├── database/
│   └── sql/
│       ├── init.sql
│       └── jobs_system.sql ✨ NOUVEAU
├── modules/
│   ├── chat/
│   ├── concess/
│   ├── creator/
│   ├── garage/
│   ├── inventory/
│   ├── jobshop/
│   └── jobs/ ✨ NOUVEAU
│       ├── client/
│       │   ├── main.lua
│       │   ├── interactions.lua
│       │   └── menus.lua
│       ├── server/
│       │   ├── main.lua
│       │   ├── database.lua
│       │   ├── interactions.lua
│       │   └── creator.lua
│       ├── html/
│       │   ├── index.html
│       │   ├── css/
│       │   │   └── style.css
│       │   └── js/
│       │       └── app.js
│       ├── config.lua
│       ├── fxmanifest.lua
│       ├── README.md
│       ├── EXAMPLES.lua
│       └── INSTALLATION.md
├── server/
│   ├── jobs.lua (existant - peut être remplacé)
│   └── ...
└── server.cfg
```

## Modifications à Effectuer

### 1. Mettre à jour server.cfg

Ajoutez le module jobs dans votre configuration:

```cfg
# ════════════════════════════════════════════
# vAvA Core - Configuration Serveur
# ════════════════════════════════════════════

# Core principal
ensure vAvA_core

# Dépendances
ensure oxmysql
ensure ox_lib

# Modules Core
ensure chat
ensure concess
ensure creator
ensure garage
ensure inventory
ensure jobshop
ensure keys
ensure loadingscreen
ensure persist
ensure sit

# Module Jobs ✨ NOUVEAU
ensure jobs

# Autres ressources
# ...
```

### 2. Intégration avec le système d'inventaire

Le module jobs est compatible avec:
- ox_inventory (recommandé)
- qb-inventory
- esx_inventory

Si vous utilisez ox_inventory, ajoutez ces items dans votre `items.lua`:

```lua
-- Items de base pour les jobs
['bread'] = {
    label = 'Pain',
    weight = 200,
    stack = true,
    close = true,
    description = 'Un pain frais'
},
['wheat'] = {
    label = 'Blé',
    weight = 100,
    stack = true,
    close = true,
    description = 'Du blé pour faire du pain'
},
['water_bottle'] = {
    label = 'Bouteille d\'eau',
    weight = 500,
    stack = true,
    close = true,
    description = 'Une bouteille d\'eau',
    client = {
        status = { thirst = 200000 },
        anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
        prop = { model = 'prop_ld_flow_bottle', pos = vec3(0.03, 0.03, 0.02), rot = vec3(0.0, 0.0, -1.5) },
        usetime = 2500,
    }
},
-- Items EMS
['bandage'] = {
    label = 'Bandage',
    weight = 100,
    stack = true,
    close = true,
    description = 'Un bandage de premiers soins'
},
['medikit'] = {
    label = 'Kit Médical',
    weight = 500,
    stack = true,
    close = true,
    description = 'Un kit médical complet'
},
-- Items Police
['handcuffs'] = {
    label = 'Menottes',
    weight = 300,
    stack = true,
    close = true,
    description = 'Des menottes'
},
-- Items Mechanic
['repairkit'] = {
    label = 'Kit de Réparation',
    weight = 1000,
    stack = true,
    close = true,
    description = 'Un kit pour réparer les véhicules'
},
```

### 3. Intégration avec le module jobshop

Modifiez `modules/jobshop/client/main.lua` pour supporter l'ouverture depuis le module jobs:

```lua
-- Ajouter cet event
RegisterNetEvent('vCore:jobshop:openFromJobSystem', function(shopName)
    -- Trouver le shop par nom
    for _, shop in pairs(JobShops) do
        if shop.name == shopName then
            OpenShopNUI(shop)
            break
        end
    end
end)
```

### 4. Intégration avec le module garage

Le module jobs spawn ses propres véhicules de service, mais vous pouvez créer une intégration:

```lua
-- Dans modules/garage/server/main.lua
RegisterNetEvent('vcore_garage:requestJobVehicle', function(vehicleModel, jobName)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local job = player:GetJob()
    if job.name ~= jobName then
        return
    end
    
    -- Vérifier si le véhicule est autorisé pour ce job
    local hasAccess = exports['jobs']:CheckVehicleAccess(source, vehicleModel)
    
    if hasAccess then
        -- Spawn le véhicule
        TriggerClientEvent('vcore_garage:spawnVehicle', source, vehicleModel)
    end
end)
```

### 5. Synchronisation des jobs avec server/jobs.lua

Si vous avez un fichier `server/jobs.lua` existant, vous pouvez:

**Option A: Remplacer complètement**
- Supprimez ou renommez `server/jobs.lua`
- Le module jobs gère tout

**Option B: Intégration hybride**
- Gardez `server/jobs.lua` pour la compatibilité
- Ajoutez des bridges:

```lua
-- Dans server/jobs.lua
-- Importer les fonctions du module jobs
local JobsModule = exports['jobs']

-- Bridge pour la compatibilité
function vCore.Jobs.SetJob(source, jobName, grade)
    return JobsModule:SetPlayerJob(source, jobName, grade)
end

function vCore.Jobs.GetPlayerJob(source)
    local player = vCore.GetPlayer(source)
    if player then
        return player:GetJob()
    end
    return nil
end

function vCore.Jobs.HasPermission(source, permission)
    return JobsModule:HasJobPermission(source, permission)
end

-- Synchroniser au démarrage
CreateThread(function()
    Wait(5000)
    local allJobs = JobsModule:GetAllJobs()
    
    for jobName, jobData in pairs(allJobs) do
        Config.Jobs.List[jobName] = jobData
    end
    
    print('[vCore] Synchronisation jobs: ' .. #allJobs .. ' jobs chargés')
end)
```

### 6. Events du Core

Assurez-vous que votre core trigger ces events pour que le module jobs fonctionne:

```lua
-- Quand le joueur se connecte
TriggerClientEvent('vCore:Client:OnPlayerLoaded', source)

-- Quand le job change
TriggerClientEvent('vCore:Client:OnJobUpdate', source, newJob)
```

### 7. Intégration avec TxAdmin

Si vous utilisez TxAdmin, ajoutez ces recettes dans `recipe.json`:

```json
{
  "tasks": [
    {
      "action": "download_github",
      "src": "https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip",
      "dest": "./resources/oxmysql"
    },
    {
      "action": "download_github", 
      "src": "https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip",
      "dest": "./resources/ox_lib"
    },
    {
      "action": "ensure_dir",
      "path": "./resources/[vava]/jobs"
    },
    {
      "action": "query_database",
      "file": "./resources/[vava]/vAvA_core/database/sql/jobs_system.sql"
    },
    {
      "action": "connect_database"
    }
  ]
}
```

## Commands Admin à Créer

Ajoutez ces commandes dans `server/commands.lua`:

```lua
-- Recharger les jobs
RegisterCommand('reloadjobs', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then return end
    
    exports['jobs']:ReloadJobs()
    TriggerClientEvent('chat:addMessage', source, {
        args = {'SYSTÈME', 'Jobs rechargés depuis la base de données'}
    })
end, false)

-- Créer un job rapide
RegisterCommand('quickjob', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then return end
    
    if not args[1] or not args[2] then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'USAGE', '/quickjob [nom] [label]'}
        })
        return
    end
    
    TriggerServerEvent('vCore:jobs:createJob', {
        name = args[1],
        label = args[2],
        type = 'custom',
        default_salary = 30,
        whitelisted = false,
        society_account = true,
        grades = {
            {grade = 0, name = 'employee', label = 'Employé', salary = 20, permissions = {}},
            {grade = 1, name = 'boss', label = 'Patron', salary = 50, permissions = {'hire', 'fire', 'manage', 'withdraw'}}
        }
    })
end, false)

-- Téléporter à un job
RegisterCommand('gotojob', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then return end
    
    if not args[1] then
        TriggerClientEvent('chat:addMessage', source, {
            args = {'USAGE', '/gotojob [nom_job]'}
        })
        return
    end
    
    -- Récupérer la première interaction du job
    local interactions = exports['jobs']:GetJobInteractions(args[1])
    
    if interactions and #interactions > 0 then
        local pos = interactions[1].position
        SetEntityCoords(GetPlayerPed(source), pos.x, pos.y, pos.z)
    end
end, false)
```

## Tests de Validation

### Checklist de Tests

#### Test 1: Installation
- [ ] SQL exécuté sans erreurs
- [ ] Module démarré
- [ ] Aucune erreur dans les logs

#### Test 2: Jobs par défaut
- [ ] Job EMS existe
- [ ] Job Police existe
- [ ] Job Mechanic existe
- [ ] Grades correctement créés

#### Test 3: Attribution de job
- [ ] `/givejob [id] ambulance 0` fonctionne
- [ ] Le joueur reçoit une notification
- [ ] Le job est sauvegardé en DB

#### Test 4: Interactions
- [ ] Les markers s'affichent
- [ ] Le texte d'aide apparaît
- [ ] L'appui sur E fonctionne

#### Test 5: Fonctionnalités
- [ ] Prise de service fonctionne
- [ ] Vestiaire fonctionne
- [ ] Spawn véhicule fonctionne
- [ ] Farm fonctionne
- [ ] Craft fonctionne
- [ ] Vente fonctionne

#### Test 6: Menu patron
- [ ] Menu boss accessible (bon grade)
- [ ] Recrutement fonctionne
- [ ] Gestion argent fonctionne

#### Test 7: Salaires
- [ ] Salaires automatiques payés
- [ ] Montant correct
- [ ] Notification reçue

### Scripts de Test

Créez `modules/jobs/test.lua`:

```lua
-- Test automatique du système
RegisterCommand('testjobs', function(source, args, rawCommand)
    if not IsPlayerAdmin(source) then return end
    
    local tests = {
        {name = 'Récupérer les jobs', func = function()
            local jobs = exports['jobs']:GetAllJobs()
            return jobs ~= nil and next(jobs) ~= nil
        end},
        {name = 'Récupérer un job', func = function()
            local job = exports['jobs']:GetJob('ambulance')
            return job ~= nil and job.name == 'ambulance'
        end},
        {name = 'Donner un job', func = function()
            return exports['jobs']:SetPlayerJob(source, 'ambulance', 0)
        end},
        {name = 'Vérifier permission', func = function()
            return exports['jobs']:HasJobPermission(source, 'revive') == false
        end},
        {name = 'Compte société', func = function()
            local money = exports['jobs']:GetSocietyAccount('ambulance')
            return type(money) == 'number'
        end}
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local success, result = pcall(test.func)
        
        if success and result then
            passed = passed + 1
            print('✓ ' .. test.name)
        else
            failed = failed + 1
            print('✗ ' .. test.name)
        end
    end
    
    print(string.format('Tests: %d passed, %d failed', passed, failed))
end, false)
```

## Maintenance

### Sauvegarde

Sauvegardez régulièrement ces tables:
```sql
mysqldump -u root -p votre_db jobs_config job_grades job_interactions > backup_jobs.sql
```

### Mises à jour

Pour mettre à jour le système:
1. Sauvegardez la base de données
2. Remplacez les fichiers
3. Exécutez les migrations si nécessaire
4. Redémarrez le serveur

### Monitoring

Surveillez ces logs:
- `job_logs` - Actions des joueurs
- `vcore_migrations` - Migrations exécutées
- Console serveur - Erreurs et warnings

## Support

Pour toute question:
1. Consultez README.md
2. Consultez INSTALLATION.md
3. Vérifiez les EXAMPLES.lua
4. Activez le debug mode
5. Consultez les logs

## Conclusion

Votre système de jobs est maintenant complètement intégré ! Vous avez:

✅ Un système de jobs complet et flexible
✅ 3 jobs pré-configurés (EMS, Police, Mechanic)
✅ Un système de création de jobs dynamique
✅ Des points d'interaction multiples (farm, craft, sell, etc.)
✅ Une intégration avec jobshop
✅ Une gestion des employés et finances
✅ Un système de salaires automatiques
✅ Des logs complets

Le système est prêt pour la production ! 🎉
