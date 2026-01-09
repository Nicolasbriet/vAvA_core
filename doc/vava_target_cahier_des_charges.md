# 📘 Cahier des Charges - Module `vava_target`

> **Système de ciblage 3D inspiré d'ox_target, conçu pour vAvA_core**  
> **Version:** 1.0.0  
> **Date:** 9 janvier 2026  
> **Auteur:** vAvA Team  
> **Framework:** ESX / QBCore Compatible

---

## 1. 🎯 Objectif du module

Le module `vava_target` a pour objectif de fournir un système de ciblage 3D permettant aux joueurs d'interagir avec :

- **Entités** (peds, véhicules, objets)
- **Modèles** spécifiques
- **Zones** définies (2D/3D)
- **Points d'intérêt** (shops, garages, jobs)
- **Interactions dynamiques** selon contexte

### Objectifs principaux

Le système doit fonctionner comme **ox_target**, mais être :

- ✅ **100% intégré à vAvA_core** - Architecture native
- ✅ **Compatible avec la charte graphique** - Design cohérent
- ✅ **Compatible avec le testbench** - Tests automatisés
- ✅ **Modulaire et extensible** - API simple et puissante
- ✅ **Performant et sécurisé** - Optimisation et validation
- ✅ **Multi-plateforme** - Clavier, souris, manette

---

## 2. 🧩 Intégration avec vAvA_core

### 2.1. Modules concernés

Le système de ciblage doit s'intégrer avec tous les modules existants et futurs :

**Modules principaux :**
- `vava_player` - Interactions joueur
- `vava_inventory` - Utilisation d'items
- `vava_jobs` - Actions spécifiques métiers
- `vava_shops` - Ouverture boutiques
- `vava_vehicles` - Interactions véhicules
- `vava_housing` - Portes, coffres, meubles
- `vava_admin` - Actions administratives
- `vava_status` - États du joueur
- `vava_garage` - Sortir/ranger véhicules
- `vava_keys` - Gestion clés
- `vava_persist` - Objets persistants

**Modules futurs :**
- `vava_ems` - Soins médicaux
- `vava_farming` - Récolte
- `vava_crafting` - Fabrication
- Tous les modules à venir

### 2.2. API commune

Le target doit pouvoir être utilisé par tous les modules via une API simple et cohérente :

```lua
-- Ajouter une interaction sur une entité spécifique
exports['vava_target']:AddTargetEntity(entity, options)

-- Ajouter une interaction sur un/des modèle(s)
exports['vava_target']:AddTargetModel(models, options)

-- Ajouter une zone d'interaction
exports['vava_target']:AddTargetZone(zoneData, options)

-- Ajouter un os de l'entité (ex: coffre, porte)
exports['vava_target']:AddTargetBone(bones, options)

-- Supprimer une interaction
exports['vava_target']:RemoveTarget(id)

-- Supprimer toutes les interactions d'un type
exports['vava_target']:RemoveTargetModel(models)
exports['vava_target']:RemoveTargetZone(zoneName)

-- Activer/désactiver temporairement le système
exports['vava_target']:DisableTarget(toggle)

-- Vérifier si le target est actif
exports['vava_target']:IsTargetActive()

-- Obtenir les entités ciblables à proximité
exports['vava_target']:GetNearbyTargets(distance)
```

### 2.3. Events système

**Events client :**
```lua
-- Déclenché quand une cible est détectée
AddEventHandler('vava_target:onTargetEnter', function(entity, options))

-- Déclenché quand une cible n'est plus visée
AddEventHandler('vava_target:onTargetExit', function(entity))

-- Déclenché lors d'une interaction
AddEventHandler('vava_target:onInteract', function(entity, option))
```

**Events serveur :**
```lua
-- Validation d'une interaction
RegisterNetEvent('vava_target:validateInteraction')

-- Log d'interaction (admin)
RegisterNetEvent('vava_target:logInteraction')
```

---

## 3. 🧱 Architecture du module

### 3.1. Structure des fichiers

