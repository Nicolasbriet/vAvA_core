# ⚡ vAvA_core - Framework FiveM Moderne

<div align="center">

![Version](https://img.shields.io/badge/version-1.0.0-red.svg)
![Lua](https://img.shields.io/badge/lua-5.4-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Status](https://img.shields.io/badge/status-Production%20Ready-success.svg)

**Framework FiveM modulaire, sécurisé et haute performance**

[Documentation](#-documentation) • [Installation](#-installation-rapide) • [Features](#-fonctionnalités) • [Support](#-support)

</div>

---

## 📖 À propos

vAvA_core est un framework FiveM moderne conçu pour offrir une base solide et extensible pour votre serveur. Développé avec Lua 5.4, il intègre les meilleures pratiques de développement et une architecture modulaire permettant une personnalisation complète.

### 🎯 Philosophie

- **Performance** - Optimisé pour des performances maximales (connection pooling, cache, requêtes optimisées)
- **Sécurité** - Anti-cheat intégré, validation des données, rate limiting, logs Discord
- **Modularité** - Architecture modulaire permettant d'activer/désactiver fonctionnalités
- **Scalabilité** - Conçu pour supporter un grand nombre de joueurs simultanés
- **Developer-Friendly** - API claire, documentation complète, exports nombreux

---

## ✨ Fonctionnalités

### 🎮 Système Core

- ✅ **Système joueurs** complet (multi-personnages, sauvegarde auto)
- ✅ **Économie** (cash, banque, argent sale, transactions, taxes)
- ✅ **Emplois** (police, ambulance, mécano + grades et permissions)
- ✅ **Inventaire** (poids, slots, items utilisables, métadonnées)
- ✅ **Véhicules** (ownership, garages, clés, persistance, assurance)
- ✅ **Statuts** (faim, soif, stress avec effets)

### 🎨 Interface

- ✅ **UI Manager centralisé** (1630 lignes)
- ✅ **Notifications** (4 types: success, error, warning, info)
- ✅ **Progress bars** (animations, props, annulation)
- ✅ **Prompts & Input** dialogs
- ✅ **HUD dynamique** (santé, armure, faim, soif, argent)
- ✅ **Texte 3D** et markers optimisés
- ✅ **Thème vAvA** (rouge néon #FF1E1E, effets glow, scanline)

### 🔒 Sécurité

- ✅ **Système de permissions ACE** (6 niveaux: USER → SUPER_ADMIN)
- ✅ **Anti-trigger** serveur
- ✅ **Rate limiting** (5 req/sec par défaut)
- ✅ **Validation** complète des données (types, patterns, sanitization)
- ✅ **Logs Discord** (erreurs, économie, admin, sécurité)
- ✅ **Système de bans** (temporaires/permanents)

### 🛠️ Outils Admin

- ✅ **25+ commandes** (kick, ban, teleport, givemoney, setjob, etc.)
- ✅ **Chat staff** privé
- ✅ **Système de reports** joueurs
- ✅ **Logs complets** (actions, économie, connexions)
- ✅ **Gestion véhicules** (spawn, delete, repair)

### 🔧 Système technique

- ✅ **Database Layer** complet (Query, Insert, Update, Delete, Transactions, Async)
- ✅ **Cache système** (TTL configurable)
- ✅ **Auto-migrations** SQL
- ✅ **Connection pool** MySQL (min: 2, max: 10)
- ✅ **Prepared statements**
- ✅ **50+ événements** centralisés
- ✅ **Callbacks sécurisés** avec rate limiting

---

## 📦 Installation Rapide

### Prérequis

- FiveM Server (dernière version)
- MySQL 8.0+ ou MariaDB 10.5+
- oxmysql (dernière version)

### Installation en 3 étapes

```bash
# 1. Copier dans resources/
cp -r vAvA_core /path/to/server/resources/

# 2. Importer la base de données
mysql -u root -p your_database < database/sql/install_complete.sql

# 3. Configurer server.cfg
```

**server.cfg:**
```cfg
# MySQL
set mysql_connection_string "mysql://user:password@localhost/database?charset=utf8mb4"

# Resources
ensure oxmysql
ensure vAvA_core
```

➡️ [**Guide d'installation complet**](doc/INSTALLATION.md)

---

## 📚 Documentation

### Guides

- [📘 Installation complète](doc/INSTALLATION.md) - Guide pas-à-pas détaillé
- [🏗️ Base Solide](doc/BASE_SOLIDE.md) - Documentation technique (systèmes, API, classes)
- [🎨 UI Manager](doc/UI_MANAGER_GUIDE.md) - Guide UI complet avec exemples
- [🗺️ Roadmap](doc/ROADMAP.md) - Évolutions prévues

### Configuration

- [⚙️ config/config.lua](config/config.lua) - Configuration centrale (16 sections)
- [🌍 locales/](locales/) - Traductions (fr, en, es)

### Exemples

```lua
-- Récupérer un joueur
local player = vCore.GetPlayer(source)

-- Vérifier permissions
if player:HasPermission(vCore.PermissionLevel.ADMIN) then
    -- Admin actions
end

-- Ajouter de l'argent
player:AddMoney('cash', 5000, 'Salaire')

-- Notification
vCore.UI.Notify(source, 'Action réussie!', 'success')

-- Progress bar
vCore.UI.ShowProgressBar(source, 'Réparation...', 5000, {
    canCancel = true,
    animation = {dict = 'mini@repair', name = 'fixing_a_player'},
    onComplete = function()
        print('Terminé!')
    end
})
```

---

## 🎯 Modules Compatibles

Le framework est compatible avec ces modules vAvA:

| Module | Description | Status |
|--------|-------------|--------|
| **vAvA_garage** | Système garages complet | ✅ Compatible |
| **vAvA_persist** | Persistance véhicules | ✅ Compatible |
| **vAvA_keys** | Gestion clés véhicules | ✅ Compatible |
| **vAvA_police** | Menu police | ✅ Compatible |
| **vAvA_ems** | Menu ambulance | ✅ Compatible |
| **vAvA_jobshop** | Boutique emplois | ✅ Compatible |
| **vAvA_sit** | Animation s'asseoir | ✅ Compatible |

---

## 🔧 Configuration

### Structure Config

```lua
Config = {
    -- Identité
    Branding = {...},
    
    -- Joueurs
    Players = {
        DefaultSpawn = {...},
        StartingMoney = {...},
        StartingStatus = {...}
    },
    
    -- Économie
    Economy = {
        MaxCash = 1000000000,
        MoneyTypes = {'cash', 'bank', 'black_money'},
        Taxes = {...}
    },
    
    -- Jobs & Grades
    Jobs = {...},
    
    -- Inventaire
    Inventory = {
        MaxWeight = 40000,
        MaxSlots = 50
    },
    
    -- Véhicules
    Vehicles = {...},
    
    -- UI Manager
    UI = {
        Notifications = {...},
        ProgressBar = {...},
        HUDUpdate = {...}
    },
    
    -- Modules
    Modules = {
        Core = {...},
        External = {...}
    },
    
    -- Permissions
    Permissions = {...},
    
    -- Et plus encore...
}
```

---

## 🎨 Personnalisation UI

### Thème vAvA par défaut

```css
:root {
    --vava-primary: #FF1E1E;      /* Rouge néon */
    --vava-secondary: #1E1E1E;
    --vava-background: #000000;
    --vava-text: #FFFFFF;
    --vava-glow: 0 0 20px #FF1E1E;
}
```

### Modifier les couleurs

Éditez [html/css/ui_manager.css](html/css/ui_manager.css) pour personnaliser:
- Couleurs primaires/secondaires
- Effets glow et scanline
- Animations
- Polices

---

## 📊 Performance

### Optimisations intégrées

- ✅ **Connection pool MySQL** (2-10 connexions)
- ✅ **Prepared statements** pour toutes les requêtes
- ✅ **Cache système** (TTL: 60s, configurable)
- ✅ **Requêtes async** pour opérations longues
- ✅ **Rate limiting** sur callbacks (protection DDoS)
- ✅ **Garbage collection** optimisé
- ✅ **Distance-based rendering** (3D text, markers)

### Benchmarks

- **Players concurrent:** 128+ joueurs testés
- **TPS:** Stable 30 FPS minimum côté client
- **Memory:** ~50MB baseline
- **Database:** <10ms par requête (pooling)

---

## 🛡️ Sécurité

### Mesures implémentées

1. **Validation complète**
   - Types (number, string, boolean, table)
   - Patterns (email, phone, plate, date)
   - Game data (money, jobs, items)
   - Sanitization SQL & HTML

2. **Anti-cheat**
   - Anti-trigger serveur
   - Rate limiting (5 req/sec)
   - Verification permissions
   - Logs toutes actions sensibles

3. **Permissions**
   - Système ACE intégré
   - 6 niveaux (USER → SUPER_ADMIN)
   - Permissions job (police, ems, mechanic)
   - Fallback groups

---

## 🤝 Contribution

Les contributions sont les bienvenues! Veuillez suivre ces étapes:

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit changements (`git commit -m 'Add AmazingFeature'`)
4. Push vers branche (`git push origin feature/AmazingFeature`)
5. Ouvrir Pull Request

### Standards de code

- **Lua 5.4** syntax
- **LuaLS** annotations (@param, @return)
- **Commentaires** en français
- **Indentation** 4 espaces
- **Naming:** camelCase pour fonctions, PascalCase pour classes

---

## 📞 Support

### Documentation

- [Installation complète](doc/INSTALLATION.md)
- [Documentation technique](doc/BASE_SOLIDE.md)
- [UI Manager Guide](doc/UI_MANAGER_GUIDE.md)

### Communauté

- **Discord:** [Rejoindre le serveur](https://discord.gg/vava)
- **GitHub Issues:** [Signaler un bug](https://github.com/vava/vAvA_core/issues)
- **Wiki:** [Documentation communautaire](https://github.com/vava/vAvA_core/wiki)

### Logs & Debugging

```lua
-- Activer mode debug
Config.Debug = true

-- Voir logs serveur
tail -f server_log.txt

-- Voir logs base de données
SELECT * FROM logs ORDER BY created_at DESC LIMIT 50;
```

---

## 📄 Licence

Ce projet est sous licence **MIT** - voir le fichier [LICENSE](LICENSE) pour détails.

---

## 🌟 Crédits

**Développé avec ❤️ par l'équipe vAvA**

### Technologies utilisées

- [FiveM](https://fivem.net/) - Plateforme GTA V multiplayer
- [oxmysql](https://github.com/overextended/oxmysql) - Database wrapper
- [Lua 5.4](https://www.lua.org/) - Langage de programmation

### Remerciements

Merci à tous les contributeurs et testeurs qui ont aidé à améliorer ce framework!

---

## 📈 Statistiques

- **Version:** 1.0.0
- **Lignes de code:** ~5000+ (core uniquement)
- **Fichiers:** 40+ (shared, server, client, html)
- **Fonctions:** 150+ exports
- **Événements:** 50+ événements
- **Commandes:** 25+ commandes admin/joueur

---

## 🗺️ Roadmap

### Version 1.1 (Prochainement)

- [ ] Admin panel NUI complet
- [ ] Système propriétés
- [ ] Crafting système
- [ ] Achievements système
- [ ] Mobile app integration

### Version 2.0 (Futur)

- [ ] Multiserveur support
- [ ] API REST externe
- [ ] Dashboard web admin
- [ ] Statistiques avancées
- [ ] IA anti-cheat

➡️ [**Roadmap complète**](doc/ROADMAP.md)

---

<div align="center">

**⭐ Si vous aimez ce projet, n'oubliez pas de lui donner une étoile! ⭐**

Made with ❤️ for the FiveM community

[⬆ Retour en haut](#-vava_core---framework-fivem-moderne)

</div>
