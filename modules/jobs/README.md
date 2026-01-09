# Module Jobs - vAvA Core

## 📋 Description

Système de gestion de jobs avancé pour vAvA Core avec support complet pour:
- EMS (Ambulance)
- Police
- Mechanic (avec customs)
- Création dynamique de jobs personnalisés
- Points d'interaction (farm, craft, process, sell)
- Intégration avec le module jobshop

## 🎯 Fonctionnalités

### Jobs Pré-configurés

#### 🚑 EMS (Ambulance)
- 5 grades: Recrue → Directeur
- Permissions: revive, heal, pharmacy
- Véhicules de service
- Tenues médicales
- Système de réanimation

#### 👮 Police
- 5 grades: Cadet → Commissaire
- Permissions: cuff, search, fine, jail, impound
- Véhicules de police
- Tenues police
- Système d'amendes et prison

#### 🔧 Mechanic
- 5 grades: Apprenti → Patron
- Permissions: repair, impound, customs
- Réparation véhicules
- Customisation véhicules
- Système de fourrière

### Job Creator

Créez des jobs personnalisés avec:
- Nom, label, icône, description
- Grades multiples avec salaires
- Permissions personnalisées
- Compte société
- Système whitelist

### Points d'Interaction

#### Types disponibles:
- **duty**: Prise/fin de service
- **wardrobe**: Vestiaire avec tenues
- **vehicle**: Garage véhicules de service
- **storage**: Coffre de job
- **boss**: Menu patron (gestion employés, finances)
- **shop**: Boutique (intégration jobshop)
- **farm**: Récolte d'items
- **craft**: Fabrication d'items
- **process**: Traitement d'items
- **sell**: Vente d'items
- **custom**: Interaction personnalisée

## 📦 Installation

### 1. Base de données

Exécutez le script SQL:
```sql
source database/sql/jobs_system.sql
```

### 2. Configuration

Éditez `modules/jobs/config.lua` selon vos besoins:
- Distance d'interaction
- Markers
- Animations
- Notifications
- Salaires automatiques

### 3. Démarrage

Ajoutez au `server.cfg`:
```cfg
ensure vAvA_core
ensure jobs
```

## 🎮 Utilisation

### Pour les joueurs

#### Prise de service
- Allez au point "duty"
- Appuyez sur `E`
- Vous êtes maintenant en service

#### Vestiaire
- Allez au vestiaire
- Choisissez une tenue
- Equipez-la

#### Véhicules
- Allez au garage
- Choisissez un véhicule
- Il spawn automatiquement

#### Farm
- Allez au point de farm
- Appuyez sur `E`
- Attendez la progression
- Recevez l'item

#### Craft
- Allez au point de craft
- Choisissez une recette
- Vérifiez les ingrédients
- Craftez

#### Vente
- Allez au point de vente
- Choisissez l'item à vendre
- Vendez tout votre stock

### Pour les patrons

#### Menu Boss
Accessible aux grades élevés:
- Recruter des joueurs
- Promouvoir/rétrograder
- Licencier
- Gérer les finances société
- Retirer/déposer de l'argent

### Pour les admins

#### Créer un job

```lua
TriggerServerEvent('vCore:jobs:createJob', {
    name = 'baker',
    label = 'Boulangerie',
    icon = 'bread-slice',
    description = 'Préparez du pain et des pâtisseries',
    type = 'custom',
    default_salary = 30,
    whitelisted = false,
    society_account = true,
    grades = {
        {
            grade = 0,
            name = 'apprentice',
            label = 'Apprenti',
            salary = 20,
            permissions = {}
        },
        {
            grade = 1,
            name = 'baker',
            label = 'Boulanger',
            salary = 40,
            permissions = {'craft'}
        },
        {
            grade = 2,
            name = 'boss',
            label = 'Patron',
            salary = 60,
            permissions = {'craft', 'hire', 'fire', 'manage', 'withdraw'}
        }
    }
})
```

#### Créer un point d'interaction

