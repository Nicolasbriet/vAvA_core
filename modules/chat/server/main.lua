--[[
    vAvA_chat - Server Main
    Module intégré à vAvA_core
]]

-- Initialisation
CreateThread(function()
    print([[^5
    ╔═══════════════════════════════════════╗
    ║         vAvA_chat - Module            ║
    ║      Système de Chat RP Complet       ║
    ╚═══════════════════════════════════════╝
    ^0]])
    print('^2[vAvA_chat] Module démarré avec succès!^0')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer le prénom RP du personnage
local function GetRPFirstName(src)
    -- Tenter via vCore
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.GetPlayer then
        local player = vCore.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.firstName then
            return player.PlayerData.firstName
        end
    end
    
    -- Fallback: nom FiveM
    return GetPlayerName(src) or "Inconnu"
end

-- Récupérer le job du joueur
local function GetPlayerJob(src)
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.GetPlayer then
        local player = vCore.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            return player.PlayerData.job.name
        end
    end
    return nil
end

-- Vérifier si le joueur est staff (utilise le système txAdmin ACE de vCore)
local function isStaff(src)
    -- Méthode principale: utiliser vCore.IsStaff (basé sur txAdmin ACE)
    if vCore and vCore.IsStaff then
        return vCore.IsStaff(src)
    end
    
    -- Fallback: vérifier directement les ACE
    for _, permission in ipairs(ChatConfig.StaffPermissions) do
        if IsPlayerAceAllowed(src, permission) then
            return true
        end
    end
    return false
end

-- Vérifier si le joueur a accès au canal job
local function hasJobAccess(src, channel)
    local playerJob = GetPlayerJob(src)
    if not playerJob then return false end
    
    local allowedJobs = ChatConfig.JobChannels[channel]
    if not allowedJobs then return false end
    
    for _, job in ipairs(allowedJobs) do
        if playerJob == job then
            return true
        end
    end
    return false
end

-- Récupérer les joueurs dans un rayon
local function GetPlayersInRadius(src, radius)
    local players = {}
    local srcPed = GetPlayerPed(src)
    local srcCoords = GetEntityCoords(srcPed)
    
    for _, id in ipairs(GetPlayers()) do
        local ped = GetPlayerPed(id)
        if ped ~= 0 then
            local coords = GetEntityCoords(ped)
            if #(srcCoords - coords) <= radius then
                table.insert(players, id)
            end
        end
    end
    return players
end

-- Envoyer un message aux joueurs avec un job spécifique
local function SendJobMessage(job, type, msg, color)
    local vCore = exports['vAvA_core']:GetCoreObject()
    
    for _, id in ipairs(GetPlayers()) do
        local playerJob = GetPlayerJob(tonumber(id))
        if playerJob then
            local allowedJobs = ChatConfig.JobChannels[job]
            for _, allowedJob in ipairs(allowedJobs or {}) do
                if playerJob == allowedJob then
                    TriggerClientEvent('vAvA_chat:showMessage', id, type, msg, color)
                    break
                end
            end
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

-- Vérification des permissions staff
RegisterServerEvent('vAvA_chat:checkStaff')
AddEventHandler('vAvA_chat:checkStaff', function()
    local src = source
    TriggerClientEvent('vAvA_chat:isStaff', src, isStaff(src))
end)

-- Canal STAFF
RegisterServerEvent('vAvA_chat:staff')
AddEventHandler('vAvA_chat:staff', function(msg)
    local src = source
    local name = GetPlayerName(src)
    
    if isStaff(src) then
        local text = string.format("[STAFF][%s] %s", name, msg)
        for _, id in ipairs(GetPlayers()) do
            if isStaff(id) then
                TriggerClientEvent('vAvA_chat:showMessage', id, 'staff', text, ChatConfig.Colors.staff)
            end
        end
    else
        TriggerClientEvent('vAvA_chat:showMessage', src, 'error', 'Vous n\'êtes pas staff.', {255, 0, 0})
    end
end)

-- Canal POLICE
RegisterServerEvent('vAvA_chat:police')
AddEventHandler('vAvA_chat:police', function(msg)
    local src = source
    local name = GetRPFirstName(src)
    
    if hasJobAccess(src, 'police') then
        local text = string.format("[POLICE][%s] %s", name, msg)
        SendJobMessage('police', 'police', text, ChatConfig.Colors.police)
    else
        TriggerClientEvent('vAvA_chat:showMessage', src, 'error', 'Vous n\'êtes pas policier.', {255, 0, 0})
    end
end)

-- Canal EMS
RegisterServerEvent('vAvA_chat:ems')
AddEventHandler('vAvA_chat:ems', function(msg)
    local src = source
    local name = GetRPFirstName(src)
    
    if hasJobAccess(src, 'ems') then
        local text = string.format("[EMS][%s] %s", name, msg)
        SendJobMessage('ems', 'ems', text, ChatConfig.Colors.ems)
    else
        TriggerClientEvent('vAvA_chat:showMessage', src, 'error', 'Vous n\'êtes pas EMS.', {255, 0, 0})
    end
end)

-- Commande /me (proximité)
RegisterServerEvent('vAvA_chat:me')
AddEventHandler('vAvA_chat:me', function(msg)
    local src = source
    local name = GetRPFirstName(src)
    local text = string.format("[ME] %s %s", name, msg)
    
    local players = GetPlayersInRadius(src, ChatConfig.General.ProximityRadius)
    for _, id in ipairs(players) do
        TriggerClientEvent('vAvA_chat:showMessage', id, 'me', text, ChatConfig.Colors.me)
    end
end)

-- Commande /do (proximité)
RegisterServerEvent('vAvA_chat:do')
AddEventHandler('vAvA_chat:do', function(msg)
    local src = source
    local name = GetRPFirstName(src)
    local text = string.format("[DO][%s] %s", name, msg)
    
    local players = GetPlayersInRadius(src, ChatConfig.General.ProximityRadius)
    for _, id in ipairs(players) do
        TriggerClientEvent('vAvA_chat:showMessage', id, 'do', text, ChatConfig.Colors['do'])
    end
end)

-- Commande /de (lancer de dé, proximité)
RegisterServerEvent('vAvA_chat:de')
AddEventHandler('vAvA_chat:de', function()
    local src = source
    local name = GetRPFirstName(src)
    local roll = math.random(1, 20)
    local text = string.format("[DE][%s] lance un dé : %d/20", name, roll)
    
    local players = GetPlayersInRadius(src, ChatConfig.General.ProximityRadius)
    for _, id in ipairs(players) do
        TriggerClientEvent('vAvA_chat:showMessage', id, 'de', text, ChatConfig.Colors.de)
    end
end)

-- Commande /ooc (proximité)
RegisterServerEvent('vAvA_chat:ooc')
AddEventHandler('vAvA_chat:ooc', function(msg)
    local src = source
    local name = GetPlayerName(src)
    local text = string.format("[OOC][%s] %s", name, msg)
    
    local players = GetPlayersInRadius(src, ChatConfig.General.ProximityRadius)
    for _, id in ipairs(players) do
        TriggerClientEvent('vAvA_chat:showMessage', id, 'ooc', text, ChatConfig.Colors.ooc)
    end
end)

-- Commande /mp (message privé)
RegisterServerEvent('vAvA_chat:mp')
AddEventHandler('vAvA_chat:mp', function(targetId, msg)
    local src = source
    local name = GetPlayerName(src)
    targetId = tonumber(targetId)
    
    if targetId and GetPlayerName(targetId) then
        local textTo = string.format("[MP][%s (%s) → %s] %s", name, src, GetPlayerName(targetId), msg)
        local textFrom = string.format("[MP][%s (%s) → Vous] %s", name, src, msg)
        TriggerClientEvent('vAvA_chat:showMessage', targetId, 'mp', textFrom, ChatConfig.Colors.mp)
        TriggerClientEvent('vAvA_chat:showMessage', src, 'mp', textTo, ChatConfig.Colors.mp)
    else
        TriggerClientEvent('vAvA_chat:showMessage', src, 'error', 'ID du joueur non trouvé.', {255, 0, 0})
    end
end)

-- Vérification des permissions pour l'UI
RegisterNetEvent('vAvA_chat:checkStaffPerms')
AddEventHandler('vAvA_chat:checkStaffPerms', function()
    local src = source
    TriggerClientEvent('vAvA_chat:setStaffPerms', src, isStaff(src))
end)
