# vAvA Core - Module Concessionnaire

Système de vente de véhicules intégré au framework vAvA Core.

## Fonctionnalités

- **Multi-types** : Voitures, bateaux, hélicoptères, avions
- **Concessionnaires civils et job** : Séparation des véhicules publics et professionnels
- **Preview 3D** : Visualisation du véhicule avec rotation
- **Personnalisation** : Couleurs primaires/secondaires et livrées
- **Paiement** : Espèces ou banque via vCore Economy
- **Administration** : Panel de gestion des véhicules
- **Persistance** : Intégration automatique avec vAvA_persist

## Installation

Le module est automatiquement chargé par le core. Ajoutez dans votre `server.cfg` :

```cfg
ensure vAvA_core
```

## Configuration

Modifiez `modules/concess/config.lua` pour configurer :

- Positions des concessionnaires
- Types de véhicules par catégorie
- Permissions admin
- Intégration avec les clés et la persistance

## Exports Client

```lua
-- Ouvrir un concessionnaire spécifique
exports['vAvA_core']:OpenDealership('cars_civilian')

-- Fermer le concessionnaire
exports['vAvA_core']:CloseDealership()

-- Vérifier si le NUI est ouvert
local isOpen = exports['vAvA_core']:IsNUIOpen()
```

## Exports Serveur

```lua
-- Récupérer la liste des véhicules
local vehicles = exports['vAvA_core']:GetVehicles()

-- Ajouter un véhicule
exports['vAvA_core']:AddVehicle({
    name = "Ma Voiture",
    model = "adder",
    category = "super",
    price = 1000000,
    vehicleType = "cars",
    job = "",
    jobOnly = false
})

-- Supprimer un véhicule
exports['vAvA_core']:RemoveVehicle('adder')

-- Mettre à jour un véhicule
exports['vAvA_core']:UpdateVehicle('adder', {
    price = 1500000
})
```

## Concessionnaires par défaut

| ID | Type | Position |
|----|------|----------|
| cars_civilian | Voitures | PDM |
| cars_job | Voitures Job | PDM Job |
| boats_civilian | Bateaux | Marina |
| helicopters_civilian | Hélicoptères | Héliport LS |
| planes_civilian | Avions | Aéroport LS |

## Commandes

- `/vadmin` - Ouvre le panel d'administration (admin only)
- `/mylicense` - Affiche votre license Rockstar
- `/fixcam` - Réinitialise la caméra si bloquée

## Structure des fichiers

```
modules/concess/
├── fxmanifest.lua
├── config.lua
├── vehicles.json
├── server/
│   └── main.lua
├── client/
│   └── main.lua
└── html/
    ├── index.html
    ├── css/
    │   └── style.css
    ├── js/
    │   └── app.js
    └── img/
        └── (images des véhicules)
```

## Base de données

Le module utilise la table `player_vehicles` existante. Structure requise :

```sql
CREATE TABLE IF NOT EXISTS `player_vehicles` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `license` VARCHAR(50),
    `citizenid` VARCHAR(50),
    `vehicle` VARCHAR(50),
    `hash` VARCHAR(50),
    `mods` TEXT,
    `plate` VARCHAR(10),
    `garage` VARCHAR(50),
    `fuel` INT DEFAULT 100,
    `engine` FLOAT DEFAULT 1000.0,
    `body` FLOAT DEFAULT 1000.0,
    `state` INT DEFAULT 1,
    `job` VARCHAR(50),
    `type` VARCHAR(20) DEFAULT 'car'
);
```

## Intégrations

### Module Keys
Les clés sont automatiquement données à l'achat si le module keys est actif.

### Module Persist
Les véhicules sont automatiquement enregistrés pour la persistance.

### vCore Economy
Les paiements passent par le système économique du core.

## Support

Pour toute question, consultez la documentation principale de vAvA Core.
