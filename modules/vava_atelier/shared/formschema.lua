--[[
    vava_atelier/shared/formschema.lua
    Rôle : logique pure du contrôle d'une déclaration d'éditeur (registre vava_atelier:editors) : textes bornés,
           famille, icône et droit connus, types (mise en page, article, placement, parent), formulaire (groupes,
           champs, huit widgets et leurs bornes croisées), fonctions du module. Un refus rend le chemin et la raison
           (« kinds[1].form.fields[3].max : doit dépasser min ») ; une clé inconnue est refusée. Le validateur du
           registre (server/editors.lua) n'accepte que ce que ce fichier accepte.
           T-101 : `format` (1 à 65535), `upgrade`, `texts.trialLine` (80), `feminine` d'un type ; `apply` et `remove`
           ensemble (atelier gardé), `trial` et `endTrial` ensemble et seulement avec `apply` ; chaîne des `parent`
           sans cycle, trois types au plus (fiche, enfant, petit-enfant).
           Testée : tests/spec/atelier_formschema_spec.lua.
    Dépendances : shared/constants.lua, shared/text.lua, shared/formvalues.lua
]]

local type, ipairs, pairs, tostring, getmetatable = type, ipairs, pairs, tostring, getmetatable
local floor, abs, max = math.floor, math.abs, math.max
local find, format = string.find, string.format

local LIMITS = VavaAtelier.LIMITS
local DEF = VavaAtelier.DEF
local CARD = VavaAtelier.CARD
local RESERVED = VavaAtelier.RESERVED
local KEY_PATTERN, MAX_KEY = VavaAtelier.KEY_PATTERN, VavaAtelier.MAX_KEY
local OPTION_PATTERN, MAX_OPTION, MAX_MODEL = VavaAtelier.OPTION_PATTERN, VavaAtelier.MAX_OPTION, VavaAtelier.MAX_MODEL
local ITEM_PATTERN, MAX_ITEM = VavaAtelier.ITEM_PATTERN, VavaAtelier.MAX_ITEM
local text = VavaAtelier.text
local fv = VavaAtelier.formvalues

local EPSILON = 1e-9

local fs = {}
VavaAtelier.formschema = fs

local function set(list)
    local out = {}
    for _, value in ipairs(list) do out[value] = true end
    return out
end

local EDITOR_KEYS = set({
    'family', 'label', 'description', 'icon', 'order', 'right', 'texts', 'kinds',
    'index', 'read', 'validate', 'options', 'compare', 'apply', 'remove', 'trial', 'endTrial', 'diff',
    'format', 'upgrade',
})
local REQUIRED_FUNCTIONS = { 'index', 'read', 'validate' }
local OPTIONAL_FUNCTIONS = { 'options', 'compare', 'apply', 'remove', 'trial', 'endTrial', 'diff', 'upgrade' }
local TEXTS_KEYS = set({ 'trial', 'publish', 'publishHint', 'trialLine' })
local KIND_KEYS = set({
    'id', 'noun', 'nounPlural', 'article', 'newLabel', 'layout', 'creatable', 'steps', 'placement', 'parent', 'form',
    'feminine',
})
local FORM_KEYS = set({ 'titleField', 'groups', 'fields' })
local GROUP_KEYS = set({ 'id', 'label', 'help', 'folded' })
local OPTION_KEYS = set({ 'value', 'label' })
local CHOICE_KEYS = set({ 'value', 'label', 'provisional' })
local COMMON_KEYS = { 'id', 'widget', 'label', 'help', 'group', 'width', 'optional', 'default' }
local WIDGET_KEYS = {
    slider = { 'min', 'max', 'step', 'integer', 'unit', 'prefix', 'decimals' },
    segmented = { 'options' },
    select = { 'options', 'source' },
    toggle = {},
    text = { 'min', 'max', 'multiline', 'charset' },
    duration = { 'min', 'max', 'units' },
    item = { 'category' },
    model = { 'choices', 'source', 'free' },
}
local FIELD_KEYS = {}
for widget, keys in pairs(WIDGET_KEYS) do
    local allowed = set(COMMON_KEYS)
    for _, key in ipairs(keys) do allowed[key] = true end
    FIELD_KEYS[widget] = allowed
