--[[
    vava_atelier/shared/formvalues.lua
    Rôle : logique pure des valeurs d'une fiche. `data` est une table plate { [champ] = nombre | chaîne | booléen },
           exactement les champs du formulaire ; le paquet réseau range ces valeurs par carte (`n` nombres, `s`
           chaînes, `b` booléens).
             - value(field, brut)      → valeur nettoyée, ou nil, code, arguments (bornes, pas, choix, caractères)
             - toData(form, paquet)    → data, ou nil, erreurs { { field?, code, args?, key? } } (clé inconnue :
                                         code `unknown_field`, sans champ)
             - toPacket(form, data)    → paquet { n?, s?, b? } pour l'interface, champs repris par défaut
             - default(field), defaults(form)
           L'Atelier ne contrôle que la forme ; les règles du jeu sont celles du module (`validate`). Les contrôles du
           monde (objet existant, valeur d'une source) sont faits par le serveur (server/check.lua).
           Testée : tests/spec/atelier_formvalues_spec.lua.
    Dépendances : shared/constants.lua, shared/text.lua
]]

local type, ipairs, pairs, next, tostring = type, ipairs, pairs, next, tostring
local floor, abs, max, huge, tointeger, mathType = math.floor, math.abs, math.max, math.huge, math.tointeger, math.type
local find, gsub = string.find, string.gsub
local sort = table.sort

local CARD = VavaAtelier.CARD
local LIMITS = VavaAtelier.LIMITS
local OPTION_PATTERN, MAX_OPTION, MAX_MODEL = VavaAtelier.OPTION_PATTERN, VavaAtelier.MAX_OPTION, VavaAtelier.MAX_MODEL
local ITEM_PATTERN, MAX_ITEM = VavaAtelier.ITEM_PATTERN, VavaAtelier.MAX_ITEM
local text = VavaAtelier.text

-- tolérance d'un pas (arrondi des réels : 0,30000000000000004 est sur un pas de 0,1)
local EPSILON = 1e-9
local CARDS = { 'n', 's', 'b' }

local fv = {}
VavaAtelier.formvalues = fv

---@param value any
---@return boolean
function fv.isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end
local isFinite = fv.isFinite

--- Rang d'une valeur sur la grille `min + k × step` : vrai si elle y tombe (à la tolérance près), et le rang entier.
---@param value number
---@param min number
---@param step number
---@return boolean onStep
---@return integer rank
function fv.onStep(value, min, step)
    local k = (value - min) / step
    local rank = floor(k + 0.5)
    return abs(k - rank) <= EPSILON * max(1, abs(k)), rank
end

--- Valeur exacte du pas `rank` : entière pour un curseur `integer`, sinon arrondie au milliardième (0,3 et non
--- 0,30000000000000004).
local function snap(min, step, rank, integer)
    local value = min + rank * step
    if integer then return tointeger(floor(value + 0.5)) or value end
    return floor(value * 1e9 + 0.5) / 1e9
end

---@param options table[]|nil
---@param value string
---@return boolean
local function among(options, value)
    if type(options) ~= 'table' then return false end
    for _, option in ipairs(options) do
        if option.value == value then return true end
    end
    return false
end

---@param value string
---@param pattern string
---@param maxLength integer
---@return boolean
local function matches(value, pattern, maxLength)
    return #value <= maxLength and find(value, pattern) ~= nil
end

--- Texte d'un champ `text` : UTF-8, sans contrôle, nettoyé (bords ; retours à la ligne unifiés), jeu de caractères,
--- longueur en caractères, lignes.
local function textValue(field, raw)
    if not text.isUtf8(raw) then return nil, 'charset' end
    local value = gsub(gsub(raw, '\r\n', '\n'), '\r', '\n')
    value = text.trim(value)
    if value == '' then
        if field.optional or (field.min or 0) == 0 then return '' end
        return nil, 'required'
    end
    if text.hasControl(value, field.multiline == true) then return nil, 'control' end
    local charset = field.charset
    if charset == 'name' then
        if not text.isName(value) then return nil, 'charset' end
        if find(value, '  ', 1, true) then return nil, 'spaces' end
    elseif charset == 'id' then
        if not text.isId(value) then return nil, 'charset' end
    elseif not text.isFree(value) then
        return nil, 'charset'
    end
    if field.multiline then
        local _, breaks = gsub(value, '\n', '')
        if breaks + 1 > LIMITS.textLines then return nil, 'lines', { LIMITS.textLines } end
    end
    local length, minLength = text.length(value), field.min or 0
    if length < minLength or length > field.max then return nil, 'length', { minLength, field.max } end
    return value
end

--- Chaîne vide d'un champ : '' s'il est facultatif, sinon « À remplir ».
local function empty(field)
    if field.optional then return '' end
    return nil, 'required'
end

--- Valeur d'un champ, nettoyée : nombre sur un pas, entier, choix déclaré, texte propre… ou nil, un code d'erreur
--- (`number`, `range`, `step`, `integer`, `type`, `required`, `choice`, `charset`, `spaces`, `control`, `lines`,
--- `length`, `item`, `model`) et ses arguments (bornes).
---@param field table  champ déclaré (déjà accepté par shared/formschema.lua)
---@param raw any
---@return any|nil value
---@return string|nil code
---@return table|nil args
function fv.value(field, raw)
    local widget = field.widget
    if widget == 'slider' then
        if not isFinite(raw) then return nil, 'number' end
        local tolerance = field.step * EPSILON
        if raw < field.min - tolerance or raw > field.max + tolerance then
            return nil, 'range', { field.min, field.max }
        end
        local onStep, rank = fv.onStep(raw, field.min, field.step)
        if not onStep then return nil, 'step', { field.step } end
        local value = snap(field.min, field.step, rank, field.integer == true)
        if value < field.min then value = field.min elseif value > field.max then value = field.max end
        return value
    elseif widget == 'duration' then
        if not isFinite(raw) then return nil, 'number' end
        local value = tointeger(raw)
        if not value then return nil, 'integer' end
        if value < field.min or value > field.max then return nil, 'range', { field.min, field.max } end
        return value
    elseif widget == 'toggle' then
        if type(raw) ~= 'boolean' then return nil, 'type' end
        return raw
    end
    if type(raw) ~= 'string' then return nil, 'type' end
    if widget == 'text' then return textValue(field, raw) end
    if raw == '' then return empty(field) end
    if widget == 'segmented' then
        if not among(field.options, raw) then return nil, 'choice' end
        return raw
    elseif widget == 'select' then
        if field.source then
            if not matches(raw, OPTION_PATTERN, MAX_OPTION) then return nil, 'choice' end
        elseif not among(field.options, raw) then
            return nil, 'choice'
        end
        return raw
    elseif widget == 'item' then
        if not matches(raw, ITEM_PATTERN, MAX_ITEM) then return nil, 'item' end
        return raw
    elseif widget == 'model' then
        if not matches(raw, OPTION_PATTERN, MAX_MODEL) then return nil, 'model' end
        if field.choices and not field.free and not among(field.choices, raw) then return nil, 'model' end
        return raw
    end
    return nil, 'type'
end

--- Valeur d'une entrée nouvelle : le défaut déclaré, sinon le plus naturel (borne basse, premier choix, vide).
---@param field table
---@return any
function fv.default(field)
    if field.default ~= nil then return field.default end
    local widget = field.widget
    if widget == 'slider' or widget == 'duration' then return field.min end
    if widget == 'toggle' then return false end
    if widget == 'segmented' then return field.options[1].value end
    if widget == 'select' then
        if field.options and not field.optional then return field.options[1].value end
        return ''
    end
    if widget == 'model' then
        if field.choices and not field.optional then return field.choices[1].value end
        return ''
    end
    return ''
end

--- `data` d'une entrée nouvelle.
---@param form table
---@return table<string, any>
function fv.defaults(form)
    local data = {}
    for _, field in ipairs(form.fields) do data[field.id] = fv.default(field) end
    return data
end

--- Valeurs reçues de l'interface → `data` du module. Chaque clé doit être un champ du formulaire, dans sa carte ;
--- chaque champ non facultatif doit être présent (un champ facultatif absent vaut ''). Les erreurs sont rangées dans
--- l'ordre du formulaire, les erreurs sans champ (clé inconnue) d'abord.
---@param form table
---@param packet any  { n?, s?, b? }
---@return table|nil data
---@return table[]|nil errors
function fv.toData(form, packet)
    local byId, order = {}, {}
    for i, field in ipairs(form.fields) do
        byId[field.id] = field
        order[field.id] = i
    end
    local data, errors, failed = {}, {}, {}
    if type(packet) ~= 'table' then packet = {} end
    for _, card in ipairs(CARDS) do
        local map = packet[card]
        if map ~= nil and type(map) ~= 'table' then
            errors[#errors + 1] = { code = 'type', key = card }
        elseif map then
            for key, raw in pairs(map) do
                local field = byId[key]
                if not field then
                    errors[#errors + 1] = { code = 'unknown_field', key = key }
                elseif CARD[field.widget] ~= card then
                    errors[#errors + 1] = { field = key, code = 'type' }
                    failed[key] = true
                else
                    local value, code, args = fv.value(field, raw)
                    if value == nil then
                        errors[#errors + 1] = { field = key, code = code, args = args }
                        failed[key] = true
                    else
                        data[key] = value
                    end
                end
            end
        end
    end
    for _, field in ipairs(form.fields) do
        local id = field.id
        if data[id] == nil and not failed[id] then
            if field.optional then
                data[id] = ''
            else
                errors[#errors + 1] = { field = id, code = 'required' }
            end
        end
    end
    if #errors == 0 then return data end
    sort(errors, function(a, b)
        local ra, rb = a.field and order[a.field] or 0, b.field and order[b.field] or 0
        if ra ~= rb then return ra < rb end
        return tostring(a.key or a.code) < tostring(b.key or b.code)
    end)
    return nil, errors
end

--- `data` du module → paquet de l'interface. Une valeur absente ou refusée d'un champ (hors bornes, choix disparu…)
--- est remplacée par le défaut du champ et signalée dans `warnings` (« Valeur de départ remise : l'ancienne manquait ou n'est plus permise ») ; un champ
--- facultatif absent vaut '' sans avertissement. Les cartes vides sont omises.
---@param form table
---@param data any
---@return table packet  { n?, s?, b? }
---@return string[] warnings  identifiants des champs repris
function fv.toPacket(form, data)
    local packet, warnings = { n = {}, s = {}, b = {} }, {}
    if type(data) ~= 'table' then data = {} end
    for _, field in ipairs(form.fields) do
        local raw, value = data[field.id], nil
        if raw ~= nil then value = fv.value(field, raw) end
        if value == nil then
            if raw == nil and field.optional then
                value = ''
            else
                value = fv.default(field)
                warnings[#warnings + 1] = field.id
            end
        end
        packet[CARD[field.widget]][field.id] = value
    end
    for _, card in ipairs(CARDS) do
        if next(packet[card]) == nil then packet[card] = nil end
    end
    return packet, warnings
end

--- Nombre entier ? (accepte un réel de valeur entière : 3.0)
---@param value any
---@return boolean
function fv.isInteger(value)
    return isFinite(value) and (mathType(value) == 'integer' or tointeger(value) ~= nil)
end
