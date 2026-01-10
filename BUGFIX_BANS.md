# 🔧 Correction du Système de Bans - vAvA_core

## ❌ Problème Identifié

Une incohérence existait entre la structure SQL de la table `bans` et le code Lua qui l'utilisait, causant l'erreur suivante :

```
Unknown column 'expire' in 'WHERE'
Query: DELETE FROM bans WHERE expire IS NOT NULL AND expire < NOW() AND permanent = 0
```

### Causes

1. **Fichiers SQL incohérents** :
   - `init.sql` et `init_simple.sql` utilisaient la colonne `expire`
   - `init_txadmin.sql` utilisait la colonne `expire_at`
   - `dal.lua` utilisait correctement `expire_at`

2. **Code Lua incohérent** :
   - `server/bans.lua` utilisait `expire` dans certaines requêtes
   - `server/security.lua` utilisait `expire` dans l'INSERT
   - `database/dal.lua` utilisait correctement `expire_at`

3. **Colonnes manquantes** :
   - `init_txadmin.sql` ne définissait pas les colonnes : `license`, `steam`, `discord`, `ip`
   - Ces colonnes étaient utilisées dans `security.lua` pour l'INSERT

---

## ✅ Solution Appliquée

### 1. Standardisation du Nom de Colonne

**Décision** : Utiliser `expire_at` partout (cohérent avec les conventions SQL modernes)

#### Fichiers Modifiés

**a) `server/bans.lua`** (3 modifications)
- ✅ Ligne 128 : `SELECT ... expire_at ...` (au lieu de `expire`)
- ✅ Ligne 130 : `WHERE expire_at IS NULL OR expire_at > NOW()` (au lieu de `expire`)
- ✅ Ligne 152 : `ban.expire_at or 'Permanent'` (au lieu de `ban.expire`)
- ✅ Ligne 168-169 : `WHERE expire_at IS NOT NULL AND expire_at < NOW()` (au lieu de `expire`)

**b) `server/security.lua`** (1 modification)
- ✅ Ligne 234 : `INSERT INTO bans (..., expire_at, ...)` (au lieu de `expire`)

**c) `database/sql/init.sql`** (1 modification)
- ✅ Ligne 114 : `expire_at DATETIME DEFAULT NULL` (au lieu de `expire`)

**d) `database/sql/init_simple.sql`** (1 modification)
- ✅ Ligne 96 : `expire_at DATETIME DEFAULT NULL` (au lieu de `expire`)

**e) `database/sql/init_txadmin.sql`** (1 modification)
- ✅ Ajout des colonnes manquantes : `license`, `steam`, `discord`, `ip`
- ✅ Ajout des index correspondants : `idx_license`, `idx_steam`, `idx_discord`

---

### 2. Structure Finale de la Table `bans`

