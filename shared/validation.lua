--[[
    vAvA_core - Validation System
    Système de validation et sécurisation des données
]]

vCore = vCore or {}
vCore.Validation = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDATION TYPES
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si une valeur est un nombre valide
---@param value any
---@param min? number
---@param max? number
---@return boolean, string?
function vCore.Validation.IsNumber(value, min, max)
    if type(value) ~= 'number' then
        return false, 'La valeur doit être un nombre'
    end
    
    if min and value < min then
        return false, 'La valeur doit être supérieure ou égale à ' .. min
    end
    
    if max and value > max then
        return false, 'La valeur doit être inférieure ou égale à ' .. max
    end
    
    return true
end

---Vérifie si une valeur est une chaîne valide
---@param value any
---@param minLength? number
---@param maxLength? number
---@return boolean, string?
function vCore.Validation.IsString(value, minLength, maxLength)
    if type(value) ~= 'string' then
        return false, 'La valeur doit être une chaîne de caractères'
    end
    
    local len = #value
    
    if minLength and len < minLength then
        return false, 'La longueur minimum est ' .. minLength .. ' caractères'
    end
    
    if maxLength and len > maxLength then
        return false, 'La longueur maximum est ' .. maxLength .. ' caractères'
    end
    
    return true
end

---Vérifie si une valeur est un booléen
---@param value any
---@return boolean, string?
function vCore.Validation.IsBoolean(value)
    if type(value) ~= 'boolean' then
        return false, 'La valeur doit être un booléen (true/false)'
    end
    return true
end

---Vérifie si une valeur est une table
---@param value any
---@return boolean, string?
function vCore.Validation.IsTable(value)
    if type(value) ~= 'table' then
        return false, 'La valeur doit être une table'
    end
    return true
end

---Vérifie si une valeur est une fonction
---@param value any
---@return boolean, string?
function vCore.Validation.IsFunction(value)
    if type(value) ~= 'function' then
        return false, 'La valeur doit être une fonction'
    end
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDATION PATTERNS
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si une chaîne est un email valide
---@param email string
---@return boolean, string?
function vCore.Validation.IsEmail(email)
    if type(email) ~= 'string' then
        return false, 'Email invalide'
    end
    
    local pattern = '^[%w%.%-_]+@[%w%.%-_]+%.%a+$'
    if not string.match(email, pattern) then
        return false, 'Format d\'email invalide'
    end
    
    return true
end

---Vérifie si une chaîne est un numéro de téléphone valide
---@param phone string
---@return boolean, string?
function vCore.Validation.IsPhone(phone)
    if type(phone) ~= 'string' then
        return false, 'Numéro de téléphone invalide'
    end
    
    local pattern = '^%d%d%d%-%d%d%d%d$'
    if not string.match(phone, pattern) then
        return false, 'Format de téléphone invalide (XXX-XXXX)'
    end
    
    return true
end

---Vérifie si une chaîne est une plaque valide
---@param plate string
---@return boolean, string?
function vCore.Validation.IsPlate(plate)
    if type(plate) ~= 'string' then
        return false, 'Plaque invalide'
    end
    
    local len = #plate
    if len < 3 or len > 8 then
        return false, 'La plaque doit contenir entre 3 et 8 caractères'
    end
    
    -- Vérifier caractères alphanumériques uniquement
    if not string.match(plate, '^[%w]+$') then
        return false, 'La plaque ne peut contenir que des lettres et chiffres'
    end
    
    return true
end

---Vérifie si une date de naissance est valide
---@param dob string Format: DD/MM/YYYY
---@param minAge? number
---@return boolean, string?
function vCore.Validation.IsDOB(dob, minAge)
    if type(dob) ~= 'string' then
        return false, 'Date de naissance invalide'
    end
    
    local pattern = '^(%d%d)/(%d%d)/(%d%d%d%d)$'
    local day, month, year = string.match(dob, pattern)
    
    if not day or not month or not year then
        return false, 'Format de date invalide (JJ/MM/AAAA)'
    end
    
    day, month, year = tonumber(day), tonumber(month), tonumber(year)
    
    -- Vérifier validité de la date
    if month < 1 or month > 12 then
        return false, 'Mois invalide'
    end
    
    local daysInMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    
    -- Année bissextile
    if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then
        daysInMonth[2] = 29
    end
    
    if day < 1 or day > daysInMonth[month] then
        return false, 'Jour invalide'
    end
    
    -- Vérifier âge minimum
    if minAge then
        local currentYear = tonumber(os.date('%Y'))
        local age = currentYear - year
        
        if age < minAge then
            return false, 'Âge minimum requis: ' .. minAge .. ' ans'
        end
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDATION GAME DATA
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si un type d'argent est valide
---@param moneyType string
---@return boolean, string?
function vCore.Validation.IsMoneyType(moneyType)
    if not vCore.Utils.TableContains(Config.Economy.MoneyTypes, moneyType) then
        return false, 'Type d\'argent invalide (cash/bank/black_money)'
    end
    return true
