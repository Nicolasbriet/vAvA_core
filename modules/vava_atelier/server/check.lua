--[[
    vava_atelier/server/check.lua
    Rôle : « Vérifier » une fiche, sans rien changer au royaume ni au journal. Dans l'ordre : valeurs reçues → data
           (shared/formvalues.lua : clés, cartes, bornes, pas, choix, jeux de caractères), contrôles du monde (objet
           existant dans vava_inventory:items et de la sorte demandée, valeur rendue par la source du module), puis
           `validate` du module, seul juge des règles du jeu (§ 7.3 de la spec : vrai, erreur générale ou erreurs par
           champ ; toute autre forme est une erreur de l'éditeur). Erreurs mises en mots ici (textes de la config).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/formvalues.lua, bridge/server.lua,
                  server/core.lua, server/entries.lua
]]

local type, ipairs, format = type, ipairs, string.format

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local messages = cfg.texts.fields
local Bridge = VavaAtelier.bridge
local entries = VavaAtelier.entries
local text, fv = VavaAtelier.text, VavaAtelier.formvalues
local OUT = VavaAtelier.OUT

local check = {}
VavaAtelier.check = check

--- Valeur d'un champ mise en mots pour un message (« 1,5 m », « × 2 », « 7 jours »).
---@param field table
---@param value number
---@return string
local function show(field, value)
    if field.widget == 'duration' then return text.duration(value) end
    local written = text.number(value, field.decimals)
    if field.prefix and field.prefix ~= '' then written = field.prefix .. ' ' .. written end
    if field.unit and field.unit ~= '' then written = written .. ' ' .. field.unit end
    return written
end

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

--- Contrôles du monde sur une data déjà en forme : objet existant (et de la sorte demandée), valeur d'une source.
---@param ctx vAvA.AtelierContext
---@param data table
---@return table[]|nil errors
---@return string|nil code  editor_error (source du module muette)
local function world(ctx, data)
    local errors = {}
    for _, field in ipairs(ctx.kind.def.form.fields) do
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
                local known = entries.inSource(ctx.editor, field, value)
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
    local data, problems = fv.toData(kind.def.form, values)
    if not data then
        local errors = {}
        for _, problem in ipairs(problems) do
            if problem.code == 'unknown_field' then return false, 'unknown_field' end
            local field = problem.field and kind.fields[problem.field]
            local message = field and describe(field, problem.code, problem.args) or messages.type
            errors[#errors + 1] = { field = problem.field, text = message }
        end
        return true, { valid = false, errors = bounded(errors) }
    end
    local errors, code = world(ctx, data)
    if not errors then return false, code end
    if #errors > 0 then return true, { valid = false, errors = bounded(errors) } end
    local called, ok, detail = Bridge.CallEditor(editor.id, 'validate', editor.fns.validate, kindId, data,
        { source = ctx.source, accountId = ctx.accountId, id = id ~= '' and id or nil })
    if not called then return false, 'editor_error' end
    local found = moduleErrors(kind, ok, detail)
    if not found then
        VavaAtelier.log.error('%s.validate(%s) : réponse d\'une forme inattendue (true, false + texte, false + liste)',
            editor.id, kindId)
        return false, 'editor_error'
    end
    if #found > 0 then return true, { valid = false, errors = found } end
    return true, { valid = true, compare = entries.compare(editor, kindId, data) }
end
