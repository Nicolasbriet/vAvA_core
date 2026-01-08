# vAvA Core - Module Garage

Système de garage et fourrière intégré au framework vAvA Core.

## Fonctionnalités

- **Multi-types** : Voitures, bateaux, hélicoptères, avions
- **Garages dynamiques** : Création via panel admin
- **Fourrière** : Système de mise en fourrière par police/mechanic
- **Persistance** : État du véhicule sauvegardé (fuel, dégâts)
- **Intégration clés** : Clés automatiques à la sortie
- **Interface moderne** : NUI responsive

## Installation

Le module est automatiquement chargé par le core. Ajoutez dans votre `server.cfg` :

```cfg
ensure vAvA_core
```

## Configuration

Modifiez `modules/garage/config.lua` pour configurer :

- Garages statiques et fourrières
- Prix de sortie de fourrière
- Jobs autorisés pour la fourrière
- Types de véhicules

## Exports Client

```lua
-- Ouvrir un garage
exports['vAvA_core']:OpenGarage('legion')

-- Ouvrir une fourrière
exports['vAvA_core']:OpenImpound('fourriere')

-- Ranger le véhicule actuel
exports['vAvA_core']:StoreVehicle('legion')
```

## Exports Serveur

```lua
-- Récupérer les véhicules d'un joueur
local vehicles = exports['vAvA_core']:GetPlayerVehicles(citizenid, 'legion')

-- Mettre un véhicule en fourrière
exports['vAvA_core']:ImpoundVehicle('ABC123', 'fourriere')

-- Sortir de fourrière
exports['vAvA_core']:ReleaseFromImpound('ABC123', 'legion')

-- Récupérer tous les garages
local garages = exports['vAvA_core']:GetGarages()

-- Ajouter un garage dynamique
exports['vAvA_core']:AddGarage('mon_garage', {
    label = "Mon Garage",
    position = vector3(100.0, 200.0, 30.0),
    vehicleType = 'car',
    showBlip = true,
    spawns = {vector4(105.0, 200.0, 30.0, 90.0)}
})
```

## Commandes

- `/garageadmin` - Ouvre le panel d'administration (admin only)

## Structure de la BDD

Le module utilise la table `player_vehicles`. Structure requise :

```sql
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50),
    `vehicle` VARCHAR(50),
    `plate` VARCHAR(10),
    `mods` TEXT,
    `fuel` INT DEFAULT 100,
    `engine` FLOAT DEFAULT 1000.0,
    `body` FLOAT DEFAULT 1000.0,
    `stored` INT DEFAULT 1,
    `garage` VARCHAR(50),
    `type` VARCHAR(20) DEFAULT 'car',
    `last_update` DATETIME
);
```

## Intégrations

### Module Keys
Les clés sont automatiquement données à la sortie du garage.

### Module Persist
Compatible avec le système de persistance pour éviter le despawn.

### Scripts Fuel
Compatible avec LegacyFuel et lc_fuel.
