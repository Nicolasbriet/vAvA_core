# 🔧 Guide Installation Rapide - Tables SQL Manquantes

> **Pour serveurs existants ayant les erreurs de tables manquantes**

---

## ❌ Erreurs Rencontrées

```
Table 's1_fivem.hospital_blood_stock' doesn't exist
Table 's1_fivem.shared_vehicle_keys' doesn't exist
Couldn't find resource vAvA_police
Couldn't find resource vAvA_player_manager
```

---

## ✅ Solutions (2 Méthodes)

### Méthode 1 : Script PowerShell Automatique (Recommandé)

1. **Ouvrez PowerShell en Administrateur** dans le dossier `vAvA_core`
2. **Exécutez le script :**
   ```powershell
   .\install_sql_tables.ps1
   ```
3. **Suivez les instructions** (entrez vos identifiants MySQL)
4. **C'est fait !** Les 4 fichiers SQL seront installés automatiquement

---

### Méthode 2 : Installation Manuelle

#### A. Installation des Tables SQL

**Option 1 : Via MySQL Workbench**

1. Ouvrez MySQL Workbench
2. Connectez-vous à votre base de données
3. Exécutez ces fichiers SQL dans l'ordre :

```sql
-- 1. EMS System
source D:/fivemserver/vAvA_core/modules/ems/sql/ems_system.sql

-- 2. Keys System  
source D:/fivemserver/vAvA_core/modules/keys/sql/keys_system.sql

-- 3. Police System
source D:/fivemserver/vAvA_core/modules/police/sql/police_system.sql

-- 4. Player Manager
source D:/fivemserver/vAvA_core/modules/player_manager/sql/player_manager.sql
```

**Option 2 : Via ligne de commande MySQL**

```bash
# Remplacez USER, PASSWORD et DATABASE par vos valeurs
mysql -u USER -pPASSWORD DATABASE < modules/ems/sql/ems_system.sql
mysql -u USER -pPASSWORD DATABASE < modules/keys/sql/keys_system.sql
mysql -u USER -pPASSWORD DATABASE < modules/police/sql/police_system.sql
mysql -u USER -pPASSWORD DATABASE < modules/player_manager/sql/player_manager.sql
```

**Option 3 : Via phpMyAdmin**

1. Connectez-vous à phpMyAdmin
2. Sélectionnez votre base de données
3. Cliquez sur "Import"
4. Importez chaque fichier SQL un par un

#### B. Copie des Modules Manquants

**PowerShell (Windows) :**
```powershell
# Depuis le dossier vAvA_core
Copy-Item "modules\police" -Destination "..\..\..\resources\[vava]\vAvA_police" -Recurse
Copy-Item "modules\player_manager" -Destination "..\..\..\resources\[vava]\vAvA_player_manager" -Recurse
```

**Ou manuellement :**
1. Copiez `vAvA_core/modules/police/` vers `resources/[vava]/vAvA_police/`
2. Copiez `vAvA_core/modules/player_manager/` vers `resources/[vava]/vAvA_player_manager/`

#### C. Vérification

1. **Vérifiez que les dossiers existent :**
   - `resources/[vava]/vAvA_police/fxmanifest.lua`
   - `resources/[vava]/vAvA_player_manager/fxmanifest.lua`

2. **Vérifiez que server.cfg contient :**
   ```properties
   ensure vAvA_police
   ensure vAvA_player_manager
   ```

3. **Redémarrez le serveur** :
   ```
   restart vAvA_core
   ```

---

## ✅ Vérification Post-Installation

### 1. Vérifier les Tables en BDD

Connectez-vous à MySQL et exécutez :

```sql
-- Vérifier tables EMS
SHOW TABLES LIKE 'hospital_%';
SHOW TABLES LIKE 'ems_%';

-- Vérifier tables Keys
SHOW TABLES LIKE '%vehicle_keys%';

-- Vérifier tables Police
SHOW TABLES LIKE 'police_%';

-- Vérifier tables Player Manager
SHOW TABLES LIKE 'player_%';
```

**Résultat attendu :**
- 7 tables EMS (hospital_blood_stock, ems_medical_history, etc.)
- 4 tables Keys (shared_vehicle_keys, vehicle_keys_history, etc.)
- 6 tables Police (police_fines, police_prisoners, etc.)
- 6 tables Player Manager (player_characters, player_stats, etc.)

### 2. Vérifier les Modules au Démarrage

Dans les logs serveur, recherchez :

```
✅ [vAvA_ems] Module EMS chargé avec succès
✅ [vAvA_keys] Module démarré avec succès!
✅ [vAvA_police] Started resource vAvA_police
✅ [vAvA_player_manager] Started resource vAvA_player_manager
```

**Aucune de ces erreurs :**
```
❌ Table 'hospital_blood_stock' doesn't exist
❌ Table 'shared_vehicle_keys' doesn't exist  
❌ Couldn't find resource vAvA_police
❌ Couldn't find resource vAvA_player_manager
```

---

## 📋 Tables Créées

### Module EMS (7 tables)
- `hospital_blood_stock` - Stock sanguin par groupe
- `ems_medical_history` - Historique médical
- `ems_invoices` - Factures médicales
- `ems_active_units` - Ambulances en service
- `ems_calls` - Appels d'urgence
- `ems_stats` - Statistiques médecins
- `ems_prescriptions` - Ordonnances

### Module Keys (4 tables)
- `shared_vehicle_keys` - Clés partagées
- `vehicle_keys_history` - Historique des clés
- `vehicle_lockpick_attempts` - Tentatives crochetage
- `vehicle_keys_config` - Configuration par classe

### Module Police (6 tables)
- `police_fines` - Amendes
- `police_criminal_records` - Casier judiciaire
- `police_prisoners` - Prisonniers actifs
- `police_impounded_vehicles` - Véhicules saisis
- `police_confiscated_items` - Items confisqués
- `police_alerts` - Alertes/dispatch

### Module Player Manager (6 tables)
- `player_characters` - Personnages
- `player_appearance` - Apparence
- `player_outfits` - Tenues
- `player_licenses` - Licences
- `player_stats` - Statistiques
- `player_history` - Historique

---

## 🆘 Problèmes Courants

### Erreur : "Access denied for user"
**Solution :** Vérifiez vos identifiants MySQL (user/password)

### Erreur : "Database doesn't exist"
**Solution :** Créez la base de données d'abord :
```sql
CREATE DATABASE IF NOT EXISTS s1_fivem CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### Erreur : "Table already exists"
**Solution :** Normal si vous réinstallez. Ignorez l'erreur ou supprimez les tables avant.

### Module ne démarre pas après copie
**Solution :** 
1. Vérifiez que `fxmanifest.lua` existe dans le dossier
2. Faites `refresh` puis `ensure nom_module` dans la console F8
3. Vérifiez les logs pour voir l'erreur exacte

---

## 📞 Support

Si les problèmes persistent :
1. Vérifiez les logs serveur complets
2. Vérifiez que oxmysql fonctionne correctement
3. Vérifiez les permissions MySQL de l'utilisateur
4. Consultez le fichier `ANALYSE_MODULES_CONFIGURATION.md` pour plus de détails

---

**✅ Une fois terminé, tous les 18 modules seront opérationnels !**
