# 🔄 MIGRATION - HUD Centralisé

## 📋 Changements effectués (9 Janvier 2026)

Le HUD du module status a été **supprimé** et **intégré** dans le HUD central de vAvA_core.

---

## 🎯 Avant / Après

### ❌ AVANT
```
vAvA_status avait son propre HUD (html/css/js)
└── Affichage séparé en bas à droite
```

### ✅ APRÈS
```
vAvA_status envoie les données au HUD central
└── vAvA_core/client/hud.lua affiche tout
```

---

## 📁 Fichiers modifiés

### Module Status

1. **`fxmanifest.lua`**
   - ❌ Supprimé `ui_page` et `files` (HTML/CSS/JS)
   - ✅ Plus besoin de ressources NUI

2. **`client/main.lua`**
   - ❌ Supprimé `InitializeHUD()` et `UpdateHUD()`
   - ✅ Envoie maintenant via event `vAvA_hud:updateStatus`

3. **`config/config.lua`**
   - ❌ Supprimé options position, animations, etc.
   - ✅ Garde juste `enabled = true/false`

4. **Fichiers HTML/CSS/JS**
   - ⚠️ Toujours présents mais **non utilisés**
   - 📝 À garder comme référence de design

### vAvA_core

1. **`client/hud.lua`**
   - ✅ Ajout event listener `vAvA_hud:updateStatus`
   - ✅ Mise à jour pour utiliser `action` au lieu de `type`
   - ✅ Séparation des messages NUI (status, money, vehicle)

2. **`html/index.html`**
   - ✅ Barres faim/soif déjà présentes
   - ✅ Aucune modification nécessaire

3. **`html/js/app.js`**
   - ✅ Gestion faim/soif déjà présente
   - ✅ Aucune modification nécessaire

---

## 🔌 Flux de données

### Ancien flux (❌ supprimé)
```
Module status (server)
    ↓ TriggerClientEvent
Module status (client)
    ↓ SendNUIMessage
Module status (html/js)
    ↓ Affichage
```

### Nouveau flux (✅ actuel)
```
Module status (server)
    ↓ TriggerClientEvent('vAvA_status:updateStatus')
Module status (client)
    ↓ TriggerEvent('vAvA_hud:updateStatus')
vAvA_core (client/hud.lua)
    ↓ SendNUIMessage({action: 'updateStatus'})
vAvA_core (html/js/app.js)
    ↓ Affichage
```

---

## ✅ Avantages

1. **HUD unifié** - Tout est au même endroit
2. **Performance** - Un seul NUI au lieu de deux
3. **Cohérence** - Design uniforme
4. **Maintenance** - Plus facile à maintenir
5. **Extensibilité** - Facile d'ajouter d'autres statuts

---

## 🎨 Design

Le HUD de vAvA_core utilise déjà la charte graphique :
- 🔴 Rouge néon #FF1E1E pour la faim
- 💧 Bleu pour la soif
- ✨ Effets glow et animations
- 📍 Position en bas à gauche

---

## 🚀 Migration

### Pour les utilisateurs

**Aucune action nécessaire !**

Le changement est transparent. Les barres de faim/soif s'affichent maintenant dans le HUD principal.

### Pour les développeurs

Si vous aviez modifié le HUD du module status :

1. **Position :** Modifier dans `vAvA_core/html/css/style.css` (`.hud-container`)
2. **Couleurs :** Modifier dans `vAvA_core/html/css/style.css` (`.hunger`, `.thirst`)
3. **Logique :** Modifier dans `vAvA_core/html/js/app.js` (fonction `updateStatus`)

---

## 📝 Configuration

### Désactiver l'affichage faim/soif

**Option 1 : Dans le module status**
```lua
-- modules/status/config/config.lua
StatusConfig.HUD.enabled = false
```

**Option 2 : Dans le HUD principal**
```lua
-- vAvA_core/config/config.lua
Config.HUD.ShowStatus = false  -- Si cette option existe
```

**Option 3 : En CSS**
```css
/* vAvA_core/html/css/style.css */
#hunger-bar, #thirst-bar {
    display: none !important;
}
```

---

## 🔍 Tests

### Vérifier que tout fonctionne

1. Se connecter au serveur
2. Observer le HUD en bas à gauche
3. Vérifier barres santé, armure, **faim**, **soif**
4. Utiliser un item food/drink
5. Voir la barre monter

### Dépannage

**Les barres ne s'affichent pas ?**
```lua
-- F8 (console client)
-- Vérifier les erreurs JavaScript

-- Console serveur
-- Chercher "[vAvA Status]" dans les logs
```

**Les valeurs ne se mettent pas à jour ?**
```lua
-- Vérifier que vCore.PlayerData.status existe
-- Console F8 :
print(vCore.PlayerData.status)
```

---

## 📚 Documentation mise à jour

Les documents suivants ont été mis à jour :

- [x] [README.md](README.md) - Mis à jour section HUD
- [x] [config/config.lua](config/config.lua) - Configuration simplifiée
- [x] [client/main.lua](client/main.lua) - Code nettoyé

Les documents suivants sont **obsolètes** pour le HUD :

- ⚠️ `html/index.html` - Ne plus utiliser
- ⚠️ `html/css/style.css` - Ne plus utiliser
- ⚠️ `html/js/app.js` - Ne plus utiliser

**Note :** Ces fichiers sont conservés comme référence de design mais ne sont plus chargés.

---

## 🎉 Résultat

✅ HUD unifié et centralisé  
✅ Meilleure performance  
✅ Code plus propre  
✅ Facile à maintenir  
✅ Prêt pour de futurs statuts (stress, fatigue, etc.)

---

<div align="center">

**Migration terminée avec succès !**

🔴 **vAvACore – Le cœur du développement** 🔴

</div>
