--[[
    vava_loadingscreen - Client Script
    Gestion côté client du loading screen
    Version: 1.0.0
]]

local isLoadingScreenActive = true
local playerLoaded = false

-- ═══════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════

CreateThread(function()
    -- Attendre que le joueur soit chargé
    while not NetworkIsSessionStarted() do
        Wait(100)
    end
    
    -- Petit délai pour s'assurer que tout est chargé
    Wait(2000)
    
    -- Cacher le loading screen
    ShutdownLoadingScreenNui()
    isLoadingScreenActive = false
    playerLoaded = true
    
    -- Envoyer l'événement de fin de chargement
    TriggerEvent('vava_loadingscreen:loaded')
    TriggerServerEvent('vava_loadingscreen:playerLoaded')
end)

-- ═══════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════

-- Afficher le loading screen manuellement
exports('Show', function()
    if not isLoadingScreenActive then
        SendNUIMessage({
            type = 'show'
        })
        isLoadingScreenActive = true
    end
end)

-- Cacher le loading screen manuellement
exports('Hide', function()
    if isLoadingScreenActive then
        SendNUIMessage({
            type = 'hide'
        })
        ShutdownLoadingScreenNui()
        isLoadingScreenActive = false
    end
end)

-- Mettre à jour la progression
exports('UpdateProgress', function(progress)
    SendNUIMessage({
        type = 'updateProgress',
        progress = progress
    })
end)

-- Mettre à jour le module en cours de chargement
exports('UpdateLoadingModule', function(moduleName)
    SendNUIMessage({
        type = 'updateLoadingModule',
        module = moduleName
    })
end)

-- Définir la langue
exports('SetLocale', function(locale)
    SendNUIMessage({
        type = 'setLocale',
        locale = locale
    })
end)

-- Vérifier si le loading screen est actif
exports('IsActive', function()
    return isLoadingScreenActive
end)

-- Vérifier si le joueur est chargé
exports('IsPlayerLoaded', function()
    return playerLoaded
end)

-- ═══════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════

-- Événement pour cacher le loading screen depuis le serveur
RegisterNetEvent('vava_loadingscreen:hide', function()
    exports['vava_loadingscreen']:Hide()
end)

-- Événement pour mettre à jour la progression depuis le serveur
RegisterNetEvent('vava_loadingscreen:updateProgress', function(progress)
    exports['vava_loadingscreen']:UpdateProgress(progress)
end)

-- Événement pour mettre à jour le nombre de joueurs
RegisterNetEvent('vava_loadingscreen:updatePlayerCount', function(count)
    SendNUIMessage({
        type = 'updatePlayerCount',
        count = count
    })
end)

-- ═══════════════════════════════════════════════════════════════
-- CALLBACKS NUI
-- ═══════════════════════════════════════════════════════════════

RegisterNUICallback('loaded', function(data, cb)
    -- Callback quand le NUI est complètement chargé
    cb('ok')
end)

RegisterNUICallback('ready', function(data, cb)
    -- Callback quand le joueur est prêt à jouer
    TriggerEvent('vava_loadingscreen:ready')
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════
-- DEBUG
-- ═══════════════════════════════════════════════════════════════

if Config and Config.Debug then
    RegisterCommand('loadingscreen_show', function()
        exports['vava_loadingscreen']:Show()
    end, false)
    
    RegisterCommand('loadingscreen_hide', function()
        exports['vava_loadingscreen']:Hide()
    end, false)
    
    RegisterCommand('loadingscreen_progress', function(source, args)
        local progress = tonumber(args[1]) or 50
        exports['vava_loadingscreen']:UpdateProgress(progress)
    end, false)
end
