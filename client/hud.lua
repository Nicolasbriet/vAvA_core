--[[
    vAvA_core - Client HUD
    Interface utilisateur (HUD)
]]

vCore = vCore or {}
vCore.HUD = {}

local isHUDVisible = true

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTRÔLE DU HUD
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche le HUD
function vCore.HUD.Show()
    isHUDVisible = true
    DisplayRadar(true)
    SendNUIMessage({type = 'showHUD'})
end

---Cache le HUD
function vCore.HUD.Hide()
    isHUDVisible = false
    DisplayRadar(false)
    SendNUIMessage({type = 'hideHUD'})
end

---Toggle le HUD
function vCore.HUD.Toggle()
    if isHUDVisible then
        vCore.HUD.Hide()
    else
        vCore.HUD.Show()
    end
end

---Vérifie si le HUD est visible
---@return boolean
function vCore.HUD.IsVisible()
    return isHUDVisible
end

-- Exports
exports('ShowHUD', function() vCore.HUD.Show() end)
exports('HideHUD', function() vCore.HUD.Hide() end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MISE À JOUR DU HUD
-- ═══════════════════════════════════════════════════════════════════════════

-- Réception des updates depuis le module status
RegisterNetEvent('vAvA_hud:updateStatus')
AddEventHandler('vAvA_hud:updateStatus', function(statusData)
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
    if job then
        SendNUIMessage({
            action = 'updatePlayerInfo',
            playerId = GetPlayerServerId(PlayerId()),
            job = job.label or 'Sans emploi',
            grade = job.grade_label or '-'
        })
    end
end)

-- Mise à jour instantanée de l'argent au changement
RegisterNetEvent('vAvA:setMoney')
AddEventHandler('vAvA:setMoney', function(money)
    if money then
        SendNUIMessage({
            action = 'updateMoney',
            cash = money.cash or 0,
            bank = money.bank or 0
        })
    end
end)

-- Initialisation des infos joueur au chargement
RegisterNetEvent('vAvA:initHUD')
AddEventHandler('vAvA:initHUD', function()
    if not vCore.IsLoaded then return end
    
    vCore.Utils.Print('Initialisation du HUD avec les données:', json.encode(vCore.PlayerData))
    
    -- Envoyer l'ID joueur
    SendNUIMessage({
        action = 'updatePlayerInfo',
        playerId = GetPlayerServerId(PlayerId()),
        job = vCore.PlayerData.job and vCore.PlayerData.job.label or 'Sans emploi',
        grade = vCore.PlayerData.job and vCore.PlayerData.job.grade_label or '-'
    })
    
    -- Envoyer l'argent initial
    SendNUIMessage({
        action = 'updateMoney',
        cash = vCore.PlayerData.money and vCore.PlayerData.money.cash or 0,
        bank = vCore.PlayerData.money and vCore.PlayerData.money.bank or 0
    })
end)

CreateThread(function()
    while true do
        Wait(500) -- Mise à jour toutes les 500ms
        
        if Config.HUD.Enabled and vCore.IsLoaded and isHUDVisible then
            local ped = PlayerPedId()
            local health = (GetEntityHealth(ped) - 100) -- Native retourne 100-200
            
            -- S'assurer que les valeurs sont entre 0 et 100
            if health < 0 then health = 0 end
            if health > 100 then health = 100 end
            
            local hudData = {
                action = 'updateStatus',
                health = health,
                armor = GetPedArmour(ped),
                hunger = vCore.PlayerData.status and vCore.PlayerData.status.hunger or 100,
                thirst = vCore.PlayerData.status and vCore.PlayerData.status.thirst or 100,
                stress = vCore.PlayerData.status and vCore.PlayerData.status.stress or 0
            }
            
            SendNUIMessage(hudData)
            
            -- Infos véhicule si dans un véhicule
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                SendNUIMessage({
                    action = 'showVehicleHud'
                })
                SendNUIMessage({
                    action = 'updateVehicle',
                    speed = math.floor(GetEntitySpeed(vehicle) * 3.6), -- km/h
                    fuel = GetVehicleFuelLevel(vehicle),
                    engine = GetIsVehicleEngineRunning(vehicle),
                    locked = GetVehicleDoorLockStatus(vehicle) == 2,
                    lights = IsVehicleLightOn(vehicle)
                })
            else
                SendNUIMessage({
                    action = 'hideVehicleHud'
                })
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- MINIMAP
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        if not Config.HUD.Minimap.enabled then
            Wait(1000) -- Attendre si désactivé
        else
            Wait(100) -- 10 FPS suffisent pour la minimap
            -- Forcer l'affichage de la minimap
            if not IsPauseMenuActive() then
                SetRadarBigmapEnabled(false, false)
                
                -- Minimap circulaire si configurée
                if Config.HUD.Minimap.shape == 'circle' then
                    SetRadarZoom(1100)
                    
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

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉSACTIVATION DU HUD NATIF
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        if not Config.HUD.Enabled then
            Wait(1000) -- Attendre si désactivé
        else
            Wait(0) -- Nécessaire pour HideHudComponentThisFrame
            -- Cacher les éléments natifs du HUD
            HideHudComponentThisFrame(1)  -- Wanted Stars
            HideHudComponentThisFrame(2)  -- Weapon Icon
            HideHudComponentThisFrame(3)  -- Cash
            HideHudComponentThisFrame(4)  -- MP Cash
            HideHudComponentThisFrame(6)  -- Vehicle Name
            HideHudComponentThisFrame(7)  -- Area Name
            HideHudComponentThisFrame(8)  -- Vehicle Class
            HideHudComponentThisFrame(9)  -- Street Name
            
            -- Garder la minimap
            -- HideHudComponentThisFrame(14) -- Radar
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBIND
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('+toggleHUD', function()
    vCore.HUD.Toggle()
end, false)

RegisterKeyMapping('+toggleHUD', 'Afficher/Cacher le HUD', 'keyboard', 'F7')

-- Debug HUD (pour vérifier les données)
RegisterCommand('debughud', function()
    if not vCore.IsLoaded then
        print('^1[DEBUG] Joueur non chargé!^0')
        return
    end
    
    print('^2[DEBUG HUD] Données joueur:^0')
    print('  IsLoaded:', vCore.IsLoaded)
    print('  Money:', json.encode(vCore.PlayerData.money))
    print('  Job:', json.encode(vCore.PlayerData.job))
    print('  Status:', json.encode(vCore.PlayerData.status))
    print('  Health:', GetEntityHealth(PlayerPedId()) - 100)
    print('  Armor:', GetPedArmour(PlayerPedId()))
    
    -- Forcer une mise à jour du HUD
    TriggerEvent('vAvA:initHUD')
    print('^2[DEBUG] HUD réinitialisé!^0')
end, false)
