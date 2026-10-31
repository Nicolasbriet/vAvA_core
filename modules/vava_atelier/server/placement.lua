--[[
    vava_atelier/server/placement.lua
    Rôle : les deux RPC de l'outil de placement (T-102, § 6.1 et § 7.1 de la spec) :
             - `place` : poser ou déplacer une fiche. Contrôles dans l'ordre : atelier gardé et disponible, type placé
               (jamais une porte : T-106), instance du royaume, personnage présent (position lue par le serveur),
               forme du lieu (shared/place.lua : clés, bornes, arrondis), portée (shared/placerules.lua), fiche
               (nouvelle : valeurs du modèle passées par le formulaire et le monde, parent vivant, titre donné tout
               seul, plafonds ; existante : vivante, sans valeurs), règles déclarées par le type (parent et frères lus
               en base), `placeCheck` du module ; puis l'écriture (server/lifecycle.lua › cycle.place : table de
               décision, brouillon et brouillon du parent dans la même transaction, essai relancé, avis, journal).
               Refus de lieu : `{ done = false, errors = { { field = 'place', text } } }` ; refus de structure :
               `false, code`. Aucun lieu calculé par le client n'est cru : la visée n'est qu'un aperçu.
             - `children` : lieux d'une fiche, de son parent et de ses enfants (type parent) ou de ses frères (type
               enfant), pour dessiner et pour la liste « Points de la zone » : { self, parent?, rows }, 200 lignes au
               plus, au seul appelant.
           Ni l'une ni l'autre n'envoie quoi que ce soit aux joueurs : une pose n'écrit qu'un brouillon.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/formvalues.lua, shared/place.lua,
                  shared/placerules.lua, shared/slug.lua, shared/lifecycle.lua, bridge/server.lua, server/core.lua,
                  server/entries.lua, server/check.lua, server/store.lua, server/index.lua, server/calls.lua,
                  server/lifecycle.lua
]]

local type, ipairs, pairs, tostring, next = type, ipairs, pairs, tostring, next
local find, format = string.find, string.format
local sort = table.sort

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local placementCfg = cfg.placement
local placeTexts = placementCfg.texts
local Bridge = VavaAtelier.bridge
local entries, check, store, index, calls, cycle = VavaAtelier.entries, VavaAtelier.check, VavaAtelier.store,
    VavaAtelier.index, VavaAtelier.calls, VavaAtelier.cycle
local fv, place, placerules, slug, lc = VavaAtelier.formvalues, VavaAtelier.place, VavaAtelier.placerules,
    VavaAtelier.slug, VavaAtelier.lifecycle
local text = VavaAtelier.text
local OUT, MAX_OPTION, MAX_MODEL = VavaAtelier.OUT, VavaAtelier.MAX_OPTION, VavaAtelier.MAX_MODEL
local MODEL_PATTERN = VavaAtelier.MODEL_PATTERN

local placement = {}
VavaAtelier.placement = placement

local LIMITS = { reach = placementCfg.reach, polygonFactor = placementCfg.polygonFactor }
local CARDS = { 'n', 's', 'b' }

--- Refus jugé sur le lieu : { done = false, errors = { { field = 'place', text } } }.
---@param why string
local function refusedPlace(why)
    return true, { done = false, errors = { { field = 'place', text = text.truncate(tostring(why), OUT.errorText) } } }
end

