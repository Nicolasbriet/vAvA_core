# 🚀 Guide Rapide - Tests Console vAvA_testbench

---

## ⚡ Démarrage rapide (2 minutes)

Vous développez souvent dans des lieux où vous ne pouvez pas vous connecter au serveur ? Voici comment lancer les tests directement depuis la console !

---

## 📋 Étapes rapides

### 1️⃣ Scanner les modules (10 secondes)

```
testbench_scan
```

**Résultat attendu :**
```
[TESTBENCH] 8 modules détectés :
  ✓ vAvA_core - Tests: 12
  ✓ vAvA_economy - Tests: 8
  ✓ vAvA_inventory - Tests: 15
  ...
```

---

### 2️⃣ Lancer les tests critiques (30 secondes)

```
testbench_critical
```

**Vérifie rapidement :**
- ✅ Connexion base de données
- ✅ Sécurité et permissions
- ✅ Intégrité des données

---

### 3️⃣ Lancer tous les tests (5-10 minutes)

```
testbench_run
```

**Résultat attendu :**
```
[TESTBENCH] ========================================
[TESTBENCH] RÉSULTATS DES TESTS
[TESTBENCH] ========================================
[TESTBENCH] Réussis  : 45
[TESTBENCH] Échoués  : 3
[TESTBENCH] Warnings : 2
[TESTBENCH] ========================================
```

---

### 4️⃣ Si un test échoue, le déboguer

```
testbench_run_test nom_du_test_echoue
testbench_logs 20
```

---

## 🎯 Cas d'usage courants

### ✅ Avant un commit Git

```bash
# Lancer les tests critiques (rapide)
testbench_critical

# Si OK, commit
git add .
git commit -m "feat: nouvelle fonctionnalité"
```

---

### ✅ Après avoir modifié du code

```bash
# Lancer uniquement le test concerné
testbench_run_test test_economy_price_calculation

# Si OK, continuer le dev
```

---

### ✅ Avant un déploiement production

```bash
# Lancer TOUS les tests
testbench_run

# Vérifier aucun échec
# Si failed = 0, déployer
```

---

### ✅ Debugging un bug

```bash
# Voir les derniers logs
testbench_logs 50

# Lancer le test spécifique
testbench_run_test test_qui_pose_probleme
```

---

## 📝 Toutes les commandes

| Commande | Temps | Usage |
|----------|-------|-------|
| `testbench_help` | 1s | Aide |
| `testbench_scan` | 10s | Scanner modules |
| `testbench_list` | 1s | Lister tests |
| `testbench_critical` | 30s | Tests critiques (rapide) |
| `testbench_run` | 5-10min | Tous les tests (complet) |
| `testbench_run_test <nom>` | 1-5s | Un test spécifique |
| `testbench_logs [count]` | 1s | Voir logs |

---

## 💡 Conseils Pro

### ⚡ Optimiser le workflow

1. **Scan une seule fois** au démarrage du serveur
   ```
   testbench_scan
   ```

2. **Tests critiques** après chaque modification importante
   ```
   testbench_critical
   ```

3. **Tests complets** avant un commit/merge
   ```
   testbench_run
   ```

---

### 🔧 Configuration automatique

Ajoutez dans votre `server.cfg` pour auto-test au démarrage :

```lua
# Auto-test au démarrage (optionnel)
# Décommenter pour activer
# exec testbench_scan
# exec testbench_critical
```

Ou dans `config.lua` du testbench :

```lua
TestbenchConfig = {
    AutoStart = {
        Enabled = true,        -- Auto-scan au démarrage
        CriticalOnly = true,   -- Lancer tests critiques uniquement
        Delay = 5000           -- Attendre 5s après le démarrage
    }
}
```

---

### 📊 Intégration CI/CD

Exemple pour GitHub Actions :

```yaml
name: Tests vAvA

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Start FiveM Server
        run: ./start-server.sh &
        
      - name: Wait for server
        run: sleep 30
        
      - name: Run tests
        run: |
          echo "testbench_scan" | nc localhost 30120
          echo "testbench_run" | nc localhost 30120
          
      - name: Parse results
        run: ./parse-test-results.sh
```

---

## 🆘 Problèmes courants

### ❌ Commande non trouvée

**Erreur :**
```
[ERROR] Unknown command: testbench_scan
```

**Solution :**
```
ensure vAvA_testbench
```

---

### ❌ Aucun test détecté

**Erreur :**
```
[TESTBENCH] 0 modules détectés
```

**Solution :** Créez des tests dans `modules/*/tests/` puis :
```
testbench_scan
```

---

### ❌ Tests déjà en cours

**Erreur :**
```
[TESTBENCH] Des tests sont déjà en cours d'exécution
```

**Solution :** Attendez la fin, ou redémarrez :
```
restart vAvA_testbench
```

---

## 🔗 Documentation complète

- 📖 [CONSOLE_COMMANDS.md](../modules/testbench/CONSOLE_COMMANDS.md) - Toutes les commandes en détail
- 📖 [README.md](../modules/testbench/README.md) - Documentation module complet
- 📖 [CREATION_COMPLETE.md](../modules/testbench/CREATION_COMPLETE.md) - Créer vos propres tests

---

## ✨ Résumé

**3 commandes essentielles à retenir :**

```bash
testbench_scan      # Scanner (1 fois au démarrage)
testbench_critical  # Tests rapides (après chaque modif)
testbench_run       # Tests complets (avant commit/deploy)
```

**C'est tout ! Vous êtes prêt à tester sans vous connecter au serveur ! 🚀**

---

*Guide créé le 9 Janvier 2026*  
*Version testbench : 3.1.0*