end
local OPTIONAL_WIDGETS = { text = true, select = true, item = true, model = true }
local WIDTHS = { full = true, half = true }

--- Fonction appelable : locale, ou d'une autre ressource (table à __call après la traversée d'un export).
---@param value any
---@return boolean
function fs.isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    local meta = getmetatable(value)
    return type(meta) == 'table' and meta.__call ~= nil
end
local isCallable = fs.isCallable

---@return false
---@return string
local function fail(path, message)
    return false, path .. ' : ' .. message
end

--- Chemin d'une clé sous `path` (« kinds[1].form » + « fields » → « kinds[1].form.fields »).
local function join(path, key)
    if path == '' then return key end
    return path .. '.' .. key
end

--- Texte UTF-8 de `min` à `max` octets.
local function isText(value, min, maxBytes)
    return type(value) == 'string' and #value >= min and #value <= maxBytes and text.isUtf8(value)
end

--- Liste pure de `min` à `max` éléments.
local function isList(value, min, maxCount)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= 'number' then return false end
        count = count + 1
    end
    return count == #value and count >= min and count <= maxCount
end

--- Première clé hors de `allowed`, ou nil.
local function unknownKey(value, allowed)
    for key in pairs(value) do
        if not allowed[key] then return tostring(key) end
    end
    return nil
end

local function isIdentifier(value, pattern, maxLength)
    return type(value) == 'string' and #value <= maxLength and find(value, pattern) ~= nil
end

local function isFinite(value)
    return fv.isFinite(value)
end

local function isInteger(value)
    return fv.isInteger(value)
end

local function isBool(value)
    return value == nil or type(value) == 'boolean'
end

--- Liste d'options `{ value, label }` (segmented, select) ou de choix `{ value, label, provisional? }` (model).
local function checkOptions(list, path, bounds, keys, maxValue)
    if not isList(list, bounds.min, bounds.max) then
        return fail(path, format('liste de %d à %d choix attendue', bounds.min, bounds.max))
    end
    local seen = {}
    for i, option in ipairs(list) do
        local here = format('%s[%d]', path, i)
        if type(option) ~= 'table' then return fail(here, 'table attendue') end
        local unknown = unknownKey(option, keys)
        if unknown then return fail(join(here, unknown), 'clé inconnue') end
        if not isIdentifier(option.value, OPTION_PATTERN, maxValue) then
            return fail(join(here, 'value'), format('valeur au motif %s, %d octets au plus', OPTION_PATTERN, maxValue))
        end
        if seen[option.value] then return fail(join(here, 'value'), 'valeur en double') end
        seen[option.value] = true
        if not isText(option.label, 1, bounds.label) then
            return fail(join(here, 'label'), format('texte de 1 à %d octets attendu', bounds.label))
        end
        if not isBool(option.provisional) then return fail(join(here, 'provisional'), 'booléen attendu') end
    end
    return true
end

local function hasValue(list, value)
    for _, option in ipairs(list) do
        if option.value == value then return true end
    end
    return false
end

local checkWidget = {}

