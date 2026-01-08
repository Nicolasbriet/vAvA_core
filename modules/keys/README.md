# vAvA_keys - Module de Gestion des Clés

## Description
Module de gestion des clés de véhicules intégré à vAvA_core. Permet le verrouillage, le partage de clés et le système de carjack.

## Fonctionnalités

### 🔑 Gestion des Clés
- **Clés permanentes** - Propriétaires de véhicules
- **Clés temporaires** - Partage limité dans le temps
- **Clés de job** - Accès automatique aux véhicules de service

### 🔒 Verrouillage
- **Touche L** - Verrouiller/Déverrouiller
- **Double L** - Contrôle du moteur à distance
- Animation télécommande réaliste
- Clignotants lors du verrouillage

### ⚙️ Moteur
- **Touche G** - Démarrer/Éteindre le moteur
- Contrôle à distance (double appui L)

### 🤝 Partage
- Partage de clés permanentes
- Partage de clés temporaires (durée configurable)
- Retrait des accès possible

### 🎭 Carjack
- Système de vol de véhicules
- Progression avec animation
- Alerte police optionnelle

## Exports

### Serveur
```lua
exports['vAvA_keys']:GiveKeys(source, plate)
exports['vAvA_keys']:RemoveKeys(source, plate)
exports['vAvA_keys']:HasKeys(source, plate)
exports['vAvA_keys']:ShareKeys(ownerSource, targetSource, plate, mode)
exports['vAvA_keys']:GetPlayerKeys(source)
```

### Client
```lua
exports['vAvA_keys']:HasKeys(plate)
exports['vAvA_keys']:ToggleLock()
exports['vAvA_keys']:ToggleEngine()
exports['vAvA_keys']:GetClosestVehicle(maxDistance)
```

## Configuration

```lua
KeysConfig.Keys = {
    TempKeyDuration = 30,        -- Minutes
    InteractionDistance = 5.0,
    EnableKeyFobAnimation = true,
    ActionCooldown = 600
}

KeysConfig.JobKeys = {
    Enabled = true,
    Jobs = {
        ['police'] = {
            vehicles = {'police', 'police2'},
            plates = {'LSPD*'}
        }
    }
}
```

## Version
2.0.0 - Module intégré à vAvA_core
