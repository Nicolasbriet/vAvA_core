# vAvA_core - Feuille de Route Développeur

> **Dernière mise à jour:** 8 Janvier 2026  
> **Version actuelle:** 2.4.0  
> **Statut:** ✅ INTÉGRATION MODULES TERMINÉE

---

## ✅ PROJET TERMINÉ - Intégration Scripts [vAvA] en Modules

### Vue d'ensemble
Objectif: Adapter tous les scripts du dossier [vAvA] en modules intégrés au vAvA_core.

| Module | Script Source | Statut | Fichiers |
|--------|---------------|--------|----------|
| `chat` | vAvA_chat | ✅ Terminé | 7 fichiers |
| `concess` | vAvA_Concess | ✅ Terminé | 9 fichiers |
| `garage` | vAvA_garage | ✅ Terminé | 9 fichiers |
| `keys` | vAvA_keys | ✅ Terminé | 9 fichiers |
| `jobshop` | vAvA_jobshop | ✅ Terminé | 8 fichiers |
| `persist` | vAvA_persist | ✅ Terminé | 5 fichiers |
| `sit` | vAvA_sit | ✅ Terminé | 6 fichiers |

**Total: 7 modules, 53 fichiers créés**

---

## 📊 DÉTAILS DES MODULES CRÉÉS

### 1. Module Chat (vAvA_chat → modules/chat/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, html/index.html, html/css/style.css, html/js/app.js

**Fonctionnalités:**
- 💬 Commandes RP: /me, /do, /ooc, /mp
- 👮 Canaux métiers: /police, /ems, /staff
- 📍 Messages par proximité (20m)
- 🎨 Interface NUI avec onglets par type de message
- ⌨️ Suggestions de commandes

**Exports:** OpenChat, SendMessage, SetChatVisible

---

### 2. Module Keys (vAvA_keys → modules/keys/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, html/index.html, html/css/style.css, html/js/app.js, database.sql, README.md

**Fonctionnalités:**
- 🔑 Clés permanentes et temporaires
- 🔒 Verrouillage/Déverrouillage (touche L)
- ⚙️ Contrôle moteur (touche G)
- 👥 Partage de clés avec interface ox_lib
- 💾 Auto-création tables BDD

**Exports Server:** GiveKeys, RemoveKeys, HasKeys, ShareKeys, GetPlayerKeys
**Exports Client:** ToggleLock, ToggleEngine, OpenVehicleUI

---

### 3. Module Concess (vAvA_Concess → modules/concess/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, html/index.html, html/css/style.css, html/js/app.js, vehicles.json, README.md

**Fonctionnalités:**
- 🚗 Multi-types: voitures, bateaux, hélicoptères, avions
- 🎥 Caméra preview avec rotation 360°
- 💳 Paiement cash ou banque
- 🔑 Intégration automatique des clés

**Exports:** OpenDealership, CloseDealership, GetVehicles, AddVehicle, RemoveVehicle

---

### 4. Module Garage (vAvA_garage → modules/garage/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, html/index.html, html/css/style.css, html/js/app.js, garages.json, README.md

**Fonctionnalités:**
- 🏠 Garages dynamiques créés via interface admin
- 🚔 Fourrière police avec ox_target
- 💰 Prix de sortie fourrière configurable
- 📍 Blips sur la carte

**Exports:** OpenGarage, OpenImpound, StoreVehicle, SpawnVehicle, GetGarages, AddGarage

---

### 5. Module JobShop (vAvA_jobshop → modules/jobshop/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, html/index.html, html/css/style.css, html/js/app.js, README.md

**Fonctionnalités:**
- 🏪 Boutiques spécialisées par job
- 💼 Gestion par patrons (prix, finances)
- 📦 Approvisionnement par employés
- 💰 Coffre de boutique avec retrait

**Exports:** GetShops, GetShopData, CreateShop, DeleteShop, AddShopItem, UpdateItemPrice

---

### 6. Module Persist (vAvA_persist → modules/persist/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, README.md

**Fonctionnalités:**
- 💾 Sauvegarde position/état véhicules
- 🔄 Restauration au redémarrage
- 🛡️ Protection anti-collision NPC
- 🔗 State bags pour synchronisation

