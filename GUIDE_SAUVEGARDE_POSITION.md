# 💾 Système de Sauvegarde de Position - vAvA_core

## 🎯 Vue d'ensemble

Le système de sauvegarde automatique enregistre la position et les données des joueurs à intervalles réguliers et lors d'événements importants.

---

## ⚙️ Configuration

### Fichier: `config/config.lua` (ligne ~52-64)

```lua
Config.Players.AutoSave = {
    enabled = true,                       -- Activer la sauvegarde auto
    interval = 300000,                    -- 5 minutes (en ms)
    saveOnDisconnect = true,              -- Sauvegarder à la déconnexion
    saveOnDeath = true,                   -- Sauvegarder à la mort
    saveOnVehicleChange = false,          -- Sauvegarder au changement véhicule
    savePosition = true,                  -- Sauvegarder la position
    saveStatus = true,                    -- Sauvegarder hunger/thirst
    saveMoney = true,                     -- Sauvegarder l'argent
    saveInventory = true,                 -- Sauvegarder l'inventaire
    debug = false                         -- Afficher logs sauvegarde
}
```

---

## 🔄 Modes de Sauvegarde

### 1. Sauvegarde Automatique Périodique

**Intervalle:** Défini par `interval` (5 minutes par défaut)

```lua
interval = 300000  -- 5 minutes
interval = 180000  -- 3 minutes
interval = 600000  -- 10 minutes
```

**Fonctionnement:**
- S'exécute toutes les X minutes automatiquement
- Sauvegarde **position + heading** du joueur
- Ne sauvegarde que si le joueur est **vivant**
- Évite les sauvegardes multiples rapprochées

---

### 2. Sauvegarde à la Déconnexion

**Option:** `saveOnDisconnect = true`

**Fonctionnement:**
- Sauvegarde **immédiate** quand le joueur se déconnecte
- Capture la dernière position connue
- Sauvegarde **complète** (position, argent, inventaire, etc.)

---

### 3. Sauvegarde à la Mort

**Option:** `saveOnDeath = true`

**Fonctionnement:**
- Sauvegarde quand le joueur meurt
- Capture la position de la mort
- Utile pour systèmes de réapparition

---

### 4. Sauvegarde au Changement de Véhicule

**Option:** `saveOnVehicleChange = false` (désactivé par défaut)

**Fonctionnement:**
- Sauvegarde quand le joueur **entre** dans un véhicule (siège conducteur)
- Attends 2 secondes après l'entrée pour stabilisation
- Peut générer beaucoup de sauvegardes (désactivé par défaut)

---

### 5. Sauvegarde Manuelle

**Commande joueur:** `/save`

```
/save
```

**Résultat:**
- Notification: "Sauvegarde en cours..."
- Sauvegarde **immédiate** de la position actuelle
- Accessible à **tous les joueurs**

---

## 👮 Commandes Admin

### `/saveall` - Sauvegarder Tous les Joueurs

**Permission:** `command.saveall` (DEVELOPER/OWNER)

**Usage:**
```
/saveall
```

**Résultat:**
```
Sauvegarde complète: 12/15 joueurs
```

**Fonction:**
- Sauvegarde **tous** les joueurs connectés
- Met à jour leur position actuelle
- Affiche nombre de sauvegardes réussies
- Utile avant restart serveur

---

### `/saveplayer [id]` - Sauvegarder un Joueur

**Permission:** `command.saveplayer` (ADMIN+)

**Usage:**
```
/saveplayer 1
```

**Résultat:**
```
Joueur #1 sauvegardé
```

**Fonction:**
- Sauvegarde un joueur spécifique
- Met à jour sa position actuelle
- Utile pour debug ou avant action admin

---

## 🐛 Mode Debug

### Activer le Debug

**Option 1: Config**
```lua
Config.Players.AutoSave = {
    debug = true  -- Afficher logs
}
```

**Option 2: Convar (server.cfg)**
```cfg
set vava_debug_save true
```

### Logs Debug

**Console Client:**
```
[vAvA_core] Position sauvegardée: 123, 456, 78
[vAvA_core] Sauvegarde déclenchée: Mort du joueur
[vAvA_core] Sauvegarde déclenchée: Véhicule
```

**Console Serveur:**
```
[vAvA_core] Position mise à jour: Joueur123 → 123, 456
[vAvA_core] Sauvegarde complète: Joueur123
[vAvA_core] Sauvegarde réussie pour: Joueur123
```

---

## 📊 Données Sauvegardées

### Position
```lua
{
    x = 123.45,
    y = 456.78,
    z = 31.20,
    heading = 205.0
}
```

### Données Complètes (Sauvegarde manuelle/déconnexion)
- ✅ Position (x, y, z, heading)
- ✅ Argent (cash, bank, black_money)
- ✅ Job (name, grade)
- ✅ Gang
- ✅ Status (hunger, thirst, stress)
- ✅ Inventaire (items, armes)
- ✅ Métadonnées (custom data)

---

## 🎮 Utilisation Pratique

### Configuration Recommandée

