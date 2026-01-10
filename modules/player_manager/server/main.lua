--[[
    vAvA_player_manager - Server Main
    Logique principale serveur
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = require 'config'

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIABLES
-- ═══════════════════════════════════════════════════════════════════════════

local ActivePlayers = {}  -- Joueurs actuellement connectés

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:LoadCharacter', function(citizenId)
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    
    if not license then
        return TriggerClientEvent('vAvA:Notify', src, 'Erreur: Licence introuvable', 'error')
    end
    
    -- Récupérer personnage
    exports['vAvA_player_manager']:GetCharacter(citizenId, function(character)
        if not character then
            return TriggerClientEvent('vAvA:Notify', src, 'Personnage introuvable', 'error')
        end
        
        -- Vérifier que le personnage appartient au joueur
        if character.license ~= license then
            return TriggerClientEvent('vAvA:Notify', src, 'Accès refusé', 'error')
        end
        
        -- Charger dans vCore
        vCore.LoadPlayer(src, citizenId)
        
        -- Marquer comme actif
        ActivePlayers[src] = {
            citizenid = citizenId,
            connectedAt = os.time()
        }
        
        -- Logger historique
        exports['vAvA_player_manager']:AddHistory(citizenId, 'character_login', 'Connexion au personnage', nil, nil, nil)
        
        -- Notifier client
        TriggerClientEvent('vAvA_player_manager:client:CharacterLoaded', src, character)
        TriggerClientEvent('vAvA:Notify', src, string.format(PMConfig.Notifications.CharacterSelected, character.firstname, character.lastname), 'success')
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATION PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:CreateCharacter', function(data)
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    
    if not license then
        return TriggerClientEvent('vAvA:Notify', src, 'Erreur: Licence introuvable', 'error')
    end
    
    -- Vérifier limite personnages
    exports['vAvA_player_manager']:GetCharacterCount(license, function(count)
        if count >= PMConfig.General.MaxCharacters then
            return TriggerClientEvent('vAvA:Notify', src, 'Limite de personnages atteinte', 'error')
        end
        
        -- Générer CitizenID
        local citizenId = exports['vAvA_player_manager']:GenerateCitizenId()
        
        -- Créer personnage
        exports['vAvA_player_manager']:CreateCharacter({
            citizenid = citizenId,
            license = license,
            firstname = data.firstname,
            lastname = data.lastname,
            dateofbirth = data.dateofbirth,
            sex = data.sex,
            nationality = data.nationality or PMConfig.Creation.DefaultNationality,
            money_cash = PMConfig.General.DefaultMoney.cash,
            money_bank = PMConfig.General.DefaultMoney.bank
        }, function(success)
            if success then
                -- Créer statistiques
                exports['vAvA_player_manager']:InitializeStats(citizenId)
                
                -- Créer histoire si activé
                if PMConfig.Creation.StoryMode and data.story then
                    exports['vAvA_player_manager']:SaveStory(citizenId, data.story)
                end
                
                TriggerClientEvent('vAvA:Notify', src, PMConfig.Notifications.CharacterCreated, 'success')
                TriggerClientEvent('vAvA_player_manager:client:RefreshCharacters', src)
            else
                TriggerClientEvent('vAvA:Notify', src, 'Erreur lors de la création', 'error')
            end
        end)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- SUPPRESSION PERSONNAGE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:server:DeleteCharacter', function(citizenId)
    local src = source
    local license = GetPlayerIdentifierByType(src, 'license')
    
    -- Vérifier propriété
    exports['vAvA_player_manager']:GetCharacter(citizenId, function(character)
        if not character or character.license ~= license then
            return TriggerClientEvent('vAvA:Notify', src, 'Accès refusé', 'error')
        end
        
        -- Supprimer
        exports['vAvA_player_manager']:DeleteCharacter(citizenId, function(success)
            if success then
                TriggerClientEvent('vAvA:Notify', src, PMConfig.Notifications.CharacterDeleted, 'success')
                TriggerClientEvent('vAvA_player_manager:client:RefreshCharacters', src)
            else
                TriggerClientEvent('vAvA:Notify', src, 'Erreur lors de la suppression', 'error')
            end
        end)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉCONNEXION
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('playerDropped', function(reason)
    local src = source
    
    if ActivePlayers[src] then
        local citizenId = ActivePlayers[src].citizenid
        local sessionTime = os.time() - ActivePlayers[src].connectedAt
        
        -- Mettre à jour temps de jeu
        exports['vAvA_player_manager']:UpdatePlaytime(citizenId, sessionTime)
        
        -- Logger
        exports['vAvA_player_manager']:AddHistory(citizenId, 'character_logout', 'Déconnexion', nil, nil, nil)
        
        ActivePlayers[src] = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.CreateCallback('vAvA_player_manager:server:GetCharacters', function(source, cb)
    local license = GetPlayerIdentifierByType(source, 'license')
    
    if not license then
        return cb({})
    end
    
    exports['vAvA_player_manager']:GetCharacters(license, function(characters)
        cb(characters or {})
    end)
end)

vCore.CreateCallback('vAvA_player_manager:server:GetCharacter', function(source, cb, citizenId)
    exports['vAvA_player_manager']:GetCharacter(citizenId, function(character)
        cb(character)
    end)
end)

vCore.CreateCallback('vAvA_player_manager:server:GetStats', function(source, cb, citizenId)
    exports['vAvA_player_manager']:GetStats(citizenId, function(stats)
        cb(stats)
    end)
end)

vCore.CreateCallback('vAvA_player_manager:server:GetHistory', function(source, cb, citizenId, limit)
    exports['vAvA_player_manager']:GetHistory(citizenId, limit or 50, function(history)
        cb(history)
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES ADMIN
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('deletechar', function(source, args, rawCommand)
    if source == 0 then
        print('[vAvA_player_manager] Cette commande doit être exécutée depuis la console')
        return
    end
    
    local player = vCore.GetPlayer(source)
    if not player or not player.IsAdmin() then
        return TriggerClientEvent('vAvA:Notify', source, 'Accès refusé', 'error')
    end
    
    if not args[1] then
        return TriggerClientEvent('vAvA:Notify', source, 'Usage: /deletechar [citizenid]', 'error')
    end
    
    exports['vAvA_player_manager']:DeleteCharacter(args[1], function(success)
        if success then
            TriggerClientEvent('vAvA:Notify', source, 'Personnage supprimé', 'success')
        else
            TriggerClientEvent('vAvA:Notify', source, 'Erreur', 'error')
        end
    end)
end, false)

RegisterCommand('resetchar', function(source, args, rawCommand)
    if source == 0 then
        print('[vAvA_player_manager] Cette commande doit être exécutée depuis la console')
        return
    end
    
    local player = vCore.GetPlayer(source)
    if not player or not player.IsAdmin() then
        return TriggerClientEvent('vAvA:Notify', source, 'Accès refusé', 'error')
    end
    
    if not args[1] then
        return TriggerClientEvent('vAvA:Notify', source, 'Usage: /resetchar [citizenid]', 'error')
    end
    
    exports['vAvA_player_manager']:ResetCharacter(args[1], function(success)
        if success then
            TriggerClientEvent('vAvA:Notify', source, 'Personnage réinitialisé', 'success')
        else
            TriggerClientEvent('vAvA:Notify', source, 'Erreur', 'error')
        end
    end)
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetActivePlayerCount', function()
    local count = 0
    for _ in pairs(ActivePlayers) do
        count = count + 1
    end
    return count
end)

exports('IsPlayerActive', function(source)
    return ActivePlayers[source] ~= nil
end)

exports('GetActivePlayers', function()
    return ActivePlayers
end)
