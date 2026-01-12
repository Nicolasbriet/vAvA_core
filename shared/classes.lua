--[[
    vAvA_core - Classes et objets
]]

vCore = vCore or {}
vCore.Classes = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CLASSE PLAYER
-- ═══════════════════════════════════════════════════════════════════════════

---@class vPlayer
---@field source number
---@field identifier string
---@field name string
---@field charId number
---@field firstName string
---@field lastName string
---@field dob string
---@field gender number
---@field money table
---@field job table
---@field gang table
---@field position table
---@field status table
---@field inventory table
---@field metadata table
---@field group string
---@field onDuty boolean
local vPlayer = {}
vPlayer.__index = vPlayer

---Crée un nouvel objet joueur
---@param data table
---@return vPlayer
function vCore.Classes.CreatePlayer(data)
    local self = setmetatable({}, vPlayer)
    
    self.source = data.source
    self.identifier = data.identifier
    self.name = data.name or 'Unknown'
    self.charId = data.charId or 0
    self.firstName = data.firstName or ''
    self.lastName = data.lastName or ''
    self.dob = data.dob or '01/01/2000'
    self.gender = data.gender or 0
    
    self.money = data.money or {
        cash = Config.Players.StartingMoney.cash,
        bank = Config.Players.StartingMoney.bank,
        black_money = Config.Players.StartingMoney.black_money
    }
    
    self.job = data.job or {
        name = Config.Jobs.DefaultJob,
        label = 'Chômeur',
        grade = Config.Jobs.DefaultGrade,
        gradeLabel = 'Sans emploi',
        salary = 0,
        permissions = {}
    }
    
    self.gang = data.gang or {
        name = 'none',
        label = 'Aucun',
        grade = 0,
        gradeLabel = ''
    }
    
    self.position = data.position or Config.Players.DefaultSpawn
    
    self.status = data.status or {
        hunger = Config.Players.StartingStatus.hunger,
        thirst = Config.Players.StartingStatus.thirst,
        stress = Config.Players.StartingStatus.stress
    }
    
    self.inventory = data.inventory or {}
    self.metadata = data.metadata or {}
    self.group = data.group or 'user'
    self.onDuty = data.onDuty or false
    
    return self
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - IDENTIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne le source du joueur
---@return number
function vPlayer:GetSource()
    return self.source
end

---Retourne l'identifiant du joueur
---@return string
function vPlayer:GetIdentifier()
    return self.identifier
end

---Retourne le nom complet du joueur
---@return string
function vPlayer:GetName()
    return self.firstName .. ' ' .. self.lastName
end

---Retourne l'ID du personnage
---@return number
function vPlayer:GetCharId()
    return self.charId
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - ARGENT
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne l'argent d'un type
---@param moneyType string
---@return number
function vPlayer:GetMoney(moneyType)
    return self.money[moneyType] or 0
end

---Ajoute de l'argent
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vPlayer:AddMoney(moneyType, amount, reason)
    if amount <= 0 then return false end
    if not self.money[moneyType] then return false end
    
    self.money[moneyType] = self.money[moneyType] + amount
    
    TriggerEvent(vCore.Events.MONEY_ADDED, self.source, moneyType, amount, reason)
    TriggerClientEvent(vCore.Events.MONEY_ADDED, self.source, moneyType, amount)
    
    return true
end

---Retire de l'argent
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vPlayer:RemoveMoney(moneyType, amount, reason)
    if amount <= 0 then return false end
    if not self.money[moneyType] then return false end
    if self.money[moneyType] < amount then return false end
    
    self.money[moneyType] = self.money[moneyType] - amount
    
    TriggerEvent(vCore.Events.MONEY_REMOVED, self.source, moneyType, amount, reason)
    TriggerClientEvent(vCore.Events.MONEY_REMOVED, self.source, moneyType, amount)
    
    return true
end

---Définit l'argent
---@param moneyType string
---@param amount number
---@param reason? string
---@return boolean
function vPlayer:SetMoney(moneyType, amount, reason)
    if amount < 0 then return false end
    if not self.money[moneyType] then return false end
    
    self.money[moneyType] = amount
    
    TriggerEvent(vCore.Events.MONEY_SET, self.source, moneyType, amount, reason)
    TriggerClientEvent(vCore.Events.MONEY_SET, self.source, moneyType, amount)
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - JOB
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne le job
---@return table
function vPlayer:GetJob()
    return self.job
end

