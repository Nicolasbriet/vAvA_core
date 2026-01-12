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
    
    -- Démarrer le système de mise à jour HUD temps réel
    StartHUDUpdater()
    
    print("^2[vAvA Status]^7 Système de statuts initialisé avec succès !")
end)

-- ========================================
-- HUD REAL-TIME UPDATER
-- ========================================

-- Cache des dernières valeurs envoyées pour éviter le spam
local LastSentValues = {}

function StartHUDUpdater()
    CreateThread(function()
        -- Intervalle de 5 secondes pour éviter tout blocage
        local interval = 5000
        
        print("^2[vAvA Status]^7 HUD Updater démarré (intervalle: 5s)")
        
        while true do
            Wait(interval)
            
            -- Utiliser GetPlayers() pour obtenir seulement les joueurs valides
            local players = GetPlayers()
            
            for _, playerId in ipairs(players) do
                local pid = tonumber(playerId)
                if pid and PlayerStatus[pid] then
                    local status = PlayerStatus[pid]
                    local lastValues = LastSentValues[pid]
                    
                    -- Envoyer uniquement si les valeurs ont changé
                    if not lastValues or 
                       lastValues.hunger ~= status.hunger or 
                       lastValues.thirst ~= status.thirst then
                        
                        TriggerClientEvent('vAvA_status:updateStatus', pid, status.hunger, status.thirst)
                        TriggerClientEvent('vAvA_hud:updateStatus', pid, {
                            hunger = status.hunger,
                            thirst = status.thirst
                        })
                        
                        LastSentValues[pid] = {
                            hunger = status.hunger,
                            thirst = status.thirst
                        }
                    end
                end
            end
        end
    end)
end

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

-- Écouter l'event local du core (pas RegisterNetEvent car c'est un TriggerEvent local)
AddEventHandler('vCore:playerLoaded', function(playerId, player)
    local src = playerId
    print(string.format("^2[vAvA Status]^7 Player loaded event reçu pour %s (src: %s)", GetPlayerName(src) or 'Unknown', src))
    
    -- Diagnostic pour débugger
    if StatusConfig.Logging.logAPI then
        DiagnosePlayerObject(src)
    end
    
    -- Charger immédiatement sans délai excessif
    CreateThread(function()
        Wait(500) -- Court délai pour laisser le temps au client de s'initialiser
        
        -- Utiliser player.identifier (propriété directe) car les méthodes via metatable peuvent ne pas être héritées
        local identifier = (player and player.identifier) or GetPlayerIdentifier(src)
        LoadPlayerStatus(src, identifier)
        
        -- IMPORTANT: Forcer l'envoi au HUD immédiatement après le chargement
        Wait(1000)
        if PlayerStatus[src] then
            -- Triple envoi avec délais pour garantir la réception
            TriggerClientEvent('vAvA_status:updateStatus', src, 
                PlayerStatus[src].hunger, PlayerStatus[src].thirst)
            TriggerClientEvent('vAvA_hud:updateStatus', src, {
                hunger = PlayerStatus[src].hunger,
                thirst = PlayerStatus[src].thirst
            })
            
            print(string.format("^2[vAvA Status]^7 Sync initiale envoyée pour %s - H:%.1f T:%.1f", 
                GetPlayerName(src), PlayerStatus[src].hunger, PlayerStatus[src].thirst))
        end
    end)
end)

-- Sauvegarde au drop du joueur
AddEventHandler('playerDropped', function(reason)
    local src = source
    
    if not PlayerStatus[src] then return end
    
    -- IMPORTANT: Sauvegarder en DB AVANT de nettoyer
    local identifier = GetPlayerIdentifier(src)
    if identifier then
        local hunger = math.floor(PlayerStatus[src].hunger)
        local thirst = math.floor(PlayerStatus[src].thirst)
        
        -- Sauvegarde synchrone pour s'assurer que c'est fait avant le cleanup
        MySQL.Async.execute([[
            INSERT INTO player_status (identifier, hunger, thirst) 
            VALUES (@identifier, @hunger, @thirst) 
            ON DUPLICATE KEY UPDATE hunger = @hunger, thirst = @thirst, last_update = CURRENT_TIMESTAMP
        ]], {
            ['@identifier'] = identifier,
            ['@hunger'] = hunger,
            ['@thirst'] = thirst
        })
        
        print(string.format("^2[vAvA Status]^7 Status sauvegardés pour joueur déconnecté %s - Faim: %d, Soif: %d", 
            GetPlayerName(src) or identifier, hunger, thirst))
    end
    
    -- Nettoyer les caches
    PlayerStatus[src] = nil
    LastUpdate[src] = nil
    LastSentValues[src] = nil
end)

