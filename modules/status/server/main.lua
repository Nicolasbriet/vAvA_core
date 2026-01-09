-- ========================================
-- VAVA STATUS - SERVER MAIN
-- Gestion serveur des statuts faim/soif
-- ========================================

local PlayerStatus = {}
local LastUpdate = {}

-- ========================================
-- INITIALISATION
-- ========================================

CreateThread(function()
    print("^2[vAvA Status]^7 Initialisation du système de statuts...")
    
    if not StatusConfig.Enabled then
        print("^3[vAvA Status]^7 Système désactivé dans la configuration")
        return
    end

    -- Créer les tables si nécessaire
    CreateDatabaseTables()
    
    -- Démarrer le système de décrémentation automatique
    StartAutoDecay()
    
    print("^2[vAvA Status]^7 Système de statuts initialisé avec succès !")
end)

-- ========================================
-- DATABASE
-- ========================================

function CreateDatabaseTables()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS player_status (
            identifier VARCHAR(50) PRIMARY KEY,
            hunger INT DEFAULT 100,
            thirst INT DEFAULT 100,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
    ]], {}, function(result)
        if StatusConfig.Logging.enabled then
            print("^2[vAvA Status]^7 Table player_status créée/vérifiée")
        end
    end)
end

-- ========================================
-- PLAYER CONNECTION/DISCONNECTION
-- ========================================

RegisterNetEvent('vAvA_core:playerLoaded')
AddEventHandler('vAvA_core:playerLoaded', function(playerId, playerData)
    local src = source
    LoadPlayerStatus(src, playerData.identifier)
end)

RegisterNetEvent('vAvA_core:playerUnloaded')
AddEventHandler('vAvA_core:playerUnloaded', function(playerId, identifier)
    SavePlayerStatus(playerId, identifier)
    PlayerStatus[playerId] = nil
    LastUpdate[playerId] = nil
end)

-- Sauvegarde au drop du joueur
AddEventHandler('playerDropped', function(reason)
    local src = source
    local identifier = GetPlayerIdentifier(src)
    
    if identifier and PlayerStatus[src] then
        SavePlayerStatus(src, identifier)
        PlayerStatus[src] = nil
        LastUpdate[src] = nil
    end
end)

-- ========================================
-- LOAD/SAVE STATUS
-- ========================================

function LoadPlayerStatus(playerId, identifier)
    MySQL.Async.fetchAll('SELECT hunger, thirst FROM player_status WHERE identifier = @identifier', {
        ['@identifier'] = identifier
    }, function(result)
        if result[1] then
            -- Charger les valeurs existantes
            PlayerStatus[playerId] = {
                hunger = math.max(0, math.min(100, result[1].hunger)),
                thirst = math.max(0, math.min(100, result[1].thirst))
            }
        else
            -- Nouveau joueur : valeurs par défaut
            PlayerStatus[playerId] = {
                hunger = 100,
                thirst = 100
            }
            
            -- Insérer dans la base
            MySQL.Async.execute('INSERT INTO player_status (identifier, hunger, thirst) VALUES (@identifier, 100, 100)', {
                ['@identifier'] = identifier
            })
        end
        
        -- Envoyer au client
        TriggerClientEvent('vAvA_status:updateStatus', playerId, PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst)
        
        if StatusConfig.Logging.enabled then
            print(string.format("^2[vAvA Status]^7 Statuts chargés pour %s - Faim: %d, Soif: %d", 
                GetPlayerName(playerId), PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst))
        end
    end)
end

function SavePlayerStatus(playerId, identifier)
    if not PlayerStatus[playerId] then return end
    
    local hunger = PlayerStatus[playerId].hunger
    local thirst = PlayerStatus[playerId].thirst
    
    MySQL.Async.execute('UPDATE player_status SET hunger = @hunger, thirst = @thirst WHERE identifier = @identifier', {
        ['@identifier'] = identifier,
        ['@hunger'] = hunger,
        ['@thirst'] = thirst
    }, function(affectedRows)
        if StatusConfig.Logging.enabled then
            print(string.format("^2[vAvA Status]^7 Statuts sauvegardés pour %s", GetPlayerName(playerId)))
        end
    end)
end

-- Sauvegarde automatique toutes les 5 minutes
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes
        
        for playerId, status in pairs(PlayerStatus) do
            local identifier = GetPlayerIdentifier(playerId)
            if identifier then
                SavePlayerStatus(playerId, identifier)
            end
        end
    end
