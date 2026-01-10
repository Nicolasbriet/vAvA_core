--[[
    vAvA_core - Module Base Class
    Classe de base pour créer des modules facilement
]]

vCore = vCore or {}
vCore.Modules = vCore.Modules or {}
vCore.ModuleBase = {}
vCore.ModuleBase.__index = vCore.ModuleBase

local registeredModules = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATION MODULE
-- ═══════════════════════════════════════════════════════════════════════════

---Crée un nouveau module
---@param name string Nom du module
---@param config table Configuration du module
---@return table Module instance
function vCore.CreateModule(name, config)
    local module = setmetatable({}, vCore.ModuleBase)
    
    -- Propriétés de base
    module.name = name
    module.version = config.version or '1.0.0'
    module.author = config.author or 'Unknown'
    module.description = config.description or ''
    module.dependencies = config.dependencies or {}
    module.config = config.config or {}
    
    -- État
    module.loaded = false
    module.enabled = true
    module.exports = {}
    module.events = {}
    module.commands = {}
    module.callbacks = {}
    module.jobs = {}
    
    -- Lifecycle hooks
    module.onLoad = config.onLoad
    module.onStart = config.onStart
    module.onStop = config.onStop
    module.onPlayerLoaded = config.onPlayerLoaded
    module.onPlayerUnloaded = config.onPlayerUnloaded
    
    registeredModules[name] = module
    
    return module
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════

---Charge le module
function vCore.ModuleBase:Load()
    if self.loaded then
        vCore.Utils.Warn('Module déjà chargé:', self.name)
        return false
    end
    
    -- Vérifier dépendances
    for _, dep in ipairs(self.dependencies) do
        if not registeredModules[dep] or not registeredModules[dep].loaded then
            vCore.Utils.Error('Dépendance manquante pour', self.name, ':', dep)
            return false
        end
    end
    
    -- Hook onLoad
    if self.onLoad then
        local success, err = pcall(self.onLoad, self)
        if not success then
            vCore.Utils.Error('Erreur onLoad', self.name, ':', err)
            return false
        end
    end
    
    self.loaded = true
    TriggerEvent(vCore.Events.MODULE_LOADED, self.name)
    vCore.Utils.Print('Module chargé:', self.name, 'v' .. self.version)
    
    return true
end

---Démarre le module
function vCore.ModuleBase:Start()
    if not self.loaded then
        vCore.Utils.Error('Module non chargé:', self.name)
        return false
    end
    
    if self.onStart then
        local success, err = pcall(self.onStart, self)
        if not success then
            vCore.Utils.Error('Erreur onStart', self.name, ':', err)
            return false
        end
    end
    
    return true
end

---Arrête le module
function vCore.ModuleBase:Stop()
    if self.onStop then
        local success, err = pcall(self.onStop, self)
        if not success then
            vCore.Utils.Error('Erreur onStop', self.name, ':', err)
        end
    end
    
    self.enabled = false
    vCore.Utils.Print('Module arrêté:', self.name)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un export
---@param name string Nom de l'export
---@param func function Fonction à exporter
function vCore.ModuleBase:RegisterExport(name, func)
    self.exports[name] = func
    
    -- Export global si serveur
    if IsDuplicityVersion() then
        exports(self.name, name, func)
    end
end

---Obtient un export d'un autre module
---@param moduleName string
---@param exportName string
---@return function|nil
function vCore.ModuleBase:GetExport(moduleName, exportName)
    local module = registeredModules[moduleName]
    if not module then return nil end
    return module.exports[exportName]
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un événement
---@param eventName string
---@param callback function
function vCore.ModuleBase:RegisterEvent(eventName, callback)
    table.insert(self.events, {
        name = eventName,
        callback = callback
    })
    
    if IsDuplicityVersion() then
        RegisterServerEvent(eventName)
    end
    
    AddEventHandler(eventName, function(...)
        if self.enabled then
            callback(...)
        end
    end)
end

---Déclenche un événement
---@param eventName string
---@param ... any
function vCore.ModuleBase:TriggerEvent(eventName, ...)
    TriggerEvent(eventName, ...)
end

---Déclenche un événement client
---@param target number|table
---@param eventName string
---@param ... any
function vCore.ModuleBase:TriggerClientEvent(target, eventName, ...)
    if IsDuplicityVersion() then
        if type(target) == 'table' then
            for _, playerId in ipairs(target) do
                TriggerClientEvent(eventName, playerId, ...)
            end
        else
            TriggerClientEvent(eventName, target, ...)
        end
    end
end

---Déclenche un événement serveur
---@param eventName string
---@param ... any
function vCore.ModuleBase:TriggerServerEvent(eventName, ...)
    if not IsDuplicityVersion() then
        TriggerServerEvent(eventName, ...)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un callback
---@param name string
---@param callback function
function vCore.ModuleBase:RegisterCallback(name, callback)
    local callbackName = self.name .. ':' .. name
    self.callbacks[name] = callback
    vCore.RegisterCallback(callbackName, callback)
end

---Appelle un callback
---@param name string
---@param callback function
---@param ... any
function vCore.ModuleBase:TriggerCallback(name, callback, ...)
    local callbackName = self.name .. ':' .. name
    vCore.TriggerCallback(callbackName, callback, ...)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre une commande