function checkWidget.slider(field, path)
    local abs1e9 = LIMITS.sliderAbs
    for _, key in ipairs({ 'min', 'max', 'step' }) do
        local value = field[key]
        if not isFinite(value) or abs(value) > abs1e9 then
            return fail(join(path, key), 'nombre fini attendu (1e9 au plus)')
        end
    end
    if field.max <= field.min then return fail(join(path, 'max'), 'doit dépasser min') end
    if field.step <= 0 then return fail(join(path, 'step'), 'doit être positif') end
    if not isBool(field.integer) then return fail(join(path, 'integer'), 'booléen attendu') end
    if field.integer then
        for _, key in ipairs({ 'min', 'max', 'step' }) do
            if not isInteger(field[key]) then return fail(join(path, key), 'entier attendu (integer)') end
        end
    end
    local steps = (field.max - field.min) / field.step
    local rank = floor(steps + 0.5)
    if abs(steps - rank) > EPSILON * max(1, steps) then
        return fail(join(path, 'step'), '(max − min) doit compter un nombre entier de pas')
    end
    if rank > LIMITS.sliderSteps then return fail(join(path, 'step'), format('plus de %d pas', LIMITS.sliderSteps)) end
    if field.unit ~= nil and not isText(field.unit, 0, LIMITS.unit) then
        return fail(join(path, 'unit'), format('texte de %d octets au plus', LIMITS.unit))
    end
    if field.prefix ~= nil and not isText(field.prefix, 0, LIMITS.prefix) then
        return fail(join(path, 'prefix'), format('texte de %d octets au plus', LIMITS.prefix))
    end
    local decimals = field.decimals
    if decimals ~= nil and (not isInteger(decimals) or decimals < 0 or decimals > LIMITS.decimals) then
        return fail(join(path, 'decimals'), format('entier de 0 à %d', LIMITS.decimals))
    end
    if field.default ~= nil then
        local value = field.default
        if not isFinite(value) then return fail(join(path, 'default'), 'nombre fini attendu') end
        if value < field.min or value > field.max then return fail(join(path, 'default'), 'hors des bornes') end
        if not fv.onStep(value, field.min, field.step) then return fail(join(path, 'default'), 'pas sur un pas') end
        if field.integer and not isInteger(value) then
            return fail(join(path, 'default'), 'entier attendu (integer)')
        end
    end
    return true
end

function checkWidget.segmented(field, path)
    local ok, err = checkOptions(field.options, join(path, 'options'), LIMITS.segmented, OPTION_KEYS, MAX_OPTION)
    if not ok then return false, err end
    if field.default ~= nil and not hasValue(field.options, field.default) then
        return fail(join(path, 'default'), 'absent des choix')
    end
    return true
end

function checkWidget.select(field, path)
    if (field.options == nil) == (field.source == nil) then
        return fail(path, 'soit options, soit source (une seule des deux)')
    end
    if field.source ~= nil then
        if not isIdentifier(field.source, KEY_PATTERN, MAX_KEY) then
            return fail(join(path, 'source'), format('identifiant au motif %s, %d octets au plus', KEY_PATTERN,
                MAX_KEY))
        end
        local default = field.default
        if default ~= nil and default ~= '' and not isIdentifier(default, OPTION_PATTERN, MAX_OPTION) then
            return fail(join(path, 'default'), 'valeur au motif des choix attendue')
        end
        return true
    end
    local ok, err = checkOptions(field.options, join(path, 'options'), LIMITS.select, OPTION_KEYS, MAX_OPTION)
    if not ok then return false, err end
    local default = field.default
    if default ~= nil and not (default == '' and field.optional) and not hasValue(field.options, default) then
        return fail(join(path, 'default'), 'absent des choix')
    end
    return true
end

function checkWidget.toggle(field, path)
    if type(field.default) ~= 'boolean' then return fail(join(path, 'default'), 'booléen obligatoire') end
    return true
end

function checkWidget.text(field, path)
    if not field.charset or not VavaAtelier.CHARSETS[field.charset] then
        return fail(join(path, 'charset'), 'name, id ou free attendu')
    end
    if not isBool(field.multiline) then return fail(join(path, 'multiline'), 'booléen attendu') end
    local limit = field.multiline and LIMITS.textMultilineMax or LIMITS.textMax
    if not isInteger(field.max) or field.max < 1 or field.max > limit then
        return fail(join(path, 'max'), format('entier de 1 à %d', limit))
    end
    if field.min ~= nil and (not isInteger(field.min) or field.min < 0 or field.min > field.max) then
        return fail(join(path, 'min'), 'entier de 0 à max')
    end
    if field.default ~= nil and field.default ~= '' then
        if type(field.default) ~= 'string' then return fail(join(path, 'default'), 'texte attendu') end
        local probe = {
            widget = 'text', charset = field.charset, multiline = field.multiline, min = field.min, max = field.max,
            optional = true,
        }
        local value = fv.value(probe, field.default)
        if value == nil or value ~= field.default then
            return fail(join(path, 'default'), 'invalide pour son jeu de caractères ou sa longueur')
        end
    end
    return true
