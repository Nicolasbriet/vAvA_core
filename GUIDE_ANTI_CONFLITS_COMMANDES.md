# Guide Anti-Conflits Commandes vAvA_core ⚠️

## 🚨 Problèmes Résolus

### Conflits Détectés et Corrigés:
1. **Commande `givemoney` dupliquée** dans `server/commands.lua` (2x) → **CORRIGÉ** ✅
2. **Commande `setmoney` dupliquée** dans `server/commands.lua` (2x) → **CORRIGÉ** ✅  
3. **Conflit `givemoney`** entre `server/commands.lua` et `modules/inventory/server/main.lua` → **CORRIGÉ** ✅

### Solutions Appliquées:
- ✅ Suppression des anciennes commandes dupliquées dans `commands.lua`
- ✅ Renommage de la commande inventory: `givemoney` → `givemoney_inventory`
- ✅ Conservation des nouvelles commandes utilisant les fonctions `vCore.*` modernes

## 📋 Commandes Finales Uniques

### Système d'Argent Principal (vCore):
- `/givemoney [id] [type] [montant]` - Ajouter de l'argent (vCore system)
- `/removemoney [id] [type] [montant]` - Retirer de l'argent (vCore system)
- `/setmoney [id] [type] [montant]` - Définir montant exact (vCore system)
- `/checkmoney [id]` - Vérifier l'argent d'un joueur
- `/debugmoney [id]` - Debug système d'argent

### Système Legacy (Inventory):
- `/givemoney_inventory [id] [montant]` - Ajouter argent comme item (legacy)

## ✅ Vérifications Anti-Conflits

### FXServer Natives:
- ❌ `help`, `quit`, `restart`, `start`, `stop`, `refresh`, `exec`, etc.
- ✅ **AUCUN CONFLIT** avec nos commandes d'argent

### Permissions ACE:
Les permissions sont correctement définies dans `server.cfg`:
```
add_ace group.superadmin command.setmoney allow
```

## 🔧 Bonnes Pratiques

### 1. Préfixage des Commandes
Pour éviter les conflits futurs, utiliser des préfixes:
- `/vava_givemoney` au lieu de `/givemoney`
- `/core_setmoney` au lieu de `/setmoney`

### 2. Vérification Avant Ajout
Avant d'ajouter une nouvelle commande:
```bash
# Chercher si elle existe déjà
Get-ChildItem . -Recurse -Include "*.lua" | Select-String -Pattern "RegisterCommand.*'COMMANDE_NAME'"
```

### 3. Nommage Module-Spécifique
- Commandes inventory: `/inventory_*`
- Commandes garage: `/garage_*`
- Commandes admin: `/admin_*`

## 🎯 Statut Actuel

**SYSTÈME SANS CONFLITS** ✅

Toutes les commandes d'argent sont:
- ✅ Uniques dans le système
- ✅ Compatibles avec FXServer
- ✅ Correctement configurées avec permissions
- ✅ Documentées et testables

## 🚀 Tests de Validation

### Test 1: Vérifier unicité
```bash
/givemoney 1 cash 1000    # Doit utiliser le système vCore moderne
```

### Test 2: Tester legacy (si nécessaire)
```bash
/givemoney_inventory 1 1000    # Doit utiliser le système inventory legacy
```

### Test 3: Permissions
```bash
/checkmoney    # Doit vérifier les permissions admin
```

Le système est maintenant **sûr et sans conflits** pour la production ! 🎯