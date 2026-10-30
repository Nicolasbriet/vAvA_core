--[[
    shared/lib/string.lua
    Rôle : utilitaires purs sur les chaînes (identifiants, préfixes, nettoyage pour les logs, UTF-8, empreinte FNV-1a).
    Dépendances : shared/init.lua, config/shared.lua
]]

local type, tostring = type, tostring
local byte, sub, find, gsub, match = string.byte, string.sub, string.find, string.gsub, string.match
local utf8len, utf8codes = utf8.len, utf8.codes

-- Ensembles ASCII écrits octet par octet : les classes %s et %c de Lua suivent la locale du système (sous Windows,
-- %s prend aussi l'octet 0xA0 de « à », %c les octets 0x81, 0x8D, 0x8F, 0x90, 0x9D, 0xAD de « Á », « Í », « í »…).
local BLANKS = '[\t-\r ]'   -- tabulation, saut de ligne, tabulation verticale, saut de page, retour chariot, espace
local CONTROLS = '[\0-\31\127]'
local TRIM_PATTERN = '^' .. BLANKS .. '*(.-)' .. BLANKS .. '*$'

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

--- Chaîne sans ses blancs ASCII de bord (espace, tabulation, sauts de ligne) ; les caractères UTF-8 restent entiers.
---@param value string
---@return string
function str.trim(value)
    return match(value, TRIM_PATTERN)
end

--- Rend une valeur non fiable affichable sans risque dans la console :
--- codes couleur FiveM (^0-^9) retirés, caractères de contrôle ASCII (0x00 à 0x1F, 0x7F) remplacés par une espace,
--- longueur bornée.
---@param value any
---@param maxLength integer
---@return string
function str.sanitize(value, maxLength)
    local text = tostring(value)
    if #text > maxLength then
        text = sub(text, 1, maxLength) .. '…'
    end
    -- « ^^11 » : retirer « ^1 » laisserait « ^1 » ; la suite entière de ^ part avec le chiffre
    text = gsub(text, '%^+%d', '')
    text = gsub(text, CONTROLS, ' ')
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
