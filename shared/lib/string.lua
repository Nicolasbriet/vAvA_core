--[[
    shared/lib/string.lua
    Rôle : utilitaires purs sur les chaînes (identifiants, préfixes, nettoyage pour les logs, UTF-8, empreinte FNV-1a).
    Dépendances : shared/init.lua, config/shared.lua
]]

local ipairs, type, tostring = ipairs, type, tostring
local byte, char, sub, find, gsub, match = string.byte, string.char, string.sub, string.find, string.gsub, string.match
local utf8len, utf8codes = utf8.len, utf8.codes

-- Ensembles écrits octet par octet : les classes %s et %c de Lua (et string.lower) suivent la locale du système (sous
-- Windows, %s prend aussi l'octet 0xA0 de « à », %c les octets 0x81, 0x8D, 0x8F, 0x90, 0x9D, 0xAD de « Á », « Í »,
-- « í »… et laisse passer les contrôles C1 écrits en UTF-8).
local BLANKS = '[\t-\r ]'   -- tabulation, saut de ligne, tabulation verticale, saut de page, retour chariot, espace
local TRIM_PATTERN = '^' .. BLANKS .. '*(.-)' .. BLANKS .. '*$'
local COLOR_CODES = '%^+[0-9]'
-- Caractères qui feraient mentir une console ou un affichage (même liste que vava_atelier, shared/text.lua) :
-- contrôles ASCII, contrôles C1 en UTF-8 (U+0080 à U+009F : CSI, OSC, DCS… qu'un terminal interpréterait), espace sans
-- largeur et marques de sens (U+200B à U+200F), séparateurs de ligne et de paragraphe et sens d'écriture (U+2028 à
-- U+202E), isolats de sens (U+2066 à U+2069), marque arabe (U+061C), marque d'ordre des octets (U+FEFF).
local CONTROL_SEQUENCES = {
    '[\0-\31\127]',
    '\xC2[\x80-\x9F]',
    '\xE2\x80[\x8B-\x8F\xA8-\xAE]',
    '\xE2\x81[\xA6-\xA9]',
    '\xD8\x9C',
    '\xEF\xBB\xBF',
}
local ASCII_UPPER = '[A-Z]'
local ASCII_LOWER = {}
for code = 65, 90 do ASCII_LOWER[char(code)] = char(code + 32) end

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

--- Minuscules ASCII seulement (A à Z) : les caractères UTF-8 restent entiers, quelle que soit la locale.
---@param value string
---@return string
function str.asciiLower(value)
    return (gsub(value, ASCII_UPPER, ASCII_LOWER))
end

--- Vrai si le texte contient un caractère de contrôle (ASCII, C1 en UTF-8), un caractère invisible ou une marque de
--- sens d'écriture (liste en tête du fichier, la même que vava_atelier).
---@param value string
---@return boolean
function str.hasControl(value)
    for _, pattern in ipairs(CONTROL_SEQUENCES) do
        if find(value, pattern) then return true end
    end
    return false
end

--- Rend une valeur non fiable affichable sans risque dans la console :
--- codes couleur FiveM (^0-^9) retirés, caractères de contrôle (ASCII, C1), invisibles et marques de sens d'écriture
--- (voir hasControl) remplacés par une espace, longueur bornée.
---@param value any
---@param maxLength integer
---@return string
function str.sanitize(value, maxLength)
    local text = tostring(value)
    if #text > maxLength then
        text = sub(text, 1, maxLength) .. '…'
    end
    -- « ^^11 » : retirer « ^1 » laisserait « ^1 » ; la suite entière de ^ part avec le chiffre
    text = gsub(text, COLOR_CODES, '')
    for _, pattern in ipairs(CONTROL_SEQUENCES) do
        text = gsub(text, pattern, ' ')
    end
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