--- Valeurs vides (fiche existante : rien d'autre que le lieu ne change par une pose).
local function emptyValues(values)
    if type(values) ~= 'table' then return true end
    for _, card in ipairs(CARDS) do
        if type(values[card]) == 'table' and next(values[card]) ~= nil then return false end
    end
    return true
end

-- Lecture des lieux --------------------------------------------------------------------------------------------------

--- Fiche lue en base pour un membre : son brouillon s'il en a un (ou, `anyDraft`, le brouillon d'un autre), sinon la
--- publiée ; jamais un retrait. entry ({ data, place, parent }), ou nil, code.
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param head vAvA.AtelierHead
---@param accountId integer
---@param anyDraft boolean
local function readEntry(editor, kind, head, accountId, anyDraft)
    local draft = head.draft
    local rowId
    if draft and not draft.removal and (anyDraft or draft.holder == accountId) then
        rowId = draft.row
    elseif head.published then
        rowId = head.published.row
    end
    if not rowId then return nil, 'unknown_entry' end
    local row, entry = cycle.rowEntry(editor, kind, rowId)
    if not row then return nil, entry end
    return entry
end

--- Valeur du champ du fantôme d'une data → { model, label?, provisional? }, ou nil.
---@param kind vAvA.AtelierKind
---@param data table|nil
local function lookOf(kind, data)
    local ghost = kind.def.ghost
    if not ghost or type(data) ~= 'table' then return nil end
    local value = data[ghost.field]
    if type(value) ~= 'string' or value == '' then return nil end
    if ghost.models then
        local look = ghost.models[value]
        if not look then return nil end
        return { model = look.model, label = look.label, provisional = look.provisional == true or nil }
    end
    if #value > MAX_MODEL or not find(value, MODEL_PATTERN) then return nil end
    return { model = value }
end

--- Indice d'une ligne (« 3 récoltes ») tiré de `hintField` et `hintFormat`, ou nil.
---@param kind vAvA.AtelierKind
---@param data table|nil
local function hintOf(kind, data)
    local def = kind.def
    if not def.hintField or type(data) ~= 'table' then return nil end
    local value = data[def.hintField]
    if type(value) ~= 'number' then return nil end
    local field = kind.fields[def.hintField]
    local written = field and field.widget == 'duration' and text.duration(value) or text.number(value)
    return text.truncate(format(def.hintFormat or '%s', written), OUT.hint)
end

