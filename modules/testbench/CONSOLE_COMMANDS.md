# 🔴 Commandes Console - vAvA_testbench

---

## 📋 Vue d'ensemble

Ce document liste toutes les commandes console disponibles pour le module **vAvA_testbench**. Ces commandes permettent de lancer et gérer les tests **sans avoir besoin de se connecter au serveur**, idéal pour les environnements de développement où vous n'avez pas accès au jeu.

---

## ⚡ Commandes disponibles

### 1️⃣ `testbench_help`

Affiche l'aide avec la liste de toutes les commandes disponibles.

**Usage :**
```
testbench_help
```

**Exemple de sortie :**
```
[TESTBENCH] ========================================
[TESTBENCH] COMMANDES DISPONIBLES
[TESTBENCH] ========================================
testbench_scan           - Scanner les modules disponibles
testbench_list           - Lister tous les tests
testbench_run            - Lancer tous les tests
testbench_run_test <nom> - Lancer un test spécifique
testbench_critical       - Lancer uniquement les tests critiques
testbench_logs [count]   - Voir les derniers logs (défaut: 10)
testbench_help           - Afficher cette aide
[TESTBENCH] ========================================
```

---

### 2️⃣ `testbench_scan`

Scanne tous les modules vAvA disponibles et détecte automatiquement leurs tests.

**Usage :**
```
testbench_scan
```

**Exemple de sortie :**
```
[TESTBENCH] Scan des modules en cours...
[TESTBENCH] 8 modules détectés :
  ✓ vAvA_core - Tests: 12
  ✓ vAvA_economy - Tests: 8
  ✓ vAvA_inventory - Tests: 15
  ✓ vAvA_jobs - Tests: 6
  ✓ vAvA_concess - Tests: 4
  ✓ vAvA_garage - Tests: 5
  ✗ vAvA_chat - Tests: 0
  ✗ vAvA_keys - Tests: 0
```

**Légende :**
- ✓ (vert) = Module avec tests disponibles
- ✗ (rouge) = Module sans tests

---

### 3️⃣ `testbench_list`

Liste tous les tests disponibles dans tous les modules.

**Usage :**
```
testbench_list
```

**Exemple de sortie :**
```
[TESTBENCH] ========================================
[TESTBENCH] LISTE DES TESTS DISPONIBLES
[TESTBENCH] ========================================
[TESTBENCH] Module: vAvA_core (12 tests)
  - test_player_creation [unit]
  - test_character_save [integration]
  - test_database_connection [critical]
  - test_economy_integration [integration]
  ...
[TESTBENCH] Module: vAvA_economy (8 tests)
  - test_price_calculation [unit]
  - test_auto_adjust [integration]
  - test_inflation_calc [unit]
  ...
[TESTBENCH] ========================================
[TESTBENCH] Total: 50 tests disponibles
```

**Types de tests :**
- `critical` (rouge) = Tests critiques (sécurité, BDD)
- `unit` (vert) = Tests unitaires
- `integration` (vert) = Tests d'intégration
- `stress` (vert) = Tests de charge
- `coherence` (vert) = Tests de cohérence

---

### 4️⃣ `testbench_run`

Lance **tous les tests** de tous les modules détectés.

**Usage :**
```
testbench_run
```

**Exemple de sortie :**
```
[TESTBENCH] Lancement de tous les tests...
[TESTBENCH] Running test: test_player_creation
[TESTBENCH] Running test: test_character_save
[TESTBENCH] Running test: test_database_connection
...
[TESTBENCH] ========================================
[TESTBENCH] RÉSULTATS DES TESTS
[TESTBENCH] ========================================
[TESTBENCH] Réussis  : 45
[TESTBENCH] Échoués  : 3
[TESTBENCH] Warnings : 2
[TESTBENCH] ========================================
[TESTBENCH] ✗ Certains tests ont échoué !
```

**Note :** Cette commande peut prendre plusieurs minutes selon le nombre de tests.

---

### 5️⃣ `testbench_run_test <nom_du_test>`

Lance **un test spécifique** par son nom.

**Usage :**
```
testbench_run_test <nom_du_test>
```

**Exemples :**
```
testbench_run_test test_player_creation
testbench_run_test test_economy_price_calculation
testbench_run_test test_database_connection
```

**Exemple de sortie (succès) :**
```
[TESTBENCH] Lancement du test: test_player_creation
[TESTBENCH] Test test_player_creation : RÉUSSI
[TESTBENCH] Message: All 5 assertions passed
```

**Exemple de sortie (échec) :**
```
[TESTBENCH] Lancement du test: test_database_connection
[TESTBENCH] Test test_database_connection : ÉCHOUÉ
[TESTBENCH] Message: Database connection timeout
```

---

### 6️⃣ `testbench_critical`

Lance **uniquement les tests critiques** (sécurité, base de données, intégrité).

**Usage :**
```
testbench_critical
```

**Exemple de sortie :**
```
[TESTBENCH] Lancement des tests critiques...
[TESTBENCH] Running critical test: test_database_connection
[TESTBENCH] Running critical test: test_sql_injection_protection
[TESTBENCH] Running critical test: test_permissions_security
[TESTBENCH] Tests critiques terminés
```

**Note :** Utile pour une validation rapide avant un déploiement.

---

