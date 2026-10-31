--[[
    vava_atelier/shared/slug.lua
    Rôle : logique pure de l'identifiant d'une fiche créée dans l'Atelier, tiré de son nom à la première sauvegarde
           (§ 5.6.4 de la spec T-101) et jamais changé ensuite (renommer change le titre, pas l'identifiant) :
           lettres accentuées ramenées à leur base, minuscules, tout ce qui n'est pas [a-z0-9] devient « _ », « _ »
           répétés réduits, bords retirés, 40 octets au plus ; vide → le nom du type. Déjà pris (base, tout statut, y
           compris retiré, ou liste du module) : suffixe _2, _3 … _99 ; au-delà, refus `full`.
           Aucune fonction dépendante de la locale (ni `%a`, ni `%s`, ni string.lower) : octets et tables ASCII.
           « Forêt de Brume » → foret_de_brume ; « L'Ancre-Rouge » → l_ancre_rouge.
           Testée : tests/spec/atelier_slug_spec.lua.
    Dépendances : shared/constants.lua
]]

local type = type
local utf8codes, utf8char = utf8.codes, utf8.char
local gsub, sub = string.gsub, string.sub

local DEF = VavaAtelier.DEF

local slug = {}
VavaAtelier.slug = slug

-- lettres accentuées → base ASCII (minuscules : la casse est ramenée ensuite)
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

-- majuscules ASCII → minuscules, octet par octet
local LOWER = {}
for code = 65, 90 do LOWER[utf8char(code)] = utf8char(code + 32) end

--- Base d'un identifiant : nom ramené à [a-z0-9_], 40 octets au plus ; '' si rien n'en reste.
---@param name any
---@return string
function slug.base(name)
    if type(name) ~= 'string' then return '' end
    local value = gsub(name, '[\xC2-\xF4][\x80-\xBF]*', FOLD)
    value = gsub(value, '[A-Z]', LOWER)
    value = gsub(value, '[^a-z0-9]+', '_')
    value = gsub(gsub(value, '^_+', ''), '_+$', '')
    if #value > DEF.slugMax then value = gsub(sub(value, 1, DEF.slugMax), '_+$', '') end
    return value
end

--- Identifiant libre d'une fiche nouvelle : base du nom, sinon celle du nom du type (« panneau »), sinon « fiche » ;
--- suffixe _2 à _99 si elle est prise. nil, 'full' quand tout est pris.
---@param name string  nom saisi (titleField)
---@param noun string  nom du type
---@param taken fun(id: string): boolean  identifiant déjà connu (base, tout statut, ou liste du module)
---@return string|nil id
---@return string|nil err
function slug.pick(name, noun, taken)
    local base = slug.base(name)
    if base == '' then base = slug.base(noun) end
    if base == '' then base = 'fiche' end
    if not taken(base) then return base end
    for n = 2, DEF.slugSuffixes do
        local candidate = base .. '_' .. n
        if not taken(candidate) then return candidate end
    end
    return nil, 'full'
end