--- Lignes de CHILDREN_SQL regroupées par fiche (types voulus seulement) : clé 'type|id' → { kind, id, published?,
--- draft? }, dans l'ordre d'arrivée.
---@param rows table[]
---@param kinds table<string, boolean>
local function merge(rows, kinds)
    local byKey, order = {}, {}
    for _, row in ipairs(rows) do
        if kinds[row.kind] then
            local key = row.kind .. '|' .. tostring(row.def_id)
            local item = byKey[key]
            if not item then
                item = { kind = row.kind, id = row.def_id }
                byKey[key] = item
                order[#order + 1] = item
            end
            if row.status == 'published' then item.published = row else item.draft = row end
        end
    end
    return order
end

--- Ligne d'un enfant vu par un membre : { kind, id, title, hint?, tone, place, look?, rev } (place : contrôlée), ou nil
--- si son lieu est illisible ou absent. `tone` : live (publiée), new (brouillon du membre jamais publié), draft
--- (brouillon du membre d'une publiée), removal (retrait préparé), other (brouillon d'un autre membre).
---@param editor vAvA.AtelierEditor
---@param item table
---@param accountId integer
local function rowOf(editor, item, accountId)
    local kind = editor.kinds[item.kind]
    if not kind then return nil end
    local draft, published = item.draft, item.published
    local source = draft or published
    local tone = 'live'
    local rev = 0
    if draft then
        local holder = index.toInt(draft.author_account_id)
        if index.toInt(draft.removal) == 1 then
            tone = 'removal'
        elseif holder ~= nil and holder == accountId then
            tone = published and 'draft' or 'new'
            rev = index.toInt(draft.rev) or 0
        else
            tone = 'other'
        end
        if tone == 'removal' and published then source = published end
    end
    local decoded = type(source.place) == 'string' and source.place ~= '' and Bridge.JsonDecode(source.place) or nil
    local where = decoded and place.check(kind.def.placement, decoded, cfg.place) or nil
    if not where then return nil end
    local data = nil
    if kind.def.hintField or kind.def.ghost then
        data = type(source.data) == 'string' and Bridge.JsonDecode(source.data) or nil
    end
    return {
        kind = item.kind, id = item.id, title = text.truncate(tostring(source.title or item.id), OUT.title),
        hint = hintOf(kind, data), tone = tone, place = where, rev = rev,
        -- un point publié a déjà son modèle en jeu : pas de fantôme
        look = tone ~= 'live' and tone ~= 'removal' and lookOf(kind, data) or nil,
    }
end

--- Enfants (types `kinds`) d'une fiche vus par un membre, triés par titre : lignes ; ou nil, code.
local function childRows(editor, parentId, kinds, accountId)
    local raw, err = store.children(editor.id, parentId, placementCfg.childrenMax * 2)
    if not raw then return nil, err end
    local wanted = {}
    for _, kindId in ipairs(kinds) do wanted[kindId] = true end
    local out = {}
    for _, item in ipairs(merge(raw, wanted)) do
        if #out >= placementCfg.childrenMax then break end
        local row = rowOf(editor, item, accountId)
        if row then out[#out + 1] = row end
    end
    sort(out, function(a, b)
        if a.title ~= b.title then return a.title < b.title end
        return a.id < b.id
    end)
    return out
end

-- Pose ---------------------------------------------------------------------------------------------------------------

--- Libellé d'un choix (select ou segmented) : options déclarées, ou source du module ; nil s'il est inconnu.
local function choiceLabel(editor, field, value)
    if type(value) ~= 'string' or value == '' then return nil end
    for _, option in ipairs(field.options or {}) do
        if option.value == value then return option.label end
    end
    if field.source then
        local _, byValue = entries.source(editor, field.source, MAX_OPTION)
        local known = byValue and byValue[value]
        return known and known.label or nil
    end
    return nil
end

--- Valeurs d'un enfant nouveau : défauts du formulaire, puis les valeurs du modèle reçues, puis le titre donné tout
--- seul (`autoTitle`) s'il est vide. Paquet { n, s, b } prêt pour check.values.
local function newPacket(editor, kind, values, siblingTitles)
    local form = kind.def.form
    local packet = fv.toPacket(form, fv.defaults(form))
    for _, card in ipairs(CARDS) do
        local received = type(values) == 'table' and values[card] or nil
        if type(received) == 'table' then
            packet[card] = packet[card] or {}
            for key, value in pairs(received) do packet[card][key] = value end
        end
    end
    local titleField, autoTitle = form.titleField, kind.def.autoTitle
    packet.s = packet.s or {}
    if autoTitle and (packet.s[titleField] == nil or packet.s[titleField] == '') then
        local label = choiceLabel(editor, kind.fields[autoTitle], packet.s[autoTitle])
        if label then packet.s[titleField] = text.truncate(placerules.autoTitle(label, siblingTitles), 40) end
    end
    return packet
end

--- Frères d'une fiche pour les règles (même type, même parent ; la fiche elle-même, `self`, comprise : la règle
--- l'ignore) : { { id, title, x, y, parent, removal } }, et leurs titres.
local function siblingsOf(rows, kindId, parentId)
    local list, titles = {}, {}
    for _, row in ipairs(rows) do
        if row.kind == kindId then
            local at = placerules.center(row.place)
            titles[#titles + 1] = row.title
            if at then
                list[#list + 1] = { id = row.id, title = row.title, x = at.x, y = at.y, parent = parentId,
                    removal = row.tone == 'removal' }
            end
        end
    end
    return list, titles
end

--- RPC place (§ 7.1 de la spec T-102). `parentArg` : parent d'un enfant nouveau ; pour une fiche existante, '' (la
--- fiche seule) ou son propre parent (« Poser des points » : le brouillon du parent est prévu comme pour un enfant
--- nouveau ; écart documenté au rapport).
---@param ctx vAvA.AtelierContext
---@param id string        '' : fiche nouvelle
---@param rev integer
---@param where table
---@param parentArg string
---@param values table
function placement.place(ctx, id, rev, where, parentArg, values)
    local editor, kind = ctx.editor, ctx.kind
    local kindId = kind.def.id
    -- 2. atelier gardé, disponible ; type placé
    local ok, code = cycle.available(editor, ctx, true)
    if not ok then return false, code end
    local shape = kind.def.placement
    if shape == nil or shape == 'door' then return false, 'not_placeable' end
    -- 3. instance du royaume ; 4. personnage présent, position lue par le serveur
    if Bridge.Bucket(ctx.source) ~= placementCfg.bucket then return false, 'instance' end
    local origin = Bridge.Position(ctx.source)
    if not origin then return false, 'not_ready' end
    -- 5. forme ; 6. portée
    local clean, err = place.check(shape, where, cfg.place)
    if not clean then return refusedPlace(err or 'lieu attendu') end
    local far = placerules.reach(shape, clean, origin, LIMITS)
    if far then return refusedPlace(placerules.text(far, placeTexts)) end
    -- 7. fiche
    local childOf = kind.def.parent
    local head, parentId, parentHead, planParent = nil, nil, nil, nil
    if id == '' then
        if childOf then
            if parentArg == '' then return false, 'parent_missing' end
            parentHead = index.get(editor.id, childOf, parentArg)
            if not index.alive(parentHead) or not (parentHead.published
                or (parentHead.draft and parentHead.draft.holder == ctx.accountId)) then
                return false, 'parent_missing'
            end
            parentId, planParent = parentArg, parentHead
        elseif parentArg ~= '' then
            return false, 'bad_request'
        end
        if index.liveCount(editor.id, kindId) >= cfg.definitions.perKind then return false, 'full' end
    else
        head = index.get(editor.id, kindId, id)
        if not index.alive(head) then return false, 'unknown_entry' end
        if not emptyValues(values) then return false, 'bad_request' end
        parentId = (head.draft and head.draft.parent) or (head.published and head.published.parent) or nil
        if parentArg ~= '' then
            if not childOf or parentArg ~= parentId then return false, 'bad_request' end
            parentHead = index.get(editor.id, childOf, parentId)
            if not index.alive(parentHead) then return false, 'parent_missing' end
            planParent = parentHead
        elseif childOf and parentId then
            parentHead = index.get(editor.id, childOf, parentId)
        end
    end
    -- lieux du parent et des frères (règles déclarées, titre d'un enfant nouveau)
    local parentInfo, siblings, titles = nil, {}, {}
    if childOf and parentId then
        local rows, rowsErr = childRows(editor, parentId, { kindId }, ctx.accountId)
        if not rows then return false, rowsErr end
        siblings, titles = siblingsOf(rows, kindId, parentId)
        if parentHead and index.alive(parentHead) then
            local parentKind = editor.kinds[childOf]
            local parentEntry = readEntry(editor, parentKind, parentHead, ctx.accountId, false)
            if parentEntry and parentEntry.place then
                parentInfo = { title = parentHead.title, shape = parentKind.def.placement, place = parentEntry.place }
            end
        end
    end
    -- data : valeurs du modèle (fiche nouvelle), ou la fiche lue
    local data, title
    if id == '' then
        local packet = newPacket(editor, kind, values, titles)
        local errors, valueCode
        data, errors, valueCode = check.values(kind, packet)
        if valueCode then return false, valueCode end
        if not data then return true, { done = false, errors = errors } end
        local worldErrors, worldCode = check.world(editor, kind, data)
        if not worldErrors then return false, worldCode end
        if #worldErrors > 0 then return true, { done = false, errors = check.bounded(worldErrors) } end
        title = calls.titleOf(kind, data, '')
    else
        local entry, readErr = readEntry(editor, kind, head, ctx.accountId, false)
        if not entry then return false, readErr end
        data = entry.data
    end
    -- 9. règles déclarées ; 10. placeCheck du module
    local found = placerules.check(kind.def.rules, shape, clean, {
        parent = parentInfo, parentId = parentId, siblings = siblings, self = id ~= '' and id or nil,
    })
    if found then return refusedPlace(placerules.text(found, placeTexts)) end
    local count = 0
    for _, sibling in ipairs(siblings) do
        if sibling.id ~= id and not sibling.removal then count = count + 1 end
    end
    local allowed, why = calls.placeCheck(editor, kindId, clean, {
        source = ctx.source, accountId = ctx.accountId, id = id, parent = parentId, data = data, siblings = count + 1,
    })
    if not allowed then return refusedPlace(why) end
    -- 8. et 11. tenant, révision, écriture
    local entryId = id
    if id == '' then
        local picked, pickErr = slug.pick(title, kind.def.noun, function(candidate)
            return index.taken(editor.id, kindId, candidate)
        end)
        if not picked then return false, pickErr end
        entryId = picked
    end
    local written, result = cycle.place(ctx, {
        kind = kind, head = head, id = entryId, rev = rev, where = clean, data = data, title = title,
        parentId = parentId, parentHead = planParent,
    })
    if not written then return false, result end
    local placed = result.head
    local situation = lc.situation(placed, ctx.accountId)
    local answer = {
        done = true, id = placed.id, rev = placed.draft and placed.draft.rev or 0, title = placed.title,
        state = cycle.stateOf(placed, situation), footer = cycle.footerOf(editor, situation, placed), place = clean,
        row = {
            kind = kindId, id = placed.id, title = placed.title, hint = hintOf(kind, result.data),
            tone = placed.published and 'draft' or 'new', place = clean, look = lookOf(kind, result.data),
            rev = placed.draft and placed.draft.rev or 0,
        },
    }
    if parentHead and index.alive(parentHead) then
        local parentSituation = lc.situation(parentHead, ctx.accountId)
        answer.parent = {
            id = parentHead.id, rev = parentHead.draft and parentHead.draft.rev or 0,
            state = cycle.stateOf(parentHead, parentSituation),
            footer = cycle.footerOf(editor, parentSituation, parentHead),
        }
    end
    return true, answer
end

-- Lieux d'une fiche ------------------------------------------------------------------------------------------------

--- RPC children : { self = { place? }, parent = { kind, id, title, place? }?, rows } — `rows` : enfants de la fiche
--- (type parent), ou ses frères, elle comprise (type enfant) ; 200 au plus, triés par titre.
---@param ctx vAvA.AtelierContext
---@param id string
function placement.children(ctx, id)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = cycle.available(editor, ctx)
    if not ok then return false, code end
    local kindId = kind.def.id
    local head = index.get(editor.id, kindId, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local entry, err = readEntry(editor, kind, head, ctx.accountId, true)
    if not entry then return false, err end
    local out = { self = { place = entry.place }, rows = {} }
    local parentId, kinds = nil, nil
    if editor.children[kindId] then
        parentId, kinds = id, editor.children[kindId]
    elseif kind.def.parent and entry.parent then
        parentId, kinds = entry.parent, { kindId }
        local parentKind = editor.kinds[kind.def.parent]
        local parentHead = index.get(editor.id, kind.def.parent, parentId)
        if parentKind and index.alive(parentHead) then
            local parentEntry = readEntry(editor, parentKind, parentHead, ctx.accountId, true)
            out.parent = { kind = kind.def.parent, id = parentId, title = parentHead.title,
                place = parentEntry and parentEntry.place or nil }
        end
    end
    if parentId then
        local rows, rowsErr = childRows(editor, parentId, kinds, ctx.accountId)
        if not rows then return false, rowsErr end
        out.rows = rows
    end
    return true, out
end
