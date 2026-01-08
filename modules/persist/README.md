# vAvA Core - Module Persist

Système de persistance des véhicules intégré au framework vAvA Core.

## Fonctionnalités

- **Persistance positions** : Les véhicules restent où ils sont laissés
- **Sauvegarde état** : Moteur, carrosserie, carburant préservés
- **Synchronisation mods** : Tuning et personnalisation conservés
- **Protection anti-NPC** : Évite les conflits avec les véhicules NPC
- **Localisation** : Retrouver son véhicule sur la carte
- **State Bags** : Synchronisation réseau optimisée

## Installation

Le module est automatiquement chargé par le core. Structure SQL requise :

```sql
-- Ajouter la colonne parking si elle n'existe pas
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `parking` TEXT NULL,
ADD COLUMN IF NOT EXISTS `last_update` DATETIME NULL;
```

## Configuration

Modifiez `config.lua` pour personnaliser :

- `Debug` : Mode debug
- `SaveInterval` : Intervalle de sauvegarde auto (ms)
- `RenderDistance` : Distance de rendu des véhicules
- `AbandonTimeout` : Délai avant abandon
- `AntiNPCCollision` : Protection contre plaques NPC
- `JobServiceVehicles` : Véhicules de service non persistés

## Exports Client

```lua
-- Sauvegarder la position du véhicule actuel
exports['vAvA_core']:SaveVehiclePosition()

-- Avec plaque spécifique
exports['vAvA_core']:SaveVehiclePosition('ABC123')

-- Récupérer les véhicules persistants
local vehicles = exports['vAvA_core']:GetPersistentVehicles()

-- Localiser un véhicule sur la carte
exports['vAvA_core']:LocateVehicle('ABC123')

-- Vérifier si c'est un véhicule joueur
local isPlayer = exports['vAvA_core']:IsPlayerVehicle(vehicle)
```

## Exports Serveur

```lua
-- Sauvegarder un véhicule
exports['vAvA_core']:SaveVehicle('ABC123', {
    coords = vector3(100.0, 200.0, 30.0),
    heading = 90.0,
    engine = 1000,
    body = 1000,
    fuel = 100
})

-- Récupérer les véhicules spawnés
local spawned = exports['vAvA_core']:GetSpawnedVehicles()

-- Enregistrer un véhicule joueur
exports['vAvA_core']:RegisterPlayerVehicle('ABC123', netId, citizenid)

-- Désenregistrer un véhicule
exports['vAvA_core']:UnregisterPlayerVehicle('ABC123')

-- Vérifier si c'est un véhicule joueur
local isPlayer = exports['vAvA_core']:IsPlayerVehicle('ABC123')
```

## États de stockage

La colonne `stored` dans `player_vehicles` :
- `0` : En fourrière
- `1` : Au garage
- `2` : Sorti, position inconnue
- `3` : Sorti, position sauvegardée (persistant)

## State Bags

Le module utilise les State Bags pour synchroniser :
- `engine` : Santé moteur
- `body` : Santé carrosserie
- `fuel` : Niveau carburant
- `mods` : Modifications visuelles/performance
- `tuning` : Données de tuning

## Intégrations

### Module Garage
Le garage met à jour `stored` et `parking` lors des opérations.

### Module Keys
Les clés sont préservées pour les véhicules persistants.

### Scripts Fuel
Compatible avec LegacyFuel et lc_fuel.

## Protection Anti-NPC

Le module vérifie plusieurs critères pour éviter d'appliquer des mods aux véhicules NPC :
1. Mission Entity (les véhicules joueurs sont toujours marqués)
2. State Bag `isPlayerVehicle`
3. Véhicule networké