-- ========================================
-- COMMANDES DEBUG
-- ========================================

RegisterCommand('debug_player_object', function(source)
    if source == 0 then return end -- Console uniquement
    
    -- Test direct via vCore
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(source)
    
    print("^6=== DEBUG PLAYER OBJECT ===^7")
    print("Player exists:", player ~= nil)
    
    if player then
        print("Type:", type(player))
        print("Has status property:", player.status ~= nil)
        print("Has GetStatus method:", type(player.GetStatus) == 'function')
        print("Has SetStatus method:", type(player.SetStatus) == 'function')
        
        if player.status then
            print("Status content:", json.encode(player.status))
        end
        
        -- Test des méthodes si elles existent
        if type(player.GetStatus) == 'function' then
            local testHunger = player:GetStatus('hunger')
            local testThirst = player:GetStatus('thirst')
            print("GetStatus('hunger'):", testHunger)
            print("GetStatus('thirst'):", testThirst)
        end
    end
    
    print("^6=== FIN DEBUG ===^7")
end, true)

-- Commande pour forcer le chargement des status (debug)
RegisterCommand('force_load_status', function(source)
    if source == 0 then return end -- Console uniquement
    
    print("^6=== FORCE LOAD STATUS ===^7")
    local identifier = GetPlayerIdentifier(source)
    if identifier then
        print(string.format("^2[vAvA Status]^7 Force load pour %s avec identifier %s", GetPlayerName(source), identifier))
        
        -- Test direct de l'objet player
        local vCore = exports['vAvA_core']:GetCoreObject()
        local player = vCore.GetPlayer(source)
        
        if player and player.status then
            print("^2[vAvA Status]^7 Objet player trouvé avec status:", json.encode(player.status))
            
            -- Forcer la mise à jour du PlayerStatus et envoyer au HUD
            PlayerStatus[source] = {
                hunger = player.status.hunger or 100,
                thirst = player.status.thirst or 100
            }
            
            -- Envoyer immédiatement au client
            TriggerClientEvent('vAvA_status:updateStatus', source, PlayerStatus[source].hunger, PlayerStatus[source].thirst)
            TriggerClientEvent('vAvA_hud:updateStatus', source, {
                hunger = PlayerStatus[source].hunger,
                thirst = PlayerStatus[source].thirst
            })
            
            print(string.format("^2[vAvA Status]^7 Status envoyés au HUD - H:%.1f T:%.1f", PlayerStatus[source].hunger, PlayerStatus[source].thirst))
        else
            print("^1[vAvA Status]^7 Player object ou player.status manquant")
            LoadPlayerStatus(source, identifier)
        end
    else
        print("^1[vAvA Status]^7 Pas d'identifier trouvé")
    end
    print("^6=== FIN FORCE LOAD ===^7")
end, true)