```
vava_core/
  modules/
    target/
      fxmanifest.lua
      config/
        config.lua           # Configuration générale
        permissions.lua      # Gestion permissions
        icons.lua           # Mapping icônes
      client/
        main.lua            # Point d'entrée client
        raycast.lua         # Système de détection
        ui.lua              # Gestion interface
        entities.lua        # Gestion entités
        zones.lua           # Gestion zones
        models.lua          # Gestion modèles
        bones.lua           # Gestion os/bones
        distance.lua        # Optimisation distance
      server/
        main.lua            # Point d'entrée serveur
        validation.lua      # Validation interactions
        permissions.lua     # Vérification permissions
        logs.lua            # Système de logs
      shared/
        utils.lua           # Fonctions utilitaires
        config.lua          # Configuration partagée
      html/                 # Interface NUI
        index.html
        css/
          style.css         # Styles (charte graphique)
          animations.css    # Animations
        js/
          app.js            # Logique UI
          interactions.js   # Gestion interactions
        images/
          icons/            # Icônes custom
      locales/
        fr.lua
        en.lua
        es.lua
```

### 3.2. Flux de données

```
[Joueur] → [Raycast] → [Détection entité/zone]
    ↓
[Vérification conditions]
    ↓
[Affichage UI] ← [Charte graphique]
    ↓
[Sélection option]
    ↓
[Validation serveur] (si nécessaire)
    ↓
[Exécution action]
    ↓
[Logs] (optionnel)
```

---

## 4. 🔧 Fonctionnement général

### 4.1. Détection des interactions

Le module doit utiliser un système de détection robuste :

**Raycast précis :**
- Direction caméra joueur
- Distance configurable (défaut: 2.5m)
- Filtrage par type d'entité
- Optimisation performance (throttling)
- Détection os/bones spécifiques

**Distance configurable :**
```lua
Config.DefaultDistance = 2.5    -- Distance par défaut
Config.MaxDistance = 10.0       -- Distance maximale
Config.VehicleDistance = 3.0    -- Distance véhicules
Config.ZoneDistance = 2.0       -- Distance zones
```

**Détection automatique :**
- Entités dans le champ de vision
- Zones géométriques (box, sphere, poly)
- Priorisation (entité > zone)
- Cache des résultats (performances)

**Gestion des zones 2D/3D :**
- Box (rectangle 3D)
- Sphere (rayon 3D)
- Cylinder (2D + hauteur)
- PolyZone (polygone complexe, optionnel)

### 4.2. Ouverture du menu d'interaction

Lorsqu'un joueur vise une entité/zone valide :

**Affichage conditionnel :**
1. **Détection** - Entité/zone trouvée
2. **Vérification permissions** - Job, grade, item
3. **Évaluation conditions** - Callbacks custom
4. **Filtrage options** - Selon contexte
5. **Affichage UI** - Menu avec options valides

**Options d'affichage :**
- Menu radial (circulaire)
- Liste verticale
- Liste horizontale
- Mode compact
- Configurable par module

**Animations :**
- Apparition fluide (fade + scale)
- Transition entre options
- Feedback hover
- Fermeture progressive

### 4.3. Exécution des actions

Chaque option doit pouvoir :

**Déclenchements possibles :**
- ✅ Event client (`TriggerEvent`)
- ✅ Event serveur (`TriggerServerEvent`)
- ✅ Function callback (exécution directe)
- ✅ Command (pour compatibilité)
- ✅ Export d'un autre resource

**Vérifications :**
- Job et grade
- Possession item(s)
- Argent disponible
- Statut joueur (vava_status)
- Distance maintenue
- Entité toujours valide
- Cooldown (anti-spam)

**Feedback utilisateur :**
- Notification succès/échec
- Animation joueur (progressbar)
- Son (optionnel)
- Particules (optionnel)

---

## 5. 🧩 Types de cibles supportées

### 5.1. Entités

**Types d'entités :**
- **Peds** - PNJ, joueurs
- **Véhicules** - Tous types
- **Objets** - Props statiques/dynamiques
- **Pickups** - Items au sol

**Propriétés :**
```lua
exports['vava_target']:AddTargetEntity(entity, {
    {
        label = "Interagir",
        icon = "fa-solid fa-hand",
        event = "mon_script:action",
        canInteract = function(entity, distance, coords)
            return true
        end
    }
})
```

### 5.2. Modèles

**Ciblage par modèle :**
- Hash unique
- Liste de hashs
- Nom de modèle (string)

**Exemples :**
```lua
-- Modèle unique
exports['vava_target']:AddTargetModel('prop_atm_01', options)

-- Multiple modèles
exports['vava_target']:AddTargetModel({
    'prop_atm_01',
    'prop_atm_02',
    'prop_atm_03'
}, options)

-- Par hash
exports['vava_target']:AddTargetModel(GetHashKey('prop_atm_01'), options)
```

**Optimisation :**
- Cache des modèles actifs
- Streaming zone uniquement
- Désactivation automatique si absent

### 5.3. Zones

