# 🎨 vAvA_core UI Manager - Guide d'utilisation

Le UI Manager est un système centralisé pour gérer toutes les interfaces utilisateur du framework vAvA_core. Il applique la charte graphique vAvA (rouge néon, effets glow) partout.

---

## 📋 Fonctionnalités

- ✅ Notifications (4 types)
- ✅ Progress Bar avec animations
- ✅ Prompts / Confirmations
- ✅ Input texte
- ✅ HUD (santé, armure, faim, soif, argent)
- ✅ Texte 3D
- ✅ Markers
- ✅ Help Text
- ✅ Menus natifs GTA
- ✅ Interfaces NUI

---

## 🚀 Utilisation

### 1. Notifications

```lua
-- Depuis le serveur
TriggerClientEvent('vCore:notify', playerId, 'Message', 'success', 5000)

-- Depuis le client
vCore.UI.Notify('Message', 'info', 5000)

-- Raccourcis
vCore.UI.NotifySuccess('Succès!')
vCore.UI.NotifyError('Erreur!')
vCore.UI.NotifyWarning('Attention!')
vCore.UI.NotifyInfo('Information')
```

**Types:** `info`, `success`, `warning`, `error`  
**Durée:** En millisecondes (défaut: 5000)

---

### 2. Progress Bar

```lua
vCore.UI.ShowProgressBar({
    label = 'Action en cours...',
    duration = 5000,           -- 5 secondes
    useWhileDead = false,      -- Annuler si mort
    canCancel = true,          -- Touche X pour annuler
    animation = {
        dict = 'mini@repair',
        anim = 'fixing_a_player',
        flag = 49
    },
    prop = {
        model = 'prop_tool_hammer',
        bone = 60309,
        offset = {x = 0.0, y = 0.0, z = 0.0},
        rotation = {x = 0.0, y = 0.0, z = 0.0}
    }
}, function()
    -- Terminé
    print('Action terminée!')
end, function()
    -- Annulé
    print('Action annulée!')
end)
```

---

### 3. Prompt / Confirmation

```lua
vCore.UI.ShowPrompt({
    title = 'Confirmation',
    message = 'Êtes-vous sûr de vouloir continuer?',
    confirmText = 'Oui',
    cancelText = 'Non'
}, function()
    -- Confirmé
    print('Confirmé!')
end, function()
    -- Annulé
    print('Annulé!')
end)
```

---

### 4. Input Texte

```lua
vCore.UI.ShowInput({
    title = 'Entrez votre nom',
    placeholder = 'John Doe',
    maxLength = 50
}, function(value)
    -- Valeur soumise
    print('Nom saisi:', value)
end)
```

---

### 5. HUD

```lua
-- Afficher HUD
vCore.UI.ShowHUD()

-- Cacher HUD
vCore.UI.HideHUD()

-- Toggle HUD
vCore.UI.ToggleHUD()
-- Ou commande: /hud

-- Mettre à jour HUD
vCore.UI.UpdateHUD({
    health = 100,
    armor = 50,
    hunger = 80,
    thirst = 70,
    money = 5000
})
```

---

### 6. Texte 3D

```lua
-- Afficher
vCore.UI.Show3DText('marker1', vector3(0.0, 0.0, 0.0), 'Appuyez sur ~r~E~s~', {
    scale = 0.4,
    color = {r = 255, g = 255, b = 255, a = 255},
    font = 4
})

-- Cacher
vCore.UI.Hide3DText('marker1')
```

---

### 7. Markers

```lua
-- Afficher
vCore.UI.ShowMarker('garage1', {
    type = 1,                              -- Type de marker
    coords = vector3(0.0, 0.0, 0.0),
    scale = {x = 2.0, y = 2.0, z = 1.0},
    color = {r = 255, g = 30, b = 30, a = 100},  -- Rouge vAvA
    rotation = {x = 0.0, y = 0.0, z = 0.0},
    bobUpAndDown = false,
    faceCamera = false
})

-- Cacher
vCore.UI.HideMarker('garage1')
```

---

### 8. Help Text

```lua
-- Afficher
vCore.UI.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~ pour interagir')

-- Cacher
vCore.UI.HideHelpText()
```

---

### 9. Menus Natifs

```lua
vCore.UI.ShowMenu({
    title = 'Garage',
    subtitle = 'Véhicules disponibles',
    options = {
        {label = 'Véhicule 1', value = 'vehicle1', description = 'Une belle voiture'},
        {label = 'Véhicule 2', value = 'vehicle2', icon = '🚗'},
        {label = 'Option désactivée', value = 'disabled', disabled = true}
    }
}, function(value, index)
    print('Sélectionné:', value, index)
end)

-- Fermer
vCore.UI.CloseMenu()
```

