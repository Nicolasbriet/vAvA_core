# 🎯 vAvA Target

> **Système de ciblage 3D pour vAvA_core**  
> Version 1.0.0 | Compatible FiveM | ESX / QBCore Ready

---

## 📋 Description

vAvA Target est un système de ciblage 3D moderne inspiré d'ox_target, entièrement intégré à vAvA_core. Il permet aux joueurs d'interagir facilement avec des entités (véhicules, objets, PNJ), des modèles spécifiques et des zones définies via une interface graphique intuitive.

### ✨ Fonctionnalités principales

- 🎯 **Ciblage précis** - Raycast depuis la caméra avec détection intelligente
- 🖼️ **3 types de menus** - Radial, Liste, Compact
- 🎨 **Charte graphique vAvA** - Design moderne avec rouge néon #FF1E1E
- 🔒 **Sécurité renforcée** - Anti-cheat, validation serveur, rate limiting
- 🌍 **Multilingue** - Français, Anglais, Espagnol
- ⚡ **Performance optimisée** - Cache, throttling, streaming intelligent
- 🧪 **Testbench compatible** - 15+ tests automatisés
- 📦 **API complète** - Exports pour tous les modules

---

## 📦 Installation

### 1. Prérequis

- vAvA_core 3.0.0 ou supérieur
- MySQL/oxmysql (pour les logs optionnels)

### 2. Installation

```bash
# Copier le module dans votre dossier vAvA_core
cp -r vAvA_target/ /path/to/vAvA_core/modules/target/

# Redémarrer le serveur ou restart vAvA_core
restart vAvA_core
```

### 3. Configuration

Modifier `config/config.lua` selon vos besoins :

```lua
TargetConfig.Enabled = true              -- Activer le module
TargetConfig.DefaultDistance = 2.5       -- Distance par défaut
TargetConfig.UI.MenuType = 'radial'      -- Type de menu: 'radial', 'list', 'compact'
TargetConfig.Security.EnableAntiCheat = true  -- Anti-cheat
```

---

## 🚀 Utilisation

### Pour les joueurs

1. **Visez** une entité/zone avec votre caméra
2. **Le menu apparaît** automatiquement si des interactions sont disponibles
3. **Cliquez** sur une option pour interagir
4. **ESC** pour fermer le menu

### Pour les développeurs

#### Ajouter une interaction sur un modèle

```lua
-- Exemple: ATM
exports['vAvA_target']:AddTargetModel('prop_atm_01', {
    {
        label = 'Utiliser le distributeur',
        icon = 'fa-solid fa-credit-card',
        event = 'vava_banking:openATM',
        server = false,
        distance = 2.0
    }
})
```

#### Ajouter une zone d'interaction

```lua
-- Exemple: Shop
exports['vAvA_target']:AddTargetZone({
    name = 'shop_247_legion',
    type = 'sphere',
    coords = vector3(25.7, -1347.3, 29.5),
    radius = 2.0
}, {
    {
        label = 'Ouvrir la boutique',
        icon = 'fa-solid fa-shopping-cart',
        event = 'vava_shops:open247',
        server = false
    }
})
```

#### Ajouter une interaction sur une entité spécifique

```lua
-- Exemple: Véhicule
local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

exports['vAvA_target']:AddTargetEntity(vehicle, {
    {
        label = 'Crocheter le véhicule',
        icon = 'fa-solid fa-key',
        event = 'vava_carjack:start',
        server = true,
        item = 'lockpick',
        outVehicle = true
    }
})
```

#### Ajouter une interaction sur un os (bone)

```lua
-- Exemple: Coffre de véhicule
exports['vAvA_target']:AddTargetBone({'boot'}, {
    {
        label = 'Ouvrir le coffre',
        icon = 'fa-solid fa-box',
        event = 'vava_inventory:openTrunk',
        server = false,
        distance = 2.0
    }
})
```

---

## 🎮 API

### Exports Client

#### AddTargetModel
```lua
local ids = exports['vAvA_target']:AddTargetModel(models, options)
```
- **models** : string ou table - Modèle(s) à cibler
- **options** : table - Liste des options d'interaction
- **Retourne** : table - IDs des targets créés

