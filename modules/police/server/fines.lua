--[[
    vAvA_police - Système d'Amendes
]]

local vCore = exports['vAvA_core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════════════════════
-- DONNER UNE AMENDE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:GiveFine', function(targetId, amount, reason)
    local src = source
    local officer = vCore.GetPlayer(src)
    local target = vCore.GetPlayer(targetId)
    
    if not officer or not target then return end
    
    -- Vérifier permissions
    local isPolice, grade = exports['vAvA_police']:IsPolice(src)
    if not isPolice or not PoliceConfig.Grades[grade].permissions.fine then
        return TriggerClientEvent('vAvA:Notify', src, 'Permission refusée', 'error')
    end
    
    -- Enregistrer l'amende
    MySQL.insert('INSERT INTO police_fines (officer_id, officer_name, citizen_id, citizen_name, amount, reason) VALUES (?, ?, ?, ?, ?, ?)', {
        officer.PlayerData.citizenid,
        officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
        target.PlayerData.citizenid,
        target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
        amount,
        reason
    }, function(fineId)
        TriggerClientEvent('vAvA:Notify', src, 'Amende de $' .. amount .. ' donnée à ' .. target.PlayerData.firstName, 'success')
        TriggerClientEvent('vAvA:Notify', targetId, 'Amende de $' .. amount .. ' reçue\nMotif: ' .. reason, 'error')
        
        -- Ajouter au casier judiciaire si montant > 500
        if amount >= 500 then
            MySQL.insert('INSERT INTO police_criminal_records (citizen_id, citizen_name, officer_id, officer_name, offense, fine_amount) VALUES (?, ?, ?, ?, ?, ?)', {
                target.PlayerData.citizenid,
                target.PlayerData.firstName .. ' ' .. target.PlayerData.lastName,
                officer.PlayerData.citizenid,
                officer.PlayerData.firstName .. ' ' .. officer.PlayerData.lastName,
                reason,
                amount
            })
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- PAYER UNE AMENDE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:server:PayFine', function(fineId)
    local src = source
    local player = vCore.GetPlayer(src)
    
    if not player then return end
    
    MySQL.single('SELECT * FROM police_fines WHERE id = ? AND paid = 0', {fineId}, function(fine)
        if not fine then
            return TriggerClientEvent('vAvA:Notify', src, 'Amende introuvable', 'error')
        end
        
        if player.PlayerData.money.bank >= fine.amount then
            player.RemoveMoney('bank', fine.amount)
            
            MySQL.update('UPDATE police_fines SET paid = 1, paid_at = NOW() WHERE id = ?', {fineId}, function()
                TriggerClientEvent('vAvA:Notify', src, 'Amende de $' .. fine.amount .. ' payée', 'success')
            end)
        else
            TriggerClientEvent('vAvA:Notify', src, 'Fonds insuffisants', 'error')
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉCUPÉRER LES AMENDES D'UN JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_police:server:GetPlayerFines', function(source, cb, citizenId)
    MySQL.query('SELECT * FROM police_fines WHERE citizen_id = ? ORDER BY created_at DESC LIMIT 20', {citizenId}, function(fines)
        cb(fines or {})
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

function AddFine(officerId, citizenId, amount, reason)
    MySQL.insert('INSERT INTO police_fines (officer_id, officer_name, citizen_id, citizen_name, amount, reason) VALUES (?, ?, ?, ?, ?, ?)', {
        officerId.id,
        officerId.name,
        citizenId.id,
        citizenId.name,
        amount,
        reason
    })
end

exports('AddFine', AddFine)
