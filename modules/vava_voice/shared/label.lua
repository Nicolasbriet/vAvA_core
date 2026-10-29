--[[
    vava_voice/shared/label.lua
    Rôle : nom d'une zone de voix, règle unique du serveur (éditeur en jeu et panneau web) : UTF-8 valide, aucun
           caractère de contrôle, espaces superflus retirés, au plus `zones.labelMax` signes — un « é » compte pour
           un, comme dans le champ de l'éditeur. La borne réseau du RPC, en octets, en découle : un signe UTF-8 tient
           en 4 octets au plus. Ensembles ASCII écrits en toutes lettres : les classes %s et %c de Lua suivent la
           langue du système et peuvent prendre un octet d'un caractère accentué pour une espace.
    Dépendances : shared/constants.lua, config.lua
]]

local type = type
local utf8len = utf8.len
local find, gsub = string.find, string.gsub

local MAX = VavaVoice.config.zones.labelMax
-- octets d'un signe en UTF-8, au plus
local BYTES_PER_SIGN = 4
local CONTROLS = '[\0-\31\127]'

local label = {}
VavaVoice.label = label

-- borne réseau du nom (octets) et motif ancré du schéma du RPC : aucun caractère de contrôle
label.BYTES_MAX = MAX * BYTES_PER_SIGN
label.PATTERN = '^[^\0-\31\127]+$'

--- Nom nettoyé, ou nil et la raison du refus.
---@param value any
---@return string|nil name
---@return string|nil code  'invalid_label' (vide, illisible, caractère de contrôle) ou 'label_too_long'
function label.clean(value)
    if type(value) ~= 'string' or #value > label.BYTES_MAX or find(value, CONTROLS) or not utf8len(value) then
        return nil, 'invalid_label'
    end
    local text = gsub(value, ' +', ' ')
    text = gsub(text, '^ ', '')
    text = gsub(text, ' $', '')
    if text == '' then return nil, 'invalid_label' end
    if utf8len(text) > MAX then return nil, 'label_too_long' end
    return text
end
