# 🚀 Guide d'Installation Rapide - vAvA_ems

## ⚡ Installation en 5 minutes

### 1️⃣ Copier le module
```bash
# Le module est déjà dans: modules/ems/
# Rien à faire si vous êtes dans le bon dossier vAvA_core
```

### 2️⃣ Ajouter au server.cfg
```cfg
# Ajouter après vAvA_core
ensure vAvA_ems
```

### 3️⃣ Importer les items SQL (Optionnel)
```bash
# Si vous utilisez l'inventaire vAvA_core
mysql -u root -p votre_database < modules/ems/sql/ems_items.sql
```

### 4️⃣ Ajouter le job EMS
```bash
# Copier le fichier de job
cp modules/ems/jobs/ambulance.lua jobs/ambulance.lua

# OU ajouter manuellement via votre interface d'administration
```

### 5️⃣ Démarrer le serveur
```bash
# Les tables SQL seront créées automatiquement
# Enjoy! 🎉
```

---

## 📋 Checklist Post-Installation

- [ ] Le serveur démarre sans erreur
- [ ] Les tables SQL ont été créées (`player_medical`, `player_injuries`, etc.)
- [ ] Le job `ambulance` existe dans la base
- [ ] Les items EMS sont dans l'inventaire
- [ ] Le menu `/ems` s'ouvre pour les EMS
- [ ] Le `/911` fonctionne pour tous les joueurs
- [ ] Le HUD des signes vitaux s'affiche (si activé)

---

## 🔧 Configuration Rapide

### Désactiver le HUD pour tous (garder uniquement pour EMS)
```lua
-- config/config.lua ligne ~380
EMSConfig.HUD = {
    enabled = true,
    onlyForEMS = true,  -- ✅ Déjà configuré par défaut
    position = 'bottom-right',
    updateInterval = 1000
}
```

### Changer la langue
```lua
-- config/config.lua ligne ~8
EMSConfig.Locale = 'fr'  -- 'fr', 'en', ou 'es'
```

### Modifier le coût de respawn
```lua
-- config/config.lua ligne ~350
EMSConfig.Death = {
    respawnCost = 5000,  -- Modifier ici
    unconsciousTime = 300,
    -- ...
}
```

### Désactiver la détection automatique
```lua
-- config/config.lua ligne ~330
EMSConfig.EmergencyCalls = {
    autoDetect = false,  -- Mettre à false
    -- ...
}
```

---

## 🎮 Premiers Pas

### Pour les Joueurs
1. Appeler les urgences: `/911`
2. Choisir le type d'urgence (Rouge/Orange/Jaune/Bleu)
3. Attendre l'EMS

### Pour les EMS
1. Prendre le job EMS (job: `ambulance`)
2. Ouvrir le menu: `/ems`
3. Voir les appels d'urgence actifs
4. Se rendre sur place
5. Diagnostiquer: Proche du patient → Menu EMS → "Diagnostiquer patient"
6. Soigner avec l'équipement approprié
7. Transporter à l'hôpital si besoin

---

## 🐛 Dépannage

### Le menu ne s'ouvre pas
- Vérifier que vous avez le job `ambulance`
- Vérifier dans F8 qu'il n'y a pas d'erreur Lua
- Vérifier que `vAvA_core` est bien démarré avant

### Les appels d'urgence ne fonctionnent pas
- Vérifier la table `emergency_calls` existe
- Vérifier `EMSConfig.EmergencyCalls.enabled = true`

### Le HUD ne s'affiche pas
- Vérifier `EMSConfig.HUD.enabled = true`
- Si `onlyForEMS = true`, seuls les EMS le voient
- Vérifier la console F8 pour erreurs NUI

### Les blessures ne s'appliquent pas
- Les blessures doivent être ajoutées via code/events
- Exemple: voir README.md section "Intégration"

---

## 📞 Support

**Problème non résolu?**
- Consultez le [README.md](README.md) complet
- Ouvrez un ticket GitHub Issues
- Rejoignez notre Discord

---

## ✅ Module Prêt!

Votre module EMS est maintenant opérationnel! 🎉

**Prochaines étapes recommandées:**
1. Configurer les items dans l'inventaire
2. Ajouter des grades EMS personnalisés
3. Intégrer les blessures avec votre système de combat
4. Tester avec testbench: `/testbench`
5. Personnaliser les coûts et paramètres

**Bon RP médical! 🚑**