-- Commande pour diagnostiquer l'inventaire (debug)
RegisterCommand('debug_inventory', function(source)
    if source == 0 then return end
    
    print("^6=== DEBUG INVENTORY ===^7")
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(source)
    
    if player then
        print("^2[vAvA Status]^7 Player trouvé - Source:", source)
        print("^2[vAvA Status]^7 Player inventory existe:", player.inventory ~= nil)
        
        if player.inventory then
            print("^2[vAvA Status]^7 Contenu inventaire:", json.encode(player.inventory))
            
            -- Compter les items
            local count = 0
            for _, item in pairs(player.inventory) do
                if item.amount and item.amount > 0 then
                    count = count + 1
                end
            end
            print("^2[vAvA Status]^7 Nombre d'items avec quantité > 0:", count)
        end
        
        -- Vérifier les méthodes d'inventaire
        print("^2[vAvA Status]^7 HasItem method:", type(player.HasItem) == 'function')
        print("^2[vAvA Status]^7 AddItem method:", type(player.AddItem) == 'function')
        print("^2[vAvA Status]^7 RemoveItem method:", type(player.RemoveItem) == 'function')
        
        -- Test HasItem sur bread et water
        if type(player.HasItem) == 'function' then
            local hasBread = player:HasItem('bread')
            local hasWater = player:HasItem('water')
            print("^2[vAvA Status]^7 HasItem('bread'):", hasBread)
            print("^2[vAvA Status]^7 HasItem('water'):", hasWater)
        end
    else
        print("^1[vAvA Status]^7 Player object non trouvé")
    end
    
    print("^6=== FIN DEBUG INVENTORY ===^7")
end, true)

-- ========================================
-- LOAD/SAVE STATUS
-- ========================================

function LoadPlayerStatus(playerId, identifier)
    -- Exécuter dans un thread séparé pour ne jamais bloquer
    CreateThread(function()
        -- Définir des valeurs par défaut immédiatement
        if not PlayerStatus[playerId] then
            PlayerStatus[playerId] = { hunger = 100, thirst = 100 }
        end
        
        -- Envoyer les valeurs par défaut immédiatement
        TriggerClientEvent('vAvA_status:updateStatus', playerId, PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst)
        
        -- Attendre un peu pour s'assurer que le joueur est bien chargé
        Wait(1000)
        
        -- Obtenir l'identifier
        if not identifier then
            local identifiers = GetPlayerIdentifiers(playerId)
            if identifiers then
                for _, id in pairs(identifiers) do
                    if string.find(id, "license:") then
                        identifier = id
                        break
                    end
                end
            end
        end
        
        if not identifier then
            print(string.format("^1[vAvA Status]^7 Pas d'identifier pour %s - valeurs par défaut", GetPlayerName(playerId) or 'Unknown'))
            return
        end
        
        -- Charger depuis la DB
        MySQL.Async.fetchAll('SELECT hunger, thirst FROM player_status WHERE identifier = @identifier', {
            ['@identifier'] = identifier
        }, function(result)
            if result and result[1] then
                PlayerStatus[playerId] = {
                    hunger = math.max(0, math.min(100, result[1].hunger or 100)),
                    thirst = math.max(0, math.min(100, result[1].thirst or 100))
                }
                print(string.format("^2[vAvA Status]^7 Status DB pour %s - Faim: %.1f, Soif: %.1f", 
                    GetPlayerName(playerId) or 'Unknown', PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst))
            else
                -- Nouveau joueur
                PlayerStatus[playerId] = { hunger = 100, thirst = 100 }
                MySQL.Async.execute('INSERT INTO player_status (identifier, hunger, thirst) VALUES (@identifier, 100, 100)', {
                    ['@identifier'] = identifier
                })
                print(string.format("^2[vAvA Status]^7 Nouveau joueur %s créé en DB", GetPlayerName(playerId) or 'Unknown'))
            end
            
            -- Envoyer les vraies valeurs
            TriggerClientEvent('vAvA_status:updateStatus', playerId, PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst)
            TriggerClientEvent('vAvA_hud:updateStatus', playerId, {
                hunger = PlayerStatus[playerId].hunger,
                thirst = PlayerStatus[playerId].thirst
            })
        end)
    end)
end

