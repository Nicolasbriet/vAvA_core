# 🔄 Guide d'utilisation du système Auto-Update (GitHub)

## 🌟 Vue d'ensemble

Le système Auto-Update vérifie et applique automatiquement les mises à jour depuis **GitHub**. Il gère :
- ✅ Vérification des versions sur GitHub
- ✅ Téléchargement automatique des fichiers
- ✅ **Réinstallation des modules** (comme txAdmin recipe)
- ✅ Déplacement des modules vers les ressources séparées
- ✅ Application des mises à jour SQL
- ✅ Redémarrage automatique des ressources (optionnel)
- ✅ Fallback local si GitHub est inaccessible

---

## 📋 Configuration

### Fichier `auto_update.lua`

```lua
local CONFIG = {
    githubRepo = 'Nicolasbriet/vAvA_core',  -- Votre dépôt GitHub
    branch = 'main',                         -- Branche à utiliser
    checkInterval = 3600000,                 -- Vérifier toutes les heures
    versionFile = 'version.json',            -- Fichier des versions
    autoUpdate = true,                       -- Activation auto
    autoRestart = false,                     -- Redémarrage auto (off par défaut)
    backupBeforeUpdate = true                -- Sauvegarde avant update
}
```

---

## 🗂️ Structure du fichier `version.json` (sur GitHub)

Créez un fichier `version.json` à la racine de votre dépôt GitHub :

```json
{
    "vava_core": "1.0.0",
    "economy": "1.2.0",
    "creator": "1.0.0",
    "updates": [
        {
            "module": "economy",
            "version": "1.2.0",
            "description": "Ajout monitoring",
            "releaseDate": "2026-01-09",
            "queries": [
                "CREATE TABLE..."
            ],
            "files": [
                "modules/economy/server/auto_adjust.lua",
                "modules/economy/config/economy.lua"
            ],
            "needsRestart": true,
            "changelog": [
                "Feature 1",
                "Fix bug 2"
            ]
        }
    ]
}
```

---

## 🏗️ Mapping des modules (modules/ → ressources)

Le système gère automatiquement le déplacement des modules :

| Module (dans vAvA_core) | Ressource séparée |
|-------------------------|-------------------|
| `modules/economy/` | `vAvA_economy` |
| `modules/creator/` | `vAvA_creator` |
| `modules/garage/` | `vAvA_garage` |
| `modules/inventory/` | `vAvA_inventory` |
| `modules/jobs/` | `vAvA_jobs` |
| `modules/chat/` | `vAvA_chat` |
| `modules/keys/` | `vAvA_keys` |
| `modules/concess/` | `vAvA_concess` |
| `modules/jobshop/` | `vAvA_jobshop` |
| `modules/persist/` | `vAvA_persist` |
| `modules/sit/` | `vAvA_sit` |
| `modules/loadingscreen/` | `vAvA_loadingscreen` |
| `modules/testbench/` | `vAvA_testbench` |

---

## 🚀 Workflow complet

### Au démarrage du serveur :

```
1. Connexion à GitHub
2. Téléchargement de version.json
3. Comparaison des versions (local vs GitHub)
4. Si nouvelle version détectée:
   ├─ Téléchargement des fichiers depuis GitHub
   ├─ Copie vers la ressource séparée (ex: vAvA_economy)
   ├─ Application des requêtes SQL
   ├─ Enregistrement de la nouvelle version
   └─ Redémarrage de la ressource (si autoRestart=true)
5. Programmation de la prochaine vérification (1h)
```

### Vérification périodique :

Le système vérifie GitHub **toutes les heures** automatiquement.

---

## 🎮 Commandes Admin

### 1. Afficher les versions
```
/versions
```
**Permissions:** Admin niveau 3+

**Affichage:**
```
[VERSIONS DES MODULES]
economy              [UPDATE AVAILABLE] v1.1.0 (dernière: v1.2.0)
  └─ Ressource: vAvA_economy (started)
creator              [OK] v1.0.0 (dernière: v1.0.0)
  └─ Ressource: vAvA_creator (started)
```