### 7️⃣ `testbench_logs [count]`

Affiche les **derniers logs** du testbench.

**Usage :**
```
testbench_logs          # Affiche les 10 derniers logs (défaut)
testbench_logs 20       # Affiche les 20 derniers logs
testbench_logs 50       # Affiche les 50 derniers logs
```

**Exemple de sortie :**
```
[TESTBENCH] ========================================
[TESTBENCH] DERNIERS LOGS (10)
[TESTBENCH] ========================================
[INFO] Scanning modules...
[INFO] 8 modules detected
[INFO] Running all tests...
[INFO] Test test_player_creation passed
[ERROR] Test test_database_connection failed
[WARNING] Test test_economy_inflation timeout
[INFO] All tests completed
[TESTBENCH] ========================================
```

**Niveaux de logs :**
- `INFO` (vert) = Informations
- `WARNING` (jaune) = Avertissements
- `ERROR` (rouge) = Erreurs
- `CRITICAL` (rouge) = Critique
- `DEBUG` (cyan) = Débogage

---

## 🔧 Workflow recommandé

Voici un workflow typique pour utiliser les commandes console :

### 1. **Premier lancement** (scan des modules)
```
testbench_scan
```

### 2. **Voir les tests disponibles**
```
testbench_list
```

### 3. **Lancer les tests critiques** (validation rapide)
```
testbench_critical
```

### 4. **Lancer tous les tests** (validation complète)
```
testbench_run
```

### 5. **Si un test échoue, le relancer individuellement**
```
testbench_run_test nom_du_test_echoue
```

### 6. **Voir les logs pour déboguer**
```
testbench_logs 20
```

---

## 📊 Intégration CI/CD

Ces commandes console sont parfaites pour l'intégration dans un pipeline CI/CD :

### Exemple script CI/CD (bash) :
```bash
#!/bin/bash

# Démarrer le serveur FiveM en arrière-plan
./FXServer.exe +exec server.cfg &
SERVER_PID=$!

# Attendre que le serveur démarre
sleep 30

# Lancer les tests via RCON ou console
echo "testbench_scan" | nc localhost 30120
echo "testbench_run" | nc localhost 30120

# Récupérer les résultats
# (parser les logs pour extraire passed/failed)

# Arrêter le serveur
kill $SERVER_PID

# Exit code basé sur les résultats
exit $TEST_EXIT_CODE
```

---

## 🚨 Notes importantes

### ⚠️ Restrictions

- 🔒 **Console uniquement** : Ces commandes ne fonctionnent **que depuis la console serveur**, pas en jeu
- 🔑 **Aucune permission requise** : Les commandes console n'ont pas besoin de permissions ACE
- 🔄 **Un test à la fois** : Vous ne pouvez pas lancer plusieurs tests simultanément

### ⚡ Performance

- Les tests peuvent prendre du temps (30s max par test par défaut)
- Utilisez `testbench_critical` pour une validation rapide (~1 minute)
- `testbench_run` peut prendre 5-15 minutes selon le nombre de tests

### 💾 Logs

- Les logs sont stockés en mémoire (max 1000 logs)
- Utilisez `testbench_logs` pour voir l'historique
- Les logs sont automatiquement supprimés après 1000 entrées (rotation)

---

## 🆘 Dépannage

### ❌ Commande non trouvée
```
[ERROR] Unknown command: testbench_scan
```

**Solution :** Vérifiez que le module `vAvA_testbench` est bien démarré :
```
ensure vAvA_testbench
```

### ❌ Tests déjà en cours
```
[TESTBENCH] Des tests sont déjà en cours d'exécution
```

**Solution :** Attendez que les tests en cours se terminent, ou redémarrez le module :
```
restart vAvA_testbench
```

### ❌ Aucun test trouvé
```
[TESTBENCH] 0 modules détectés
```

**Solution :** Vérifiez que vous avez bien créé des tests dans le dossier `tests/` de vos modules, puis relancez :
```
testbench_scan
```

### ❌ Test introuvable
```
[TESTBENCH] Test introuvable: nom_du_test
```

**Solution :** Listez les tests disponibles pour voir le nom exact :
```
testbench_list
```

---

## 📝 Exemples avancés

### Lancer uniquement les tests d'un module spécifique
```lua
-- Créer un script custom dans modules/testbench/scripts/run_module.lua
RegisterCommand('testbench_run_module', function(source, args)
    if source ~= 0 then return end
    
    local moduleName = args[1]
    if not moduleName then
        print('[TESTBENCH] Usage: testbench_run_module <nom_module>')
        return
    end
    
    -- Logique pour filtrer et lancer les tests du module
    -- ...
end, true)
```

### Export depuis un autre script
```lua
-- Depuis un autre module, vous pouvez appeler :
local results = exports['vAvA_testbench']:RunAllTests()

print('Tests passed: ' .. results.passed)
print('Tests failed: ' .. results.failed)
```

---

## 🔗 Liens utiles

- **README principal** : [README.md](README.md)
- **Guide de création de tests** : [CREATION_COMPLETE.md](CREATION_COMPLETE.md)
- **Configuration** : [config/config.lua](config/config.lua)

---

*Dernière mise à jour : 9 Janvier 2026*  
*Version : 3.1.0*  
*Module : vAvA_testbench*
