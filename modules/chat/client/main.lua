--[[
    vAvA_chat - Client Main
    Module intégré à vAvA_core
]]

-- Variables locales
local isStaffMember = false
local currentJob = nil

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS NUI
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('setNuiFocus', function(data, cb)
    SetNuiFocus(data.focus, data.cursor)
    cb('ok')
end)

RegisterNUICallback('closeChat', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS RÉSEAU
-- ═══════════════════════════════════════════════════════════════════════════

-- Affichage des messages
RegisterNetEvent('vAvA_chat:showMessage')
AddEventHandler('vAvA_chat:showMessage', function(type, msg, color)
    local prefix = '[CHAT]'
    if type == 'me' then prefix = '[ME]'
    elseif type == 'do' then prefix = '[DO]'
    elseif type == 'de' then prefix = '[DE]'
    elseif type == 'ooc' then prefix = '[OOC]'
    elseif type == 'mp' then prefix = '[MP]'
    elseif type == 'police' then prefix = '[POLICE]'
    elseif type == 'ems' then prefix = '[EMS]'
    elseif type == 'staff' then prefix = '[STAFF]'
    elseif type == 'error' then prefix = '[ERREUR]'
    end
    
    SendNUIMessage({
        type = 'showMessage',
        prefix = prefix,
        msg = msg,
        color = color or {255, 255, 255}
    })
end)

-- Réception du statut staff
RegisterNetEvent('vAvA_chat:isStaff')
AddEventHandler('vAvA_chat:isStaff', function(isStaffResult)
    isStaffMember = isStaffResult
    updateChatPermissions()
end)

RegisterNetEvent('vAvA_chat:setStaffPerms')
AddEventHandler('vAvA_chat:setStaffPerms', function(isStaffResult)
    isStaffMember = isStaffResult
    updateChatPermissions()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS LOCALES
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer les données du joueur
local function GetPlayerData()
    local vCore = exports['vAvA_core']:GetCoreObject()
    if vCore and vCore.PlayerData then
        return vCore.PlayerData
    end
    return {}
end

-- Mettre à jour les permissions du chat
function updateChatPermissions()
    local playerData = GetPlayerData()
    local job = playerData.job and playerData.job.name or ''
    currentJob = job
    
    -- Vérifier le statut staff
    TriggerServerEvent('vAvA_chat:checkStaff')
    
    -- Envoyer les permissions au NUI
    SendNUIMessage({
        type = 'updateChatPerms',
        perms = {
            isStaff = isStaffMember,
            job = job
        }
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- THREAD PRINCIPAL - OUVERTURE DU CHAT
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        -- Touche T pour ouvrir le chat
        if IsControlJustReleased(0, ChatConfig.General.OpenKey) then
            if not IsPauseMenuActive() then
                SetNuiFocus(true, true)
                SendNUIMessage({type = 'openChat'})
                updateChatPermissions()
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- THREAD ÉCHAP - FERMETURE DU CHAT
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustReleased(0, 322) then -- ESC
            if IsNuiFocused() then
                SetNuiFocus(false, false)
                SetNuiFocusKeepInput(false)
                SendNUIMessage({type = 'closeChat'})
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS NUI - TRAITEMENT DES MESSAGES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('chatMessage', function(data, cb)
    local msg = data.msg or ''
    
    if msg:sub(1, 1) == '/' then
        local args = {}
        for word in msg:gmatch("[^%s]+") do
            table.insert(args, word)
        end
        local cmd = args[1]:sub(2):lower()
        table.remove(args, 1)
        
        -- Traitement des commandes
        if cmd == 'me' then
            TriggerServerEvent('vAvA_chat:me', table.concat(args, ' '))
        elseif cmd == 'do' then
            TriggerServerEvent('vAvA_chat:do', table.concat(args, ' '))
        elseif cmd == 'de' then
            TriggerServerEvent('vAvA_chat:de')
        elseif cmd == 'ooc' then
            TriggerServerEvent('vAvA_chat:ooc', table.concat(args, ' '))
        elseif cmd == 'mp' then
            local target = args[1]
            table.remove(args, 1)
            local message = table.concat(args, ' ')
            if target and message ~= '' then
                TriggerServerEvent('vAvA_chat:mp', target, message)
            end
        elseif cmd == 'police' then
            TriggerServerEvent('vAvA_chat:police', table.concat(args, ' '))
        elseif cmd == 'ems' then
            TriggerServerEvent('vAvA_chat:ems', table.concat(args, ' '))
        elseif cmd == 'staff' then
            TriggerServerEvent('vAvA_chat:staff', table.concat(args, ' '))
        else
            -- Commande inconnue, exécuter via le système natif
            ExecuteCommand(msg:sub(2))
        end
    else
        -- Message sans commande = /me par défaut
        TriggerServerEvent('vAvA_chat:me', msg)
    end
    
    SendNUIMessage({type = 'closeChat'})
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS DE MISE À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

-- Mise à jour des permissions lors du chargement du joueur
RegisterNetEvent('vCore:playerLoaded')
AddEventHandler('vCore:playerLoaded', function()
    updateChatPermissions()
end)

-- Compatibilité QBCore
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    updateChatPermissions()
end)

-- Mise à jour des permissions lors du changement de job
RegisterNetEvent('vCore:jobChanged')
AddEventHandler('vCore:jobChanged', function()
    updateChatPermissions()
end)

-- Compatibilité QBCore
RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function()
    updateChatPermissions()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SUGGESTIONS DE COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

local allSuggestions = {}

local function sendAllSuggestionsToUI()
    local cmds = {}
    local nativeCmds = GetRegisteredCommands() or {}
    
    if type(nativeCmds) == 'table' then
        for _, cmd in ipairs(nativeCmds) do
            table.insert(cmds, { name = '/' .. cmd.name, help = '' })
        end
    end
    
    local all = {}
    local exists = {}
    
    for _, s in ipairs(cmds) do
        table.insert(all, s)
        exists[s.name] = true
    end
    
    for _, s in ipairs(allSuggestions) do
        if not exists[s.name] then
            table.insert(all, s)
        end
    end
    
    SendNUIMessage({
        type = 'updateSuggestions',
        suggestions = all
    })
end

AddEventHandler('chat:addSuggestion', function(cmd, help, params)
    for _, s in ipairs(allSuggestions) do
        if s.name == cmd then return end
    end
    table.insert(allSuggestions, {name = cmd, help = help or '', params = params})
    sendAllSuggestionsToUI()
end)

RegisterNetEvent('vAvA_chat:requestSuggestions')
AddEventHandler('vAvA_chat:requestSuggestions', function()
    SendNUIMessage({
        type = 'updateSuggestions',
        suggestions = allSuggestions
    })
end)

-- Suggestions par défaut
CreateThread(function()
    Wait(2000)
    
    -- Ajouter les suggestions de commandes de chat
    TriggerEvent('chat:addSuggestion', '/me', 'Action visible en proximité', {})
    TriggerEvent('chat:addSuggestion', '/do', 'Description d\'une situation', {})
    TriggerEvent('chat:addSuggestion', '/de', 'Lancer un dé (1-20)', {})
    TriggerEvent('chat:addSuggestion', '/ooc', 'Message hors personnage (proximité)', {})
    TriggerEvent('chat:addSuggestion', '/mp', 'Message privé à un joueur', {{name = 'id', help = 'ID du joueur'}, {name = 'message', help = 'Votre message'}})
    TriggerEvent('chat:addSuggestion', '/police', 'Canal radio police', {})
    TriggerEvent('chat:addSuggestion', '/ems', 'Canal radio EMS', {})
    TriggerEvent('chat:addSuggestion', '/staff', 'Canal staff (staff uniquement)', {})
end)
