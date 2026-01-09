# vAvA Target - Guide de Test Rapide

## 🚀 Démarrage

Votre module vAvA_target est maintenant configuré avec des **outils de debug complets**.

## ✅ Étapes de Test

### 1. Démarrer le Serveur
Assurez-vous que `vAvA_target` est dans votre `server.cfg` :
```
ensure vAvA_target
```

### 2. Rejoindre le Serveur

### 3. Ouvrir la Console F8
Vous devriez voir :
```
[vAvA Target] Module loading...
[vAvA Target] Initialisation thread started
[vAvA Target] Dot display thread started
[vAvA Target] System initialized - Active: true
```

### 4. Test Rapide : Commande /targettest
Dans le chat, tapez :
```
/targettest
```
**Résultat attendu** : Un point rouge + croix apparaît au centre de l'écran pendant 5 secondes

✅ **Si le point apparaît** : Le système de dessin fonctionne !
❌ **Si rien n'apparaît** : Problème avec DrawRect (voir DEBUG.md)

### 5. Test de la Touche ALT
1. **Maintenez ALT** (gauche ou droite)
2. **Résultat attendu** : Point rouge + croix au centre de l'écran

✅ **Si le point apparaît** : TOUT FONCTIONNE ! 🎉
❌ **Si rien n'apparaît** : Continuez au point 6

### 6. Debug de la Touche ALT
Tapez dans le chat :
```
/targetdebug
```
Maintenez ALT et regardez dans F8 console :
- `Key 19 (ALT) pressed:` devrait être `true`
- `isTargetActive:` devrait être `true`
- `TargetConfig.UI.ShowDot:` devrait être `true`

### 7. Tester avec des Vraies Cibles

#### Option A : Utiliser le script d'exemple
Copiez le contenu de `EXEMPLE_TEST.lua` dans un nouveau script ou à la fin de `client/main.lua`

Relancez : `restart vAvA_target`

#### Option B : Test manuel
1. Maintenez **ALT**
2. **Visez un véhicule** proche (2-3 mètres)
3. **Résultat attendu** : Menu circulaire apparaît avec options

#### Option C : Téléport zone de test
```
/testzone
```
Vous serez téléporté à La Mesa. Maintenez ALT et vous devriez voir une option de zone.

## 🐛 Commandes de Debug

| Commande | Description |
|----------|-------------|
| `/targettest` | Teste l'affichage du point pendant 5s (sans touche ALT) |
| `/targetdebug` | Affiche toutes les infos de debug dans F8 |
| `/targettoggle` | Active/Désactive le système |
| `/testzone` | Se téléporte à la zone de test La Mesa |

## 🔧 Problèmes Courants

### "Rien n'apparaît quand j'appuie sur ALT"

**Diagnostic** :
1. `/targettest` → Si le point apparaît, la touche ALT n'est pas détectée
2. `/targetdebug` → Vérifiez `isTargetActive: true` et `Key 19 pressed: true`

**Solutions** :
- Si `isTargetActive: false` → `/targettoggle`
- Si `Key 19 pressed: false` → Essayez SHIFT en modifiant la config :
  ```lua
  TargetConfig.ActivationKey = 21  -- SHIFT au lieu d'ALT
  ```

### "Le module ne se charge pas"

**Vérifications** :
1. Dossier existe : `resources/[vava]/vAvA_target/`
2. Dans `server.cfg` : `ensure vAvA_target`
3. Pas d'erreurs dans la console serveur au démarrage

### "Le point apparaît mais pas de menu"

Vous devez viser une **entité avec des targets** :
- Véhicule proche (2-3m)
- PNJ proche
- Zone configurée

Utilisez `EXEMPLE_TEST.lua` pour créer des targets de test automatiquement.

## 📊 Logs à Vérifier

### Au Démarrage (F8)
```
[vAvA Target] Module loading...
[vAvA Target] Initialisation thread started
[vAvA Target] System initialized - Active: true
[vAvA Target] Config.Enabled: true
[vAvA Target] Config.UseKeyActivation: true
[vAvA Target] Config.ActivationKey: 19
[vAvA Target] Config.UI.ShowDot: true
[vAvA Target] Config.UI.DotSize: 8
[vAvA Target] Dot display thread started
```

### Quand ALT Pressé (F8)
```
[vAvA Target] Dot thread tick 500 Active: true
[vAvA Target] ALT KEY PRESSED!
[vAvA Target] TargetConfig.UI: table
[vAvA Target] ShowDot: true
```

### Avec /targetdebug (F8)
```
=================================
[vAvA Target] DEBUG INFO
=================================
isTargetActive: true
isMenuOpen: false
isAltPressed: true/false
TargetConfig.Enabled: true
TargetConfig.ActivationKey: 19
Key 19 (ALT) pressed: true/false
=================================
```

## 🎨 Personnalisation

### Changer la Couleur du Point
Dans `config/config.lua` :
```lua
DotColor = {255, 30, 30, 255},  -- Rouge vAvA (R, G, B, A)
-- Exemples :
-- {0, 255, 0, 255}     -- Vert
-- {0, 150, 255, 255}   -- Bleu clair
-- {255, 255, 0, 255}   -- Jaune
```

### Changer la Taille du Point
```lua
DotSize = 8,  -- Pixels (défaut)
-- Plus gros : 12, 16, 20
-- Plus petit : 4, 6
```

### Changer la Touche d'Activation
```lua
ActivationKey = 19,  -- ALT (défaut)
-- 21 = SHIFT
-- 29 = B
-- 38 = E
```

## 📝 Fichiers Importants

- **config/config.lua** : Configuration complète
- **DEBUG.md** : Guide de debug détaillé
- **EXEMPLE_TEST.lua** : Script d'exemple avec targets de test
- **client/main.lua** : Code principal (avec commandes debug)

## 🆘 Support

Si après tous ces tests rien ne fonctionne, fournissez :

1. Sortie complète de `/targetdebug` (F8)
2. Résultat de `/targettest` (le point apparaît-il ?)
3. Logs de démarrage du module (F8 au lancement)
4. Screenshot de votre `config/config.lua` (lignes 1-50)

---

**Créé par vAvA Team** | Version 1.0.0
