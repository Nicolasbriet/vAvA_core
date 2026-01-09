-- ========================================
-- VAVA STATUS - SHARED API
-- API publique pour les autres modules
-- ========================================

StatusAPI = {}

-- ========================================
-- DOCUMENTATION API
-- ========================================

--[[
    Cette API permet aux autres modules d'interagir avec le système de statuts.
    
    EXPORTS SERVEUR:
    ----------------
    exports['vAvA_status']:GetHunger(playerId) -- Retourne la faim (0-100)
    exports['vAvA_status']:GetThirst(playerId) -- Retourne la soif (0-100)
    exports['vAvA_status']:SetHunger(playerId, value) -- Définit la faim (0-100)
    exports['vAvA_status']:SetThirst(playerId, value) -- Définit la soif (0-100)
    exports['vAvA_status']:AddHunger(playerId, amount) -- Ajoute de la faim (+/-)
    exports['vAvA_status']:AddThirst(playerId, amount) -- Ajoute de la soif (+/-)
    exports['vAvA_status']:ConsumeItem(playerId, itemName) -- Consomme un item
    
    EXPORTS CLIENT:
    ---------------
    exports['vAvA_status']:GetCurrentHunger() -- Retourne la faim actuelle du joueur
    exports['vAvA_status']:GetCurrentThirst() -- Retourne la soif actuelle du joueur
    
    EVENTS:
    -------
    TriggerServerEvent('vAvA_status:consumeItem', itemName) -- Depuis client, consommer un item
    TriggerClientEvent('vAvA_status:updateStatus', playerId, hunger, thirst) -- Depuis serveur, MAJ status
    TriggerClientEvent('vAvA_status:playAnimation', playerId, animType) -- Depuis serveur, jouer animation
    
    EXEMPLE D'UTILISATION (depuis un autre module):
    ------------------------------------------------
    
    -- Serveur : Donner de la nourriture
    local currentHunger = exports['vAvA_status']:GetHunger(playerId)
    exports['vAvA_status']:AddHunger(playerId, 30) -- +30 faim
    
    -- Serveur : Consommer un item
    exports['vAvA_status']:ConsumeItem(playerId, 'burger')
    
    -- Client : Vérifier la faim
    local hunger = exports['vAvA_status']:GetCurrentHunger()
    if hunger < 20 then
        print("Tu as très faim !")
    end
]]

-- ========================================
-- ITEMS CONFIGURATION
-- ========================================

StatusAPI.ConsumableItems = StatusConfig.ConsumableItems

-- Vérifier si un item est consommable
function StatusAPI.IsConsumable(itemName)
    return StatusConfig.ConsumableItems[itemName] ~= nil
end

-- Obtenir les effets d'un item
function StatusAPI.GetItemEffects(itemName)
    return StatusConfig.ConsumableItems[itemName]
end

-- ========================================
-- LEVELS CONFIGURATION
-- ========================================

StatusAPI.Levels = StatusConfig.Levels

-- Obtenir le niveau correspondant à une valeur
function StatusAPI.GetLevel(value)
    if value >= StatusConfig.Levels.normal.min then
        return "normal", StatusConfig.Levels.normal
    elseif value >= StatusConfig.Levels.light.min then
        return "light", StatusConfig.Levels.light
    elseif value >= StatusConfig.Levels.warning.min then
        return "warning", StatusConfig.Levels.warning
    elseif value > StatusConfig.Levels.danger.min then
        return "danger", StatusConfig.Levels.danger
    else
        return "collapse", StatusConfig.Levels.collapse
    end
end

-- ========================================
-- TESTBENCH INTEGRATION
-- ========================================

-- Activer le mode test (appelé par vava_testbench)
function StatusAPI.EnableTestMode()
    StatusConfig.TestMode = true
    print("^3[vAvA Status]^7 Mode test activé")
end

-- Désactiver le mode test
function StatusAPI.DisableTestMode()
    StatusConfig.TestMode = false
    print("^2[vAvA Status]^7 Mode test désactivé")
end

-- Obtenir l'état actuel du mode test
function StatusAPI.IsTestMode()
    return StatusConfig.TestMode
end

return StatusAPI