---

### 10. NUI Personnalisé

```lua
-- Afficher
vCore.UI.ShowNUI('myInterface', {
    title = 'Mon Interface',
    data = {...}
})

-- Cacher
vCore.UI.HideNUI('myInterface')

-- Enregistrer callback
vCore.UI.RegisterNUICallback('myAction', function(data, cb)
    print('Action reçue:', json.encode(data))
    cb('ok')
end)
```

---

## 🎨 Charte Graphique vAvA

Le UI Manager applique automatiquement la charte vAvA:

```lua
Config.Branding.Colors = {
    primary = '#FF1E1E',         -- Rouge néon
    primaryDark = '#8B0000',     -- Rouge foncé
    background = '#000000',       -- Noir profond
    text = '#FFFFFF'              -- Blanc
}
```

**Effets:**
- Glow: `0 0 20px #FF1E1E`
- Animations scanline (cyberpunk)
- Transitions fluides (0.3s cubic-bezier)

**Polices:**
- Titres: **Orbitron**
- Texte: **Montserrat**

---

## 🔧 Exports

Toutes les fonctions sont exportées:

```lua
-- Depuis un autre resource
exports['vAvA_core']:Notify('Message', 'success', 5000)
exports['vAvA_core']:ShowProgressBar(data, onComplete)
exports['vAvA_core']:ShowPrompt(data, onConfirm, onCancel)
-- etc.
```

---

## 📱 Exemples Complets

### Exemple 1: Action avec progress

```lua
-- Client
RegisterCommand('reparer', function()
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    
    if vehicle == 0 then
        vCore.UI.NotifyError('Vous devez être dans un véhicule!')
        return
    end
    
    vCore.UI.ShowProgressBar({
        label = 'Réparation en cours...',
        duration = 10000,
        canCancel = true,
        animation = {
            dict = 'mini@repair',
            anim = 'fixing_a_player',
            flag = 49
        }
    }, function()
        -- Succès
        SetVehicleFixed(vehicle)
        vCore.UI.NotifySuccess('Véhicule réparé!')
    end, function()
        -- Annulé
        vCore.UI.NotifyWarning('Réparation annulée')
    end)
end)
```

### Exemple 2: Confirmation avant action

```lua
RegisterCommand('supprimervehicule', function()
    vCore.UI.ShowPrompt({
        title = 'Attention',
        message = 'Voulez-vous vraiment supprimer ce véhicule?',
        confirmText = 'Oui, supprimer',
        cancelText = 'Annuler'
    }, function()
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            DeleteVehicle(vehicle)
            vCore.UI.NotifySuccess('Véhicule supprimé')
        end
    end)
end)
```

### Exemple 3: Input avec callback serveur

```lua
-- Client
RegisterCommand('transfertargent', function()
    vCore.UI.ShowInput({
        title = 'Transférer de l\'argent',
        placeholder = 'Montant',
        maxLength = 10
    }, function(amount)
        amount = tonumber(amount)
        if amount and amount > 0 then
            TriggerServerEvent('vCore:transferMoney', amount)
        else
            vCore.UI.NotifyError('Montant invalide')
        end
    end)
end)

-- Server
RegisterNetEvent('vCore:transferMoney', function(amount)
    local source = source
    -- ... logique transfert ...
    vCore.Notify(source, 'Transfert effectué: $' .. amount, 'success')
end)
```

---

## ⚡ Performance

- ✅ Rendering conditionnel (distance checks pour 3D text et markers)
- ✅ Animations CSS (GPU accelerated)
- ✅ Cleanup automatique
- ✅ Event throttling

---

## 🐛 Dépannage

**Notifications n'apparaissent pas:**
- Vérifier que `html/js/ui_manager.js` est chargé
- Vérifier console F8 pour erreurs JS

**Progress bar ne fonctionne pas:**
- Vérifier que `duration` est en millisecondes
- Vérifier que callbacks sont définis

**NUI ne répond pas:**
- Vérifier que callbacks sont enregistrés
- Vérifier focus NUI (SetNuiFocus)

---

## 📚 Documentation Complète

Voir:
- `client/ui_manager.lua` (code source commenté)
- `PLAN_REFONTE_COMPLETE_V2.md` (architecture)
- `AUDIT_CORE_FILES.md` (analyse technique)

---

**Créé par:** vAvA Team  
**Version:** 2.0  
**Dernière mise à jour:** 10 janvier 2025
