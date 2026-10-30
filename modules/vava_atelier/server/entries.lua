--[[
    vava_atelier/server/entries.lua
    Rôle : ce qui est en vigueur chez les modules, lu pour l'interface. Liste d'un type (fonction `index` du module,
           nettoyée, triée, gardée `limits.cacheMs`), filtre et pages ; fiche (`read` du module → paquet de valeurs,
           libellés des valeurs choisies dans une liste distante, valeurs reprises par défaut signalées, encadré
           « Pour comparer ») ; valeurs proposées d'un champ (source du
           module gardée `limits.cacheMs`, ou objets du royaume) ; recherche dans les ateliers visibles. Points
           d'extension `index`, `read`, `state`, `footer` (T-101 les remplace : la base fera foi).
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/formvalues.lua, bridge/server.lua,
                  server/core.lua, server/editors.lua
]]

local type, ipairs, pairs = type, ipairs, pairs
local find = string.find
local sort = table.sort
local ceil, max, min = math.ceil, math.max, math.min
local GetGameTimer = GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local limits = cfg.limits
local texts = cfg.texts
local Bridge = VavaAtelier.bridge
local providers = VavaAtelier.providers
local text, fv = VavaAtelier.text, VavaAtelier.formvalues
local OUT = VavaAtelier.OUT
local ENTRY_PATTERN, MAX_ENTRY = VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY
local OPTION_PATTERN, MAX_OPTION, MAX_MODEL = VavaAtelier.OPTION_PATTERN, VavaAtelier.MAX_OPTION, VavaAtelier.MAX_MODEL

local entries = {}
VavaAtelier.entries = entries

-- listes gardées : éditeur → type → { at, list, byId } ; sources : éditeur → source → { at, list }
local indexCache, sourceCache = {}, {}

-- Points d'extension (T-100 : ce que dit le module) ------------------------------------------------------------------

--- Entrées en vigueur d'un type, telles que le module les rend (nettoyées ensuite).
---@param editor vAvA.AtelierEditor
---@param kindId string
---@return boolean called
---@return any list
function providers.index(editor, kindId)
    return Bridge.CallEditor(editor.id, 'index', editor.fns.index, kindId)
end

--- Valeurs d'une entrée en vigueur, telles que le module les rend.
---@param editor vAvA.AtelierEditor
---@param kindId string
---@param id string
---@return boolean called
---@return any data
function providers.read(editor, kindId, id)
    return Bridge.CallEditor(editor.id, 'read', editor.fns.read, kindId, id)
end

--- Étiquette d'état d'une fiche : « En vigueur » (lue chez le module) ou « Rien d'enregistré ».
---@param _ vAvA.AtelierEditor
---@param _kind string
---@param id string  '' : entrée nouvelle
---@return { label: string, tone: string }
function providers.state(_, _kind, id)
    if id == '' then return { label = texts.stateNew, tone = 'new' } end
    return { label = texts.stateLive, tone = 'live' }
end

--- Boutons du pied de fiche (T-100 : « Vérifier » seul).
---@return { id: string, label: string, primary: boolean }[]
function providers.footer()
    return { { id = 'check', label = texts.check, primary = true } }
end

-- Listes ------------------------------------------------------------------------------------------------------------

--- Une entrée rendue par `index`, nettoyée : identifiant au motif, titre de 1 à 64 octets, indice de 60 au plus.
local function cleanEntry(raw)
    if type(raw) ~= 'table' then return nil end
    local id, title, hint = raw.id, raw.title, raw.hint
    if type(id) ~= 'string' or #id > MAX_ENTRY or not find(id, ENTRY_PATTERN) then return nil end
    if type(title) ~= 'string' or not text.isUtf8(title) or text.hasControl(title) then return nil end
    title = text.truncate(text.trim(title), OUT.title)
    if title == '' then return nil end
    local entry = { id = id, title = title, search = text.normalize(title) }
    if type(hint) == 'string' and text.isUtf8(hint) and not text.hasControl(hint) and hint ~= '' then
        entry.hint = text.truncate(hint, OUT.hint)
    end
    return entry