**Types de zones :**

**Box (rectangle 3D) :**
```lua
exports['vava_target']:AddTargetZone({
    name = "zone_shop_1",
    coords = vector3(x, y, z),
    size = vector3(2.0, 2.0, 2.0),
    rotation = 45.0,
    debug = false
}, options)
```

**Sphere (rayon 3D) :**
```lua
exports['vava_target']:AddTargetZone({
    name = "zone_garage",
    coords = vector3(x, y, z),
    radius = 3.0,
    debug = false
}, options)
```

**Cylinder (2D + hauteur) :**
```lua
exports['vava_target']:AddTargetZone({
    name = "zone_lift",
    coords = vector3(x, y, z),
    radius = 2.0,
    height = 4.0,
    debug = false
}, options)
```

**PolyZone (optionnel) :**
```lua
exports['vava_target']:AddTargetZone({
    name = "zone_custom",
    points = {
        vector2(x1, y1),
        vector2(x2, y2),
        vector2(x3, y3)
    },
    minZ = z1,
    maxZ = z2,
    debug = false
}, options)
```

**Mode debug :**
- Affichage visuel des zones
- Couleurs selon type
- Labels informatifs
- Toggle en jeu (admin)

### 5.4. Points d'intérêt

**Catégories :**
- **Shops** - Magasins, supérettes
- **Garages** - Sortie/rangement véhicules
- **Jobs** - Interactions métiers
- **Services publics** - Banque, hôpital, mairie
- **Interactions RP** - Portes, coffres, distributeurs

**Configuration centralisée :**
```lua
Config.POIs = {
    shops = {
        {coords = vector3(...), label = "24/7", type = "shop"},
        -- ...
    },
    garages = {
        {coords = vector3(...), label = "Garage Central", type = "garage"},
        -- ...
    }
}
```

**Chargement automatique :**
- Génération targets depuis config
- Icônes par type
- Distance adaptée
- Permissions si nécessaire

---

## 6. 🧪 Options d'interaction

### 6.1. Structure complète

```lua
{
    -- Affichage
    label = "Ouvrir la porte",              -- Texte affiché
    icon = "fa-solid fa-door-open",         -- Icône FontAwesome
    
    -- Déclenchement
    event = "vava_housing:openDoor",        -- Event à déclencher
    server = false,                         -- Client event (true = server)
    
    -- Conditions
    distance = 2.0,                         -- Distance maximale
    job = { "police", "sheriff" },          -- Job(s) autorisé(s)
    grade = 2,                              -- Grade minimum
    item = "keycard",                       -- Item requis
    money = 100,                            -- Argent requis
    
    -- Validation avancée
    canInteract = function(entity, distance, coords, isPlayer)
        -- Logique custom
        return true -- ou false
    end,
    
    -- Actions
    action = function(entity)
        -- Code exécuté en plus de l'event
    end,
    
    -- Options supplémentaires
    cooldown = 3000,                        -- Cooldown en ms
    groups = { "admin", "moderator" },      -- Groupes autorisés
    vehicles = { "police", "ambulance" },   -- Véhicule requis
    duty = true,                            -- En service uniquement
    
    -- Données custom
    data = {
        doorId = 1,
        locked = false
    }
}
```

### 6.2. Options supportées

#### Affichage
- `label` (string) - Texte affiché
- `icon` (string) - Icône FontAwesome ou chemin custom
- `color` (string, optionnel) - Couleur spécifique (override charte)

#### Déclenchement
- `event` (string) - Event à déclencher
- `server` (boolean) - Client (false) ou server (true)
- `export` (table) - `{resource = "nom", func = "fonction"}`
- `command` (string) - Commande à exécuter
- `action` (function) - Callback direct

#### Conditions simples
- `distance` (float) - Distance maximale
- `job` (string ou table) - Job(s) requis
- `grade` (number) - Grade minimum
- `item` (string ou table) - Item(s) requis
- `money` (number) - Argent requis
- `groups` (table) - Groupes admin requis

#### Conditions avancées
- `canInteract(entity, distance, coords, isPlayer)` - Callback validation
  - Retourne `boolean`
  - Exécuté côté client (performances)
  - Possibilité validation serveur si nécessaire

#### Véhicules
- `vehicles` (table) - Modèles de véhicules requis
- `inVehicle` (boolean) - Doit être dans un véhicule
- `outVehicle` (boolean) - Doit être hors véhicule

#### Statut
- `duty` (boolean) - En service requis
- `alive` (boolean) - Vivant/mort
- `status` (table) - États vava_status requis

