--[[
    vava_example_atelier/shared/rules.lua
    Rôle : logique pure des règles propres à l'exemple, rendues par la fonction `validate` de l'éditeur des panneaux
           (l'Atelier ne contrôle que la forme ; le module reste seul juge) :
             - nom unique parmi les panneaux (accents et casse ignorés, l'entrée elle-même exclue) ;
             - panneau éclairé ⇒ affiché au moins un jour ;
             - langue « runes » ⇒ texte de 120 caractères au plus.
           Et l'encadré « Pour comparer » : l'autre panneau du même quartier, sinon le premier autre.
           Testée : tests/spec/examples_atelier_spec.lua.
    Dépendances : config.lua
]]

local type, ipairs, floor = type, ipairs, math.floor
local char, format, gsub = string.char, string.format, string.gsub
local utf8len, utf8codes, utf8char = utf8.len, utf8.codes, utf8.char

local rules = {}
VavaExampleAtelier.rules = rules

rules.MIN_LIT_SECONDS = 86400
rules.MAX_RUNES = 120
rules.TEXTS = {
    duplicate = 'Un panneau porte déjà ce nom.',
    lit = 'Un panneau éclairé reste au moins un jour : la lanterne doit valoir la peine.',
    runes = 'Les runes se gravent lentement : 120 caractères au plus.',
}

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

-- Casse et blancs ASCII écrits octet par octet : `string.lower` et `%s` suivent la locale du système (sous Windows,
-- le premier octet de « Ł » passerait pour une majuscule, l'octet 0xA0 de « Š » pour une espace : la clé ne serait
-- plus de l'UTF-8).
local ASCII_LOWER = {}
for code = 65, 90 do ASCII_LOWER[char(code)] = char(code + 32) end

--- Nom ramené à une forme comparable : accents, casse et blancs de bord ignorés.
---@param name any
---@return string
function rules.key(name)
    if type(name) ~= 'string' then return '' end
    local folded = gsub(name, '[\xC2-\xF4][\x80-\xBF]*', FOLD)
    return (gsub(gsub(gsub(folded, '[A-Z]', ASCII_LOWER), '^[\t-\r ]+', ''), '[\t-\r ]+$', ''))
end

--- Erreurs d'un panneau : { { field, text } } (vide : rien à redire). `others` : les autres panneaux connus
--- ({ id, titre }), `selfId` : l'entrée vérifiée (nil pour une entrée nouvelle).
---@param data table
---@param others { id: string, titre: string }[]
---@param selfId string|nil
---@return { field: string, text: string }[]
function rules.board(data, others, selfId)
    local errors = {}
    local key = rules.key(data.titre)
    for _, other in ipairs(others) do
        if other.id ~= selfId and rules.key(other.titre) == key then
            errors[#errors + 1] = { field = 'titre', text = rules.TEXTS.duplicate }
            break
        end
    end
    if data.eclaire == true and (data.duree or 0) < rules.MIN_LIT_SECONDS then
        errors[#errors + 1] = { field = 'duree', text = rules.TEXTS.lit }
    end
    if data.langue == 'runes' and (utf8len(data.texte or '') or 0) > rules.MAX_RUNES then
        errors[#errors + 1] = { field = 'texte', text = rules.TEXTS.runes }
    end
    return errors
end

--- Nombre à la française (« 2,2 »).
local function frenchNumber(value)
    if floor(value) == value then return format('%d', floor(value)) end
    return (gsub(format('%.1f', value), '%.', ','))
end

--- Encadré « Pour comparer » : l'autre panneau du même quartier, sinon le premier autre ; nil s'il n'y en a pas.
---@param data table  panneau affiché
---@param boards table[]  panneaux connus (données complètes)
---@param selfId string|nil
---@return { title: string, text: string }|nil
function rules.compare(data, boards, selfId)
    local chosen
    for _, board in ipairs(boards) do
        if board.id ~= selfId then
            if board.quartier == data.quartier then
                chosen = board
                break
            end
            chosen = chosen or board
        end
    end
    if not chosen then return nil end
    local days = floor((chosen.duree or 0) / 86400)
    return {
        title = 'Pour comparer : ' .. chosen.titre,
        text = format('%s m, lisible à %s m, %d %s', frenchNumber(chosen.taille), frenchNumber(chosen.portee), days,
            days > 1 and 'jours' or 'jour'),
    }
end
