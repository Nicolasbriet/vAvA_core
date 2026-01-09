# vAvA Creator

<div align="center">
    <img src="https://img.shields.io/badge/vAvACore-v2.4.0-FF1E1E?style=for-the-badge" alt="Version">
    <img src="https://img.shields.io/badge/FiveM-Ready-brightgreen?style=for-the-badge" alt="FiveM">
</div>

## 📋 Description

**vAvA Creator** est un système complet de création et gestion de personnages pour FiveM, intégré au framework vAvA_core. Il offre une expérience utilisateur moderne et immersive avec une interface graphique respectant la charte vAvACore.

### ✨ Fonctionnalités Principales

- 🎭 **Création de personnage en 8 étapes** - Wizard intuitif avec aperçu en temps réel
- 👥 **Multi-personnages** - Support jusqu'à 3 personnages par joueur
- 🛍️ **Magasins de vêtements** - Binco, Suburban, Ponsonbys avec prix différenciés
- 💇 **Salons de coiffure** - 5 emplacements à Los Santos
- 💉 **Chirurgie esthétique** - Modifier l'apparence de son personnage
- 🌍 **Multi-langue** - Français, Anglais, Espagnol

---

## 📁 Structure des Fichiers

```
modules/creator/
├── fxmanifest.lua          # Configuration de la ressource
├── config.lua              # Configuration complète
├── README.md               # Documentation
├── client/
│   ├── main.lua            # Logique principale client
│   └── shop.lua            # Magasins côté client
├── server/
│   ├── main.lua            # Gestion des personnages
│   └── shop.lua            # Transactions des magasins
├── html/
│   ├── index.html          # Interface utilisateur
│   ├── css/
│   │   └── style.css       # Styles vAvACore
│   └── js/
│       └── app.js          # Logique JavaScript
└── locales/
    ├── en.lua              # Anglais
    ├── es.lua              # Espagnol
    └── fr.lua              # Français
```

---

## 🚀 Installation

### Prérequis

