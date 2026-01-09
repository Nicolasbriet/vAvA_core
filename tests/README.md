# 🧪 Tests vAvA_core - Documentation

---

## 📋 Vue d'ensemble

Ce dossier contient tous les tests automatisés pour le framework vAvA_core et ses modules. Les tests sont organisés par type et par module pour faciliter la maintenance et l'exécution.

---

## 📁 Structure des tests

```
tests/
├── unit/                    # Tests unitaires (fonctions individuelles)
│   ├── core_tests.lua      # Tests du core (6 tests)
│   ├── economy_tests.lua   # Tests de l'économie (8 tests)
│   ├── inventory_tests.lua # Tests de l'inventaire (9 tests)
│   ├── jobs_tests.lua      # Tests des jobs (8 tests)
│   └── vehicles_tests.lua  # Tests des véhicules (6 tests)
│
└── integration/             # Tests d'intégration (cycles complets)
    └── full_cycle_tests.lua # Tests de cycles complets (5 tests)
```

**Total : 42 tests créés**

---

## 🎯 Types de tests

### 1. Tests Critiques (`critical`)
Tests essentiels qui vérifient les fonctionnalités de base :
- Connexion base de données
- Tables SQL existantes
- Initialisation des modules
- Sécurité

### 2. Tests Unitaires (`unit`)
Tests de fonctions individuelles en isolation :
- Calculs de prix
- Calculs de salaires
- Ajout/suppression d'items
- Gestion des permissions

### 3. Tests d'Intégration (`integration`)
Tests d'interactions entre plusieurs modules :
- Cycle complet d'un joueur
- Transaction économique complète
- Paiement de salaire
- Achat de véhicule

### 4. Tests de Sécurité (`security`)
Tests de validation de sécurité :
- Système de permissions
- Protection anti-cheat
- Validation des inputs

---

## 🚀 Lancer les tests

### Depuis la console serveur

```bash
# Scanner les modules
testbench_scan

# Voir les tests disponibles
testbench_list

# Lancer tous les tests
testbench_run

# Lancer uniquement les tests critiques
testbench_critical

# Lancer un test spécifique
testbench_run_test test_database_connection
```

### Depuis le jeu (admin)

```
/testbench
```

Puis utiliser l'interface graphique pour :
- Scanner les modules
- Voir les tests disponibles
- Lancer les tests
- Voir les logs en temps réel

---

## 📊 Tests disponibles par module

### vAvA_core (6 tests + 5 intégration)

**Tests unitaires :**
- ✅ `test_core_initialization` - Vérifie l'initialisation du core
- ✅ `test_database_connection` - Vérifie la connexion DB
- ✅ `test_player_table_exists` - Vérifie les tables joueurs
- ✅ `test_callback_system` - Vérifie les callbacks
- ✅ `test_player_cache` - Vérifie le cache
- ✅ `test_permissions_system` - Vérifie les permissions

**Tests d'intégration :**
- ✅ `test_player_full_cycle` - Cycle complet joueur
- ✅ `test_economy_full_transaction` - Transaction économique
- ✅ `test_job_salary_payment` - Paiement salaire
- ✅ `test_vehicle_purchase_cycle` - Achat véhicule
- ✅ `test_inventory_shop_integration` - Inventory + shop

---

### Economy (8 tests)

- ✅ `test_economy_initialization` - Initialisation
- ✅ `test_price_calculation` - Calcul des prix
- ✅ `test_salary_calculation` - Calcul des salaires
- ✅ `test_tax_application` - Application des taxes
- ✅ `test_economy_state` - État économique
- ✅ `test_quantity_discount` - Remises quantité
- ✅ `test_transaction_logging` - Logs transactions
- ✅ `test_auto_adjustment` - Auto-ajustement

---

### Inventory (9 tests)

- ✅ `test_inventory_initialization` - Initialisation
- ✅ `test_add_item` - Ajout d'item
- ✅ `test_remove_item` - Suppression d'item
- ✅ `test_item_count` - Comptage items
- ✅ `test_weight_limit` - Limite de poids
- ✅ `test_item_metadata` - Métadonnées
- ✅ `test_hotbar` - Système hotbar
- ✅ `test_item_usage` - Utilisation items
- ✅ `test_inventory_slots` - Système de slots

---

### Jobs (8 tests)

- ✅ `test_jobs_initialization` - Initialisation
- ✅ `test_get_jobs` - Récupération jobs
- ✅ `test_default_jobs_exist` - Jobs par défaut
- ✅ `test_job_grades` - Système de grades
- ✅ `test_set_job` - Attribution job
- ✅ `test_get_player_job` - Récupération job joueur
- ✅ `test_job_salary` - Système salaire
- ✅ `test_job_permissions` - Permissions par job