function SavePlayerStatus(playerId, identifier)
    if not PlayerStatus[playerId] then return end
    
    -- Toujours obtenir l'identifier
    if not identifier then
        identifier = GetPlayerIdentifier(playerId)
    end
    
    if not identifier then
        print(string.format("^1[vAvA Status]^7 Impossible de sauvegarder - pas d'identifier pour player %s", playerId))
        return
    end
    
    local hunger = math.floor(PlayerStatus[playerId].hunger)
    local thirst = math.floor(PlayerStatus[playerId].thirst)
    
    -- Sauvegarder en DB (INSERT ou UPDATE)
    MySQL.Async.execute([[
        INSERT INTO player_status (identifier, hunger, thirst) 
        VALUES (@identifier, @hunger, @thirst) 
        ON DUPLICATE KEY UPDATE hunger = @hunger, thirst = @thirst, last_update = CURRENT_TIMESTAMP
    ]], {
        ['@identifier'] = identifier,
        ['@hunger'] = hunger,
        ['@thirst'] = thirst
    }, function(rowsChanged)
        if StatusConfig.Logging and StatusConfig.Logging.enabled then
            print(string.format("^2[vAvA Status]^7 Status sauvegardés en DB pour %s - Faim: %d, Soif: %d", 
                GetPlayerName(playerId) or identifier, hunger, thirst))
        end
    end)
    
    -- Aussi synchroniser avec l'objet player vCore
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(playerId)
    if player then
        if not player.status then
            player.status = {}
        end
        player.status.hunger = hunger
        player.status.thirst = thirst
    end
end

-- Sauvegarde automatique toutes les 5 minutes
CreateThread(function()
    while true do
        Wait(5 * 60 * 1000) -- 5 minutes
        
        -- Utiliser GetPlayers() pour obtenir seulement les joueurs valides
        local players = GetPlayers()
        
        for _, playerId in ipairs(players) do
            local pid = tonumber(playerId)
            if pid and PlayerStatus[pid] then
                local identifier = GetPlayerIdentifier(pid)
                if identifier then
                    SavePlayerStatus(pid, identifier)
                end
            end
        end
        
        -- Nettoyer les joueurs déconnectés (une fois par cycle)
        for playerId, _ in pairs(PlayerStatus) do
            local found = false
            for _, p in ipairs(players) do
                if tonumber(p) == playerId then
                    found = true
                    break
                end
            end
            if not found then
                PlayerStatus[playerId] = nil
                LastSentValues[playerId] = nil
                LastUpdate[playerId] = nil
            end
        end
    end
end)

-- ========================================
-- AUTO DECAY SYSTEM
-- ========================================