end)

-- ========================================
-- AUTO DECAY SYSTEM
-- ========================================

function StartAutoDecay()
    CreateThread(function()
        while true do
            local interval = StatusConfig.UpdateInterval * 60 * 1000 -- Convertir minutes en ms
            
            -- Mode test : décrémentation rapide
            if StatusConfig.TestMode then
                interval = (interval / StatusConfig.TestConfig.decayMultiplier)
            end
            
            Wait(interval)
            
            -- Appliquer la décrémentation à tous les joueurs
            for playerId, status in pairs(PlayerStatus) do
                if GetPlayerPing(playerId) > 0 then -- Vérifier que le joueur est connecté
                    ApplyDecay(playerId)
                end
            end
        end
    end)
end

function ApplyDecay(playerId)
    if not PlayerStatus[playerId] then return end
    
    -- Générer valeurs aléatoires dans les limites configurées
    local hungerDecay = math.random(StatusConfig.Decrementation.hunger.min, StatusConfig.Decrementation.hunger.max)
    local thirstDecay = math.random(StatusConfig.Decrementation.thirst.min, StatusConfig.Decrementation.thirst.max)
    
    -- Mode test : décrémentation plus rapide
    if StatusConfig.TestMode and StatusConfig.TestConfig.fastDecay then
        hungerDecay = hungerDecay * StatusConfig.TestConfig.decayMultiplier
        thirstDecay = thirstDecay * StatusConfig.TestConfig.decayMultiplier
    end
    
    -- Appliquer la décrémentation
    local newHunger = math.max(0, PlayerStatus[playerId].hunger - hungerDecay)
    local newThirst = math.max(0, PlayerStatus[playerId].thirst - thirstDecay)
    
    -- Mettre à jour
    SetHunger(playerId, newHunger, true)
    SetThirst(playerId, newThirst, true)
    
    -- Logger si activé
    if StatusConfig.Logging.logLevelChanges then
        local oldHungerLevel = GetStatusLevel(PlayerStatus[playerId].hunger + hungerDecay)
        local newHungerLevel = GetStatusLevel(newHunger)
        local oldThirstLevel = GetStatusLevel(PlayerStatus[playerId].thirst + thirstDecay)
        local newThirstLevel = GetStatusLevel(newThirst)
        
        if oldHungerLevel ~= newHungerLevel or oldThirstLevel ~= newThirstLevel then
            print(string.format("^3[vAvA Status]^7 %s - Nouveau niveau: Faim=%s, Soif=%s", 
                GetPlayerName(playerId), newHungerLevel, newThirstLevel))
        end
    end
end

function GetStatusLevel(value)
    if value >= StatusConfig.Levels.normal.min then
        return "normal"
    elseif value >= StatusConfig.Levels.light.min then
        return "light"
    elseif value >= StatusConfig.Levels.warning.min then
        return "warning"
    elseif value > StatusConfig.Levels.danger.min then
        return "danger"
    else
        return "collapse"
    end
end

-- ========================================
-- API FUNCTIONS
-- ========================================

function GetHunger(playerId)
    if not PlayerStatus[playerId] then return 0 end
    return PlayerStatus[playerId].hunger
end

function GetThirst(playerId)
    if not PlayerStatus[playerId] then return 0 end
    return PlayerStatus[playerId].thirst
end

function SetHunger(playerId, value, internal)
    if not PlayerStatus[playerId] then return false end
    
    -- Validation
    value = math.max(0, math.min(100, tonumber(value) or 0))
    
    -- Anti-cheat : vérifier les changements suspects (si pas un appel interne)
    if not internal and StatusConfig.Security.antiCheat then
        local oldValue = PlayerStatus[playerId].hunger
        local change = math.abs(value - oldValue)
        
        if change > StatusConfig.Security.maxValueChange then
            if StatusConfig.Security.logSuspiciousActivity then
                print(string.format("^1[vAvA Status ANTICHEAT]^7 Changement suspect détecté pour %s : Faim %d → %d (delta: %d)", 
                    GetPlayerName(playerId), oldValue, value, change))
            end
            
            if StatusConfig.Security.banOnCheat then
                DropPlayer(playerId, "[vAvA Status] Tentative de triche détectée")
            end
            
            return false
        end
        
        -- Vérifier l'intervalle minimum entre updates
        local now = GetGameTimer()
        if LastUpdate[playerId] and (now - LastUpdate[playerId]) < StatusConfig.Security.minUpdateInterval then
            return false
        end
        LastUpdate[playerId] = now
    end
    
    -- Mettre à jour
    PlayerStatus[playerId].hunger = value
    
    -- Envoyer au client
    TriggerClientEvent('vAvA_status:updateStatus', playerId, value, PlayerStatus[playerId].thirst)
    
    -- Logger si activé
    if StatusConfig.Logging.logAPI and not internal then
        print(string.format("^2[vAvA Status API]^7 SetHunger(%s, %d)", GetPlayerName(playerId), value))
    end
    
    return true