### 2. Vérifier et appliquer les mises à jour
```
/checkupdates
```
**Permissions:** Admin niveau 3+
Force la vérification immédiate depuis GitHub.

### 3. Réinstaller un module
```
/reinstallmodule economy
```
**Permissions:** Admin niveau 4+ (superadmin)
Réinstalle complètement un module depuis GitHub.

### 4. Forcer une mise à jour (ancienne commande)
```
/forceupdate
```
Utilise les mises à jour locales (fallback si GitHub inaccessible).

---

## 📦 Ajouter une nouvelle mise à jour

### Étape 1 : Développer la fonctionnalité

Développez votre nouvelle fonctionnalité dans le module concerné.

### Étape 2 : Mettre à jour `version.json` sur GitHub

```json
{
    "economy": "1.3.0",  // ← Incrémenter la version
    "updates": [
        {
            "module": "economy",
            "version": "1.3.0",
            "description": "Ajout des graphiques statistiques",
            "releaseDate": "2026-01-10",
            "queries": [
                "CREATE TABLE IF NOT EXISTS `economy_stats` (...)",
                "ALTER TABLE `economy_items` ADD COLUMN `popularity` INT"
            ],
            "files": [
                "modules/economy/server/stats.lua",
                "modules/economy/server/main.lua",
                "modules/economy/config/economy.lua"
            ],
            "needsRestart": true,
            "changelog": [
                "Ajout des graphiques de transactions",
                "Calcul automatique de popularité",
                "Export Excel des statistiques"
            ]
        }
    ]
}
```

### Étape 3 : Push sur GitHub

```bash
git add version.json modules/economy/
git commit -m "Economy v1.3.0 - Graphiques statistiques"
git push origin main
```

### Étape 4 : Sur le serveur

Le serveur détectera automatiquement la mise à jour :
- Au prochain démarrage
- OU lors de la vérification périodique (toutes les heures)
- OU avec `/checkupdates`

---

## 🔒 Sécurité et Fallback

### Mode fallback local

Si GitHub est inaccessible, le système utilise les versions locales définies dans `auto_update.lua` :

```lua
local LOCAL_VERSIONS = {
    ['economy'] = '1.2.0',
    -- ...
}

local LOCAL_UPDATES = {
    {
        module = 'economy',
        version = '1.2.0',
        queries = [...],
        -- ...
    }
}
```

### Logs de connexion

```
[AUTO UPDATE] Récupération des versions depuis GitHub...
[AUTO UPDATE] URL: https://raw.githubusercontent.com/Nicolasbriet/vAvA_core/main/version.json
[AUTO UPDATE] Versions GitHub récupérées avec succès
[AUTO UPDATE] Source: GitHub
```

ou en cas d'échec :

```
[AUTO UPDATE ERROR] GitHub inaccessible (HTTP 404)
[AUTO UPDATE] Source: Local
```

---

## 📊 Exemple de sortie complète

```
═══════════════════════════════════════════════════════════
[AUTO UPDATE] Vérification des mises à jour des modules...
═══════════════════════════════════════════════════════════
[AUTO UPDATE] Récupération des versions depuis GitHub...
[AUTO UPDATE] Versions GitHub récupérées avec succès
[AUTO UPDATE] Source: GitHub
[AUTO UPDATE] Module: economy
[AUTO UPDATE] Version installée: v1.1.0 → Nouvelle version: v1.2.0
[AUTO UPDATE] Application de la mise à jour: economy v1.2.0
[AUTO UPDATE] Description: Ajout du système de monitoring
[AUTO UPDATE] Requête #1 exécutée avec succès
[AUTO UPDATE] Requête #2 exécutée avec succès
[AUTO UPDATE] Mise à jour economy v1.2.0 terminée avec succès!
[AUTO UPDATE] Réinstallation du module: economy → vAvA_economy
[AUTO UPDATE] Téléchargé: modules/economy/server/auto_adjust.lua
[AUTO UPDATE] Téléchargé: modules/economy/config/economy.lua
[AUTO UPDATE] Module economy réinstallé avec succès
[AUTO UPDATE] Redémarrage de la ressource: vAvA_economy
═══════════════════════════════════════════════════════════
[AUTO UPDATE] 1 mise(s) à jour appliquée(s) avec succès
[AUTO UPDATE] 1 module(s) réinstallé(s) depuis GitHub
═══════════════════════════════════════════════════════════
```