**Exports:** SaveVehicle, GetSpawnedVehicles, RegisterPlayerVehicle, IsPlayerVehicle

---

### 7. Module Sit (vAvA_sit → modules/sit/)
**Fichiers:** fxmanifest.lua, config.lua, server/main.lua, client/main.lua, sit_points.json, README.md

**Fonctionnalités:**
- 🪑 Points d'assise configurables via interface admin
- 🎭 8 animations d'assise différentes
- 👻 Mode édition avec ghost ped et caméra libre
- 📍 Intégration ox_target

**Exports:** OpenSitMenu, ToggleEditMode, SitDown, StandUp, CreateSitPoint, DeleteSitPoint

---

## ⏸️ EN PAUSE - Module Inventaire

### Tâches restantes à faire

| Priorité | Tâche | Description |
|----------|-------|-------------|
| 🔴 HAUTE | Interface Admin NUI | Panel admin pour créer/modifier/supprimer des items facilement (pas en commande) |
| 🔴 HAUTE | Drag & Drop placement | Pouvoir déplacer un item vers n'importe quel slot vide de son choix |
| 🟠 MOYENNE | Sauvegarde au restart | S'assurer que les items sont bien sauvegardés quand on restart la ressource |
| 🟠 MOYENNE | Métadonnées items | Ajouter système de metadata (durabilité, numéro série arme, etc.) |

---

## ✅ Tâches terminées

### Module: `inventory`
- [x] Création système inventaire complet
- [x] Items en base de données (pas fichiers)
- [x] Commandes admin (/createitem, /giveitem, etc.)
- [x] Images SVG par défaut intégrées
- [x] Money = item stackable
- [x] Items de base pour nouveaux joueurs
- [x] Protection null hotbar
- [x] UseItem envoie le slot correctement
- [x] Drag & Drop basique avec feedback visuel
- [x] Modal de sélection hotbar
- [x] GiveItem avec vérification proximité et notifications
- [x] Désactivation roue des armes native
- [x] Hotbar cachée (raccourcis 1-5 fonctionnels)
- [x] Système faim/soif avec animations
- [x] Fermeture auto inventaire lors consommation

### Core: `vAvA_core`
- [x] Correction Wait(0) dans debug.lua
- [x] Correction Wait(0) dans hud.lua
- [x] Recipe txAdmin fonctionnel

---

## 🐛 Bugs connus

| Module | Description | Statut |
|--------|-------------|--------|
| inventory | ~~UseItem ne consomme pas les items food/drink~~ | ✅ Résolu |
| inventory | ~~Drag & Drop ne fonctionne pas~~ | ✅ Résolu |
| inventory | ~~GiveItem ne vérifie pas proximité~~ | ✅ Résolu |
| inventory | ~~Modal hotbar manquante~~ | ✅ Résolu |

---

## 📁 Structure des modifications

```
modules/inventory/
├── client/main.lua      ← NUI callbacks, useItem, giveItem proximité
├── server/main.lua      ← AddItem, RemoveItem, UseItem, GiveItem logic
├── html/
│   ├── js/app.js        ← Drag&Drop, Hotbar modal, Actions
│   ├── css/style.css    ← Styles modal hotbar
│   └── index.html       ← Modal sélection hotbar
└── config.lua           ← Configuration
```

---

## 📝 Notes techniques

### Inventaire - Architecture
- **Cache mémoire**: Inventaires chargés en RAM au login
- **MySQL.Async**: Toutes les requêtes sont async (pas de blocage)
- **Images**: SVG en base64 intégrés dans app.js

### Events importants
- `vAvA_inventory:requestInventory` - Ouvrir inventaire
- `vAvA_inventory:useItem` - Utiliser item
- `vAvA_inventory:moveItem` - Déplacer item
- `vAvA_inventory:giveItem` - Donner item à joueur proche
- `vAvA_inventory:setHotbar` - Définir raccourci

---

## 🔄 Historique des versions

### v2.0.0 (8 Jan 2026)
- Refonte complète inventaire
- Items en BDD
- Suppression threads (anti-freeze)

### v1.0.0 (Initial)
- Framework de base
- HUD, Notifications, Callbacks
