# 📘 vAvA Status - Système de Faim & Soif

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-red)
![Status](https://img.shields.io/badge/status-production-green)
![Framework](https://img.shields.io/badge/framework-vAvA_core-red)

**Système complet de gestion de la faim et de la soif**

[Installation](#-installation) • [Configuration](#-configuration) • [API](#-api) • [Intégration](#-intégration)

</div>

---

## 📋 Table des matières

- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Utilisation](#-utilisation)
- [API](#-api)
- [Intégration](#-intégration)
- [HUD](#-hud)
- [Tests](#-tests)
- [Dépannage](#-dépannage)

---

## ✨ Fonctionnalités

### 🎯 Core
- ✅ Système de faim (0-100)
- ✅ Système de soif (0-100)
- ✅ Décrémentation automatique configurable
- ✅ Sauvegarde automatique en base de données
- ✅ 50+ items consommables pré-configurés
- ✅ Effets progressifs selon les niveaux

### 🎨 Interface
- ✅ HUD moderne avec charte graphique vAvA
- ✅ Barres animées avec effet néon rouge (#FF1E1E)
- ✅ Pourcentages en temps réel
- ✅ 4 positions disponibles (coins de l'écran)
- ✅ Masquage automatique optionnel
- ✅ Animations smooth et effets visuels

### 🎮 Gameplay
- ✅ 5 niveaux de statut (normal → collapse)
- ✅ Effets visuels progressifs (flou, ralentissement)
- ✅ Réduction de stamina selon le niveau
- ✅ Messages RP aléatoires
- ✅ Animations de consommation (manger/boire)
- ✅ Perte de vie progressive en danger
- ✅ K.O. si faim/soif à 0

### 🔧 Technique
- ✅ API complète pour les autres modules
- ✅ Intégration économie (prix dynamiques)
- ✅ Système anti-cheat intégré
- ✅ Logging complet et configurable
- ✅ Support multilingue (FR, EN, ES)
- ✅ Compatible testbench
- ✅ Mode test rapide

---

## 📦 Installation

### 1. Prérequis

- **vAvA_core** (framework principal)
- **oxmysql** (base de données)
- **FiveM Server** build 2802+

### 2. Installation

Le module est déjà intégré dans vAvA_core :

```
vAvA_core/
└── modules/
    └── status/
```

### 3. Configuration serveur

Ajouter dans `server.cfg` :

```cfg
# vAvA Status Module
ensure oxmysql
ensure vAvA_core

# Le module status se charge automatiquement avec vAvA_core
```

### 4. Base de données

La table est créée automatiquement au démarrage :

```sql
CREATE TABLE IF NOT EXISTS player_status (
    identifier VARCHAR(50) PRIMARY KEY,
    hunger INT DEFAULT 100,
    thirst INT DEFAULT 100,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)
```

---

## ⚙️ Configuration

Fichier : [`modules/status/config/config.lua`](config/config.lua)

### Décrémentation

```lua
StatusConfig.UpdateInterval = 5 -- Minutes entre chaque update

StatusConfig.Decrementation = {
    hunger = { min = 1, max = 3 },  -- Perte aléatoire par interval
    thirst = { min = 2, max = 4 }   -- La soif descend plus vite
}
```

### Items consommables

```lua
StatusConfig.ConsumableItems = {
    bread = { hunger = 15, thirst = 0, animation = 'eat' },
    water = { hunger = 0, thirst = 25, animation = 'drink' },
    burger = { hunger = 45, thirst = 0, animation = 'eat' },
    -- ... 50+ items
}
```

### Niveaux et effets

| Niveau | Faim/Soif | Effets |
|--------|-----------|--------|
| **Normal** | 70-100 | Aucun effet |
| **Léger** | 40-70 | Stamina -15% |
| **Avertissement** | 20-40 | Stamina -40%, Léger flou |
| **Danger** | 0-20 | Stamina -70%, Flou important, -1 HP/5s |
| **Collapse** | 0 | K.O., Mort |

### HUD

```lua
StatusConfig.HUD = {
    enabled = true,
    position = 'bottom-right',  -- bottom-right, bottom-left, top-right, top-left
    showPercentage = true,
    hideWhenFull = false,
    animations = true,
    glowEffect = true
}
```

---

## 🎮 Utilisation

### Pour les joueurs

- **Automatique** : La faim et la soif descendent automatiquement
- **Consommer** : Utiliser des items depuis l'inventaire
- **HUD** : Visible en permanence (sauf si `hideWhenFull = true`)

### Commandes debug

```
/debugstatus - Afficher les valeurs actuelles (console)
```

---

## 🔌 API

### Exports Serveur

```lua
-- Obtenir les valeurs
local hunger = exports['vAvA_status']:GetHunger(playerId)
local thirst = exports['vAvA_status']:GetThirst(playerId)

-- Définir les valeurs (0-100)
exports['vAvA_status']:SetHunger(playerId, 50)
exports['vAvA_status']:SetThirst(playerId, 75)

-- Ajouter/Retirer
exports['vAvA_status']:AddHunger(playerId, 30)  -- +30 faim
exports['vAvA_status']:AddThirst(playerId, -10) -- -10 soif

-- Consommer un item
local success = exports['vAvA_status']:ConsumeItem(playerId, 'burger')
```

### Exports Client

```lua
-- Obtenir les valeurs locales
local hunger = exports['vAvA_status']:GetCurrentHunger()
local thirst = exports['vAvA_status']:GetCurrentThirst()
```

### Events

#### Server → Client

```lua
-- Mettre à jour le statut
TriggerClientEvent('vAvA_status:updateStatus', playerId, hunger, thirst)

-- Jouer une animation
TriggerClientEvent('vAvA_status:playAnimation', playerId, 'eat') -- ou 'drink'
```

#### Client → Server

```lua
-- Consommer un item
TriggerServerEvent('vAvA_status:consumeItem', 'burger')
```

---

## 🔗 Intégration

### HUD Central

**Important :** Le module status n'a **pas** de HUD séparé. Il utilise le HUD central de vAvA_core.

Les barres de faim/soif sont affichées dans [client/hud.lua](../../client/hud.lua) du core.

```lua
-- Le module status envoie les données via event
TriggerEvent('vAvA_hud:updateStatus', {
    hunger = hunger,
    thirst = thirst
})

-- Le HUD du core les reçoit et affiche
RegisterNetEvent('vAvA_hud:updateStatus')
```

**Position :** En bas à gauche avec santé, armure, etc.  
**Design :** Charte graphique vAvA (rouge néon #FF1E1E)

### Module Inventory

Dans votre module inventory, lors de l'utilisation d'un item :

```lua
-- server/main.lua
RegisterNetEvent('inventory:useItem')
AddEventHandler('inventory:useItem', function(itemName)
    local src = source
    
    -- Vérifier si l'item est consommable
    if exports['vAvA_status']:ConsumeItem(src, itemName) then
        -- Item consommé avec succès
        -- Retirer l'item de l'inventaire
        RemoveItem(src, itemName, 1)
    end
end)
```

### Module Economy

Le module utilise automatiquement `vava_economy` pour les prix si activé :

```lua
StatusConfig.EconomyIntegration = true
StatusConfig.UseEconomyPrices = true
```

### Module Testbench

Tests automatiques disponibles :

```lua
-- Exemple de test
{
    name = "Status Decay Test",
    type = "unit",
    run = function(ctx)
        local initialHunger = exports['vAvA_status']:GetHunger(1)
        
        -- Attendre la décrémentation
        ctx.utils.wait(5 * 60 * 1000)
        
        local newHunger = exports['vAvA_status']:GetHunger(1)
        ctx.assert.isTrue(newHunger < initialHunger, "La faim devrait avoir diminué")
    end
}
```

---

## 🎨 HUD

### HUD Centralisé

Le module status **n'a pas de HUD séparé**. Il utilise le HUD central de vAvA_core.

**Fichier :** [vAvA_core/client/hud.lua](../../client/hud.lua)  
**Interface :** [vAvA_core/html/index.html](../../html/index.html)  

### Barres affichées

| Barre | Couleur | Position | Icône |
|-------|---------|----------|-------|
| Santé | Rouge | Bas gauche | ❤️ |
| Armure | Bleu | Bas gauche | 🛡️ |
| **Faim** | **Rouge néon** | **Bas gauche** | **🍔** |
| **Soif** | **Bleu clair** | **Bas gauche** | **💧** |

### Personnalisation

Pour personnaliser l'affichage, modifier :

**Position/Layout :**  
[vAvA_core/html/css/style.css](../../html/css/style.css)

```css
.hud-container {
    position: fixed;
    bottom: 20px;
    left: 20px;  /* Modifier ici */
}
```

**Couleurs :**
```css
.status-fill.hunger {
    background: #FF1E1E;  /* Modifier ici */
}

.status-fill.thirst {
    background: #1E90FF;  /* Modifier ici */
}
```

**Logique :**  
[vAvA_core/html/js/app.js](../../html/js/app.js)

```javascript
// Fonction updateStatus()
if (data.hunger !== undefined) {
    // Personnaliser ici
}
```

### Désactiver

Pour désactiver l'affichage faim/soif :

```lua
-- modules/status/config/config.lua
StatusConfig.HUD.enabled = false
```

### Migration depuis l'ancien HUD

Si vous aviez l'ancien HUD séparé, consultez [MIGRATION_HUD.md](MIGRATION_HUD.md).

---

## 🧪 Tests

### Mode Test

Activer le mode test pour décrémentation rapide :

```lua
StatusConfig.TestMode = true
StatusConfig.TestConfig = {
    fastDecay = true,
    decayMultiplier = 10,  -- 10x plus rapide
    skipAnimations = true,
    instantEffects = true
}
```

### Tests Testbench

Lancer les tests via testbench :

```
/testbench
```

Tests disponibles :
- ✅ Décrémentation automatique
- ✅ Consommation d'items
- ✅ Limites (0-100)
- ✅ Anti-cheat
- ✅ Sauvegarde/Chargement
- ✅ Intégration HUD

---

## 🔧 Dépannage

### Le HUD ne s'affiche pas

1. Vérifier que `StatusConfig.HUD.enabled = true`
2. Vérifier la console (F8) pour les erreurs NUI
3. Tester avec `/debugstatus`

### La faim/soif ne descend pas

1. Vérifier `StatusConfig.Enabled = true`
2. Vérifier `StatusConfig.UpdateInterval`
3. Consulter les logs serveur

### Les items ne restaurent pas

1. Vérifier que l'item est dans `StatusConfig.ConsumableItems`
2. Vérifier l'intégration avec l'inventaire
3. Vérifier les logs : `StatusConfig.Logging.logConsumption = true`

### Erreurs de base de données

1. Vérifier que `oxmysql` est démarré
2. Vérifier la connexion MySQL dans `vAvA_core`
3. Créer manuellement la table si nécessaire

---

## 📝 Changelog

### Version 1.0.0 (9 Janvier 2026)
- ✅ Première version stable
- ✅ Système complet faim/soif
- ✅ HUD avec charte graphique vAvA
- ✅ 50+ items consommables
- ✅ API complète
- ✅ Anti-cheat intégré
- ✅ Support multilingue
- ✅ Integration testbench

---

## 👥 Support

Pour toute question ou problème :

1. Consulter la [documentation complète](../doc/vava_status_cahier_des_charges.md)
2. Vérifier les [issues GitHub](#)
3. Contacter l'équipe vAvA

---

## 📜 Licence

© 2026 vAvA Development Team - Tous droits réservés

Ce module fait partie intégrante de **vAvA_core** et ne peut être redistribué séparément.

---

<div align="center">

**vAvACore – Le cœur du développement**

🔴 Made with ❤️ and Neon 🔴

</div>
