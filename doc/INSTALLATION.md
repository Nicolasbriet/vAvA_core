# 🚀 Guide d'Installation vAvA_core

## 📋 Prérequis

- **FiveM Server** (dernière version recommandée)
- **MySQL Server** 8.0+ ou MariaDB 10.5+
- **oxmysql** (dernière version)
- **txAdmin** (optionnel mais recommandé)

---

## ⚡ Installation Rapide (5 minutes)

### Étape 1: Copier les fichiers

```bash
# Copier vAvA_core dans votre dossier resources
cp -r vAvA_core /path/to/server/resources/
```

### Étape 2: Base de données

```sql
-- Importer le fichier SQL principal
source database/sql/install_complete.sql;
```

OU via HeidiSQL/phpMyAdmin:
1. Créer une database `vava_fivem`
2. Importer `database/sql/install_complete.sql`
3. Vérifier que toutes les tables sont créées (16 tables)

### Étape 3: Configuration oxmysql

Éditez votre `server.cfg`:

```cfg
# MySQL Configuration
set mysql_connection_string "mysql://user:password@localhost/vava_fivem?charset=utf8mb4"

# Démarrer oxmysql
ensure oxmysql

# Démarrer vAvA_core
ensure vAvA_core
```

### Étape 4: Permissions Admin (txAdmin)

Éditez votre `server.cfg` ou `admins.json`:

```cfg
# ACE Permissions pour admins
add_ace group.superadmin vava allow
add_ace group.admin vava.kick allow
add_ace group.admin vava.ban allow
add_ace group.admin vava.teleport allow

# Ajouter votre identifier
add_principal identifier.license:YOUR_LICENSE group.superadmin
```

### Étape 5: Démarrer le serveur

```bash
# Lancer FiveM Server
./run.sh +exec server.cfg
```

---

## 🔧 Configuration Avancée

### config/config.lua

Personnalisez votre configuration:

```lua
Config.Branding = {
    Name = 'Votre Serveur',
    Logo = 'https://votre-domaine.com/logo.png',
    PrimaryColor = '#FF1E1E',
    Discord = 'https://discord.gg/votre-serveur'
}

Config.Players = {
    DefaultSpawn = {x = 195.52, y = -933.35, z = 29.69, heading = 144.0},
    StartingMoney = {
        cash = 5000,
        bank = 10000,
        black_money = 0
    }
}
```

### Modules

Activer/désactiver les modules dans `config.lua`:

```lua
Config.Modules = {
    Core = {
        economy = true,
        jobs = true,
        inventory = true,
        vehicles = true,
        status = true,
        hud = true
    },
    External = {
        police = true,
        garage = true,
        persist = true,
        keys = true,
        -- Autres modules...
    }
}
```

---

## 🎨 Personnalisation UI

### html/css/ui_manager.css

Changer les couleurs:

```css
:root {
    --vava-primary: #FF1E1E;      /* Rouge néon */
    --vava-secondary: #1E1E1E;    /* Gris foncé */
    --vava-background: #000000;   /* Noir profond */
    --vava-text: #FFFFFF;         /* Blanc */
}
```

---

## 📊 Vérification Installation

### Console Serveur

Vous devriez voir:

```
[vCore] Framework vAvA_core v1.0.0 chargé
[vCore:Database] Connexion MySQL établie
[vCore:Config] Configuration chargée
[vCore:Events] Système d'événements chargé (50+ événements)
[vCore:Permissions] Système de permissions chargé
[vCore:Validation] Système de validation chargé
[vCore:Players] Système joueurs initialisé
[vCore:Economy] Système économique démarré
[vCore:Jobs] 12 jobs chargés
[vCore:Inventory] 7 items de base chargés
[vCore:Commands] Système de commandes chargé (25 commandes)
```

### Base de données

Vérifier les tables créées:

```sql
SHOW TABLES;
```

Devrait afficher:
- `users`
- `characters`
- `items`
- `vehicles`
- `vehicle_keys`
- `job_grades`
- `logs`
- `bans`
- `transactions`
- `society_accounts`
- `system_info`
- `garages`
- `player_contacts`
- `player_notes`
- `billing`
- `properties`

### Test en jeu

1. Se connecter au serveur
2. Créer un personnage
3. Vérifier HUD en haut à droite
4. Tester commande: `/help`
5. Admin: Tester `/noclip`, `/tp <id>`

---

## 🔐 Configuration Permissions

### Méthode 1: ACE (Recommandée)

Dans `server.cfg`:

```cfg
# Super Admin (Propriétaire)
add_principal identifier.license:LICENSE_HERE group.superadmin
add_ace group.superadmin vava allow

# Admin
add_principal identifier.license:LICENSE_HERE group.admin
add_ace group.admin vava.kick allow
add_ace group.admin vava.ban allow
add_ace group.admin vava.teleport allow
add_ace group.admin vava.givemoney allow
add_ace group.admin vava.spawnvehicle allow

# Modérateur
add_principal identifier.license:LICENSE_HERE group.moderator
add_ace group.moderator vava.kick allow
add_ace group.moderator vava.teleport allow

# Helper
add_principal identifier.license:LICENSE_HERE group.helper
add_ace group.helper vava.teleport allow
```

