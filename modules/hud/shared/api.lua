--[[
    vAvA_hud - API Partagée
    Exports et fonctions publiques du module HUD
]]

HUD = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- API CLIENT (Exports)
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche le HUD
---@usage exports['vAvA_hud']:ShowHUD()
function HUD.Show()
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:ShowHUD()
end

---Cache le HUD
---@usage exports['vAvA_hud']:HideHUD()
function HUD.Hide()
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:HideHUD()
end

---Toggle le HUD (afficher/cacher)
---@usage exports['vAvA_hud']:ToggleHUD()
function HUD.Toggle()
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:ToggleHUD()
end

---Vérifie si le HUD est visible
---@return boolean
---@usage local isVisible = exports['vAvA_hud']:IsHUDVisible()
function HUD.IsVisible()
    if IsDuplicityVersion() then return false end
    return exports['vAvA_hud']:IsHUDVisible()
end

---Met à jour les status (santé, armure, faim, soif, stress)
---@param data table {health = number, armor = number, hunger = number, thirst = number, stress = number}
---@usage exports['vAvA_hud']:UpdateStatus({health = 100, armor = 50, hunger = 75, thirst = 80, stress = 10})
function HUD.UpdateStatus(data)
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:UpdateStatus(data)
end

---Met à jour l'argent
---@param data table {cash = number, bank = number}
---@usage exports['vAvA_hud']:UpdateMoney({cash = 5000, bank = 10000})
function HUD.UpdateMoney(data)
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:UpdateMoney(data)
end

---Met à jour les informations joueur
---@param data table {playerId = number, job = string, grade = string}
---@usage exports['vAvA_hud']:UpdatePlayerInfo({playerId = 1, job = 'Police', grade = 'Agent'})
function HUD.UpdatePlayerInfo(data)
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:UpdatePlayerInfo(data)
end

---Met à jour les informations véhicule
---@param data table {speed = number, fuel = number, engine = boolean, locked = boolean, lights = boolean}
---@usage exports['vAvA_hud']:UpdateVehicle({speed = 120, fuel = 75, engine = true, locked = false, lights = true})
function HUD.UpdateVehicle(data)
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:UpdateVehicle(data)
end

---Affiche le HUD véhicule
---@usage exports['vAvA_hud']:ShowVehicleHud()
function HUD.ShowVehicleHud()
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:ShowVehicleHud()
end

---Cache le HUD véhicule
---@usage exports['vAvA_hud']:HideVehicleHud()
function HUD.HideVehicleHud()
    if IsDuplicityVersion() then return end
    exports['vAvA_hud']:HideVehicleHud()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

---Événements utilisables pour mettre à jour le HUD
---@field vAvA_hud:updateStatus Mettre à jour les status
---@field vAvA:setJob Mettre à jour le job (écouté automatiquement par le module)
---@field vAvA:setMoney Mettre à jour l'argent (écouté automatiquement par le module)
---@field vAvA:initHUD Initialiser le HUD (écouté automatiquement par le module)
HUD.Events = {
    UpdateStatus = 'vAvA_hud:updateStatus',
    SetJob = 'vAvA:setJob',
    SetMoney = 'vAvA:setMoney',
    InitHUD = 'vAvA:initHUD'
}
