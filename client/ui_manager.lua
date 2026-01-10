--[[
    vAvA_core - Client UI Manager
    Gestionnaire d'interfaces utilisateur centralisé
    
    Gère:
    - Menus natifs GTA
    - Interfaces NUI
    - Notifications système
    - HUD personnalisé
    - Progress bars
    - Prompts/confirmations
    
    Charte graphique vAvA appliquée partout
]]

vCore = vCore or {}
vCore.UI = vCore.UI or {}

-- État des UIs
local currentMenu = nil
local currentNUI = nil
local hudVisible = true
local nuiCallbacks = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- MENUS NATIFS GTA
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche un menu natif GTA avec options
---@param menuData table Configuration du menu
---@param callback function Fonction appelée lors de la sélection
function vCore.UI.ShowMenu(menuData, callback)
    if currentMenu then
        vCore.UI.CloseMenu()
    end
    
    currentMenu = {
        data = menuData,
        callback = callback,
        index = 1
    }
    
    -- Créer les options
    local elements = {}
    for i, option in ipairs(menuData.options) do
        table.insert(elements, {
            label = option.label,
            value = option.value,
            description = option.description,
            icon = option.icon,
            disabled = option.disabled or false
        })
    end
    
    currentMenu.elements = elements
    
    -- Afficher le menu (implémentation NativeUI ou MenuV)
    TriggerEvent('vCore:UI:displayMenu', {
        title = menuData.title,
        subtitle = menuData.subtitle,
        elements = elements
    })
end

---Ferme le menu actuel
function vCore.UI.CloseMenu()
    if currentMenu then
        TriggerEvent('vCore:UI:closeMenu')
        currentMenu = nil
    end
end

