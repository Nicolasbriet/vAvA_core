--[[
    vAvA_core - Server Commands
    Commandes admin et utilisateur
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES UTILISATEUR
-- ═══════════════════════════════════════════════════════════════════════════

-- /me - Action RP
RegisterCommand('me', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local message = table.concat(args, ' ')
    if message == '' then return end
    
    local name = player:GetName()
    local text = '^5[ME] ^7' .. name .. ' ' .. message
    
    -- Envoyer aux joueurs proches
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    local players = vCore.GetPlayers()
    for id, p in pairs(players) do
        local targetPed = GetPlayerPed(id)
        local targetCoords = GetEntityCoords(targetPed)
        local dist = #(coords - targetCoords)
        
        if dist < 30.0 then
            TriggerClientEvent('chat:addMessage', id, {args = {text}})
        end
    end
end, false)

-- /do - Description RP
RegisterCommand('do', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local message = table.concat(args, ' ')
    if message == '' then return end
    
    local text = '^3[DO] ^7' .. message
    
    -- Envoyer aux joueurs proches
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    local players = vCore.GetPlayers()
    for id, p in pairs(players) do
        local targetPed = GetPlayerPed(id)
        local targetCoords = GetEntityCoords(targetPed)
        local dist = #(coords - targetCoords)
        
        if dist < 30.0 then
            TriggerClientEvent('chat:addMessage', id, {args = {text}})
        end
    end
end, false)

-- /ooc - Message hors RP
RegisterCommand('ooc', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local message = table.concat(args, ' ')
    if message == '' then return end
    
    local name = GetPlayerName(source)
    local text = '^1[OOC] ^7' .. name .. ': ' .. message
    
    TriggerClientEvent('chat:addMessage', -1, {args = {text}})
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

-- /give - Donner un item
RegisterCommand('give', function(source, args, rawCommand)
    local admin = vCore.GetPlayer(source)
    if source > 0 and (not admin or not admin:IsAdmin()) then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 3 then
        local msg = 'Usage: /give [id] [item] [quantité]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local itemName = args[2]
    local amount = tonumber(args[3]) or 1
    
    if vCore.Inventory.AddItem(targetId, itemName, amount) then
        vCore.Notify(source, Lang('admin_item_given'), 'success')
    end
end, false)

-- /givemoney - Donner de l'argent
RegisterCommand('givemoney', function(source, args, rawCommand)
    local admin = vCore.GetPlayer(source)
    if source > 0 and (not admin or not admin:IsAdmin()) then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 3 then
        local msg = 'Usage: /givemoney [id] [type: cash/bank] [montant]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local moneyType = args[2]
    local amount = tonumber(args[3]) or 0
    
    if vCore.Economy.AddMoney(targetId, moneyType, amount, 'Admin') then
        vCore.Notify(source, Lang('admin_money_given'), 'success')
    end
end, false)

-- /setjob - Définir le job
RegisterCommand('setjob', function(source, args, rawCommand)
    local admin = vCore.GetPlayer(source)
    if source > 0 and (not admin or not admin:IsAdmin()) then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 3 then
        local msg = 'Usage: /setjob [id] [job] [grade]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3]) or 0
    
    if vCore.Jobs.SetJob(targetId, jobName, grade) then
        vCore.Notify(source, Lang('admin_job_set'), 'success')
    end
end, false)

-- /tp - Téléportation à un joueur
RegisterCommand('tp', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /tp [id]', 'info')
        return
    end
    
    local targetId = tonumber(args[1])
    local targetPed = GetPlayerPed(targetId)
    
    if targetPed then
        local coords = GetEntityCoords(targetPed)
        TriggerClientEvent('vCore:teleport', source, coords.x, coords.y, coords.z)
        vCore.Notify(source, Lang('admin_player_teleported'), 'success')
    end
end, false)

-- /bring - Téléporter un joueur à soi
RegisterCommand('bring', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /bring [id]', 'info')
        return
    end
    
    local targetId = tonumber(args[1])
    local adminPed = GetPlayerPed(source)
    local coords = GetEntityCoords(adminPed)
    
    TriggerClientEvent('vCore:teleport', targetId, coords.x, coords.y, coords.z)
    vCore.Notify(source, Lang('admin_player_teleported'), 'success')
end, false)

-- /heal - Soigner un joueur
RegisterCommand('heal', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    TriggerClientEvent('vCore:heal', targetId)
    vCore.Notify(source, Lang('admin_player_healed'), 'success')
end, false)

-- /revive - Réanimer un joueur
RegisterCommand('revive', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    TriggerClientEvent('vCore:revive', targetId)
    vCore.Notify(source, Lang('admin_player_revived'), 'success')
end, false)

-- /kick - Expulser un joueur
RegisterCommand('kick', function(source, args, rawCommand)
    local admin = vCore.GetPlayer(source)
    if source > 0 and (not admin or not admin:IsAdmin()) then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 1 then
        local msg = 'Usage: /kick [id] [raison]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local reason = table.concat(args, ' ', 2) or 'Aucune raison'
    
    DropPlayer(targetId, Lang('security_kicked') .. '\n' .. Lang('security_kick_reason', reason))
    
    vCore.Notify(source, Lang('admin_player_kicked'), 'success')
    
    -- Log
    local adminName = source > 0 and GetPlayerName(source) or 'Console'
    vCore.Log('admin', 'admin:' .. adminName, 'Kick: #' .. targetId, {reason = reason})
end, false)

-- /car - Spawner un véhicule
RegisterCommand('car', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /car [modèle]', 'info')
        return
    end
    
    local model = args[1]
    TriggerClientEvent('vCore:spawnVehicleAdmin', source, model)
end, false)

-- /dv - Supprimer le véhicule
RegisterCommand('dv', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local admin = vCore.GetPlayer(source)
    if not admin or not admin:IsAdmin() then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    TriggerClientEvent('vCore:deleteVehicle', source)
    vCore.Notify(source, Lang('admin_vehicle_deleted'), 'success')
end, false)

-- /players - Liste des joueurs
RegisterCommand('players', function(source, args, rawCommand)
    local players = vCore.GetPlayers()
    
    print('=== JOUEURS CONNECTÉS ===')
    for id, player in pairs(players) do
        print(string.format('[%d] %s (%s) - Job: %s', 
            id, 
            player:GetName(),
            player:GetIdentifier(),
            player:GetJob().label
        ))
    end
    print('========================')
    print('Total: ' .. vCore.GetPlayerCount() .. ' joueur(s)')
end, false)

-- /refresh - Recharger les caches
RegisterCommand('refresh', function(source, args, rawCommand)
    local admin = vCore.GetPlayer(source)
    if source > 0 and (not admin or not admin:IsAdmin()) then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    vCore.Cache.Items.Load()
    vCore.Cache.Jobs.Load()
    
    local msg = 'Caches rechargés'
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
end, false)