### Méthode 2: Identifiers

Dans `config/config.lua`:

```lua
Config.Admin = {
    Method = 'identifiers',
    Groups = {
        superadmin = 5,
        admin = 3,
        moderator = 2,
        helper = 1,
        user = 0
    },
    Admins = {
        'license:YOUR_LICENSE_HERE',  -- Super Admin
        'license:ADMIN_LICENSE_HERE'  -- Admin
    }
}
```

---

## 🚨 Dépannage

### Erreur: "oxmysql not started"

```cfg
# S'assurer que oxmysql démarre avant vAvA_core
ensure oxmysql
ensure vAvA_core
```

### Erreur: "Failed to execute query"

Vérifier:
1. Connexion MySQL correcte
2. Base de données existe
3. Permissions utilisateur MySQL
4. Tables créées

```sql
-- Tester connexion
SELECT * FROM system_info;
```

### Erreur: "Player not loaded"

Vérifier:
1. Tables `users` et `characters` existent
2. Logs serveur pour erreurs SQL
3. Configuration `Config.Players.DefaultSpawn`

### UI ne s'affiche pas

Vérifier:
1. Fichiers `html/` présents
2. `ui_page` dans fxmanifest.lua
3. `files` déclarés dans fxmanifest.lua
4. Console F8 pour erreurs JavaScript

---

## 📦 Modules Additionnels

### Installation modules externes

1. **vAvA_garage**
```cfg
ensure vAvA_garage
```

2. **vAvA_persist** (persistance véhicules)
```cfg
ensure vAvA_persist
```

3. **vAvA_keys** (clés véhicules)
```cfg
ensure vAvA_keys
```

4. **vAvA_police** (menu police)
```cfg
ensure vAvA_police
```

**Ordre de chargement recommandé:**
```cfg
ensure oxmysql
ensure vAvA_core
ensure vAvA_persist
ensure vAvA_keys
ensure vAvA_garage
ensure vAvA_police
ensure vAvA_ems
# ... autres modules
```

---

## 🔄 Mise à jour

### Sauvegarde

Avant toute mise à jour:

```bash
# Sauvegarder base de données
mysqldump -u root -p vava_fivem > backup_$(date +%Y%m%d).sql

# Sauvegarder config
cp config/config.lua config/config.lua.bak
```

### Appliquer mise à jour

```bash
# Arrêter serveur
# Remplacer fichiers vAvA_core
# Importer migrations SQL si nécessaire
# Redémarrer serveur
```

### Auto-migrations

Le système détecte automatiquement les migrations manquantes:

```lua
-- database/migrations.lua
-- Les migrations s'exécutent automatiquement au démarrage
```

---

## 📊 Performance & Optimisation

### Recommandations MySQL

```cnf
[mysqld]
max_connections = 100
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
query_cache_size = 0
```

### Config vAvA_core

```lua
Config.Database = {
    ConnectionPool = {
        min = 2,
        max = 10
    },
    PreparedStatements = true,
    Cache = {
        enabled = true,
        TTL = 60
    }
}
```

---

## 🎯 Commandes Utiles

### Admin

```
/kick <id> [raison]
/ban <id> <durée> [raison]
/unban <identifier>
/tp <id>
/bring <id>
/car <model>
/dv
/fix
/givemoney <id> <type> <montant>
/setjob <id> <job> <grade>
/noclip
/godmode
```

### Joueur

```
/help
/me <action>
/do <description>
/clear
/report <message>
```

### Staff

```
/staff <message>  -- Chat staff uniquement
```

---

## 📞 Support

### Documentation

- [BASE_SOLIDE.md](doc/BASE_SOLIDE.md) - Documentation technique complète
- [ROADMAP.md](doc/ROADMAP.md) - Évolutions prévues
- [README.md](doc/README.md) - Guide utilisateur

### Logs

Vérifier les logs:

```bash
# Console serveur
tail -f server_log.txt

# Logs base de données
SELECT * FROM logs ORDER BY created_at DESC LIMIT 50;
```

### Discord Support

Rejoignez le Discord vAvA pour support et mises à jour:
https://discord.gg/vava (à configurer)

---

## ✅ Checklist Post-Installation

- [ ] Base de données créée et tables présentes
- [ ] oxmysql connecté et fonctionnel
- [ ] vAvA_core démarre sans erreur
- [ ] Personnage créé avec succès
- [ ] HUD visible en jeu
- [ ] Commandes /help fonctionnelle
- [ ] Permissions admin configurées
- [ ] UI Manager responsive (notifications, progress bars)
- [ ] Système économie fonctionnel (cash, bank)
- [ ] Jobs assignables (/setjob)
- [ ] Véhicules spawnables (/car)

---

## 🎉 Félicitations!

Votre framework vAvA_core est installé et prêt à l'emploi!

**Prochaines étapes:**
1. Personnaliser la configuration
2. Installer les modules additionnels
3. Configurer les jobs et salaires
4. Créer votre contenu custom
5. Tester en profondeur

---

*Guide d'installation v1.0.0 - 11/01/2025*
