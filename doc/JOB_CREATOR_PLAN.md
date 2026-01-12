# 🏗️ Job Creator System - Plan de Développement

*Système de création de jobs avancé pour vAvA_core*

## 🎯 Vision du Projet

Créer un système de gestion de jobs complet et intuitif, similaire au "Jobs Creator: The Ultimate Tool for FiveM Server Admins", mais entièrement intégré à l'écosystème vAvA_core.

## ✅ État Actuel vs Objectif

### État Actuel (vAvA_core)
- ✅ Commande `/setjob` fonctionnelle
- ✅ Système de jobs basique
- ✅ Gestion des grades et permissions
- ✅ Compatible personnages (non utilisateurs)
- ❌ Interface graphique limitée
- ❌ Pas de templates pré-configurés
- ❌ Création manuelle des jobs

### Objectif (Job Creator Ultimate)
- 🎯 Interface web moderne et intuitive
- 🎯 Templates pré-configurés (10+ jobs)
- 🎯 Placement visuel des points d'interaction
- 🎯 Système de preview en temps réel
- 🎯 Import/Export de configurations
- 🎯 Gestion avancée des sociétés

## 🏗️ Architecture du Système

### Structure des Fichiers

```
vAvA_jobcreator/
├── fxmanifest.lua
├── config/
│   ├── config.lua           # Configuration générale
│   ├── templates.lua        # Templates de jobs
│   └── permissions.lua      # Système de permissions
├── client/
│   ├── main.lua            # Client principal
│   ├── interface.lua       # Gestion UI
│   ├── preview.lua         # Mode prévisualisation
│   ├── interactions.lua    # Points d'interaction
│   └── utils.lua          # Fonctions utilitaires
├── server/
│   ├── main.lua           # Serveur principal
│   ├── database.lua       # Gestion BDD
│   ├── templates.lua      # Gestion templates
│   ├── society.lua        # Système société
│   ├── jobs.lua           # Logique jobs
│   └── commands.lua       # Commandes admin
├── web/
│   ├── index.html         # Interface principale
│   ├── css/
│   │   ├── style.css      # Styles principaux
│   │   └── themes.css     # Thèmes vAvA
│   ├── js/
│   │   ├── app.js         # Application principale
│   │   ├── jobs.js        # Gestion jobs
│   │   ├── templates.js   # Gestion templates
│   │   └── utils.js       # Utilitaires JS
│   └── assets/
│       ├── icons/         # Icônes jobs
│       └── sounds/        # Sons interface
└── database/
    ├── schema.sql         # Structure BDD
    └── templates.sql      # Données de base
```

## 📊 Fonctionnalités Détaillées

### 1. Dashboard Principal

#### Interface Web Responsive
```html
<!-- Interface moderne avec design vAvA -->
<div class="vava-dashboard">
    <header class="dashboard-header">
        <img src="assets/vava-logo.png" alt="vAvA" class="logo">
        <h1>Job Creator Ultimate</h1>
    </header>
    
    <nav class="dashboard-nav">
        <button class="nav-btn active" data-section="jobs">Jobs</button>
        <button class="nav-btn" data-section="templates">Templates</button>
        <button class="nav-btn" data-section="society">Sociétés</button>
        <button class="nav-btn" data-section="stats">Statistiques</button>
    </nav>
    
    <main class="dashboard-main">
        <!-- Contenu dynamique -->
    </main>
</div>
```

#### Fonctionnalités du Dashboard
- 📊 Vue d'ensemble des jobs actifs
- 🎯 Statistiques en temps réel
- 🔧 Accès rapide aux outils
- 📋 Notifications système

### 2. Système de Templates

#### Templates Pré-Configurés

