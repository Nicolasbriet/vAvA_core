--[[
    vAvA_core - Server Players Management
    Gestion des joueurs côté serveur
]]

vCore = vCore or {}
vCore.Players = vCore.Players or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- IDENTIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

---Récupère l'identifiant principal d'un joueur
---@param source number
---@return string|nil
function vCore.Players.GetIdentifier(source)
    local identifierType = Config.Players.Identifiers.primary
    local identifiers = GetPlayerIdentifiers(source)
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, identifierType .. ':') then
            return identifier
        end
    end
    
    -- Fallback sur license
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'license:') then
            return identifier
        end
    end
    
    return nil
end

---Récupère tous les identifiants d'un joueur
---@param source number
---@return table
function vCore.Players.GetAllIdentifiers(source)
    local result = {
        license = nil,
        steam = nil,
        discord = nil,
        ip = nil
    }
    
    local identifiers = GetPlayerIdentifiers(source)
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'license:') then
            result.license = identifier
        elseif string.find(identifier, 'steam:') then
            result.steam = identifier
        elseif string.find(identifier, 'discord:') then
            result.discord = identifier
        elseif string.find(identifier, 'ip:') then
            result.ip = identifier
        end
    end
    
    return result
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONNEXION JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)
    
    deferrals.update(Lang('loading'))
    
    local identifier = vCore.Players.GetIdentifier(source)
    
    if not identifier then
        deferrals.done('Identifiant introuvable. Veuillez redémarrer votre jeu.')
        return
    end
    
    -- Vérifier le ban
    local ban = vCore.DB.GetBan(identifier)
    if ban then
        local reason = ban.reason or 'Aucune raison spécifiée'
        local expireAt = ban.expire_at
        
        if expireAt then
            deferrals.done(Lang('security_banned') .. '\n' .. Lang('security_ban_reason', reason) .. '\n' .. Lang('security_ban_expire', expireAt))
        else
            deferrals.done(Lang('security_banned') .. '\n' .. Lang('security_ban_reason', reason) .. '\n' .. Lang('security_ban_permanent'))
        end
        return
    end
    
    -- Créer ou mettre à jour l'utilisateur
    local identifiers = vCore.Players.GetAllIdentifiers(source)
    local user = vCore.DB.GetUserByIdentifier(identifier)
    
    if not user then
        -- Nouveau joueur
        vCore.DB.Execute([[
            INSERT INTO users (identifier, license, steam, discord, name)
            VALUES (?, ?, ?, ?, ?)
        ]], {identifier, identifiers.license, identifiers.steam, identifiers.discord, name})
        
        vCore.Utils.Print('Nouveau joueur:', name, '(' .. identifier .. ')')
    else
        -- Joueur existant - mettre à jour last_seen
        vCore.DB.Execute('UPDATE users SET name = ?, last_seen = NOW() WHERE identifier = ?', {name, identifier})
    end
    
    deferrals.done()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:loadPlayer', function(charId)
    local source = source
    local identifier = vCore.Players.GetIdentifier(source)
    
    print('[vCore] Loading player - Source:', source, 'CharID:', charId, 'Identifier:', identifier)
    
    if not identifier then
        print('[vCore] ERROR: No identifier found for source:', source)
        DropPlayer(source, 'Identifiant introuvable')
        return
    end
    
    -- Charger le personnage
    local charData = vCore.DB.GetCharacter(charId)
    
    if not charData then
        print('[vCore] ERROR: Character not found with ID:', charId)
        vCore.Notify(source, Lang('player_not_found'), 'error')
        return
    end
    
    print('[vCore] Character found:', charData.firstname, charData.lastname)
    
    -- Vérifier que le personnage appartient au joueur
    if charData.identifier ~= identifier then
        print('[vCore] ERROR: Character ownership mismatch -', charData.identifier, '!=', identifier)
        vCore.Utils.Warn('Tentative de chargement de personnage non autorisé:', source, charId)
        return
    end
    
    -- Récupérer les données utilisateur
    local userData = vCore.DB.GetUserByIdentifier(identifier)
    
    -- Préparer le metadata en incluant le skin
    local metadata = json.decode(charData.metadata or '{}')
    if charData.skin_data then
        metadata.skin = json.decode(charData.skin_data)
    end
    
    -- Créer l'objet joueur
    local player = vCore.Classes.CreatePlayer({
        source = source,
        identifier = identifier,
        name = GetPlayerName(source),
        charId = charData.id,
        firstName = charData.firstname,
        lastName = charData.lastname,
        dob = charData.dob,
        gender = charData.gender,
        money = json.decode(charData.money or '{}'),
        job = json.decode(charData.job or '{}'),
        gang = json.decode(charData.gang or '{}'),
        position = json.decode(charData.position or '{}'),
        status = json.decode(charData.status or '{}'),
        inventory = json.decode(charData.inventory or '[]'),
        metadata = metadata,
        group = userData and userData.group or 'user'
    })
    
    -- Reconstruire le job complet depuis la config
    local jobName = player.job.name or Config.Jobs.DefaultJob
    local jobGrade = player.job.grade or Config.Jobs.DefaultGrade
    local jobConfig = Config.Jobs.List[jobName]
    
    if jobConfig and jobConfig.grades[jobGrade] then
        player.job = {
            name = jobName,
            label = jobConfig.label,
            grade = jobGrade,
            gradeLabel = jobConfig.grades[jobGrade].label,
            salary = jobConfig.grades[jobGrade].salary,
            permissions = jobConfig.grades[jobGrade].permissions or {}
        }
    end
    
    -- Ajouter au cache
    vCore.Cache.Players.Set(source, player)
    
    print('[vCore] Player added to cache - Source:', source)
    print('[vCore] Cache verification:', vCore.Cache.Players.Get(source) ~= nil)
    print('[vCore] Player position:', json.encode(player.position))
    
    -- Envoyer les données au client
    TriggerClientEvent('vCore:playerLoaded', source, player:ToClientData())
    
    -- Envoyer l'intervalle de sauvegarde
    if Config.Players.AutoSave.enabled then
        TriggerClientEvent('vCore:setSaveInterval', source, Config.Players.AutoSave.interval)
    end
    
    -- Déclencher l'événement de chargement
    TriggerEvent(vCore.Events.PLAYER_LOADED, source, player)
    
    vCore.Utils.Print('Joueur chargé:', player:GetName(), '(#' .. source .. ')')
    
    -- Log
    vCore.Log('info', identifier, 'Joueur connecté: ' .. player:GetName())
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉCONNEXION JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function(reason)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    -- Sauvegarder à la déconnexion si activé
    if Config.Players.AutoSave.saveOnDisconnect then
        -- Note: On ne met PAS à jour la position ici car le ped n'existe déjà plus
        -- La dernière position a été sauvegardée par l'auto-save ou manuellement
        
        -- Sauvegarder
        local success = vCore.DB.SavePlayer(player)
        
        if Config.Players.AutoSave.debug then
            if success then
                print('^2[vCore]^7 Sauvegarde réussie au disconnect:', player:GetName())
            else
                print('^1[vCore]^7 Échec sauvegarde au disconnect:', player:GetName())
            end
        end
    end
    
    -- Log
    vCore.Log('info', player:GetIdentifier(), 'Joueur déconnecté: ' .. player:GetName() .. ' (' .. reason .. ')')
    
    -- Retirer du cache
    vCore.Cache.Players.Delete(source)
    
    -- Déclencher l'événement
    TriggerEvent(vCore.Events.PLAYER_DROPPED, source, player, reason)
    
    vCore.Utils.Print('Joueur déconnecté:', player:GetName(), '-', reason)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SAUVEGARDE MANUELLE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:savePlayer', function()
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    -- Mettre à jour la position actuelle
    local ped = GetPlayerPed(source)
    if ped and ped ~= 0 and DoesEntityExist(ped) and Config.Players.AutoSave.savePosition then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        if coords and heading then
            player:SetPosition(coords.x, coords.y, coords.z, heading)
        end
    end
    
    -- Sauvegarder
    local success = vCore.DB.SavePlayer(player)
    
    if success then
        TriggerEvent(vCore.Events.PLAYER_SAVED, source, player)
        
        if Config.Players.AutoSave.debug then
            print('^2[vAvA_core]^7 Sauvegarde complète: ' .. player:GetName())
        end
    else
        if Config.Players.AutoSave.debug then
            print('^1[vAvA_core]^7 Échec sauvegarde: ' .. player:GetName())
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGOUT (CHANGEMENT DE PERSONNAGE)
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:logoutPlayer', function()
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    print('[vCore] Player logout:', player:GetName())
    
    -- Sauvegarder avant de logout
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        player:SetPosition(coords.x, coords.y, coords.z, heading)
    end
    
    local success = vCore.DB.SavePlayer(player)
    
    if success then
        print('[vCore] Character saved before logout')
    end
    
    -- Retirer du cache (décharge le personnage)
    vCore.Cache.Players.Delete(source)
    
    -- Réinitialiser les données client
    TriggerClientEvent('vCore:playerLogout', source)
    
    -- Rediriger vers la sélection de personnage
    Wait(500)
    TriggerClientEvent('vava_creator:openSelection', source)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SAUVEGARDE AUTOMATIQUE PÉRIODIQUE