end

--- Liste en vigueur d'un type (gardée `limits.cacheMs`) : { list, byId }, ou nil si le module ne répond pas.
---@param editor vAvA.AtelierEditor
---@param kindId string
---@return table|nil
function entries.index(editor, kindId)
    local now = GetGameTimer()
    local byEditor = indexCache[editor.id]
    if not byEditor then
        byEditor = {}
        indexCache[editor.id] = byEditor
    end
    local cached = byEditor[kindId]
    if cached and now - cached.at < limits.cacheMs then return cached end
    local called, raw = providers.index(editor, kindId)
    if not called then return nil end
    if type(raw) ~= 'table' then
        VavaAtelier.log.error('%s.index(%s) : liste attendue, reçu %s', editor.id, kindId, type(raw))
        return nil
    end
    local list, byId = {}, {}
    for _, item in ipairs(raw) do
        local entry = cleanEntry(item)
        if entry and not byId[entry.id] then
            if #list >= limits.indexEntries then
                VavaAtelier.log.warn('%s.index(%s) : plus de %d entrées, la suite est ignorée', editor.id, kindId,
                    limits.indexEntries)
                break
            end
            list[#list + 1] = entry
            byId[entry.id] = entry
        end
    end
    sort(list, function(a, b)
        if a.search ~= b.search then return a.search < b.search end
        return a.id < b.id
    end)
    cached = { at = now, list = list, byId = byId }
    byEditor[kindId] = cached
    return cached
end

--- Nombre d'entrées en vigueur du type principal (étiquette de l'accueil), ou nil si le module ne répond pas.
---@param editor vAvA.AtelierEditor
---@return integer|nil
function entries.count(editor)
    local index = entries.index(editor, editor.firstKind)
    return index and #index.list or nil
end

