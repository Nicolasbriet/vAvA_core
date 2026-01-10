--[[
    vAvA_police - Server Records
    API pour casier judiciaire et identité
]]

local vCore = exports['vAvA_core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - IDENTITÉ
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_police:server:GetPlayerIdentity', function(source, cb, targetId)
    local target = vCore.GetPlayer(targetId)
    
    if not target then
        cb(nil)
        return
    end
    
    cb({
        firstName = target.PlayerData.firstName,
        lastName = target.PlayerData.lastName,
        dateofbirth = target.PlayerData.dateofbirth,
        sex = target.PlayerData.sex,
        phone = target.PlayerData.phone,
        job = target.PlayerData.job.label,
        citizenid = target.PlayerData.citizenid
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - CASIER JUDICIAIRE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:CheckCriminalRecord', function(targetId)
    local src = source
    local target = vCore.GetPlayer(targetId)
    
    if not target then
        return TriggerClientEvent('vAvA:Notify', src, 'Joueur introuvable', 'error')
    end
    
    exports['vAvA_police']:GetCriminalRecord(target.PlayerData.citizenid, function(records)
        if not records or #records == 0 then
            TriggerClientEvent('vAvA:Notify', src, 'Casier judiciaire vierge', 'success')
            return
        end
        
        local msg = string.format('~r~CASIER JUDICIAIRE~s~\n%s %s\n\n', target.PlayerData.firstName, target.PlayerData.lastName)
        
        for i, record in ipairs(records) do
            if i <= 5 then -- Max 5 derniers
                msg = msg .. string.format(
                    '~y~%s~s~\nAmende: $%d | Prison: %d min\nOfficier: %s\nDate: %s\n\n',
                    record.offense,
                    record.fine_amount,
                    record.jail_time,
                    record.officer_name,
                    record.created_at
                )
            end
        end
        
        if #records > 5 then
            msg = msg .. string.format('... et %d autres infractions', #records - 5)
        end
        
        TriggerClientEvent('vAvA:Notify', src, msg, 'info', 15000)
    end)
end)

vCore.CreateCallback('vAvA_police:server:GetCriminalRecordFull', function(source, cb, citizenId)
    exports['vAvA_police']:GetCriminalRecord(citizenId, function(records)
        cb(records)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - RECHERCHE PERSONNE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_police:server:SearchPerson', function(source, cb, query)
    exports['vAvA_police']:SearchPersonByName(query, function(results)
        local formatted = {}
        
        for _, person in ipairs(results) do
            table.insert(formatted, {
                citizenid = person.citizenid,
                firstName = person.firstname,
                lastName = person.lastname,
                dateofbirth = person.dateofbirth,
                sex = person.sex,
                phone = person.phone_number,
                job = person.job
            })
        end
        
        cb(formatted)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS - RECHERCHE VÉHICULE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_police:server:SearchVehicle', function(source, cb, plate)
    exports['vAvA_police']:SearchVehicleByPlate(plate, function(vehicle)
        if not vehicle then
            cb(nil)
            return
        end
        
        -- Récupérer propriétaire
        MySQL.single('SELECT firstname, lastname FROM users WHERE citizenid = ?', {vehicle.owner}, function(owner)
            cb({
                plate = vehicle.plate,
                model = vehicle.vehicle,
                owner = owner and (owner.firstname .. ' ' .. owner.lastname) or 'Inconnu',
                ownerid = vehicle.owner
            })
        end)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- AJOUTER ENREGISTREMENT CASIER
-- ═══════════════════════════════════════════════════════════════════════════

function AddCriminalRecord(officerId, officerName, citizenId, citizenName, offense, details, fineAmount, jailTime)
    exports['vAvA_police']:AddCriminalRecord({
        citizen_id = citizenId,
        citizen_name = citizenName,
        officer_id = officerId,
        officer_name = officerName,
        offense = offense,
        description = details,
        fine_amount = fineAmount or 0,
        jail_time = jailTime or 0
    })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('AddCriminalRecord', AddCriminalRecord)
exports('GetCriminalRecord', function(citizenId, callback)
    exports['vAvA_police']:GetCriminalRecord(citizenId, callback)
end)