#### AddTargetZone
```lua
local id = exports['vAvA_target']:AddTargetZone(zoneData, options)
```
- **zoneData** : table - Données de la zone (name, type, coords, etc.)
- **options** : table - Liste des options d'interaction
- **Retourne** : string - ID de la zone créée

#### AddTargetEntity
```lua
local id = exports['vAvA_target']:AddTargetEntity(entity, options)
```
- **entity** : number - Handle de l'entité
- **options** : table - Liste des options d'interaction
- **Retourne** : string - ID du target créé

#### AddTargetBone
```lua
local id = exports['vAvA_target']:AddTargetBone(bones, options)
```
- **bones** : table - Liste des bones (ex: {'boot', 'bonnet'})
- **options** : table - Liste des options d'interaction
- **Retourne** : string - ID du target créé

#### RemoveTarget
```lua
local success = exports['vAvA_target']:RemoveTarget(id)
```
- **id** : string - ID du target à supprimer
- **Retourne** : boolean - Succès de l'opération

#### RemoveTargetModel
```lua
local success = exports['vAvA_target']:RemoveTargetModel(models)
```
- **models** : string ou table - Modèle(s) à retirer
- **Retourne** : boolean - Succès de l'opération

#### RemoveTargetZone
```lua
local success = exports['vAvA_target']:RemoveTargetZone(zoneName)
```
- **zoneName** : string - Nom de la zone à supprimer
- **Retourne** : boolean - Succès de l'opération

#### DisableTarget
```lua
exports['vAvA_target']:DisableTarget(toggle)
```
- **toggle** : boolean - true = désactiver, false = activer

#### IsTargetActive
```lua
local isActive = exports['vAvA_target']:IsTargetActive()
```
- **Retourne** : boolean - État du système

#### GetNearbyTargets
```lua
local targets = exports['vAvA_target']:GetNearbyTargets(distance)
```
- **distance** : number - Distance de recherche (optionnel)
- **Retourne** : table - {entities = {}, zones = {}}

### Exports Serveur

#### ValidateInteraction
```lua
exports['vAvA_target']:ValidateInteraction(playerId, eventName, entityNetworkId, data)
```

#### LogInteraction
```lua
exports['vAvA_target']:LogInteraction(playerId, eventName, details)
```

---

## ⚙️ Options d'interaction

### Structure complète

```lua
{
    -- Affichage
    label = 'Action',                    -- Texte affiché
    icon = 'fa-solid fa-circle',         -- Icône FontAwesome
    color = '#FF1E1E',                   -- Couleur (optionnel)
    keybind = 'E',                       -- Touche (optionnel, affichage uniquement)
    
    -- Déclenchement
    event = 'event:name',                -- Event à déclencher
    server = false,                      -- true = ServerEvent, false = ClientEvent
    
    -- OU
    export = {
        resource = 'vAvA_module',
        func = 'FunctionName'
    },
    
    -- OU
    command = 'command_name',
    
    -- OU
    action = function(entity, data)
        -- Code direct
    end,
    
    -- Conditions simples
    distance = 2.5,                      -- Distance max
    job = 'police',                      -- ou {'police', 'sheriff'}
    grade = 2,                           -- Grade minimum
    item = 'lockpick',                   -- ou {'item1', 'item2'}
    money = 500,                         -- Argent requis
    groups = {'admin'},                  -- Groupes admin
    
    -- Conditions avancées
    canInteract = function(entity, distance, coords, isPlayer)
        -- Logique custom
        return true  -- ou false
    end,
    
    -- Véhicules
    inVehicle = false,                   -- Doit être dans un véhicule
    outVehicle = true,                   -- Doit être hors véhicule
    vehicles = {'adder', 'zentorno'},    -- Modèles de véhicules requis
    
    -- Statut
    duty = true,                         -- En service requis
    alive = true,                        -- Vivant/mort
    
    -- Système
    cooldown = 5000,                     -- Cooldown en ms
    data = {custom = 'data'},            -- Données custom
    debug = false                        -- Debug pour cette option
}
```

