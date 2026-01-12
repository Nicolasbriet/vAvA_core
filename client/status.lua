--[[
    vAvA_core - Client Status
    Gestion des status (faim, soif, stress)
    
    ⚠️ FICHIER DÉSACTIVÉ ⚠️
    Tout est géré par:
    - modules/status pour hunger/thirst/effets visuels
    - modules/ems pour la vie/mort
]]

vCore = vCore or {}
vCore.Status = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉSACTIVÉ: La décrémentation est faite par modules/status/server/main.lua
-- ═══════════════════════════════════════════════════════════════════════════

--[[ DÉSACTIVÉ: Module modules/status gère la décrémentation
CreateThread(function()
    while true do
        Wait(60000) -- Toutes les minutes
        
        if Config.Status.Enabled and vCore.IsLoaded then
            local ped = PlayerPedId()
            
            -- Faim
            if vCore.PlayerData.status then
                local hunger = vCore.PlayerData.status.hunger or 100
                hunger = hunger - Config.Status.DecreaseRate.hunger
                vCore.PlayerData.status.hunger = math.max(0, hunger)
                
                -- Soif
                local thirst = vCore.PlayerData.status.thirst or 100
                thirst = thirst - Config.Status.DecreaseRate.thirst
                vCore.PlayerData.status.thirst = math.max(0, thirst)
                
                -- Stress (récupération)
                local stress = vCore.PlayerData.status.stress or 0
                stress = stress + Config.Status.DecreaseRate.stress -- Négatif donc diminue
                vCore.PlayerData.status.stress = vCore.Utils.Clamp(stress, 0, 100)
                
                -- Envoyer au serveur
                TriggerServerEvent('vCore:updateStatus', vCore.PlayerData.status)
            end
        end
    end
end)
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- EFFETS DES STATUS - DÉSACTIVÉ (géré par modules/status + modules/ems)
-- ═══════════════════════════════════════════════════════════════════════════

--[[ DÉSACTIVÉ: Le module modules/status gère les effets visuels
     et le module modules/ems gère la vie/mort
CreateThread(function()
    while true do
        Wait(5000) -- Toutes les 5 secondes
        
        if Config.Status.Enabled and vCore.IsLoaded and vCore.PlayerData.status then
            local ped = PlayerPedId()
            local hunger = vCore.PlayerData.status.hunger or 100
            local thirst = vCore.PlayerData.status.thirst or 100
            local stress = vCore.PlayerData.status.stress or 0
            
            -- Effet faim critique
            if hunger <= Config.Status.Effects.hunger.critical then
                local health = GetEntityHealth(ped)
                SetEntityHealth(ped, health - Config.Status.Effects.hunger.damage)
                
                if hunger <= 5 then
                    vCore.Notify(Lang('status_dying'), 'error')
                else
                    vCore.Notify(Lang('status_hungry'), 'warning')
                end
            end
            
            -- Effet soif critique
            if thirst <= Config.Status.Effects.thirst.critical then
                local health = GetEntityHealth(ped)
                SetEntityHealth(ped, health - Config.Status.Effects.thirst.damage)
                
                if thirst <= 5 then
                    vCore.Notify(Lang('status_dying'), 'error')
                else
                    vCore.Notify(Lang('status_thirsty'), 'warning')
                end
            end
            
            -- Effet stress élevé
            if stress >= Config.Status.Effects.stress.high then
                vCore.Notify(Lang('status_stressed'), 'warning')
                
                -- Effets visuels
                for _, effect in ipairs(Config.Status.Effects.stress.effects) do
                    if effect == 'screen_shake' then
                        ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.1)
                    end
                end
            end
        end
    end
end)
]]
-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS STATUS
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne un status
---@param statusType string
---@return number
function vCore.Status.Get(statusType)
    return vCore.PlayerData.status and vCore.PlayerData.status[statusType] or 0
end

---Définit un status localement
---@param statusType string
---@param value number
function vCore.Status.Set(statusType, value)
    if vCore.PlayerData.status then
        vCore.PlayerData.status[statusType] = vCore.Utils.Clamp(value, 0, 100)
    end
end

---Ajoute à un status
---@param statusType string
---@param value number
function vCore.Status.Add(statusType, value)
    local current = vCore.Status.Get(statusType)
    vCore.Status.Set(statusType, current + value)
end

---Retire d'un status
---@param statusType string
---@param value number
function vCore.Status.Remove(statusType, value)
    local current = vCore.Status.Get(statusType)
    vCore.Status.Set(statusType, current - value)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- AUGMENTATION DU STRESS
-- ═══════════════════════════════════════════════════════════════════════════

-- Stress en courant
CreateThread(function()
    while true do
        Wait(10000) -- Toutes les 10 secondes
        
        if Config.Status.Enabled and vCore.IsLoaded then
            local ped = PlayerPedId()
            
            -- Sprint = stress
            if IsPedSprinting(ped) then
                vCore.Status.Add('stress', 0.5)
            end
            
            -- Tir = stress
            if IsPedShooting(ped) then
                vCore.Status.Add('stress', 2)
            end
            
            -- Blessé = stress
            if GetEntityHealth(ped) < 100 then
                vCore.Status.Add('stress', 1)
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Mise à jour depuis le serveur
RegisterNetEvent(vCore.Events.STATUS_UPDATED, function(statusType, value)
    if vCore.PlayerData.status then
        vCore.PlayerData.status[statusType] = value
    end
end)
