-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Economy Client
-- Gestion côté client du système économique
-- ══════════════════════════════════════════════════════════════════════════════

-- Attendre que vCore soit disponible
local vCore = nil
CreateThread(function()
    while not vCore do
        vCore = exports['vAvA_core']:GetCoreObject()
        if not vCore then 
            Wait(100) 
        end
    end
end)

local adminUIOpen = false

-- ══════════════════════════════════════════════════════════════════════════════
-- Ouvrir l'interface admin
-- ══════════════════════════════════════════════════════════════════════════════

function OpenAdminUI()
    if adminUIOpen then return end
    
    -- Demander les données au serveur
    vCore.TriggerCallback('vAvA_economy:getState', function(state)
        vCore.TriggerCallback('vAvA_economy:getAllItems', function(items)
            vCore.TriggerCallback('vAvA_economy:getAllJobs', function(jobs)
                vCore.TriggerCallback('vAvA_economy:getLogs', function(logs)
                    -- Envoyer tout à la NUI
                    SendNUIMessage({
                        action = 'openDashboard',
                        state = state,
                        items = items,
                        jobs = jobs,
                        logs = logs
                    })
                    
                    SetNuiFocus(true, true)
                    adminUIOpen = true
                end)
            end)
        end)
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Fermer l'interface admin
-- ══════════════════════════════════════════════════════════════════════════════

function CloseAdminUI()
    if not adminUIOpen then return end
    
    SendNUIMessage({
        action = 'closeDashboard'
    })
    
    -- D\u00e9lai pour \u00e9viter le freeze
    SetTimeout(100, function()
        SetNuiFocus(false, false)
    end)
    
    adminUIOpen = false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- Commande admin
-- ══════════════════════════════════════════════════════════════════════════════

RegisterCommand('economy', function()
    OpenAdminUI()
end, false)

-- ══════════════════════════════════════════════════════════════════════════════
-- NUI Callbacks
-- ══════════════════════════════════════════════════════════════════════════════

-- Fermer l'UI
RegisterNUICallback('close', function(data, cb)
    CloseAdminUI()
    cb({success = true})
end)

-- Recalculer l'économie
RegisterNUICallback('recalculate', function(data, cb)
    TriggerServerEvent('vAvA_economy:recalculate')
    cb({success = true})
end)

-- Changer le multiplicateur global
RegisterNUICallback('setMultiplier', function(data, cb)
    TriggerServerEvent('vAvA_economy:setMultiplier', data.multiplier)
    cb({success = true})
end)

-- Modifier le prix d'un item
RegisterNUICallback('updateItemPrice', function(data, cb)
    TriggerServerEvent('vAvA_economy:updateItemPrice', data.itemName, data.newPrice)
    cb({success = true})
end)

-- Modifier le salaire d'un job
RegisterNUICallback('updateJobSalary', function(data, cb)
    TriggerServerEvent('vAvA_economy:updateJobSalary', data.jobName, data.newSalary)
    cb({success = true})
end)

-- Modifier une taxe
RegisterNUICallback('updateTax', function(data, cb)
    TriggerServerEvent('vAvA_economy:updateTax', data.taxType, data.newRate)
    cb({success = true})
end)

-- Réinitialiser l'économie
RegisterNUICallback('resetEconomy', function(data, cb)
    TriggerServerEvent('vAvA_economy:reset')
    cb({success = true})
end)

-- Rafraîchir les données
RegisterNUICallback('refresh', function(data, cb)
    cb({success = true})
    SetTimeout(100, function()
        vCore.TriggerCallback('vAvA_economy:getState', function(state)
            SendNUIMessage({
                action = 'refreshData',
                state = state
            })
        end)
    end)
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- Touche pour ouvrir l'interface (F10 par défaut, admin only)
-- ══════════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(0)
        
        if IsControlJustPressed(0, 57) then -- F10
            if not adminUIOpen then
                OpenAdminUI()
            end
        end
        
        if IsControlJustPressed(0, 322) then -- ESC
            if adminUIOpen then
                CloseAdminUI()
            end
        end
    end
end)
