# vAvA Core - Module JobShop

Système de boutiques pour jobs avec gestion admin/patron intégré au framework vAvA Core.

## Fonctionnalités

- **Multi-boutiques** : Création dynamique de boutiques pour différents jobs
- **Gestion patron** : Prix, stock, activation/désactivation d'articles
- **Caisse de boutique** : L'argent des ventes va dans la caisse, retrait par le patron
- **Approvisionnement** : Les employés peuvent ajouter du stock depuis leur inventaire
- **Administration** : Création/suppression de boutiques par les admins
- **PNJ vendeurs** : Spawn automatique de PNJ aux positions des boutiques
- **Blips dynamiques** : Affichage sur la carte

## Installation

Le module est automatiquement chargé par le core. Structure SQL requise :

```sql
CREATE TABLE IF NOT EXISTS `job_shops` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(100) NOT NULL,
    `job` VARCHAR(50) NOT NULL,
    `boss_grade` INT DEFAULT 0,
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT DEFAULT 0,
    `cash` INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS `job_shop_items` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `shop_id` INT NOT NULL,
    `item_name` VARCHAR(50) NOT NULL,
    `price` INT DEFAULT 0,
    `stock` INT DEFAULT 0,
    `enabled` TINYINT DEFAULT 1,
    FOREIGN KEY (`shop_id`) REFERENCES `job_shops`(`id`) ON DELETE CASCADE
);
```

## Exports Client

```lua
-- Ouvrir une boutique
exports['vAvA_core']:OpenJobShop(shopId)

-- Ouvrir le menu patron
exports['vAvA_core']:OpenBossMenu(shopId)

-- Ouvrir le menu stock (employé)
exports['vAvA_core']:OpenStockMenu(shopId)
```

## Exports Serveur

```lua
-- Récupérer toutes les boutiques
local shops = exports['vAvA_core']:GetShops()

-- Récupérer une boutique spécifique
local shop = exports['vAvA_core']:GetShopData(shopId)

-- Créer une boutique (via code)
exports['vAvA_core']:CreateShop({
    name = "Ma Boutique",
    job = "baker",
    boss_grade = 3,
    coords = { x = 100.0, y = 200.0, z = 30.0, w = 180.0 }
})

-- Supprimer une boutique
exports['vAvA_core']:DeleteShop(shopId)

-- Ajouter un item à une boutique
exports['vAvA_core']:AddShopItem(shopId, 'bread', 5, 100)

-- Modifier le prix d'un item
exports['vAvA_core']:UpdateItemPrice(shopId, 'bread', 10)

-- Ajouter du stock
exports['vAvA_core']:AddStock(shopId, 'bread', 50)
```

## Commandes

- `/jobshopadmin` - Ouvre le panel d'administration (admin only)
- `/jobshoplist` - Liste toutes les boutiques dans le chat (admin only)

## Configuration

Modifiez `config.lua` pour personnaliser :

- `AdminGroups` : Groupes ayant accès à l'administration
- `PedModel` : Modèle du PNJ vendeur
- `MaxItemsPerShop` / `MaxStockPerItem` : Limites
- `CurrencyType` : 'cash' ou 'bank'
- `InteractionDistance` : Distance d'interaction
- `Blip` : Configuration des blips sur la carte
- `Notifications` : Messages personnalisables

## Flux de fonctionnement

1. **Admin** crée une boutique via `/jobshopadmin`
2. **Patron** (boss_grade suffisant) configure les articles et prix
3. **Employés** approvisionnent le stock depuis leur inventaire
4. **Clients** achètent les articles
5. **Patron** retire l'argent de la caisse

## Intégrations

### ox_target
Si ox_target est présent, les interactions se font via le système de ciblage.

### ox_lib
Si ox_lib est présent, les notifications utilisent le système ox_lib.

### Inventaire
Compatible avec tout système d'inventaire utilisant les fonctions vCore standard.
