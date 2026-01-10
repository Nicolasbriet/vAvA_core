--[[
    vAvA_core - Server Commands
    Commandes admin et utilisateur
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si un joueur a les permissions admin (ACE ou player object)
---@param source number
---@param aceCommand string|nil ACE spécifique à vérifier (ex: "command.car")
---@return boolean
local function HasAdminPermission(source, aceCommand)
    if source == 0 then return true end -- Console = toujours admin
    
    -- Vérifier ACE directement (fonctionne même sans personnage chargé)
    if aceCommand and IsPlayerAceAllowed(source, aceCommand) then
        return true
    end
    
    -- Vérifier ACE admin générique
    if IsPlayerAceAllowed(source, 'vava.admin') or 
       IsPlayerAceAllowed(source, 'vava.superadmin') or
       IsPlayerAceAllowed(source, 'vava.developer') or
       IsPlayerAceAllowed(source, 'vava.owner') then
        return true
    end
    
    -- Fallback: vérifier via l'objet player (si personnage chargé)
    local player = vCore.GetPlayer(source)
    if player and player:IsAdmin() then
        return true
    end
    
    return false
end

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
-- /vava_getid - Obtenir son identifiant (pour ajouter au server.cfg)
RegisterCommand('vava_getid', function(source, args, rawCommand)
    if source <= 0 then return end
    
    local identifiers = vCore.Players.GetAllIdentifiers(source)
    local identifier = vCore.Players.GetIdentifier(source)
    
    vCore.Notify(source, '~b~=== VOS IDENTIFIANTS ===', 'info')
    if identifiers.license then
        vCore.Notify(source, '~g~License:~w~ ' .. identifiers.license, 'info')
    end
    if identifiers.discord then
        vCore.Notify(source, '~b~Discord:~w~ ' .. identifiers.discord, 'info')
    end
    if identifiers.steam then
        vCore.Notify(source, '~y~Steam:~w~ ' .. identifiers.steam, 'info')
    end
    
    print('=================================================')
    print('[vAvA_core] IDENTIFIANTS pour ' .. GetPlayerName(source))
    print('=================================================')
    print('Principal: ' .. (identifier or 'AUCUN'))
    if identifiers.license then print('License  : ' .. identifiers.license) end
    if identifiers.discord then print('Discord  : ' .. identifiers.discord) end
    if identifiers.steam then print('Steam    : ' .. identifiers.steam) end
    print('=================================================')
    print('Pour ajouter comme admin, copiez cette ligne dans server.cfg:')
    print('add_principal identifier.' .. (identifiers.license or 'license:VOTRE_LICENSE') .. ' group.admin')
    print('=================================================')
end, false)
-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

-- /give - Donner un item
RegisterCommand('give', function(source, args, rawCommand)
    if source > 0 and not HasAdminPermission(source, 'command.give') then
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
    if source > 0 and not HasAdminPermission(source, 'command.givemoney') then
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
    if source > 0 and not HasAdminPermission(source, 'command.setjob') then
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
    
    if not HasAdminPermission(source, 'command.tp') then
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
    
    if not HasAdminPermission(source, 'command.bring') then
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
    
    if not HasAdminPermission(source, 'command.heal') then
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
    
    if not HasAdminPermission(source, 'command.revive') then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    local targetId = tonumber(args[1]) or source
    
    TriggerClientEvent('vCore:revive', targetId)
    vCore.Notify(source, Lang('admin_player_revived'), 'success')
end, false)

-- /kick - Expulser un joueur
RegisterCommand('kick', function(source, args, rawCommand)
    if source > 0 and not HasAdminPermission(source, 'command.kick') then
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
    
    if not HasAdminPermission(source, 'command.car') then
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
    
    if not HasAdminPermission(source, 'command.dv') then
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
    if source > 0 and not HasAdminPermission(source, 'command.refresh') then
        vCore.Notify(source, Lang('admin_no_permission'), 'error')
        return
    end
    
    vCore.Cache.Items.Load()
    vCore.Cache.Jobs.Load()
    
    local msg = 'Caches rechargés'
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES FIVEM NATIVES (Compatibilité)
-- ═══════════════════════════════════════════════════════════════════════════

-- /tpm - Téléportation au marker
RegisterCommand('tpm', function(source, args, rawCommand)
    if source <= 0 then return end
    
    if not HasAdminPermission(source, 'command.tpm') then
        vCore.Notify(source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    TriggerClientEvent('vCore:teleportToMarker', source)
    vCore.Notify(source, 'Téléportation au marker...', 'success')
end, false)

-- /goto - TP vers un joueur
RegisterCommand('goto', function(source, args, rawCommand)
    if source <= 0 then return end
    
    if not HasAdminPermission(source, 'command.goto') then
        vCore.Notify(source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /goto [id]', 'info')
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        vCore.Notify(source, 'ID invalide', 'error')
        return
    end
    
    local targetPed = GetPlayerPed(targetId)
    if not DoesEntityExist(targetPed) then
        vCore.Notify(source, 'Joueur introuvable', 'error')
        return
    end
    
    local coords = GetEntityCoords(targetPed)
    TriggerClientEvent('vCore:teleport', source, coords.x, coords.y, coords.z)
    vCore.Notify(source, 'Téléporté vers #' .. targetId, 'success')
end, false)

-- /freeze - Geler un joueur
RegisterCommand('freeze', function(source, args, rawCommand)
    if source <= 0 then return end
    
    if not HasAdminPermission(source, 'command.freeze') then
        vCore.Notify(source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /freeze [id]', 'info')
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        vCore.Notify(source, 'ID invalide', 'error')
        return
    end
    
    TriggerClientEvent('vCore:freeze', targetId, true)
    vCore.Notify(source, 'Joueur #' .. targetId .. ' gelé', 'success')
    
    -- Log
    local adminName = GetPlayerName(source)
    vCore.Log('admin', 'admin:' .. adminName, 'Freeze: #' .. targetId, {})
end, false)

-- /unfreeze - Dégeler un joueur
RegisterCommand('unfreeze', function(source, args, rawCommand)
    if source <= 0 then return end
    
    if not HasAdminPermission(source, 'command.unfreeze') then
        vCore.Notify(source, 'Vous n\'avez pas la permission', 'error')
        return
    end
    
    if #args < 1 then
        vCore.Notify(source, 'Usage: /unfreeze [id]', 'info')
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        vCore.Notify(source, 'ID invalide', 'error')
        return
    end
    
    TriggerClientEvent('vCore:freeze', targetId, false)
    vCore.Notify(source, 'Joueur #' .. targetId .. ' dégelé', 'success')
end, false)

-- /weather - Changer la météo
RegisterCommand('weather', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.weather') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 1 then
        local msg = 'Usage: /weather [clear/extrasunny/clouds/overcast/rain/thunder/foggy/snow]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local weather = args[1]
    TriggerClientEvent('vCore:setWeather', -1, weather)
    
    local msg = 'Météo changée: ' .. weather
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
end, false)

-- /time - Changer l'heure
RegisterCommand('time', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.time') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 2 then
        local msg = 'Usage: /time [heure] [minute]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local hour = tonumber(args[1]) or 12
    local minute = tonumber(args[2]) or 0
    
    TriggerClientEvent('vCore:setTime', -1, hour, minute)
    
    local msg = string.format('Heure changée: %02d:%02d', hour, minute)
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
end, false)

-- /setmoney - Modifier l'argent d'un joueur
RegisterCommand('setmoney', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.setmoney') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 3 then
        local msg = 'Usage: /setmoney [id] [cash/bank/black] [montant]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local moneyType = args[2]
    local amount = tonumber(args[3])
    
    if not targetId or not amount then
        local msg = 'Arguments invalides'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    local player = vCore.GetPlayer(targetId)
    if not player then
        local msg = 'Joueur introuvable'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    player:SetMoney(moneyType, amount)
    
    local msg = string.format('Argent défini: %s = %d$ pour #%d', moneyType, amount, targetId)
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
    
    -- Log
    local adminName = source > 0 and GetPlayerName(source) or 'Console'
    vCore.Log('admin', 'admin:' .. adminName, 'SetMoney: #' .. targetId, {type = moneyType, amount = amount})
end, false)

-- /setgroup - Changer le groupe d'un joueur
RegisterCommand('setgroup', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.setgroup') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 2 then
        local msg = 'Usage: /setgroup [id] [user/helper/mod/admin/superadmin/developer/owner]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local group = args[2]
    
    if not targetId then
        local msg = 'ID invalide'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    local player = vCore.GetPlayer(targetId)
    if not player then
        local msg = 'Joueur introuvable'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    player:SetGroup(group)
    
    local msg = string.format('Groupe changé: #%d → %s', targetId, group)
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
    
    -- Log
    local adminName = source > 0 and GetPlayerName(source) or 'Console'
    vCore.Log('admin', 'admin:' .. adminName, 'SetGroup: #' .. targetId, {group = group})
end, false)

-- /ban - Bannir un joueur
RegisterCommand('ban', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.ban') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 2 then
        local msg = 'Usage: /ban [id] [durée: 1h/24h/7d/perm] [raison]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    local duration = args[2]
    local reason = table.concat(args, ' ', 3) or 'Aucune raison'
    
    if not targetId then
        local msg = 'ID invalide'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    local identifier = vCore.Players.GetIdentifier(targetId)
    if not identifier then
        local msg = 'Joueur introuvable'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    -- Calculer expiration
    local expireAt = nil
    if duration ~= 'perm' then
        local multipliers = {
            h = 3600,
            d = 86400,
            w = 604800
        }
        
        local time = tonumber(duration:match('%d+'))
        local unit = duration:match('%a+')
        
        if time and multipliers[unit] then
            expireAt = os.time() + (time * multipliers[unit])
        end
    end
    
    -- Créer le ban
    vCore.DB.Execute([[
        INSERT INTO bans (identifier, reason, banned_by, expire_at)
        VALUES (?, ?, ?, FROM_UNIXTIME(?))
    ]], {identifier, reason, source > 0 and GetPlayerName(source) or 'Console', expireAt})
    
    -- Kick le joueur
    DropPlayer(targetId, 'Vous avez été banni\\nRaison: ' .. reason .. '\\nDurée: ' .. duration)
    
    local msg = string.format('Joueur #%d banni (%s): %s', targetId, duration, reason)
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
    
    -- Log
    local adminName = source > 0 and GetPlayerName(source) or 'Console'
    vCore.Log('admin', 'admin:' .. adminName, 'Ban: #' .. targetId, {duration = duration, reason = reason})
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES SAUVEGARDE
-- ═══════════════════════════════════════════════════════════════════════════

-- /saveall - Sauvegarder tous les joueurs
RegisterCommand('saveall', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.saveall') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    local players = vCore.GetPlayers()
    local count = 0
    
    for id, player in pairs(players) do
        -- Mettre à jour position
        local ped = GetPlayerPed(id)
        if ped and DoesEntityExist(ped) then
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            player:SetPosition(coords.x, coords.y, coords.z, heading)
        end
        
        -- Sauvegarder
        if vCore.DB.SavePlayer(player) then
            count = count + 1
        end
    end
    
    local msg = string.format('Sauvegarde complète: %d/%d joueurs', count, vCore.GetPlayerCount())
    if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
    
    -- Log
    local adminName = source > 0 and GetPlayerName(source) or 'Console'
    vCore.Log('admin', 'admin:' .. adminName, 'SaveAll executed', {count = count})
end, false)

-- /saveplayer - Sauvegarder un joueur spécifique
RegisterCommand('saveplayer', function(source, args, rawCommand)
    if not HasAdminPermission(source, 'command.saveplayer') then
        if source > 0 then vCore.Notify(source, 'Vous n\'avez pas la permission', 'error') end
        return
    end
    
    if #args < 1 then
        local msg = 'Usage: /saveplayer [id]'
        if source > 0 then vCore.Notify(source, msg, 'info') else print(msg) end
        return
    end
    
    local targetId = tonumber(args[1])
    if not targetId then
        local msg = 'ID invalide'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    local player = vCore.GetPlayer(targetId)
    if not player then
        local msg = 'Joueur introuvable'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
        return
    end
    
    -- Mettre à jour position
    local ped = GetPlayerPed(targetId)
    if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        player:SetPosition(coords.x, coords.y, coords.z, heading)
    end
    
    -- Sauvegarder
    if vCore.DB.SavePlayer(player) then
        local msg = 'Joueur #' .. targetId .. ' sauvegardé'
        if source > 0 then vCore.Notify(source, msg, 'success') else print(msg) end
    else
        local msg = 'Échec de la sauvegarde'
        if source > 0 then vCore.Notify(source, msg, 'error') else print(msg) end
    end
end, false)

print('[vAvA_core] ^2✓^7 Commands loaded (User + Admin + FiveM Natives + Save)')
