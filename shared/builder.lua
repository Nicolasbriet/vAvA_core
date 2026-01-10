--[[
    vAvA_core - Builder Class
    Classe builder pour créer des structures complexes facilement
]]

vCore = vCore or {}
vCore.Builder = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU BUILDER
-- ═══════════════════════════════════════════════════════════════════════════

---@class MenuBuilder
local MenuBuilder = {}
MenuBuilder.__index = MenuBuilder

---Crée un nouveau menu builder
---@param title string
---@return MenuBuilder
function vCore.Builder.Menu(title)
    local self = setmetatable({}, MenuBuilder)
    
    self.data = {
        title = title,
        subtitle = '',
        elements = {},
        onSelect = nil,
        onClose = nil
    }
    
    return self
end

---Définit le sous-titre
---@param subtitle string
---@return MenuBuilder
function MenuBuilder:SetSubtitle(subtitle)
    self.data.subtitle = subtitle
    return self
end

---Ajoute un élément
---@param label string
---@param value any
---@param description? string
---@return MenuBuilder
function MenuBuilder:AddElement(label, value, description)
    table.insert(self.data.elements, {
        label = label,
        value = value,
        description = description or ''
    })
    return self
end

---Ajoute plusieurs éléments
---@param elements table
---@return MenuBuilder
function MenuBuilder:AddElements(elements)
    for _, elem in ipairs(elements) do
        self:AddElement(elem.label, elem.value, elem.description)
    end
    return self
end

---Définit le callback de sélection
---@param callback function
---@return MenuBuilder
function MenuBuilder:OnSelect(callback)
    self.data.onSelect = callback
    return self
end

---Définit le callback de fermeture
---@param callback function
---@return MenuBuilder
function MenuBuilder:OnClose(callback)
    self.data.onClose = callback
    return self
end

---Construit et affiche le menu
---@param target? number Source du joueur (serveur) ou nil (client)
function MenuBuilder:Show(target)
    if IsDuplicityVersion() and target then
        TriggerClientEvent(vCore.Events.UI_SHOW_MENU, target, self.data)
    elseif not IsDuplicityVersion() then
        vCore.UI.ShowMenu(self.data, self.data.onSelect, self.data.onClose)
    end
end

---Obtient les données du menu
---@return table
function MenuBuilder:Build()
    return self.data
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION BUILDER
-- ═══════════════════════════════════════════════════════════════════════════

---@class NotificationBuilder
local NotificationBuilder = {}
NotificationBuilder.__index = NotificationBuilder

---Crée une notification builder
---@param message string
---@return NotificationBuilder
function vCore.Builder.Notification(message)
    local self = setmetatable({}, NotificationBuilder)
    
    self.data = {
        message = message,
        type = 'info',
        duration = 5000
    }
    
    return self
end

---Type de notification
---@param type string success|error|warning|info
---@return NotificationBuilder
function NotificationBuilder:Type(type)
    self.data.type = type
    return self
end

---Durée en ms
---@param duration number
---@return NotificationBuilder
function NotificationBuilder:Duration(duration)
    self.data.duration = duration
    return self
end

---Affiche la notification
---@param target? number
function NotificationBuilder:Show(target)
    if IsDuplicityVersion() and target then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, self.data.message, self.data.type, self.data.duration)
    elseif not IsDuplicityVersion() then
        vCore.UI.Notify(self.data.message, self.data.type, self.data.duration)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PROGRESS BUILDER
-- ═══════════════════════════════════════════════════════════════════════════

---@class ProgressBuilder
local ProgressBuilder = {}
ProgressBuilder.__index = ProgressBuilder

---Crée un progress bar builder
---@param label string
---@param duration number
---@return ProgressBuilder
function vCore.Builder.Progress(label, duration)
    local self = setmetatable({}, ProgressBuilder)
    
    self.data = {
        label = label,
        duration = duration,
        options = {
            canCancel = false,
            animation = nil,
            prop = nil,
            onComplete = nil,
            onCancel = nil
        }
    }
    
    return self
end

---Peut être annulé
---@param canCancel boolean
---@return ProgressBuilder
function ProgressBuilder:CanCancel(canCancel)
    self.data.options.canCancel = canCancel
    return self
end

---Animation
---@param dict string
---@param name string
---@return ProgressBuilder
function ProgressBuilder:Animation(dict, name)
    self.data.options.animation = {dict = dict, name = name}
    return self
end

---Prop
---@param model string
---@param bone number
---@param pos table
---@param rot table
---@return ProgressBuilder
function ProgressBuilder:Prop(model, bone, pos, rot)
    self.data.options.prop = {
        model = model,
        bone = bone,
        pos = pos,
        rot = rot
    }
    return self
end

---Callback à la fin
---@param callback function
---@return ProgressBuilder
function ProgressBuilder:OnComplete(callback)
    self.data.options.onComplete = callback
    return self
end

---Callback si annulé
---@param callback function
---@return ProgressBuilder
function ProgressBuilder:OnCancel(callback)
    self.data.options.onCancel = callback
    return self
end

---Affiche le progress bar
---@param target? number
function ProgressBuilder:Show(target)
    if IsDuplicityVersion() and target then
        TriggerClientEvent(vCore.Events.UI_PROGRESS_START, target, self.data.label, self.data.duration, self.data.options)
    elseif not IsDuplicityVersion() then
        vCore.UI.ShowProgressBar(self.data.label, self.data.duration, self.data.options)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- QUERY BUILDER (SQL)
