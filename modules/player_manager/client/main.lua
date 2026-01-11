--[[
    vAvA_player_manager - Client Main
    Logique principale client
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = PlayerManagerConfig
local CurrentCharacter = nil
local IsInSelector = false

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while vCore == nil do
        Wait(100)
    end
    
    -- Charger traductions
    LoadLocale()
end)

function LoadLocale()
    local locale = GetConvar('vava_locale', 'fr')
    local localeFile = 'locales/' .. locale .. '.lua'
    
    if LoadResourceFile(GetCurrentResourceName(), localeFile) then
        Locales = require('locales.' .. locale)
    else
        Locales = require('locales.fr')  -- Fallback FR
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:CharacterLoaded', function(character)
    CurrentCharacter = character
    
    -- Spawn personnage
    local spawn = PMConfig.General.DefaultSpawn
    SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z)
    SetEntityHeading(PlayerPedId(), spawn.w)
    
    -- Charger apparence si existe
    vCore.TriggerCallback('vAvA_player_manager:server:GetAppearance', function(appearance)
        if appearance and appearance.skin then
            local skinData = json.decode(appearance.skin)
            -- Appliquer apparence (nécessite module appearance)
            TriggerEvent('vAvA_appearance:client:LoadSkin', skinData)
        end
    end, character.citizenid)
    
    -- Notifications de bienvenue
    Wait(1000)
    TriggerEvent('vAvA:Notify', Locales['character_selected']:format(character.firstname, character.lastname), 'success')
    
    -- Charger stats
    LoadPlayerStats()
end)

RegisterNetEvent('vAvA_player_manager:client:RefreshCharacters', function()
    if IsInSelector then
        TriggerEvent('vAvA_player_manager:client:OpenSelector')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- STATS
-- ═══════════════════════════════════════════════════════════════════════════

function LoadPlayerStats()
    if not CurrentCharacter then return end
    
    vCore.TriggerCallback('vAvA_player_manager:server:GetStats', function(stats)
        if stats then
            -- Afficher stats dans HUD si module HUD existe
            TriggerEvent('vAvA_hud:client:UpdateStats', stats)
        end
    end, CurrentCharacter.citizenid)
end

-- Thread mise à jour stats
if PMConfig.Stats.TrackPlaytime then
    CreateThread(function()
        while true do
            Wait(60000)  -- Chaque minute
            
            if CurrentCharacter then
                -- Le serveur gère la mise à jour
                TriggerServerEvent('vAvA_player_manager:server:UpdatePlaytime', 60)
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MORT
-- ═══════════════════════════════════════════════════════════════════════════

if PMConfig.Stats.TrackDeaths then
    CreateThread(function()
        local wasDead = false
        
        while true do
            Wait(1000)
            
            local ped = PlayerPedId()
            local isDead = IsEntityDead(ped)
            
            if isDead and not wasDead then
                TriggerServerEvent('vAvA_player_manager:server:AddDeath')
                wasDead = true
            elseif not isDead and wasDead then
                wasDead = false
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('characters', function()
    TriggerEvent('vAvA_player_manager:client:OpenSelector')
end, false)

RegisterCommand('showid', function(source, args)
    local targetId = tonumber(args[1])
    
    if not targetId then
        -- Chercher joueur le plus proche
        local players, closestDistance, closestPlayer = vCore.GetPlayersFromCoords(), 3.0, -1
        local coords = GetEntityCoords(PlayerPedId())
        
        for _, player in ipairs(players) do
            local target = GetPlayerFromServerId(player)
            local targetPed = GetPlayerPed(target)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)
            
            if distance < closestDistance then
                closestPlayer = player
                closestDistance = distance
            end
        end
        
        if closestPlayer ~= -1 then
            targetId = closestPlayer
        else
            return TriggerEvent('vAvA:Notify', 'Aucun joueur à proximité', 'error')
        end
    end
    
    TriggerServerEvent('vAvA_player_manager:server:ShowID', targetId)
end, false)

RegisterCommand('showlicenses', function()
    TriggerEvent('vAvA_player_manager:client:ShowLicenses')
end, false)

RegisterCommand('stats', function()
    TriggerEvent('vAvA_player_manager:client:ShowStats')
end, false)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetCurrentCharacter', function()
    return CurrentCharacter
end)

exports('IsInSelector', function()
    return IsInSelector
end)

exports('SetInSelector', function(state)
    IsInSelector = state
end)
