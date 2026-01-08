# vAvA Core - Module Sit

Système de points d'assise avec animations personnalisables intégré au framework vAvA Core.

## Fonctionnalités

- **Points d'assise** : Création de points où les joueurs peuvent s'asseoir
- **Multi-animations** : 8 animations d'assise différentes
- **Mode édition** : Interface visuelle pour placer les points
- **Gestion admin** : Création, modification, suppression des points
- **ox_target** : Intégration automatique avec ox_target
- **Persistance** : Sauvegarde des points dans un fichier JSON

## Installation

Le module est automatiquement chargé par le core.

## Configuration

Modifiez `config.lua` pour personnaliser :

- `AdminGroups` : Groupes ayant accès à l'administration
- `AdminLicenses` : Licenses spécifiques d'admins
- `Commands.admin` : Commande admin (défaut: `/sitmanager`)
- `Commands.menu` : Commande pour s'asseoir (défaut: `/vsit`)
- `InteractionDistance` : Distance d'interaction
- `Animations` : Liste des animations disponibles

## Commandes

- `/sitmanager` - Ouvre le menu d'administration (admin only)
- `/vsit` - S'asseoir au point le plus proche

## Exports Client

```lua
-- Ouvrir le menu admin
exports['vAvA_core']:OpenSitMenu()

-- Basculer le mode édition
exports['vAvA_core']:ToggleEditMode()

-- S'asseoir à un point
exports['vAvA_core']:SitDown(pointId)

-- Se lever
exports['vAvA_core']:StandUp()

-- Récupérer tous les points
local points = exports['vAvA_core']:GetSitPoints()
```

## Exports Serveur

```lua
-- Créer un point d'assise
local pointId = exports['vAvA_core']:CreateSitPoint(vector3(100.0, 200.0, 30.0), 90.0)

-- Supprimer un point
exports['vAvA_core']:DeleteSitPoint(pointId)

-- Récupérer tous les points
local points = exports['vAvA_core']:GetSitPoints()

-- Vérifier si un point est occupé
local occupied = exports['vAvA_core']:IsPointOccupied(pointId)
```

## Mode Édition

1. Utilisez `/sitmanager` pour ouvrir le menu admin
2. Cliquez sur "Créer un point"
3. Utilisez les contrôles :
   - **ZQSD** : Déplacer le fantôme
   - **Q/E** : Monter/Descendre
   - **Molette** : Rotation
   - **ENTRÉE** : Valider la position
   - **RETOUR** : Annuler

## Animations disponibles

1. Position casual
2. Position pensif
3. Position penchée
4. Position réfléchie
5. Position détendue
6. Position canapé
7. Position écoute
8. Position classique

## Intégrations

### ox_target
Les points créent automatiquement des zones ox_target.

### ox_lib
Les menus utilisent ox_lib si disponible.

## Structure des données

```lua
-- Point d'assise
{
    id = "1",
    coords = { x = 100.0, y = 200.0, z = 30.0 },
    heading = 90.0,
    created_by = "Admin",
    created_at = 1234567890
}
```
