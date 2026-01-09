# 💰 vAvA_economy - Système Économique Auto-Adaptatif

> **Version:** 1.0.0  
> **Framework:** vAvA_core  
> **Auteur:** vAvA

## 📋 Description

Module d'économie **centralisé**, **automatique** et **auto-adaptatif** pour vAvA_core. Contrôlez toute l'économie de votre serveur depuis un seul fichier de configuration et laissez le système s'ajuster automatiquement selon l'activité des joueurs.

---

## ✨ Fonctionnalités Principales

### 🎚️ Économie Centralisée
- **Un seul fichier** contrôle tous les prix, salaires, taxes
- **Multiplicateur global** pour changer toute l'économie en 1 ligne
- **Profils prédéfinis** (Hardcore, Normal, Riche, Ultra-Riche)

### 🤖 Auto-Adaptation
- Ajustement automatique des prix selon l'offre et la demande
- Salaires adaptés au nombre de joueurs par job
- Inflation calculée selon l'activité économique globale
- Recalcul automatique toutes les 24h (configurable)

### 📊 Système de Rareté
- Items classés de 1 à 10 (commun → légendaire)
- Prix calculés automatiquement selon la rareté
- Catégories: nourriture, armes, vêtements, outils, etc.

### 💼 Gestion des Jobs
- Salaires automatiques avec bonus par job
- Jobs essentiels (Police, EMS, Mechanic) avec multiplicateur x1.5
- Ajustement selon la popularité du job

### 🛍️ Multiplicateurs de Shops
- Chaque shop a son propre multiplicateur
- Zone pauvre → prix réduits
- Zone riche/luxe → prix majorés

### 💳 Système de Taxes
- 6 types de taxes configurables
- Application automatique sur achats/ventes/salaires
- Logging complet

### 📈 Interface Admin (NUI)
- Dashboard moderne avec graphiques en temps réel
- Vue d'ensemble de l'économie
- Gestion items/jobs/taxes
- Historique des changements
- Recalcul manuel et réinitialisation

---

## 🚀 Installation

### 1. Copier le module
```bash
modules/economy/ → vAvA_core/modules/economy/
```

### 2. Exécuter le SQL
```sql
-- Importer le fichier SQL
database/sql/economy_system.sql
```

Cela créera 7 tables:
- `economy_state` - État global
- `economy_items` - Prix dynamiques
- `economy_jobs` - Salaires dynamiques  
- `economy_logs` - Historique
- `economy_transactions` - Statistiques
- `economy_shops` - Multiplicateurs shops
- `economy_taxes` - Configuration taxes

### 3. Ajouter dans server.cfg
```cfg
ensure vAvA_economy
```

### 4. Configurer
Modifier `modules/economy/config/economy.lua`:

```lua
-- Changer le multiplicateur global (1.0 = normal)
EconomyConfig.baseMultiplier = 1.0

-- Ou utiliser un profil prédéfini
-- 0.5 = hardcore, 1.0 = normal, 2.0 = riche, 5.0 = ultra-riche
```

---

## 🎮 Utilisation

### Pour les Admins

#### Ouvrir le Dashboard
- Commande: `/economy`
- Ou touche: **F10**

#### Actions Disponibles
- 📊 Visualiser l'état de l'économie
- 🔄 Recalculer manuellement
- ✏️ Modifier prix/salaires/taxes
- 🔙 Réinitialiser aux valeurs par défaut

### Pour les Développeurs

#### Obtenir le prix d'un item
```lua
-- Server ou Client
local price = exports['economy']:GetPrice('bread')
local priceInShop = exports['economy']:GetPrice('bread', 'supermarket')
local price10 = exports['economy']:GetPrice('bread', 'supermarket', 10)
```

#### Obtenir un salaire
```lua
-- Server
local salary = exports['economy']:GetSalary('police', 2) -- Grade 2
```

#### Appliquer une taxe
```lua
-- Server
local finalAmount, taxAmount = exports['economy']:ApplyTax('achat', 100)
-- finalAmount = 105 (avec taxe de 5%)
-- taxAmount = 5
```

#### Enregistrer une transaction
```lua
-- Server
exports['economy']:RegisterTransaction('bread', 'buy', 1, 10, 'supermarket', playerIdentifier)
```

