# 🔐 Guide de Configuration des Permissions vAvA_core

## 🎯 Vue d'ensemble

Le système de permissions de vAvA_core utilise les **ACE Permissions de txAdmin/FXServer** pour gérer les niveaux d'accès des joueurs.

---

## 📊 Niveaux de Permission

| Niveau | Nom | Description | Commandes |
|--------|-----|-------------|-----------|
| 0 | USER / HELPER | Joueur normal | Commandes RP de base |
| 1 | MOD | Modérateur | Kick, mute, spec |
| 2 | ADMIN | Administrateur | Give, tp, vehicle, weather |
| 3 | SUPERADMIN | Super Admin | Ban, unban, setjob, setmoney |
| 4 | DEVELOPER | Développeur | Debug, reload modules |
| 5 | OWNER | Propriétaire | Accès complet |

---

## 🔧 Configuration Rapide (3 étapes)

### Étape 1: Récupérer votre identifiant

1. Connectez-vous sur votre serveur
2. Tapez dans le chat: `/vava_getid`
3. Vos identifiants s'affichent dans le chat ET dans la console serveur

**Exemple de sortie:**
```
=== VOS IDENTIFIANTS ===
License: license:9ca277a68ad4d2c3324edf1f068c2a8229f069fd
Discord: discord:123456789012345678
Steam: steam:11000010a1b2c3d
```

### Étape 2: Modifier le server.cfg

Ouvrez `server.cfg` et cherchez la section des permissions (ligne ~72-85).

Décommentez et modifiez une ligne selon votre identifiant:

```cfg
# AVANT (commenté):
# add_principal identifier.license:VOTRE_LICENSE_ICI group.admin

# APRÈS (décommenté et modifié):
add_principal identifier.license:9ca277a68ad4d2c3324edf1f068c2a8229f069fd group.admin
```

**Groupes disponibles:**
- `group.owner` - Niveau 5 (accès total)
- `group.developer` - Niveau 4
- `group.superadmin` - Niveau 3
- `group.admin` - Niveau 2
- `group.mod` - Niveau 1
- `group.helper` - Niveau 0

### Étape 3: Redémarrer le serveur

```bash
restart vAvA_core
```

Ou redémarrez complètement le serveur FiveM.

---

## 🎨 Exemples Complets

### Ajouter un Owner (niveau max)

```cfg
# Avec License
add_principal identifier.license:9ca277a68ad4d2c3324edf1f068c2a8229f069fd group.owner

# Avec Discord
add_principal identifier.discord:123456789012345678 group.owner

# Avec Steam
add_principal identifier.steam:11000010a1b2c3d group.owner
```

### Ajouter plusieurs admins

```cfg
# Owner principal
add_principal identifier.license:abc123... group.owner

# Admin 1
add_principal identifier.license:def456... group.admin

# Admin 2 (via Discord)
add_principal identifier.discord:789012... group.admin

# Modérateur
add_principal identifier.discord:345678... group.mod

# Helper
add_principal identifier.license:ghi789... group.helper
```

---

## 🔍 Vérifier les Permissions

### En jeu:

```
/vava_getid         → Affiche vos identifiants
/admin              → Test si vous avez accès admin
/give 1 bread 10    → Test si vous pouvez give des items
```

### En console:

```lua
-- Vérifier les ACE d'un joueur
source = 1
print(IsPlayerAceAllowed(source, 'vava.admin'))

-- Vérifier le niveau d'un joueur
local player = vCore.GetPlayer(1)
print(player:GetPermissionLevel())
print(player:IsAdmin())
```

---

## 🛠️ Dépannage

### ❌ "Vous n'avez pas la permission"

**Cause:** Identifiant incorrect ou groupe mal configuré

**Solutions:**
1. Vérifiez que l'identifiant est exact (espaces, casse)
2. Vérifiez que le groupe existe (`group.admin` pas `group.administrator`)
3. Redémarrez le serveur après modification
4. Utilisez `/vava_getid` pour confirmer votre identifiant

### ❌ ACE non reconnues

**Cause:** Ordre de chargement incorrect

**Solution:** Vérifiez que `ensure vAvA_core` est APRÈS `ensure oxmysql` dans `server.cfg`

### ❌ Permissions fonctionnent dans txAdmin mais pas en jeu

**Cause:** Config.Permissions.Method incorrect

**Solution:** Vérifiez dans `config/config.lua`:
```lua
Config.Permissions = {
    Method = 'ace',  -- DOIT être 'ace' pour txAdmin
    AcePrefix = 'vava',
    -- ...
}
```

---

## 🎯 Permissions ACE Avancées

### Structure des ACE vAvA:

```
vava.owner          → Propriétaire (niveau 5)
vava.developer      → Développeur (niveau 4)
vava.dev            → Alias de developer
vava.superadmin     → Super Admin (niveau 3)
vava.admin          → Admin (niveau 2)
vava.mod            → Modérateur (niveau 1)
vava.moderator      → Alias de mod
vava.helper         → Helper (niveau 0)
```

### Créer des permissions personnalisées:

Dans `server.cfg`:

```cfg
# Donner une permission spécifique
add_ace group.admin vava.teleport allow

# Retirer une permission
add_ace group.mod vava.ban deny

# Créer un groupe custom
add_ace group.trial_admin vava.give allow
add_ace group.trial_admin vava.tp allow
add_principal identifier.license:abc123 group.trial_admin
```

---

## 📋 Liste des Commandes par Niveau

### Niveau 0 (USER/HELPER)
- `/me` - Action RP
- `/do` - Description RP
- `/ooc` - Message OOC
- `/vava_getid` - Voir ses identifiants

### Niveau 1 (MOD)
- Toutes les commandes USER +
- `/kick` - Kick un joueur
- `/spec` - Spectate un joueur
- `/freeze` - Freeze un joueur

### Niveau 2 (ADMIN)
- Toutes les commandes MOD +
- `/give` - Donner des items
- `/tp` - Se téléporter
- `/tpto` - TP vers un joueur
- `/bring` - Amener un joueur
- `/vehicle` - Spawn un véhicule
- `/dv` - Delete véhicule
- `/repair` - Réparer véhicule
- `/weather` - Changer météo
- `/time` - Changer heure

### Niveau 3 (SUPERADMIN)
- Toutes les commandes ADMIN +
- `/ban` - Ban un joueur
- `/unban` - Unban un joueur
- `/setjob` - Changer job d'un joueur
- `/setmoney` - Modifier argent
- `/revive` - Réanimer
- `/heal` - Soigner

### Niveau 4 (DEVELOPER)
- Toutes les commandes SUPERADMIN +
- `/refresh` - Refresh resource
- `/restart` - Restart resource
- `/noclip` - Mode noclip
- `/coords` - Afficher coordonnées
- `/debug` - Mode debug

### Niveau 5 (OWNER)
- Toutes les commandes DEVELOPER +
- Accès complet à tous les modules
- Modification config en live
- Accès console MySQL

---

## 🔐 Sécurité

### Bonnes pratiques:

1. **Ne jamais partager votre license**
2. **Utilisez Discord ID pour les admins** (plus facile à révoquer)
3. **Donnez le niveau minimum nécessaire**
4. **Documentez qui a quel niveau**
5. **Révisez régulièrement les permissions**

### Révoquer un admin:

```cfg
# Commentez ou supprimez la ligne dans server.cfg:
# add_principal identifier.license:abc123 group.admin

# Puis redémarrez le serveur
restart vAvA_core
```

---

## 📚 Références

- **Fichiers de configuration:**
  - `server.cfg` - ACE principals (ligne 72-85)
  - `config/config.lua` - Config.Permissions (ligne 363-412)
  - `shared/permissions.lua` - Fonctions de vérification
  - `shared/classes.lua` - Méthodes player (ligne 405-440)
  - `shared/enums.lua` - AdminLevel enum (ligne 55-66)

- **Documentation FiveM:**
  - [ACE Permissions](https://docs.fivem.net/docs/server-manual/setting-up-a-server/#permissions-aces)
  - [Identifiers](https://docs.fivem.net/docs/scripting-reference/runtimes/lua/functions/GetPlayerIdentifiers/)

---

## ✅ Checklist de Configuration

- [ ] J'ai utilisé `/vava_getid` pour récupérer mon identifiant
- [ ] J'ai ajouté la ligne `add_principal identifier.license:... group.admin` dans `server.cfg`
- [ ] J'ai décommenté la ligne (enlevé le #)
- [ ] J'ai redémarré le serveur
- [ ] J'ai testé avec `/admin` ou `/give` en jeu
- [ ] Mes permissions fonctionnent correctement

---

## 🆘 Support

Si vous rencontrez des problèmes:

1. Vérifiez les logs console: `F8` en jeu
2. Vérifiez les logs serveur FiveM
3. Testez `/vava_getid` pour confirmer l'identifiant
4. Vérifiez que `Config.Permissions.Method = 'ace'` dans config.lua
5. Consultez ce guide: [GUIDE_PERMISSIONS.md](GUIDE_PERMISSIONS.md)

---

**Version:** 1.1.0  
**Dernière mise à jour:** 2025-01-11  
**Auteur:** vAvA Development Team