---@param name string
---@param data table {help, params, minLevel, restricted}
---@param callback function
function vCore.ModuleBase:RegisterCommand(name, data, callback)
    table.insert(self.commands, {name = name, data = data})
    
    if IsDuplicityVersion() and vCore.Commands then
        vCore.Commands.Register(name, data, callback)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- JOBS
-- ═══════════════════════════════════════════════════════════════════════════

---Enregistre un job personnalisé
---@param jobName string
---@param jobData table
function vCore.ModuleBase:RegisterJob(jobName, jobData)
    self.jobs[jobName] = jobData
    
    if IsDuplicityVersion() and Config.Jobs then
        Config.Jobs.List[jobName] = jobData
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DATABASE
-- ═══════════════════════════════════════════════════════════════════════════

---Exécute une requête SQL
---@param query string
---@param params table
---@return any
function vCore.ModuleBase:Query(query, params)
    return vCore.DB.Query(query, params)
end

---Exécute une requête SQL et retourne le premier résultat
---@param query string
---@param params table
---@return table|nil
function vCore.ModuleBase:QuerySingle(query, params)
    return vCore.DB.Single(query, params)
end

---Insère dans la base de données
---@param query string
---@param params table
---@return number ID inséré
function vCore.ModuleBase:Insert(query, params)
    return vCore.DB.Insert(query, params)
end

---Exécute une requête de modification
---@param query string
---@param params table
---@return number Lignes affectées
function vCore.ModuleBase:Execute(query, params)
    return vCore.DB.Execute(query, params)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

---Obtient une valeur de config
---@param key string
---@param default? any
---@return any
function vCore.ModuleBase:GetConfig(key, default)
    local keys = vCore.Utils.Split(key, '.')
    local value = self.config
    
    for _, k in ipairs(keys) do
        if type(value) ~= 'table' then return default end
        value = value[k]
        if value == nil then return default end
    end
    
    return value
end

---Définit une valeur de config
---@param key string
---@param value any
function vCore.ModuleBase:SetConfig(key, value)
    local keys = vCore.Utils.Split(key, '.')
    local config = self.config
    
    for i = 1, #keys - 1 do
        local k = keys[i]
        if type(config[k]) ~= 'table' then
            config[k] = {}
        end
        config = config[k]
    end
    
    config[keys[#keys]] = value
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS UI
-- ═══════════════════════════════════════════════════════════════════════════

---Affiche une notification
---@param target number
---@param message string
---@param type string
---@param duration? number
function vCore.ModuleBase:Notify(target, message, type, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, message, type, duration)
    else
        if vCore.UI then
            vCore.UI.Notify(message, type, duration)
        end
    end
end

---Affiche un menu
---@param target number
---@param menuData table
function vCore.ModuleBase:ShowMenu(target, menuData)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_SHOW_MENU, target, menuData)
    else
        if vCore.UI then
            vCore.UI.ShowMenu(menuData)
        end
    end
end

---Affiche une progress bar
---@param target number
---@param label string
---@param duration number
---@param options? table
function vCore.ModuleBase:ShowProgressBar(target, label, duration, options)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_PROGRESS_START, target, label, duration, options)
    else
        if vCore.UI then
            vCore.UI.ShowProgressBar(label, duration, options)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGS
-- ═══════════════════════════════════════════════════════════════════════════

---Log une information
---@param ... any
function vCore.ModuleBase:Log(...)
    local args = {...}
    local message = table.concat(args, ' ')
    vCore.Utils.Print('[' .. self.name .. ']', message)
end

---Log un debug
---@param ... any
function vCore.ModuleBase:Debug(...)
    if self:GetConfig('debug', false) then
        local args = {...}
        local message = table.concat(args, ' ')
        vCore.Utils.Debug('[' .. self.name .. ']', message)
    end
end

---Log une erreur
---@param ... any
function vCore.ModuleBase:Error(...)
    local args = {...}
    local message = table.concat(args, ' ')
    vCore.Utils.Error('[' .. self.name .. ']', message)
end

---Log dans la base de données
---@param type string
---@param source number|string
---@param message string
---@param data? table
function vCore.ModuleBase:LogDB(type, source, message, data)
    if IsDuplicityVersion() and vCore.DB then
        vCore.DB.AddLog(self.name .. ':' .. type, tostring(source), message, data)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Obtient un joueur
---@param source number
---@return vPlayer|nil
function vCore.ModuleBase:GetPlayer(source)
    if IsDuplicityVersion() then
        return vCore.GetPlayer(source)
    end
    return nil
end

---Obtient tous les joueurs
---@return table
function vCore.ModuleBase:GetPlayers()
    if IsDuplicityVersion() then
        return vCore.GetPlayers()
    end
    return {}
end

---Vérifie les permissions
---@param source number
---@param permission string|number
---@return boolean
function vCore.ModuleBase:HasPermission(source, permission)
    if IsDuplicityVersion() then
        if type(permission) == 'number' then
            return vCore.Permissions.HasLevel(source, permission)
        else
            return vCore.Permissions.HasACE(source, permission)
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

---Obtient un module
---@param name string
---@return table|nil
function vCore.GetModule(name)
    return registeredModules[name]
end

---Obtient tous les modules
---@return table
function vCore.GetModules()
    return registeredModules
end

---Vérifie si un module est chargé
---@param name string
---@return boolean
function vCore.IsModuleLoaded(name)
    local module = registeredModules[name]
    return module ~= nil and module.loaded
end

print('^2[vCore:ModuleBase]^7 Système de modules avancé chargé')
