# 🎮 Commandes FiveM Natives - vAvA_core

## 🎯 Vue d'ensemble

Ce document liste toutes les **commandes FiveM natives** disponibles selon votre niveau de permission.

---

## 📋 Commandes par Niveau

### 🟢 Niveau MOD (1)

| Commande | Description | Exemple |
|----------|-------------|---------|
| `/kick [id] [raison]` | Expulser un joueur | `/kick 1 AFK trop longtemps` |
| `/freeze [id]` | Geler un joueur | `/freeze 5` |
| `/unfreeze [id]` | Dégeler un joueur | `/unfreeze 5` |

---

### 🔵 Niveau ADMIN (2)

**Toutes les commandes MOD +**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `/car [modèle]` | Spawn un véhicule | `/car adder` |
| `/tp [x] [y] [z]` | Se téléporter | `/tp 100 200 30` |
| `/tpm` | TP au marker | `/tpm` |
| `/bring [id]` | Amener un joueur | `/bring 3` |
| `/goto [id]` | TP vers un joueur | `/goto 3` |
| `/freeze [id]` | Geler un joueur | `/freeze 5` |
| `/unfreeze [id]` | Dégeler un joueur | `/unfreeze 5` |
| `/weather [météo]` | Changer météo | `/weather clear` |
| `/time [heure] [minute]` | Changer heure | `/time 12 30` |

**Météos disponibles:**
- `clear` - Clair
- `extrasunny` - Très ensoleillé
- `clouds` - Nuageux
- `overcast` - Couvert
- `rain` - Pluie
- `thunder` - Orage
- `foggy` - Brouillard
- `snow` - Neige

---

### 🟣 Niveau SUPERADMIN (3)

**Toutes les commandes ADMIN +**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `/setjob [id] [job] [grade]` | Changer job | `/setjob 1 police 3` |
| `/setmoney [id] [type] [montant]` | Modifier argent | `/setmoney 1 cash 5000` |
| `/setgroup [id] [groupe]` | Changer groupe | `/setgroup 1 admin` |
| `/ban [id] [durée] [raison]` | Bannir un joueur | `/ban 1 24h Cheat` |
| `/unban [license]` | Débannir un joueur | `/unban license:abc123` |

**Types d'argent:**
- `cash` - Argent liquide
- `bank` - Banque
- `black` - Argent sale

**Groupes:**
- `user` - Joueur (0)
- `helper` - Helper (0)
- `mod` - Modérateur (1)
- `admin` - Admin (2)
- `superadmin` - Super Admin (3)
- `developer` - Développeur (4)
- `owner` - Propriétaire (5)

---

### 🔴 Niveau DEVELOPER (4)

**Toutes les commandes SUPERADMIN +**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `/restart [resource]` | Redémarrer resource | `/restart vAvA_core` |
| `/refresh` | Refresh resources | `/refresh` |
| `/start [resource]` | Démarrer resource | `/start vAvA_chat` |
| `/stop [resource]` | Arrêter resource | `/stop vAvA_chat` |
| `/ensure [resource]` | Ensure resource | `/ensure vAvA_core` |

---

### ⚫ Niveau OWNER (5)

**Toutes les commandes DEVELOPER +**

| Commande | Description | Exemple |
|----------|-------------|---------|
| `command allow` | Toutes les commandes | Accès complet |
| `resource.* allow` | Toutes les resources | Contrôle total |

---

## 🔧 Commandes Utiles Supplémentaires

### Commandes Système

```bash
# Console serveur
status              → État du serveur
players             → Liste des joueurs
quit                → Arrêter le serveur
exec server.cfg     → Recharger config

# En jeu (F8)
quit                → Déconnexion
reconnect           → Reconnexion
```

### Commandes de Développement

```bash
# Debug
/coords             → Afficher coordonnées
/heading            → Afficher heading
/vector3            → Format vector3
/vector4            → Format vector4

# Performance
/perf               → Performance info
/resmon             → Resource monitor
```

---

## 🎨 Véhicules Populaires

### Voitures de Sport
```
/car adder          → Bugatti
/car t20            → McLaren
/car zentorno       → Lamborghini
/car turismor       → Ferrari
/car infernus       → Lamborghini
```

### Voitures de Luxe
```
/car schafter3      → Mercedes
/car oracle2        → BMW
/car windsor        → Rolls Royce
/car cognoscenti    → Bentley
```

### Véhicules Utilitaires
```
/car stockade       → Camion blindé
/car benson         → Camion
/car mule           → Fourgon
/car pounder        → Grand camion
```

### Véhicules d'Urgence
```
/car police         → Voiture police
/car police2        → SUV police
/car ambulance      → Ambulance
/car firetruk       → Camion pompier
```