```lua
-- Templates de base inclus
Config.JobTemplates = {
    ['police'] = {
        name = 'police',
        label = 'Police Nationale',
        category = 'public',
        icon = 'badge-check',
        color = '#2563eb',
        grades = {
            [0] = {name = 'cadet', label = 'Cadet', salary = 1500, permissions = {'handcuff'}},
            [1] = {name = 'officer', label = 'Officier', salary = 2000, permissions = {'handcuff', 'search'}},
            [2] = {name = 'sergeant', label = 'Sergent', salary = 2500, permissions = {'handcuff', 'search', 'impound'}},
            [3] = {name = 'lieutenant', label = 'Lieutenant', salary = 3000, permissions = {'handcuff', 'search', 'impound', 'hire'}},
            [4] = {name = 'chief', label = 'Chef de Police', salary = 4000, permissions = {'handcuff', 'search', 'impound', 'hire', 'fire', 'manage'}}
        },
        interactions = {
            {type = 'duty', pos = vector3(441.79, -981.93, 30.69), label = 'Prise de service'},
            {type = 'cloakroom', pos = vector3(452.6, -992.8, 30.6), label = 'Vestiaire'},
            {type = 'armory', pos = vector3(451.7, -980.1, 30.6), label = 'Armurerie', grade = 1},
            {type = 'garage', pos = vector3(454.6, -1017.4, 28.4), label = 'Garage Police'},
            {type = 'boss', pos = vector3(448.4, -973.2, 30.6), label = 'Bureau Chef', grade = 3}
        },
        vehicles = {
            {model = 'police', label = 'Cruiser', grade = 0},
            {model = 'police2', label = 'Buffalo Police', grade = 1},
            {model = 'policet', label = 'Transport Police', grade = 2}
        },
        society = {
            account = true,
            vault = vector3(461.45, -994.49, 24.91)
        }
    },
    
    ['ambulance'] = {
        name = 'ambulance',
        label = 'EMS',
        category = 'public',
        icon = 'heart-pulse',
        color = '#dc2626',
        -- Configuration EMS complète...
    },
    
    ['mechanic'] = {
        name = 'mechanic', 
        label = 'Benny\'s Garage',
        category = 'private',
        icon = 'wrench',
        color = '#f59e0b',
        -- Configuration mécanicien...
    }
    
    -- + 10 autres templates
}
```

#### Système de Clonage
```lua
-- Cloner un job existant avec modifications
local function CloneJob(sourceJob, newName, modifications)
    local newJob = table.clone(sourceJob)
    newJob.name = newName
    
    -- Appliquer les modifications
    for key, value in pairs(modifications) do
        newJob[key] = value
    end
    
    return newJob
end
```

### 3. Placement Visuel des Interactions

#### Mode Placement
```lua
-- Client-side : Mode placement visuel
local PlacementMode = {
    active = false,
    jobName = nil,
    interactionType = nil,
    currentMarker = nil
}

function StartPlacementMode(jobName, interactionType)
    PlacementMode.active = true
    PlacementMode.jobName = jobName
    PlacementMode.interactionType = interactionType
    
    -- Afficher les instructions
    ShowNotification("Positionnez-vous et appuyez sur [E] pour placer le point d'interaction")
    
    -- Thread pour le placement
    CreateThread(function()
        while PlacementMode.active do
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local heading = GetEntityHeading(playerPed)
            
            -- Afficher marqueur de prévisualisation
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 1.0, 0, 255, 0, 100, false, true, 2, false, false, false, false)
            
            -- Placer avec E
            if IsControlJustPressed(0, 38) then -- E
                ConfirmPlacement(coords, heading)
                break
            end
            
            -- Annuler avec X
            if IsControlJustPressed(0, 73) then -- X
                CancelPlacement()
                break
            end
            
            Wait(0)
        end
    end)
end
```

#### Interface de Configuration
```html
<!-- Interface de configuration des interactions -->
<div class="interaction-config">
    <h3>Configuration de l'Interaction</h3>
    
    <div class="form-group">
        <label>Type d'Interaction</label>
        <select id="interaction-type">
            <option value="duty">Prise de service</option>
            <option value="cloakroom">Vestiaire</option>
            <option value="shop">Boutique</option>
            <option value="garage">Garage</option>
            <option value="armory">Armurerie</option>
            <option value="boss">Menu Patron</option>
            <option value="custom">Personnalisé</option>
        </select>
    </div>
    
    <div class="form-group">
        <label>Label</label>
        <input type="text" id="interaction-label" placeholder="Nom affiché">
    </div>
    
    <div class="form-group">
        <label>Grade minimum</label>
        <select id="interaction-grade">
            <option value="0">Tous</option>
            <option value="1">Grade 1+</option>
            <option value="2">Grade 2+</option>
            <option value="3">Grade 3+</option>
        </select>
    </div>
    
    <button class="btn btn-primary" onclick="startPlacement()">Placer sur la Carte</button>
</div>
```

