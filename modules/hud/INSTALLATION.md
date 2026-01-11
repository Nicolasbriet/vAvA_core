# 🚀 Installation Rapide - Module vAvA_hud

> **Version:** 1.0.0  
> **Date:** 11 Janvier 2026  
> **Prérequis:** vAvA_core installé

---

## ⚡ Installation en 3 Étapes

### 1. Vérifier la Structure

Assurez-vous que le module est dans:
```
resources/[vava]/vAvA_hud/
```

### 2. Ajouter dans server.cfg

```cfg
# vAvA Framework
ensure vAvA_core
ensure vAvA_hud  # ← Nouveau module
```

### 3. Redémarrer le Serveur

```bash
restart vAvA_core
restart vAvA_hud
```

---

## ✅ Vérification

1. **Se connecter** au serveur
2. **Le HUD s'affiche** automatiquement
3. **Tester F7** pour toggle le HUD
4. **Vérifier** les 4 sections:
   - 📊 Status (bas gauche)
   - 💰 Argent (haut droite)
   - 👤 Infos joueur (haut gauche)
   - 🚗 Véhicule (bas droite, en véhicule uniquement)

---

## 🔧 Configuration (Optionnel)

Éditer `vAvA_hud/config/config.lua` pour personnaliser:

```lua
HUDConfig = {
    Enabled = true,              -- Activer/désactiver
    
    Position = {
        Status = 'bottom-left',  -- Position des status
        Money = 'top-right',     -- Position de l'argent
        -- ...
    },
    
    Display = {
        Health = true,           -- Afficher santé
        Armor = true,            -- Afficher armure
        Stress = false,          -- Stress désactivé par défaut
        -- ...
    },
    
    Settings = {
        UpdateInterval = 500,    -- 500ms = 0.5 seconde
        -- ...
    }
}
```

---

## 🐛 Debug

Si problème, activer le debug:

```lua
HUDConfig.Debug = {
    enabled = true,
    showLogs = true,
    command = 'debughud'
}
```

Puis taper `/debughud` dans F8 pour voir les données.

---

## 📚 Documentation Complète

- **README.md** : Documentation utilisateur complète
- **CREATION_COMPLETE.md** : Rapport de création technique
- **EXTRACTION_MODULE_HUD.md** : Rapport d'extraction du core

---

## 💬 Support

**Problème courant:** Le HUD ne s'affiche pas
- ✅ Vérifier que vAvA_core est démarré **avant** vAvA_hud
- ✅ Vérifier dans config: `HUDConfig.Enabled = true`
- ✅ Tester `/debughud` pour diagnostiquer

---

**C'est tout! Le module est prêt à l'emploi.** 🎉

**Développé par vAvA** - Conforme à la charte graphique vAvACore