### Exemples

#### Interaction simple
```lua
{
    label = 'Ouvrir',
    icon = 'fa-solid fa-door-open',
    event = 'door:open',
    server = false
}
```

#### Interaction avec conditions
```lua
{
    label = 'Accéder à l\'armurerie',
    icon = 'fa-solid fa-gun',
    event = 'police:openArmory',
    server = true,
    job = 'police',
    grade = 2,
    duty = true
}
```

#### Interaction avec callback
```lua
{
    label = 'Réparer le véhicule',
    icon = 'fa-solid fa-wrench',
    event = 'mechanic:repair',
    server = true,
    job = 'mechanic',
    item = 'repair_kit',
    canInteract = function(entity, distance, coords, isPlayer)
        -- Vérifier que c'est un véhicule endommagé
        if not IsEntityAVehicle(entity) then
            return false
        end
        
        local health = GetVehicleEngineHealth(entity)
        return health < 1000
    end
}
```

---

## 🎨 Types de zones

### Sphere
```lua
{
    name = 'zone_shop',
    type = 'sphere',
    coords = vector3(x, y, z),
    radius = 2.0,
    debug = false
}
```

### Box (Rectangle 3D)
```lua
{
    name = 'zone_garage',
    type = 'box',
    coords = vector3(x, y, z),
    size = vector3(3.0, 3.0, 2.0),
    heading = 0.0,
    debug = false
}
```

### Cylinder (2D + hauteur)
```lua
{
    name = 'zone_lift',
    type = 'cylinder',
    coords = vector3(x, y, z),
    radius = 2.0,
    height = 3.0,
    debug = false
}
```

### Poly (Polygone complexe)
```lua
{
    name = 'zone_custom',
    type = 'poly',
    coords = vector3(x, y, z),  -- Centre
    points = {
        vector2(x1, y1),
        vector2(x2, y2),
        vector2(x3, y3),
        -- ...
    },
    minZ = 28.0,
    maxZ = 32.0,
    debug = false
}
```

---

## 🎭 Types de menus

### Menu Radial (par défaut)
```lua
TargetConfig.UI.MenuType = 'radial'
```
- Options en cercle autour d'un point central
- Idéal pour 3-8 options
- Navigation par direction

### Menu Liste
```lua
TargetConfig.UI.MenuType = 'list'
TargetConfig.UI.Position = 'top-right'  -- top-left, top-right, bottom-left, bottom-right, center
```
- Options en liste verticale
- Support scroll
- Illimité options

### Menu Compact
```lua
TargetConfig.UI.MenuType = 'compact'
```
- Options en ligne horizontale
- Max 5 options
- Ultra rapide

---

## 🔐 Sécurité

### Anti-cheat intégré

Le module inclut plusieurs protections :

- ✅ **Rate limiting** - Max 60 interactions/minute par défaut
- ✅ **Validation distance** - Vérification côté serveur
- ✅ **Validation entité** - Vérification existence réelle
- ✅ **Détection spam** - Système d'avertissements
- ✅ **Sanctions automatiques** - Kick/Ban configurables

### Configuration sécurité

```lua
TargetConfig.Security = {
    EnableAntiCheat = true,
    MaxInteractionsPerMinute = 60,
    ValidateDistance = true,
    ValidateEntity = true,
    LogInteractions = true,
    LogLevel = 'warning',
    AutoKick = true,
    AutoBan = false,
    WarningsBeforeKick = 3
}
```

---

## 🧪 Tests

Le module inclut 15+ tests automatisés via testbench :

```bash
# Ouvrir le testbench
/testbench

# Chercher "vAvA_target" dans la liste
# Lancer les tests

# Types de tests :
- Unit (7 tests) - Validation API, zones, modèles
- Integration (4 tests) - Add/Remove targets, toggle système
- Security (3 tests) - Distance, permissions, entités invalides
- Coherence (4 tests) - Config, zones prédéfinies, exports
```

---

## 📊 Performance

### Optimisations