-- ═══════════════════════════════════════════════════════════════════════════

---@class QueryBuilder
local QueryBuilder = {}
QueryBuilder.__index = QueryBuilder

---Crée un query builder
---@param table string
---@return QueryBuilder
function vCore.Builder.Query(table)
    local self = setmetatable({}, QueryBuilder)
    
    self.table = table
    self.type = 'SELECT'
    self.columns = {'*'}
    self.whereConditions = {}
    self.orderBy = nil
    self.limitValue = nil
    self.offsetValue = nil
    self.params = {}
    
    return self
end

---Sélectionne des colonnes
---@param ... string
---@return QueryBuilder
function QueryBuilder:Select(...)
    self.type = 'SELECT'
    self.columns = {...}
    return self
end

---Condition WHERE
---@param column string
---@param operator string
---@param value any
---@return QueryBuilder
function QueryBuilder:Where(column, operator, value)
    table.insert(self.whereConditions, {column = column, operator = operator, value = value})
    table.insert(self.params, value)
    return self
end

---ORDER BY
---@param column string
---@param direction? string ASC|DESC
---@return QueryBuilder
function QueryBuilder:OrderBy(column, direction)
    self.orderBy = {column = column, direction = direction or 'ASC'}
    return self
end

---LIMIT
---@param limit number
---@return QueryBuilder
function QueryBuilder:Limit(limit)
    self.limitValue = limit
    return self
end

---OFFSET
---@param offset number
---@return QueryBuilder
function QueryBuilder:Offset(offset)
    self.offsetValue = offset
    return self
end

---Construit la requête SQL
---@return string, table
function QueryBuilder:Build()
    local query = self.type .. ' ' .. table.concat(self.columns, ', ') .. ' FROM ' .. self.table
    
    -- WHERE
    if #self.whereConditions > 0 then
        local conditions = {}
        for _, cond in ipairs(self.whereConditions) do
            table.insert(conditions, cond.column .. ' ' .. cond.operator .. ' ?')
        end
        query = query .. ' WHERE ' .. table.concat(conditions, ' AND ')
    end
    
    -- ORDER BY
    if self.orderBy then
        query = query .. ' ORDER BY ' .. self.orderBy.column .. ' ' .. self.orderBy.direction
    end
    
    -- LIMIT
    if self.limitValue then
        query = query .. ' LIMIT ' .. self.limitValue
    end
    
    -- OFFSET
    if self.offsetValue then
        query = query .. ' OFFSET ' .. self.offsetValue
    end
    
    return query, self.params
end

---Exécute la requête
---@return table
function QueryBuilder:Execute()
    local query, params = self:Build()
    return vCore.DB.Query(query, params)
end

---Exécute et retourne le premier résultat
---@return table|nil
function QueryBuilder:First()
    local query, params = self:Build()
    return vCore.DB.Single(query, params)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMAND BUILDER
-- ═══════════════════════════════════════════════════════════════════════════

---@class CommandBuilder
local CommandBuilder = {}
CommandBuilder.__index = CommandBuilder

---Crée un command builder
---@param name string
---@return CommandBuilder
function vCore.Builder.Command(name)
    local self = setmetatable({}, CommandBuilder)
    
    self.name = name
    self.data = {
        help = '',
        params = {},
        minLevel = 0,
        restricted = false
    }
    self.callback = nil
    
    return self
end

---Aide de la commande
---@param help string
---@return CommandBuilder
function CommandBuilder:Help(help)
    self.data.help = help
    return self
end

---Ajoute un paramètre
---@param name string
---@param help string
---@param required? boolean
---@return CommandBuilder
function CommandBuilder:Param(name, help, required)
    table.insert(self.data.params, {
        name = name,
        help = help,
        required = required or false
    })
    return self
end

---Niveau minimum requis
---@param level number
---@return CommandBuilder
function CommandBuilder:MinLevel(level)
    self.data.minLevel = level
    self.data.restricted = true
    return self
end

---Fonction callback
---@param callback function
---@return CommandBuilder
function CommandBuilder:Handler(callback)
    self.callback = callback
    return self
end

---Enregistre la commande
function CommandBuilder:Register()
    if IsDuplicityVersion() and vCore.Commands then
        vCore.Commands.Register(self.name, self.data, self.callback)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SHORTCUTS
-- ═══════════════════════════════════════════════════════════════════════════

---Menu rapide
---@param title string
---@return MenuBuilder
function vCore.Menu(title)
    return vCore.Builder.Menu(title)
end

---Notification rapide
---@param message string
---@return NotificationBuilder
function vCore.Notify(message)
    return vCore.Builder.Notification(message)
end

---Progress rapide
---@param label string
---@param duration number
---@return ProgressBuilder
function vCore.Progress(label, duration)
    return vCore.Builder.Progress(label, duration)
end

---Query rapide
---@param table string
---@return QueryBuilder
function vCore.Query(table)
    return vCore.Builder.Query(table)
end

---Command rapide
---@param name string
---@return CommandBuilder
function vCore.Command(name)
    return vCore.Builder.Command(name)
end

print('^2[vCore:Builder]^7 Système Builder chargé')
