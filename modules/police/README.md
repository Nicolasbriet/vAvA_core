# 🚔 vAvA Police - Module Complet

## 📋 Description

Module de gestion policière avancé pour vAvA_core, offrant un système complet de gestion des forces de l'ordre avec:
- 7 grades avec permissions granulaires
- Système d'amendes et prison
- Tablette policière avec recherches
- Radar de vitesse
- GPS et alertes dispatch
- Casier judiciaire
- Logs complets

---

## ⚙️ Installation

### 1. Base de données
```bash
# Exécuter le fichier SQL
mysql -u root -p votre_db < sql/police_system.sql
```

### 2. Configuration
Éditez `config.lua` selon vos besoins:
- Grades et permissions
- Positions des commissariats
- Montant des amendes
- Paramètres de la prison

### 3. Dépendances
- `vAvA_core` (framework principal)
- `oxmysql` (accès base de données)

---

## 🎮 Utilisation

### Commandes de base
- **F6**: Ouvrir le menu police (en service uniquement)
- **X**: Activer/désactiver le radar
- **Y**: Définir GPS vers alerte (dans les 10s après réception)
- **E**: Interagir avec les points d'intérêt (vestiaire, armurerie, garage)

### Menu F6 - Options
1. **Interaction Citoyen**
   - Menotter/Démenotter
   - Fouiller
   - Escorter
   - Mettre/Sortir du véhicule
   - Donner amende
   - Envoyer en prison
   - Voir identité
   - Consulter casier

2. **Vestiaire**: Changer de tenue (civil/police)

3. **Armurerie**: Récupérer armes et équipement (selon grade)

4. **Garage**: Sortir véhicule de service (selon grade)

5. **Tablette**: Interface de recherche et alertes

6. **Demande Renfort**: Envoyer position GPS à tous les collègues

---

## 📊 Système de Grades

| Grade | Nom | Permissions |
|-------|-----|-------------|
| 0 | Cadet | Menottes, Amendes simples |
| 1 | Officer I | + Fouille, Véhicules légers |
| 2 | Officer II | + Prison (<30min), Armes de base |
| 3 | Officer III | + Tablette, Dispatch |
| 4 | Sergeant | + Toutes armes, Tous véhicules |
| 5 | Lieutenant | + Prison illimitée |
| 6 | Captain | Accès complet |

---

## 💰 Amendes

### Catégorie: Infractions Routières
- Excès vitesse (<20km/h): $150
- Excès vitesse (20-50km/h): $400
- Excès vitesse (>50km/h): $800
- Feu rouge: $250
- Stationnement gênant: $100
- Conduite sans permis: $1000
- Conduite dangereuse: $500

### Catégorie: Infractions Administratives
- Insulte envers agent: $500
- Refus d'obtempérer: $800
- Fausse identité: $1500
- Non-port ceinture: $200

### Catégorie: Infractions Criminelles
- Vol simple: $2000
- Vol véhicule: $5000
- Agression: $3000
- Port d'arme illégal: $7500
- Trafic stupéfiants: $15000
- Tentative meurtre: $25000
- Meurtre: $50000

---

## 🏛️ Système de Prison

- **Temps minimum**: 5 minutes
- **Temps maximum**: 120 minutes (2 heures)
- **Réduction de peine**: 1 min de travail = 1 min de réduction
- **Persistence**: Le temps est sauvegardé en cas de déconnexion

### Points de travail en prison
Approchez-vous des zones de travail (marqueur jaune) et appuyez sur **E** pour réduire votre peine.

---

## 📱 Tablette Policière

### Onglet Recherche
- **Recherche Personne**: Nom, prénom → Affiche identité + casier
- **Recherche Véhicule**: Plaque → Affiche propriétaire + infos

### Onglet Alertes
- Alertes actives en temps réel
- Code d'alerte (10-XX)
- Priorité (1=haute, 3=basse)
- Clic pour prendre en charge

### Onglet Unités
- Liste des policiers en service
- Statut et disponibilité

---

## 🚨 Système d'Alertes

### Codes 10
- **10-32**: Coups de feu
- **10-50**: Accident de la route
- **10-60**: Vol de véhicule
- **10-90**: Cambriolage
- **10-99**: Officier en danger

