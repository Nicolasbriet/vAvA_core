# 👤 vAvA Player Manager - Module Complet

## 📋 Description

Module de gestion avancée des joueurs et personnages pour vAvA_core, incluant:
- Sélecteur multi-personnages (jusqu'à 5 par compte)
- Système de création de personnage avec histoire
- Cartes d'identité et licences
- Statistiques détaillées
- Historique complet des actions
- Interface NUI moderne

---

## ⚙️ Installation

### 1. Base de données
```bash
mysql -u root -p votre_db < sql/player_manager.sql
```

### 2. Configuration
Éditez `config.lua`:
- Nombre max de personnages
- Argent de départ
- Position spawn par défaut
- Licences disponibles
- Stats à traquer

---

## 🎮 Utilisation

### Commandes
- `/characters` - Ouvrir sélecteur de personnages
- `/showid [id]` - Montrer carte d'identité
- `/showlicenses` - Voir mes licences
- `/stats` - Voir statistiques

### Commandes Admin
- `/deletechar [citizenid]` - Supprimer personnage
- `/resetchar [citizenid]` - Réinitialiser personnage
- `/givelicense [id] [type]` - Donner licence
- `/revokelicense [id] [type]` - Révoquer licence

---

## 📊 Système de Licences

| Licence | Coût | Examen | Validité |
|---------|------|--------|----------|
| Permis de conduire | $5,000 | Oui | 365 jours |
| Permis port d'arme | $15,000 | Oui | 180 jours |
| Licence commerciale | $25,000 | Non | Illimité |
| Permis de chasse | $2,000 | Non | 365 jours |
| Permis de pêche | $1,500 | Non | 365 jours |
| Licence de pilote | $50,000 | Oui | 365 jours |
| Permis bateau | $8,000 | Oui | 365 jours |

---

## 📈 Statistiques Trackées

- ⏱️ Temps de jeu (heures)
- 🚶 Distance à pied (km)
- 🚗 Distance en véhicule (km)
- 💀 Nombre de morts
- 👮 Arrestations
- 💼 Missions accomplies
- 💰 Argent gagné
- 💸 Argent dépensé

---

## 📚 Exports Serveur

```lua
-- Personnages
exports['vAvA_player_manager']:GetCharacter(citizenId, callback)
exports['vAvA_player_manager']:CreateCharacter(data, callback)
exports['vAvA_player_manager']:DeleteCharacter(citizenId, callback)
exports['vAvA_player_manager']:UpdateCharacter(citizenId, data, callback)

-- Licences
exports['vAvA_player_manager']:HasLicense(citizenId, licenseType, callback)
exports['vAvA_player_manager']:GiveLicense(citizenId, licenseType, issuedBy, callback)
exports['vAvA_player_manager']:RevokeLicense(citizenId, licenseType, callback)
exports['vAvA_player_manager']:SuspendLicense(citizenId, licenseType, days, callback)

-- Stats
exports['vAvA_player_manager']:GetStats(citizenId, callback)
exports['vAvA_player_manager']:UpdateStat(citizenId, statName, value)
exports['vAvA_player_manager']:SetStat(citizenId, statName, value)

-- Historique
exports['vAvA_player_manager']:AddHistory(citizenId, eventType, description, eventData, amount, relatedPlayer)
exports['vAvA_player_manager']:GetHistory(citizenId, limit, callback)
```

## 📚 Exports Client

```lua
-- Interface
exports['vAvA_player_manager']:OpenSelector()
exports['vAvA_player_manager']:OpenCreator()
exports['vAvA_player_manager']:ShowLicenses()
exports['vAvA_player_manager']:ShowStats()
exports['vAvA_player_manager']:ShowID(targetId)

-- Info
exports['vAvA_player_manager']:GetCurrentCharacter()
exports['vAvA_player_manager']:IsInSelector()
```

---

## 🔧 Configuration Avancée

### Ajouter une licence
```lua
-- Dans config.lua > PlayerManagerConfig.Licenses
{
    name = 'motorcycle',
    label = 'Permis Moto',
    description = 'Autorise conduite de motos',
    cost = 3000,
    examRequired = true,
    examLocation = vector3(x, y, z),
    examDuration = 300,
    validityDays = 365,
    canRevoke = true
}
```

### Tracker nouvelle stat
```lua
-- Dans config.lua > PlayerManagerConfig.Stats.Categories
{
    name = 'vehicles_stolen',
    label = 'Véhicules volés',
    unit = '',
    icon = '🚗'
}

-- Puis créer colonne SQL
ALTER TABLE player_stats ADD COLUMN vehicles_stolen INT DEFAULT 0;

-- Utiliser
exports['vAvA_player_manager']:UpdateStat(citizenId, 'vehicles_stolen', 1)
```

---

## 📄 Licence

© 2026 vAvA Core - Tous droits réservés