-- ═══════════════════════════════════════════════════════════════════════════

if Config.Players.AutoSave.enabled then
    print(string.format('^2[vCore]^7 Sauvegarde automatique activée (intervalle: %d secondes)', Config.Players.AutoSave.interval))
    
    CreateThread(function()
        while true do
            Wait(Config.Players.AutoSave.interval * 1000)
            
            if Config.Players.AutoSave.debug then
                print('^3[vCore]^7 Démarrage de la sauvegarde automatique...')
            end
            
            local players = vCore.Cache.Players.GetAll()
            local count = 0
            
            for source, player in pairs(players) do
                if player and player.PlayerData then
                    -- Mettre à jour la position actuelle
                    local ped = GetPlayerPed(source)
                    if ped and ped ~= 0 and DoesEntityExist(ped) then
                        local coords = GetEntityCoords(ped)
                        local heading = GetEntityHeading(ped)
                        if coords and heading then
                            player:SetPosition(coords.x, coords.y, coords.z, heading)
                        end
                    end
                    
                    -- Sauvegarder toutes les données
                    local success = vCore.DB.SavePlayer(player)
                    
                    if success then
                        count = count + 1
                        -- Notifier le joueur
                        vCore.Notify(source, 'Progression sauvegardée', 'success')
                        
                        -- Log détaillé
                        if Config.Players.AutoSave.debug then
                            local pos = player.PlayerData.position
                            print(string.format('^2[vCore]^7 ✓ Sauvegarde: %s | Position: %.1f, %.1f, %.1f', 
                                player:GetName(), 
                                pos.x or 0, pos.y or 0, pos.z or 0
                            ))
                        end
                    end
                end
            end
            
            if Config.Players.AutoSave.debug and count > 0 then
                print(string.format('^2[vCore]^7 ✓ Auto-save: %d joueur(s) sauvegardé(s)', count))
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR POSITION
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:updatePosition', function(coords, heading)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if player and Config.Players.AutoSave.savePosition then
        player:SetPosition(coords.x, coords.y, coords.z, heading)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR STATUS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:updateStatus', function(status)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if player then
        for statusType, value in pairs(status) do
            player.status[statusType] = value
        end
    end
end)