--- Page d'une liste : { total, page, pages, entries = { { id, title, hint? } } }.
---@param ctx vAvA.AtelierContext
---@param page integer
---@param query string
---@return boolean ok
---@return table|string result
function entries.list(ctx, page, query)
    local index = entries.index(ctx.editor, ctx.kind.def.id)
    if not index then return false, 'editor_error' end
    local needle = text.normalize(query)
    local matched = {}
    for _, entry in ipairs(index.list) do
        if text.contains(entry.search, needle) then matched[#matched + 1] = entry end
    end
    local size = limits.pageSize
    local pages = max(1, ceil(#matched / size))
    page = min(page, pages)
    local out = {}
    for i = (page - 1) * size + 1, min(#matched, page * size) do
        local entry = matched[i]
        out[#out + 1] = { id = entry.id, title = entry.title, hint = entry.hint }
    end
    return true, { total = #matched, page = page, pages = pages, entries = out }
end

--- Encadré « Pour comparer » d'un module : { title, text } borné, ou nil.
---@param editor vAvA.AtelierEditor
---@param kindId string
---@param data table
---@return table|nil
function entries.compare(editor, kindId, data)
    if not editor.fns.compare then return nil end
    local called, raw = Bridge.CallEditor(editor.id, 'compare', editor.fns.compare, kindId, data)
    if not called or type(raw) ~= 'table' or type(raw.title) ~= 'string' or not text.isUtf8(raw.title) then
        return nil
    end
    local body = type(raw.text) == 'string' and text.isUtf8(raw.text) and raw.text or ''
    return { title = text.truncate(raw.title, OUT.compareTitle), text = text.truncate(body, OUT.compareText) }
end

--- Longueur d'une valeur de la source d'un champ : 64 pour un modèle, 32 pour un choix.
---@param field table
---@return integer
local function sourceMax(field)
    return field.widget == 'model' and MAX_MODEL or MAX_OPTION
end

--- Libellés des valeurs courantes des champs à liste distante (select ou model à source, objet), tirés de la source
--- gardée et des objets du royaume : { [champ] = { label, image?, provisional? } }. Une valeur vide, absente de sa
--- liste, ou dont la liste ne répond pas n'a pas de libellé (la page montre alors la valeur brute).
---@param editor vAvA.AtelierEditor
---@param form table
---@param strings table<string, string>|nil  carte `s` du paquet de la fiche
---@return table<string, table>
local function labelsOf(editor, form, strings)
    local labels = {}
    if not strings then return labels end
    for _, field in ipairs(form.fields) do
        local value, known = strings[field.id], nil
        if type(value) == 'string' and value ~= '' then
            if field.widget == 'item' then
                known = Bridge.Item(value)
            elseif field.source and (field.widget == 'select' or field.widget == 'model') then
                local _, byValue = entries.source(editor, field.source, sourceMax(field))
                known = byValue and byValue[value]
            end
        end
        if known then
            labels[field.id] = { label = known.label, image = known.image, provisional = known.provisional }
        end
    end
    return labels
end

--- Fiche en vigueur : { id, title, values, labels, warnings?, compare?, state, footer }.
---@param ctx vAvA.AtelierContext
---@param id string
---@return boolean ok
---@return table|string result
function entries.read(ctx, id)
    local editor, kind = ctx.editor, ctx.kind
    local kindId = kind.def.id
    local index = entries.index(editor, kindId)
    if not index then return false, 'editor_error' end
    local entry = index.byId[id]
    if not entry then return false, 'unknown_entry' end
    local called, data = providers.read(editor, kindId, id)
    if not called then return false, 'editor_error' end
    if data == nil then return false, 'unknown_entry' end
    if type(data) ~= 'table' then
        VavaAtelier.log.error('%s.read(%s, %s) : table attendue, reçu %s', editor.id, kindId, id, type(data))
        return false, 'editor_error'
    end
    local values, warnings = fv.toPacket(kind.def.form, data)
    return true, {
        id = id, title = entry.title, values = values,
        -- la page n'appelle plus `options` à l'ouverture d'une fiche pour nommer les valeurs choisies
        labels = labelsOf(editor, kind.def.form, values.s),
        warnings = #warnings > 0 and warnings or nil,
        compare = entries.compare(editor, kindId, data),
        state = providers.state(editor, kindId, id),
        footer = providers.footer(editor, kindId, id),
    }
end

-- Valeurs proposées -------------------------------------------------------------------------------------------------

--- Liste d'une source de module (gardée `limits.cacheMs`), nettoyée au motif du widget : { { value, label,
--- provisional?, search } } et la même indexée par valeur, ou nil si le module ne répond pas.
---@param editor vAvA.AtelierEditor
---@param source string
---@param maxValue integer  longueur d'une valeur (32 pour select, 64 pour model)
---@return table[]|nil list
---@return table<string, table>|nil byValue
function entries.source(editor, source, maxValue)
    local now = GetGameTimer()
    local byEditor = sourceCache[editor.id]
    if not byEditor then
        byEditor = {}
        sourceCache[editor.id] = byEditor
    end
    local key = source .. '#' .. maxValue
    local cached = byEditor[key]
    if cached and now - cached.at < limits.cacheMs then return cached.list, cached.byValue end
    local called, raw = Bridge.CallEditor(editor.id, 'options', editor.fns.options, source)
    if not called then return nil end
    if type(raw) ~= 'table' then
        VavaAtelier.log.error('%s.options(%s) : liste attendue, reçu %s', editor.id, source, type(raw))
        return nil
    end
    local list, byValue = {}, {}
    for _, item in ipairs(raw) do
        if type(item) == 'table' and type(item.value) == 'string' and #item.value <= maxValue
            and find(item.value, OPTION_PATTERN) and not byValue[item.value] then
            local label = item.value
            if type(item.label) == 'string' and item.label ~= '' and text.isUtf8(item.label)
                and not text.hasControl(item.label) then
                label = item.label
            end
            label = text.truncate(label, OUT.optionLabel)
            local option = { value = item.value, label = label, provisional = item.provisional == true or nil,
                search = text.normalize(label .. ' ' .. item.value) }
            list[#list + 1] = option
            byValue[item.value] = option
            if #list >= limits.optionsMax then break end
        end
    end
    byEditor[key] = { at = now, list = list, byValue = byValue }
    return list, byValue
end

--- Une valeur appartient-elle à la source d'un champ ? nil si le module ne répond pas.
---@param editor vAvA.AtelierEditor
---@param field table
---@param value string
---@return boolean|nil
function entries.inSource(editor, field, value)
    local list, byValue = entries.source(editor, field.source, sourceMax(field))
    if not list then return nil end
    return byValue[value] ~= nil
end

--- Valeurs proposées d'un champ (select ou model à source, objet) : { items = { { value, label, image?,
--- provisional? } }, more }.
---@param ctx vAvA.AtelierContext
---@param fieldId string
---@param query string
---@param page integer
---@return boolean ok
---@return table|string result
function entries.options(ctx, fieldId, query, page)
    local field = ctx.kind.fields[fieldId]
    if not field then return false, 'unknown_field' end
    local list
    if field.widget == 'item' then
        list = Bridge.Items()
        if not list then return true, { items = {}, more = false } end
    elseif (field.widget == 'select' or field.widget == 'model') and field.source then
        list = entries.source(ctx.editor, field.source, sourceMax(field))
        if not list then return false, 'editor_error' end
    else
        return false, 'unknown_field'
    end
    local needle, category = text.normalize(query), field.category
    if category == '' then category = nil end
    local size, from = limits.optionsPage, (page - 1) * limits.optionsPage
    local items, matched = {}, 0
    for _, item in ipairs(list) do
        if (not category or item.category == category) and text.contains(item.search, needle) then
            matched = matched + 1
            if matched > from and matched <= from + size then
                items[#items + 1] = {
                    value = item.value, label = item.label, image = item.image, provisional = item.provisional,
                }
            elseif matched > from + size then
                break
            end
        end
    end
    return true, { items = items, more = matched > from + size }
end

-- Recherche ---------------------------------------------------------------------------------------------------------

--- Entrées et ateliers dont le nom contient le texte, dans les ateliers visibles de ce membre : { hits = { { editor,
--- kind, id?, title, where } } } (20 au plus).
---@param visible vAvA.AtelierEditor[]
---@param query string
---@return boolean ok
---@return table result
function entries.search(visible, query)
    local needle = text.normalize(query)
    local hits, limit = {}, limits.searchHits
    if #needle < 2 then return true, { hits = hits } end
    for _, editor in ipairs(visible) do
        if #hits >= limit then break end
        if text.contains(text.normalize(editor.label), needle) then
            hits[#hits + 1] = {
                editor = editor.id, kind = editor.firstKind, title = editor.label, where = texts.searchWorkshop,
            }
        end
        local kinds = {}
        for kindId, kind in pairs(editor.kinds) do kinds[kind.rank] = kindId end
        for _, kindId in ipairs(kinds) do
            if #hits >= limit then break end
            local index = entries.index(editor, kindId)
            if index then
                local where = editor.label .. ' › ' .. editor.kinds[kindId].def.noun
                for _, entry in ipairs(index.list) do
                    if text.contains(entry.search, needle) then
                        hits[#hits + 1] = {
                            editor = editor.id, kind = kindId, id = entry.id, title = entry.title, where = where,
                        }
                        if #hits >= limit then break end
                    end
                end
            end
        end
    end
    return true, { hits = hits }
end

--- Oublie les listes gardées d'un éditeur (retiré du registre).
---@param editorId string
function entries.forget(editorId)
    indexCache[editorId], sourceCache[editorId] = nil, nil
end
