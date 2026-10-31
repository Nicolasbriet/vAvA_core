--[[
    vava_magic/shared/text.lua
    Rôle : outils de texte en UTF-8 (servis au seul serveur, aucun fichier client ne s'en sert) : nettoyage d'une
           saisie, longueur en signes (un « é » compte pour un), troncature qui ne coupe jamais un caractère,
           découpage en mots.
    Dépendances : shared/constants.lua
]]

local type = type
local utf8len, utf8offset = utf8.len, utf8.offset
local gsub, sub, gmatch, concat = string.gsub, string.sub, string.gmatch, table.concat

-- Ensembles ASCII écrits en toutes lettres : les classes %c et %s de Lua suivent la langue du système et peuvent
-- prendre un octet d'un caractère accentué UTF-8 (0xA0 du « à ») pour une espace.
local CONTROLS = '[\0-\31\127]'
local SPACES = ' +'
local WORD = '[^ ]+'

local text = {}
VavaMagic.text = text

--- Nettoie une saisie : UTF-8 valide exigé, caractères de contrôle remplacés par des espaces, espaces réduits.
---@param value any
---@return string|nil cleaned  nil si ce n'est pas un texte UTF-8 valide
function text.clean(value)
    if type(value) ~= 'string' or not utf8len(value) then return nil end
    local cleaned = gsub(value, CONTROLS, ' ')
    cleaned = gsub(cleaned, SPACES, ' ')
    cleaned = gsub(cleaned, '^ ', '')
    cleaned = gsub(cleaned, ' $', '')
    return cleaned
end

--- Nombre de signes (caractères UTF-8) ; 0 pour un texte invalide.
---@param value string
---@return integer
function text.length(value)
    return utf8len(value) or 0
end

--- Garde les `max` premiers signes, sans couper un caractère.
---@param value string
---@param max integer
---@return string
function text.truncate(value, max)
    local length = utf8len(value)
    if not length or length <= max then return value end
    local cut = utf8offset(value, max + 1)
    return sub(value, 1, cut - 1)
end

--- Mots d'un texte nettoyé (séparés par des espaces).
---@param value string
---@return string[]
function text.words(value)
    local list = {}
    for word in gmatch(value, WORD) do list[#list + 1] = word end
    return list
end

---@param words string[]
---@return string
function text.join(words)
    return concat(words, ' ')
end

--- Nom donné à un contact : nettoyé, 1 à `max` signes, ou nil.
---@param value any
---@param max integer
---@return string|nil
function text.name(value, max)
    local cleaned = text.clean(value)
    if not cleaned or cleaned == '' or text.length(cleaned) > max then return nil end
    return cleaned
end