- [vAvA_core](https://github.com/vAvA/vAvA_core) (v2.4.0+)
- [oxmysql](https://github.com/overextended/oxmysql)

### Étapes

1. **Télécharger** le dossier `creator` dans `modules/`

2. **Configurer** le fichier `config.lua` selon vos besoins

3. **Démarrer** la ressource (elle se charge automatiquement via vAvA_core)

4. La table de base de données `vava_characters` sera créée automatiquement

---

## ⚙️ Configuration

### Configuration Générale

```lua
Config = {
    DefaultLocale = 'fr',           -- Langue par défaut
    MultiCharacter = true,          -- Activer multi-persos
    MaxCharacters = 3,              -- Nombre max de persos
    
    NameMinLength = 2,              -- Longueur min nom
    NameMaxLength = 20,             -- Longueur max nom
    AgeMin = 18,                    -- Âge minimum
    AgeMax = 80,                    -- Âge maximum
}
```

### Magasins de Vêtements

```lua
Config.ClothingShops = {
    {
        name = 'binco_legion',
        label = 'Binco - Legion Square',
        coords = vector3(120.45, -223.54, 54.56),
        priceMultiplier = 1.0,      -- Prix de base
        categories = {'tops', 'pants', 'shoes', 'accessories'}
    },
    -- ...
}
```

### Salons de Coiffure

```lua
Config.BarberShops = {
    {
        name = 'barber_hawick',
        label = 'Barbier - Hawick',
        coords = vector3(-814.25, -183.34, 37.57),
        prices = {
            hair = 50,
            beard = 30,
            eyebrows = 20
        }
    },
    -- ...
}
```

---

## 🎮 Utilisation

### Pour les Joueurs

1. **Connexion** - À la connexion, l'écran de sélection de personnage s'affiche
2. **Création** - Cliquez sur un slot vide pour créer un personnage
3. **8 Étapes** - Suivez le wizard de création :
   - Genre (Homme/Femme)
   - Morphologie (Héritage parental)
   - Visage (Traits faciaux)
   - Cheveux (Coupe, couleur, barbe)
   - Peau (Imperfections, maquillage)
   - Vêtements (Haut, pantalon, chaussures)
   - Identité (Nom, prénom, âge)
   - Résumé (Confirmation)
4. **Jouer** - Sélectionnez un personnage existant pour jouer

### Magasins

Les magasins sont accessibles en se rendant aux emplacements marqués sur la carte :
- 🔵 **Vêtements** - Binco, Suburban, Ponsonbys
- ✂️ **Coiffeur** - 5 salons à Los Santos
- 💉 **Chirurgie** - Hôpital central

---

## 🔧 API Développeur

### Événements Serveur

```lua
-- Récupérer les personnages d'un joueur
vCore.Callback.TriggerCallback('vava_creator:getCharacters', function(characters)
    -- characters = array de personnages
end)

-- Créer un personnage
vCore.Callback.TriggerCallback('vava_creator:createCharacter', function(success, citizenid)
    -- success = boolean
    -- citizenid = string (si succès)
end, characterData)

-- Charger un personnage
vCore.Callback.TriggerCallback('vava_creator:loadCharacter', function(success)
    -- success = boolean
end, citizenid)

-- Supprimer un personnage
vCore.Callback.TriggerCallback('vava_creator:deleteCharacter', function(success)
    -- success = boolean
end, citizenid)
```

### Exports Client

```lua
-- Ouvrir l'écran de sélection
exports['vava_creator']:OpenCharacterSelection()

-- Ouvrir le créateur
exports['vava_creator']:OpenCreator()

-- Ouvrir un magasin de vêtements
exports['vava_creator']:OpenClothingShop(shopName)

-- Ouvrir un coiffeur
exports['vava_creator']:OpenBarberShop(shopName)

-- Ouvrir la chirurgie
exports['vava_creator']:OpenSurgeryShop()
```

### Exports Serveur

```lua
-- Récupérer le skin d'un joueur
local skin = exports['vava_creator']:GetPlayerSkin(source)

-- Sauvegarder le skin d'un joueur
exports['vava_creator']:SavePlayerSkin(source, skinData)

-- Récupérer les vêtements d'un joueur
local clothes = exports['vava_creator']:GetPlayerClothes(source)
```

---

## 🎨 Charte Graphique

Le module respecte la charte graphique vAvACore :

| Élément | Valeur |
|---------|--------|
| Couleur Primaire | `#FF1E1E` (Rouge Néon) |
| Couleur Secondaire | `#CC1818` |
| Fond Principal | `#000000` |
| Texte Principal | `#FFFFFF` |
| Police Titres | Orbitron |
| Police Corps | Montserrat |

---

## 📊 Base de Données

### Table `vava_characters`

```sql
CREATE TABLE IF NOT EXISTS `vava_characters` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL UNIQUE,
    `license` VARCHAR(100) NOT NULL,
    `slot` INT NOT NULL DEFAULT 1,
    `firstname` VARCHAR(50) NOT NULL,
    `lastname` VARCHAR(50) NOT NULL,
    `age` INT NOT NULL DEFAULT 18,
    `gender` VARCHAR(10) NOT NULL DEFAULT 'male',
    `nationality` VARCHAR(50) DEFAULT 'American',
    `story` TEXT,
    `skin_data` LONGTEXT,
    `clothes_data` LONGTEXT,
    `position` VARCHAR(255) DEFAULT '{"x":0,"y":0,"z":0}',
    `money` VARCHAR(255) DEFAULT '{"cash":500,"bank":5000}',
    `job` VARCHAR(100) DEFAULT 'unemployed',
    `job_grade` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `last_played` TIMESTAMP NULL,
    INDEX `idx_license` (`license`),
    INDEX `idx_citizenid` (`citizenid`)
);
```

---

## 🐛 Dépannage

### Problèmes Courants

**Le personnage n'apparaît pas correctement**
- Vérifiez que toutes les dépendances sont installées
- Assurez-vous que la ressource démarre après vAvA_core

**Les magasins ne s'ouvrent pas**
- Vérifiez les coordonnées dans `config.lua`
- Assurez-vous que les zones sont bien créées

**Erreur de base de données**
- Vérifiez la connexion MySQL
- Assurez-vous que oxmysql est démarré avant ce module

### Logs

Les logs sont disponibles dans la console serveur avec le préfixe `[vAvA Creator]`

---

## 📝 Changelog

### Version 1.0.0
- ✅ Création initiale du module
- ✅ Système de création en 8 étapes
- ✅ Multi-personnages (3 slots)
- ✅ Magasins de vêtements (6 emplacements)
- ✅ Salons de coiffure (5 emplacements)
- ✅ Chirurgie esthétique
- ✅ Support multi-langue (FR, EN, ES)
- ✅ Interface vAvACore

---

## 📄 Licence

Ce module fait partie de vAvA_core et est sous licence propriétaire vAvA.

---

<div align="center">
    <b>Développé avec ❤️ par l'équipe vAvA</b>
</div>