end

---Vérifie si un montant est valide
---@param amount number
---@param moneyType? string
---@return boolean, string?
function vCore.Validation.IsAmount(amount, moneyType)
    local valid, err = vCore.Validation.IsNumber(amount, 1)
    if not valid then return false, err end
    
    if moneyType and Config.Economy.MaxCash then
        if amount > Config.Economy.MaxCash then
            return false, 'Montant maximum dépassé: ' .. vCore.Utils.FormatMoney(Config.Economy.MaxCash)
        end
    end
    
    return true
end

---Vérifie si un job existe
---@param jobName string
---@return boolean, string?
function vCore.Validation.IsJob(jobName)
    if not Config.Jobs.List[jobName] then
        return false, 'Job inexistant'
    end
    return true
end

---Vérifie si un grade de job existe
---@param jobName string
---@param grade number
---@return boolean, string?
function vCore.Validation.IsJobGrade(jobName, grade)
    local valid, err = vCore.Validation.IsJob(jobName)
    if not valid then return false, err end
    
    if not Config.Jobs.List[jobName].grades[grade] then
        return false, 'Grade inexistant pour ce job'
    end
    
    return true
end

---Vérifie si un modèle de véhicule est valide
---@param model string|number
---@return boolean, string?
function vCore.Validation.IsVehicleModel(model)
    if type(model) == 'number' then
        return true
    end
    
    if type(model) ~= 'string' then
        return false, 'Modèle de véhicule invalide'
    end
    
    if #model < 3 or #model > 20 then
        return false, 'Nom de modèle trop court ou trop long'
    end
    
    return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SANITIZATION
-- ═══════════════════════════════════════════════════════════════════════════

---Nettoie une chaîne de caractères dangereux
---@param str string
---@return string
function vCore.Validation.Sanitize(str)
    if type(str) ~= 'string' then return '' end
    
    -- Retirer caractères dangereux pour SQL
    str = string.gsub(str, "'", "''")
    str = string.gsub(str, '"', '""')
    str = string.gsub(str, '\\', '\\\\')
    
    -- Retirer caractères de contrôle
    str = string.gsub(str, '%c', '')
    
    return str
end

---Nettoie une chaîne pour l'affichage (HTML/NUI)
---@param str string
---@return string
function vCore.Validation.SanitizeHTML(str)
    if type(str) ~= 'string' then return '' end
    
    str = string.gsub(str, '<', '&lt;')
    str = string.gsub(str, '>', '&gt;')
    str = string.gsub(str, '"', '&quot;')
    str = string.gsub(str, "'", '&#39;')
    str = string.gsub(str, '&', '&amp;')
    
    return str
end

---Limite une chaîne à une longueur maximale
---@param str string
---@param maxLength number
---@return string
function vCore.Validation.LimitLength(str, maxLength)
    if type(str) ~= 'string' then return '' end
    if #str <= maxLength then return str end
    return string.sub(str, 1, maxLength)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VALIDATION COMPLÈTE
-- ═══════════════════════════════════════════════════════════════════════════

---Valide plusieurs règles en une fois
---@param value any
---@param rules table {type, min, max, pattern, custom}
---@return boolean, string?
function vCore.Validation.Validate(value, rules)
    -- Type
    if rules.type then
        local typeCheck = {
            number = vCore.Validation.IsNumber,
            string = vCore.Validation.IsString,
            boolean = vCore.Validation.IsBoolean,
            table = vCore.Validation.IsTable,
            ['function'] = vCore.Validation.IsFunction
        }
        
        local checkFunc = typeCheck[rules.type]
        if checkFunc then
            local valid, err = checkFunc(value, rules.min, rules.max)
            if not valid then return false, err end
        end
    end
    
    -- Pattern custom
    if rules.pattern and type(value) == 'string' then
        if not string.match(value, rules.pattern) then
            return false, rules.patternError or 'Format invalide'
        end
    end
    
    -- Fonction de validation custom
    if rules.custom and type(rules.custom) == 'function' then
        local valid, err = rules.custom(value)
        if not valid then return false, err end
    end
    
    return true
end

print('^2[vCore:Validation]^7 Système de validation chargé')