**Serveur Public (Beaucoup de joueurs):**
```lua
AutoSave = {
    enabled = true,
    interval = 600000,          -- 10 minutes (moins de charge)
    saveOnDisconnect = true,
    saveOnDeath = true,
    saveOnVehicleChange = false,
    debug = false
}
```

**Serveur RP Privé:**
```lua
AutoSave = {
    enabled = true,
    interval = 180000,          -- 3 minutes (plus fréquent)
    saveOnDisconnect = true,
    saveOnDeath = true,
    saveOnVehicleChange = true, -- Tracking précis
    debug = false
}
```

**Serveur Test/Dev:**
```lua
AutoSave = {
    enabled = true,
    interval = 60000,           -- 1 minute (test rapide)
    saveOnDisconnect = true,
    saveOnDeath = true,
    saveOnVehicleChange = true,
    debug = true                -- Voir tous les logs
}
```

---

## 🔧 Optimisation Performance

### Réduire la Charge Serveur

1. **Augmenter l'intervalle:**
```lua
interval = 600000  -- 10 minutes au lieu de 5
```

2. **Désactiver sauvegarde véhicule:**
```lua
saveOnVehicleChange = false
```

3. **Sauvegarder uniquement position:**
```lua
savePosition = true
saveStatus = false
saveInventory = false
```

### Impact Performance

| Intervalle | Sauvegardes/h | Impact |
|------------|--------------|--------|
| 1 minute | 60 | 🔴 Élevé |
| 3 minutes | 20 | 🟡 Moyen |
| 5 minutes | 12 | 🟢 Faible |
| 10 minutes | 6 | 🟢 Très faible |

---

## 🛠️ Dépannage

### ❌ Position non sauvegardée

**Vérifications:**
1. Config activée:
```lua
Config.Players.AutoSave.enabled = true
Config.Players.AutoSave.savePosition = true
```

2. Intervalle correct:
```lua
interval = 300000  -- Pas 0 ou négatif
```

3. Logs debug:
```lua
debug = true
```

4. Vérifier table BDD:
```sql
SELECT id, firstname, lastname, position FROM characters LIMIT 5;
```

---

### ❌ "Position not saved" dans logs

**Cause:** Player object non trouvé

**Solution:**
```lua
-- Vérifier que le joueur a un personnage chargé
local player = vCore.GetPlayer(source)
if player then
    -- OK
end
```

---

### ❌ Sauvegarde trop fréquente

**Cause:** Intervalle trop court ou saveOnVehicleChange activé

**Solution:**
```lua
interval = 600000              -- Augmenter à 10 min
saveOnVehicleChange = false    -- Désactiver
```

---

## 📋 Checklist Installation

- [ ] Configuration dans `config/config.lua`
- [ ] Intervalle défini (5 minutes recommandé)
- [ ] `saveOnDisconnect = true`
- [ ] `savePosition = true`
- [ ] ACE ajoutées dans server.cfg (saveall, saveplayer)
- [ ] Table `characters` avec colonne `position` (JSON)
- [ ] Test commande `/save` en jeu
- [ ] Test déconnexion/reconnexion
- [ ] Vérification position en BDD

---

## 📚 Événements Disponibles

### Serveur

```lua
-- Déclenché après sauvegarde réussie
AddEventHandler('vCore:playerSaved', function(source, player)
    print('Joueur sauvegardé: ' .. player:GetName())
end)
```

### Client

```lua
-- Recevoir l'intervalle de sauvegarde
RegisterNetEvent('vCore:setSaveInterval', function(interval)
    print('Intervalle: ' .. (interval / 1000) .. 's')
end)
```

---

## 🎯 Exemples d'Usage

### Sauvegarder avant action importante

```lua
-- Avant téléportation
RegisterCommand('tpevent', function(source)
    local player = vCore.GetPlayer(source)
    if player then
        vCore.DB.SavePlayer(player)  -- Sauvegarde avant TP
        -- Téléporter...
    end
end)
```

### Notification périodique

```lua
-- Notifier les joueurs
AddEventHandler('vCore:playerSaved', function(source, player)
    TriggerClientEvent('vCore:Notify', source, 'Progression sauvegardée', 'success')
end)
```

### Sauvegarder avant restart

```lua
-- Console serveur: sauvegarder tous avant restart
saveall
wait 3
restart vAvA_core
```

---

## 🔐 Sécurité

### Bonnes Pratiques

1. **Ne pas sauvegarder trop souvent** (charge BDD)
2. **Activer saveOnDisconnect** (crucial)
3. **Debug = false en production** (logs spam)
4. **Backup BDD réguliers** (safety)
5. **Logs des sauvegardes ratées**

---

## 📊 Statistiques

**Avec 50 joueurs:**
- Intervalle 5 min = **600 requêtes SQL/h**
- Intervalle 10 min = **300 requêtes SQL/h**

**Recommandation:** 5-10 minutes pour équilibre performance/sécurité

---

**Version:** 1.1.2  
**Dernière mise à jour:** 2026-01-11  
**Auteur:** vAvA Development Team
