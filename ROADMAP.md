# vAvA_core - Feuille de Route Développeur

> **Dernière mise à jour:** 8 Janvier 2026  
> **Version actuelle:** 2.2.0  
> **Statut inventaire:** ⏸️ EN PAUSE

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
