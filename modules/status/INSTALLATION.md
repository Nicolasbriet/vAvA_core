# 🚀 Installation Rapide - vAvA Status

## ⚡ Installation en 3 étapes

### Étape 1: Vérification

Le module est déjà intégré dans vAvA_core:

```bash
vAvA_core/
└── modules/
    └── status/  ← Déjà présent
```

### Étape 2: Configuration

Aucune configuration supplémentaire nécessaire ! Le module se charge automatiquement avec vAvA_core.

**Optionnel:** Personnaliser les paramètres dans [`modules/status/config/config.lua`](config/config.lua)

### Étape 3: Redémarrage

```bash
restart vAvA_core
```

C'est tout ! ✅

---

## 🎮 Test en jeu

1. **Se connecter au serveur**
2. **Observer le HUD** en bas à droite (barres faim/soif)
3. **Utiliser un item food/drink** depuis l'inventaire
4. **Observer la barre monter** 📈
5. **Attendre 5 minutes**, observer la décrémentation 📉

---

## ⚙️ Configuration personnalisée (optionnel)

### Changer la position du HUD

```lua
-- config/config.lua, ligne ~145
StatusConfig.HUD = {
    position = 'bottom-right',  -- Changer ici
    -- Options: bottom-right, bottom-left, top-right, top-left
}
```

### Ajuster la vitesse de décrémentation

```lua
-- config/config.lua, ligne ~13
StatusConfig.UpdateInterval = 5  -- Minutes (défaut: 5)

StatusConfig.Decrementation = {
    hunger = { min = 1, max = 3 },  -- Perte par interval
    thirst = { min = 2, max = 4 }   -- La soif descend plus vite
}
```

### Masquer le HUD quand plein

```lua
-- config/config.lua, ligne ~149
StatusConfig.HUD = {
    hideWhenFull = true,  -- Masquer si faim/soif = 100%
}
```

---

## 🧪 Tester avec Testbench

```
1. /testbench
2. Onglet "Modules"
3. Chercher "vAvA_status"
4. Cliquer "Run Tests"
5. Vérifier: 12/12 tests passent ✅
```

---

## 🔧 Dépannage rapide

### Le HUD ne s'affiche pas

```lua
-- Vérifier dans config/config.lua:
StatusConfig.Enabled = true
StatusConfig.HUD.enabled = true
```

### La faim/soif ne descend pas

```lua
-- Vérifier dans config/config.lua:
StatusConfig.Enabled = true
StatusConfig.UpdateInterval = 5  -- Pas 0 !
```

### Les items ne restaurent pas

1. Vérifier que l'item est dans `StatusConfig.ConsumableItems`
2. Vérifier les logs serveur (F8)
3. Activer les logs: `StatusConfig.Logging.logConsumption = true`

---

## 📚 Documentation complète

- [README.md](README.md) - Documentation complète
- [CREATION_COMPLETE.md](CREATION_COMPLETE.md) - Rapport de création
- [config/config.lua](config/config.lua) - Toutes les options
- [../doc/vava_status_cahier_des_charges.md](../doc/vava_status_cahier_des_charges.md) - Cahier des charges

---

## 🆘 Support

Besoin d'aide ?

1. Consulter le [README.md](README.md)
2. Vérifier les logs serveur (console)
3. Tester avec `/debugstatus` (console F8)
4. Contacter l'équipe vAvA

---

## ✅ Checklist installation

- [ ] Fichiers présents dans `modules/status/`
- [ ] vAvA_core redémarré
- [ ] HUD visible en jeu
- [ ] Items food/drink restaurent bien
- [ ] Décrémentation fonctionne (attendre 5min)
- [ ] Tests testbench passent (12/12)

---

<div align="center">

**Installation terminée ! 🎉**

Le système de faim et soif est maintenant actif.

🔴 **vAvACore – Le cœur du développement** 🔴

</div>
