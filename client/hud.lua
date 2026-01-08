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

CreateThread(function()
    while true do
        Wait(500) -- Mise à jour toutes les 500ms
        
        if Config.HUD.Enabled and vCore.IsLoaded and isHUDVisible then
            local ped = PlayerPedId()
            
            local hudData = {
                type = 'updateHUD',
                health = GetEntityHealth(ped) - 100,
                maxHealth = 100,
                armor = GetPedArmour(ped),
                hunger = vCore.PlayerData.status and vCore.PlayerData.status.hunger or 100,
                thirst = vCore.PlayerData.status and vCore.PlayerData.status.thirst or 100,
                stress = vCore.PlayerData.status and vCore.PlayerData.status.stress or 0,
                cash = vCore.PlayerData.money and vCore.PlayerData.money.cash or 0,
                bank = vCore.PlayerData.money and vCore.PlayerData.money.bank or 0,
                job = vCore.PlayerData.job and vCore.PlayerData.job.label or 'Chômeur',
                onDuty = vCore.PlayerData.onDuty or false
            }
            
            -- Infos véhicule si dans un véhicule
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                hudData.inVehicle = true
                hudData.speed = math.floor(GetEntitySpeed(vehicle) * 3.6) -- km/h
                hudData.fuel = GetVehicleFuelLevel(vehicle)
            else
                hudData.inVehicle = false
            end
            
            SendNUIMessage(hudData)
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
