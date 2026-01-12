# 🍎 Intégration Module Status - Configuration Complète

## ✅ Modifications Appliquées

### 1. Intégration Core ↔ Status Module
- **Fichier modifié:** `shared/classes.lua`
- **Changements:** Les méthodes `GetStatus`, `AddStatus`, `SetStatus`, `RemoveStatus` utilisent maintenant le module vAvA_status pour hunger/thirst
- **Bénéfice:** Toutes les actions d'inventaire utilisent automatiquement le système de status avancé

### 2. Inventaire Intelligent
- **Fichier modifié:** `server/inventory.lua`
- **Changements:** 
  - Auto-enregistrement de tous les items consommables du module status
  - Fallback sur les anciennes méthodes si module status indisponible
  - Support pour les animations et effets visuels
- **Items supportés:** Tous les items de `StatusConfig.ConsumableItems`

### 3. HUD Temps Réel
- **Fichiers modifiés:** 
  - `modules/status/client/main.lua`
  - `modules/hud/client/main.lua`
- **Changements:**
  - Mise à jour immédiate du HUD lors des changements de status
  - Synchronisation optimisée entre status ↔ HUD
  - Fréquence d'update augmentée pour fluidité

### 4. Configuration Optimisée
- **Fichier modifié:** `modules/status/config/config.lua`
- **Changements:**
  - Décrémentation plus fréquente (2min au lieu de 5min)
  - Nouveau paramètre HUDUpdateInterval (1000ms)
  - Optimisations anti-cheat

## 🚀 Installation & Configuration

### 1. Dans server.cfg
```bash
# Ordre d'importance crucial
ensure oxmysql
ensure vAvA_core      # Framework principal
ensure vAvA_hud       # Module HUD (optionnel mais recommandé)
ensure vAvA_status    # Module Status (requis)
ensure vAvA_inventory # Autres modules vAvA
```

### 2. Redémarrage requis
```bash
restart vAvA_core
restart vAvA_hud
restart vAvA_status
```

### 3. Test de fonctionnement
Une fois redémarré, ces messages doivent apparaître dans les logs :

```
[vAvA Core] Module status détecté et intégré avec succès !
[vAvA Status] Système de statuts initialisé avec succès !
[vCore Inventory] Enregistrement automatique des items du module status...
[vCore Inventory] Item enregistré: bread
[vCore Inventory] Item enregistré: burger
[vCore Inventory] Item enregistré: water
...
```

## 🍔 Items Disponibles (Auto-enregistrés)

### Nourriture
- `bread` - Pain (+15 faim)
- `sandwich` - Sandwich (+30 faim)  
- `burger` - Burger (+45 faim)
- `pizza` - Pizza (+50 faim)
- `hotdog` - Hot-dog (+35 faim)
- `taco` - Taco (+40 faim)
- `donut` - Donut (+20 faim)
- `apple` - Pomme (+10 faim, +5 soif)
- `orange` - Orange (+10 faim, +5 soif)
- `chips` - Chips (+15 faim, -5 soif)

### Boissons
- `water` - Eau (+25 soif)
- `soda` - Soda (+15 soif)
- `coffee` - Café (+10 soif, +5 faim)
- `juice` - Jus (+20 soif, +5 faim)
- `milk` - Lait (+15 soif, +10 faim)
- `beer` - Bière (+10 soif)
- `wine` - Vin (+8 soif)
- `whiskey` - Whisky (+5 soif)

### Items Premium
- `steak` - Steak (+60 faim)
- `pasta` - Pâtes (+55 faim)
- `salad` - Salade (+25 faim, +10 soif)
- `soup` - Soupe (+30 faim, +15 soif)

## 🎮 Utilisation

### Pour les Joueurs
```lua
-- Utiliser un item depuis l'inventaire
TriggerServerEvent('vCore:useItem', 'burger')
```

### Pour les Développeurs
```lua
-- Server-side: Ajouter de la faim/soif
local player = vCore.GetPlayer(source)
player:AddStatus('hunger', 30)  -- Utilise automatiquement vAvA_status
player:AddStatus('thirst', 25)

-- Client-side: Récupérer les valeurs actuelles
local hunger = exports['vAvA_status']:GetCurrentHunger()
local thirst = exports['vAvA_status']:GetCurrentThirst()
```

## 🔧 Dépannage

### Module status non détecté
```bash
# Vérifier l'ordre de démarrage
ensure vAvA_core
ensure vAvA_status
```

### Items non enregistrés
- Vérifier les logs pour `[vCore Inventory] Item enregistré: ...`
- S'assurer que le module status est démarré AVANT le core

### HUD non mis à jour
- Vérifier que vAvA_hud est installé
- Event `vCore:status:updated` disponible en fallback

## ✨ Fonctionnalités Avancées

### Effets Visuels
- Flou d'écran selon le niveau de faim/soif
- Réduction de stamina progressive
- Messages RP automatiques

### Anti-Cheat Intégré
- Vérification des changements de valeurs suspects
- Logs des actions de consommation
- Protection contre le spam

### Intégration Économie
- Support pour les prix dynamiques via vAvA_economy
- Compatibilité avec les systèmes de jobs/salaires

---

**✅ Configuration terminée ! Le système de faim/soif est maintenant pleinement intégré et opérationnel en temps réel.**