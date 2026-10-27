--[[
    vava_chat/shared/text.lua
    Rôle : texte d'un message en UTF-8, commun au serveur et au client : nettoyage (caractères de contrôle, codes de
           couleur ^0-^9 de FiveM, espaces), longueur en signes, troncature qui ne coupe jamais un caractère.
           Ensembles ASCII écrits en toutes lettres : les classes %s, %c et %d de Lua suivent la langue du système et
           peuvent prendre un octet d'un caractère accentué pour une espace.
    Dépendances : shared/constants.lua
]]

local type = type
local utf8len, utf8offset = utf8.len, utf8.offset
local gsub, sub = string.gsub, string.sub

local CONTROLS = '[\0-\31\127]'
local CONTROLS_BUT_LINES = '[\0-\9\11-\31\127]'
local COLOR_CODES = '%^[0-9]'
local SPACES = ' +'
local LINE_EDGES = ' *\n *'
local LINES = '\n\n+'

local text = {}
VavaChat.text = text

--- Texte nettoyé (UTF-8 valide exigé), ou nil. `keepLines` garde les retours à la ligne (messages d'autres ressources).
---@param value any
---@param keepLines? boolean
---@return string|nil
function text.clean(value, keepLines)
    if type(value) ~= 'string' or not utf8len(value) then return nil end
    local cleaned = gsub(value, keepLines and CONTROLS_BUT_LINES or CONTROLS, ' ')
    cleaned = gsub(cleaned, COLOR_CODES, '')
    cleaned = gsub(cleaned, SPACES, ' ')
    if keepLines then
        cleaned = gsub(cleaned, LINE_EDGES, '\n')
        cleaned = gsub(cleaned, LINES, '\n')
        cleaned = gsub(cleaned, '^\n', '')
        cleaned = gsub(cleaned, '\n$', '')
    end
    cleaned = gsub(cleaned, '^ ', '')
    cleaned = gsub(cleaned, ' $', '')
    return cleaned
end

---@param value string
---@return integer
function text.length(value)
    return utf8len(value) or 0
end

--- Garde les `max` premiers signes, sans couper un caractère ; `suffix` est ajouté si le texte a été coupé.
---@param value string
---@param max integer
---@param suffix? string
---@return string
function text.truncate(value, max, suffix)
    local length = utf8len(value)
    if not length or length <= max then return value end
    return sub(value, 1, utf8offset(value, max + 1) - 1) .. (suffix or '')
end