function StartAutoDecay()
    CreateThread(function()
        -- Intervalle de 5 minutes (300 secondes)
        local interval = (StatusConfig.UpdateInterval or 5) * 60 * 1000
        interval = math.max(60000, interval) -- Minimum 1 minute
        
        print(string.format("^2[vAvA Status]^7 Auto Decay démarré (intervalle: %d min)", interval / 60000))
        
        while true do
            Wait(interval)
            
            -- Utiliser GetPlayers() pour obtenir seulement les joueurs valides
            local players = GetPlayers()
            
            for _, playerId in ipairs(players) do
                local pid = tonumber(playerId)
                if pid and PlayerStatus[pid] then
                    ApplyDecay(pid)
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
    elseif value > StatusConfig.Levels.critical.max then
        -- danger: 5-20 (valeur > 5 et < 20)
        return "danger"
    elseif value > 0 then
        -- critical: 0-5 (valeur > 0 et <= 5)
        return "critical"
    else
        -- collapse: exactement 0
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
        print(string.format("^2[vAvA Status API]^7 SetHunger(%s, %.1f)", GetPlayerName(playerId), value))
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
        print(string.format("^2[vAvA Status API]^7 SetThirst(%s, %.1f)", GetPlayerName(playerId), value))
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
        print(string.format("^2[vAvA Status]^7 %s a consommé %s (+%.1f faim, +%.1f soif)", 
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

-- Event pour synchroniser les status (demandé par vCore)
RegisterNetEvent('vAvA_status:requestSync')
AddEventHandler('vAvA_status:requestSync', function()
    local src = source
    
    -- IMPORTANT: Exécuter dans un thread séparé pour ne pas bloquer
    CreateThread(function()
        -- Vérifier si les données existent en cache
        if PlayerStatus[src] and PlayerStatus[src].hunger and PlayerStatus[src].thirst then
            TriggerClientEvent('vAvA_status:updateStatus', src, PlayerStatus[src].hunger, PlayerStatus[src].thirst)
            TriggerClientEvent('vAvA_hud:updateStatus', src, {
                hunger = PlayerStatus[src].hunger,
                thirst = PlayerStatus[src].thirst
            })
        else
            -- Pas de cache, utiliser valeurs par défaut immédiatement
            -- La DB sera chargée par LoadPlayerStatus lors du playerLoaded
            PlayerStatus[src] = { hunger = 100, thirst = 100 }
            TriggerClientEvent('vAvA_status:updateStatus', src, 100, 100)
            TriggerClientEvent('vAvA_hud:updateStatus', src, { hunger = 100, thirst = 100 })
            
            -- Charger depuis DB en arrière-plan
            local identifier = GetPlayerIdentifier(src)
            if identifier then
                MySQL.Async.fetchAll('SELECT hunger, thirst FROM player_status WHERE identifier = @identifier', {
                    ['@identifier'] = identifier
                }, function(result)
                    if result and result[1] then
                        PlayerStatus[src] = {
                            hunger = math.max(0, math.min(100, result[1].hunger or 100)),
                            thirst = math.max(0, math.min(100, result[1].thirst or 100))
                        }
                        -- Renvoyer les vraies valeurs
                        TriggerClientEvent('vAvA_status:updateStatus', src, PlayerStatus[src].hunger, PlayerStatus[src].thirst)
                        TriggerClientEvent('vAvA_hud:updateStatus', src, {
                            hunger = PlayerStatus[src].hunger,
                            thirst = PlayerStatus[src].thirst
                        })
                    end
                end)
            end
        end
    end)
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

-- Export pour obtenir les items consommables
exports('GetConsumableItems', function()
    return StatusConfig.ConsumableItems
end)

-- Export pour vérifier si un item est consommable
exports('IsConsumable', function(itemName)
    return StatusConfig.ConsumableItems[itemName] ~= nil
end)

-- Commande de diagnostic (développement uniquement)
if StatusConfig.Logging.enabled then
    RegisterCommand('vAvA_status_debug', function(source, args)
        if source == 0 then -- Console uniquement
            local playerId = tonumber(args[1])
            if playerId and GetPlayerPing(playerId) > 0 then
                DiagnosePlayerObject(playerId)
            else
                print("^1[vAvA Status]^7 Usage: vAvA_status_debug <player_id>")
            end
        end
    end, true) -- Restricted = true
end

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Fonction de diagnostic pour vérifier la structure des objets player
function DiagnosePlayerObject(playerId)
    local vCore = exports['vAvA_core']:GetCoreObject()
    local player = vCore.GetPlayer(playerId)
    
    print(string.format("^3[vAvA Status DEBUG]^7 === Diagnostic Player %s ===", GetPlayerName(playerId)))
    print(string.format("^3[vAvA Status DEBUG]^7 Player object exists: %s", tostring(player ~= nil)))
    
    if player then
        print(string.format("^3[vAvA Status DEBUG]^7 PlayerData exists: %s", tostring(player.PlayerData ~= nil)))
        
        if player.PlayerData then
            print(string.format("^3[vAvA Status DEBUG]^7 PlayerData.status exists: %s", tostring(player.PlayerData.status ~= nil)))
            if player.PlayerData.status then
                print(string.format("^3[vAvA Status DEBUG]^7 PlayerData.status.hunger: %s", tostring(player.PlayerData.status.hunger)))
                print(string.format("^3[vAvA Status DEBUG]^7 PlayerData.status.thirst: %s", tostring(player.PlayerData.status.thirst)))
            end
        end
        
        print(string.format("^3[vAvA Status DEBUG]^7 GetStatus method exists: %s", tostring(player.GetStatus ~= nil)))
        print(string.format("^3[vAvA Status DEBUG]^7 SetStatus method exists: %s", tostring(player.SetStatus ~= nil)))
        
        -- Tester les méthodes si elles existent
        if player.GetStatus then
            local hunger = player:GetStatus('hunger')
            local thirst = player:GetStatus('thirst')
            print(string.format("^3[vAvA Status DEBUG]^7 GetStatus hunger: %s", tostring(hunger)))
            print(string.format("^3[vAvA Status DEBUG]^7 GetStatus thirst: %s", tostring(thirst)))
        end
    end
    
    print("^3[vAvA Status DEBUG]^7 === Fin Diagnostic ===")
end

function GetPlayerIdentifier(playerId)
    -- Protection contre les IDs invalides
    if not playerId or playerId <= 0 then
        return nil
    end
    
    local success, identifiers = pcall(GetPlayerIdentifiers, playerId)
    if not success or not identifiers then
        return nil
    end
    
    for _, id in pairs(identifiers) do
        if id and string.find(id, "license:") then
            return id
        end
    end
    return nil
end

-- ========================================
-- EMS INTEGRATION HANDLERS
-- Gère les notifications vers le module EMS
-- La vie/mort est entièrement déléguée au module EMS
-- ========================================

-- Handler pour les événements de status critiques
RegisterNetEvent('vAvA_status:emsNotify')
AddEventHandler('vAvA_status:emsNotify', function(data)
    local src = source
    
    if not data or not data.level then
        print("^1[Status -> EMS]^7 Erreur: données de notification invalides")
        return
    end
    
    print(string.format("^5[Status -> EMS]^7 Notification reçue de %s: level=%s, condition=%s", 
        GetPlayerName(src), data.level, data.condition or "none"))
    
    -- Stocker l'état pour que le module EMS puisse le consulter
    if PlayerStatus[src] then
        if data.level == "recovered" then
            -- Le joueur s'est rétabli
            PlayerStatus[src].emsLevel = nil
            PlayerStatus[src].emsCondition = nil
            PlayerStatus[src].emsNotifiedAt = nil
            
            -- Trigger un event de récupération
            TriggerEvent('vAvA_ems:statusRecovered', {
                playerId = src,
                playerName = GetPlayerName(src),
                hunger = data.hunger,
                thirst = data.thirst
            })
        else
            -- État critique/danger/collapse
            PlayerStatus[src].emsLevel = data.level
            PlayerStatus[src].emsCondition = data.condition
            PlayerStatus[src].emsNotifiedAt = os.time()
            
            -- Trigger un event global que le module EMS peut écouter
            TriggerEvent('vAvA_ems:statusEmergency', {
                playerId = src,
                playerName = GetPlayerName(src),
                level = data.level,
                hunger = data.hunger,
                thirst = data.thirst,
                condition = data.condition
            })
        end
    end
    
    -- Si le module EMS n'est pas présent, afficher une alerte dans la console
    -- Le module EMS devra écouter l'event 'vAvA_ems:statusEmergency'
end)

-- Export pour que le module EMS puisse consulter l'état des joueurs
function GetPlayerStatusForEMS(playerId)
    if PlayerStatus[playerId] then
        return {
            hunger = PlayerStatus[playerId].hunger,
            thirst = PlayerStatus[playerId].thirst,
            level = GetStatusLevelFromValue(math.min(PlayerStatus[playerId].hunger, PlayerStatus[playerId].thirst)),
            isCritical = PlayerStatus[playerId].emsLevel == "critical" or PlayerStatus[playerId].emsLevel == "collapse",
            isCollapsed = PlayerStatus[playerId].emsLevel == "collapse",
            condition = PlayerStatus[playerId].emsCondition or nil
        }
    end
    return nil
end

-- Fonction utilitaire pour obtenir le niveau à partir d'une valeur
function GetStatusLevelFromValue(value)
    if value >= 70 then return "normal"
    elseif value >= 40 then return "light"
    elseif value >= 20 then return "warning"
    elseif value > 5 then return "danger"
    elseif value > 0 then return "critical"
    else return "collapse"
    end
end

-- Export pour le module EMS
exports('GetPlayerStatusForEMS', GetPlayerStatusForEMS)

-- Handler pour quand le module EMS informe que le joueur est soigné
RegisterNetEvent('vAvA_ems:playerHealed')
AddEventHandler('vAvA_ems:playerHealed', function(playerId, healType)
    -- Si le joueur a été soigné par l'EMS, réinitialiser les flags EMS
    if PlayerStatus[playerId] then
        PlayerStatus[playerId].emsLevel = nil
        PlayerStatus[playerId].emsCondition = nil
        PlayerStatus[playerId].emsNotifiedAt = nil
        
        print(string.format("^2[Status <- EMS]^7 Joueur %s signalé comme soigné (%s)", 
            GetPlayerName(playerId), healType or "unknown"))
    end
end)