end

function SetThirst(playerId, value, internal)
    if not PlayerStatus[playerId] then return false end
    
    -- Validation
    value = math.max(0, math.min(100, tonumber(value) or 0))
    
    -- Anti-cheat (même logique que SetHunger)
    if not internal and StatusConfig.Security.antiCheat then
        local oldValue = PlayerStatus[playerId].thirst
        local change = math.abs(value - oldValue)
        
        if change > StatusConfig.Security.maxValueChange then
            if StatusConfig.Security.logSuspiciousActivity then
                print(string.format("^1[vAvA Status ANTICHEAT]^7 Changement suspect détecté pour %s : Soif %d → %d (delta: %d)", 
                    GetPlayerName(playerId), oldValue, value, change))
            end
            
            if StatusConfig.Security.banOnCheat then
                DropPlayer(playerId, "[vAvA Status] Tentative de triche détectée")
            end
            
            return false
        end
        
        local now = GetGameTimer()
        if LastUpdate[playerId] and (now - LastUpdate[playerId]) < StatusConfig.Security.minUpdateInterval then
            return false
        end
        LastUpdate[playerId] = now
    end
    
    -- Mettre à jour
    PlayerStatus[playerId].thirst = value
    
    -- Envoyer au client
    TriggerClientEvent('vAvA_status:updateStatus', playerId, PlayerStatus[playerId].hunger, value)
    
    -- Logger si activé
    if StatusConfig.Logging.logAPI and not internal then
        print(string.format("^2[vAvA Status API]^7 SetThirst(%s, %d)", GetPlayerName(playerId), value))
    end
    
    return true
end

function AddHunger(playerId, amount)
    local current = GetHunger(playerId)
    return SetHunger(playerId, current + amount)
end

function AddThirst(playerId, amount)
    local current = GetThirst(playerId)
    return SetThirst(playerId, current + amount)
end

-- ========================================
-- ITEM CONSUMPTION
-- ========================================

function ConsumeItem(playerId, itemName)
    if not StatusConfig.ConsumableItems[itemName] then
        return false, "Item not consumable"
    end
    
    local itemData = StatusConfig.ConsumableItems[itemName]
    
    -- Appliquer les effets
    if itemData.hunger and itemData.hunger ~= 0 then
        AddHunger(playerId, itemData.hunger)
    end
    
    if itemData.thirst and itemData.thirst ~= 0 then
        AddThirst(playerId, itemData.thirst)
    end
    
    -- Envoyer l'animation au client
    if itemData.animation then
        TriggerClientEvent('vAvA_status:playAnimation', playerId, itemData.animation)
    end
    
    -- Logger
    if StatusConfig.Logging.logConsumption then
        print(string.format("^2[vAvA Status]^7 %s a consommé %s (+%d faim, +%d soif)", 
            GetPlayerName(playerId), itemName, itemData.hunger or 0, itemData.thirst or 0))
    end
    
    return true
end

-- Event depuis l'inventaire
RegisterNetEvent('vAvA_status:consumeItem')
AddEventHandler('vAvA_status:consumeItem', function(itemName)
    local src = source
    ConsumeItem(src, itemName)
end)

-- ========================================
-- EXPORTS
-- ========================================

exports('GetHunger', GetHunger)
exports('GetThirst', GetThirst)
exports('SetHunger', SetHunger)
exports('SetThirst', SetThirst)
exports('AddHunger', AddHunger)
exports('AddThirst', AddThirst)
exports('ConsumeItem', ConsumeItem)

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

function GetPlayerIdentifier(playerId)
    local identifiers = GetPlayerIdentifiers(playerId)
    for _, id in pairs(identifiers) do
        if string.find(id, "license:") then
            return id
        end
    end
    return nil
end
