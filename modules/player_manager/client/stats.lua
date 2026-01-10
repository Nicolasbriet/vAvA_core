--[[
    vAvA_player_manager - Client Stats
    Affichage statistiques
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = require 'config'

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHER STATISTIQUES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:ShowStats', function()
    local player = vCore.GetPlayerData()
    
    if not player then return end
    
    vCore.TriggerCallback('vAvA_player_manager:server:GetStats', function(stats)
        if not stats then
            return TriggerEvent('vAvA:Notify', 'Statistiques introuvables', 'error')
        end
        
        -- Formater stats
        local formattedStats = FormatStats(stats)
        
        -- Ouvrir interface NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'showStats',
            stats = formattedStats,
            categories = PMConfig.Stats.Categories
        })
    end, player.citizenid)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FORMATER STATS
-- ═══════════════════════════════════════════════════════════════════════════

function FormatStats(stats)
    return {
        {
            name = 'playtime',
            label = 'Temps de jeu',
            value = math.floor((stats.playtime or 0) / 3600),  -- Heures
            unit = 'heures',
            icon = '⏱️'
        },
        {
            name = 'distance_walked',
            label = 'Distance à pied',
            value = string.format('%.2f', stats.distance_walked or 0),
            unit = 'km',
            icon = '🚶'
        },
        {
            name = 'distance_driven',
            label = 'Distance en véhicule',
            value = string.format('%.2f', stats.distance_driven or 0),
            unit = 'km',
            icon = '🚗'
        },
        {
            name = 'deaths',
            label = 'Nombre de morts',
            value = stats.deaths or 0,
            unit = '',
            icon = '💀'
        },
        {
            name = 'arrests',
            label = 'Arrestations',
            value = stats.arrests or 0,
            unit = '',
            icon = '👮'
        },
        {
            name = 'jobs_completed',
            label = 'Missions accomplies',
            value = stats.jobs_completed or 0,
            unit = '',
            icon = '💼'
        },
        {
            name = 'money_earned',
            label = 'Argent gagné',
            value = string.format('$%s', FormatMoney(stats.money_earned or 0)),
            unit = '',
            icon = '💰'
        },
        {
            name = 'money_spent',
            label = 'Argent dépensé',
            value = string.format('$%s', FormatMoney(stats.money_spent or 0)),
            unit = '',
            icon = '💸'
        }
    }
end

function FormatMoney(amount)
    local formatted = amount
    while true do  
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then
            break
        end
    end
    return formatted
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNUICallback('closeStats', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowStats', function()
    TriggerEvent('vAvA_player_manager:client:ShowStats')
end)
