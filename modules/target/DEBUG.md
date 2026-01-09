# vAvA Target - Guide de Debug

## Commandes de Debug Disponibles

### `/targetdebug`
Affiche toutes les informations de debug dans la console F8 :
- État du système (actif/inactif)
- État du menu (ouvert/fermé)
- État de la touche ALT
- Configuration complète
- Test de détection des touches

### `/targettoggle`
Active ou désactive le système de target

### `/targettest`
Teste l'affichage du point central pendant 5 secondes (force l'affichage sans touche ALT)

## Procédure de Test

1. **Démarrer le serveur**
   ```
   ensure vAvA_target
   ```

2. **Rejoindre le serveur en jeu**

3. **Ouvrir la console F8** et vérifier les messages :
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

4. **Tester les commandes** :
   - Tapez `/targettest` - Un point rouge devrait apparaître au centre de l'écran pendant 5 secondes
   - Si le point apparaît avec `/targettest`, le système de dessin fonctionne
   - Si le point n'apparaît pas, problème avec DrawRect ou résolution d'écran

5. **Tester la touche ALT** :
   - Appuyez sur ALT (gauche ou droite)
   - Tapez `/targetdebug` pendant que vous maintenez ALT
   - Vérifiez dans F8 : `Key 19 (ALT) pressed: true`
   - Si false, testez avec `/targettoggle` puis réessayez

6. **Vérifier le thread du point** :
   - Maintenez ALT pendant 10 secondes
   - Dans F8, vous devriez voir des messages réguliers :
     ```
     [vAvA Target] Dot thread tick 500 Active: true
     [vAvA Target] ALT KEY PRESSED!
     ```

## Problèmes Courants

### Aucun point n'apparaît quand je maintiens ALT

**Solution 1** : Vérifier que le système est actif
```
/targetdebug
```
Vérifiez `isTargetActive: true`. Si false, tapez `/targettoggle`

**Solution 2** : Tester le dessin de base
```
/targettest
```
Si le point apparaît, le problème vient de la détection de touche ALT

**Solution 3** : Vérifier la configuration
Dans F8, vérifiez :
- `TargetConfig.UI.ShowDot: true`
- `TargetConfig.ActivationKey: 19`
- `TargetConfig.Enabled: true`

### Le point apparaît avec /targettest mais pas avec ALT

La touche ALT n'est pas détectée. Vérifiez :

1. Tapez `/targetdebug` et maintenez ALT
2. Vérifiez `Key 19 (ALT) pressed: true/false`
3. Si false, testez avec SHIFT (key 21) en modifiant temporairement la config

### Pas de messages dans la console

Le module n'est pas chargé. Vérifiez :

1. Dans server.cfg : `ensure vAvA_target`
2. Que le dossier existe : `resources/[vava]/vAvA_target/`
3. Relancez le serveur

## Configuration de Test Minimale

Si rien ne fonctionne, éditez `config/config.lua` :

```lua
TargetConfig.Enabled = true
TargetConfig.Debug = true  -- Activer le mode debug
TargetConfig.ActivationKey = 21  -- Tester avec SHIFT
TargetConfig.UI.ShowDot = true
TargetConfig.UI.DotSize = 16  -- Augmenter la taille
```

Relancez la ressource : `restart vAvA_target`

## Logs à Fournir

Si le problème persiste, fournissez :

1. Sortie de `/targetdebug` (copier tout le texte de F8)
2. Résultat de `/targettest` (le point apparaît-il ?)
3. Messages de la console au démarrage du serveur
4. Votre configuration (config/config.lua)

## Notes Techniques

- **Key Code 19** = ALT (gauche et droite)
- **Key Code 21** = SHIFT (alternative pour test)
- **DrawRect** fonctionne uniquement dans un thread avec `Citizen.Wait(0)`
- Le point est dessiné à la position `(0.5, 0.5)` = centre écran
- Taille du point : `DotSize * 0.001` = 8 pixels * 0.001 = 0.008 (0.8% de la largeur écran)
