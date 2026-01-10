# 🚑 vAvA_ems - Système EMS Complet

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-red.svg" alt="Version">
  <img src="https://img.shields.io/badge/vAvA_core-Compatible-brightgreen.svg" alt="vAvA Core">
  <img src="https://img.shields.io/badge/FiveM-Ready-blue.svg" alt="FiveM">
</p>

**Système EMS réaliste et immersif pour vAvA_core**  
Urgences, diagnostic, soins, hospitalisation, système de sang complet.

---

## 📋 Table des matières

- [Présentation](#-présentation)
- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Utilisation](#-utilisation)
- [API](#-api)
- [Commandes](#-commandes)
- [Intégration](#-intégration)
- [Tests](#-tests)

---

## 🎯 Présentation

**vAvA_ems** est un module EMS complet et réaliste pour le framework vAvA_core. Il offre une expérience médicale authentique avec :

- ✅ **Système médical avancé** - États, signes vitaux, monitoring en temps réel
- ✅ **Blessures réalistes** - 12 types de blessures, 8 parties du corps, 4 niveaux de sévérité
- ✅ **Système de sang** - 8 groupes sanguins, compatibilité, transfusions, dons
- ✅ **Interventions EMS** - Appels 911, dispatch automatique, géolocalisation
- ✅ **Matériel médical** - 22 équipements différents (basique, avancé, critique)
- ✅ **Interface HUD** - Charte graphique vAvA (rouge néon #FF1E1E)
- ✅ **Hôpital complet** - 9 zones, lits, pharmacie, banque de sang
- ✅ **Multilingue** - Français, Anglais, Espagnol

---

## ✨ Fonctionnalités

### 🩺 Système Médical Central

**États du joueur :**
- Normal
- Douleur (légère / moyenne / sévère)
- Saignement (lent / actif / critique)
- Inconscient
- Coma
- Arrêt cardiaque
- Mort RP

**Signes vitaux :**
- Pouls (40-180 BPM)
- Tension artérielle (systolique/diastolique)
- Saturation O₂ (0-100%)
- Température (35-42°C)
- Niveau de douleur (0-10)
- Volume sanguin (0-100%)

**Effets dynamiques :**
- Vision floue progressive
- Ralentissement mouvement
- Perte de précision tir
- Chutes aléatoires
- Tremblements caméra
- Ragdoll si inconscient

### 🩸 Système de Blessures

**12 types de blessures :**
- Contusion
- Plaie ouverte
- Fracture simple / ouverte
- Blessure par balle (entrée/sortie)
- Brûlure (1er, 2e, 3e degré)
- Traumatisme crânien
- Lésion interne
- Hémorragie interne

**8 parties du corps :**
- Tête (critique, affecte vision)
- Cou (très critique)
- Torse (affecte respiration)
- Abdomen (risque hémorragie interne)
- Bras gauche/droit (limite utilisation armes)
- Jambe gauche/droite (affecte mobilité)

**4 niveaux de sévérité :**
1. Légère (MINOR)
2. Modérée (MODERATE)
3. Sévère (SEVERE)
4. Critique (CRITICAL)

### 🩸 Système de Sang & Transfusions

**8 groupes sanguins :**
- O- (donneur universel)
- O+
- A-, A+
- B-, B+
- AB-, AB+ (receveur universel)

**Compatibilité automatique :**
- Vérification groupe sanguin patient
- Test compatibilité avant transfusion
- Risque choc transfusionnel si incompatible
- Stock hospitalier géré en temps réel

**Don de sang :**
- Don volontaire citoyen
- Cooldown 56 jours RP
- Récompense symbolique (100$)
- Effets temporaires post-don (fatigue légère)
- Génération PNJ pour stocks

### 📞 Interventions EMS

**Appels d'urgence (911) :**
- Code Rouge (arrêt cardiaque, mort imminente)
- Code Orange (inconscient, état critique)
- Code Jaune (blessé, douleur sévère)
- Code Bleu (assistance médicale)

**Géolocalisation & Alertes automatiques :**
- Détection joueur inconscient sans appel
- Notification EMS avec coordonnées
- Waypoint automatique sur la map
- Blip temporaire 5 minutes
- Anti-abus (cooldown, sanctions)

**Processus d'intervention :**
1. Appel d'urgence reçu
2. Dispatch unité EMS
3. Sécurisation zone
4. Diagnostic interactif (5s)
5. Stabilisation sur place
6. Transport ambulance
7. Hospitalisation / sortie

### 🧰 Matériel Médical

**Équipement basique** (Stagiaire, Ambulancier) :
- Gants médicaux *(obligatoire)*
- Bandages (contrôle saignements légers)
- Attelles (immobilisation fractures)
- Antiseptiques (prévention infections)
- Oxygène portable (assistance respiratoire)
- Pansements compressifs (hémorragies modérées)

**Équipement avancé** (Paramedic, Médecin) :
- Défibrillateur (arrêts cardiaques)
- Perfusions IV (NaCl, Plasma, Ringer)
- Morphine / Antidouleur
- Adrénaline (choc, arrêt cardiaque)
- Kit de suture (plaies profondes)
- Kit thoracique (pneumothorax)
- Planche dorsale (traumatismes colonne)

**Équipement critique** (Médecin, Chirurgien) :
- Kit d'intubation (ventilation artificielle)
- Ventilateur mécanique (assistance prolongée)
- Kit chirurgie d'urgence (bloc mobile)
- Kit réanimation avancée (protocoles complexes)
- Échographie portable (hémorragies internes)
- Kit transfusion sanguine (mobile)

### 🚑 Véhicules EMS

- **Ambulance standard** - Équipement basique + avancé
- **Ambulance de réanimation** - Équipement complet (critique inclus)
- **Hélicoptère médical** - Transport rapide + soins avancés

### 🏥 Hôpital (Pillbox Hill Medical Center)

**9 zones hospitalières :**
- Réception (enregistrement, rendez-vous)
- Urgences (accueil patients critiques)
- Salle de tri (évaluation, priorisation)
- Bloc opératoire (chirurgies)
- Réanimation / USI (soins intensifs)
- Pharmacie (médicaments)
- Radiologie (scanner, IRM, rayons X)
- Laboratoire (analyses sanguines)
- Banque de sang (stocks par groupe)

**6 lits d'hôpital disponibles** avec gestion occupation

**Coûts hospitaliers :**
- Consultation : 50$
- Urgences : 500$
- Chirurgie : 2500$
- Hospitalisation : 1000$/jour RP
- Transfusion sanguine : 500$

### 🎮 Interface HUD EMS

**Charte graphique vAvA :**
- Rouge néon #FF1E1E (couleur principale)
- Noir profond #000000 (fond)
- Blanc pur #FFFFFF (texte)
- Typographie Orbitron / Rajdhani / Roboto
- Effets glow, shimmer, scanline
- Animations fluides et modernes

**HUD signes vitaux :**
- Visible uniquement pour EMS (configurable)
- 4 positions disponibles (coins écran)
- Mise à jour temps réel (1s)
- Barres animées avec effets visuels
- Statut patient (Stable / Modéré / Instable / Critique)

**Menu EMS principal :**
- Interventions (appels d'urgence, diagnostic)
- Banque de sang (stock en temps réel)
- Véhicules EMS (spawn)
- Actions médicales (équipement, CPR)

**Menu diagnostic patient :**
- Identité (nom, groupe sanguin)
- Signes vitaux complets
- Liste blessures détaillée
- Actions (traiter, transfuser, réanimer)

---

## 📦 Installation

### Prérequis

- [vAvA_core](https://github.com/Nicolasbriet/vAvA_core) (framework principal)
- [oxmysql](https://github.com/overextended/oxmysql) (gestion BDD)
- MySQL/MariaDB

### Étapes

1. **Télécharger le module**
```bash
cd resources/[vava]/modules/
git clone https://github.com/votre-repo/vAvA_ems.git ems
```

2. **Ajouter au server.cfg**
```cfg
ensure vAvA_core
ensure vAvA_ems
```

3. **Lancer le serveur**  
Les tables SQL seront créées automatiquement au premier démarrage :
- `player_medical`
- `player_injuries`
- `hospital_blood_stock`
- `emergency_calls`

4. **Configurer le job EMS** (optionnel)  
Ajoutez le job `ambulance` dans votre système de jobs vAvA_core si ce n'est pas déjà fait.

---

## ⚙️ Configuration

Éditez [config/config.lua](config/config.lua) pour personnaliser :

### Général
```lua
EMSConfig.Debug = false             -- Mode debug
EMSConfig.Locale = 'fr'             -- Langue (fr, en, es)
EMSConfig.EMSJob = 'ambulance'      -- Job EMS requis
```

### Signes Vitaux
```lua
EMSConfig.NormalVitalSigns = {
    pulse = 75,                     -- Pouls normal (BPM)
    bloodPressureSystolic = 120,    -- Tension systolique
    bloodPressureDiastolic = 80,    -- Tension diastolique
    oxygenSaturation = 98,          -- Saturation O₂ (%)
    temperature = 37.0,             -- Température (°C)
    painLevel = 0,                  -- Douleur (0-10)
    bloodVolume = 100               -- Volume sanguin (%)
}
```

### Taux de Saignement
```lua
EMSConfig.BleedingRates = {
    none = 0,
    slow = 0.05,      -- 0.05% par seconde
    active = 0.15,    -- 0.15% par seconde
    critical = 0.50   -- 0.50% par seconde
}
```

### Don de Sang
```lua
EMSConfig.BloodDonation = {
    enabled = true,
    cooldown = 56 * 24 * 60 * 60,   -- 56 jours en secondes
    unitsPerDonation = 1,
    reward = 100,                    -- Argent en compensation
    minHealth = 80,                  -- Santé minimale pour donner
    effectDuration = 300             -- 5 minutes d'effets
}
```

### Appels d'Urgence
```lua
EMSConfig.EmergencyCalls = {
    enabled = true,
    autoDetect = true,               -- Détection auto joueur inconscient
    autoDetectDelay = 30,            -- 30s avant alerte auto
    cooldown = 60                    -- Cooldown entre appels
}
```

### Mort & Respawn
```lua
EMSConfig.Death = {
    enablePermadeath = false,        -- Mort RP définitive
    unconsciousTime = 300,           -- 5 minutes avant mort
    respawnCost = 5000,              -- Coût respawn hôpital
    loseInventory = false,           -- Perte inventaire
    loseMoneyPercent = 10            -- Perte 10% argent liquide
}
```

### HUD
```lua
EMSConfig.HUD = {
    enabled = true,
    onlyForEMS = true,               -- Visible uniquement pour EMS
    position = 'bottom-right',       -- Position (4 choix)
    updateInterval = 1000            -- Mise à jour (ms)
}
```

---

## 🎮 Utilisation

### Pour les Joueurs

**Appeler les urgences :**
```
/911
```
→ Menu de sélection du type d'urgence (Code Rouge/Orange/Jaune/Bleu)

**Faire un don de sang :**  
Se rendre à la banque de sang de l'hôpital (zone marquée)

### Pour les EMS

**Ouvrir le menu EMS :**
```
/ems
```

**Actions disponibles :**
- Voir les appels d'urgence actifs
- Diagnostiquer un patient proche (5 secondes)
- Utiliser l'équipement médical
- Transfuser du sang
- Réanimer (CPR / Défibrillateur)
- Spawn véhicules EMS
- Consulter stock de sang

**Workflow type :**
1. Recevoir appel d'urgence → Waypoint automatique
2. Se rendre sur place en ambulance
3. Sécuriser la zone
4. `/ems` → Diagnostiquer patient
5. Traiter blessures avec équipement adapté
6. Transfuser si volume sanguin < 60%
7. Transporter à l'hôpital si nécessaire
8. Facturer patient (coûts configurables)

---

## 🔌 API

### Exports Serveur

```lua
-- Obtenir l'état médical d'un joueur
local state = exports['vAvA_ems']:GetPlayerMedicalState(source)
-- Retourne: { bloodType, state, vitalSigns, injuries, ... }

-- Définir un signe vital
exports['vAvA_ems']:SetVitalSign(source, 'bloodVolume', 80)
-- Signes: pulse, bloodPressureSystolic, bloodPressureDiastolic, 
--         oxygenSaturation, temperature, painLevel, bloodVolume

-- Ajouter une blessure
exports['vAvA_ems']:AddInjury(source, 'gunshot_entry', 'chest', 3)
-- Types: voir EMSConfig.InjuryTypes (12 types)
-- Parties: voir EMSConfig.BodyParts (8 parties)
-- Sévérité: 1-4 (MINOR, MODERATE, SEVERE, CRITICAL)

-- Retirer une blessure
exports['vAvA_ems']:RemoveInjury(source, injuryId)

-- Groupe sanguin
local bloodType = exports['vAvA_ems']:GetBloodType(source)

-- Stock de sang
local stock = exports['vAvA_ems']:GetBloodStock('O+')
exports['vAvA_ems']:AddBloodStock('O+', 5)
exports['vAvA_ems']:RemoveBloodStock('O+', 1)

-- Transfusion
exports['vAvA_ems']:TransfuseBlood(medicSource, patientSource, 'O+')

-- Créer un appel d'urgence
local callId = exports['vAvA_ems']:CreateEmergencyCall(source, 'RED', 'Accident majeur')
```

### Exports Client

```lua
-- Obtenir l'état médical local
local myState = exports['vAvA_ems']:GetLocalMedicalState()

-- Ouvrir le menu EMS
exports['vAvA_ems']:OpenEMSMenu()

-- Diagnostiquer un patient
exports['vAvA_ems']:OpenPatientDiagnosis(targetId)

-- Utiliser un équipement
exports['vAvA_ems']:UseEquipment('defibrillator', targetId)
```

### Events

**Serveur :**
```lua
-- Demander les données médicales
TriggerServerEvent('vAvA_ems:server:requestMedicalData')

-- Appel d'urgence
TriggerServerEvent('vAvA_ems:server:emergencyCall', 'RED', 'Description')

-- Don de sang
TriggerServerEvent('vAvA_ems:server:donateBlood')

-- Utiliser équipement
TriggerServerEvent('vAvA_ems:server:useEquipment', 'bandage', targetId)

-- Transfuser
TriggerServerEvent('vAvA_ems:server:transfuseBlood', targetId, 'O+')
```

**Client :**
```lua
-- Mise à jour état médical
RegisterNetEvent('vAvA_ems:client:updateMedicalState', function(state) end)

-- Nouvel appel d'urgence
RegisterNetEvent('vAvA_ems:client:newEmergencyCall', function(call) end)

-- Réanimation
RegisterNetEvent('vAvA_ems:client:revive', function() end)

-- Effets don de sang
RegisterNetEvent('vAvA_ems:client:bloodDonationEffects', function(duration) end)
```

---

## 🎯 Commandes

| Commande | Description | Permission |
|----------|-------------|------------|
| `/ems` | Ouvrir le menu EMS | job: ambulance |
| `/911` | Appeler les urgences | all |
| `/revive` (debug) | Se réanimer | debug mode only |

---

## 🔗 Intégration

### Avec vAvA_inventory

Le module s'intègre automatiquement avec l'inventaire vAvA_core :

```lua
-- Les équipements médicaux sont des items
-- Exemple : ajouter un bandage à un joueur
xPlayer:AddItem('bandage', 5)

-- Utilisation automatique via UseEquipment
```

### Avec vAvA_economy

Gestion automatique des coûts hospitaliers et récompenses :

```lua
-- Respawn à l'hôpital
xPlayer:RemoveMoney('bank', EMSConfig.Death.respawnCost)

-- Don de sang
xPlayer:AddMoney('cash', EMSConfig.BloodDonation.reward)
```

### Avec d'autres ressources

**Exemple : Dégâts par balle**
```lua
-- Dans votre système de combat
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' then
        local victim = args[1]
        local attacker = args[2]
        local weapon = args[7]
        
        if IsEntityAPed(victim) and IsPedAPlayer(victim) then
            local player = PlayerId()
            if PlayerPedId() == victim then
                local victimId = GetPlayerServerId(player)
                
                -- Ajouter blessure par balle
                TriggerServerEvent('vAvA_ems:addInjury', 'gunshot_entry', 'chest', 3)
                
                -- Réduire volume sanguin
                TriggerServerEvent('vAvA_ems:reduceBloodVolume', 15)
            end
        end
    end
end)
```

---

## 🧪 Tests

Le module inclut **30+ tests testbench** :

### Lancer les tests
```lua
-- Depuis le testbench vAvA_core
/testbench

-- Scanner les tests EMS
-- Lancer les tests
```

### Catégories de tests

**Tests unitaires (15) :**
- Initialisation signes vitaux
- Validation types de blessures
- Groupes sanguins et compatibilité
- Structure équipement médical
- Grades EMS

**Tests d'intégration (10) :**
- Progression états médicaux
- Taux de saignement
- Codes d'urgence
- Zones hospitalières
- Coûts hospitaliers

**Tests de cohérence (5) :**
- Configuration locale
- Job EMS
- Paramètres sauvegarde
- Paramètres HUD
- Stock de sang initial

---

## 📊 Base de Données

### Tables créées automatiquement

**player_medical**
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- identifier (VARCHAR(50), UNIQUE)
- blood_type (VARCHAR(3), DEFAULT 'O+')
- last_checkup (INT, DEFAULT 0)
- last_blood_donation (INT, DEFAULT 0)
- medical_history (TEXT)
```

**player_injuries**
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- identifier (VARCHAR(50), INDEX)
- injury_type (VARCHAR(50))
- body_part (VARCHAR(20))
- severity (INT)
- timestamp (INT)
- treated (BOOLEAN, DEFAULT FALSE)
```

**hospital_blood_stock**
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- blood_type (VARCHAR(3), UNIQUE)
- units (INT, DEFAULT 0)
- last_update (INT)
```

**emergency_calls**
```sql
- id (INT, AUTO_INCREMENT, PRIMARY KEY)
- caller (VARCHAR(50))
- location (VARCHAR(255))
- coords (VARCHAR(100))
- call_type (VARCHAR(20))
- priority (INT)
- status (VARCHAR(20), DEFAULT 'pending', INDEX)
- assigned_to (VARCHAR(50))
- timestamp (INT)
```

---

## 🛠️ Développement

### Structure des fichiers

```
vAvA_ems/
├── fxmanifest.lua
├── config/
│   └── config.lua           (~700 lignes)
├── server/
│   └── main.lua             (~800 lignes)
├── client/
│   └── main.lua             (~600 lignes)
├── shared/
│   └── api.lua              (~200 lignes)
├── locales/
│   ├── fr.lua               (~130 lignes)
│   ├── en.lua               (~120 lignes)
│   └── es.lua               (~120 lignes)
├── html/
│   ├── index.html           (~200 lignes)
│   ├── css/
│   │   └── style.css        (~700 lignes)
│   └── js/
│       └── app.js           (~400 lignes)
├── tests/
│   └── ems_tests.lua        (~500 lignes)
└── README.md                (~800 lignes)

Total: ~5000 lignes de code
```

### Contribuer

1. Fork le projet
2. Créer une branche (`git checkout -b feature/AmazingFeature`)
3. Commit (`git commit -m 'Add AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Ouvrir une Pull Request

---

## 📄 License

MIT License - Libre d'utilisation et modification.

---

## 👥 Crédits

- **Auteur** : vAvA
- **Framework** : vAvA_core
- **Inspiré par** : Systèmes médicaux réalistes RP

---

## 📞 Support

- **Discord** : [Votre serveur Discord]
- **GitHub Issues** : [Créer un ticket]
- **Documentation** : [Wiki complet]

---

<p align="center">
  <strong>Fait avec ❤️ pour la communauté FiveM RP</strong><br>
  <sub>vAvA_ems v1.0.0 - 2026</sub>
</p>