---

### Vehicles (6 tests)

- ✅ `test_vehicle_spawn` - Spawn véhicule
- ✅ `test_vehicle_ownership` - Propriété véhicule
- ✅ `test_vehicle_keys` - Système de clés
- ✅ `test_vehicle_garage` - Système garage
- ✅ `test_vehicle_persistence` - Persistance
- ✅ `test_vehicle_damage` - Système de dégâts

---

## ✍️ Créer vos propres tests

### Structure d'un test

```lua
return {
    {
        name = 'test_my_feature',           -- Nom unique du test
        type = 'unit',                      -- Type: unit, integration, critical, security
        description = 'Description du test', -- Description claire
        run = function(ctx)                  -- Fonction d'exécution
            -- Votre code de test ici
            
            -- Assertions disponibles
            ctx.assert.isTrue(value, 'message')
            ctx.assert.equals(actual, expected, 'message')
            ctx.assert.isNotNil(value, 'message')
            ctx.assert.isType(value, 'table', 'message')
            
            -- Utilitaires
            ctx.utils.wait(1000)  -- Attendre 1 seconde
        end
    }
}
```

### Assertions disponibles

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
ctx.assert.isType(value, 'string', message)
ctx.assert.isType(value, 'number', message)
ctx.assert.isType(value, 'table', message)
ctx.assert.isType(value, 'function', message)

-- Erreurs
ctx.assert.throws(function() ... end, message)
```

### Exemple complet

```lua
return {
    {
        name = 'test_player_money',
        type = 'unit',
        description = 'Vérifie le système d\'argent',
        run = function(ctx)
            local testPlayer = 'test_' .. os.time()
            
            -- Donner de l'argent
            local success = exports['vAvA_core']:AddMoney(testPlayer, 'cash', 1000)
            ctx.assert.isTrue(success, 'L\'argent doit être ajouté')
            
            -- Vérifier le montant
            local money = exports['vAvA_core']:GetMoney(testPlayer, 'cash')
            ctx.assert.equals(money, 1000, 'Le montant doit être 1000')
            
            -- Retirer de l'argent
            local removed = exports['vAvA_core']:RemoveMoney(testPlayer, 'cash', 500)
            ctx.assert.isTrue(removed, 'L\'argent doit être retiré')
            
            -- Vérifier le nouveau montant
            local newMoney = exports['vAvA_core']:GetMoney(testPlayer, 'cash')
            ctx.assert.equals(newMoney, 500, 'Le montant doit être 500')
        end
    }
}
```

---

## 📝 Bonnes pratiques

### ✅ À faire

- ✅ Nommer les tests clairement : `test_nom_descriptif`
- ✅ Une assertion par aspect testé
- ✅ Messages d'erreur clairs et utiles
- ✅ Tests indépendants (pas de dépendances entre tests)
- ✅ Nettoyer après chaque test (teardown)
- ✅ Utiliser des données de test uniques (timestamp)

### ❌ À éviter

- ❌ Tests trop longs (> 30 secondes)
- ❌ Tests dépendants d'autres tests
- ❌ Tests sans assertions
- ❌ Messages d'erreur vagues
- ❌ Données de test hardcodées (risque de collision)
- ❌ Tests destructifs sans sandbox

---

## 🔧 Dépannage

### Test échoue : "Module not found"

**Cause :** Le module n'est pas démarré

**Solution :**
```lua
ensure vAvA_core
ensure economy
ensure inventory
```

### Test échoue : "Database connection failed"

**Cause :** MySQL n'est pas configuré

**Solution :**
- Vérifier `server.cfg` pour MySQL
- Vérifier que les tables sont créées
- Tester avec `testbench_run_test test_database_connection`

### Test timeout

**Cause :** Le test prend trop de temps (> 30s par défaut)

**Solution :**
- Optimiser le code du test
- Ou augmenter le timeout dans `config.lua` :
```lua
TestbenchConfig.Performance.MaxTestDuration = 60000 -- 60 secondes
```

---

## 📖 Ressources

- **Documentation testbench** : `modules/testbench/README.md`
- **Commandes console** : `modules/testbench/CONSOLE_COMMANDS.md`
- **Guide de création** : `modules/testbench/CREATION_COMPLETE.md`

---

*Dernière mise à jour : 9 Janvier 2026*  
*Version : 3.1.0*  
*Tests créés : 42 tests*
