# vAvA_core - Feuille de Route Développeur

> **Dernière mise à jour:** 28 Janvier 2025  
> **Version actuelle:** 2.1.0

---

## 📋 Tâches en cours

### Module: `inventory`

| Statut | Tâche | Fichier(s) | Priorité |
|--------|-------|------------|----------|
| ✅ | Corriger fonction "Utiliser" items consommables | `server/main.lua`, `client/main.lua` | HAUTE |
| ✅ | Corriger Drag & Drop | `html/js/app.js` | HAUTE |
| ✅ | Choisir case raccourci (modal) | `html/js/app.js`, `html/index.html` | MOYENNE |
| ✅ | Corriger "Donner" + vérif proximité | `client/main.lua`, `server/main.lua` | HAUTE |

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
- [x] Drag & Drop amélioré avec feedback visuel
- [x] Modal de sélection hotbar
- [x] GiveItem avec vérification proximité et notifications

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