- **Cache** - Résultats de détection cachés (1000ms par défaut)
- **Throttling** - Update toutes les 500ms (configurable)
- **Streaming** - Uniquement entités proches (50m par défaut)
- **Limite entités** - Max 10 entités traitées par frame
- **Thread sleep** - 0ms par défaut (max perf)

### Mesures

- **Idle** : ~0.00ms
- **Menu ouvert** : ~0.01ms
- **Détection active** : ~0.02ms

---

## 🎨 Charte graphique

Le module respecte entièrement la charte vAvA :

- 🔴 **Rouge néon** : #FF1E1E (principal)
- ⚫ **Noir** : #000000 (backgrounds)
- ⚪ **Blanc** : #FFFFFF (texte)
- 🔴 **Rouge foncé** : #8B0000 (ombres)

**Effets** :
- Glow néon sur éléments importants
- Animations fluides (0.3-0.6s)
- Scanline animée sur headers
- Pulse sur indicateurs

**Typographie** :
- **Titres** : Orbitron, Rajdhani (Bold 700-900)
- **Corps** : Roboto, Inter (Regular 400-500)

---

## 🌍 Multilingue

Langues supportées :
- 🇫🇷 Français (fr.lua)
- 🇬🇧 Anglais (en.lua)
- 🇪🇸 Espagnol (es.lua)

Changer la langue :
```lua
TargetConfig.Language = 'fr'  -- ou 'en', 'es'
```

---

## 🔧 Commandes admin

```bash
/target_debug     # Activer/désactiver le mode debug
/target_stats     # Afficher les statistiques (interactions, warnings)
```

---

## 📝 Events système

### Client

```lua
-- Détection cible
AddEventHandler('vava_target:onTargetEnter', function(entity, options)
    -- Une cible est détectée
end)

-- Perte cible
AddEventHandler('vava_target:onTargetExit', function(entity)
    -- Cible perdue
end)

-- Interaction
AddEventHandler('vava_target:onInteract', function(entity, option)
    -- Une interaction a été déclenchée
end)
```

### Serveur

```lua
-- Validation interaction
RegisterNetEvent('vava_target:validateInteraction')

-- Log interaction
RegisterNetEvent('vava_target:logInteraction')
```

---

## 🛠️ Intégrations

### Modules vAvA compatibles

- ✅ vAvA_inventory - Hook automatique sur useItem
- ✅ vAvA_economy - Support prix dynamiques
- ✅ vAvA_jobs - Vérification duty et permissions
- ✅ vAvA_testbench - Tests automatisés
- ✅ vAvA_garage - Interactions véhicules
- ✅ vAvA_keys - Système clés
- ✅ Tous modules futurs

---

## 🐛 Dépannage

### Le menu ne s'ouvre pas

1. Vérifier que le module est activé : `TargetConfig.Enabled = true`
2. Vérifier que vous visez bien une entité/zone enregistrée
3. Activer le debug : `/target_debug`
4. Vérifier la distance : augmenter `TargetConfig.DefaultDistance`

### Erreurs NUI

1. Vider le cache FiveM (F8 → `resmon` → vérifier vAvA_target)
2. Vérifier les fichiers HTML/CSS/JS sont bien chargés
3. Ouvrir la console navigateur (F8 → `con_miniconChannels script:*`)

### Performance

1. Augmenter `TargetConfig.UpdateRate` (ex: 1000ms)
2. Réduire `TargetConfig.Performance.MaxEntitiesPerFrame`
3. Activer `TargetConfig.Performance.AutoDisableOnLowFPS`

---

## 📜 Licence

MIT License - vAvA Team © 2026

---

## 🤝 Support

- **Discord** : [discord.gg/vava](#)
- **GitHub** : [github.com/vava-team/vAvA_core](#)
- **Forum** : [forum.vava-rp.com](#)

---

## 📅 Changelog

### v1.0.0 (10 Janvier 2026)
- ✨ Première version stable
- 🎯 Système de ciblage complet
- 🎨 3 types de menus (radial, liste, compact)
- 🔒 Anti-cheat et sécurité
- 🌍 Multilingue (FR, EN, ES)
- 🧪 15+ tests testbench
- 📚 Documentation complète

---

**Made with ❤️ by vAvA Team**
