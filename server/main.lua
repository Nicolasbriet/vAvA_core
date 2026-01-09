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
    
    -- 🔄 SYSTÈME AUTO-UPDATE - Vérifier et appliquer les mises à jour
    Wait(500)
    if vCore.AutoUpdate then
        vCore.AutoUpdate.CheckAndApply()
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
-- SYSTÈME DE PERMISSIONS (txAdmin ACE)
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si un joueur a une permission ACE spécifique
---@param source number
---@param permission string
---@return boolean
function vCore.HasAce(source, permission)
    return IsPlayerAceAllowed(source, permission)
end

---Vérifie si un joueur a une des permissions ACE listées
---@param source number
---@param permissions table Liste des permissions à vérifier
---@return boolean
function vCore.HasAnyAce(source, permissions)
    for _, perm in ipairs(permissions) do
        if IsPlayerAceAllowed(source, perm) then
            return true
        end
    end
    return false
end

---Retourne le niveau de permission d'un joueur (basé sur ACE txAdmin)
---@param source number
---@return number level, string role
function vCore.GetPermissionLevel(source)
    -- Vérifier par ACE (priorité haute)
    if Config.Permissions.Method == 'ace' then
        -- Vérifier les niveaux ACE définis
        for role, data in pairs(Config.Permissions.AceLevels) do
            for _, ace in ipairs(data.aces) do
                if IsPlayerAceAllowed(source, ace) then
                    return data.level, role
                end
            end
        end
        
        -- Vérifier les ACE extras (WaveAdmin, etc.)
        for _, ace in ipairs(Config.Permissions.ExtraAces or {}) do
            if IsPlayerAceAllowed(source, ace) then
                -- Déterminer le niveau basé sur le nom
                if ace:find('owner') or ace:find('god') then
                    return 5, 'owner'
                elseif ace:find('_dev') then
                    return 4, 'developer'
                elseif ace:find('superadmin') then
                    return 3, 'superadmin'
                elseif ace:find('admin') or ace:find('operator') then
                    return 2, 'admin'
                elseif ace:find('mod') then
                    return 1, 'mod'
                elseif ace:find('helper') then
                    return 0, 'helper'
                end
            end
        end
    end
    
    -- Fallback: utiliser le groupe vCore interne
    if Config.Permissions.FallbackToGroups then
        local player = vCore.Cache.Players.Get(source)
        if player then
            local group = player.group or 'user'
            local level = Config.Admin.Groups[group] or 0
            return level, group
        end
        
        -- Vérifier par identifiant dans Config.Admin.Admins
        local identifiers = GetPlayerIdentifiers(source)
        for _, id in ipairs(identifiers) do
            if Config.Admin.Admins[id] then
                local role = Config.Admin.Admins[id]
                local level = Config.Admin.Groups[role] or 0
                return level, role
            end
        end
    end
    
    return 0, 'user'
end

---Vérifie si un joueur est admin (niveau >= 2)
---@param source number
---@return boolean
function vCore.IsAdmin(source)
    local level, _ = vCore.GetPermissionLevel(source)
    return level >= 2
end

---Vérifie si un joueur est superadmin (niveau >= 3)
---@param source number
---@return boolean
function vCore.IsSuperAdmin(source)
    local level, _ = vCore.GetPermissionLevel(source)
    return level >= 3
end

---Vérifie si un joueur est owner/developer (niveau >= 4)
---@param source number
---@return boolean
function vCore.IsOwner(source)
    local level, _ = vCore.GetPermissionLevel(source)
    return level >= 4
end

---Vérifie si un joueur est staff (mod ou plus, niveau >= 1)
---@param source number
---@return boolean
function vCore.IsStaff(source)
    local level, _ = vCore.GetPermissionLevel(source)
    return level >= 1
end

---Vérifie si un joueur a un niveau de permission minimum
---@param source number
---@param minLevel number
---@return boolean
function vCore.HasPermissionLevel(source, minLevel)
    local level, _ = vCore.GetPermissionLevel(source)
    return level >= minLevel
end

---Retourne le rôle d'un joueur (string)
---@param source number
---@return string
function vCore.GetPlayerRole(source)
    local _, role = vCore.GetPermissionLevel(source)
    return role
end

-- Ajouter au vCore.Functions pour compatibilité (style QBCore/ESX)
vCore.Functions = vCore.Functions or {}

-- Fonctions joueurs
vCore.Functions.GetPlayer = vCore.GetPlayer
vCore.Functions.GetPlayers = vCore.GetPlayers
vCore.Functions.GetPlayerCount = vCore.GetPlayerCount
vCore.Functions.GetPlayerByIdentifier = vCore.GetPlayerByIdentifier
vCore.Functions.GetPlayerByCharId = vCore.GetPlayerByCharId

-- Fonctions notifications
vCore.Functions.Notify = vCore.Notify
vCore.Functions.NotifyAll = vCore.NotifyAll

-- Fonctions callbacks
vCore.Functions.CreateCallback = vCore.CreateCallback
vCore.Functions.RegisterServerCallback = vCore.RegisterServerCallback

-- Fonctions permissions (txAdmin ACE)
vCore.Functions.HasAce = vCore.HasAce
vCore.Functions.HasAnyAce = vCore.HasAnyAce
vCore.Functions.GetPermissionLevel = vCore.GetPermissionLevel
vCore.Functions.IsAdmin = vCore.IsAdmin
vCore.Functions.IsSuperAdmin = vCore.IsSuperAdmin
vCore.Functions.IsOwner = vCore.IsOwner
vCore.Functions.IsStaff = vCore.IsStaff
vCore.Functions.HasPermissionLevel = vCore.HasPermissionLevel
vCore.Functions.GetPlayerRole = vCore.GetPlayerRole

-- Export des fonctions de permissions
exports('IsAdmin', vCore.IsAdmin)
exports('IsSuperAdmin', vCore.IsSuperAdmin)
exports('IsOwner', vCore.IsOwner)
exports('IsStaff', vCore.IsStaff)
exports('GetPermissionLevel', vCore.GetPermissionLevel)
exports('HasAce', vCore.HasAce)

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
