--[[
    vAvA_core - Server Main
    Point d'entrée principal du serveur
]]

vCore = vCore or {}
vCore.Players = {}
vCore.Started = false

-- ═══════════════════════════════════════════════════════════════════════════
-- INITIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    vCore.Utils.Print('═══════════════════════════════════════════════════════════')
    vCore.Utils.Print('        vAvA_core Framework v1.0.0')
    vCore.Utils.Print('        Auteur: vAvA')
    vCore.Utils.Print('═══════════════════════════════════════════════════════════')
    
    -- Attendre la connexion à la DB
    Wait(1000)
    
    -- Lancer les migrations
    if Config.Database.AutoMigrate then
        vCore.Migrations.Run()
    end
    
    -- Charger les caches
    Wait(500)
    vCore.Cache.Items.Load()
    vCore.Cache.Jobs.Load()
    
    vCore.Started = true
    vCore.Utils.Print('Framework démarré avec succès!')
    vCore.Utils.Print('═══════════════════════════════════════════════════════════')
    
    TriggerEvent('vCore:serverStarted')
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS PRINCIPAUX
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne l'objet vCore
---@return table
exports('GetCoreObject', function()
    return vCore
end)

---Retourne un joueur par source
---@param source number
---@return vPlayer|nil
exports('GetPlayer', function(source)
    return vCore.Cache.Players.Get(source)
end)

---Retourne tous les joueurs
---@return table
exports('GetPlayers', function()
    return vCore.Cache.Players.GetAll()
end)

---Retourne un joueur par identifiant
---@param identifier string
---@return vPlayer|nil
exports('GetPlayerByIdentifier', function(identifier)
    local players = vCore.Cache.Players.GetAll()
    for _, player in pairs(players) do
        if player:GetIdentifier() == identifier then
            return player
        end
    end
    return nil
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS GLOBALES
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne un joueur par source
---@param source number
---@return vPlayer|nil
function vCore.GetPlayer(source)
    return vCore.Cache.Players.Get(source)
end

---Retourne tous les joueurs
---@return table
function vCore.GetPlayers()
    return vCore.Cache.Players.GetAll()
end

---Retourne le nombre de joueurs connectés
---@return number
function vCore.GetPlayerCount()
    return vCore.Utils.TableCount(vCore.Cache.Players.GetAll())
end

---Retourne un joueur par identifiant
---@param identifier string
---@return vPlayer|nil
function vCore.GetPlayerByIdentifier(identifier)
    local players = vCore.Cache.Players.GetAll()
    for _, player in pairs(players) do
        if player:GetIdentifier() == identifier then
            return player
        end
    end
    return nil
end

---Retourne un joueur par ID de personnage
---@param charId number
---@return vPlayer|nil
function vCore.GetPlayerByCharId(charId)
    local players = vCore.Cache.Players.GetAll()
    for _, player in pairs(players) do
        if player:GetCharId() == charId then
            return player
        end
    end
    return nil
end

---Envoie une notification à un joueur
---@param source number
---@param message string
---@param type? string
---@param duration? number
function vCore.Notify(source, message, type, duration)
    TriggerClientEvent('vCore:notify', source, message, type or 'info', duration or 5000)
end

---Envoie une notification à tous les joueurs
---@param message string
---@param type? string
---@param duration? number
function vCore.NotifyAll(message, type, duration)
    TriggerClientEvent('vCore:notify', -1, message, type or 'info', duration or 5000)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SAUVEGARDE AUTOMATIQUE
-- ═══════════════════════════════════════════════════════════════════════════

if Config.Players.AutoSave.enabled then
    CreateThread(function()
        while true do
            Wait(Config.Players.AutoSave.interval)
            
            local players = vCore.Cache.Players.GetAll()
            local count = 0
            
            for source, player in pairs(players) do
                -- Mettre à jour la position
                local ped = GetPlayerPed(source)
                if ped and DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local heading = GetEntityHeading(ped)
                    player:SetPosition(coords.x, coords.y, coords.z, heading)
                end
                
                -- Sauvegarder
                if vCore.DB.SavePlayer(player) then
                    count = count + 1
                end
            end
            
            if count > 0 then
                vCore.Utils.Debug('Sauvegarde automatique:', count, 'joueur(s)')
            end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS RESSOURCE
-- ═══════════════════════════════════════════════════════════════════════════

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    
    vCore.Utils.Print('Arrêt du framework, sauvegarde des joueurs...')
    
    local players = vCore.Cache.Players.GetAll()
    for source, player in pairs(players) do
        vCore.DB.SavePlayer(player)
    end
    
    vCore.Utils.Print('Sauvegarde terminée!')
end)
