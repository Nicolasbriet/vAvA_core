# 🔐 Configuration des Permissions txAdmin pour vAvA Core

## 📋 Vue d'ensemble

vAvA Core utilise le système **ACE (Access Control Entries)** de FiveM, géré par **txAdmin**.
Les permissions sont vérifiées automatiquement via `IsPlayerAceAllowed()`.

---

## 🎯 Permissions ACE disponibles

| Permission | Niveau | Description |
|------------|--------|-------------|
| `vava.owner` | 5 | Propriétaire - Accès total |
| `vava.developer` | 4 | Développeur - Accès complet |
| `vava.superadmin` | 3 | Super Admin - Administration avancée |
| `vava.admin` | 2 | Admin - Administration standard |
| `vava.mod` | 1 | Modérateur - Modération basique |
| `vava.helper` | 0 | Helper - Assistance |

---

## ⚙️ Configuration dans server.cfg

Ajoutez ces lignes à votre `server.cfg` pour créer les groupes de permissions :

```cfg
# ═══════════════════════════════════════════════════════════════════
# PERMISSIONS vAvA Core
# ═══════════════════════════════════════════════════════════════════

# Groupes de base
add_ace group.owner vava.owner allow
add_ace group.owner vava.developer allow
add_ace group.owner vava.superadmin allow
add_ace group.owner vava.admin allow
add_ace group.owner vava.mod allow
add_ace group.owner vava.helper allow

add_ace group.developer vava.developer allow
add_ace group.developer vava.superadmin allow
add_ace group.developer vava.admin allow
add_ace group.developer vava.mod allow
add_ace group.developer vava.helper allow

add_ace group.superadmin vava.superadmin allow
add_ace group.superadmin vava.admin allow
add_ace group.superadmin vava.mod allow
add_ace group.superadmin vava.helper allow

add_ace group.admin vava.admin allow
add_ace group.admin vava.mod allow
add_ace group.admin vava.helper allow

add_ace group.mod vava.mod allow
add_ace group.mod vava.helper allow

add_ace group.helper vava.helper allow

# ═══════════════════════════════════════════════════════════════════
# ATTRIBUTION DES JOUEURS AUX GROUPES
# ═══════════════════════════════════════════════════════════════════

# Format: add_principal identifier.TYPE:ID group.GROUPE

# Exemples par License Rockstar:
# add_principal identifier.license:xxxxx group.owner
# add_principal identifier.license:9ca277a68ad4d2c3324edf1f068c2a8229f069fd group.owner

# Exemples par Discord:
# add_principal identifier.discord:123456789012345678 group.admin

# Exemples par Steam:
# add_principal identifier.steam:110000xxxxxxxxx group.mod
```

---

## 🖥️ Configuration via txAdmin

### Méthode 1: Interface txAdmin

1. Allez dans **txAdmin** > **Settings** > **Game Server** > **CFG Editor**
2. Ajoutez les permissions ACE comme ci-dessus
3. Sauvegardez et redémarrez

### Méthode 2: txAdmin Admin Manager

1. Allez dans **txAdmin** > **Manage Admins**
2. Pour chaque admin, définissez les permissions
3. txAdmin attribue automatiquement `txadmin.operator` aux admins

---

## 🔄 Compatibilité

### Compatibilité txAdmin native

Les opérateurs txAdmin reçoivent automatiquement les permissions:
- `txadmin.operator` → Reconnu comme **Admin** (niveau 2)
- `txadmin.operator.super` → Reconnu comme **Owner** (niveau 5)

### Compatibilité WaveAdmin

Si vous utilisez WaveAdmin, ces permissions sont aussi reconnues:
- `WaveAdmin.owner`
- `WaveAdmin._dev`
- `WaveAdmin.god`
- `WaveAdmin.superadmin`
- `WaveAdmin.mod`
- `WaveAdmin.helper`

---

## 📝 Vérification des permissions

### Dans les scripts Lua

```lua
-- Méthode recommandée (via vCore)
if vCore.IsAdmin(source) then
    -- Le joueur est admin ou plus
end

if vCore.IsStaff(source) then
    -- Le joueur est mod ou plus
end

if vCore.HasPermissionLevel(source, 3) then
    -- Le joueur a au moins le niveau superadmin
end

local level, role = vCore.GetPermissionLevel(source)
print("Niveau:", level, "Rôle:", role)

-- Vérifier une permission ACE spécifique
if vCore.HasAce(source, 'vava.admin') then
    -- Le joueur a la permission vava.admin
end
```

### Exports disponibles

```lua
exports['vAvA_core']:IsAdmin(source)           -- boolean
exports['vAvA_core']:IsSuperAdmin(source)      -- boolean
exports['vAvA_core']:IsOwner(source)           -- boolean
exports['vAvA_core']:IsStaff(source)           -- boolean
exports['vAvA_core']:GetPermissionLevel(source) -- number, string
exports['vAvA_core']:HasAce(source, 'perm')    -- boolean
```

---

## 🔧 Configuration avancée

Dans `config/config.lua`, vous pouvez personnaliser:

```lua
Config.Permissions = {
    Method = 'ace',                    -- 'ace' pour txAdmin
    AcePrefix = 'vava',                -- Préfixe des permissions
    FallbackToGroups = true,           -- Utiliser les groupes vCore si ACE non trouvé
    
    AceLevels = {
        owner = { aces = {'vava.owner', 'txadmin.operator.super'}, level = 5 },
        developer = { aces = {'vava.developer', 'vava.dev'}, level = 4 },
        superadmin = { aces = {'vava.superadmin', 'txadmin.operator'}, level = 3 },
        admin = { aces = {'vava.admin'}, level = 2 },
        mod = { aces = {'vava.mod'}, level = 1 },
        helper = { aces = {'vava.helper'}, level = 0 }
    }
}
```

---

## ❓ FAQ

**Q: Comment savoir si mes permissions fonctionnent?**
A: Utilisez la commande `/vcore_debug` en jeu (si activée) ou vérifiez les logs serveur.

**Q: Les admins txAdmin ont-ils automatiquement accès?**
A: Oui! `txadmin.operator` donne accès admin automatiquement.

**Q: Puis-je utiliser les deux systèmes (ACE + groupes vCore)?**
A: Oui, activez `FallbackToGroups = true` dans la config. ACE est vérifié en premier.

---

*vAvA Core - Système de permissions unifié basé sur txAdmin ACE*
