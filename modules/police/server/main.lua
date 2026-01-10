--[[
    vAvA_police - Server Main
    Gestion principale côté serveur
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

local vCore = exports['vAvA_core']:GetCoreObject()
local onDutyPolice = {} -- Liste des policiers en service

CreateThread(function()
    print([[^5
    ╔═══════════════════════════════════════╗
    ║       vAvA_police - Module Police     ║
    ║     Système Complet de Gestion        ║
    ╚═══════════════════════════════════════╝
    ^0]])
    
    -- Vérifier la base de données
    MySQL.ready(function()
        print('^2[vAvA_police] Base de données connectée^0')
        
        -- Libérer les prisonniers dont le temps est écoulé
        MySQL.query('SELECT * FROM police_prisoners WHERE time_remaining <= 0', {}, function(prisoners)
            for _, prisoner in ipairs(prisoners) do
                TriggerClientEvent('vAvA_police:client:ReleaseFromJail', prisoner.citizen_id)
                MySQL.query('DELETE FROM police_prisoners WHERE id = ?', {prisoner.id})
            end
        end)
    end)
    
    print('^2[vAvA_police] Module démarré avec succès!^0')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer le joueur vCore
local function GetPlayer(source)
    return vCore.GetPlayer(source)
end

-- Vérifier si le joueur est police
local function IsPolice(source)
    local player = GetPlayer(source)
    if not player then return false end
    
    local job = player.PlayerData.job
    if not job then return false end
    
    for _, policeJob in ipairs(PoliceConfig.General.PoliceJobs) do
        if job.name == policeJob then
            return true, job.grade.level
        end
    end
    return false
end

-- Vérifier les permissions par grade
local function HasPermission(source, permission)
    local isPolice, grade = IsPolice(source)
    if not isPolice then return false end
    
    local gradeConfig = PoliceConfig.Grades[grade]
    if not gradeConfig then return false end
    
    return gradeConfig.permissions[permission] == true
end

-- Logger les actions
local function LogAction(officerId, officerName, action, targetId, targetName, details)
    MySQL.insert('INSERT INTO police_logs (officer_id, officer_name, action, target_id, target_name, details) VALUES (?, ?, ?, ?, ?, ?)', {
        officerId,
        officerName,
        action,
        targetId or nil,
        targetName or nil,
        details or nil
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - SERVICE ON/OFF DUTY
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:ToggleDuty', function()
    local src = source
    local isPolice = IsPolice(src)
    
    if not isPolice then return end
    
    if onDutyPolice[src] then
        onDutyPolice[src] = nil
        TriggerClientEvent('vAvA_police:client:SetDuty', src, false)
        TriggerClientEvent('vAvA:Notify', src, 'Vous êtes maintenant hors service', 'info')
    else
        onDutyPolice[src] = true
        TriggerClientEvent('vAvA_police:client:SetDuty', src, true)
        TriggerClientEvent('vAvA:Notify', src, 'Vous êtes maintenant en service', 'success')
    end
    
    -- Informer tous les clients
    TriggerClientEvent('vAvA_police:client:UpdateOnDutyList', -1, GetOnDutyPoliceList())
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - MENOTTES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:Handcuff', function(targetId)
    local src = source
    
    if not HasPermission(src, 'handcuff') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    local officer = GetPlayer(src)
    local target = GetPlayer(targetId)
    
    if not officer or not target then return end
    
    TriggerClientEvent('vAvA_police:client:GetHandcuffed', targetId)
    TriggerClientEvent('vAvA:Notify', src, 'Vous avez menotté ' .. target.PlayerData.firstName, 'success')
    TriggerClientEvent('vAvA:Notify', targetId, 'Vous avez été menotté', 'warning')
    
    LogAction(
        officer.PlayerData.citizenid,
        officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
        'handcuff',
        target.PlayerData.citizenid,
        target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
        'Menottage'
    )
end)

RegisterNetEvent('vAvA_police:server:Unhandcuff', function(targetId)
    local src = source
    
    if not HasPermission(src, 'handcuff') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    local officer = GetPlayer(src)
    local target = GetPlayer(targetId)
    
    if not officer or not target then return end
    
    TriggerClientEvent('vAvA_police:client:GetUnhandcuffed', targetId)
    TriggerClientEvent('vAvA:Notify', src, 'Vous avez démenotté ' .. target.PlayerData.firstName, 'success')
    TriggerClientEvent('vAvA:Notify', targetId, 'Vous avez été démenotté', 'info')
    
    LogAction(
        officer.PlayerData.citizenid,
        officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
        'unhandcuff',
        target.PlayerData.citizenid,
        target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
        'Démenottage'
    )
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - ESCORTE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:Escort', function(targetId)
    local src = source
    
    if not HasPermission(src, 'handcuff') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    TriggerClientEvent('vAvA_police:client:GetEscorted', targetId, src)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:PutInVehicle', function(targetId)
    local src = source
    
    if not HasPermission(src, 'handcuff') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    TriggerClientEvent('vAvA_police:client:PutInVehicle', targetId)
end)

RegisterNetEvent('vAvA_police:server:RemoveFromVehicle', function(targetId)
    local src = source
    
    if not HasPermission(src, 'handcuff') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    TriggerClientEvent('vAvA_police:client:RemoveFromVehicle', targetId)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - FOUILLE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:SearchPlayer', function(targetId)
    local src = source
    
    if not HasPermission(src, 'search') then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    local officer = GetPlayer(src)
    local target = GetPlayer(targetId)
    
    if not officer or not target then return end
    
    -- Récupérer l'inventaire du joueur
    local inventory = target.PlayerData.inventory or {}
    local foundItems = {}
    local illegalItems = {}
    
    for _, item in pairs(inventory) do
        if item.amount > 0 then
            table.insert(foundItems, {
                name = item.name,
                label = item.label,
                amount = item.amount
            })
            
            -- Vérifier si item illégal
            for _, illegal in ipairs(PoliceConfig.Interactions.IllegalItems) do
                if item.name == illegal then
                    table.insert(illegalItems, item)
                end
            end
        end
    end
    
    -- Envoyer les résultats
    TriggerClientEvent('vAvA_police:client:ShowSearchResults', src, foundItems, illegalItems)
    TriggerClientEvent('vAvA:Notify', targetId, 'Vous êtes en train d\'être fouillé', 'warning')
    
    -- Confisquer les items illégaux automatiquement
    if #illegalItems > 0 then
        for _, item in ipairs(illegalItems) do
            target.RemoveItem(item.name, item.amount)
            
            -- Logger la confiscation
            MySQL.insert('INSERT INTO police_confiscated_items (citizen_id, citizen_name, officer_id, officer_name, item_name, item_label, quantity) VALUES (?, ?, ?, ?, ?, ?, ?)', {
                target.PlayerData.citizenid,
                target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
                officer.PlayerData.citizenid,
                officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
                item.name,
                item.label,
                item.amount
            })
        end
        
        TriggerClientEvent('vAvA:Notify', src, #illegalItems .. ' items illégaux confisqués', 'success')
        TriggerClientEvent('vAvA:Notify', targetId, 'Items illégaux confisqués', 'error')
    end
    
    LogAction(
        officer.PlayerData.citizenid,
        officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
        'search',
        target.PlayerData.citizenid,
        target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
        #foundItems .. ' items trouvés, ' .. #illegalItems .. ' items confisqués'
    )
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PUBLIQUES (EXPORTS)
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer la liste des policiers en service
function GetOnDutyPoliceList()
    local list = {}
    for playerId, _ in pairs(onDutyPolice) do
        local player = GetPlayer(playerId)
        if player then
            table.insert(list, {
                source = playerId,
                name = player.PlayerData.firstName .. ' ' .. player.PlayerData.lastName,
                grade = player.PlayerData.job.grade.name
            })
        end
    end
    return list
end

-- Vérifier si un joueur est police en service
function IsPoliceOnDuty(source)
    return onDutyPolice[source] == true
end

-- Récupérer tous les policiers en service
function GetOnDutyPolice()
    local count = 0
    for _, _ in pairs(onDutyPolice) do
        count = count + 1
    end
    return count, onDutyPolice
end

-- Envoyer une alerte à tous les policiers
function SendPoliceAlert(code, message, coords, priority)
    priority = priority or 3
    
    for playerId, _ in pairs(onDutyPolice) do
        TriggerClientEvent('vAvA_police:client:ReceiveAlert', playerId, {
            code = code,
            message = message,
            coords = coords,
            priority = priority,
            timestamp = os.time()
        })
    end
    
    -- Logger l'alerte
    local street = GetStreetNameFromHashKey(GetStreetNameAtCoord(coords.x, coords.y, coords.z))
    MySQL.insert('INSERT INTO police_alerts (alert_code, alert_type, message, coords_x, coords_y, coords_z, street, priority) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        code,
        'auto',
        message,
        coords.x,
        coords.y,
        coords.z,
        street,
        priority
    })
end

-- Exports
exports('IsPoliceOnDuty', IsPoliceOnDuty)
exports('GetOnDutyPolice', GetOnDutyPolice)
exports('SendPoliceAlert', SendPoliceAlert)
exports('GetOnDutyPoliceList', GetOnDutyPoliceList)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS - DÉCONNEXION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function()
    local src = source
    if onDutyPolice[src] then
        onDutyPolice[src] = nil
        TriggerClientEvent('vAvA_police:client:UpdateOnDutyList', -1, GetOnDutyPoliceList())
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_police:server:IsPolice', function(source, cb)
    cb(IsPolice(source))
end)

vCore.CreateCallback('vAvA_police:server:HasPermission', function(source, cb, permission)
    cb(HasPermission(source, permission))
end)

vCore.CreateCallback('vAvA_police:server:GetOnDutyPolice', function(source, cb)
    cb(GetOnDutyPoliceList())
end)