#### Système
- `cooldown` (number) - Cooldown en ms
- `data` (table) - Données custom passées à l'event
- `debug` (boolean) - Mode debug pour cette option

### 6.3. Exemples d'utilisation

**Exemple 1 : Porte simple**
```lua
exports['vava_target']:AddTargetModel('prop_door_01', {
    {
        label = "Ouvrir/Fermer",
        icon = "fa-solid fa-door-open",
        event = "vava_housing:toggleDoor",
        distance = 2.0
    }
})
```

**Exemple 2 : Interaction job**
```lua
exports['vava_target']:AddTargetZone({
    name = "lspd_armory",
    coords = vector3(452.6, -980.0, 30.6),
    size = vector3(2.0, 2.0, 2.0)
}, {
    {
        label = "Ouvrir l'armurerie",
        icon = "fa-solid fa-gun",
        event = "vava_jobs:openArmory",
        job = {"police", "sheriff"},
        grade = 2,
        duty = true
    }
})
```

**Exemple 3 : Action complexe**
```lua
exports['vava_target']:AddTargetEntity(vehicle, {
    {
        label = "Crocheter",
        icon = "fa-solid fa-lock-open",
        event = "vava_vehicles:lockpick",
        item = "lockpick",
        canInteract = function(entity, distance)
            local locked = GetVehicleDoorLockStatus(entity)
            return locked > 1
        end,
        cooldown = 5000
    }
})
```

---

## 7. 🎨 Compatibilité charte graphique

### 7.1. Intégration obligatoire

Le module **DOIT** utiliser la charte graphique officielle :

**Référence :**
```
vava_core/doc/chartegraphique.md
```

**Chargement :**
```lua
local charte = exports.vava_chartegraphique:GetCharte()

-- Utilisation dans l'UI
local colors = {
    primary = charte.colors.primary,
    secondary = charte.colors.secondary,
    background = charte.colors.background,
    text = charte.colors.text
}
```

### 7.2. Éléments concernés

**Couleurs :**
- ✅ Fond du menu
- ✅ Texte (labels, descriptions)
- ✅ Icônes
- ✅ Hover/Focus
- ✅ Bordures
- ✅ Ombres

**Typographies :**
- ✅ Police principale
- ✅ Taille de texte
- ✅ Poids (bold, regular)
- ✅ Interligne
- ✅ Kerning

**Formes :**
- ✅ Arrondis (border-radius)
- ✅ Padding/Margin
- ✅ Espacement entre options
- ✅ Taille des éléments

**Animations :**
- ✅ Durée transitions
- ✅ Easing functions
- ✅ Effets d'apparition
- ✅ Feedback hover

**Icônes :**
- ✅ Taille
- ✅ Couleur
- ✅ Espacement avec texte
- ✅ Style (solid, regular, light)

### 7.3. Interdictions

**⚠️ Aucun style ne doit être codé en dur :**
- ❌ Pas de couleurs hexadécimales fixes dans le CSS
- ❌ Pas de tailles de police en dur
- ❌ Pas d'arrondis fixes
- ❌ Pas d'animations custom non conformes

**✅ À la place :**
- Variables CSS générées depuis la charte
- Classes réutilisables
- Cohérence visuelle totale

### 7.4. Exemple CSS

```css
/* ❌ MAUVAIS */
.target-menu {
    background: #1a1a1a;
    color: #ffffff;
    border-radius: 8px;
}

/* ✅ BON */
.target-menu {
    background: var(--vava-bg-primary);
    color: var(--vava-text-primary);
    border-radius: var(--vava-radius-md);
}
```

---

## 8. 🖥️ Interface utilisateur (UI)

### 8.1. Exigences

**Design :**
- ✅ Menu radial **ou** liste verticale (configurable)
- ✅ Animations fluides (60 FPS minimum)
- ✅ Design minimaliste et moderne
- ✅ Responsive (s'adapte au nombre d'options)
- ✅ Compatible clavier, souris, manette

**Ergonomie :**
- ✅ Lisibilité optimale
- ✅ Feedback visuel immédiat
- ✅ Icônes claires et explicites
- ✅ Ordre logique des options
- ✅ Accessibilité (contraste, taille)

**Performance :**
- ✅ Léger (< 0.01ms)
- ✅ Pas de lag à l'ouverture
- ✅ Réactivité instantanée
- ✅ Pas d'impact FPS

### 8.2. Données envoyées à l'UI