### Intégration dans autres ressources
```lua
-- Exemple: Déclencher une alerte depuis un autre script
exports['vAvA_police']:SendDispatchAlert('10-90', 'Cambriolage 24/7 Store', coords, 2)
```

---

## 🎯 Radar de Vitesse

- **Activation**: Touche X
- **Portée**: 50 mètres devant le véhicule
- **Détection**: Seulement véhicules en approche (angle <45°)
- **HUD**: Affiche modèle, plaque, vitesse, limite, excès
- **Zones**: Détection automatique des zones 50/80/130 km/h

---

## 🗺️ GPS et Blips

### Blips automatiques
- **Vert**: Collègues en service (mis à jour toutes les 5s)
- **Rouge clignotant**: Alerte dispatch (10s pour Y → GPS)
- **Bleu**: Demande de renfort

---

## 📚 Exports Serveur

```lua
-- Vérifier si joueur est policier en service
local isOnDuty = exports['vAvA_police']:IsPoliceOnDuty(playerId)

-- Obtenir nombre de policiers en service
local count, list = exports['vAvA_police']:GetOnDutyPolice()

-- Envoyer alerte dispatch
exports['vAvA_police']:SendDispatchAlert(code, message, coords, priority)

-- Obtenir amendes d'un joueur
exports['vAvA_police']:GetPlayerFines(citizenId, function(fines)
    -- fines = table
end)

-- Ajouter entrée au casier judiciaire
exports['vAvA_police']:AddCriminalRecord({
    citizen_id = citizenId,
    citizen_name = name,
    officer_id = officerId,
    officer_name = officerName,
    offense = 'Vol de véhicule',
    description = 'Détails...',
    fine_amount = 5000,
    jail_time = 30
})

-- Logger une action police
exports['vAvA_police']:LogPoliceAction({
    officer_id = citizenId,
    officer_name = name,
    action = 'handcuff',
    target_id = targetId,
    target_name = targetName,
    details = 'Raison...'
})
```

## 📚 Exports Client

```lua
-- Vérifier si joueur est menotté
local isHandcuffed = exports['vAvA_police']:IsHandcuffed()

-- Vérifier si joueur est policier
local isPolice = exports['vAvA_police']:IsPolice()

-- Vérifier si joueur est en service
local isOnDuty = exports['vAvA_police']:IsOnDuty()

-- Ouvrir tablette
exports['vAvA_police']:OpenTablet()

-- Fermer tablette
exports['vAvA_police']:CloseTablet()

-- Obtenir joueurs à proximité
local nearbyPlayers = exports['vAvA_police']:GetNearbyPlayers(radius)
```

---

## 🔧 Configuration Avancée

### Ajouter un commissariat
```lua
-- Dans config.lua > PoliceConfig.Stations
{
    name = 'LSPD Sandy Shores',
    cloakroom = vector3(1853.21, 3689.5, 34.27),
    armory = vector3(1850.1, 3690.3, 34.27),
    garage = vector3(1867.5, 3696.8, 33.5),
    prison = vector3(1847.8, 2585.8, 45.67),
    duty = vector3(1851.2, 3687.5, 34.27)
}
```

### Ajouter un grade
```lua
-- Dans config.lua > PoliceConfig.Grades
[7] = {
    name = 'Chief',
    permissions = {
        handcuff = true,
        search = true,
        fine = true,
        jail = true,
        impound = true,
        armory = true,
        tablet = true,
        dispatch = true
    }
}
```

### Ajouter une amende
```lua
-- Dans config.lua > PoliceConfig.Fines
{
    label = 'Nouvelle infraction',
    amount = 1000,
    category = 'traffic'
}
```

---

## 📞 Support

Pour tout bug ou suggestion:
- Discord: vAvA Community
- GitHub: vAvA_core/issues

---

## 📜 Changelog

### Version 1.0.0 (10/01/2026)
- ✅ Système complet de gestion policière
- ✅ 7 grades avec permissions
- ✅ Amendes et prison
- ✅ Tablette avec recherches
- ✅ Radar de vitesse
- ✅ GPS et alertes
- ✅ Casier judiciaire
- ✅ Interface NUI complète
- ✅ Support multilingue (FR/EN/ES)

---

## 📄 Licence

© 2026 vAvA Core - Tous droits réservés
