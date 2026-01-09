-- ============================================
-- vAvA Target - Shared Locale Helper
-- Système de traduction autonome
-- ============================================

Locales = Locales or {}
CurrentLocale = TargetConfig and TargetConfig.Language or 'fr'

-- Fonction helper pour obtenir une traduction
function Lang(key, vars)
    local locale = Locales[CurrentLocale]
    
    if not locale then
        print('[vAvA Target] Locale not found: ' .. CurrentLocale)
        return key
    end
    
    local text = locale[key]
    
    if not text then
        print('[vAvA Target] Translation not found: ' .. key)
        return key
    end
    
    if vars then
        for k, v in pairs(vars) do
            text = text:gsub('{' .. k .. '}', tostring(v))
            text = text:gsub('%%s', tostring(v), 1)
        end
    end
    
    return text
end

-- Fonction pour changer la langue
function SetLocale(locale)
    if Locales[locale] then
        CurrentLocale = locale
        if TargetConfig then
            TargetConfig.Language = locale
        end
        return true
    end
    return false
end

-- Export
_G.Lang = Lang
_G.SetLocale = SetLocale
