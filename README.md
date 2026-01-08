# 🎮 vAvA_core - Framework FiveM

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/FiveM-Ready-green.svg" alt="FiveM Ready">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

Un framework FiveM complet et moderne, alternative à ESX et QBCore.

## ✨ Fonctionnalités

- 🔐 **Système de joueurs** - Classe vPlayer avec méthodes complètes
- 💰 **Économie** - Cash, Banque, Argent sale
- 👔 **Jobs** - Système de métiers avec grades et salaires
- 🎒 **Inventaire** - Système d'items avec poids et slots
- 🚗 **Véhicules** - Garage, propriétés, états
- 🛡️ **Sécurité** - Rate limiting, anti-exploit, bans
- 🌍 **Multilingue** - Français, Anglais, Espagnol
- 📊 **HUD** - Interface moderne avec NUI
- 📝 **Logs** - Système de logs + Discord webhook

## 📋 Prérequis

- [FiveM Server](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
- [oxmysql](https://github.com/overextended/oxmysql/releases)
- MySQL/MariaDB (XAMPP, HeidiSQL, etc.)

## 🚀 Installation Rapide

### Option 1 : txAdmin Recipe (Recommandé)

1. Dans txAdmin, allez dans **Recipe Deployer**
2. Sélectionnez **Local Recipe** et choisissez `vava_core.yaml`
3. Remplissez les informations de la base de données
4. txAdmin s'occupe du reste !

> 📁 Le fichier `vava_core.yaml` est inclus dans ce package

### Option 2 : Installateur automatique (Windows)

1. Double-cliquez sur `install.bat`
2. Suivez les instructions
3. C'est prêt !

### Option 3 : Installation manuelle

1. **Créer la base de données**
```sql
CREATE DATABASE vava_core CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

2. **Importer les tables**
```bash
mysql -u root -p vava_core < database/sql/init_simple.sql
```

3. **Configurer server.cfg**
```cfg
set mysql_connection_string "mysql://root@localhost/vava_core"

ensure oxmysql
ensure vAvA_core
```

4. **Lancer le serveur**

## 📁 Structure

```
vAvA_core/
├── fxmanifest.lua          # Manifest
├── config/
│   └── config.lua          # Configuration
├── locales/                # Langues
├── shared/                 # Classes & Utils
├── database/               # DAL & Migrations
├── server/                 # Scripts serveur
├── client/                 # Scripts client
├── utils/                  # Outils debug
└── html/                   # Interface NUI
```

## 🔧 Configuration

Éditez `config/config.lua` pour personnaliser :

```lua
Config = {}

Config.Debug = false
Config.Locale = 'fr'

Config.StartingMoney = {
    cash = 5000,
    bank = 10000,
    black_money = 0
}

Config.DefaultSpawn = vector4(-269.4, -955.3, 31.2, 205.0)
```

## 📚 API / Exports

### Server

```lua
-- Récupérer un joueur
local player = exports['vAvA_core']:GetPlayer(source)

-- Argent
player:GetMoney('cash')
player:AddMoney('cash', 1000)
player:RemoveMoney('bank', 500)

-- Job
player:GetJob()
player:SetJob('police', 2)

-- Inventaire
player:HasItem('phone')
player:AddItem('bread', 5)
player:RemoveItem('water', 1)
```

### Client

```lua
-- Notifications
exports['vAvA_core']:Notify('Message', 'success')

-- Callbacks
exports['vAvA_core']:TriggerCallback('vCore:getPlayerData', function(data)
    print(data.money.cash)
end)
```

## 🎮 Commandes

| Commande | Description | Permission |
|----------|-------------|------------|
| `/givemoney [id] [type] [amount]` | Donner de l'argent | admin |
| `/setjob [id] [job] [grade]` | Définir un job | admin |
| `/giveitem [id] [item] [amount]` | Donner un item | admin |
| `/tp [x] [y] [z]` | Téléportation | admin |
| `/car [model]` | Spawn véhicule | admin |
| `/dv` | Supprimer véhicule | admin |
| `/me [action]` | Action RP | user |
| `/ooc [message]` | Message HRP | user |

## 🔒 Sécurité

- Rate limiting sur les events
- Validation server-side
- Anti-trigger spam
- Système de bans avec expiration
- Logs Discord automatiques

## 📝 Logs Discord

Configurez le webhook dans `config/config.lua` :

```lua
Config.DiscordWebhook = 'https://discord.com/api/webhooks/...'
Config.DiscordLogs = {
    money = true,
    jobs = true,
    admin = true,
    connections = true
}
```

## 🤝 Support

- Discord : [Votre serveur Discord]
- Documentation : [Lien vers la doc]

## 📄 License

MIT License - Libre d'utilisation et modification.

---

<p align="center">
  Fait avec ❤️ pour la communauté FiveM
</p>