**Format NUI Message :**
```lua
SendNUIMessage({
    action = "open",
    data = {
        title = "Véhicule",        -- Titre optionnel
        options = {
            {
                id = 1,
                label = "Ouvrir coffre",
                icon = "fa-solid fa-box",
                description = "Accéder au coffre du véhicule"
            },
            {
                id = 2,
                label = "Verrouiller",
                icon = "fa-solid fa-lock",
                disabled = false
            }
        },
        position = {x = 0.5, y = 0.5}  -- Position écran (0-1)
    }
})
```

**Actions UI :**
- `open` - Ouvrir le menu
- `close` - Fermer le menu
- `update` - Mise à jour options
- `disable` - Désactiver temporairement
- `enable` - Réactiver

### 8.3. Fermeture automatique

Le menu doit se fermer automatiquement dans les cas suivants :

**Conditions de fermeture :**
- ✅ Distance trop grande (> distance définie)
- ✅ Entité disparue/détruite
- ✅ Joueur en mouvement rapide
- ✅ Action exécutée (selon config)
- ✅ Joueur entre en véhicule
- ✅ Joueur tombe/est blessé
- ✅ Pression touche ESC/Retour
- ✅ Timeout (configurable, défaut: 30s)

**Animations de fermeture :**
- Fade out progressif
- Scale down
- Durée: 200-300ms

### 8.4. Modes d'affichage

**Menu radial :**
```
        [Option 1]
             |
[Option 4] - ● - [Option 2]
             |
        [Option 3]
```
- Navigation circulaire
- 3-8 options idéal
- Sélection par direction

**Liste verticale :**
```
┌─────────────────┐
│ ⚙ Option 1     │
│ 🔧 Option 2     │ ← hover
│ 📦 Option 3     │
└─────────────────┘
```
- Navigation linéaire
- Illimité options
- Scroll si nécessaire

**Liste compacte :**
```
[●] Ouvrir  [●] Fermer  [●] Fouiller
```
- Une ligne
- Max 5 options
- Ultra rapide

---

## 9. 🔐 Sécurité

Le module doit garantir la sécurité à tous les niveaux :

### 9.1. Validation serveur

**Actions sensibles :**
- ❗ Toutes les actions ayant un impact (argent, items, statut)
- ❗ Validation permissions (job, grade, item)
- ❗ Vérification distance réelle
- ❗ Anti-cheat détection

**Flow sécurisé :**
```
[Client] → Interaction
    ↓
[Client] → Vérifications basiques
    ↓
[Server] → TriggerServerEvent
    ↓
[Server] → Validation complète
    ↓
[Server] → Exécution action
    ↓
[Client] ← Feedback
```

### 9.2. Anti-cheat

**Détection exploits :**
- ✅ Interaction hors distance (teleport check)
- ✅ Spam interactions (rate limiting)
- ✅ Entités invalides (vérification existence)
- ✅ Permissions falsifiées (validation serveur)
- ✅ Bypass UI (validation actions)

**Sanctions automatiques :**
- Warning (1ère fois)
- Kick (récidive)
- Ban temporaire (abus)
- Logs détaillés pour staff

### 9.3. Impossibilité d'interagir avec entités non autorisées

**Vérifications :**
- Entité existe réellement
- Entité n'est pas blacklistée
- Joueur a les permissions
- Entité est dans le network scope
- Pas de collisions/blocages

### 9.4. Vérification des permissions

**Hiérarchie de vérification :**
1. **Job** - Métier requis
2. **Grade** - Niveau dans le job
3. **Item** - Possession item(s)
4. **Argent** - Solde suffisant
5. **Statut** - États vava_status
6. **Custom** - Callback canInteract()

**Validation multi-niveau :**
```lua
-- Côté client (pré-filtre)
if not HasPermission(option) then
    return false
end

-- Côté serveur (validation finale)
RegisterNetEvent('vava_target:interact')
AddEventHandler('vava_target:interact', function(data)
    local src = source
    
    -- Re-vérification complète serveur
    if not ValidatePermissions(src, data.option) then
        BanPlayer(src, "Target exploit attempt")
        return
    end
    
    -- Action sécurisée
    ExecuteAction(src, data)
end)
```

### 9.5. Logs optionnels

**Types de logs :**
- Interactions réussies
- Interactions refusées (permissions)
- Tentatives d'exploit
- Erreurs système

**Format logs :**
```lua
{
    timestamp = os.time(),
    player = {id = source, name = "Player", identifier = "license:..."},
    action = "vava_shops:open",
    entity = {type = "model", model = "prop_atm_01"},
    coords = vector3(x, y, z),
    success = true,
    reason = nil -- ou "permission_denied"
}
```

