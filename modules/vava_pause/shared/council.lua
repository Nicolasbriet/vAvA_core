--[[
    vava_pause/shared/council.lua
    Rôle : logique pure d'une demande au Conseil, servie au seul serveur : nature permise, texte normalisé (UTF-8
           valide ; octets de contrôle refusés sauf le saut de ligne, contrôles C1 compris ; espaces répétés, espaces de
           bord de ligne et bords du texte retirés ; au plus deux sauts de ligne de suite et `maxLines` lignes ; au moins
           `minChars` caractères comptés en caractères, pas en octets).
    Dépendances : shared/constants.lua
]]

local type, ipairs = type, ipairs
local utf8len = utf8.len
local find, gsub = string.find, string.gsub

local council = {}
VavaPause.council = council

-- Octets de contrôle ASCII sauf le saut de ligne (10), écrits octet par octet (jamais %c : il suit la locale, T-133).
local CONTROL = '[\0-\9\11-\31\127]'
-- Contrôles C1 (U+0080 à U+009F) en UTF-8.
local C1 = '\194[\128-\159]'

--- Vrai si `kind` est une nature de demande (VavaPause.KINDS).
---@param kind any
---@return boolean
function council.isKind(kind)
    for _, name in ipairs(VavaPause.KINDS) do
        if kind == name then return true end
    end
    return false
end

--- Texte normalisé, ou nil, code : invalid_text (pas une chaîne, trop long, UTF-8 invalide, contrôle, trop de lignes),
--- too_short (moins de `minChars` caractères une fois normalisé).
---@param text any
---@param opts { minChars: integer, maxBytes: integer, maxLines: integer }
---@return string|nil
---@return string|nil code
function council.normalize(text, opts)
    if type(text) ~= 'string' or #text > opts.maxBytes then return nil, 'invalid_text' end
    if not utf8len(text) then return nil, 'invalid_text' end
    if find(text, CONTROL) or find(text, C1) then return nil, 'invalid_text' end
    local clean = gsub(text, ' +', ' ')
    clean = gsub(clean, ' ?\n ?', '\n')
    clean = gsub(clean, '^[ \n]+', '')
    clean = gsub(clean, '[ \n]+$', '')
    clean = gsub(clean, '\n\n\n+', '\n\n')
    local _, breaks = gsub(clean, '\n', '\n')
    if breaks + 1 > opts.maxLines then return nil, 'invalid_text' end
    if utf8len(clean) < opts.minChars then return nil, 'too_short' end
    return clean
end