### 4. Système de Société Avancé

#### Comptes Société
```lua
-- Gestion des comptes société
vCore.JobCreator.Society = {}

function vCore.JobCreator.Society.CreateAccount(jobName)
    local account = {
        job = jobName,
        money = 0,
        transactions = {},
        settings = {
            withdrawLimit = 5000,
            depositTax = 0.05,
            payrollAuto = true
        }
    }
    
    -- Enregistrer en BDD
    MySQL.Async.execute('INSERT INTO society_accounts (job_name, data) VALUES (@job, @data)', {
        ['@job'] = jobName,
        ['@data'] = json.encode(account)
    })
    
    return account
end

function vCore.JobCreator.Society.AddMoney(jobName, amount, reason)
    -- Ajouter argent avec historique
    local account = GetSocietyAccount(jobName)
    account.money = account.money + amount
    
    -- Enregistrer transaction
    table.insert(account.transactions, {
        type = 'deposit',
        amount = amount,
        reason = reason,
        date = os.time(),
        by = 'system'
    })
    
    SaveSocietyAccount(jobName, account)
end
```

### 5. Import/Export de Configurations

#### Format JSON Standard
```json
{
    "vava_job_export": {
        "version": "1.0.0",
        "export_date": "2025-01-12",
        "jobs": [
            {
                "name": "taxi",
                "label": "Taxi Company",
                "category": "transport",
                "grades": [
                    {
                        "grade": 0,
                        "name": "driver",
                        "label": "Chauffeur",
                        "salary": 500,
                        "permissions": ["drive"]
                    }
                ],
                "interactions": [
                    {
                        "type": "duty",
                        "position": {"x": 909.49, "y": -150.64, "z": 74.17},
                        "heading": 238.5,
                        "label": "Prise de service Taxi"
                    }
                ],
                "vehicles": [
                    {
                        "model": "taxi",
                        "label": "Taxi Standard",
                        "min_grade": 0
                    }
                ]
            }
        ]
    }
}
```

## 🚀 Plan de Développement

### Phase 1 : Foundation (Semaines 1-2)
- [ ] Structure de base du module
- [ ] Interface web basique
- [ ] Intégration vAvA_core
- [ ] Templates de base (Police, EMS, Mécano)

### Phase 2 : Interface (Semaines 3-4)
- [ ] Dashboard complet
- [ ] Système de placement visuel
- [ ] Configuration des grades
- [ ] Gestion des permissions

### Phase 3 : Avancé (Semaines 5-6)
- [ ] Système de société
- [ ] Import/Export JSON
- [ ] Templates avancés (5+ jobs)
- [ ] Statistiques et rapports

### Phase 4 : Finition (Semaines 7-8)
- [ ] Tests et optimisation
- [ ] Documentation complète
- [ ] Système de mise à jour
- [ ] Support multi-serveur

## 🎮 Commandes Prévues

### Commandes Admin
```lua
/jobcreator                    -- Ouvrir l'interface
/jobcreator create [template]  -- Créer job depuis template
/jobcreator delete [job]       -- Supprimer job
/jobcreator import [file]      -- Importer configuration
/jobcreator export [job]       -- Exporter job
/jobcreator reload             -- Recharger les jobs
```

### Interface F7 intégrée
- Menu admin avec section "Job Creator"
- Accès rapide aux fonctions principales
- Statut des jobs en temps réel

## 💼 Intégration avec vAvA_core

### Utilisation des APIs Natives
```lua
-- Utilisation des fonctions vAvA_core existantes
vCore.Jobs.SetJob(source, jobName, grade)
vCore.Economy.AddMoney(source, 'cash', amount, 'salary')
vCore.Notify(source, message, type)
```

### Extension du Système
```lua
-- Extension des fonctionnalités jobs
vCore.JobCreator = {}
vCore.JobCreator.Templates = {}
vCore.JobCreator.Society = {}
vCore.JobCreator.Interactions = {}
```

---

*Ce plan garantit une intégration parfaite avec vAvA_core tout en apportant les fonctionnalités avancées d'un "Job Creator Ultimate".*