```sql
CREATE TABLE IF NOT EXISTS `bans` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `identifier` VARCHAR(60) NOT NULL,
    `license` VARCHAR(60) DEFAULT NULL,
    `steam` VARCHAR(60) DEFAULT NULL,
    `discord` VARCHAR(60) DEFAULT NULL,
    `ip` VARCHAR(50) DEFAULT NULL,
    `reason` TEXT NOT NULL,
    `expire_at` DATETIME DEFAULT NULL,
    `permanent` TINYINT(1) DEFAULT 0,
    `banned_by` VARCHAR(60) DEFAULT 'System',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_identifier` (`identifier`),
    INDEX `idx_license` (`license`),
    INDEX `idx_steam` (`steam`),
    INDEX `idx_discord` (`discord`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## 🔄 Migration pour Serveurs Existants

### Option 1 : Script de Migration Automatique (Recommandé)

Un script SQL a été créé pour migrer automatiquement les serveurs existants :

**Fichier** : [database/sql/migration_bans_fix.sql](../database/sql/migration_bans_fix.sql)

**Utilisation** :
```bash
# Via MySQL CLI
mysql -u root -p votre_database < database/sql/migration_bans_fix.sql

# Via phpMyAdmin
# 1. Ouvrir phpMyAdmin
# 2. Sélectionner votre base de données
# 3. Onglet "SQL"
# 4. Copier/coller le contenu de migration_bans_fix.sql
# 5. Exécuter
```

**Actions du script** :
- ✅ Renomme automatiquement `expire` en `expire_at` (si la colonne existe)
- ✅ Ajoute les colonnes manquantes (`license`, `steam`, `discord`, `ip`) si nécessaire
- ✅ Crée les index appropriés
- ✅ Sécurisé : vérifie l'existence des colonnes avant modification

---

### Option 2 : Migration Manuelle

Si vous préférez exécuter les commandes manuellement :

```sql
-- 1. Renommer la colonne expire en expire_at (si elle existe)
ALTER TABLE `bans` 
CHANGE COLUMN `expire` `expire_at` DATETIME DEFAULT NULL;

-- 2. Ajouter les colonnes manquantes (si elles n'existent pas)
ALTER TABLE `bans` 
ADD COLUMN `license` VARCHAR(60) DEFAULT NULL AFTER `identifier`,
ADD INDEX `idx_license` (`license`);

ALTER TABLE `bans` 
ADD COLUMN `steam` VARCHAR(60) DEFAULT NULL AFTER `license`,
ADD INDEX `idx_steam` (`steam`);

ALTER TABLE `bans` 
ADD COLUMN `discord` VARCHAR(60) DEFAULT NULL AFTER `steam`,
ADD INDEX `idx_discord` (`discord`);

ALTER TABLE `bans` 
ADD COLUMN `ip` VARCHAR(50) DEFAULT NULL AFTER `discord`;

-- 3. Vérifier la structure
DESCRIBE bans;
```

---

## 🧪 Vérification

Après la migration, vérifiez que tout fonctionne correctement :

### 1. Vérifier la Structure de la Table

```sql
DESCRIBE bans;
```

**Résultat attendu** :
```
+------------+--------------+------+-----+-------------------+
| Field      | Type         | Null | Key | Default           |
+------------+--------------+------+-----+-------------------+
| id         | int(11)      | NO   | PRI | NULL              |
| identifier | varchar(60)  | NO   | MUL | NULL              |
| license    | varchar(60)  | YES  | MUL | NULL              |
| steam      | varchar(60)  | YES  | MUL | NULL              |
| discord    | varchar(60)  | YES  | MUL | NULL              |
| ip         | varchar(50)  | YES  |     | NULL              |
| reason     | text         | NO   |     | NULL              |
| expire_at  | datetime     | YES  |     | NULL              |
| permanent  | tinyint(1)   | YES  |     | 0                 |
| banned_by  | varchar(60)  | YES  |     | System            |
| created_at | timestamp    | NO   |     | CURRENT_TIMESTAMP |
+------------+--------------+------+-----+-------------------+
```

### 2. Tester le Système de Ban

Dans le jeu (console F8) ou console serveur :

```lua
-- Tester un ban temporaire (24h)
/ban 1 24 Test de ban

-- Lister les bans actifs
/listbans

-- Débannir
/unban license:XXX
```

### 3. Vérifier les Logs Serveur

Après redémarrage, vous ne devriez plus voir l'erreur :
```
✅ Plus d'erreur "Unknown column 'expire' in 'WHERE'"
```

---

## 📊 Résumé des Modifications

| Fichier | Modifications | Statut |
|---------|---------------|--------|
| `server/bans.lua` | 4 corrections `expire` → `expire_at` | ✅ Corrigé |
| `server/security.lua` | 1 correction dans INSERT | ✅ Corrigé |
| `database/dal.lua` | Déjà correct | ✅ Aucune modification |
| `database/sql/init.sql` | Colonne renommée | ✅ Corrigé |
| `database/sql/init_simple.sql` | Colonne renommée | ✅ Corrigé |
| `database/sql/init_txadmin.sql` | Colonnes ajoutées | ✅ Corrigé |
| `database/sql/migration_bans_fix.sql` | Script créé | ✅ Nouveau |

---

## 🎯 Impact

### Avant (Problèmes)
- ❌ Erreur SQL au démarrage : `Unknown column 'expire'`
- ❌ Nettoyage automatique des bans expirés ne fonctionnait pas
- ❌ Liste des bans (`/listbans`) retournait des erreurs
- ❌ Structure SQL incohérente entre les 3 fichiers d'initialisation

### Après (Solution)
- ✅ Aucune erreur SQL au démarrage
- ✅ Nettoyage automatique des bans expirés fonctionne (toutes les heures)
- ✅ Commande `/listbans` fonctionne correctement
- ✅ Structure SQL unifiée et cohérente
- ✅ Support complet des identifiants multiples (license, steam, discord, ip)
- ✅ Code Lua cohérent avec la structure SQL

---

## 🚀 Déploiement

### Nouveau Serveur
Aucune action requise ! Les fichiers SQL corrigés seront utilisés automatiquement lors de l'installation.

### Serveur Existant
1. **Sauvegarde** : Faites une sauvegarde de votre base de données
   ```bash
   mysqldump -u root -p votre_database > backup_$(date +%Y%m%d).sql
   ```

2. **Migration** : Exécutez le script de migration
   ```bash
   mysql -u root -p votre_database < database/sql/migration_bans_fix.sql
   ```

3. **Mise à Jour** : Mettez à jour vos fichiers vAvA_core avec les versions corrigées

4. **Redémarrage** : Redémarrez le serveur
   ```bash
   restart vAvA_core
   ```

5. **Vérification** : Testez les commandes `/ban`, `/unban`, `/listbans`

---

## 📝 Notes Techniques

### Conventions SQL
- Utilisation de `expire_at` au lieu de `expire` pour suivre les conventions modernes (suffixe `_at` pour les timestamps)
- Type `DATETIME` permet NULL pour les bans permanents
- Type `TIMESTAMP` pour `created_at` avec auto-fill

### Identifiants Multiples
Le système de ban supporte maintenant plusieurs types d'identifiants :
- `identifier` : Identifiant principal (license, steam, etc.)
- `license` : Rockstar License
- `steam` : Steam ID
- `discord` : Discord ID
- `ip` : Adresse IP

Cela permet un système de ban plus robuste et difficile à contourner.

### Nettoyage Automatique
Un thread s'exécute toutes les heures pour supprimer automatiquement les bans expirés :
```lua
CreateThread(function()
    while true do
        Wait(3600000) -- 1 heure
        DELETE FROM bans WHERE expire_at IS NOT NULL AND expire_at < NOW()
    end
end)
```

---

## 🐛 Dépannage

### Erreur : "Column 'expire_at' doesn't exist"
**Cause** : La migration n'a pas été exécutée  
**Solution** : Exécutez le script `migration_bans_fix.sql`

### Erreur : "Duplicate column name 'license'"
**Cause** : La colonne existe déjà  
**Solution** : Normal, le script détecte automatiquement les colonnes existantes

### Bans existants ne fonctionnent plus
**Cause** : Données corrompues ou migration incomplète  
**Solution** : Vérifiez que `expire_at` contient bien les valeurs de l'ancien champ `expire`

---

## 📞 Support

Si vous rencontrez des problèmes après la migration :

1. Vérifiez les logs serveur pour des erreurs SQL
2. Exécutez `DESCRIBE bans;` pour vérifier la structure
3. Consultez la documentation complète dans [doc/](../doc/)
4. Ouvrez une issue sur GitHub : https://github.com/Nicolasbriet/vAvA_core

---

**✅ Correction Appliquée avec Succès !**

*Date : 10 janvier 2026*  
*Version : vAvA_core v3.1.0*