```lua
TriggerServerEvent('vCore:jobs:createInteraction', {
    job_name = 'baker',
    type = 'farm',
    name = 'flour_harvest',
    label = 'Récolter de la farine',
    position = {x = 100.0, y = 200.0, z = 30.0},
    heading = 180.0,
    min_grade = 0,
    config = {
        time = 5000,
        animation = {
            dict = 'amb@world_human_gardener_plant@male@base',
            anim = 'base',
            flag = 1
        }
    }
})
```

#### Ajouter un item farmable

```lua
TriggerServerEvent('vCore:jobs:addFarmItem', interactionId, {
    item_name = 'wheat',
    amount_min = 1,
    amount_max = 3,
    chance = 100,
    required_item = nil,
    remove_required = false,
    time = 5000
})
```

#### Ajouter une recette de craft

```lua
TriggerServerEvent('vCore:jobs:addCraftRecipe', interactionId, {
    name = 'bread',
    label = 'Pain',
    result_item = 'bread',
    result_amount = 1,
    ingredients = {
        wheat = 3,
        water = 1
    },
    time = 10000,
    required_grade = 1
})
```

#### Ajouter un item vendable

```lua
TriggerServerEvent('vCore:jobs:addSellItem', interactionId, {
    item_name = 'bread',
    price = 5,
    label = 'Pain'
})
```

## 🔧 API / Exports

### Client

```lua
-- Récupérer le job actuel
local job = exports['jobs']:GetCurrentJob()

-- Récupérer la config du job
local config = exports['jobs']:GetJobConfig()

-- Vérifier si en service
local onDuty = exports['jobs']:IsOnDuty()

-- Récupérer les interactions
local interactions = exports['jobs']:GetInteractions()
```

### Server

```lua
-- Récupérer un job
local job = exports['jobs']:GetJob('ambulance')

-- Récupérer tous les jobs
local allJobs = exports['jobs']:GetAllJobs()

-- Changer le job d'un joueur
exports['jobs']:SetPlayerJob(source, 'ambulance', 2)

-- Mettre en service
exports['jobs']:SetPlayerDuty(source, true)

-- Vérifier une permission
local hasPerm = exports['jobs']:HasJobPermission(source, 'revive')

-- Argent société
local money = exports['jobs']:GetSocietyAccount('ambulance')
exports['jobs']:AddSocietyMoney('ambulance', 1000)
exports['jobs']:RemoveSocietyMoney('ambulance', 500)

-- Logs
exports['jobs']:LogJobAction('ambulance', identifier, 'action', 'description')
```

## 🔗 Intégration avec JobShop

Le système est conçu pour s'intégrer avec le module jobshop existant:

1. Les points d'interaction de type "shop" peuvent ouvrir un jobshop
2. Les items farmés/craftés peuvent être vendus dans le jobshop
3. Les permissions de job s'appliquent au jobshop

## 🎨 Personnalisation

### Markers
Modifiez `JobsConfig.DefaultMarkers` dans [config.lua](config.lua)

### Animations
Modifiez `JobsConfig.DefaultAnimations` dans [config.lua](config.lua)

### Notifications
Modifiez `JobsConfig.Notifications` dans [config.lua](config.lua)

## 📝 Structure de la base de données

### Tables principales:
- `jobs_config`: Configuration des jobs
- `job_grades`: Grades par job
- `job_interactions`: Points d'interaction
- `job_vehicles`: Véhicules de job
- `job_outfits`: Tenues de job
- `job_farm_items`: Items farmables
- `job_craft_recipes`: Recettes de craft
- `job_sell_items`: Items vendables
- `job_accounts`: Comptes société
- `job_logs`: Logs d'actions

## 🐛 Dépannage

### Les interactions ne s'affichent pas
- Vérifiez que vous avez le bon job
- Vérifiez le grade minimum requis
- Vérifiez que l'interaction est activée en DB

### Les véhicules ne spawn pas
- Vérifiez que le modèle existe
- Vérifiez qu'il y a de l'espace
- Vérifiez les permissions de grade

### Le craft ne fonctionne pas
- Vérifiez que vous avez tous les ingrédients
- Vérifiez le grade requis
- Vérifiez que la recette est activée

## 🤝 Support

Pour toute question ou problème:
1. Vérifiez ce README
2. Consultez les logs serveur
3. Activez `JobsConfig.Debug = true`

## 📄 Licence

© vAvA Core - Tous droits réservés
