--[[
    vava_atelier/shared/text.lua
    Rôle : logique pure des textes de l'Atelier : UTF-8 valide, longueur en caractères, caractères de contrôle, jeux
           de caractères d'un champ (`name`, `id`, `free`), normalisation pour la recherche (accents et casse ignorés),
           coupe sans briser un caractère, nombres et durées écrits à la française (messages d'erreur).
           Testée : tests/spec/atelier_text_spec.lua.
    Dépendances : shared/constants.lua
]]

local type, ipairs, floor, tointeger = type, ipairs, math.floor, math.tointeger
local utf8len, utf8codes, utf8char = utf8.len, utf8.codes, utf8.char
local byte, find, format, gsub = string.byte, string.find, string.format, string.gsub
local char, sub = string.char, string.sub
local concat = table.concat

local text = {}
VavaAtelier.text = text

-- Lettres accentuées ramenées à leur lettre de base pour la recherche (« Forêt » → « foret », « ÉCLAT » → « eclat »).
local FOLD = {}
local function fold(chars, base)
    for _, code in utf8codes(chars) do FOLD[utf8char(code)] = base end
end
fold('àáâãäåÀÁÂÃÄÅ', 'a')
fold('çÇ', 'c')
fold('èéêëÈÉÊË', 'e')
fold('ìíîïÌÍÎÏ', 'i')
fold('ñÑ', 'n')
fold('òóôõöøÒÓÔÕÖØ', 'o')
fold('ùúûüÙÚÛÜ', 'u')
fold('ýÿÝŸ', 'y')
fold('œŒ', 'oe')
fold('æÆ', 'ae')
fold('ß', 'ss')
fold('’', '\'')

local NBSP = '\u{00A0}'
-- blancs ASCII écrits octet par octet : `%s` dépend de la locale du système (sous Windows, il prend aussi l'octet 0xA0
-- de « à » ou de « Š », et couperait ces caractères en deux) ; de même, `string.lower` prendrait le premier octet d'un
-- caractère accentué pour une majuscule (0xC3 → 0xE3) : seules les 26 majuscules ASCII sont baissées
local LEADING_BLANKS = '^[\t-\r ]+'
local TRAILING_BLANKS = '[\t-\r ]+$'
local BLANK_RUNS = '[\t-\r ]+'
local ASCII_UPPER = '[A-Z]'
local ASCII_LOWER = {}
for code = 65, 90 do ASCII_LOWER[char(code)] = char(code + 32) end

---@param value any
---@return boolean
function text.isUtf8(value)
    return type(value) == 'string' and utf8len(value) ~= nil
end

--- Longueur en caractères d'un texte UTF-8 valide, sinon nil.
---@param value string
---@return integer|nil
function text.length(value)
    return utf8len(value)
end

--- Texte sans ses blancs de bord (espaces, tabulations, retours à la ligne).
---@param value string
---@return string
function text.trim(value)
    return (gsub(gsub(value, LEADING_BLANKS, ''), TRAILING_BLANKS, ''))
end

--- Vrai si le texte contient un caractère de contrôle (ASCII, C1), un caractère invisible ou de sens d'écriture qui
--- ferait mentir l'affichage : espace sans largeur et marques de sens (U+200B à U+200F), séparateurs de ligne et de
--- paragraphe (U+2028, U+2029), sens d'écriture (U+202A à U+202E, U+2066 à U+2069), marque arabe (U+061C), marque
--- d'ordre des octets (U+FEFF). `allowNewline` : le retour à la ligne est permis.
---@param value string
---@param allowNewline? boolean
---@return boolean
function text.hasControl(value, allowNewline)
    local probe = value
    if allowNewline then probe = gsub(value, '\n', '') end
    -- contrôles ASCII écrits octet par octet : `%c` dépend de la locale du système (sous Windows, il prend aussi des
    -- octets de suite UTF-8 comme 0x8F ou 0xAD, et refuserait « Ï » ou « í »)
    return find(probe, '[\0-\31\127]') ~= nil
        or find(probe, '\xC2[\x80-\x9F]') ~= nil
        or find(probe, '\xE2\x80[\x8B-\x8F\xA8-\xAE]') ~= nil
        or find(probe, '\xE2\x81[\xA6-\xA9]') ~= nil
        or find(probe, '\xD8\x9C', 1, true) ~= nil
        or find(probe, '\xEF\xBB\xBF', 1, true) ~= nil
end

--- Un point de code permis dans un nom : lettre (accents latins compris), chiffre, espace, apostrophe, trait d'union,
--- virgule, point.
---@param code integer
---@return boolean
local function nameCode(code)
    if code < 128 then
        return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
            or code == 32 or code == 39 or code == 45 or code == 44 or code == 46
    end
    if code >= 0xC0 and code <= 0xFF then return code ~= 0xD7 and code ~= 0xF7 end
    return (code >= 0x100 and code <= 0x17F) or code == 0x2019
end

--- Jeu de caractères `name` (texte UTF-8 valide attendu).
---@param value string
---@return boolean
function text.isName(value)
    for _, code in utf8codes(value) do
        if not nameCode(code) then return false end
    end
    return true
end

--- Jeu de caractères `id` : minuscules sans accent, chiffres et « _ ».
---@param value string
---@return boolean
function text.isId(value)
    return find(value, '^[a-z0-9_]+$') ~= nil
end

--- Jeu de caractères `free` : tout caractère imprimable sauf « < » et « > » (contrôles et invisibles : vus avant, par
--- `hasControl`).
---@param value string
---@return boolean
function text.isFree(value)
    return find(value, '[<>]') == nil
end

--- Forme de recherche : accents et casse ignorés, blancs réduits à un espace, bords retirés.
---@param value string
---@return string
function text.normalize(value)
    local folded = gsub(value, '[\xC2-\xF4][\x80-\xBF]*', FOLD)
    return text.trim(gsub(gsub(folded, ASCII_UPPER, ASCII_LOWER), BLANK_RUNS, ' '))
end

--- Vrai si `needle` (déjà normalisé) se trouve dans `haystack` (déjà normalisé). Un filtre vide garde tout.
---@param haystack string
---@param needle string
---@return boolean
function text.contains(haystack, needle)
    return needle == '' or find(haystack, needle, 1, true) ~= nil
end

--- Texte coupé à `maxBytes` octets sans briser un caractère UTF-8.
---@param value string
---@param maxBytes integer
---@return string
function text.truncate(value, maxBytes)
    if #value <= maxBytes then return value end
    local cut = maxBytes
    -- un octet de suite (10xxxxxx) juste après la coupe : le caractère commencé avant n'est pas complet
    while cut > 0 and ((byte(value, cut + 1) or 0) & 0xC0) == 0x80 do cut = cut - 1 end
    return sub(value, 1, cut)
end

--- Nombre à la française : virgule décimale, milliers séparés par une espace insécable ; `decimals` chiffres après
--- la virgule s'il est donné, sinon au plus trois, sans zéros inutiles.
---@param value number
---@param decimals? integer
---@return string
function text.number(value, decimals)
    local written
    if decimals then
        written = format('%.' .. decimals .. 'f', value)
    elseif tointeger(value) then
        written = format('%d', tointeger(value))
    else
        written = gsub(gsub(format('%.3f', value), '0+$', ''), '%.$', '')
    end
    local sign, whole, rest = written:match('^(%-?)(%d+)(.*)$')
    if not whole then return written end
    local groups, first = {}, #whole % 3
    if first > 0 then groups[1] = sub(whole, 1, first) end
    for i = first + 1, #whole, 3 do groups[#groups + 1] = sub(whole, i, i + 2) end
    return sign .. concat(groups, NBSP) .. gsub(rest, '%.', ',')
end

local DURATION_PARTS = {
    { seconds = 86400, one = 'jour', many = 'jours', short = 'j' },
    { seconds = 3600, short = 'h' },
    { seconds = 60, short = 'min' },
    { seconds = 1, short = 's' },
}

--- Durée lisible : « 7 jours », « 10 minutes », « 1 h 30 min », « 45 s ».
---@param seconds integer
---@return string
function text.duration(seconds)
    seconds = floor(seconds)
    if seconds > 0 and seconds % 86400 == 0 then
        local days = seconds // 86400
        return format('%d %s', days, days > 1 and 'jours' or 'jour')
    end
    if seconds > 0 and seconds < 3600 and seconds % 60 == 0 then
        local minutes = seconds // 60
        return format('%d %s', minutes, minutes > 1 and 'minutes' or 'minute')
    end
    local parts, left = {}, seconds
    for _, part in ipairs(DURATION_PARTS) do
        local count = left // part.seconds
        if count > 0 then
            parts[#parts + 1] = format('%d %s', count, part.short)
            left = left - count * part.seconds
        end
    end
    if #parts == 0 then return '0 s' end
    return concat(parts, ' ')
end