end

function checkWidget.duration(field, path)
    if not isInteger(field.min) or field.min < 1 then
        return fail(join(path, 'min'), 'entier ≥ 1 attendu (secondes)')
    end
    if not isInteger(field.max) or field.max > LIMITS.durationMax then
        return fail(join(path, 'max'), format('entier ≤ %d attendu (secondes)', LIMITS.durationMax))
    end
    if field.max <= field.min then return fail(join(path, 'max'), 'doit dépasser min') end
    if not isList(field.units, 1, 4) then return fail(join(path, 'units'), 'liste de 1 à 4 unités attendue') end
    local seen = {}
    for i, unit in ipairs(field.units) do
        if not VavaAtelier.DURATION_UNITS[unit] or seen[unit] then
            return fail(format('%s.units[%d]', path, i), 's, min, h ou j attendu, sans double')
        end
        seen[unit] = true
    end
    if field.default ~= nil then
        local value = field.default
        if not isInteger(value) or value < field.min or value > field.max then
            return fail(join(path, 'default'), 'entier dans les bornes attendu')
        end
    end
    return true
end

function checkWidget.item(field, path)
    if field.category ~= nil and not isIdentifier(field.category, '^[%w_]*$', LIMITS.category) then
        return fail(join(path, 'category'), format('motif ^[%%w_]*$, %d octets au plus', LIMITS.category))
    end
    if field.default ~= nil and field.default ~= '' and not isIdentifier(field.default, ITEM_PATTERN, MAX_ITEM) then
        return fail(join(path, 'default'), 'nom d\'objet attendu')
    end
    return true
end

function checkWidget.model(field, path)
    if (field.choices == nil) == (field.source == nil) then
        return fail(path, 'soit choices, soit source (une seule des deux)')
    end
    if not isBool(field.free) then return fail(join(path, 'free'), 'booléen attendu') end
    if field.source ~= nil then
        if not isIdentifier(field.source, KEY_PATTERN, MAX_KEY) then
            return fail(join(path, 'source'), format('identifiant au motif %s, %d octets au plus', KEY_PATTERN,
                MAX_KEY))
        end
    else
        local ok, err = checkOptions(field.choices, join(path, 'choices'), LIMITS.choices, CHOICE_KEYS, MAX_MODEL)
        if not ok then return false, err end
    end
    local default = field.default
    if default ~= nil and default ~= '' then
        if not isIdentifier(default, OPTION_PATTERN, MAX_MODEL) then
            return fail(join(path, 'default'), 'nom de modèle attendu')
        end
        if field.choices and not field.free and not hasValue(field.choices, default) then
            return fail(join(path, 'default'), 'absent des choix')
        end
    end
    return true
end