#### Obtenir l'état de l'économie
```lua
-- Server ou Client
local state = exports['economy']:GetEconomyState()
-- {inflation = 1.0, baseMultiplier = 1.0, lastUpdate = timestamp}
```

---

## ⚙️ Configuration Avancée

### Ajouter un nouvel item
```lua
-- Dans config/economy.lua
EconomyConfig.itemsRarity = {
    mon_item = {
        rarity = 5,              -- 1-10
        category = 'tool',
        basePrice = 150
    }
}
```

### Ajouter un nouveau job
```lua
EconomyConfig.jobs = {
    mon_job = {
        baseSalary = 120,
        bonus = 1.2,
        essential = false
    }
}
```

### Ajouter un shop
```lua
EconomyConfig.shops = {
    mon_shop = 1.5  -- Prix x1.5
}
```

### Modifier les taxes
```lua
EconomyConfig.taxes = {
    achat = 0.10,     -- 10%
    vente = 0.05      -- 5%
}
```

---

## 🧮 Règles Économiques

### Règle Fondamentale
**1 unité = 1 minute de travail d'un job basique**

### Formule Prix Final
```
prix_final = basePrice × rarity × baseMultiplier × shopMultiplier × inflation × taxes
```

### Formule Salaire Final
```
salaire_final = baseSalary × bonus × baseMultiplier × inflation × gradeBonus
```

### Auto-Ajustement Prix
```
nouveau_prix = prix_actuel × (1 + (taux_achat - taux_vente) × 0.05)
```

---

## 📊 API Complète

### Exports Server

| Export | Description | Paramètres |
|--------|-------------|------------|
| `GetPrice` | Prix d'un item | item, shop?, quantity? |
| `GetSalary` | Salaire d'un job | job, grade? |
| `GetShopMultiplier` | Multiplicateur shop | shopName |
| `ApplyTax` | Appliquer taxe | taxType, amount |
| `RegisterTransaction` | Logger transaction | item, type, qty, price, shop, player |
| `RecalculateEconomy` | Recalculer | adminId, reason |
| `GetEconomyState` | État global | - |
| `GetSellPrice` | Prix de vente | item, shop?, quantity? |

### Callbacks

| Callback | Description |
|----------|-------------|
| `vAvA_economy:getState` | État global |
| `vAvA_economy:getItemInfo` | Info item |
| `vAvA_economy:getJobInfo` | Info job |
| `vAvA_economy:getAllItems` | Tous les items |
| `vAvA_economy:getAllJobs` | Tous les jobs |
| `vAvA_economy:getLogs` | Historique |

---

## 🔐 Sécurité

- ✅ Toutes les modifications loggées
- ✅ Vérifications serveur obligatoires
- ✅ Limites min/max sur prix et salaires
- ✅ Cooldown sur recalculs manuels (1h)
- ✅ Permissions admin requises
- ✅ Confirmation pour actions critiques

---

## 🛠️ Intégration Modules Existants

Le module economy s'intègre automatiquement avec:
- ✅ `vAvA_inventory` - Prix items
- ✅ `vAvA_jobs` - Salaires
- ✅ `vAvA_concess` - Prix véhicules  
- ✅ `vAvA_garage` - Frais fourrière
- ✅ `vAvA_jobshop` - Prix shops métiers

Voir le guide d'intégration: `INTEGRATION.md`

---

## 📝 Support & Documentation

- 📖 Cahier des charges complet: `vava_economy_cahier_des_charges.md`
- 🔧 Guide intégration: `INTEGRATION.md`
- 💡 Exemples: `EXAMPLES.lua`

---

## 🏆 Avantages

✨ **Économie vivante** qui évolue naturellement  
🎯 **Équilibre automatique** sans intervention manuelle  
🚀 **Gain de temps** énorme pour les admins  
🔒 **Impossible à casser** grâce aux limites et validations  
📈 **Transparence totale** avec logs et dashboard  
🎨 **Modulaire** et compatible avec tous modules vAvA  

---

## 📌 Version

**v1.0.0** - Janvier 2026  
- Release initiale  
- Système complet fonctionnel  
- Dashboard admin NUI  
- Auto-ajustement implémenté  

---

**© 2026 vAvA - Tous droits réservés**
