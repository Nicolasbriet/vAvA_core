# vAvA_inventory - Système d'inventaire moderne

## Description
Système d'inventaire complet et moderne pour FiveM, intégré au framework vAvA_core.

## Fonctionnalités

### Interface utilisateur
- ✨ Design moderne glassmorphism
- 🖱️ Drag & Drop complet
- 📱 Interface responsive
- 🎨 Animations fluides
- 🌙 Thème sombre élégant

### Gestion des items
- 📦 Stack automatique des items
- 🔢 Quantités configurables
- ⚖️ Système de poids
- 🎁 Donner des items aux autres joueurs
- 🗑️ Jeter des items au sol
- ✂️ Diviser les stacks

### Système d'armes
- 🔫 Gestion complète des armes GTA V
- 🎯 Différents types de munitions par arme
- ❌ Désactivation de la roue des armes native
- ⚔️ Animation d'équipement
- 💾 Synchronisation des munitions

### Hotbar (Raccourcis)
- 🔢 Slots 1-5 configurables
- ⚡ Accès rapide aux items
- 🖱️ Drag & drop depuis l'inventaire

## Installation

1. Placez le dossier `vAvA_inventory` dans votre dossier `resources/[vAvA]/`
2. Ajoutez `ensure vAvA_inventory` dans votre `server.cfg` après `ensure vAvA_core`
3. Redémarrez le serveur

## Configuration

Éditez le fichier `config.lua` pour personnaliser :

```lua
InventoryConfig = {
    MaxSlots = 40,           -- Nombre de slots
    MaxWeight = 100,         -- Poids maximum (kg)
    OpenKey = 'F2',          -- Touche pour ouvrir
    
    Hotbar = {
        enabled = true,
        keys = {'1', '2', '3', '4', '5'}
    },
    
    Weapons = {
        disableWeaponWheel = true,   -- Désactiver la roue des armes
        requireAmmo = true,          -- Nécessite des munitions
    }
}
```

## Types de munitions

| Type | Armes compatibles |
|------|-------------------|
| PISTOL | Pistolets, revolvers |
| SMG | Pistolets-mitrailleurs |
| RIFLE | Fusils d'assaut |
| SHOTGUN | Fusils à pompe |
| SNIPER | Fusils de précision |
| MG | Mitrailleuses |

## Exports (Server)

```lua
-- Ajouter un item
exports.vAvA_inventory:AddItem(source, 'bread', 5)

-- Retirer un item
exports.vAvA_inventory:RemoveItem(source, 'bread', 2)

-- Vérifier si le joueur a un item
local hasItem = exports.vAvA_inventory:HasItem(source, 'bread', 1)

-- Obtenir la quantité d'un item
local count = exports.vAvA_inventory:GetItemCount(source, 'bread')

-- Enregistrer un callback d'utilisation d'item
exports.vAvA_inventory:RegisterItemCallback('bread', function(source, item)
    -- Action quand le joueur utilise le pain
    TriggerClientEvent('vAvA:notify', source, 'Miam !', 'success')
end)
```

## Exports (Client)

```lua
-- Vérifier si l'inventaire est ouvert
local isOpen = exports.vAvA_inventory:IsInventoryOpen()

-- Obtenir l'inventaire du joueur
local inventory = exports.vAvA_inventory:GetPlayerInventory()

-- Obtenir l'arme équipée
local weapon = exports.vAvA_inventory:GetCurrentWeapon()
```

## Ajouter des images d'items

Placez vos images PNG dans `html/img/items/`:
- Nommez-les avec le nom de l'item en minuscules
- Exemple: `bread.png`, `water.png`, `weapon_pistol.png`
- Taille recommandée: 64x64 ou 128x128 pixels

## Commandes admin

| Commande | Description |
|----------|-------------|
| `/giveitem [id] [item] [amount]` | Donner un item à un joueur |
| `/clearinventory [id]` | Vider l'inventaire d'un joueur |

## Structure des fichiers

```
vAvA_inventory/
├── fxmanifest.lua
├── config.lua
├── README.md
├── client/
│   ├── main.lua      (Interface, keybinds, armes)
│   └── drops.lua     (Items au sol)
├── server/
│   └── main.lua      (Callbacks, BDD, exports)
├── shared/
│   └── functions.lua (Fonctions utilitaires)
└── html/
    ├── index.html
    ├── css/
    │   └── style.css
    ├── js/
    │   └── app.js
    └── img/
        └── items/
            └── default.png
```

## Dépendances

- vAvA_core
- oxmysql

## Licence

Ce script fait partie du framework vAvA_core.
