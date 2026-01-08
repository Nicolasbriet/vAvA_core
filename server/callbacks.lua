--[[
    vAvA_core - Server Callbacks System
    Système de callbacks serveur sécurisé
]]

vCore = vCore or {}
vCore.ServerCallbacks = {}

local pendingCallbacks = {}
local callbackId = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- ENREGISTREMENT DES CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un callback serveur
---@param name string
---@param callback function
function vCore.RegisterServerCallback(name, callback)
    vCore.ServerCallbacks[name] = callback
    vCore.Utils.Debug('Callback enregistré:', name)
end

---Alias pour compatibilité
vCore.CreateCallback = vCore.RegisterServerCallback

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉCEPTION DES CALLBACKS DEPUIS LE CLIENT
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:triggerCallback', function(name, requestId, ...)
    local source = source
    
    -- Vérifier que le callback existe
    if not vCore.ServerCallbacks[name] then
        vCore.Utils.Warn('Callback inexistant:', name)
        TriggerClientEvent('vCore:callbackResponse', source, requestId, nil)
        return
    end
    
    -- Rate limit check
    if Config.Security.RateLimit.enabled then
        if not vCore.Security.CheckRateLimit(source, 'callback:' .. name) then
            vCore.Utils.Warn('Rate limit atteint pour', source, 'sur', name)
            TriggerClientEvent('vCore:callbackResponse', source, requestId, nil)
            return
        end
    end
    
    -- Exécuter le callback
    local player = vCore.GetPlayer(source)
    
    vCore.ServerCallbacks[name](source, function(...)
        TriggerClientEvent('vCore:callbackResponse', source, requestId, ...)
    end, player, ...)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS PRÉDÉFINIS
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer les données joueur
vCore.RegisterServerCallback('vCore:getPlayerData', function(source, cb, player)
    if player then
        cb(player:ToClientData())
    else
        cb(nil)
    end
end)

-- Récupérer les personnages
vCore.RegisterServerCallback('vCore:getCharacters', function(source, cb, player, identifier)
    local characters = vCore.DB.GetCharacters(identifier)
    local result = {}
    
    for i, char in ipairs(characters) do
        table.insert(result, {
            id = char.id,
            firstName = char.firstname,
            lastName = char.lastname,
            dob = char.dob,
            gender = char.gender,
            job = json.decode(char.job or '{}'),
            money = json.decode(char.money or '{}')
        })
    end
    
    cb(result)
end)

-- Créer un personnage
vCore.RegisterServerCallback('vCore:createCharacter', function(source, cb, player, data)
    local identifier = vCore.Players.GetIdentifier(source)
    
    -- Vérifier la limite de personnages
    local characters = vCore.DB.GetCharacters(identifier)
    if #characters >= Config.Players.MultiCharacter.maxCharacters then
        cb(false, 'character_limit')
        return
    end
    
    local charId = vCore.DB.CreateCharacter(
        identifier,
        data.firstName,
        data.lastName,
        data.dob,
        data.gender
    )
    
    if charId then
        cb(true, charId)
    else
        cb(false, 'error')
    end
end)

-- Supprimer un personnage
vCore.RegisterServerCallback('vCore:deleteCharacter', function(source, cb, player, charId)
    local identifier = vCore.Players.GetIdentifier(source)
    
    -- Vérifier que le personnage appartient au joueur
    local char = vCore.DB.GetCharacter(charId)
    if not char or char.identifier ~= identifier then
        cb(false)
        return
    end
    
    local success = vCore.DB.DeleteCharacter(charId)
    cb(success)
end)

-- Vérifier si un joueur a un item
vCore.RegisterServerCallback('vCore:hasItem', function(source, cb, player, itemName, amount)
    if player then
        cb(player:HasItem(itemName, amount))
    else
        cb(false)
    end
end)

-- Récupérer l'inventaire
vCore.RegisterServerCallback('vCore:getInventory', function(source, cb, player)
    if player then
        cb(player:GetInventory())
    else
        cb({})
    end
end)

-- Récupérer les véhicules du joueur
vCore.RegisterServerCallback('vCore:getPlayerVehicles', function(source, cb, player)
    if player then
        local vehicles = vCore.DB.GetPlayerVehicles(player:GetIdentifier())
        cb(vehicles)
    else
        cb({})
    end
end)

-- Vérifier si en service
vCore.RegisterServerCallback('vCore:isOnDuty', function(source, cb, player)
    if player then
        cb(player:IsOnDuty())
    else
        cb(false)
    end
end)

-- Récupérer le job
vCore.RegisterServerCallback('vCore:getJob', function(source, cb, player)
    if player then
        cb(player:GetJob())
    else
        cb(nil)
    end
end)

-- Vérifier une permission job
vCore.RegisterServerCallback('vCore:hasJobPermission', function(source, cb, player, permission)
    if player then
        cb(player:HasJobPermission(permission))
    else
        cb(false)
    end
end)
