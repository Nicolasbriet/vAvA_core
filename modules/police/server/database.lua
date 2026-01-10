--[[
    vAvA_police - Server Database
    Helpers pour accès base de données
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- AMENDES
-- ═══════════════════════════════════════════════════════════════════════════

function GetPlayerFines(citizenId, callback)
    MySQL.query('SELECT * FROM police_fines WHERE citizen_id = ? ORDER BY created_at DESC LIMIT 20', {citizenId}, function(result)
        callback(result or {})
    end)
end

function GetUnpaidFines(citizenId, callback)
    MySQL.query('SELECT * FROM police_fines WHERE citizen_id = ? AND paid = 0 ORDER BY created_at DESC', {citizenId}, function(result)
        callback(result or {})
    end)
end

function CreateFine(data, callback)
    MySQL.insert('INSERT INTO police_fines (officer_id, officer_name, citizen_id, citizen_name, amount, reason) VALUES (?, ?, ?, ?, ?, ?)', {
        data.officer_id,
        data.officer_name,
        data.citizen_id,
        data.citizen_name,
        data.amount,
        data.reason
    }, function(id)
        callback(id)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CASIER JUDICIAIRE
-- ═══════════════════════════════════════════════════════════════════════════

function GetCriminalRecord(citizenId, callback)
    MySQL.query('SELECT * FROM police_criminal_records WHERE citizen_id = ? ORDER BY created_at DESC', {citizenId}, function(result)
        callback(result or {})
    end)
end

function AddCriminalRecord(data, callback)
    MySQL.insert('INSERT INTO police_criminal_records (citizen_id, citizen_name, officer_id, officer_name, offense, description, fine_amount, jail_time) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.citizen_id,
        data.citizen_name,
        data.officer_id,
        data.officer_name,
        data.offense,
        data.description or nil,
        data.fine_amount or 0,
        data.jail_time or 0
    }, function(id)
        if callback then callback(id) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PRISON
-- ═══════════════════════════════════════════════════════════════════════════

function GetPrisoner(citizenId, callback)
    MySQL.single('SELECT * FROM police_prisoners WHERE citizen_id = ?', {citizenId}, function(result)
        callback(result)
    end)
end

function CreatePrisoner(data, callback)
    MySQL.insert('INSERT INTO police_prisoners (citizen_id, citizen_name, officer_id, officer_name, jail_time, time_remaining, reason, release_at) VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))', {
        data.citizen_id,
        data.citizen_name,
        data.officer_id,
        data.officer_name,
        data.jail_time,
        data.time_remaining,
        data.reason,
        data.jail_time
    }, function(id)
        callback(id)
    end)
end

function UpdatePrisonerTime(id, timeRemaining)
    MySQL.update('UPDATE police_prisoners SET time_remaining = ? WHERE id = ?', {timeRemaining, id})
end

function ReleasePrisoner(citizenId)
    MySQL.update('DELETE FROM police_prisoners WHERE citizen_id = ?', {citizenId})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ALERTES
-- ═══════════════════════════════════════════════════════════════════════════

function CreateAlert(data, callback)
    local streetHash = GetStreetNameAtCoord(data.coords.x, data.coords.y, data.coords.z)
    local street = GetStreetNameFromHashKey(streetHash)
    
    MySQL.insert('INSERT INTO police_alerts (alert_code, alert_type, message, coords_x, coords_y, coords_z, street, priority) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
        data.code,
        data.type,
        data.message,
        data.coords.x,
        data.coords.y,
        data.coords.z,
        street,
        data.priority or 3
    }, function(id)
        if callback then callback(id) end
    end)
end

function GetRecentAlerts(limit, callback)
    MySQL.query('SELECT * FROM police_alerts WHERE responded = 0 ORDER BY created_at DESC LIMIT ?', {limit or 10}, function(result)
        callback(result or {})
    end)
end

function RespondToAlert(alertId, officerId)
    MySQL.update('UPDATE police_alerts SET responded = 1, responder_id = ?, responded_at = NOW() WHERE id = ?', {officerId, alertId})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉHICULES SAISIS
-- ═══════════════════════════════════════════════════════════════════════════

function ImpoundVehicle(data, callback)
    MySQL.insert('INSERT INTO police_impounded_vehicles (plate, owner_id, owner_name, officer_id, officer_name, reason, impound_fee) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.plate,
        data.owner_id,
        data.owner_name,
        data.officer_id,
        data.officer_name,
        data.reason,
        data.impound_fee or 500
    }, function(id)
        if callback then callback(id) end
    end)
end

function ReleaseImpoundedVehicle(plate)
    MySQL.update('UPDATE police_impounded_vehicles SET released_at = NOW() WHERE plate = ? AND released_at IS NULL', {plate})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS CONFISQUÉS
-- ═══════════════════════════════════════════════════════════════════════════

function LogConfiscatedItem(data)
    MySQL.insert('INSERT INTO police_confiscated_items (citizen_id, citizen_name, officer_id, officer_name, item_name, item_label, quantity) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        data.citizen_id,
        data.citizen_name,
        data.officer_id,
        data.officer_name,
        data.item_name,
        data.item_label,
        data.quantity
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGS
-- ═══════════════════════════════════════════════════════════════════════════

function LogPoliceAction(data)
    MySQL.insert('INSERT INTO police_logs (officer_id, officer_name, action, target_id, target_name, details) VALUES (?, ?, ?, ?, ?, ?)', {
        data.officer_id,
        data.officer_name,
        data.action,
        data.target_id or nil,
        data.target_name or nil,
        data.details or nil
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RECHERCHES
-- ═══════════════════════════════════════════════════════════════════════════

function SearchPersonByName(name, callback)
    MySQL.query('SELECT * FROM users WHERE CONCAT(firstname, " ", lastname) LIKE ? LIMIT 10', {'%' .. name .. '%'}, function(result)
        callback(result or {})
    end)
end

function SearchVehicleByPlate(plate, callback)
    MySQL.single('SELECT * FROM owned_vehicles WHERE plate = ?', {plate}, function(result)
        callback(result)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetPlayerFines', GetPlayerFines)
exports('GetCriminalRecord', GetCriminalRecord)
exports('AddCriminalRecord', AddCriminalRecord)
exports('CreateAlert', CreateAlert)
exports('LogPoliceAction', LogPoliceAction)
