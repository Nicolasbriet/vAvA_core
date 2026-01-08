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
    
    if not identifier then
        DropPlayer(source, 'Identifiant introuvable')
        return
    end
    
    -- Charger le personnage
    local charData = vCore.DB.GetCharacter(charId)
    
    if not charData then
        vCore.Notify(source, Lang('player_not_found'), 'error')
        return
    end
    
    -- Vérifier que le personnage appartient au joueur
    if charData.identifier ~= identifier then
        vCore.Utils.Warn('Tentative de chargement de personnage non autorisé:', source, charId)
        return
    end
    
    -- Récupérer les données utilisateur
    local userData = vCore.DB.GetUserByIdentifier(identifier)
    
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
        metadata = json.decode(charData.metadata or '{}'),
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
    
    -- Envoyer les données au client
    TriggerClientEvent('vCore:playerLoaded', source, player:ToClientData())
    
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
    
    -- Mettre à jour la position avant sauvegarde
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        player:SetPosition(coords.x, coords.y, coords.z, heading)
    end
    
    -- Sauvegarder
    vCore.DB.SavePlayer(player)
    
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
    
    -- Mettre à jour la position
    local ped = GetPlayerPed(source)
    if ped and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        player:SetPosition(coords.x, coords.y, coords.z, heading)
    end
    
    if vCore.DB.SavePlayer(player) then
        TriggerEvent(vCore.Events.PLAYER_SAVED, source, player)
        vCore.Utils.Debug('Joueur sauvegardé:', player:GetName())
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR POSITION
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:updatePosition', function(coords, heading)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if player then
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
