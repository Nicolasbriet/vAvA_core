# 🎬 vava_loadingscreen

> Écran de chargement immersif avec image de fond pour **vAvA_core**

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![Framework](https://img.shields.io/badge/framework-vAvA__core-red.svg)
![Lua](https://img.shields.io/badge/lua-5.4-purple.svg)

---

## 📋 Table des matières

- [Fonctionnalités](#-fonctionnalités)
- [Installation](#-installation)
- [Configuration](#️-configuration)
- [Personnalisation](#-personnalisation)
- [API & Exports](#-api--exports)
- [Événements](#-événements)
- [FAQ](#-faq)

---

## ✨ Fonctionnalités

- 🖼️ **Image de fond personnalisable** avec effets (flou, filtres, animations)
- 📊 **Barre de progression** animée (ligne, bloc, cercle)
- 💬 **Messages dynamiques** multilingues (fr, en, es)
- 🎵 **Musique d'ambiance** avec contrôle mute/unmute
- ✨ **Effets visuels** (vignette, scanlines, particules)
- 📱 **Design responsive** (16:9, 21:9, 32:9, 4:3)
- ⚡ **Mode performance** pour les configurations modestes
- 🎨 **Entièrement personnalisable** via config.lua

---

## 📦 Installation

### 1. Copier le module

Placez le dossier `loadingscreen` dans votre répertoire `modules/` :

```
vAvA_core/
└── modules/
    └── loadingscreen/
        ├── fxmanifest.lua
        ├── config.lua
        ├── client/
        ├── locales/
        └── ui/
```

### 2. Ajouter vos assets

Créez le dossier `ui/assets/` et ajoutez :

- `background.png` - Votre image de fond (recommandé: 1920x1080 minimum)
- `logo.png` - Votre logo (recommandé: 512x512 avec transparence)
- `music.mp3` - Votre musique d'ambiance (optionnel)

### 3. Ajouter au server.cfg

```cfg
ensure vAvA_core
ensure vava_loadingscreen
```

**Important :** Le loadingscreen doit être démarré **après** vAvA_core.

### 4. Redémarrer le serveur

```
restart vava_loadingscreen
```

---

## ⚙️ Configuration

### Fichier `config.lua`

```lua
Config.LoadingScreen = {
    -- Informations du serveur
    ServerName = "vAvA Roleplay",
    ServerSlogan = "L'immersion au service du RP",
    ServerVersion = "1.0.0",
    
    -- Langue (fr, en, es)
    DefaultLocale = "fr",
    
    -- Image de fond
    Background = {
        Image = "assets/background.jpg",
        Blur = 0,           -- 0-20
        Opacity = 1.0,      -- 0.0-1.0
        Filter = "none",    -- none, sepia, grayscale, saturate
        Animation = "zoom", -- none, zoom, parallax
        AnimationSpeed = 30 -- secondes
    },
    
    -- Logo
    Logo = {
        Enabled = true,
        Image = "assets/logo.png",
        Width = 200,
        Height = 200,
        Animation = true -- effet pulse
    },
    
    -- Barre de progression
    ProgressBar = {
        Style = "line",     -- line, block, circle
        Color = "#e74c3c",
        ShowPercentage = true
    },
    
    -- Musique
    Music = {
        Enabled = false,
        File = "assets/music.mp3",
        Volume = 0.3,       -- 0.0-1.0
        AutoPlay = true,
        ShowControls = true
    },
    
    -- Effets visuels
    Effects = {
        Particles = {
            Enabled = false,
            Type = "snow",   -- snow, rain, dust, stars
            Density = 50
        },
        Vignette = {
            Enabled = true,
            Opacity = 0.4
        }
    }
}
```

---

## 🎨 Personnalisation

### Couleurs

Modifiez les couleurs dans `config.lua` :

```lua
Colors = {
    Primary = "#e74c3c",      -- Couleur principale (rouge)
    Secondary = "#c0392b",    -- Couleur secondaire
    Text = "#ffffff",         -- Couleur du texte
    Accent = "#f39c12"        -- Couleur d'accent (jaune)
}
```

### Messages personnalisés

Éditez les fichiers dans `locales/` pour ajouter vos propres messages :

```lua
-- locales/fr.lua
messages = {
    "💡 Conseil : Restez en personnage !",
    "📜 Lisez les règles avant de jouer.",
    -- Ajoutez vos messages ici
}
```

### Styles de barre de progression

| Style | Description |
|-------|-------------|
| `line` | Barre horizontale classique |
| `block` | Blocs qui se remplissent |
| `circle` | Cercle de progression |

### Types de particules

| Type | Description |
|------|-------------|
| `snow` | Flocons de neige |
| `rain` | Gouttes de pluie |
| `dust` | Poussière |
| `stars` | Étoiles scintillantes |

---

## 📡 API & Exports

### Afficher/Masquer

```lua
-- Afficher le loading screen
exports['vava_loadingscreen']:Show()

-- Masquer le loading screen
exports['vava_loadingscreen']:Hide()
```

### Progression

```lua
-- Mettre à jour la progression (0-100)
exports['vava_loadingscreen']:UpdateProgress(75)

-- Mettre à jour le module en cours de chargement
exports['vava_loadingscreen']:UpdateLoadingModule("Chargement des véhicules...")
```

### État

```lua
-- Vérifier si le loading screen est actif
local isActive = exports['vava_loadingscreen']:IsActive()

-- Vérifier si le joueur est chargé
local isLoaded = exports['vava_loadingscreen']:IsPlayerLoaded()
```

### Langue

```lua
-- Changer la langue dynamiquement
exports['vava_loadingscreen']:SetLocale("en")
```

---

## 📨 Événements

### Client

```lua
-- Quand le loading screen est terminé
AddEventHandler('vava_loadingscreen:loaded', function()
    print("Loading screen terminé !")
end)

-- Quand le joueur est prêt à jouer
AddEventHandler('vava_loadingscreen:ready', function()
    print("Joueur prêt !")
end)
```

### Serveur

```lua
-- Quand un joueur a fini de charger
AddEventHandler('vava_loadingscreen:playerLoaded', function()
    local src = source
    print("Joueur " .. src .. " a fini de charger")
end)
```

### Depuis le serveur

```lua
-- Cacher le loading screen d'un joueur
TriggerClientEvent('vava_loadingscreen:hide', playerId)

-- Mettre à jour la progression
TriggerClientEvent('vava_loadingscreen:updateProgress', playerId, 50)

-- Mettre à jour le nombre de joueurs
TriggerClientEvent('vava_loadingscreen:updatePlayerCount', playerId, GetNumPlayerIndices())
```

---

## ❓ FAQ

### Le loading screen ne s'affiche pas

1. Vérifiez que le module est bien démarré dans `server.cfg`
2. Vérifiez que les fichiers `ui/` sont présents
3. Vérifiez la console pour les erreurs

### La musique ne joue pas

Les navigateurs bloquent l'autoplay. Le joueur doit interagir avec la page.
Solution : Mettez `AutoPlay = false` et `ShowControls = true`.

### L'image de fond est pixelisée

Utilisez une image de haute résolution (1920x1080 minimum, 4K recommandé).

### Le loading screen reste bloqué

Vérifiez que `loadscreen_manual_shutdown 'yes'` est dans votre `fxmanifest.lua`.
Le script appelle automatiquement `ShutdownLoadingScreenNui()`.

---

## 📁 Structure des fichiers

```
loadingscreen/
├── fxmanifest.lua          # Manifest FiveM
├── config.lua              # Configuration principale
├── README.md               # Documentation
├── client/
│   └── main.lua            # Script client
├── locales/
│   ├── fr.lua              # Français
│   ├── en.lua              # Anglais
│   └── es.lua              # Espagnol
└── ui/
    ├── index.html          # Structure HTML
    ├── style.css           # Styles CSS
    ├── app.js              # Logique JavaScript
    └── assets/
        ├── background.png  # Image de fond
        ├── logo.png        # Logo du serveur
        └── music.mp3       # Musique (optionnel)
```

---

## 🔧 Debug

Activez le mode debug dans la config de vAvA_core :

```lua
Config.Debug = true
```

Commandes disponibles :
- `/loadingscreen_show` - Afficher le loading screen
- `/loadingscreen_hide` - Masquer le loading screen
- `/loadingscreen_progress [0-100]` - Définir la progression

---

## 📝 Changelog

### v1.0.0
- 🎉 Version initiale
- ✨ Support des images de fond avec effets
- 📊 3 styles de barre de progression
- 💬 Messages dynamiques multilingues
- 🎵 Support audio avec contrôles
- ✨ Effets visuels (vignette, scanlines, particules)
- 📱 Design responsive multi-résolution
- ⚡ Mode performance

---

## 📄 Licence

Ce module fait partie du framework **vAvA_core**.  
Développé par **Briet** pour la communauté vAvA.

---

<p align="center">
  <strong>Propulsé par vAvA Framework</strong><br>
  <em>L'immersion au service du RP</em>
</p>
