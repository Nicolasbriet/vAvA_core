--[[
    vava_voice/shared/label.lua
    Rôle : nom d'une zone de voix, règle unique du serveur (éditeur en jeu et panneau web) : UTF-8 valide, aucun
           caractère de contrôle (C0, DEL, C1), aucun caractère invisible qui tromperait la lecture (largeur nulle,
           marques de sens d'écriture, BOM), espaces superflus retirés, au plus `zones.labelMax` signes — un « é »
           compte pour un, comme dans le champ de l'éditeur. Un nom fait d'espaces, insécables comprises, est vide.
           La borne réseau du RPC, en octets, en découle : un signe UTF-8 tient en 4 octets au plus. Ensembles écrits
           octet par octet : les classes %s et %c de Lua suivent la langue du système et peuvent prendre un octet
           d'un caractère accentué pour une espace ; l'UTF-8 étant vérifié, chaque suite ne peut être que ce signe.
    Dépendances : shared/constants.lua, config.lua
]]

local type, ipairs = type, ipairs
local utf8len = utf8.len
local find, gsub = string.find, string.gsub

local MAX = VavaVoice.config.zones.labelMax
-- octets d'un signe en UTF-8, au plus
local BYTES_PER_SIGN = 4
local CONTROLS = '[\0-\31\127]'
local INVISIBLES = {
    '\xC2[\x80-\x9F]',                  -- contrôles C1 (U+0080 à U+009F)
    '\xE2\x80[\x8B-\x8F\xA8-\xAE]',     -- largeur nulle, LRM, RLM (U+200B à U+200F), séparateurs et marques (U+2028 à U+202E)
    '\xE2\x81[\xA6-\xA9]',              -- isolats de sens d'écriture (U+2066 à U+2069)
    '\xEF\xBB\xBF',                     -- BOM, espace insécable de largeur nulle (U+FEFF)
}
local NBSP = '\xC2\xA0'

local label = {}
VavaVoice.label = label

-- borne réseau du nom (octets) et motif ancré du schéma du RPC : aucun caractère de contrôle
label.BYTES_MAX = MAX * BYTES_PER_SIGN
label.PATTERN = '^[^\0-\31\127]+$'

--- Nom nettoyé, ou nil et la raison du refus.
---@param value any
---@return string|nil name
---@return string|nil code  'invalid_label' (vide, illisible, caractère de contrôle ou invisible) ou 'label_too_long'
function label.clean(value)
    if type(value) ~= 'string' or #value > label.BYTES_MAX or find(value, CONTROLS) or not utf8len(value) then
        return nil, 'invalid_label'
    end
    for _, pattern in ipairs(INVISIBLES) do
        if find(value, pattern) then return nil, 'invalid_label' end
    end
    local text = gsub(value, ' +', ' ')
    text = gsub(text, '^ ', '')
    text = gsub(text, ' $', '')
    if gsub(gsub(text, NBSP, ''), ' ', '') == '' then return nil, 'invalid_label' end
    if utf8len(text) > MAX then return nil, 'label_too_long' end
    return text
end