--- Un champ du formulaire.
---@return boolean ok
---@return string|nil err
local function checkField(field, path, groups)
    if type(field) ~= 'table' then return fail(path, 'table attendue') end
    if not isIdentifier(field.id, KEY_PATTERN, MAX_KEY) then
        return fail(join(path, 'id'), format('identifiant au motif %s, %d octets au plus', KEY_PATTERN, MAX_KEY))
    end
    if RESERVED[field.id] then return fail(join(path, 'id'), 'clé réservée (id, place, version, status, parent)') end
    local widget = field.widget
    if type(widget) ~= 'string' or not WIDGET_KEYS[widget] then return fail(join(path, 'widget'), 'widget inconnu') end
    local unknown = unknownKey(field, FIELD_KEYS[widget])
    if unknown then return fail(join(path, unknown), 'clé inconnue pour le widget ' .. widget) end
    if not isText(field.label, 1, LIMITS.fieldLabel) then
        return fail(join(path, 'label'), format('texte de 1 à %d octets obligatoire', LIMITS.fieldLabel))
    end
    if not isText(field.help, 1, LIMITS.help) then
        return fail(join(path, 'help'), format('phrase d\'aide de 1 à %d octets obligatoire', LIMITS.help))
    end
    if field.group ~= nil and (type(field.group) ~= 'string' or not groups[field.group]) then
        return fail(join(path, 'group'), 'groupe inconnu')
    end
    if field.width ~= nil and not WIDTHS[field.width] then return fail(join(path, 'width'), 'full ou half attendu') end
    if field.optional ~= nil then
        if type(field.optional) ~= 'boolean' then return fail(join(path, 'optional'), 'booléen attendu') end
        if field.optional and not OPTIONAL_WIDGETS[widget] then
            return fail(join(path, 'optional'), 'permis pour text, select, item et model seulement')
        end
    end
    return checkWidget[widget](field, path)
end

--- Formulaire d'un type.
---@param form any
---@param path? string
---@return boolean ok
---@return string|nil err
---@return boolean|nil usesSource  un champ demande une liste au module (`options` obligatoire)
function fs.checkForm(form, path)
    path = path or 'form'
    if type(form) ~= 'table' then return fail(path, 'table attendue') end
    local unknown = unknownKey(form, FORM_KEYS)
    if unknown then return fail(join(path, unknown), 'clé inconnue') end
    local groups = {}
    if form.groups ~= nil then
        if not isList(form.groups, 0, LIMITS.groups) then
            return fail(join(path, 'groups'), format('liste de %d groupes au plus attendue', LIMITS.groups))
        end
        for i, group in ipairs(form.groups) do
            local here = format('%s.groups[%d]', path, i)
            if type(group) ~= 'table' then return fail(here, 'table attendue') end
            local key = unknownKey(group, GROUP_KEYS)
            if key then return fail(join(here, key), 'clé inconnue') end
            if not isIdentifier(group.id, KEY_PATTERN, MAX_KEY) then
                return fail(join(here, 'id'), 'identifiant attendu')
            end
            if groups[group.id] then return fail(join(here, 'id'), 'groupe en double') end
            groups[group.id] = true
            if not isText(group.label, 1, LIMITS.groupLabel) then
                return fail(join(here, 'label'), format('texte de 1 à %d octets attendu', LIMITS.groupLabel))
            end
            if group.help ~= nil and not isText(group.help, 1, LIMITS.groupHelp) then
                return fail(join(here, 'help'), format('texte de 1 à %d octets attendu', LIMITS.groupHelp))
            end
            if not isBool(group.folded) then return fail(join(here, 'folded'), 'booléen attendu') end
        end
    end
    if not isList(form.fields, 1, LIMITS.fields) then
        return fail(join(path, 'fields'), format('liste de 1 à %d champs attendue', LIMITS.fields))
    end
    local seen, counts, usesSource = {}, { n = 0, s = 0, b = 0 }, false
    for i, field in ipairs(form.fields) do
        local here = format('%s.fields[%d]', path, i)
        local ok, err = checkField(field, here, groups)
        if not ok then return false, err end
        if seen[field.id] then return fail(join(here, 'id'), 'champ en double') end
        seen[field.id] = field
        local card = CARD[field.widget]
        counts[card] = counts[card] + 1
        if field.source ~= nil then usesSource = true end
    end
    if counts.s > LIMITS.cardS then
        return fail(join(path, 'fields'), format('plus de %d champs texte ou choix (carte s)', LIMITS.cardS))
    end
    if counts.b > LIMITS.cardB then
        return fail(join(path, 'fields'), format('plus de %d interrupteurs (carte b)', LIMITS.cardB))
    end
    local title = type(form.titleField) == 'string' and seen[form.titleField] or nil
    if not title then return fail(join(path, 'titleField'), 'champ du formulaire obligatoire') end
    if title.widget ~= 'text' or title.multiline or title.optional then
        return fail(join(path, 'titleField'), 'champ text sur une ligne, non facultatif, attendu')
    end
    return true, nil, usesSource
