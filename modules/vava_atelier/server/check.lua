--[[
    vava_atelier/server/check.lua
    Rôle : « Vérifier » une fiche, sans rien changer au royaume ni au journal. Dans l'ordre : valeurs reçues → data
           (shared/formvalues.lua : clés, cartes, bornes, pas, choix, jeux de caractères), contrôles du monde (objet
           existant dans vava_inventory:items et de la sorte demandée, valeur rendue par la source du module), puis
           `validate` du module, seul juge des règles du jeu (§ 7.3 de la spec : vrai, erreur générale ou erreurs par
           champ ; toute autre forme est une erreur de l'éditeur). Erreurs mises en mots ici (textes de la config).
           T-101 : les mêmes contrôles servent à l'enregistrement (`values`), à l'essai et à la publication
           (`stored` : data gardée revue par le formulaire en vigueur, le monde et le module, avec `ctx.action`).
           La mise en mots des valeurs (`show`) est dans shared/changes.lua.
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/formvalues.lua, shared/changes.lua,
                  bridge/server.lua, server/core.lua, server/entries.lua
]]

local type, ipairs, pairs, format = type, ipairs, pairs, string.format

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local messages = cfg.texts.fields
local Bridge = VavaAtelier.bridge
local entries = VavaAtelier.entries
local text, fv, changes = VavaAtelier.text, VavaAtelier.formvalues, VavaAtelier.changes
local OUT = VavaAtelier.OUT

local check = {}
VavaAtelier.check = check

local show = changes.show

--- Texte d'une erreur de forme (code de shared/formvalues.lua).
---@param field table
---@param code string
---@param args table|nil
---@return string
local function describe(field, code, args)
    if code == 'range' then return format(messages.range, show(field, args[1]), show(field, args[2])) end
    if code == 'step' then return format(messages.step, show(field, args[1])) end
    if code == 'length' then return format(messages.length, args[1], args[2]) end
    if code == 'lines' then return format(messages.lines, args[1]) end
    if code == 'charset' then return messages.charset[field.charset] or messages.charset.free end
    return messages[code] or messages.type
end

--- Erreurs par champ, bornées : { { field?, text } } (16 au plus, textes de 160 octets au plus).
---@param list table[]
---@return table[]
local function bounded(list)
    local out = {}
    for i = 1, #list do
        if i > OUT.errors then break end
        out[i] = list[i]
    end
    return out
end
check.bounded = bounded

--- Contrôles du monde sur une data déjà en forme : objet existant (et de la sorte demandée), valeur d'une source.
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param data table
---@return table[]|nil errors
---@return string|nil code  editor_error (source du module muette)
function check.world(editor, kind, data)
    local errors = {}
    for _, field in ipairs(kind.def.form.fields) do
        local value = data[field.id]
        if value ~= '' and type(value) == 'string' then
            if field.widget == 'item' then
                local item, err = Bridge.Item(value)
                if err == 'unavailable' then
                    errors[#errors + 1] = { field = field.id, text = messages.itemUnavailable }
                elseif not item then
                    errors[#errors + 1] = { field = field.id, text = messages.item }
                elseif field.category and field.category ~= '' and item.category ~= field.category then
                    errors[#errors + 1] = { field = field.id, text = messages.itemCategory }
                end
            elseif field.source then
                local known = entries.inSource(editor, field, value)
                if known == nil then return nil, 'editor_error' end
                if not known then
                    local refusal = field.widget == 'model' and messages.model or messages.choice
                    errors[#errors + 1] = { field = field.id, text = refusal }
                end
            end
        end
    end
    return errors
end

--- Réponse d'un module à `validate`, ramenée à la forme de l'interface. nil : forme refusée (erreur de l'éditeur).
---@param kind vAvA.AtelierKind
---@param ok any
---@param detail any
---@return table[]|nil errors  vide : valide
local function moduleErrors(kind, ok, detail)
    if ok == true then return {} end
    if ok ~= false then return nil end
    if type(detail) == 'string' and text.isUtf8(detail) then
        return { { text = text.truncate(detail, OUT.errorText) } }
    end
    if type(detail) ~= 'table' then return nil end
    local out = {}
    for _, item in ipairs(detail) do
        if type(item) ~= 'table' or type(item.text) ~= 'string' or not text.isUtf8(item.text) then return nil end
        local entry = { text = text.truncate(item.text, OUT.errorText) }
        -- un champ inconnu du formulaire devient une erreur générale
        if type(item.field) == 'string' and kind.fields[item.field] then entry.field = item.field end
        out[#out + 1] = entry
        if #out >= OUT.errors then break end
    end
    if #out == 0 then return nil end
    return out
end

--- `validate` du module, isolé : erreurs (vide : valide), ou nil, 'editor_error'.
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param data table
---@param vctx table  { source, accountId, id?, action?, parent?, place?, bundle? }
---@return table[]|nil
---@return string|nil
function check.module(editor, kind, data, vctx)
    local kindId = kind.def.id
    local called, ok, detail = Bridge.CallEditor(editor.id, 'validate', editor.fns.validate, kindId, data, vctx)
    if not called then return nil, 'editor_error' end
    local found = moduleErrors(kind, ok, detail)
    if not found then
        VavaAtelier.log.error('%s.validate(%s) : réponse d\'une forme inattendue (true, false + texte, false + liste)',
            editor.id, kindId)
        return nil, 'editor_error'
    end
    return found
end

--- Valeurs reçues → data : data, ou nil et les erreurs de forme mises en mots, ou nil, nil, code (unknown_field).
---@param kind vAvA.AtelierKind
---@param values table  { n?, s?, b? }
---@return table|nil data
---@return table[]|nil errors
---@return string|nil code
function check.values(kind, values)
    local data, problems = fv.toData(kind.def.form, values)
    if data then return data end
    local errors = {}
    for _, problem in ipairs(problems) do
        if problem.code == 'unknown_field' then return nil, nil, 'unknown_field' end
        local field = problem.field and kind.fields[problem.field]
        local message = field and describe(field, problem.code, problem.args) or messages.type
        errors[#errors + 1] = { field = problem.field, text = message }
    end
    return nil, bounded(errors)
end

--- Data gardée revue entière (essai, publication, retour en arrière, import) : forme par le formulaire en vigueur,
--- monde, puis `validate` du module. Erreurs (vide : valide), ou nil, code.
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param data table  data normalisée (shared/stored.lua)
---@param vctx table
---@return table[]|nil
---@return string|nil
function check.stored(editor, kind, data, vctx)
    local packet = fv.toPacket(kind.def.form, data)
    local _, errors, code = check.values(kind, packet)
    if code then return nil, code end
    if errors then return errors end
    local worldErrors, worldCode = check.world(editor, kind, data)
    if not worldErrors then return nil, worldCode end
    if #worldErrors > 0 then return bounded(worldErrors) end
    return check.module(editor, kind, data, vctx)
end

--- « Vérifier » : { valid = true, compare? } ou { valid = false, errors = { { field?, text } } }.
---@param ctx vAvA.AtelierContext
---@param id string  '' : entrée nouvelle
---@param values table  { n?, s?, b? }
---@return boolean ok
---@return table|string result
function check.run(ctx, id, values)
    local editor, kind = ctx.editor, ctx.kind
    local kindId = kind.def.id
    if id ~= '' then
        local index = entries.index(editor, kindId)
        if not index then return false, 'editor_error' end
        if not index.byId[id] then return false, 'unknown_entry' end
    end
    -- la clé réservée `parent` d'un type enfant n'est pas un champ (T-101 : enregistrement seulement)
    if kind.def.parent and type(values) == 'table' and type(values.s) == 'table' and values.s.parent ~= nil then
        local copy = {}
        for key, value in pairs(values.s) do if key ~= 'parent' then copy[key] = value end end
        values = { n = values.n, s = copy, b = values.b }
    end
    local data, errors, code = check.values(kind, values)
    if code then return false, code end
    if not data then return true, { valid = false, errors = errors } end
    local worldErrors, worldCode = check.world(editor, kind, data)
    if not worldErrors then return false, worldCode end
    if #worldErrors > 0 then return true, { valid = false, errors = bounded(worldErrors) } end
    local found, moduleCode = check.module(editor, kind, data,
        { source = ctx.source, accountId = ctx.accountId, id = id ~= '' and id or nil, action = 'check' })
    if not found then return false, moduleCode end
    if #found > 0 then return true, { valid = false, errors = found } end
    return true, { valid = true, compare = entries.compare(editor, kindId, data) }
end