### Motos
```
/car bati           → Sport bike
/car akuma          → Sport bike
/car hexer          → Cruiser
/car sovereign      → Harley style
```

### Hélicoptères
```
/car buzzard        → Hélico combat
/car frogger        → Hélico civil
/car maverick       → Hélico tourisme
/car polmav         → Hélico police
```

---

## 🛠️ Configuration ACE

Pour ajouter/modifier les permissions dans [server.cfg](d:\fivemserver\vAvA_core\server.cfg):

### Donner une commande à un groupe

```cfg
# Format:
add_ace group.GROUPE command.COMMANDE allow

# Exemples:
add_ace group.admin command.car allow
add_ace group.mod command.kick allow
add_ace group.superadmin command.ban allow
```

### Retirer une commande à un groupe

```cfg
add_ace group.admin command.ban deny
```

### Créer un groupe custom

```cfg
# Créer le groupe avec quelques commandes
add_ace group.trial_admin command.tp allow
add_ace group.trial_admin command.car allow
add_ace group.trial_admin command.freeze allow

# Ajouter des joueurs au groupe
add_principal identifier.license:abc123 group.trial_admin
```

---

## 🔍 Vérification des Permissions

### Tester une commande

```lua
-- Console serveur
IsPlayerAceAllowed(1, "command.car")
IsPlayerAceAllowed(1, "command.ban")
```

### Voir toutes les permissions d'un joueur

```
/vava_debug_perms
```

### Tester une ACE spécifique

```
/vava_test_ace command.car
/vava_test_ace command.setjob
```

---

## ⚠️ Dépannage

### ❌ "You do not have permission to use this command"

**Causes possibles:**
1. Votre groupe n'a pas la permission `command.COMMANDE`
2. Vous n'êtes pas assigné à un groupe dans server.cfg
3. Le serveur n'a pas été redémarré après modification

**Solutions:**

1. **Vérifier votre groupe:**
```
/vava_debug_perms
```

2. **Vérifier les ACE dans server.cfg:**
```cfg
# Ligne ~70-120
add_ace group.admin command.car allow
add_ace group.admin command.tp allow
# etc.
```

3. **Vérifier que vous êtes assigné:**
```cfg
# Ligne ~85
add_principal identifier.license:VOTRE_LICENSE group.admin
```

4. **Redémarrer le serveur:**
```
restart vAvA_core
```

### ❌ Commande ne fait rien

**Causes:**
- Mauvais format de commande
- ID joueur invalide
- Véhicule inexistant

**Solutions:**
- Vérifier la syntaxe: `/car adder` pas `/car 1 adder`
- Utiliser `/vava_getid` pour l'ID
- Vérifier le nom du véhicule (pas d'espaces)

---

## 📚 Liste Complète des Véhicules

Pour une liste complète des véhicules:
- [GTA V Vehicles](https://wiki.rage.mp/index.php?title=Vehicles)
- [FiveM Documentation](https://docs.fivem.net/docs/game-references/game-vehicles/)

---

## 🔐 Sécurité

### ⚠️ Bonnes Pratiques

1. **Ne donnez pas `command allow`** sauf au owner
2. **Limitez l'accès à `/restart` et `/stop`** (peut crash le serveur)
3. **Surveillez l'utilisation de `/car`** (abus possible)
4. **Loggez les commandes sensibles** (/ban, /setmoney)
5. **Révisez régulièrement les groupes**

### Commandes Dangereuses

⚠️ Ces commandes peuvent causer des problèmes:
- `/stop [resource]` - Peut casser le serveur
- `/restart [resource]` - Peut déconnecter les joueurs
- `/setmoney` - Peut déséquilibrer l'économie
- `/car` - Abus possible (spawn mass)

**Recommandation:** Réservez-les aux SUPERADMIN+ uniquement.

---

## ✅ Checklist

- [ ] J'ai ajouté ma license dans server.cfg
- [ ] J'ai redémarré le serveur
- [ ] `/vava_debug_perms` confirme mon niveau
- [ ] Je peux utiliser `/car [modèle]`
- [ ] Je peux utiliser `/tp [x] [y] [z]`
- [ ] Mes commandes admin fonctionnent

---

## 🆘 Support

**Commandes de diagnostic:**
- `/vava_getid` - Voir vos identifiants
- `/vava_debug_perms` - Diagnostic complet
- `/vava_test_ace command.car` - Tester une commande
- `/vava_list_aces` - Lister vos ACE

**Documentation:**
- [GUIDE_PERMISSIONS.md](GUIDE_PERMISSIONS.md) - Guide permissions complet
- [FIX_PERMISSIONS_SESSION_11JAN.md](FIX_PERMISSIONS_SESSION_11JAN.md) - Rapport technique

---

**Version:** 1.1.1  
**Dernière mise à jour:** 2025-01-11  
**Auteur:** vAvA Development Team
