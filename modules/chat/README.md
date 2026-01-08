# vAvA_chat - Module de Chat RP

## Description
Module de chat RP complet intégré à vAvA_core, offrant des commandes de roleplay (/me, /do, /ooc, /mp) et des canaux métiers (/police, /ems, /staff).

## Fonctionnalités

### 💬 Commandes RP
- `/me [action]` - Action visible en proximité (20m)
- `/do [description]` - Description d'une situation
- `/de` - Lancer un dé (1-20)
- `/ooc [message]` - Message hors personnage (proximité)
- `/mp [id] [message]` - Message privé à un joueur

### 👮 Canaux Métiers
- `/police [message]` - Canal radio police (police, bcso, sheriff, lspd)
- `/ems [message]` - Canal radio EMS (ambulance, ems, doctor, hospital)
- `/staff [message]` - Canal staff (permissions ACE requises)

### 🎨 Interface
- Onglets par type de message (Général, OOC, DO, ME, MP, Police, EMS, Staff)
- Boutons raccourcis contextuels selon le job/permissions
- Drag & Drop pour déplacer le chat
- Redimensionnement avec poignées aux coins
- Sauvegarde des préférences (position, taille)
- Historique des commandes (flèches haut/bas)
- Suggestions de commandes en temps réel

## Installation

### En tant que module vAvA_core
Le module est automatiquement chargé par vAvA_core.

### En standalone
```cfg
ensure vAvA_core
ensure vAvA_chat
```

## Configuration

Éditez `config.lua` pour personnaliser :

```lua
ChatConfig.General = {
    ProximityRadius = 20.0,  -- Distance pour /me, /do, /ooc
    OpenKey = 245,           -- Touche T
    MessageDisplayTime = 5000
}

ChatConfig.Colors = {
    me = {255, 0, 255},      -- Violet
    ['do'] = {0, 150, 255},  -- Bleu
    -- ...
}

ChatConfig.StaffPermissions = {
    "vAvA.owner",
    "vAvA.admin",
    -- ...
}

ChatConfig.JobChannels = {
    police = {"police", "bcso", "sheriff", "lspd"},
    ems = {"ambulance", "ems", "doctor", "hospital"}
}
```

## Contrôles
- **T** - Ouvrir le chat
- **Entrée** - Envoyer le message
- **Échap** - Fermer le chat
- **↑/↓** - Historique des commandes

## Version
1.0.0 - Module intégré à vAvA_core