**Stockage :**
- Base de données (optionnel)
- Fichiers logs (serveur)
- Panel admin (consultation)

---

## 10. 🧪 Intégration avec `vava_testbench`

Le module target doit être entièrement testable via le testbench.

### 10.1. Tests unitaires

**Tests de base :**
```lua
-- Ajout de target
TestBench:Test("Target - Add Entity Target", function()
    local entity = CreateObject(...)
    local result = exports['vava_target']:AddTargetEntity(entity, options)
    return result == true
end)

-- Suppression de target
TestBench:Test("Target - Remove Entity Target", function()
    exports['vava_target']:RemoveTarget(id)
    return not TargetExists(id)
end)

-- Détection entité
TestBench:Test("Target - Detect Entity in Range", function()
    local entity = CreateObject(...)
    local detected = IsEntityDetected(entity)
    return detected == true
end)

-- Détection zone
TestBench:Test("Target - Detect Zone in Range", function()
    exports['vava_target']:AddTargetZone(zoneData, options)
    local inZone = IsPlayerInZone("test_zone")
    return inZone == true
end)

-- Exécution d'options
TestBench:Test("Target - Execute Option", function()
    local executed = false
    exports['vava_target']:AddTargetEntity(entity, {
        {
            label = "Test",
            action = function() executed = true end
        }
    })
    InteractWithEntity(entity)
    return executed == true
end)
```

### 10.2. Tests d'intégration

**Tests modules :**
```lua
-- Interaction avec shops
TestBench:Test("Target - Open Shop", function()
    local shopOpened = false
    AddEventHandler('vava_shops:opened', function()
        shopOpened = true
    end)
    InteractWithShop()
    Wait(1000)
    return shopOpened == true
end)

-- Interaction avec jobs
TestBench:Test("Target - Job Action", function()
    SetPlayerJob("police")
    local actionExecuted = ExecuteJobAction()
    return actionExecuted == true
end)

-- Interaction avec inventaire
TestBench:Test("Target - Use Item via Target", function()
    GivePlayerItem("keycard")
    local doorOpened = InteractWithDoor()
    return doorOpened == true
end)

-- Interaction avec véhicules
TestBench:Test("Target - Vehicle Interaction", function()
    local vehicle = SpawnTestVehicle()
    local trunkOpened = OpenTrunkViaTarget(vehicle)
    return trunkOpened == true
end)
```

### 10.3. Tests HUD/UI

**Tests interface :**
```lua
-- Ouverture du menu
TestBench:Test("Target - UI Opens", function()
    TriggerTargetMenu()
    Wait(500)
    return IsTargetMenuVisible()
end)

-- Affichage des options
TestBench:Test("Target - UI Shows Options", function()
    local optionsCount = GetDisplayedOptionsCount()
    return optionsCount > 0
end)

-- Cohérence charte graphique
TestBench:Test("Target - UI Uses Charte", function()
    local uiColors = GetTargetUIColors()
    local charteColors = exports.vava_chartegraphique:GetCharte().colors
    return CompareColors(uiColors, charteColors)
end)

-- Animations fluides
TestBench:Test("Target - UI Animation Performance", function()
    local fps = GetFrameRate()
    TriggerTargetMenu()
    Wait(1000)
    local fpsAfter = GetFrameRate()
    return (fps - fpsAfter) < 5 -- Perte max 5 FPS
end)
```

### 10.4. Tests de charge

**Tests performance :**
```lua
-- 200 entités → stable
TestBench:Test("Target - 200 Entities Performance", function()
    local entities = {}
    for i = 1, 200 do
        local entity = CreateTestEntity()
        exports['vava_target']:AddTargetEntity(entity, options)
        table.insert(entities, entity)
    end
    
    local fps = GetFrameRate()
    Wait(5000)
    local fpsAfter = GetFrameRate()
    
    return (fps - fpsAfter) < 10
end)

-- 100 zones → stable
TestBench:Test("Target - 100 Zones Performance", function()
    for i = 1, 100 do
        exports['vava_target']:AddTargetZone({
            name = "zone_"..i,
            coords = GetRandomCoords(),
            radius = 3.0
        }, options)
    end
    
    return GetFrameRate() > 50
end)

-- 1000 interactions/min → stable
TestBench:Test("Target - 1000 Interactions/min", function()
    local start = GetGameTimer()
    local count = 0
    
    while GetGameTimer() - start < 60000 do
        SimulateInteraction()
        count = count + 1
        if count >= 1000 then break end
        Wait(10)
    end
    
    return count >= 1000 and GetFrameRate() > 50
end)
```

