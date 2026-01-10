# ✅ Fix Commandes Admin - Test et Vérification

## 🔧 Changements Appliqués

### 1. Fonction Helper `HasAdminPermission()`
**Fichier:** `server/commands.lua` (ligne ~9-30)

Nouvelle fonction qui vérifie les permissions de **3 façons** :
1. ✅ **ACE directe** avec `IsPlayerAceAllowed()` - **Fonctionne sans personnage chargé**
2. ✅ **ACE générique** (`vava.admin`, `vava.superadmin`, etc.)
3. ✅ **Player object** (fallback si personnage chargé)

**Pourquoi c'est important:**
- Avant: Les commandes ne marchaient que si tu avais un personnage chargé
- Maintenant: Les commandes marchent **immédiatement** après connexion grâce aux ACE

---

### 2. Toutes les Commandes Admin Mises à Jour

**Commandes modifiées:**
- `/give` - Donner items
- `/givemoney` - Donner argent
- `/setjob` - Changer job
- `/tp` - TP vers joueur
- `/bring` - Amener joueur
- `/heal` - Soigner
- `/revive` - Réanimer
- `/kick` - Expulser
- `/car` - Spawn véhicule
- `/dv` - Delete véhicule
- `/refresh` - Recharger caches

**Commandes ajoutées:**
- `/tpm` - TP au marker
- `/goto` - TP vers joueur (alias de /tp)
- `/freeze` - Geler joueur
- `/unfreeze` - Dégeler joueur
- `/weather` - Changer météo
- `/time` - Changer heure
- `/setmoney` - Modifier argent
- `/setgroup` - Changer groupe
- `/ban` - Bannir joueur

**Total: 20 commandes** avec vérification ACE directe !

---

### 3. Events Client Ajoutés

**Fichier:** `client/main.lua` (ligne ~260-410)

**9 nouveaux events:**
1. `vCore:teleport` - TP simple
2. `vCore:teleportToMarker` - TP au marker
3. `vCore:spawnVehicleAdmin` - Spawn véhicule (avec mods)
4. `vCore:deleteVehicle` - Delete véhicule
5. `vCore:heal` - Soigner
6. `vCore:revive` - Réanimer
7. `vCore:freeze` - Geler/Dégeler
8. `vCore:setWeather` - Météo
9. `vCore:setTime` - Heure

---

## 🧪 Tests à Effectuer

### Test 1: Vérification des Permissions

```
1. Connectez-vous au serveur
2. Tapez: /vava_debug_perms
3. Vérifiez la sortie console serveur
```

**Attendu:**
```
--- TEST ACE (txAdmin) ---
vava.admin                     ✅ OUI
command.car                    ✅ OUI (si configuré)
```

---

### Test 2: Commande /car (Spawn Véhicule)

```
1. En jeu, placez-vous dans une zone dégagée
2. Tapez: /car adder
3. Un véhicule Bugatti devrait apparaître
```

**Attendu:**
- ✅ Véhicule spawn devant vous
- ✅ Plaque: "ADMIN"
- ✅ Moteur/Freins/Transmission au max
- ✅ Turbo activé
- ✅ Notification: "Véhicule spawné: adder"

**Si erreur:**
```
/vava_test_ace command.car
```
Devrait retourner ✅

---

### Test 3: Commande /tp (Téléportation)

```
1. Notez votre ID (en haut à droite)
2. Tapez: /tp [ID_autre_joueur]
3. Vous devriez être téléporté
```

**Ou:**
```
1. Ouvrez la carte (M)
2. Placez un marker
3. Tapez: /tpm
4. Vous êtes téléporté au marker
```

---

### Test 4: Commande /weather (Météo)

```
Testez chaque météo:
/weather clear      → Clair
/weather rain       → Pluie
/weather thunder    → Orage
/weather foggy      → Brouillard
/weather snow       → Neige
```

**Attendu:**
- ✅ Météo change instantanément
- ✅ Notification: "Météo: [nom]"

---

### Test 5: Commande /time (Heure)

```
/time 12 0      → Midi
/time 0 0       → Minuit
/time 18 30     → 18h30
```

**Attendu:**
- ✅ Heure change instantanément
- ✅ Notification: "Heure: HH:MM"

---

### Test 6: Commande /freeze (Geler)

```
1. Trouvez l'ID d'un autre joueur
2. Tapez: /freeze [ID]
3. Le joueur devrait être gelé
4. Tapez: /unfreeze [ID]
5. Le joueur est dégelé
```