---

## 🛠️ Configuration avancée

### Activer le redémarrage automatique

Par défaut, les ressources ne sont **pas redémarrées automatiquement**. Pour activer :

```lua
local CONFIG = {
    autoRestart = true  -- ⚠️ Peut causer des déconnexions
}
```

### Changer l'intervalle de vérification

```lua
local CONFIG = {
    checkInterval = 7200000  -- 2 heures au lieu de 1
}
```

### Désactiver les mises à jour automatiques

```lua
local CONFIG = {
    autoUpdate = false  -- Mises à jour manuelles uniquement
}
```

---

## 🐛 Résolution de problèmes

### GitHub inaccessible

**Symptôme:** `[AUTO UPDATE ERROR] GitHub inaccessible (HTTP 404)`

**Solutions:**
1. Vérifier que le dépôt est public
2. Vérifier que `version.json` existe à la racine
3. Vérifier le nom du dépôt dans CONFIG
4. Le système utilisera automatiquement le fallback local

### Fichiers non téléchargés

**Symptôme:** `[AUTO UPDATE ERROR] Échec téléchargement`

**Solutions:**
1. Vérifier les chemins dans `files` (doivent correspondre au repo GitHub)
2. Vérifier que les fichiers existent sur GitHub
3. Vérifier les permissions d'écriture sur le serveur

### Module non trouvé

**Symptôme:** `[AUTO UPDATE ERROR] Module inconnu: xxx`

**Solution:** Ajouter le module dans `MODULE_MAPPING` :

```lua
local MODULE_MAPPING = {
    ['votre_module'] = {
        resource = 'vAvA_votre_module',
        path = 'modules/votre_module'
    }
}
```

---

## 📚 Exports disponibles

```lua
-- Vérifier les mises à jour
exports['vAvA_core']:CheckUpdates()

-- Obtenir la version d'un module
local version = exports['vAvA_core']:GetModuleVersion('economy')

-- Récupérer les versions depuis GitHub
exports['vAvA_core']:FetchGitHubVersions(function(success, versions)
    if success then
        print('Versions:', json.encode(versions))
    end
end)
```

---

## 🎯 Checklist de déploiement

- [ ] Créer `version.json` à la racine du dépôt GitHub
- [ ] Configurer CONFIG dans `auto_update.lua`
- [ ] Push le code sur GitHub
- [ ] Tester avec `/checkupdates`
- [ ] Vérifier les logs au démarrage
- [ ] Valider avec `/versions`

---

**Créé par vAvA - Version 2.0.0 avec support GitHub**


---

## ✨ Fonctionnalités

- ✅ Vérification automatique au démarrage du serveur
- ✅ Application des mises à jour SQL sans intervention manuelle
- ✅ Gestion des versions avec semantic versioning
- ✅ Logs détaillés de chaque mise à jour
- ✅ Commandes admin pour forcer les mises à jour
- ✅ Protection contre les régressions de version

---

## 📋 Comment ajouter une nouvelle mise à jour

### Étape 1 : Mettre à jour la version du module

Dans `auto_update.lua`, section `MODULE_VERSIONS` :

```lua
local MODULE_VERSIONS = {
    ['vava_core'] = '1.0.0',
    ['economy'] = '1.3.0',      -- ← Incrémenter la version
    ['creator'] = '1.0.0',
    -- ...
}
```

### Étape 2 : Ajouter l'entrée de mise à jour

Dans `auto_update.lua`, section `UPDATES` :

