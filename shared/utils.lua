--[[
    vAvA_core - Utilitaires partagés
]]

vCore = vCore or {}
vCore.Utils = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE TRADUCTION
-- ═══════════════════════════════════════════════════════════════════════════

---@param key string Clé de traduction
---@param ... any Variables à injecter
---@return string
function Lang(key, ...)
    local locale = Config.Locale or 'fr'
    local translations = Locales[locale]
    
    if not translations then
        translations = Locales['fr'] or {}
    end
    
    local text = translations[key]
    
    if not text then
        return '[MISSING: ' .. key .. ']'
    end
    
    local args = {...}
    
    if #args > 0 then
        -- Support des arguments nommés {amount = 500}
        if type(args[1]) == 'table' then
            for k, v in pairs(args[1]) do
                text = string.gsub(text, '%%{' .. k .. '}', tostring(v))
            end
        else
            -- Support des arguments positionnels
            text = string.format(text, ...)
        end
    end
    
    return text
end

-- Alias global
_L = Lang

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

---Formate un nombre avec séparateur de milliers
---@param number number
---@return string
function vCore.Utils.FormatNumber(number)
    local formatted = tostring(number)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1 %2')
        if k == 0 then break end
    end
    return formatted
end

---Formate un montant en devise
---@param amount number
---@return string
function vCore.Utils.FormatMoney(amount)
    return '$' .. vCore.Utils.FormatNumber(amount)
end

---Génère un identifiant unique
---@return string
function vCore.Utils.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

---Génère une chaîne aléatoire
---@param length number
---@return string
function vCore.Utils.RandomString(length)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local result = ''
    for i = 1, length do
        local index = math.random(1, #chars)
        result = result .. string.sub(chars, index, index)
    end
    return result
end

---Clone une table
---@param original table
---@return table
function vCore.Utils.DeepClone(original)
    local copy
    if type(original) == 'table' then
        copy = {}
        for key, value in next, original, nil do
            copy[vCore.Utils.DeepClone(key)] = vCore.Utils.DeepClone(value)
        end
        setmetatable(copy, vCore.Utils.DeepClone(getmetatable(original)))
    else
        copy = original
    end
    return copy
end

---Fusionne deux tables
---@param t1 table
---@param t2 table
---@return table
function vCore.Utils.MergeTables(t1, t2)
    local result = vCore.Utils.DeepClone(t1)
    for k, v in pairs(t2) do
        if type(v) == 'table' and type(result[k]) == 'table' then
            result[k] = vCore.Utils.MergeTables(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end

---Vérifie si une table contient une valeur
---@param table table
---@param value any
---@return boolean
function vCore.Utils.TableContains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

---Compte les éléments d'une table
---@param table table
---@return number
function vCore.Utils.TableCount(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

---Convertit une table en JSON
---@param data any
---@return string
function vCore.Utils.ToJSON(data)
    return json.encode(data)
end

---Parse une chaîne JSON
---@param str string
---@return any
function vCore.Utils.FromJSON(str)
    if not str or str == '' then return nil end
    return json.decode(str)
end

---Trim une chaîne
---@param str string
---@return string
function vCore.Utils.Trim(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

---Split une chaîne
---@param str string
---@param delimiter string
---@return table
function vCore.Utils.Split(str, delimiter)
    local result = {}
    for match in (str .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

---Formate un timestamp en date lisible
---@param timestamp number
---@param format? string
---@return string
function vCore.Utils.FormatDate(timestamp, format)
    format = format or '%d/%m/%Y %H:%M:%S'
    return os.date(format, timestamp)
end

---Retourne le timestamp actuel
---@return number
function vCore.Utils.GetTimestamp()
    return os.time()
end

---Calcule la différence entre deux timestamps
---@param t1 number
---@param t2 number
---@return table {days, hours, minutes, seconds}
function vCore.Utils.TimeDiff(t1, t2)
    local diff = math.abs(t2 - t1)
    return {
        days = math.floor(diff / 86400),
        hours = math.floor((diff % 86400) / 3600),
        minutes = math.floor((diff % 3600) / 60),
        seconds = diff % 60
    }
end

---Arrondit un nombre
---@param number number
---@param decimals? number
---@return number
function vCore.Utils.Round(number, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(number * mult + 0.5) / mult
end

---Limite un nombre entre min et max
---@param value number
---@param min number
---@param max number
---@return number
function vCore.Utils.Clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

---Génère un nombre aléatoire entre min et max
---@param min number
---@param max number
---@return number
function vCore.Utils.Random(min, max)
    return math.random(min, max)
end

---Calcule la distance entre deux points 3D
---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return number
function vCore.Utils.GetDistance(x1, y1, z1, x2, y2, z2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

---Calcule la distance entre deux vecteurs
---@param vec1 vector3
---@param vec2 vector3
---@return number
function vCore.Utils.GetDistanceVector(vec1, vec2)
    return #(vec1 - vec2)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PRINT DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

---Print debug avec formatage
---@param ... any
function vCore.Utils.Debug(...)
    if not Config.Debug then return end
    
    local args = {...}
    local message = ''
    
    for i, v in ipairs(args) do
        if type(v) == 'table' then
            message = message .. json.encode(v)
        else
            message = message .. tostring(v)
        end
        if i < #args then
            message = message .. ' '
        end
    end
    
    print('^3[vCore:Debug]^7 ' .. message)
end

---Print info
---@param ... any
function vCore.Utils.Print(...)
    local args = {...}
    local message = ''
    
    for i, v in ipairs(args) do
        if type(v) == 'table' then
            message = message .. json.encode(v)
        else
            message = message .. tostring(v)
        end
        if i < #args then
            message = message .. ' '
        end
    end
    
    print('^2[vCore]^7 ' .. message)
end

---Print erreur
---@param ... any
function vCore.Utils.Error(...)
    local args = {...}
    local message = ''
    
    for i, v in ipairs(args) do
        if type(v) == 'table' then
            message = message .. json.encode(v)
        else
            message = message .. tostring(v)
        end
        if i < #args then
            message = message .. ' '
        end
    end
    
    print('^1[vCore:Error]^7 ' .. message)
end

---Print warning
---@param ... any
function vCore.Utils.Warn(...)
    local args = {...}
    local message = ''
    
    for i, v in ipairs(args) do
        if type(v) == 'table' then
            message = message .. json.encode(v)
        else
            message = message .. tostring(v)
        end
        if i < #args then
            message = message .. ' '
        end
    end
    
    print('^3[vCore:Warning]^7 ' .. message)
end