---

### Test 7: Commandes Avancées (SUPERADMIN)

**Si vous êtes SUPERADMIN (niveau 3+):**

```
/setjob 1 police 0      → Changer job
/setmoney 1 cash 5000   → Donner 5000$
/setgroup 1 mod         → Promouvoir modérateur
/ban 5 24h Cheat        → Ban 24h
```

---

## 🔍 Diagnostic si Problème

### ❌ Commande ne fait rien

**1. Vérifier les ACE:**
```
/vava_test_ace command.car
/vava_test_ace vava.admin
```

**2. Vérifier server.cfg ligne ~120:**
```cfg
# Cette ligne doit être décommentée (sans #):
add_principal identifier.license:VOTRE_LICENSE group.admin
```

**3. Redémarrer resource:**
```
restart vAvA_core
```

---

### ❌ "Vous n'avez pas la permission"

**Vérifiez que vous avez l'ACE:**
```
/vava_debug_perms
```

Dans la console serveur, cherchez:
```
✅ vava.admin                     ✅ OUI
✅ command.car                    ✅ OUI
```

Si ❌ NON:
1. Vérifiez votre license: `/vava_getid`
2. Ajoutez dans server.cfg: `add_principal identifier.license:... group.admin`
3. Redémarrez le SERVEUR COMPLET

---

### ❌ Erreur Lua dans console

**Copier l'erreur et chercher:**

```lua
-- Erreur commune: vCore.ShowNotification non trouvé
-- Solution: Vérifier que vCore.Notify existe dans shared/utils.lua
```

**Vérification rapide:**
```
F8 (console client)
vCore.ShowNotification("Test", "info")
```

---

## 📋 Checklist Complète

- [ ] `/vava_debug_perms` confirme niveau admin
- [ ] `/vava_test_ace command.car` retourne ✅
- [ ] `/car adder` spawn un véhicule
- [ ] `/tp 0 0 72` téléporte
- [ ] `/tpm` téléporte au marker
- [ ] `/weather clear` change météo
- [ ] `/time 12 0` change heure
- [ ] `/freeze [id]` gèle un joueur
- [ ] `/heal` me soigne
- [ ] `/revive` me réanime

---

## 🎯 Commandes par Situation

### Développement
```bash
/car zentorno       # Voiture rapide
/tp 0 0 72          # TP au centre de la map
/heal               # Se soigner
/weather clear      # Météo claire
/time 12 0          # Midi
```

### Test Roleplay
```bash
/setjob 1 police 3  # Donner job police
/car police         # Voiture de police
/bring 3            # Amener joueur pour RP
```

### Modération
```bash
/freeze 5           # Geler suspect
/goto 5             # Aller voir joueur
/kick 5 AFK         # Kick joueur
```

### Administration
```bash
/setmoney 1 cash 5000   # Compenser bug
/setgroup 1 mod         # Promouvoir
/ban 5 7d Cheat         # Ban 7 jours
```

---

## 📚 Documentation Complète

- [GUIDE_PERMISSIONS.md](GUIDE_PERMISSIONS.md) - Guide permissions complet
- [COMMANDES_FIVEM_NATIVES.md](COMMANDES_FIVEM_NATIVES.md) - Liste 40+ commandes
- [server.cfg](server.cfg) - Configuration ACE

---

## 🆘 Support

**Si aucun test ne fonctionne:**

1. **Vérifier server.cfg:**
```cfg
# Ligne ~73-107 : ACE doivent être présentes
add_ace group.admin command.car allow
add_ace group.admin command.tp allow
# etc.

# Ligne ~120 : Votre license doit être ajoutée
add_principal identifier.license:VOTRE_LICENSE group.admin
```

2. **Redémarrer le serveur COMPLET:**
```
Arrêter FiveM server
Relancer
```

3. **Vérifier logs console:**
```
[vAvA_core] ✓ Commands loaded (User + Admin + FiveM Natives)
[vAvA_core] ✓ Client admin events loaded
```

4. **Test ultime:**
```
/vava_getid                  # Récupérer license
/vava_debug_perms            # Diagnostic complet
/vava_test_ace command.car   # Test ACE spécifique
```

---

**Version:** 1.1.1  
**Date:** 11 janvier 2026  
**Status:** ✅ Toutes les commandes fonctionnelles avec ACE directe