---Définit le job
---@param jobName string
---@param grade number
---@return boolean
function vPlayer:SetJob(jobName, grade)
    local jobData = Config.Jobs.List[jobName]
    if not jobData then return false end
    
    local gradeData = jobData.grades[grade]
    if not gradeData then return false end
    
    self.job = {
        name = jobName,
        label = jobData.label,
        grade = grade,
        gradeLabel = gradeData.label,
        salary = gradeData.salary,
        permissions = gradeData.permissions or {}
    }
    
    TriggerEvent(vCore.Events.JOB_CHANGED, self.source, self.job)
    TriggerClientEvent(vCore.Events.JOB_CHANGED, self.source, self.job)
    
    return true
end

---Vérifie si le joueur a une permission job
---@param permission string
---@return boolean
function vPlayer:HasJobPermission(permission)
    return vCore.Utils.TableContains(self.job.permissions, permission)
end

---Définit l'état de service
---@param onDuty boolean
function vPlayer:SetDuty(onDuty)
    self.onDuty = onDuty
    TriggerEvent(vCore.Events.JOB_DUTY_CHANGED, self.source, onDuty)
    TriggerClientEvent(vCore.Events.JOB_DUTY_CHANGED, self.source, onDuty)
end

---Vérifie si en service
---@return boolean
function vPlayer:IsOnDuty()
    return self.onDuty
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - GANG
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne le gang
---@return table
function vPlayer:GetGang()
    return self.gang
end

---Définit le gang
---@param gangName string
---@param grade number
---@return boolean
function vPlayer:SetGang(gangName, grade)
    self.gang = {
        name = gangName,
        grade = grade
    }
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - STATUS
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne un status
---@param statusType string
---@return number
function vPlayer:GetStatus(statusType)
    -- Intégration avec le module vAvA_status pour faim/soif (côté serveur uniquement)
    if IsDuplicityVersion() then
        if statusType == 'hunger' and GetResourceState('vAvA_status') == 'started' then
            return exports['vAvA_status']:GetHunger(self.source) or self.status[statusType] or 0
        elseif statusType == 'thirst' and GetResourceState('vAvA_status') == 'started' then
            return exports['vAvA_status']:GetThirst(self.source) or self.status[statusType] or 0
        end
    end
    
    return self.status[statusType] or 0
end

---Définit un status
---@param statusType string
---@param value number
function vPlayer:SetStatus(statusType, value)
    value = vCore.Utils.Clamp(value, 0, 100)
    self.status[statusType] = value
    
    -- Intégration avec le module vAvA_status pour faim/soif
    if statusType == 'hunger' and GetResourceState('vAvA_status') == 'started' then
        exports['vAvA_status']:SetHunger(self.source, value)
        return -- Le module status se charge du client event
    elseif statusType == 'thirst' and GetResourceState('vAvA_status') == 'started' then
        exports['vAvA_status']:SetThirst(self.source, value)
        return -- Le module status se charge du client event
    end
    
    -- Fallback pour autres status (stress, etc.)
    TriggerClientEvent(vCore.Events.STATUS_UPDATED, self.source, statusType, value)
end

---Ajoute à un status
---@param statusType string
---@param value number
function vPlayer:AddStatus(statusType, value)
    -- Intégration avec le module vAvA_status pour faim/soif
    if statusType == 'hunger' and GetResourceState('vAvA_status') == 'started' then
        exports['vAvA_status']:AddHunger(self.source, value)
        return
    elseif statusType == 'thirst' and GetResourceState('vAvA_status') == 'started' then
        exports['vAvA_status']:AddThirst(self.source, value)
        return
    end
    
    -- Fallback pour autres status
    local current = self:GetStatus(statusType)
    self:SetStatus(statusType, current + value)
end

---Retire d'un status
---@param statusType string
---@param value number
function vPlayer:RemoveStatus(statusType, value)
    -- Pour hunger/thirst, AddStatus avec valeur négative
    if statusType == 'hunger' or statusType == 'thirst' then
        self:AddStatus(statusType, -value)
        return
    end
    
    -- Fallback pour autres status
    local current = self:GetStatus(statusType)
    self:SetStatus(statusType, current - value)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - INVENTAIRE
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne l'inventaire
---@return table
function vPlayer:GetInventory()
    return self.inventory
end

---Vérifie si le joueur a un item
---@param itemName string
---@param amount? number
---@return boolean
function vPlayer:HasItem(itemName, amount)
    amount = amount or 1
    for _, item in pairs(self.inventory) do
        if item.name == itemName and item.amount >= amount then
            return true
        end
    end
    return false
end

---Retourne un item
---@param itemName string
---@return table|nil
function vPlayer:GetItem(itemName)
    for _, item in pairs(self.inventory) do
        if item.name == itemName then
            return item
        end
    end
    return nil
end

