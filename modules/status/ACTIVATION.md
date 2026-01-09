# 🔌 Activation du Module Status

## Architecture modulaire vAvA

Le module **vAvA_status** est un module autonome situé dans:

```
vAvA_core/
└── modules/
    └── status/          ← Module autonome
        ├── fxmanifest.lua
        ├── config/
        ├── server/
        ├── client/
        └── ...
```

## 📦 Méthode d'activation

### Option 1: Copier vers le dossier resources (Recommandé)

```bash
# Copier le module vers le dossier resources
cp -r vAvA_core/modules/status resources/vAvA_status

# Ou sur Windows:
xcopy /E /I vAvA_core\modules\status resources\vAvA_status
```

Puis dans `server.cfg`:

```cfg
ensure vAvA_core
ensure vAvA_status
```

### Option 2: Lien symbolique

```bash
# Linux/Mac
ln -s vAvA_core/modules/status resources/vAvA_status

# Windows (admin)
mklink /D resources\vAvA_status vAvA_core\modules\status
```

Puis dans `server.cfg`:

```cfg
ensure vAvA_core
ensure vAvA_status
```

### Option 3: Utiliser comme module interne (Avancé)

Modifier `vAvA_core/fxmanifest.lua` pour inclure les fichiers du module status:

```lua
-- Dans vAvA_core/fxmanifest.lua

-- Ajouter dans shared_scripts:
shared_scripts {
    -- ... fichiers existants ...
    'modules/status/config/config.lua',
    'modules/status/shared/api.lua'
}

-- Ajouter dans server_scripts:
server_scripts {
    -- ... fichiers existants ...
    'modules/status/server/main.lua'
}

-- Ajouter dans client_scripts:
client_scripts {
    -- ... fichiers existants ...
    'modules/status/client/main.lua'
}

-- Ajouter dans files:
files {
    'modules/status/html/index.html',
    'modules/status/html/css/style.css',
    'modules/status/html/js/app.js',
    'modules/status/locales/*.lua'
}

-- Ajouter ui_page:
ui_page 'modules/status/html/index.html'
```

⚠️ **Note:** Cette méthode nécessite de redémarrer vAvA_core à chaque modification du module status.

---

## ✅ Vérification de l'activation

### Méthode 1: Console serveur

Chercher dans les logs:

```
[vAvA Status] Initialisation du système de statuts...
[vAvA Status] Système de statuts initialisé avec succès !
```

### Méthode 2: En jeu

1. Se connecter au serveur
2. Observer le HUD en bas à droite
3. Si visible → ✅ Module actif

### Méthode 3: Console F8 (client)

```javascript
// Tester les exports
GetResourceState('vAvA_status')
// Devrait retourner: "started"
```

### Méthode 4: Testbench

```
/testbench
→ Onglet "Modules"
→ vAvA_status devrait apparaître dans la liste
```

---

## 🔄 Ordre de chargement recommandé

```cfg
# server.cfg

ensure oxmysql           # 1. Base de données
ensure vAvA_core         # 2. Framework principal
ensure vAvA_status       # 3. Module status
ensure vAvA_inventory    # 4. Inventaire (si séparé)
ensure vAvA_economy      # 5. Économie (si séparé)
```

**Important:** vAvA_status doit être chargé **après** vAvA_core.

---

## 🐛 Dépannage

### Erreur: "Resource vAvA_status not found"

**Solution:** Le module n'est pas dans le bon dossier.

```bash
# Vérifier:
ls resources/vAvA_status/fxmanifest.lua

# Devrait exister
```

### Erreur: "exports['vAvA_status'] is undefined"

**Solution:** Le module n'est pas démarré.

```cfg
# Dans server.cfg, ajouter:
ensure vAvA_status
```

### Erreur: "Table player_status doesn't exist"

**Solution:** La table se crée automatiquement. Si erreur persiste:

```sql
-- Créer manuellement:
CREATE TABLE IF NOT EXISTS player_status (
    identifier VARCHAR(50) PRIMARY KEY,
    hunger INT DEFAULT 100,
    thirst INT DEFAULT 100,
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Le HUD ne s'affiche pas

**Solutions:**

1. Vérifier que vAvA_status est bien démarré (console serveur)
2. Vérifier `StatusConfig.Enabled = true` dans config
3. Vérifier `StatusConfig.HUD.enabled = true` dans config
4. F8 → Vérifier erreurs JavaScript
5. Redémarrer le module: `restart vAvA_status`

---

## 📝 Checklist d'activation

- [ ] Module copié dans `resources/vAvA_status/` (ou lien symbolique)
- [ ] `ensure vAvA_status` ajouté dans server.cfg
- [ ] vAvA_status chargé après vAvA_core
- [ ] Console serveur affiche "Système de statuts initialisé"
- [ ] HUD visible en jeu
- [ ] Tests testbench passent (12/12)

---

## 🆘 Support

Si problème persiste:

1. Consulter [README.md](README.md)
2. Consulter [INSTALLATION.md](INSTALLATION.md)
3. Vérifier logs serveur (console)
4. Vérifier logs client (F8)
5. Tester avec `/debugstatus`
6. Contacter l'équipe vAvA

---

<div align="center">

**Module prêt à l'emploi ! 🚀**

🔴 **vAvACore – Le cœur du développement** 🔴

</div>
