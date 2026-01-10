--[[
    vAvA_core - Permissions System
    Système de permissions centralisé
]]

vCore = vCore or {}
vCore.Permissions = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- NIVEAUX DE PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════

vCore.PermissionLevel = {
    USER = 0,           -- Joueur standard
    HELPER = 1,         -- Support/Helper
    MODERATOR = 2,      -- Modérateur
    ADMIN = 3,          -- Administrateur
    SENIOR_ADMIN = 4,   -- Admin Senior
    SUPER_ADMIN = 5     -- Super Admin (Propriétaire)
}

-- Labels des niveaux
vCore.PermissionLabel = {
    [0] = 'Joueur',
    [1] = 'Helper',
    [2] = 'Modérateur',
    [3] = 'Administrateur',
    [4] = 'Admin Senior',
    [5] = 'Super Admin'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PERMISSIONS ACE
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Permissions.ACE = {
    -- Permissions générales
    NOCLIP = 'vava.noclip',
    GODMODE = 'vava.godmode',
    SPECTATE = 'vava.spectate',
    
    -- Permissions joueurs
    KICK = 'vava.kick',
    BAN = 'vava.ban',
    WARN = 'vava.warn',
    TELEPORT = 'vava.teleport',
    BRING = 'vava.bring',
    REVIVE = 'vava.revive',
    
    -- Permissions économie
    GIVE_MONEY = 'vava.givemoney',
    GIVE_ITEM = 'vava.giveitem',
    TAKE_MONEY = 'vava.takemoney',
    TAKE_ITEM = 'vava.takeitem',
    
    -- Permissions job
    SET_JOB = 'vava.setjob',
    SET_GANG = 'vava.setgang',
    JOB_MENU = 'vava.jobmenu',
    
    -- Permissions véhicules
    SPAWN_VEHICLE = 'vava.spawnvehicle',
    DELETE_VEHICLE = 'vava.deletevehicle',
    REPAIR_VEHICLE = 'vava.repairvehicle',
    GIVE_VEHICLE = 'vava.givevehicle',
    
    -- Permissions système
    RESTART = 'vava.restart',
    STOP = 'vava.stop',
    LOGS = 'vava.logs',
    DATABASE = 'vava.database',
    
    -- Permissions modules
    ADMIN_PANEL = 'vava.adminpanel',
    PLAYER_MANAGER = 'vava.playermanager',
    VEHICLE_MANAGER = 'vava.vehiclemanager'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PERMISSIONS JOB
-- ═══════════════════════════════════════════════════════════════════════════

vCore.Permissions.Job = {
    -- Police
    POLICE_HANDCUFF = 'police.handcuff',
    POLICE_SEARCH = 'police.search',
    POLICE_FINE = 'police.fine',
    POLICE_JAIL = 'police.jail',
    POLICE_SEIZE = 'police.seize',
    POLICE_ANNOUNCE = 'police.announce',
    POLICE_ARMORY = 'police.armory',
    POLICE_GARAGE = 'police.garage',
    
    -- Ambulance
    AMBULANCE_REVIVE = 'ambulance.revive',
    AMBULANCE_HEAL = 'ambulance.heal',
    AMBULANCE_ANNOUNCE = 'ambulance.announce',
    AMBULANCE_PHARMACY = 'ambulance.pharmacy',
    AMBULANCE_GARAGE = 'ambulance.garage',
    
    -- Mécano
    MECHANIC_REPAIR = 'mechanic.repair',
    MECHANIC_CLEAN = 'mechanic.clean',
    MECHANIC_IMPOUND = 'mechanic.impound',
    MECHANIC_CRAFT = 'mechanic.craft',
    MECHANIC_GARAGE = 'mechanic.garage'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    -- Serveur uniquement
    
    ---Vérifie si un joueur a une permission ACE
    ---@param source number
    ---@param permission string
    ---@return boolean
    function vCore.Permissions.HasACE(source, permission)
        if Config.Permissions.Method == 'ace' then
            return IsPlayerAceAllowed(source, permission)
        elseif Config.Permissions.Method == 'identifiers' then
            local player = vCore.GetPlayer(source)
            if not player then return false end
            
            local level = player:GetPermissionLevel()
            return level >= vCore.PermissionLevel.ADMIN
        end
        return false
    end
    
    ---Vérifie si un joueur a un niveau de permission minimum
    ---@param source number
    ---@param minLevel number
    ---@return boolean
    function vCore.Permissions.HasLevel(source, minLevel)
        local player = vCore.GetPlayer(source)
        if not player then return false end
        
        return player:GetPermissionLevel() >= minLevel
    end
    
    ---Retourne le niveau de permission d'un joueur
    ---@param source number
    ---@return number, string
    function vCore.Permissions.GetLevel(source)
        local player = vCore.GetPlayer(source)
        if not player then return 0, vCore.PermissionLabel[0] end
        
        local level = player:GetPermissionLevel()
        return level, vCore.PermissionLabel[level] or 'Unknown'
    end
    
    ---Vérifie si un joueur a une permission job
    ---@param source number
    ---@param permission string
    ---@return boolean
    function vCore.Permissions.HasJobPermission(source, permission)
        local player = vCore.GetPlayer(source)
        if not player then return false end
        
        return player:HasJobPermission(permission)
    end
    
    ---Vérifie si un joueur a un job spécifique
    ---@param source number
    ---@param jobName string
    ---@param minGrade? number
    ---@return boolean
    function vCore.Permissions.HasJob(source, jobName, minGrade)
        local player = vCore.GetPlayer(source)
        if not player then return false end
        
        local job = player:GetJob()
        if job.name ~= jobName then return false end
        
        if minGrade and job.grade < minGrade then return false end
        
        return true
    end
    
    ---Vérifie si un joueur est en service
    ---@param source number
    ---@return boolean
    function vCore.Permissions.IsOnDuty(source)
        local player = vCore.GetPlayer(source)
        if not player then return false end
        
        return player:IsOnDuty()
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ALIASES (compatibilité)
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    vCore.HasPermission = vCore.Permissions.HasACE
    vCore.HasPermissionLevel = vCore.Permissions.HasLevel
    vCore.GetPermissionLevel = vCore.Permissions.GetLevel
    vCore.HasJobPermission = vCore.Permissions.HasJobPermission
    vCore.HasJob = vCore.Permissions.HasJob
end

print('^2[vCore:Permissions]^7 Système de permissions chargé')