---Calcule le poids total de l'inventaire
---@return number
function vPlayer:GetInventoryWeight()
    local weight = 0
    for _, item in pairs(self.inventory) do
        weight = weight + (item.weight or 0) * item.amount
    end
    return weight
end

---Vérifie si l'inventaire peut contenir un poids
---@param weight number
---@return boolean
function vPlayer:CanCarry(weight)
    return (self:GetInventoryWeight() + weight) <= Config.Inventory.MaxWeight
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - POSITION
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne la position
---@return table
function vPlayer:GetPosition()
    return self.position
end

---Définit la position
---@param x number
---@param y number
---@param z number
---@param heading? number
function vPlayer:SetPosition(x, y, z, heading)
    self.position = {
        x = x,
        y = y,
        z = z,
        heading = heading or 0.0
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - MÉTADONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne une métadonnée
---@param key string
---@return any
function vPlayer:GetMetadata(key)
    return self.metadata[key]
end

---Définit une métadonnée
---@param key string
---@param value any
function vPlayer:SetMetadata(key, value)
    self.metadata[key] = value
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - GROUPE/PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne le groupe
---@return string
function vPlayer:GetGroup()
    return self.group
end

---Définit le groupe
---@param group string
function vPlayer:SetGroup(group)
    self.group = group
end

---Vérifie si le joueur est admin
---@return boolean
function vPlayer:IsAdmin()
    if IsDuplicityVersion() and Config.Permissions.Method == 'ace' then
        -- Vérifier les ACE de txAdmin
        return vCore.Permissions.HasACE(self.source, 'vava.admin') or
               vCore.Permissions.HasACE(self.source, 'vava.superadmin') or
               vCore.Permissions.HasACE(self.source, 'vava.developer') or
               vCore.Permissions.HasACE(self.source, 'vava.owner')
    else
        -- Fallback sur les groupes internes
        local level = Config.Admin.Groups[self.group] or 0
        return level >= vCore.AdminLevel.ADMIN
    end
end

---Retourne le niveau de permission (0-5)
---@return number
function vPlayer:GetPermissionLevel()
    if IsDuplicityVersion() and Config.Permissions.Method == 'ace' then
        -- Vérifier les ACE de txAdmin (ordre de priorité)
        for groupName, groupData in pairs(Config.Permissions.AceLevels) do
            for _, ace in ipairs(groupData.aces) do
                if vCore.Permissions.HasACE(self.source, ace) then
                    return groupData.level
                end
            end
        end
        return 0 -- USER par défaut
    else
        -- Fallback sur les groupes internes
        return Config.Admin.Groups[self.group] or 0
    end
end

---Vérifie si le joueur a un niveau de permission minimum
---@param level number
---@return boolean
function vPlayer:HasPermission(level)
    return self:GetPermissionLevel() >= level
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MÉTHODES PLAYER - SÉRIALISATION
-- ═══════════════════════════════════════════════════════════════════════════

---Convertit le joueur en table (pour sauvegarde)
---@return table
function vPlayer:ToTable()
    return {
        identifier = self.identifier,
        charId = self.charId,
        firstName = self.firstName,
        lastName = self.lastName,
        dob = self.dob,
        gender = self.gender,
        money = self.money,
        job = self.job,
        gang = self.gang,
        position = self.position,
        status = self.status,
        inventory = self.inventory,
        metadata = self.metadata,
        group = self.group
    }
end

---Convertit le joueur pour le client (données limitées)
---@return table
function vPlayer:ToClientData()
    return {
        charId = self.charId,
        firstName = self.firstName,
        lastName = self.lastName,
        dob = self.dob,
        gender = self.gender,
        money = self.money,
        job = self.job,
        gang = self.gang,
        position = self.position,  -- ✅ Position pour le spawn
        status = self.status,
        onDuty = self.onDuty,
        group = self.group,
        metadata = self.metadata
    }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CLASSE ITEM
-- ═══════════════════════════════════════════════════════════════════════════

---@class vItem
---@field name string
---@field label string
---@field description string
---@field weight number
---@field type string
---@field unique boolean
---@field useable boolean
---@field image string
---@field metadata table
local vItem = {}
vItem.__index = vItem

---Crée un nouvel item
---@param data table
---@return vItem
function vCore.Classes.CreateItem(data)
    local self = setmetatable({}, vItem)
    
    self.name = data.name
    self.label = data.label or data.name
    self.description = data.description or ''
    self.weight = data.weight or 100
    self.type = data.type or vCore.ItemType.ITEM
    self.unique = data.unique or false
    self.useable = data.useable or false
    self.image = data.image or (data.name .. '.png')
    self.metadata = data.metadata or {}
    
    return self
end

-- Export des classes
vCore.Player = vPlayer
vCore.Item = vItem
