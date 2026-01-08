--[[
    vAvA_core - Client Notifications
    Système de notifications
]]

vCore = vCore or {}

-- Queue de notifications
local notificationQueue = {}
local isShowingNotification = false

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTION PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche une notification
---@param message string
---@param type? string
---@param duration? number
function vCore.Notify(message, type, duration)
    type = type or 'info'
    duration = duration or 5000
    
    table.insert(notificationQueue, {
        message = message,
        type = type,
        duration = duration
    })
    
    if not isShowingNotification then
        ProcessNotificationQueue()
    end
end

---Export pour la notification
exports('Notify', function(message, type, duration)
    vCore.Notify(message, type, duration)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- TRAITEMENT DE LA QUEUE
-- ═══════════════════════════════════════════════════════════════════════════

function ProcessNotificationQueue()
    if #notificationQueue == 0 then
        isShowingNotification = false
        return
    end
    
    isShowingNotification = true
    local notification = table.remove(notificationQueue, 1)
    
    ShowNotification(notification.message, notification.type, notification.duration)
    
    SetTimeout(notification.duration + 500, function()
        ProcessNotificationQueue()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHAGE NOTIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

function ShowNotification(message, type, duration)
    -- Icônes par type
    local icons = {
        info = '~b~ℹ~s~',
        success = '~g~✓~s~',
        warning = '~y~⚠~s~',
        error = '~r~✗~s~'
    }
    
    local icon = icons[type] or icons.info
    
    -- Utiliser le système natif de GTA
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(icon .. ' ' .. message)
    EndTextCommandThefeedPostTicker(false, true)
    
    -- Alternative: envoyer au NUI si on veut un style custom
    -- SendNUIMessage({
    --     type = 'notification',
    --     message = message,
    --     notifyType = type,
    --     duration = duration
    -- })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENT SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:notify', function(message, type, duration)
    vCore.Notify(message, type, duration)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION AVANCÉE (3D)
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche un texte 3D
---@param coords vector3
---@param text string
---@param scale? number
function vCore.Draw3DText(coords, text, scale)
    scale = scale or 0.35
    
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - coords)
    
    if onScreen then
        local scale = (1 / dist) * 2
        local fov = (1 / GetGameplayCamFov()) * 100
        local scale = scale * fov
        
        SetTextScale(0.0, scale)
        SetTextFont(4)
        SetTextProportional(true)
        SetTextColour(255, 255, 255, 215)
        SetTextDropShadow()
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextOutline()
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

---Affiche un texte d'aide
---@param text string
---@param beep? boolean
function vCore.ShowHelpText(text, beep)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, beep or false, -1)
end

---Affiche un texte de sous-titre
---@param text string
---@param duration? number
function vCore.ShowSubtitle(text, duration)
    duration = duration or 5000
    
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandPrint(duration, true)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION CONTEXTUELLE
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche une instruction avec touche
---@param key string
---@param text string
function vCore.ShowKeyHint(key, text)
    local instructionalButtons = Scaleform.Request("instructional_buttons")
    
    instructionalButtons:CallFunction("CLEAR_ALL")
    instructionalButtons:CallFunction("SET_CLEAR_SPACE", 200)
    
    local slot = 0
    
    instructionalButtons:CallFunction("SET_DATA_SLOT", slot, GetControlInstructionalButton(2, GetHashKey("INPUT_" .. string.upper(key)), true), text)
    
    instructionalButtons:CallFunction("DRAW_INSTRUCTIONAL_BUTTONS")
    
    DrawScaleformMovieFullscreen(instructionalButtons.handle, 255, 255, 255, 255, 0)
end
