--[[
    vAvA_player_manager - Client History
    Affichage historique
]]

local vCore = exports['vAvA_core']:GetCoreObject()
local PMConfig = require 'config'

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHER HISTORIQUE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_player_manager:client:ShowHistory', function()
    local player = vCore.GetPlayerData()
    
    if not player then return end
    
    vCore.TriggerCallback('vAvA_player_manager:server:GetHistory', function(history)
        if not history then
            return TriggerEvent('vAvA:Notify', 'Historique introuvable', 'error')
        end
        
        -- Formater historique
        local formattedHistory = FormatHistory(history)
        
        -- Ouvrir interface NUI
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'showHistory',
            history = formattedHistory,
            eventTypes = PMConfig.History.EventTypes
        })
    end, player.citizenid, 50)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FORMATER HISTORIQUE
-- ═══════════════════════════════════════════════════════════════════════════

function FormatHistory(history)
    local formatted = {}
    
    for _, event in ipairs(history) do
        table.insert(formatted, {
            id = event.id,
            type = event.event_type,
            typeLabel = GetEventTypeLabel(event.event_type),
            description = event.event_description,
            amount = event.amount and string.format('$%s', FormatMoney(event.amount)) or nil,
            relatedPlayer = event.related_player,
            date = FormatDate(event.created_at),
            icon = GetEventTypeIcon(event.event_type)
        })
    end
    
    return formatted
end

function GetEventTypeLabel(eventType)
    local labels = {
        character_login = 'Connexion',
        character_logout = 'Déconnexion',
        job_change = 'Changement emploi',
        name_change = 'Changement nom',
        bank_deposit = 'Dépôt banque',
        bank_withdraw = 'Retrait banque',
        bank_transfer = 'Virement',
        property_buy = 'Achat propriété',
        property_sell = 'Vente propriété',
        vehicle_buy = 'Achat véhicule',
        vehicle_sell = 'Vente véhicule',
        arrest = 'Arrestation',
        fine = 'Amende',
        jail = 'Prison',
        death = 'Mort',
        revive = 'Réanimation',
        license_obtained = 'Licence obtenue',
        license_revoked = 'Licence révoquée',
        license_suspended = 'Licence suspendue'
    }
    
    return labels[eventType] or eventType
end

function GetEventTypeIcon(eventType)
    local icons = {
        character_login = '🟢',
        character_logout = '🔴',
        job_change = '💼',
        name_change = '✏️',
        bank_deposit = '💰',
        bank_withdraw = '💸',
        bank_transfer = '🔄',
        property_buy = '🏠',
        property_sell = '🏚️',
        vehicle_buy = '🚗',
        vehicle_sell = '🔧',
        arrest = '👮',
        fine = '💵',
        jail = '🔒',
        death = '💀',
        revive = '💚',
        license_obtained = '📜',
        license_revoked = '❌',
        license_suspended = '⏸️'
    }
    
    return icons[eventType] or '📋'
end

function FormatDate(dateString)
    -- Format: "YYYY-MM-DD HH:MM:SS"
    local year = string.sub(dateString, 1, 4)
    local month = string.sub(dateString, 6, 7)
    local day = string.sub(dateString, 9, 10)
    local hour = string.sub(dateString, 12, 13)
    local minute = string.sub(dateString, 15, 16)
    
    return string.format('%s/%s/%s %s:%s', day, month, year, hour, minute)
end

function FormatMoney(amount)
    local formatted = tostring(amount)
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

RegisterNUICallback('closeHistory', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('loadMoreHistory', function(data, cb)
    local player = vCore.GetPlayerData()
    
    if not player then
        cb({})
        return
    end
    
    vCore.TriggerCallback('vAvA_player_manager:server:GetHistory', function(history)
        local formattedHistory = FormatHistory(history)
        cb(formattedHistory)
    end, player.citizenid, data.limit or 50)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowHistory', function()
    TriggerEvent('vAvA_player_manager:client:ShowHistory')
end)