end

---@class vAvA.AtelierSchemaContext
---@field families table<string, boolean>  familles connues (config.families)
---@field rights table<string, boolean>    droits permis (config.rights.allowed)
---@field icons table<string, boolean>     icônes de l'interface

--- Déclaration complète d'un éditeur.
---@param def any
---@param ctx vAvA.AtelierSchemaContext
---@return boolean ok
---@return string|nil err
function fs.checkEditor(def, ctx)
    if type(def) ~= 'table' then return fail('éditeur', 'table attendue') end
    local unknown = unknownKey(def, EDITOR_KEYS)
    if unknown then return fail(unknown, 'clé inconnue') end
    if type(def.family) ~= 'string' or not ctx.families[def.family] then return fail('family', 'famille inconnue') end
    if not isText(def.label, 1, LIMITS.label) then
        return fail('label', format('texte de 1 à %d octets attendu', LIMITS.label))
    end
    if not isText(def.description, 1, LIMITS.description) then
        return fail('description', format('texte de 1 à %d octets attendu', LIMITS.description))
    end
    if type(def.icon) ~= 'string' or not ctx.icons[def.icon] then
        return fail('icon', 'icône inconnue de l\'interface')
    end
    if def.order ~= nil and (not isInteger(def.order) or def.order < 0 or def.order > LIMITS.order) then
        return fail('order', format('entier de 0 à %d attendu', LIMITS.order))
    end
    if type(def.right) ~= 'string' or not ctx.rights[def.right] then return fail('right', 'droit non permis') end
    local texts = def.texts
    if type(texts) ~= 'table' then return fail('texts', 'table attendue (trial, publish, publishHint?)') end
    local key = unknownKey(texts, TEXTS_KEYS)
    if key then return fail(join('texts', key), 'clé inconnue') end
    for _, name in ipairs({ 'trial', 'publish' }) do
        if not isText(texts[name], 1, LIMITS.textsLabel) then
            return fail(join('texts', name), format('texte de 1 à %d octets attendu', LIMITS.textsLabel))
        end
    end
    if texts.publishHint ~= nil and not isText(texts.publishHint, 0, LIMITS.publishHint) then
        return fail('texts.publishHint', format('texte de %d octets au plus', LIMITS.publishHint))
    end
    if texts.trialLine ~= nil and not isText(texts.trialLine, 0, DEF.trialLine) then
        return fail('texts.trialLine', format('texte de %d octets au plus', DEF.trialLine))
    end
    if def.format ~= nil and (not isInteger(def.format) or def.format < 1 or def.format > DEF.formatMax) then
        return fail('format', format('entier de 1 à %d attendu', DEF.formatMax))
    end

    if not isList(def.kinds, 1, LIMITS.kinds) then
        return fail('kinds', format('liste de 1 à %d types attendue', LIMITS.kinds))
    end
    local kindIds, usesSource = {}, false
    for i, kind in ipairs(def.kinds) do
        local here = format('kinds[%d]', i)
        if type(kind) ~= 'table' then return fail(here, 'table attendue') end
        key = unknownKey(kind, KIND_KEYS)
        if key then return fail(join(here, key), 'clé inconnue') end
        if not isIdentifier(kind.id, KEY_PATTERN, MAX_KEY) then
            return fail(join(here, 'id'), format('identifiant au motif %s, %d octets au plus', KEY_PATTERN, MAX_KEY))
        end
        if kindIds[kind.id] then return fail(join(here, 'id'), 'type en double') end
        kindIds[kind.id] = true
        for _, name in ipairs({ 'noun', 'nounPlural' }) do
            if not isText(kind[name], 1, LIMITS.noun) then
                return fail(join(here, name), format('texte de 1 à %d octets attendu', LIMITS.noun))
            end
        end
        if type(kind.article) ~= 'string' or not VavaAtelier.ARTICLES[kind.article] then
            return fail(join(here, 'article'), 'le, la ou l\' attendu')
        end
        if not isText(kind.newLabel, 1, LIMITS.newLabel) then
            return fail(join(here, 'newLabel'), format('texte de 1 à %d octets attendu', LIMITS.newLabel))
        end
        if type(kind.layout) ~= 'string' or not VavaAtelier.LAYOUTS[kind.layout] then
            return fail(join(here, 'layout'), 'page ou side attendu')
        end
        if not isBool(kind.creatable) then return fail(join(here, 'creatable'), 'booléen attendu') end
        if not isBool(kind.feminine) then return fail(join(here, 'feminine'), 'booléen attendu') end
        if kind.steps ~= nil then
            if not isList(kind.steps, 0, LIMITS.steps) then
                return fail(join(here, 'steps'), format('liste de %d étapes au plus attendue', LIMITS.steps))
            end
            for s, step in ipairs(kind.steps) do
                if not isText(step, 1, LIMITS.step) then
                    return fail(format('%s.steps[%d]', here, s), format('texte de 1 à %d octets attendu', LIMITS.step))
                end
            end
        end
        local placement = kind.placement
        if placement ~= nil and (type(placement) ~= 'string' or not VavaAtelier.PLACEMENTS[placement]) then
            return fail(join(here, 'placement'), 'point, oriented, circle, polygon ou door attendu')
        end
        local ok, err, source = fs.checkForm(kind.form, join(here, 'form'))
        if not ok then return false, err end
        usesSource = usesSource or source
    end
    local parents = {}
    for i, kind in ipairs(def.kinds) do
        local parent = kind.parent
        if parent ~= nil and (type(parent) ~= 'string' or parent == kind.id or not kindIds[parent]) then
            return fail(format('kinds[%d].parent', i), 'identifiant d\'un autre type de cet éditeur attendu')
        end
        parents[kind.id] = parent
    end
    -- chaîne des parents : jamais de cycle (A → B → A), trois types au plus (fiche, enfant, petit-enfant)
    for i, kind in ipairs(def.kinds) do
        local depth, current = 1, parents[kind.id]
        while current do
            depth = depth + 1
            if current == kind.id then return fail(format('kinds[%d].parent', i), 'cycle de parents') end
            if depth > DEF.parentDepth then
                return fail(format('kinds[%d].parent', i), format('chaîne de plus de %d types', DEF.parentDepth))
            end
            current = parents[current]
        end
    end

    for _, name in ipairs(REQUIRED_FUNCTIONS) do
        if not isCallable(def[name]) then return fail(name, 'fonction obligatoire') end
    end
    for _, name in ipairs(OPTIONAL_FUNCTIONS) do
        if def[name] ~= nil and not isCallable(def[name]) then return fail(name, 'fonction attendue') end
    end
    if usesSource and def.options == nil then return fail('options', 'fonction obligatoire (un champ a une source)') end
    -- atelier gardé : apply et remove ensemble ; l'essai (trial, endTrial ensemble) n'a de sens que gardé
    if (def.apply == nil) ~= (def.remove == nil) then
        return fail(def.apply == nil and 'apply' or 'remove', 'apply et remove se déclarent ensemble')
    end
    if (def.trial == nil) ~= (def.endTrial == nil) then
        return fail(def.trial == nil and 'trial' or 'endTrial', 'trial et endTrial se déclarent ensemble')
    end
    if def.trial ~= nil and def.apply == nil then return fail('trial', 'un essai demande apply et remove') end
    return true
end
