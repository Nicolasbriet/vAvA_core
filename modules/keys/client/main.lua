--[[
    vAvA_keys - Client Main
    Système principal côté client
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local playerKeys = {}
local jobKeys = {}
local sharedKeys = {}
local keysReady = false
local lastNoKeysNotification = 0
local notificationCooldowns = {}

-- Rendre accessible globalement
_G.playerKeys = playerKeys
_G.jobKeys = jobKeys
_G.sharedKeys = sharedKeys
_G.jobAccessCache = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('vAvA_keys:requestKeys')
    
    if KeysConfig.Debug then
        print('^2[vAvA_keys]^0 Client initialisé')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

-- Notification
function ShowKeysNotif(msg, type, title)
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.Notify then
        vCore.Notify(msg, type)
    else
        print('[vAvA_keys] ' .. msg)
    end
end

-- Vérifier si le joueur a les clés
function HasKeys(plate)
    if not plate or plate == "" then return false end
    plate = string.gsub(plate, "%s+", "")
    return playerKeys[plate] == true
end

-- Export accessible
exports('HasKeys', HasKeys)
_G.HasKeys = HasKeys

-- Obtenir le véhicule le plus proche
function GetClosestVehicle(maxDistance)
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local closestVeh, minDist = nil, maxDistance or KeysConfig.Keys.InteractionDistance
    
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local dist = #(GetEntityCoords(vehicle) - pos)
        if dist < minDist then
            minDist = dist
            closestVeh = vehicle
        end
    end
    
    return closestVeh, minDist
end

exports('GetClosestVehicle', GetClosestVehicle)

-- Animation télécommande
function PlayKeyFobAnimation()
    if not KeysConfig.Keys.EnableKeyFobAnimation then return end
    
    local ped = PlayerPedId()
    RequestAnimDict("anim@mp_player_intmenu@key_fob@")
    while not HasAnimDictLoaded("anim@mp_player_intmenu@key_fob@") do 
        Wait(10) 
    end
    TaskPlayAnim(ped, "anim@mp_player_intmenu@key_fob@", "fob_click", 8.0, -8.0, 700, 48, 0, false, false, false)
end

-- Faire clignoter les feux
function FlashVehicleLights(vehicle)
    if not KeysConfig.Effects.FlashLights then return end
    
    SetVehicleLights(vehicle, 2)
    Wait(KeysConfig.Effects.FlashDuration)
    SetVehicleLights(vehicle, 0)
end

-- Notification pas de clés avec cooldown
function ShowNoKeysNotification(plate)
    local now = GetGameTimer()
    
    if now - lastNoKeysNotification < KeysConfig.Keys.NoKeysNotificationCooldown then
        return
    end
    
    if notificationCooldowns[plate] and now - notificationCooldowns[plate] < KeysConfig.Keys.NoKeysNotificationCooldown then
        return
    end
    
    ShowKeysNotif('🔑 Vous n\'avez pas les clés de ce véhicule !', 'error')
    
    lastNoKeysNotification = now
    notificationCooldowns[plate] = now
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Synchronisation des clés
RegisterNetEvent('vAvA_keys:syncKeys')
AddEventHandler('vAvA_keys:syncKeys', function(keys, jobKeysData, sharedKeysData)
    playerKeys = keys or {}
    jobKeys = jobKeysData or {}
    sharedKeys = sharedKeysData or {}
    _G.playerKeys = playerKeys
    _G.jobKeys = jobKeys
    _G.sharedKeys = sharedKeys
    keysReady = true
    
    if KeysConfig.Debug then
        print('^2[vAvA_keys]^0 Clés synchronisées:', json.encode(keys))
    end
end)

-- Sync verrouillage depuis serveur
RegisterNetEvent('vAvA_keys:syncVehicleLockFromServer')
AddEventHandler('vAvA_keys:syncVehicleLockFromServer', function(netId, isLocked)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    
    if vehicle and DoesEntityExist(vehicle) then
        if isLocked then
            SetVehicleDoorsLocked(vehicle, 2)
            SetVehicleDoorsLockedForAllPlayers(vehicle, true)
        else
            SetVehicleDoorsLocked(vehicle, 1)
            SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        end
    end
end)

-- Réception d'une clé
RegisterNetEvent('vAvA_keys:receiveKey')
AddEventHandler('vAvA_keys:receiveKey', function(plate, keyType)
    if not plate then return end
    
    plate = string.gsub(plate, "%s+", "")
    playerKeys[plate] = true
    _G.playerKeys = playerKeys
    
    local typeText = keyType == 'temp' and 'temporaires' or 'permanentes'
    ShowKeysNotif('Vous avez reçu les clés ' .. typeText .. ' du véhicule ' .. plate, 'success')
end)

-- Perte d'une clé
RegisterNetEvent('vAvA_keys:removeKey')
AddEventHandler('vAvA_keys:removeKey', function(plate, reason)
    if not plate then return end
    
    plate = string.gsub(plate, "%s+", "")
    playerKeys[plate] = nil
    _G.playerKeys = playerKeys
    
    ShowKeysNotif(reason or 'Vous n\'avez plus les clés de ' .. plate, 'info')
end)

-- Notification du serveur
RegisterNetEvent('vAvA_keys:notify')
AddEventHandler('vAvA_keys:notify', function(msg, type)
    ShowKeysNotif(msg, type)
end)

-- Réponse accès job
RegisterNetEvent('vAvA_keys:jobAccessResponse')
AddEventHandler('vAvA_keys:jobAccessResponse', function(plate, hasAccess)
    plate = string.gsub(plate, "%s+", "")
    _G.jobAccessCache[plate] = hasAccess
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

-- Chargement du joueur
RegisterNetEvent('vCore:playerLoaded')
AddEventHandler('vCore:playerLoaded', function()
    TriggerServerEvent('vAvA_keys:requestKeys')
end)

-- Compatibilité QBCore
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('vAvA_keys:requestKeys')
end)
