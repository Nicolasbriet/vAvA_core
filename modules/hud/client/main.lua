--[[
    vAvA_hud - Client Main
    Gestion du HUD côté client
]]

local HUD = {}
local isHUDVisible = true

-- Obtenir vCore depuis l'export du core
local vCore = exports['vAvA_core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    -- Attendre que le core soit chargé
    while not vCore do
        Wait(100)
        vCore = exports['vAvA_core']:GetCoreObject()
    end
    
    print('[vAvA_hud] Module HUD initialisé')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTRÔLE DU HUD
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche le HUD
function HUD.Show()
    isHUDVisible = true
    if HUDConfig.Settings.Minimap.enabled then
        DisplayRadar(true)
    end
    SendNUIMessage({action = 'show'})
end

---Cache le HUD
function HUD.Hide()
    isHUDVisible = false
    DisplayRadar(false)
    SendNUIMessage({action = 'hide'})
end

---Toggle le HUD
function HUD.Toggle()
    if isHUDVisible then
        HUD.Hide()
    else
        HUD.Show()
    end
end

---Vérifie si le HUD est visible
---@return boolean
function HUD.IsVisible()
    return isHUDVisible
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR DU HUD
-- ═══════════════════════════════════════════════════════════════════════════

---Met à jour les status (santé, armure, faim, soif, stress)
---@param data table Données de status
function HUD.UpdateStatus(data)
    if not isHUDVisible then return end
    SendNUIMessage({
        action = 'updateStatus',
        health = data.health or HUDConfig.Defaults.health,
        armor = data.armor or HUDConfig.Defaults.armor,
        hunger = data.hunger or HUDConfig.Defaults.hunger,
        thirst = data.thirst or HUDConfig.Defaults.thirst,
        stress = data.stress or HUDConfig.Defaults.stress
    })
end

---Met à jour l'argent
---@param data table Données d'argent
function HUD.UpdateMoney(data)
    if not isHUDVisible then return end
    SendNUIMessage({
        action = 'updateMoney',
        cash = data.cash or HUDConfig.Defaults.cash,
        bank = data.bank or HUDConfig.Defaults.bank
    })
end

---Met à jour les informations joueur
---@param data table Données du joueur
function HUD.UpdatePlayerInfo(data)
    if not isHUDVisible then return end
    SendNUIMessage({
        action = 'updatePlayerInfo',
        playerId = data.playerId or GetPlayerServerId(PlayerId()),
        job = data.job or HUDConfig.Defaults.job,
        grade = data.grade or HUDConfig.Defaults.grade
    })
end

---Met à jour les informations véhicule
---@param data table Données du véhicule
function HUD.UpdateVehicle(data)
    if not isHUDVisible then return end
    SendNUIMessage({
        action = 'updateVehicle',
        speed = data.speed or HUDConfig.Defaults.speed,
        fuel = data.fuel or HUDConfig.Defaults.fuel,
        engine = data.engine or false,
        locked = data.locked or false,
        lights = data.lights or false
    })
end

---Affiche le HUD véhicule
function HUD.ShowVehicleHud()
    if not isHUDVisible then return end
    SendNUIMessage({action = 'showVehicleHud'})
end

---Cache le HUD véhicule
function HUD.HideVehicleHud()
    if not isHUDVisible then return end
    SendNUIMessage({action = 'hideVehicleHud'})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Réception des updates depuis le module status
RegisterNetEvent('vAvA_hud:updateStatus')
AddEventHandler('vAvA_hud:updateStatus', function(statusData)
    if not vCore or not vCore.PlayerData then return end
    
    if not vCore.PlayerData.status then
        vCore.PlayerData.status = {}
    end
    
    if statusData.hunger then
        vCore.PlayerData.status.hunger = statusData.hunger
    end
    
    if statusData.thirst then
        vCore.PlayerData.status.thirst = statusData.thirst
    end
end)

-- Mise à jour instantanée du job/grade au changement
RegisterNetEvent('vAvA:setJob')
AddEventHandler('vAvA:setJob', function(job)
    if not job then return end
    
    HUD.UpdatePlayerInfo({
        playerId = GetPlayerServerId(PlayerId()),
        job = job.label or HUDConfig.Defaults.job,
        grade = job.grade_label or HUDConfig.Defaults.grade
    })
end)

-- Mise à jour instantanée de l'argent au changement
RegisterNetEvent('vAvA:setMoney')
AddEventHandler('vAvA:setMoney', function(money)
    if not money then return end
    
    HUD.UpdateMoney({
        cash = money.cash or HUDConfig.Defaults.cash,
        bank = money.bank or HUDConfig.Defaults.bank
    })
end)

-- Initialisation des infos joueur au chargement
RegisterNetEvent('vAvA:initHUD')
AddEventHandler('vAvA:initHUD', function()
    if not vCore or not vCore.IsLoaded then return end
    
    if HUDConfig.Debug.enabled then
        print('[vAvA_hud] Initialisation du HUD avec les données:', json.encode(vCore.PlayerData))
    end
    
    -- Envoyer l'ID joueur
    HUD.UpdatePlayerInfo({
        playerId = GetPlayerServerId(PlayerId()),
        job = vCore.PlayerData.job and vCore.PlayerData.job.label or HUDConfig.Defaults.job,
        grade = vCore.PlayerData.job and vCore.PlayerData.job.grade_label or HUDConfig.Defaults.grade
    })
    
    -- Envoyer l'argent initial
    HUD.UpdateMoney({
        cash = vCore.PlayerData.money and vCore.PlayerData.money.cash or HUDConfig.Defaults.cash,
        bank = vCore.PlayerData.money and vCore.PlayerData.money.bank or HUDConfig.Defaults.bank
    })
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- BOUCLE DE MISE À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(HUDConfig.Settings.UpdateInterval)
        
        if HUDConfig.Enabled and vCore and vCore.IsLoaded and isHUDVisible then
            local ped = PlayerPedId()
            local health = (GetEntityHealth(ped) - 100) -- Native retourne 100-200
            
            -- S'assurer que les valeurs sont entre 0 et 100
            if health < 0 then health = 0 end
            if health > 100 then health = 100 end
            
            -- Mise à jour des status
            HUD.UpdateStatus({
                health = health,
                armor = GetPedArmour(ped),
                hunger = vCore.PlayerData.status and vCore.PlayerData.status.hunger or HUDConfig.Defaults.hunger,
                thirst = vCore.PlayerData.status and vCore.PlayerData.status.thirst or HUDConfig.Defaults.thirst,
                stress = vCore.PlayerData.status and vCore.PlayerData.status.stress or HUDConfig.Defaults.stress
            })
            
            -- Infos véhicule si dans un véhicule
            if HUDConfig.Display.Vehicle and IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                HUD.ShowVehicleHud()
                HUD.UpdateVehicle({
                    speed = math.floor(GetEntitySpeed(vehicle) * 3.6), -- km/h
                    fuel = GetVehicleFuelLevel(vehicle),
                    engine = GetIsVehicleEngineRunning(vehicle),
                    locked = GetVehicleDoorLockStatus(vehicle) == 2,
                    lights = IsVehicleLightOn(vehicle)
                })
            else
                HUD.HideVehicleHud()
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MINIMAP
-- ═══════════════════════════════════════════════════════════════════════════

if HUDConfig.Settings.Minimap.enabled then
    CreateThread(function()
        while true do
            Wait(100) -- 10 FPS suffisent pour la minimap
            
            if HUDConfig.Enabled then
                -- Forcer l'affichage de la minimap
                if not IsPauseMenuActive() then
                    SetRadarBigmapEnabled(false, false)
                    
                    -- Minimap circulaire si configurée
                    if HUDConfig.Settings.Minimap.shape == 'circle' then
                        SetRadarZoom(HUDConfig.Settings.Minimap.zoom)
                        
                        -- Appliquer le masque circulaire
                        local minimapHandle = RequestScaleformMovie("MINIMAP")
                        if HasScaleformMovieLoaded(minimapHandle) then
                            BeginScaleformMovieMethod(minimapHandle, "SETUP_HEALTH_ARMOUR")
                            ScaleformMovieMethodAddParamInt(3)
                            EndScaleformMovieMethod()
                        end
                    end
                end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉSACTIVATION DU HUD NATIF
-- ═══════════════════════════════════════════════════════════════════════════

if HUDConfig.Settings.HideNativeHUD then
    CreateThread(function()
        while true do
            Wait(0) -- Nécessaire pour HideHudComponentThisFrame
            
            if HUDConfig.Enabled then
                local components = HUDConfig.Settings.HideComponents
                
                if components.wantedStars then HideHudComponentThisFrame(1) end
                if components.weaponIcon then HideHudComponentThisFrame(2) end
                if components.cash then HideHudComponentThisFrame(3) end
                if components.mpCash then HideHudComponentThisFrame(4) end
                if components.vehicleName then HideHudComponentThisFrame(6) end
                if components.areaName then HideHudComponentThisFrame(7) end
                if components.vehicleClass then HideHudComponentThisFrame(8) end
                if components.streetName then HideHudComponentThisFrame(9) end
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBIND
-- ═══════════════════════════════════════════════════════════════════════════

if HUDConfig.Keybinds.Toggle.enabled then
    RegisterCommand(HUDConfig.Keybinds.Toggle.command, function()
        HUD.Toggle()
    end, false)
    
    RegisterKeyMapping(
        HUDConfig.Keybinds.Toggle.command,
        HUDConfig.Keybinds.Toggle.description,
        'keyboard',
        HUDConfig.Keybinds.Toggle.key
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

if HUDConfig.Debug.enabled then
    RegisterCommand(HUDConfig.Debug.command, function()
        if not vCore or not vCore.IsLoaded then
            print('^1[vAvA_hud] Joueur non chargé!^0')
            return
        end
        
        print('^2[vAvA_hud] Données joueur:^0')
        print('  IsLoaded:', vCore.IsLoaded)
        print('  Money:', json.encode(vCore.PlayerData.money))
        print('  Job:', json.encode(vCore.PlayerData.job))
        print('  Status:', json.encode(vCore.PlayerData.status))
        print('  Health:', GetEntityHealth(PlayerPedId()) - 100)
        print('  Armor:', GetPedArmour(PlayerPedId()))
        
        -- Forcer une mise à jour du HUD
        TriggerEvent('vAvA:initHUD')
        print('^2[vAvA_hud] HUD réinitialisé!^0')
    end, false)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('ShowHUD', HUD.Show)
exports('HideHUD', HUD.Hide)
exports('ToggleHUD', HUD.Toggle)
exports('IsHUDVisible', HUD.IsVisible)
exports('UpdateStatus', HUD.UpdateStatus)
exports('UpdateMoney', HUD.UpdateMoney)
exports('UpdatePlayerInfo', HUD.UpdatePlayerInfo)
exports('UpdateVehicle', HUD.UpdateVehicle)
exports('ShowVehicleHud', HUD.ShowVehicleHud)
exports('HideVehicleHud', HUD.HideVehicleHud)
