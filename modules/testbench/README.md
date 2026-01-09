# 🧪 vAvA TESTBENCH

<div align="center">

![vAvA Logo](https://via.placeholder.com/150x150/FF1E1E/FFFFFF?text=vAvA)

**Système de Test Automatisé et Adaptatif**

[![Version](https://img.shields.io/badge/version-1.0.0-FF1E1E.svg?style=flat-square)](https://github.com)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-00D9FF.svg?style=flat-square)](https://fivem.net)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat-square)](LICENSE)

</div>

---

## 📋 Table des Matières

- [Vue d'ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Utilisation](#-utilisation)
- [Types de Tests](#-types-de-tests)
- [API & Exemples](#-api--exemples)
- [Configuration](#-configuration)
- [Architecture](#-architecture)
- [Charte Graphique](#-charte-graphique)
- [Contribution](#-contribution)

---

## 🎯 Vue d'ensemble

**vAvA Testbench** est un module de test automatisé, adaptatif et intelligent conçu spécifiquement pour les projets vAvA Core sur FiveM. Il offre une suite complète d'outils pour tester, valider et garantir la qualité de votre code.

### ⚡ Caractéristiques Principales

- 🔍 **Auto-détection** - Scan automatique des modules et ressources
- 🧪 **Multi-types** - Unit, Integration, Stress, Security tests
- 🎨 **Interface moderne** - UI avec thème vAvA (rouge néon, cyber futuriste)
- 📊 **Logs temps réel** - Suivi en direct des tests
- 🔒 **Sandbox** - Isolation complète pour tests destructifs
- 📈 **Analytics** - Statistiques et rapports détaillés
- 🚀 **Performance** - Tests de charge et benchmarking
- 🛡️ **Sécurité** - Validation anti-cheat et permissions
- 💾 **Export** - Résultats JSON pour CI/CD

---

## ✨ Fonctionnalités

### 🔧 Détection Automatique

```lua
-- Le testbench scan automatiquement tous les modules vAvA
-- Détecte les fichiers, dépendances, exports, et features
Scanner.ScanAll() -- Analyse complète de l'écosystème
```

### 🎯 Tests Adaptatifs

Le système recommande automatiquement des tests basés sur :
- Type de module (core, economy, gameplay, etc.)
- Dépendances détectées (DB, Economy, Inventory, etc.)
- Complexité du code
- Features utilisées (UI, Commands, Exports, etc.)

### 📊 Dashboard Temps Réel

Interface NUI moderne avec :
- Modules détectés
- Tests en cours d'exécution
- Résultats en temps réel
- Logs détaillés avec filtres
- Graphiques de performance
- Export JSON

---

## 📦 Installation

### 1. Prérequis

- FiveM Server
- vAvA_core (v3.0.0+)
- oxmysql (optionnel)

### 2. Installation

```bash
# Cloner dans votre dossier resources
cd resources
git clone https://github.com/vAvA/testbench.git modules/testbench

# Ou télécharger le ZIP et extraire dans modules/testbench
```

### 3. Configuration

Éditez `config/config.lua` selon vos besoins :

```lua
TestbenchConfig = {
    Enabled = true,
    DevMode = true,
    AdminOnly = true,
    AutoStart = {
        Enabled = true,
        CriticalOnly = true,
        Delay = 5000
    }
}
```

### 4. Démarrer le module

```lua
-- Ajoutez dans server.cfg
ensure vAvA_core
ensure vAvA_testbench
```

---

## 🎮 Utilisation

### Commande Principale

```
/testbench
```

Ouvre l'interface de test (admin uniquement par défaut).

### Interface Utilisateur

#### 📱 Navigation

- **Dashboard** - Vue d'ensemble des tests et statistiques
- **Modules** - Liste des modules détectés avec infos
- **Tests** - Tous les tests disponibles avec filtres
- **Logs** - Historique détaillé avec recherche
- **Scénarios** - Tests complexes prédéfinis

#### 🎛️ Contrôles

| Bouton | Action |
|--------|--------|
| 🔍 **SCAN** | Scanner les modules et détecter les tests |
| ▶️ **RUN ALL** | Exécuter tous les tests |
| ⏹️ **STOP** | Arrêter les tests en cours |
| 💾 **EXPORT** | Exporter les résultats en JSON |
| ✕ **CLOSE** | Fermer l'interface |

---

## 🧪 Types de Tests

### 1. Tests Unitaires (`unit`)

Tests de fonctions individuelles en isolation.

```lua
{
    name = 'test_player_creation',
    type = 'unit',
    run = function(ctx)
        local player = CreatePlayer('test123')
        ctx.assert.isNotNil(player, 'Player doit être créé')
        ctx.assert.equals(player.id, 'test123', 'ID doit correspondre')
    end
}
```

### 2. Tests d'Intégration (`integration`)

Tests d'interactions entre modules.

```lua
{
    name = 'test_economy_inventory_link',
    type = 'integration',
    run = function(ctx)
        -- Acheter un item
        local success = BuyItem(player, 'bread', 1, 50)
        
        -- Vérifier l'argent ET l'inventaire
        ctx.assert.isTrue(success, 'Achat doit réussir')
        ctx.assert.equals(GetMoney(player), 950, 'Argent déduit')
        ctx.assert.equals(GetItem(player, 'bread'), 1, 'Item ajouté')
    end
}
```

### 3. Tests de Charge (`stress`)

Tests de performance sous stress.

```lua
{
    name = 'test_1000_concurrent_players',
    type = 'stress',
    run = function(ctx)
        local startTime = os.clock()
        
        -- Simuler 1000 joueurs
        for i = 1, 1000 do
            ProcessPlayer('player_' .. i)
        end
        
        local duration = (os.clock() - startTime) * 1000
        ctx.assert.isTrue(duration < 5000, 'Doit traiter en moins de 5s')
    end
}
```

### 4. Tests de Sécurité (`security`)

Validation anti-cheat et permissions.

```lua
{
    name = 'test_admin_commands_protection',
    type = 'security',
    run = function(ctx)
        local normalPlayer = { permissions = {} }
        
        -- Essayer d'utiliser une commande admin
        local allowed = HasPermission(normalPlayer, 'admin.ban')
        
        ctx.assert.isFalse(allowed, 'Joueur normal ne doit pas avoir accès')
    end
}
```

### 5. Tests de Cohérence (`coherence`)

Validation de la logique et des données.

```lua
{
    name = 'test_database_consistency',
    type = 'coherence',
    run = function(ctx)
        -- Vérifier qu'il n'y a pas d'argent négatif dans la DB
        local players = MySQL.query.await('SELECT money FROM users WHERE money < 0')
        
        ctx.assert.equals(#players, 0, 'Aucun joueur ne doit avoir d\'argent négatif')
    end
}
```

---

## 💻 API & Exemples

### Assertions Disponibles

```lua
-- Booléens
ctx.assert.isTrue(value, message)
ctx.assert.isFalse(value, message)

-- Égalité
ctx.assert.equals(actual, expected, message)
ctx.assert.notEquals(actual, expected, message)

-- Nil
ctx.assert.isNil(value, message)
ctx.assert.isNotNil(value, message)

-- Types
ctx.assert.isType(value, expectedType, message)

-- Erreurs
ctx.assert.throws(function, message)
```

### Utilitaires de Test

```lua
-- Mock de fonction
local mockFn, mock = ctx.utils.mock(function(a, b)
    return a + b
end)

-- Vérifier les appels
mock.wasCalled() -- true/false
mock.wasCalledWith(2, 3) -- true/false

-- Génération de données aléatoires
local str = ctx.utils.randomString(10) -- 'aB3Xz9KpQw'
local num = ctx.utils.randomInt(1, 100) -- 42

-- Délai
ctx.utils.wait(1000) -- Attend 1 seconde
```

### Structure de Test Complète

```lua
local MyTests = {
    name = 'my_module_tests',
    type = 'unit',
    description = 'Tests pour mon module',
    
    -- Exécuté une fois avant tous les tests
    setup = function(ctx)
        ctx.data.testData = { value = 123 }
        print('Setup des tests')
    end,
    
    -- Test 1
    test1 = {
        name = 'first_test',
        run = function(ctx)
            ctx.assert.equals(ctx.data.testData.value, 123)
        end
    },
    
    -- Test 2
    test2 = {
        name = 'second_test',
        run = function(ctx)
            ctx.assert.isTrue(true)
        end
    },
    
    -- Exécuté une fois après tous les tests
    teardown = function(ctx)
        ctx.data = {}
        print('Nettoyage après tests')
    end
}

return MyTests
```

---

## ⚙️ Configuration

### Fichier `config/config.lua`

```lua
TestbenchConfig = {
    -- Général
    Enabled = true,
    DevMode = true,
    
    -- Sécurité
    AdminOnly = true,
    AllowedACE = 'vava.admin',
    
    -- Auto-start
    AutoStart = {
        Enabled = true,
        CriticalOnly = true,
        Delay = 5000
    },
    
    -- Sandbox (isolation)
    Sandbox = {
        Enabled = true,
        FakeDatabase = true,
        FakeEconomy = true,
        FakeInventory = true
    },
    
    -- Performance
    Performance = {
        MaxTestDuration = 30000,
        ParallelTests = 5,
        CacheResults = true
    },
    
    -- Export
    Export = {
        Enabled = true,
        Format = 'json',
        AutoSave = true,
        SavePath = 'modules/testbench/logs/'
    }
}
```

---

## 🏗️ Architecture

```
modules/testbench/
├── fxmanifest.lua          # Manifest FiveM
├── config/
│   └── config.lua          # Configuration
├── client/
│   └── main.lua            # Client script
├── server/
│   ├── main.lua            # Server principal
│   ├── scanner.lua         # Auto-détection modules
│   ├── runner.lua          # Moteur d'exécution tests
│   └── logger.lua          # Système de logs
├── ui/
│   ├── index.html          # Interface NUI
│   ├── css/
│   │   └── style.css       # Styles (thème vAvA)
│   └── js/
│       └── app.js          # Logique UI
└── tests/
    ├── auto/               # Tests automatiques
    ├── unit/               # Tests unitaires
    ├── integration/        # Tests d'intégration
    ├── stress/             # Tests de charge
    └── security/           # Tests de sécurité
```

---

## 🎨 Charte Graphique

### Couleurs

| Couleur | Hex | Usage |
|---------|-----|-------|
| Rouge Néon | `#FF1E1E` | Primary, accents, glow |
| Noir | `#000000` | Background principal |
| Rouge Foncé | `#8B0000` | Shadows, gradients |
| Blanc | `#FFFFFF` | Text principal |
| Gris | `#CCCCCC` | Text secondaire |

### Typographie

- **Titres** : Orbitron, Rajdhani (Bold, 700-900)
- **Corps** : Roboto, Inter (Regular, 400-500)
- **Code** : Courier New (Monospace)

### Effets

- **Neon Glow** : `0 0 10px #FF1E1E, 0 0 20px #FF1E1E, 0 0 30px #FF1E1E`
- **Borders** : 1-2px solid avec effet gradient
- **Animations** : Pulse, scanline, fade (0.3-0.6s ease)

---

## 🚀 Exports

### Côté Server

```lua
-- Scanner les modules
exports['vAvA_testbench']:ScanModules()

-- Exécuter un test
exports['vAvA_testbench']:RunTest(testData)

-- Obtenir les résultats
local results = exports['vAvA_testbench']:GetResults()
```

### Côté Client

```lua
-- Obtenir les utilitaires de test
local utils = exports['vAvA_testbench']:GetTestUtils()

-- Obtenir les coordonnées du joueur
local coords = utils.GetPlayerCoords()

-- Simuler une action
utils.SimulateAction('buy_item')
```

---

## 🤝 Contribution

Contributions bienvenues ! Pour contribuer :

1. Fork le projet
2. Créez une branche (`git checkout -b feature/AmazingFeature`)
3. Commit vos changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers la branche (`git push origin feature/AmazingFeature`)
5. Ouvrez une Pull Request

---

## 📝 License

MIT License - Voir [LICENSE](LICENSE) pour plus de détails.

---

## 👥 Auteurs

- **vAvA Team** - *Initial work* - [@vAvA](https://github.com/vAvA)

---

## 🙏 Remerciements

- FiveM Community
- oxmysql contributors
- Tous les testeurs et contributeurs

---

<div align="center">

**⚡ Propulsé par vAvA Core ⚡**

[Documentation](https://docs.vava.gg) • [Support](https://discord.gg/vava) • [Website](https://vava.gg)

</div>