---Callback de sélection menu
RegisterNetEvent('vCore:UI:menuSelected', function(index, value)
    if currentMenu and currentMenu.callback then
        currentMenu.callback(value, index)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI (HTML/CSS/JS)
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche une interface NUI
---@param nuiName string Nom de l'interface
---@param data table Données à envoyer à l'interface
function vCore.UI.ShowNUI(nuiName, data)
    currentNUI = nuiName
    
    SendNUIMessage({
        action = 'show',
        nui = nuiName,
        data = data or {}
    })
    
    SetNuiFocus(true, true)
end

---Cache une interface NUI
---@param nuiName string Nom de l'interface
function vCore.UI.HideNUI(nuiName)
    if currentNUI == nuiName then
        currentNUI = nil
    end
    
    SendNUIMessage({
        action = 'hide',
        nui = nuiName
    })
    
    SetNuiFocus(false, false)
end

---Enregistre un callback NUI
---@param callbackName string Nom du callback
---@param callback function Fonction à exécuter
function vCore.UI.RegisterNUICallback(callbackName, callback)
    nuiCallbacks[callbackName] = callback
    
    RegisterNUICallback(callbackName, function(data, cb)
        if nuiCallbacks[callbackName] then
            nuiCallbacks[callbackName](data, cb)
        else
            cb('error')
        end
    end)
end

-- Callback générique de fermeture NUI
vCore.UI.RegisterNUICallback('closeNUI', function(data, cb)
    vCore.UI.HideNUI(data.nui)
    cb('ok')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche une notification
---@param message string Message à afficher
---@param type string Type (info, success, warning, error)
---@param duration number Durée en millisecondes
function vCore.UI.Notify(message, type, duration)
    type = type or 'info'
    duration = duration or 5000
    
    SendNUIMessage({
        action = 'notify',
        message = message,
        type = type,
        duration = duration,
        color = Config.Branding.Colors.primary  -- Rouge néon vAvA
    })
end

-- Alias pour compatibilité
vCore.Notify = vCore.UI.Notify

-- Raccourcis par type
function vCore.UI.NotifyInfo(message, duration)
    vCore.UI.Notify(message, 'info', duration)
end

function vCore.UI.NotifySuccess(message, duration)
    vCore.UI.Notify(message, 'success', duration)
end

function vCore.UI.NotifyWarning(message, duration)
    vCore.UI.Notify(message, 'warning', duration)
end

function vCore.UI.NotifyError(message, duration)
    vCore.UI.Notify(message, 'error', duration)
end

-- Event réseau
RegisterNetEvent('vCore:notify', function(message, type, duration)
    vCore.UI.Notify(message, type, duration)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HUD
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche le HUD
---@param components table|nil Composants spécifiques à afficher
function vCore.UI.ShowHUD(components)
    hudVisible = true
    
    SendNUIMessage({
        action = 'showHUD',
        components = components or {'all'}
    })
    
    -- Réactiver les composants GTA
    DisplayRadar(true)
end

---Cache le HUD
---@param components table|nil Composants spécifiques à cacher
function vCore.UI.HideHUD(components)
    if not components then
        hudVisible = false
    end
    
    SendNUIMessage({
        action = 'hideHUD',
        components = components or {'all'}
    })
    
    -- Désactiver les composants GTA si tout est caché
    if not components then
        DisplayRadar(false)
    end
end

---Met à jour les données du HUD
---@param data table Données à mettre à jour (health, armor, money, etc.)
function vCore.UI.UpdateHUD(data)
    SendNUIMessage({
        action = 'updateHUD',
        data = data
    })
end

---Toggle la visibilité du HUD
function vCore.UI.ToggleHUD()
    if hudVisible then
        vCore.UI.HideHUD()
    else
        vCore.UI.ShowHUD()
    end
end

-- Commande /hud
RegisterCommand('hud', function()
    vCore.UI.ToggleHUD()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- PROGRESS BAR
-- ═══════════════════════════════════════════════════════════════════════════

local progressActive = false

---Affiche une barre de progression
---@param data table {label, duration, useWhileDead, canCancel, animation, prop}
---@param onComplete function Fonction appelée à la fin
---@param onCancel function|nil Fonction appelée si annulé
function vCore.UI.ShowProgressBar(data, onComplete, onCancel)
    if progressActive then
        vCore.UI.NotifyWarning('Une action est déjà en cours')
        return
    end
    
    progressActive = true
    local cancelled = false
    
    SendNUIMessage({
        action = 'showProgress',
        label = data.label,
        duration = data.duration,
        color = Config.Branding.Colors.primary
    })
    
    -- Animation
    if data.animation then
        local playerPed = PlayerPedId()
        RequestAnimDict(data.animation.dict)
        while not HasAnimDictLoaded(data.animation.dict) do
            Wait(100)
        end
        TaskPlayAnim(playerPed, data.animation.dict, data.animation.anim, 8.0, -8.0, -1, data.animation.flag or 49, 0, false, false, false)
    end
    
    -- Prop
    local prop = nil
    if data.prop then
        local playerPed = PlayerPedId()
        RequestModel(data.prop.model)
        while not HasModelLoaded(data.prop.model) do
            Wait(100)
        end
        
        prop = CreateObject(GetHashKey(data.prop.model), 0.0, 0.0, 0.0, true, true, true)
        AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, data.prop.bone or 60309), 
            data.prop.offset.x, data.prop.offset.y, data.prop.offset.z,
            data.prop.rotation.x, data.prop.rotation.y, data.prop.rotation.z,
            true, true, false, true, 1, true
        )
    end
    
    -- Vérifier si l'action peut être annulée
    if data.canCancel then
        CreateThread(function()
            while progressActive do
                Wait(0)
                if IsControlJustPressed(0, 73) then  -- X
                    cancelled = true
                    break
                end
            end
        end)
    end
    
    -- Timer
    local startTime = GetGameTimer()
    CreateThread(function()
        while progressActive do
            Wait(100)
            
            local elapsed = GetGameTimer() - startTime
            local progress = (elapsed / data.duration) * 100
            
            -- Vérifier si le joueur est mort (si useWhileDead = false)
            if not data.useWhileDead and IsEntityDead(PlayerPedId()) then
                cancelled = true
                break
            end
            
            -- Vérifier si annulé
            if cancelled then
                break
            end
            
            -- Terminer
            if elapsed >= data.duration then
                break
            end
        end
        
        -- Nettoyage
        progressActive = false
        
        SendNUIMessage({
            action = 'hideProgress'
        })
        
        if data.animation then
            ClearPedTasks(PlayerPedId())
        end
        
        if prop then
            DeleteObject(prop)
        end
        
        -- Callback
        if cancelled then
            if onCancel then onCancel() end
        else
            if onComplete then onComplete() end
        end
    end)
end

---Annule la progress bar en cours
function vCore.UI.CancelProgressBar()
    progressActive = false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PROMPTS / CONFIRMATIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche un prompt de confirmation
---@param data table {title, message, confirmText, cancelText}
---@param onConfirm function Fonction appelée si confirmé
---@param onCancel function|nil Fonction appelée si annulé
function vCore.UI.ShowPrompt(data, onConfirm, onCancel)
    SendNUIMessage({
        action = 'showPrompt',
        title = data.title or 'Confirmation',
        message = data.message,
        confirmText = data.confirmText or 'Confirmer',
        cancelText = data.cancelText or 'Annuler',
        color = Config.Branding.Colors.primary
    })
    
    SetNuiFocus(true, true)
    
    -- Callbacks temporaires
    local promptCallbackConfirm = function(_, cb)
        SetNuiFocus(false, false)
        if onConfirm then onConfirm() end
        cb('ok')
    end
    
    local promptCallbackCancel = function(_, cb)
        SetNuiFocus(false, false)
        if onCancel then onCancel() end
        cb('ok')
    end
    
    RegisterNUICallback('promptConfirm', promptCallbackConfirm)
    RegisterNUICallback('promptCancel', promptCallbackCancel)
end

---Affiche un input texte
---@param data table {title, placeholder, maxLength}
---@param onSubmit function Fonction appelée avec la valeur
function vCore.UI.ShowInput(data, onSubmit)
    SendNUIMessage({
        action = 'showInput',
        title = data.title,
        placeholder = data.placeholder or '',
        maxLength = data.maxLength or 255,
        color = Config.Branding.Colors.primary
    })
    
    SetNuiFocus(true, true)
    
    RegisterNUICallback('inputSubmit', function(inputData, cb)
        SetNuiFocus(false, false)
        if onSubmit then onSubmit(inputData.value) end
        cb('ok')
    end)
    
    RegisterNUICallback('inputCancel', function(_, cb)
        SetNuiFocus(false, false)
        cb('ok')
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE TEXTE 3D
-- ═══════════════════════════════════════════════════════════════════════════

local text3Ds = {}

---Affiche un texte en 3D
---@param id string Identifiant unique
---@param coords vector3 Coordonnées
---@param text string Texte à afficher
---@param options table|nil Options (scale, color, font)
function vCore.UI.Show3DText(id, coords, text, options)
    options = options or {}
    
    text3Ds[id] = {
        coords = coords,
        text = text,
        scale = options.scale or 0.35,
        color = options.color or {r = 255, g = 255, b = 255, a = 255},
        font = options.font or 4
    }
end

---Cache un texte 3D
---@param id string Identifiant
function vCore.UI.Hide3DText(id)
    text3Ds[id] = nil
end

-- Thread de rendu des textes 3D
CreateThread(function()
    while true do
        local sleep = 1000
        
        if next(text3Ds) then
            sleep = 0
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for id, data in pairs(text3Ds) do
                local distance = #(playerCoords - data.coords)
                
                if distance < 10.0 then
                    local onScreen, x, y = World3dToScreen2d(data.coords.x, data.coords.y, data.coords.z)
                    
                    if onScreen then
                        SetTextScale(data.scale, data.scale)
                        SetTextFont(data.font)
                        SetTextProportional(true)
                        SetTextColour(data.color.r, data.color.g, data.color.b, data.color.a)
                        SetTextEntry('STRING')
                        SetTextCentre(true)
                        AddTextComponentString(data.text)
                        DrawText(x, y)
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MARKERS
-- ═══════════════════════════════════════════════════════════════════════════

local markers = {}

---Affiche un marker
---@param id string Identifiant unique
---@param data table {type, coords, scale, color, rotation, bobUpAndDown, faceCamera}
function vCore.UI.ShowMarker(id, data)
    markers[id] = {
        type = data.type or 1,
        coords = data.coords,
        scale = data.scale or {x = 1.0, y = 1.0, z = 1.0},
        color = data.color or {r = 255, g = 30, b = 30, a = 100},  -- Rouge néon vAvA
        rotation = data.rotation or {x = 0.0, y = 0.0, z = 0.0},
        bobUpAndDown = data.bobUpAndDown or false,
        faceCamera = data.faceCamera or false
    }
end

---Cache un marker
---@param id string Identifiant
function vCore.UI.HideMarker(id)
    markers[id] = nil
end

-- Thread de rendu des markers
CreateThread(function()
    while true do
        local sleep = 1000
        
        if next(markers) then
            sleep = 0
            local playerCoords = GetEntityCoords(PlayerPedId())
            
            for id, data in pairs(markers) do
                local distance = #(playerCoords - data.coords)
                
                if distance < 50.0 then
                    DrawMarker(
                        data.type,
                        data.coords.x, data.coords.y, data.coords.z,
                        0.0, 0.0, 0.0,
                        data.rotation.x, data.rotation.y, data.rotation.z,
                        data.scale.x, data.scale.y, data.scale.z,
                        data.color.r, data.color.g, data.color.b, data.color.a,
                        data.bobUpAndDown,
                        data.faceCamera,
                        2, false, nil, nil, false
                    )
                end
            end
        end
        
        Wait(sleep)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- HELP TEXT
-- ═══════════════════════════════════════════════════════════════════════════

local helpText = nil

---Affiche un texte d'aide (bas de l'écran)
---@param text string Texte à afficher
function vCore.UI.ShowHelpText(text)
    helpText = text
end

---Cache le texte d'aide
function vCore.UI.HideHelpText()
    helpText = nil
end

-- Thread de rendu du texte d'aide
CreateThread(function()
    while true do
        local sleep = 500
        
        if helpText then
            sleep = 0
            
            SetTextComponentFormat('STRING')
            AddTextComponentString(helpText)
            DisplayHelpTextFromStringLabel(0, 0, 1, -1)
        end
        
        Wait(sleep)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowMenu', vCore.UI.ShowMenu)
exports('CloseMenu', vCore.UI.CloseMenu)
exports('ShowNUI', vCore.UI.ShowNUI)
exports('HideNUI', vCore.UI.HideNUI)
exports('Notify', vCore.UI.Notify)
exports('ShowHUD', vCore.UI.ShowHUD)
exports('HideHUD', vCore.UI.HideHUD)
exports('UpdateHUD', vCore.UI.UpdateHUD)
exports('ShowProgressBar', vCore.UI.ShowProgressBar)
exports('ShowPrompt', vCore.UI.ShowPrompt)
exports('ShowInput', vCore.UI.ShowInput)
exports('Show3DText', vCore.UI.Show3DText)
exports('Hide3DText', vCore.UI.Hide3DText)
exports('ShowMarker', vCore.UI.ShowMarker)
exports('HideMarker', vCore.UI.HideMarker)
exports('ShowHelpText', vCore.UI.ShowHelpText)
exports('HideHelpText', vCore.UI.HideHelpText)

print('^2[vCore:UI]^7 UI Manager chargé avec succès!')