### 10.5. Rapport de tests

**Génération automatique :**
```lua
TestBench:GenerateReport("vava_target", {
    unit_tests = results.unit,
    integration_tests = results.integration,
    ui_tests = results.ui,
    performance_tests = results.performance,
    coverage = "95%",
    status = "PASSED"
})
```

---

## 11. 🌍 Multilingue

### 11.1. Support des locales

Le module doit supporter plusieurs langues via le système de localisation :

**Fichiers de langue :**
```
locales/
  fr.lua    # Français (par défaut)
  en.lua    # Anglais
  es.lua    # Espagnol
```

### 11.2. Structure des fichiers

**Exemple fr.lua :**
```lua
Locale = {
    -- UI
    press_to_interact = "Appuyez sur ~INPUT_CONTEXT~ pour interagir",
    no_options = "Aucune option disponible",
    
    -- Erreurs
    too_far = "Vous êtes trop loin",
    no_permission = "Vous n'avez pas la permission",
    missing_item = "Il vous manque : %s",
    not_enough_money = "Fonds insuffisants",
    
    -- Actions communes
    open = "Ouvrir",
    close = "Fermer",
    interact = "Interagir",
    cancel = "Annuler",
    
    -- Véhicules
    open_trunk = "Ouvrir le coffre",
    open_hood = "Ouvrir le capot",
    open_door = "Ouvrir la porte",
    lock_vehicle = "Verrouiller",
    unlock_vehicle = "Déverrouiller",
    
    -- Divers
    search = "Fouiller",
    take = "Prendre",
    give = "Donner",
    use = "Utiliser"
}
```

### 11.3. Utilisation

```lua
-- Récupération traduction
local label = _U('press_to_interact')

-- Avec paramètres
local label = _U('missing_item', 'Keycard')

-- Dans les options
{
    label = _U('open_trunk'),
    icon = "fa-solid fa-box",
    event = "vava_vehicles:openTrunk"
}
```

### 11.4. Configuration

```lua
Config.Locale = 'fr' -- ou 'en', 'es'
```

---

## 12. 📦 Livrables

### 12.1. Code source complet

**Fichiers livrés :**
- ✅ Code source (client + server + shared)
- ✅ Configuration complète (config.lua)
- ✅ Manifest (fxmanifest.lua)
- ✅ Interface NUI (HTML/CSS/JS)
- ✅ Locales (FR/EN/ES)
- ✅ Assets (icônes, images)

### 12.2. Documentation API

**Documentation technique :**
- ✅ Liste complète des exports
- ✅ Liste des events disponibles
- ✅ Structure des données
- ✅ Exemples d'utilisation
- ✅ Cas d'usage avancés
- ✅ Troubleshooting

**Format :**
```
doc/
  API.md              # Documentation API complète
  EXAMPLES.md         # Exemples pratiques
  INTEGRATION.md      # Guide d'intégration
```

### 12.3. Exemples d'utilisation

**Exemples fournis :**
```lua
-- examples/shops.lua
-- Exemple d'intégration shops

-- examples/jobs.lua
-- Exemple d'interactions jobs

-- examples/vehicles.lua
-- Exemple véhicules avancé

-- examples/housing.lua
-- Exemple portes et coffres

-- examples/custom.lua
-- Exemple personnalisé complexe
```

### 12.4. Intégration testbench

**Tests livrés :**
- ✅ Suite de tests unitaires
- ✅ Tests d'intégration
- ✅ Tests performance
- ✅ Tests UI
- ✅ Configuration testbench
- ✅ Documentation tests

### 12.5. Intégration charte graphique

**Livrables design :**
- ✅ Variables CSS depuis charte
- ✅ Thèmes préconfigurés
- ✅ Mode sombre/clair
- ✅ Customisation guidée

### 12.6. Fichier de configuration