```lua
{
    module = 'economy',                     -- Nom du module
    version = '1.3.0',                      -- Nouvelle version
    description = 'Ajout des graphiques statistiques', -- Description
    queries = {                             -- Requêtes SQL à exécuter
        [[
            CREATE TABLE IF NOT EXISTS `economy_stats` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `date` DATE NOT NULL,
                `transactions` INT DEFAULT 0,
                `volume` DECIMAL(15,2) DEFAULT 0
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
        [[
            ALTER TABLE `economy_items` 
            ADD COLUMN `popularity` INT DEFAULT 0 AFTER `sell_count`;
        ]]
    },
    files = {                               -- Fichiers modifiés (info)
        'modules/economy/server/stats.lua',
        'modules/economy/config/economy.lua'
    }
}
```

### Étape 3 : Redémarrer le serveur

Le système détectera automatiquement la nouvelle version et appliquera les mises à jour.

---

## 📊 Semantic Versioning

| Version | Quand l'utiliser |
|---------|------------------|
| **MAJOR** (1.0.0 → 2.0.0) | Changements incompatibles, restructuration majeure |
| **MINOR** (1.0.0 → 1.1.0) | Ajout de nouvelles fonctionnalités compatibles |
| **PATCH** (1.0.0 → 1.0.1) | Corrections de bugs, améliorations mineures |

---

## 🎮 Commandes Admin

### Afficher les versions des modules
```
/versions
```
Affiche toutes les versions installées et attendues des modules.

### Forcer une mise à jour
```
/forceupdate
```
Force la vérification et l'application des mises à jour (admin niveau 4).

---

## 📦 Exemple complet : Ajouter une table

```lua
-- Dans MODULE_VERSIONS
['inventory'] = '1.1.0',  -- Anciennement 1.0.0

-- Dans UPDATES
{
    module = 'inventory',
    version = '1.1.0',
    description = 'Ajout du système de craft',
    queries = {
        [[
            CREATE TABLE IF NOT EXISTS `crafting_recipes` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `result_item` VARCHAR(100) NOT NULL,
                `ingredients` JSON NOT NULL,
                `crafting_time` INT DEFAULT 5,
                `required_level` INT DEFAULT 0,
                KEY `result_item` (`result_item`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]],
        [[
            INSERT INTO `crafting_recipes` 
            (`result_item`, `ingredients`, `crafting_time`) 
            VALUES 
            ('bandage', '{"cloth":2,"alcohol":1}', 3),
            ('lockpick', '{"metal":1,"screws":2}', 5)
            ON DUPLICATE KEY UPDATE `id` = `id`;
        ]]
    },
    files = {
        'modules/inventory/server/crafting.lua',
        'modules/inventory/config/recipes.lua'
    }
}
```

---

## ⚠️ Bonnes pratiques

### ✅ À FAIRE

- Toujours utiliser `CREATE TABLE IF NOT EXISTS`
- Utiliser `ON DUPLICATE KEY UPDATE` pour les insertions
- Tester les requêtes SQL dans phpMyAdmin/HeidiSQL avant
- Incrémenter correctement les versions
- Ajouter des descriptions claires

### ❌ À ÉVITER

- Ne jamais utiliser `DROP TABLE` dans les mises à jour
- Éviter les modifications destructives (perte de données)
- Ne pas sauter de versions (1.0.0 → 1.2.0 sans 1.1.0)
- Éviter les requêtes trop longues qui bloquent le démarrage

---

## 🔍 Logs et débogage

### Logs au démarrage
```
[AUTO UPDATE] Vérification des mises à jour des modules...
[AUTO UPDATE] Module: economy
[AUTO UPDATE] Version installée: v1.1.0 → Nouvelle version: v1.2.0
[AUTO UPDATE] Application de la mise à jour: economy v1.2.0
[AUTO UPDATE] Description: Ajout du système de monitoring
[AUTO UPDATE] Requête #1 exécutée avec succès
[AUTO UPDATE] Requête #2 exécutée avec succès
[AUTO UPDATE] Mise à jour economy v1.2.0 terminée avec succès!
[AUTO UPDATE] 1 mise(s) à jour appliquée(s) avec succès
```

