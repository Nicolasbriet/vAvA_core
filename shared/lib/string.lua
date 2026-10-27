--[[
    shared/lib/string.lua
    Rôle : utilitaires purs sur les chaînes (identifiants, préfixes, nettoyage pour les logs, UTF-8, empreinte FNV-1a).
    Dépendances : shared/init.lua, config/shared.lua
]]

local type, tostring = type, tostring
local byte, sub, find, gsub, match = string.byte, string.sub, string.find, string.gsub, string.match
local utf8len, utf8codes = utf8.len, utf8.codes

local identifiers = vAvA.config.shared.identifiers
local IDENTIFIER_PATTERN = identifiers.pattern
local IDENTIFIER_MAX_LENGTH = identifiers.maxLength

-- Paramètres standard de FNV-1a 32 bits.
local FNV_OFFSET_BASIS = 2166136261
local FNV_PRIME = 16777619
local UINT32_MASK = 0xFFFFFFFF

local str = {}
vAvA.lib.string = str

--- Vrai si la valeur est un identifiant valide (hook, RPC, registre, clé).
---@param value any
---@return boolean
function str.isIdentifier(value)
    return type(value) == 'string'
        and #value <= IDENTIFIER_MAX_LENGTH
        and find(value, IDENTIFIER_PATTERN) ~= nil
end

---@param value string
---@param prefix string
---@return boolean
function str.hasPrefix(value, prefix)
    return sub(value, 1, #prefix) == prefix
end

---@param value string
---@return string
function str.trim(value)
    return match(value, '^%s*(.-)%s*$')
end

--- Rend une valeur non fiable affichable sans risque dans la console :
--- codes couleur FiveM (^0-^9) et caractères de contrôle retirés, longueur bornée.
---@param value any
---@param maxLength integer
---@return string
function str.sanitize(value, maxLength)
    local text = tostring(value)
    if #text > maxLength then
        text = sub(text, 1, maxLength) .. '…'
    end
    text = gsub(text, '%^%d', '')
    text = gsub(text, '%c', ' ')
    return text
end

--- Longueur en caractères (et non en octets) ; nil si la chaîne n'est pas de l'UTF-8 valide.
---@param value string
---@return integer|nil
function str.utf8Length(value)
    local length = utf8len(value)
    return length
end

--- Ensemble des points de code d'une chaîne UTF-8 valide (liste de caractères autorisés venant de la config).
--- Les motifs Lua ne connaissent que les octets : « é » n'est pas reconnu par %a.
---@param characters string
---@return table<integer, true>
function str.codepointSet(characters)
    local set = {}
    for _, code in utf8codes(characters) do
        set[code] = true
    end
    return set
end

--- Empreinte FNV-1a 32 bits (entier non signé). Sert à détecter la modification d'un fichier déjà appliqué.
---@param value string
---@return integer
function str.fnv1a(value)
    local hash = FNV_OFFSET_BASIS
    for i = 1, #value do
        hash = ((hash ~ byte(value, i)) * FNV_PRIME) & UINT32_MASK
    end
    return hash
end