**config.lua complet :**
```lua
Config = {}

-- Général
Config.Framework = 'auto'              -- 'esx', 'qbcore', 'auto'
Config.Locale = 'fr'                    -- 'fr', 'en', 'es'
Config.Debug = false                    -- Mode debug

-- UI
Config.UIMode = 'radial'                -- 'radial', 'vertical', 'horizontal'
Config.UIPosition = 'center'            -- 'center', 'right', 'left'
Config.ShowLabels = true                -- Afficher labels
Config.ShowIcons = true                 -- Afficher icônes

-- Distances
Config.DefaultDistance = 2.5            -- Distance par défaut
Config.MaxDistance = 10.0               -- Distance maximale
Config.VehicleDistance = 3.0            -- Distance véhicules
Config.ZoneDistance = 2.0               -- Distance zones

-- Performance
Config.RefreshRate = 500                -- Rafraîchissement (ms)
Config.MaxEntities = 200                -- Entités max simultanées
Config.MaxZones = 100                   -- Zones max simultanées

-- Sécurité
Config.EnableValidation = true          -- Validation serveur
Config.EnableLogs = true                -- Logs actifs
Config.RateLimit = 10                   -- Interactions max/seconde
Config.EnableAntiCheat = true           -- Anti-cheat actif

-- Debug zones
Config.DebugZones = false               -- Afficher zones en jeu
Config.DebugColor = {r = 0, g = 255, b = 0, a = 100}

-- Charte graphique
Config.UseCharte = true                 -- Utiliser charte graphique
Config.CustomColors = {}                -- Override (si UseCharte = false)
```

---

## 13. 🧱 Philosophie du module

### 13.1. Principes fondamentaux

Le module `vava_target` doit respecter les valeurs suivantes :

**✅ Simplicité**
- API intuitive et claire
- Configuration accessible
- Code lisible et maintenable
- Documentation complète

**✅ Modularité**
- Séparation des responsabilités
- Composants indépendants
- Réutilisabilité du code
- Extensibilité facilitée

**✅ Performance**
- Optimisation constante
- Pas d'impact FPS
- Gestion mémoire efficace
- Cache intelligent

**✅ Cohérence**
- Respect charte graphique
- Conventions de code unifiées
- Expérience utilisateur homogène
- Intégration harmonieuse

**✅ Sécurité**
- Validation systématique
- Anti-cheat intégré
- Logs complets
- Permissions robustes

**✅ Extensibilité**
- API ouverte
- Hooks et callbacks
- Système de plugins (futur)
- Compatibilité à long terme

**✅ Durabilité**
- Code pérenne
- Maintenance facilitée
- Rétro-compatibilité
- Évolutions prévues

**✅ Compatible testbench**
- Tests automatisés
- Couverture complète
- CI/CD intégré
- Qualité garantie

**✅ Compatible charte graphique**
- Design cohérent
- Expérience uniforme
- Identité visuelle respectée
- Personnalisation encadrée

### 13.2. Engagement qualité

**Standards de développement :**
- ✅ Code review obligatoire
- ✅ Tests avant merge
- ✅ Documentation à jour
- ✅ Pas de TODO en production
- ✅ Optimisation continue
- ✅ Support communautaire

**Maintenance :**
- ✅ Correctifs rapides (bugs critiques)
- ✅ Mises à jour régulières (features)
- ✅ Écoute feedback communauté
- ✅ Roadmap publique
- ✅ Changelog détaillé

---

## 14. 🚀 Roadmap & Évolutions

### Phase 1 - Core (v1.0) ✅
- Système de ciblage basique
- Entités, modèles, zones
- UI simple (liste)
- Intégration vAvA_core
- Tests unitaires

### Phase 2 - Features (v1.5) 🔄
- Menu radial
- Animations avancées
- Optimisations performance
- Charte graphique intégrée
- Tests complets

### Phase 3 - Advanced (v2.0) 🔮
- PolyZones support
- Système de bones avancé
- UI customisable par module
- Thèmes multiples
- API étendue

### Phase 4 - Intelligence (v2.5) 🔮
- Suggestions automatiques
- Apprentissage contexte
- Prédiction interactions
- Optimisation adaptative

---

## ✅ Conclusion

Le module `vava_target` est un composant central de vAvA_core qui doit offrir une expérience d'interaction fluide, intuitive et performante. 

### Objectifs clés
- ⚡ Performance optimale
- 🎨 Design cohérent
- 🔐 Sécurité maximale
- 🧪 Qualité testée
- 📦 Modularité complète
- 🔧 Maintenance facilitée

### Impact attendu
- Amélioration expérience utilisateur
- Simplification développement modules
- Cohérence visuelle globale
- Performance serveur optimisée
- Sécurité renforcée

---

**Document créé le :** 9 janvier 2026  
**Dernière mise à jour :** 9 janvier 2026  
**Version :** 1.0.0  
**Statut :** ✅ Validé  

---

*© 2026 vAvA Team - Tous droits réservés*