### En cas d'erreur
```
[AUTO UPDATE ERROR] Erreur SQL requête #1: Table 'economy_logs' doesn't exist
[AUTO UPDATE ERROR] Échec de la mise à jour economy v1.2.0
[AUTO UPDATE] 1 mise(s) à jour échouée(s)
```

---

## 🗃️ Structure de la base de données

### Table `vcore_module_versions`

Stocke les versions actuellement installées :

```sql
CREATE TABLE `vcore_module_versions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `module_name` VARCHAR(100) NOT NULL UNIQUE,
    `version` VARCHAR(20) NOT NULL,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Exemple de données :
```
+----+-------------+---------+---------------------+
| id | module_name | version | updated_at          |
+----+-------------+---------+---------------------+
|  1 | vava_core   | 1.0.0   | 2026-01-09 10:30:00 |
|  2 | economy     | 1.2.0   | 2026-01-09 10:30:15 |
|  3 | creator     | 1.0.0   | 2026-01-09 10:30:00 |
+----+-------------+---------+---------------------+
```

---

## 🚀 Export disponible

### Vérifier les mises à jour manuellement (depuis un autre script)
```lua
exports['vAvA_core']:CheckUpdates()
```

### Obtenir la version d'un module
```lua
local version = exports['vAvA_core']:GetModuleVersion('economy')
print('Version de economy:', version)
```

---

## 📝 Exemple de workflow de développement

1. **Développer la nouvelle fonctionnalité**
   - Coder les nouvelles features
   - Créer les nouvelles tables SQL

2. **Préparer la mise à jour**
   - Incrémenter la version dans `MODULE_VERSIONS`
   - Ajouter l'entrée dans `UPDATES` avec les requêtes SQL

3. **Tester localement**
   - Redémarrer le serveur de test
   - Vérifier les logs d'auto-update
   - Valider que la mise à jour fonctionne

4. **Déployer en production**
   - Push les fichiers sur le serveur de production
   - Redémarrer le serveur
   - Le système appliquera automatiquement les mises à jour

5. **Vérifier le déploiement**
   - Utiliser `/versions` pour confirmer les versions
   - Vérifier les tables dans phpMyAdmin

---

## 🛡️ Sécurité

- Les commandes admin nécessitent niveau 3 ou 4
- Les mises à jour sont enregistrées dans `economy_logs`
- Aucune mise à jour ne peut régresser (v1.2.0 → v1.1.0 impossible)
- Les erreurs SQL n'arrêtent pas le serveur, juste la mise à jour concernée

---

## 💡 Conseils avancés

### Mise à jour conditionnelle

Si vous devez vérifier l'existence d'une colonne avant modification :

```lua
queries = {
    [[
        -- Ajouter une colonne seulement si elle n'existe pas
        SET @exist = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS 
                      WHERE TABLE_NAME = 'economy_items' 
                      AND COLUMN_NAME = 'popularity');
        SET @sql = IF(@exist = 0, 
            'ALTER TABLE `economy_items` ADD COLUMN `popularity` INT DEFAULT 0',
            'SELECT "Column already exists"');
        PREPARE stmt FROM @sql;
        EXECUTE stmt;
    ]]
}
```

### Migrations de données

Pour migrer des données entre tables :

```lua
queries = {
    -- Créer nouvelle table
    [[CREATE TABLE IF NOT EXISTS `new_table` (...)]],
    
    -- Migrer les données
    [[INSERT INTO `new_table` SELECT * FROM `old_table`]],
    
    -- Optionnel: supprimer ancienne table
    -- [[DROP TABLE IF EXISTS `old_table`]]
}
```

---

## 📚 Ressources

- [Semantic Versioning](https://semver.org/)
- [MySQL Documentation](https://dev.mysql.com/doc/)
- [FiveM Documentation](https://docs.fivem.net/)

---

**Créé par vAvA - Version 1.0.0**
