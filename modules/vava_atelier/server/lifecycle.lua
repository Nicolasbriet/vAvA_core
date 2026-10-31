--[[
    vava_atelier/server/lifecycle.lua
    Rôle : écritures d'une fiche gardée (§ 5.6, § 7.2 de la spec T-101) : enregistrer (fiche nouvelle à l'identifiant
           tiré de son nom, brouillon d'une publiée, sauvegarde à révision), essayer, arrêter l'essai, résumer,
           publier (lot de la fiche et des brouillons de ses enfants du même tenant ; retrait en cascade), revenir à
           une version (copie ; rétablissement en cascade d'une fiche retirée), abandonner, préparer un retrait,
           reprendre le brouillon d'un autre ; et la lecture d'une fiche gardée (brouillon s'il y en a un, sinon la
           publiée). Chaque écriture : atelier gardé et disponible, verrou de la fiche, tenant, révision, jeton du
           résumé, puis la base d'abord et le module ensuite ; un refus du module rend la base comme avant et
           resynchronise l'atelier. Une ligne de journal par changement de statut, jamais par sauvegarde.
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/formvalues.lua, shared/journaltext.lua,
                  shared/slug.lua, shared/changes.lua, shared/stored.lua, shared/lifecycle.lua, bridge/server.lua,
                  server/core.lua, server/journal.lua, server/entries.lua, server/check.lua, server/store.lua,
                  server/index.lua, server/calls.lua, server/trials.lua, server/sync.lua
]]

local type, ipairs, pairs, tostring, xpcall = type, ipairs, pairs, tostring, xpcall
local format, find = string.format, string.find
local concat, pack, unpack = table.concat, table.pack, table.unpack
local traceback = debug.traceback
local time = os.time

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local Bridge = VavaAtelier.bridge
local journal, entries, check = VavaAtelier.journal, VavaAtelier.entries, VavaAtelier.check
local store, index, calls, trials, sync = VavaAtelier.store, VavaAtelier.index, VavaAtelier.calls, VavaAtelier.trials,
    VavaAtelier.sync
local text, fv, jt = VavaAtelier.text, VavaAtelier.formvalues, VavaAtelier.journaltext
local slug, changes, stored, lc = VavaAtelier.slug, VavaAtelier.changes, VavaAtelier.stored, VavaAtelier.lifecycle
local DEF, OUT = VavaAtelier.DEF, VavaAtelier.OUT
local HOOK_PUBLISHED = VavaAtelier.HOOKS.PUBLISHED
local ENTRY_PATTERN, MAX_ENTRY = VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY

local cycle = {}
VavaAtelier.cycle = cycle

-- Outils --------------------------------------------------------------------------------------------------------

--- Atelier gardé et disponible (ni en synchronisation, ni « à synchroniser »).
---@return boolean|nil ok
---@return string|nil code
local function available(editor)
    if not editor.stored then return nil, 'not_stored' end
    local state = index.state(editor.id)
    if state == 'ready' then return true end
    if state == 'failed' then sync.retry(editor.id) end
    return nil, 'syncing'
end
cycle.available = available

--- Nom du membre au journal et sur un brouillon.
local function actorOf(ctx)
    return Bridge.ActorLabel(ctx.source) or texts.console
end

--- Ligne et fiche lues : row, entry ; nil, code (db_error, stale : ligne disparue, unreadable).
local function rowEntry(editor, kind, rowId)
    local row, err = store.row(rowId)
    if err then return nil, err end
    if not row then return nil, 'stale' end
    local entry = calls.entryOf(editor, kind, row)
    if not entry then return nil, 'unreadable' end
    return row, entry
end
cycle.rowEntry = rowEntry

--- Situation de la fiche pour l'appelant.
local function situationOf(head, ctx)
    return lc.situation(head, ctx.accountId)
end

--- Étiquette d'état : { label, tone, line? }.
---@param head vAvA.AtelierHead|nil
---@param situation string
---@return table
local function stateOf(head, situation)
    local states = texts.states
    if not head or situation == 'new' then return { label = texts.stateNew, tone = 'new' } end
    local draft = head.draft
    local line = nil
    if draft and find(situation, '^other_') then
        line = text.truncate(format(states.holder, tostring(draft.holderLabel), jt.age(time(), draft.at or time())),
            OUT.summary)
    end
    if draft and draft.removal then return { label = states.removal, tone = 'removal', line = line } end
    if draft and draft.status == 'trial' then
        return { label = format(states.trial, lc.nextVersion(head.top)), tone = 'trial', line = line }
    end
    if draft then return { label = states.draft, tone = 'draft', line = line } end
    if head.published then
        if head.refused then return { label = states.refused, tone = 'refused' } end
        return { label = format(states.live, head.published.version or 1), tone = 'live' }
    end
    if head.retired then return { label = format(states.archived, head.retired.version or 1), tone = 'archived' } end
    return { label = texts.stateNew, tone = 'new' }
end
cycle.stateOf = stateOf

--- Libellé d'un bouton du pied de fiche.
local function buttonLabel(editor, button)
    local b = texts.buttons
    local id = button.id
    if id == 'trial' then return editor.texts.trial end
    if id == 'publish' then return button.removal and b.publishRemoval or editor.texts.publish end
    if id == 'discard' then return button.removal and b.discardRemoval or b.discard end
    return b[id] or id
end

--- Pied de fiche : { { id, label, primary?, link? } }.
---@param editor vAvA.AtelierEditor
---@param situation string
---@param head vAvA.AtelierHead|nil
---@param archived? { removal: boolean, unreadable: boolean }
---@return table[]
local function footerOf(editor, situation, head, archived)
    local list = lc.footer(situation, {
        stored = editor.stored, hasTrial = editor.hasTrial, versioned = head ~= nil and head.top ~= nil,
        archived = archived,
    })
    local out = {}
    for i, button in ipairs(list) do
        out[i] = { id = button.id, label = buttonLabel(editor, button), primary = button.primary, link = button.link }
    end
    return out
end
cycle.footerOf = footerOf

--- Réponse d'écriture commune : { done, rev, state, footer } de la fiche vue par l'appelant.
local function answer(ctx, head, extra)
    local situation = situationOf(head, ctx)
    local out = {
        done = true, rev = head and head.draft and head.draft.rev or 0, state = stateOf(head, situation),
        footer = footerOf(ctx.editor, situation, head),
    }
    for k, v in pairs(extra or {}) do out[k] = v end
    return out
end

--- Refus jugé par le module (ou par le contrôle de forme) : { done = false, errors }.
local function refusedBy(errors)
    return true, { done = false, errors = check.bounded(errors) }
end

--- Lance `fn` sous les verrous des fiches (toutes ou aucune) ; verrous rendus même en cas d'erreur.
local function locked(keys, fn, ...)
    local token, code = index.lock(keys)
    if not token then return false, code end
    local results = pack(xpcall(fn, traceback, ...))
    index.unlock(token)
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2, results.n)
end

--- Une fiche est-elle publiée (et vivante) ?
local function publishedIn(editorId)
    return function(kindId, id)
        local head = index.get(editorId, kindId, id)
        return head ~= nil and head.published ~= nil
    end
end

--- Membre tenant trop de brouillons ?
local function tooManyDrafts(accountId)
    return index.draftCount(accountId) >= cfg.drafts.perMember
end

--- Parent reçu d'un type enfant (clé réservée `parent` de la carte `s`), retiré des valeurs : values, parent ; nil,
--- code si le parent n'est pas un identifiant.
local function splitParent(kind, values)
    if type(values) ~= 'table' or type(values.s) ~= 'table' or values.s.parent == nil or not kind.def.parent then
        return values, nil
    end
    local parent = values.s.parent
    if type(parent) ~= 'string' or #parent > MAX_ENTRY or not find(parent, ENTRY_PATTERN) then
        return nil, 'parent_missing'
    end
    local copy = {}
    for key, value in pairs(values.s) do if key ~= 'parent' then copy[key] = value end end
    return { n = values.n, s = copy, b = values.b }, parent
end

--- Avertissements non bloquants du module sur une sauvegarde (décision 7) : textes.
local function saveWarnings(editor, kind, data, ctx, id, entry)
    local found = check.module(editor, kind, data, {
        source = ctx.source, accountId = ctx.accountId, id = id, action = 'save', parent = entry.parent,
        place = entry.place,
    })
    if not found or #found == 0 then return nil end
    local out = {}
    for i, item in ipairs(found) do out[i] = { field = item.field, text = item.text } end
    return out
end

--- Résumé court d'un brouillon (« 2 réglages changés ») vis-à-vis de la publiée.
local function draftSummary(kind, before, after)
    local _, count = changes.fields(kind.def.form, before, after, texts.changes)
    if count == 0 then return '' end
    return changes.settingsCount(count, texts.changes)
end

-- Lire une fiche gardée ---------------------------------------------------------------------------------------------

--- Fiche de la base : brouillon s'il y en a un (le sien, ou celui d'un autre en lecture), sinon la publiée.
--- { id, title, values, labels, warnings?, compare?, state, footer, rev, version, holder?, removal, stale }.
---@param ctx vAvA.AtelierContext
---@param id string
---@return boolean ok
---@return table|string
function cycle.read(ctx, id)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local draft = head.draft
    local rowId = draft and draft.row or head.published.row
    local row, entry = rowEntry(editor, kind, rowId)
    if not row then return false, entry end
    local situation = situationOf(head, ctx)
    local values = fv.toPacket(kind.def.form, entry.data)
    local warnings = #entry.reset > 0 and entry.reset or nil
    local result = {
        id = id, title = calls.titleOf(kind, entry.data, head.title), values = values,
        labels = entries.labels(editor, kind.def.form, values.s), warnings = warnings,
        compare = entries.compare(editor, kind.def.id, entry.data),
        state = stateOf(head, situation), footer = footerOf(editor, situation, head),
        rev = draft and draft.rev or 0, version = head.published and head.published.version or nil,
        removal = draft ~= nil and draft.removal == true,
        stale = draft ~= nil and head.published ~= nil and draft.base ~= head.published.version,
    }
    if draft then
        result.holder = {
            label = draft.holderLabel, mine = draft.holder ~= nil and draft.holder == ctx.accountId,
            at = jt.age(time(), draft.at or time()),
        }
    end
    return true, result
end

-- Enregistrer ---------------------------------------------------------------------------------------------------

--- Fiche nouvelle : brouillon à l'identifiant tiré de son nom.
local function saveNew(ctx, data, parent)
    local editor, kind = ctx.editor, ctx.kind
    local kindId = kind.def.id
    if index.liveCount(editor.id, kindId) >= cfg.definitions.perKind then return false, 'full' end
    if tooManyDrafts(ctx.accountId) then return false, 'full' end
    -- un enfant peut naître sans parent (la page de T-101 n'en choisit pas) : sa publication seule le refusera
    if kind.def.parent and parent and not index.alive(index.get(editor.id, kind.def.parent, parent)) then
        return false, 'parent_missing'
    end
    local title = calls.titleOf(kind, data, '')
    local id, err = slug.pick(title, kind.def.noun, function(candidate)
        return index.taken(editor.id, kindId, candidate)
    end)
    if not id then return false, err end
    return locked({ index.key(editor.id, kindId, id) }, function()
        if index.taken(editor.id, kindId, id) then return false, 'busy' end
        local dataJson, placeJson = calls.encode(data, nil)
        if not dataJson then return false, placeJson end
        local fingerprint = stored.fingerprint(data, nil, parent)
        local warnings = saveWarnings(editor, kind, data, ctx, nil, { parent = parent })
        local author = actorOf(ctx)
        local rowId, dbErr = store.insertDraft({
            editor = editor.id, kind = kindId, defId = id, removal = false, format = editor.format, title = title,
            parent = parent, data = dataJson, place = placeJson, fingerprint = fingerprint, accountId = ctx.accountId,
            author = author,
        })
        if not rowId then return false, dbErr end
        local head = index.ensure(editor.id, kindId, id)
        head.draft = { row = rowId, rev = 1, status = 'draft', removal = false, holder = ctx.accountId,
            holderLabel = author, title = title, parent = parent, summary = nil, at = time() }
        index.touch(editor.id, head)
        entries.invalidate(editor.id, kindId)
        VavaAtelier.log.debug("%s : fiche nouvelle '%s' (%s)", editor.id, id, kindId)
        journal.write(ctx.source, { editor = editor.id, kind = kindId, id = id, action = 'created', title = title })
        calls.notify(editor.id, kindId, id, 'saved', ctx.source)
        return true, answer(ctx, head, { id = id, title = title, warnings = warnings })
    end)
end

--- Fiche existante : brouillon d'une publiée, ou sauvegarde de son brouillon à sa révision.
local function saveExisting(ctx, head, rev, data, parent)
    local editor, kind = ctx.editor, ctx.kind
    local kindId = kind.def.id
    local situation = situationOf(head, ctx)
    local allowed, code = lc.allowed('save', situation, true, head.published ~= nil)
    if not allowed then return false, code end
    return locked({ index.key(editor.id, kindId, head.id) }, function()
        local draft = head.draft
        local published = nil
        if head.published then
            local _, entry = rowEntry(editor, kind, head.published.row)
            published = entry
        end
        local author = actorOf(ctx)
        local title = calls.titleOf(kind, data, head.id)
        if not draft then
            -- premier brouillon d'une publiée : lieu et parent de la version de base recopiés
            if rev ~= 0 then return false, 'stale' end
            if tooManyDrafts(ctx.accountId) then return false, 'full' end
            if not published then return false, 'unreadable' end
            local where = published.place
            local parentId = parent or published.parent
            local dataJson, placeJson = calls.encode(data, where)
            if not dataJson then return false, placeJson end
            local summary = draftSummary(kind, published.data, data)
            local warnings = saveWarnings(editor, kind, data, ctx, head.id, { parent = parentId, place = where })
            local rowId, dbErr = store.insertDraft({
                editor = editor.id, kind = kindId, defId = head.id, removal = false, format = editor.format,
                title = title, parent = parentId, data = dataJson, place = placeJson,
                fingerprint = stored.fingerprint(data, where, parentId), base = head.published.version,
                summary = summary, accountId = ctx.accountId, author = author,
            })
            if not rowId then return false, dbErr end
            head.draft = { row = rowId, rev = 1, status = 'draft', removal = false, holder = ctx.accountId,
                holderLabel = author, base = head.published.version, title = title, parent = parentId,
                summary = summary ~= '' and summary or nil, at = time() }
            index.touch(editor.id, head)
            entries.invalidate(editor.id, kindId)
            journal.write(ctx.source, { editor = editor.id, kind = kindId, id = head.id, action = 'saved',
                title = title, version = head.published.version })
            calls.notify(editor.id, kindId, head.id, 'saved', ctx.source)
            return true, answer(ctx, head, { id = head.id, title = title, warnings = warnings })
        end
        if rev ~= draft.rev then return false, 'stale' end
        local row, current = rowEntry(editor, kind, draft.row)
        if not row then return false, current end
        local where = current.place
        local parentId = parent or current.parent
        local dataJson, placeJson = calls.encode(data, where)
        if not dataJson then return false, placeJson end
        local summary = published and draftSummary(kind, published.data, data) or ''
        local warnings = saveWarnings(editor, kind, data, ctx, head.id, { parent = parentId, place = where })
        local affected, dbErr = store.updateDraft(draft.row, rev, {
            data = dataJson, place = placeJson, parent = parentId, title = title,
            fingerprint = stored.fingerprint(data, where, parentId), format = editor.format, summary = summary,
        })
        if not affected then return false, dbErr end
        if affected == 0 then return false, 'stale' end
        draft.rev, draft.title, draft.parent, draft.at = draft.rev + 1, title, parentId, time()
        draft.summary = summary ~= '' and summary or nil
        index.touch(editor.id, head)
        entries.invalidate(editor.id, kindId)
        -- en essai : l'essai est relancé avec la nouvelle version, chez l'auteur seul
        if draft.status == 'trial' then cycle.retrial(ctx, head, data, where, parentId) end
        calls.notify(editor.id, kindId, head.id, 'saved', ctx.source)
        return true, answer(ctx, head, { id = head.id, title = title, warnings = warnings })
    end)
end

--- RPC save : valeurs → data (forme, monde), puis brouillon. { done, id, rev, title, state, footer, warnings? }.
---@param ctx vAvA.AtelierContext
---@param id string  '' : fiche nouvelle
---@param rev integer
---@param values table
function cycle.save(ctx, id, rev, values)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = nil
    if id ~= '' then
        head = index.get(editor.id, kind.def.id, id)
        if not index.alive(head) then return false, 'unknown_entry' end
    end
    local cleaned, parent = splitParent(kind, values)
    if not cleaned then return false, parent end
    local data, errors, valueCode = check.values(kind, cleaned)
    if valueCode then return false, valueCode end
    if not data then return refusedBy(errors) end
    local worldErrors, worldCode = check.world(editor, kind, data)
    if not worldErrors then return false, worldCode end
    if #worldErrors > 0 then return refusedBy(worldErrors) end
    if parent and kind.def.parent and not index.alive(index.get(editor.id, kind.def.parent, parent)) then
        return false, 'parent_missing'
    end
    if not head then return saveNew(ctx, data, parent) end
    return saveExisting(ctx, head, rev, data, parent)
end

-- Essai -----------------------------------------------------------------------------------------------------------

--- Lot d'un essai : la fiche et les brouillons (hors retraits) de ses enfants du même tenant, lus et revus.
--- items = { { head, kind, entry, rowId, depth } } ; nil, code ; ou nil, nil, errors.
local function trialLot(ctx, head)
    local editor = ctx.editor
    local refs, err = lc.bundle({ kind = head.kind, id = head.id }, index.draftRefs(editor.id), editor.parents,
        ctx.accountId, cfg.bundle.maxChildren)
    if not refs then return nil, err end
    local items = { { head = head, kind = editor.kinds[head.kind], rowId = head.draft.row, depth = 1 } }
    for _, ref in ipairs(refs) do
        if not ref.removal then
            local child = index.get(editor.id, ref.kind, ref.id)
            items[#items + 1] = { head = child, kind = editor.kinds[ref.kind], rowId = child.draft.row,
                depth = ref.depth }
        end
    end
    local bundle = {}
    for _, item in ipairs(items) do
        local row, entry = rowEntry(editor, item.kind, item.rowId)
        if not row then return nil, entry end
        item.entry = entry
        bundle[#bundle + 1] = { kind = item.head.kind, id = item.head.id, data = entry.data, parent = entry.parent,
            place = entry.place, removal = false }
    end
    local errors = {}
    for _, item in ipairs(items) do
        local found, code = check.stored(editor, item.kind, item.entry.data, {
            source = ctx.source, accountId = ctx.accountId, id = item.head.id, action = 'trial',
            parent = item.entry.parent, place = item.entry.place, bundle = bundle,
        })
        if not found then return nil, code end
        for _, e in ipairs(found) do
            if item.depth == 1 then
                errors[#errors + 1] = e
            else
                errors[#errors + 1] = { text = text.truncate(format(texts.summaries.child,
                    changes.capital(item.kind.def.noun), item.head.title, e.text), OUT.errorText) }
            end
        end
    end
    if #errors > 0 then return nil, nil, errors end
    return items
end

--- Fiches passées au module pour un essai : def de la fiche et { { kind, def } } des enfants.
local function trialDefs(items)
    local children = {}
    for i = 2, #items do
        local item = items[i]
        children[#children + 1] = { kind = item.head.kind,
            def = stored.def(item.entry, item.head.id, lc.nextVersion(item.head.top)) }
    end
    return stored.def(items[1].entry, items[1].head.id, lc.nextVersion(items[1].head.top)), children
end

--- RPC trial : { done, rev, state, footer, children }.
function cycle.trial(ctx, id, rev)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    if not editor.hasTrial then return false, 'no_trial' end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('trial', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return false, refusal end
    if rev ~= head.draft.rev then return false, 'stale' end
    if trials.count(ctx.accountId) >= cfg.trial.perMember then return false, 'trial_busy' end
    return locked({ index.key(editor.id, kind.def.id, id) }, function()
        local items, lotCode, errors = trialLot(ctx, head)
        if errors then return refusedBy(errors) end
        if not items then return false, lotCode end
        local rows = {}
        for i, item in ipairs(items) do rows[i] = item.rowId end
        local set = store.setStatus(rows, 'draft', 'trial')
        if set == nil then return false, 'db_error' end
        local def, children = trialDefs(items)
        local shown, why = calls.trial(editor, kind.def.id, def, {
            source = ctx.source, accountId = ctx.accountId, children = children, reason = 'start',
        })
        if not shown then
            store.setStatus(rows, 'trial', 'draft')
            return refusedBy({ { text = why } })
        end
        local childRefs = {}
        for i = 2, #items do
            childRefs[#childRefs + 1] = { kind = items[i].head.kind, id = items[i].head.id }
            items[i].head.draft.status = 'trial'
        end
        head.draft.status = 'trial'
        local version = lc.nextVersion(head.top)
        trials.start({
            editor = editor.id, kind = kind.def.id, id = id, title = head.title, version = version, rows = rows,
            children = childRefs, source = ctx.source, accountId = ctx.accountId, label = actorOf(ctx),
        })
        index.touch(editor.id, head)
        entries.invalidate(editor.id)
        journal.write(ctx.source, { editor = editor.id, kind = kind.def.id, id = id, action = 'trial',
            title = head.title, version = version })
        calls.notify(editor.id, kind.def.id, id, 'saved', ctx.source)
        return true, answer(ctx, head, { children = #childRefs })
    end)
end

--- Essai relancé après une sauvegarde (le module montre la nouvelle version à l'auteur seul).
function cycle.retrial(ctx, head, data, where, parentId)
    local editor = ctx.editor
    local trial = trials.of(ctx.accountId)
    if not trial or trial.editor ~= editor.id or trial.id ~= head.id then return end
    trials.touch(ctx.accountId, ctx.source)
    local def = stored.def({ data = data, place = where, parent = parentId }, head.id, lc.nextVersion(head.top))
    local children = {}
    for _, ref in ipairs(trial.children) do
        local child = index.get(editor.id, ref.kind, ref.id)
        if child and child.draft then
            local _, entry = rowEntry(editor, editor.kinds[ref.kind], child.draft.row)
            if entry then
                children[#children + 1] = { kind = ref.kind,
                    def = stored.def(entry, ref.id, lc.nextVersion(child.top)) }
            end
        end
    end
    local shown, why = calls.trial(editor, head.kind, def, {
        source = ctx.source, accountId = ctx.accountId, children = children, reason = 'save',
    })
    if not shown then VavaAtelier.log.warn('%s : essai de %s non relancé : %s', editor.id, head.id, tostring(why)) end
end

--- RPC endTrial : { done, rev, state, footer }.
function cycle.endTrial(ctx, id)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('endTrial', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return false, refusal end
    local trial = trials.of(ctx.accountId)
    if not trial or trial.editor ~= editor.id or trial.id ~= id then return false, 'stale' end
    return locked({ index.key(editor.id, kind.def.id, id) }, function()
        trials.finish(ctx.accountId, 'stop', { requester = ctx.source })
        return true, answer(ctx, head)
    end)
end

-- Résumé et publication -------------------------------------------------------------------------------------------

--- Compte des enfants d'un lot par type, dans l'ordre des types : groupes pour shared/changes.lua.
local function childGroups(editor, items, removalCount)
    local byKind = {}
    for i = 2, #items do
        local item = items[i]
        local g = byKind[item.head.kind]
        if not g then
            local def = item.kind.def
            g = { noun = def.noun, nounPlural = def.nounPlural, feminine = changes.feminine(def), added = 0,
                removed = 0, changed = 0, count = 0 }
            byKind[item.head.kind] = g
        end
        g.count = g.count + 1
        if item.removal or removalCount then
            g.removed = g.removed + 1
        elseif item.added then
            g.added = g.added + 1
        else
            g.changed = g.changed + 1
        end
    end
    local out = {}
    for _, kindId in ipairs(editor.kindOrder) do
        if byKind[kindId] then out[#out + 1] = byKind[kindId] end
    end
    return out
end

--- Lignes d'avertissement d'un résumé (4 au plus).
local function pushWarning(list, value)
    if #list < DEF.previewWarnings then list[#list + 1] = text.truncate(value, OUT.summary) end
end

--- Plan d'une publication (résumé et publication le recalculent à l'identique). nil, code ; ou le plan
--- { items, removal, lines, warnings, errors?, summary, token }.
local function publishPlan(ctx, head)
    local editor = ctx.editor
    local draft = head.draft
    local removal = draft.removal == true
    local mainKind = editor.kinds[head.kind]
    local row, entry = rowEntry(editor, mainKind, draft.row)
    if not row then return nil, entry end
    local main = { head = head, kind = mainKind, rowId = draft.row, rev = draft.rev, entry = entry, removal = removal,
        depth = 1, added = head.published == nil }
    local items = { main }
    if removal then
        if not head.published then return nil, 'stale' end
        local refs, err = lc.cascade(head.kind, head.id, editor.parents, index.publishedRefs(editor.id),
            cfg.bundle.maxChildren)
        if not refs then return nil, err end
        for _, ref in ipairs(refs) do
            local child = index.get(editor.id, ref.kind, ref.id)
            local kind = editor.kinds[ref.kind]
            local own = child.draft and child.draft.removal and child.draft.holder == ctx.accountId
            local childRow, childEntry = rowEntry(editor, kind, own and child.draft.row or child.published.row)
            if not childRow then return nil, childEntry end
            items[#items + 1] = { head = child, kind = kind, rowId = own and child.draft.row or nil,
                rev = own and child.draft.rev or 0, cascade = not own and child.published.row or nil,
                entry = childEntry, removal = true, depth = ref.depth }
        end
    else
        local refs, err = lc.bundle({ kind = head.kind, id = head.id }, index.draftRefs(editor.id), editor.parents,
            ctx.accountId, cfg.bundle.maxChildren)
        if not refs then return nil, err end
        for _, ref in ipairs(refs) do
            local child = index.get(editor.id, ref.kind, ref.id)
            local kind = editor.kinds[ref.kind]
            -- un retrait d'une fiche qui n'est plus publiée n'a plus rien à retirer
            if not (ref.removal and not child.published) then
                local childRow, childEntry = rowEntry(editor, kind, child.draft.row)
                if not childRow then return nil, childEntry end
                items[#items + 1] = { head = child, kind = kind, rowId = child.draft.row, rev = child.draft.rev,
                    entry = childEntry, removal = ref.removal == true, depth = ref.depth,
                    added = child.published == nil }
            end
        end
    end
    -- versions publiées d'avant (résumés, inchangée)
    for _, item in ipairs(items) do
        if item.head.published and not item.removal then
            local pubRow, pubEntry = rowEntry(editor, item.kind, item.head.published.row)
            if not pubRow then return nil, pubEntry end
            item.before = pubEntry
        end
        item.version = lc.nextVersion(item.head.top)
    end
    if not removal and #items == 1 and main.before and main.before.fingerprint == entry.fingerprint then
        return nil, 'unchanged'
    end
    -- parents : publiés, ou dans le lot (jamais une fiche retirée par ce lot)
    local inBundle, removing = {}, {}
    for _, item in ipairs(items) do
        if item.removal then removing[item.head.kind .. '|' .. item.head.id] = true
        else inBundle[item.head.kind .. '|' .. item.head.id] = true end
    end
    local isPublished = publishedIn(editor.id)
    local function alivePublished(kindId, id)
        return isPublished(kindId, id) and not removing[kindId .. '|' .. id]
    end
    for _, item in ipairs(items) do
        if not item.removal then
            local ready, code = lc.parentReady(item.head.kind, item.entry.parent, editor.parents, alivePublished,
                inBundle)
            if not ready then return nil, code end
        end
    end
    -- validation complète : forme, monde, module (`publish`, ou `remove` pour un retrait)
    local bundle = {}
    for _, item in ipairs(items) do
        bundle[#bundle + 1] = { kind = item.head.kind, id = item.head.id, data = item.entry.data,
            parent = item.entry.parent, place = item.entry.place, removal = item.removal }
    end
    local errors = {}
    for _, item in ipairs(items) do
        local vctx = { source = ctx.source, accountId = ctx.accountId, id = item.head.id,
            action = item.removal and 'remove' or 'publish', parent = item.entry.parent, place = item.entry.place,
            bundle = bundle }
        local found, code
        if item.removal then
            found, code = check.module(editor, item.kind, item.entry.data, vctx)
        else
            found, code = check.stored(editor, item.kind, item.entry.data, vctx)
        end
        if not found then return nil, code end
        for _, e in ipairs(found) do
            if item.depth == 1 then
                errors[#errors + 1] = e
            else
                errors[#errors + 1] = { text = text.truncate(format(texts.summaries.child,
                    changes.capital(item.kind.def.noun), item.head.title, e.text), OUT.errorText) }
            end
        end
    end
    -- résumé
    local lines, warnings, summary = {}, {}, ''
    local publishedVersion = head.published and head.published.version or nil
    if removal then
        local groups = childGroups(editor, items, true)
        local counts = {}
        for i, g in ipairs(groups) do counts[i] = { count = g.count, noun = g.noun, nounPlural = g.nounPlural } end
        local line, childLine = changes.removal(mainKind.def, counts, texts.changes)
        lines[#lines + 1] = line
        if childLine ~= '' then lines[#lines + 1] = childLine end
        local _, journalLine = changes.removal(mainKind.def, counts, texts.changes, true)
        summary = journalLine
    else
        local fieldSummary = ''
        if main.before then
            fieldSummary = changes.summary(mainKind.def.form, main.before.data, entry.data, texts.changes,
                calls.diff(editor, head.kind, main.before.data, entry.data))
        end
        if fieldSummary ~= '' then
            lines[#lines + 1] = text.truncate(format(texts.changes.titled, calls.titleOf(mainKind, entry.data,
                head.title), fieldSummary), OUT.summary)
        end
        local childSummary = changes.children(childGroups(editor, items, false), texts.changes)
        if childSummary ~= '' then lines[#lines + 1] = childSummary end
        local parts = {}
        if fieldSummary ~= '' then parts[#parts + 1] = fieldSummary end
        if childSummary ~= '' then parts[#parts + 1] = childSummary end
        summary = changes.fit(concat(parts, ' ; '))
        main.summary = fieldSummary
        for i = 2, #items do
            local item = items[i]
            if item.before and not item.removal then
                item.summary = changes.summary(item.kind.def.form, item.before.data, item.entry.data, texts.changes,
                    calls.diff(editor, item.head.kind, item.before.data, item.entry.data))
            end
        end
    end
    lines[#lines + 1] = changes.versionLine('publish', texts.changes, publishedVersion, main.version)
    while #lines > DEF.previewLines do lines[#lines - 1] = nil end
    if draft.base and publishedVersion and draft.base ~= publishedVersion then
        pushWarning(warnings, texts.states.stale)
    end
    for _, item in ipairs(items) do
        if #item.entry.reset > 0 then
            local labels = {}
            for _, fieldId in ipairs(item.entry.reset) do
                local field = item.kind.fields[fieldId]
                labels[#labels + 1] = field and field.label or fieldId
            end
            pushWarning(warnings, format(texts.summaries.reset, concat(labels, ', ')))
        end
    end
    -- jeton : ce que le résumé décrit
    local tokenChildren = {}
    for i = 2, #items do
        local item = items[i]
        tokenChildren[#tokenChildren + 1] = { item.head.kind, item.head.id, item.rowId or 0, item.rev or 0,
            item.cascade or 0 }
    end
    local token = lc.token({ what = 'publish', main = { head.kind, head.id, draft.row, draft.rev },
        children = tokenChildren, published = publishedVersion or 0, top = head.top or 0 })
    return { items = items, removal = removal, lines = lines, warnings = warnings, summary = summary,
        errors = #errors > 0 and check.bounded(errors) or nil, token = token, published = publishedVersion }
end

--- Plan d'un retour à une version (et du rétablissement en cascade d'une fiche retirée). nil, code ; ou le plan.
local function restorePlan(ctx, head, target)
    local editor = ctx.editor
    local mainKind = editor.kinds[head.kind]
    local row, err = store.version(editor.id, head.kind, head.id, target)
    if err then return nil, err end
    if not row then return nil, 'unknown_version' end
    local plan, planErr = lc.restorePlan({ status = row.status, removal = index.toInt(row.removal),
        version = index.toInt(row.version) }, head.top)
    if not plan then return nil, planErr end
    local entry = calls.entryOf(editor, mainKind, row)
    if not entry then return nil, 'unreadable' end
    local isPublished = publishedIn(editor.id)
    local ready, code = lc.parentReady(head.kind, entry.parent, editor.parents, isPublished)
    if not ready then return nil, code end
    local items = { { head = head, kind = mainKind, sourceRow = index.toInt(row.id), entry = entry,
        version = plan.version, restoredFrom = plan.restoredFrom, depth = 1 } }
    -- fiche retirée : ses enfants retirés dans le même lot reviennent avec elle
    if head.retired and not head.published and head.retired.batch then
        local removals, batchErr = store.batchRemovals(editor.id, head.retired.batch)
        if not removals then return nil, batchErr end
        local list = {}
        for i, r in ipairs(removals) do
            list[i] = { kind = r.kind, id = r.def_id, batch = index.toInt(r.batch), version = index.toInt(r.version) }
        end
        for _, ref in ipairs(lc.restoreCascade(head.retired.batch, { kind = head.kind, id = head.id }, list)) do
            local child = index.get(editor.id, ref.kind, ref.id)
            local kind = editor.kinds[ref.kind]
            if kind and child and not child.published and child.top == ref.version + 1 then
                local childRow = store.version(editor.id, ref.kind, ref.id, ref.version)
                local childEntry = childRow and index.toInt(childRow.removal) ~= 1
                    and calls.entryOf(editor, kind, childRow) or nil
                if childEntry then
                    items[#items + 1] = { head = child, kind = kind, sourceRow = index.toInt(childRow.id),
                        entry = childEntry, version = lc.nextVersion(child.top), restoredFrom = ref.version,
                        depth = editor.kindDepth[ref.kind] or 2, added = true }
                end
            end
        end
    end
    local bundle = {}
    for _, item in ipairs(items) do
        bundle[#bundle + 1] = { kind = item.head.kind, id = item.head.id, data = item.entry.data,
            parent = item.entry.parent, place = item.entry.place, removal = false }
    end
    local errors = {}
    for _, item in ipairs(items) do
        local found, foundCode = check.stored(editor, item.kind, item.entry.data, {
            source = ctx.source, accountId = ctx.accountId, id = item.head.id, action = 'restore',
            parent = item.entry.parent, place = item.entry.place, bundle = bundle,
        })
        if not found then return nil, foundCode end
        for _, e in ipairs(found) do
            if item.depth == 1 then errors[#errors + 1] = e
            else
                errors[#errors + 1] = { text = text.truncate(format(texts.summaries.child,
                    changes.capital(item.kind.def.noun), item.head.title, e.text), OUT.errorText) }
            end
        end
    end
    local lines, warnings = {}, {}
    if head.published then
        local pubRow, pubEntry = rowEntry(editor, mainKind, head.published.row)
        if pubRow then
            local fieldSummary = changes.summary(mainKind.def.form, pubEntry.data, entry.data, texts.changes,
                calls.diff(editor, head.kind, pubEntry.data, entry.data))
            if fieldSummary ~= '' then
                lines[#lines + 1] = text.truncate(format(texts.changes.titled, calls.titleOf(mainKind, entry.data,
                    head.title), fieldSummary), OUT.summary)
            end
        end
    end
    local childSummary = changes.children(childGroups(editor, items, false), texts.changes)
    if childSummary ~= '' then lines[#lines + 1] = childSummary end
    lines[#lines + 1] = changes.versionLine('restore', texts.changes, target, plan.version)
    if #entry.reset > 0 then pushWarning(warnings, format(texts.summaries.reset, concat(entry.reset, ', '))) end
    local tokenChildren = {}
    for i = 2, #items do
        tokenChildren[#tokenChildren + 1] = { items[i].head.kind, items[i].head.id, items[i].version }
    end
    local token = lc.token({ what = 'restore', target = target, main = { head.kind, head.id },
        published = head.published and head.published.version or 0, top = head.top or 0, children = tokenChildren })
    return { items = items, lines = lines, warnings = warnings, token = token,
        errors = #errors > 0 and check.bounded(errors) or nil, version = plan.version, target = target,
        summary = format(texts.summaries.restored, target) }
end

--- Fiche, et contrôles communs du résumé et de la publication d'un brouillon.
local function draftHead(ctx, id, rev)
    local editor, kind = ctx.editor, ctx.kind
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return nil, 'unknown_entry' end
    local allowed, refusal = lc.allowed('publish', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return nil, refusal end
    if rev ~= head.draft.rev then return nil, 'stale' end
    return head
end

--- RPC preview : { title, lines, warnings, token, valid, errors? }. Aucune écriture.
---@param what 'publish'|'restore'
---@param ref integer  publish : la révision lue ; restore : la version visée
function cycle.preview(ctx, id, what, ref)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head, plan, err
    if what == 'publish' then
        head, err = draftHead(ctx, id, ref)
        if not head then return false, err end
        plan, err = publishPlan(ctx, head)
    else
        head = index.get(editor.id, kind.def.id, id)
        if not head then return false, 'unknown_entry' end
        if ref < 1 then return false, 'unknown_version' end
        plan, err = restorePlan(ctx, head, ref)
    end
    if not plan then return false, err end
    return true, {
        title = head.title, lines = plan.lines, warnings = plan.warnings, token = plan.token,
        valid = plan.errors == nil, errors = plan.errors,
    }
end

--- Versions publiées d'un lot : lignes remises à jour en mémoire après la transaction.
local function markPublished(editor, item, rowId, by)
    local head = item.head
    head.published = { row = rowId, version = item.version, title = calls.titleOf(item.kind, item.entry.data,
        head.id), parent = item.entry.parent, format = editor.format, fingerprint = item.entry.fingerprint,
        at = time() }
    head.top = item.version
    head.retired = nil
    head.refused = nil
    if head.draft and head.draft.row == rowId then head.draft = nil end
    head.publishedBy = by
    index.touch(editor.id, head)
end

local function markRetired(editor, item, batch)
    local head = item.head
    head.published = nil
    head.top = item.version
    head.retired = { row = item.rowId, version = item.version, title = head.title, batch = batch, at = time() }
    if head.draft and item.rowId and head.draft.row == item.rowId then head.draft = nil end
    index.touch(editor.id, head)
end

--- Appels au module d'un lot écrit en base, dans l'ordre (retraits des enfants, puis applications des parents) :
--- true, ou false et le texte du premier refus.
local function applyLot(editor, items, reason)
    for _, item in ipairs(lc.callOrder(items)) do
        local info = { reason = reason, last = item.last == true }
        local ok, why
        if item.removal then
            ok, why = calls.remove(editor, item.head.kind, item.head.id, info)
        else
            info.previous = item.previous
            ok, why = calls.apply(editor, item.head.kind, stored.def(item.entry, item.head.id, item.version), info)
        end
        if not ok then return false, why end
    end
    return true
end

--- Refus du module au cours d'un lot : base rendue comme avant, puis resynchronisation de l'atelier.
local function rollback(editor, undoPlan, why)
    local done = store.transaction(store.undoSteps(editor.id, lc.undo(undoPlan)))
    if not done then
        VavaAtelier.log.error("atelier '%s' : refus du module (%s) et base non rendue : à synchroniser", editor.id,
            tostring(why))
    else
        VavaAtelier.log.warn("atelier '%s' : refus du module (%s), base rendue, resynchronisation", editor.id,
            tostring(why))
    end
    sync.start(editor, 'refusal')
    return true, { done = false, errors = { { text = why } } }
end

--- Hooks vava_atelier:published, un par fiche du lot.
local function publishedHooks(ctx, items, action, by)
    for _, item in ipairs(items) do
        core.hooks.runAfter(HOOK_PUBLISHED, {
            editor = ctx.editor.id, kind = item.head.kind, id = item.head.id, version = item.version,
            previous = item.previous, action = item.removal and 'remove' or action,
            actor = { accountId = ctx.accountId, label = by },
        })
    end
end

--- RPC publish : { done, version, state, footer } ; refus du module : { done = false, errors }.
function cycle.publish(ctx, id, rev, token)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head, err = draftHead(ctx, id, rev)
    if not head then return false, err end
    -- verrous : la fiche et ses enfants (lot recalculé sous verrou ensuite)
    local keys = { index.key(editor.id, head.kind, id) }
    for _, ref in ipairs(index.draftRefs(editor.id)) do
        if ref.holder == ctx.accountId and editor.parents[ref.kind] then
            keys[#keys + 1] = index.key(editor.id, ref.kind, ref.id)
        end
    end
    return locked(keys, function()
        local plan, planErr = publishPlan(ctx, head)
        if not plan then return false, planErr end
        if plan.token ~= token then return false, 'stale' end
        if plan.errors then return refusedBy(plan.errors) end
        if head.draft.status == 'trial' then trials.finish(ctx.accountId, 'publish', { requester = ctx.source }) end
        local by = actorOf(ctx)
        local batch = head.draft.row
        local steps, rows, inserted = {}, {}, {}
        for i, item in ipairs(plan.items) do
            local summary = i == 1 and plan.summary or item.summary
            item.previous = item.head.published and item.head.published.version or nil
            if item.head.published then
                steps[#steps + 1] = store.archiveStep(item.head.published.row)
                rows[#rows + 1] = { id = item.head.published.row, before = 'published' }
            end
            if item.cascade then
                steps[#steps + 1] = store.cascadeStep(item.cascade, item.version, batch, ctx.accountId, by)
                inserted[#inserted + 1] = { kind = item.head.kind, id = item.head.id, version = item.version }
            elseif item.removal then
                steps[#steps + 1] = store.retireStep(item.rowId, item.version, batch, by, summary)
                rows[#rows + 1] = { id = item.rowId, before = 'draft' }
            else
                steps[#steps + 1] = store.publishStep(item.rowId, item.version, batch, by, summary)
                rows[#rows + 1] = { id = item.rowId, before = 'draft' }
            end
        end
        local written, dbErr = store.transaction(steps)
        if not written then return false, dbErr end
        for _, item in ipairs(plan.items) do
            if item.removal then markRetired(editor, item, batch) else markPublished(editor, item, item.rowId, by) end
        end
        entries.invalidate(editor.id)
        local applied, why = applyLot(editor, plan.items, 'publish')
        if not applied then return rollback(editor, { rows = rows, inserted = inserted }, why) end
        local main = plan.items[1]
        journal.write(ctx.source, { editor = editor.id, kind = head.kind, id = id,
            action = plan.removal and 'removed' or 'published', title = calls.titleOf(main.kind, main.entry.data, id),
            summary = plan.summary ~= '' and plan.summary or nil, version = main.version })
        publishedHooks(ctx, plan.items, 'publish', by)
        for _, item in ipairs(plan.items) do
            calls.notify(editor.id, item.head.kind, item.head.id, item.removal and 'removed' or 'published', ctx.source)
        end
        local situation = situationOf(head, ctx)
        return true, { done = true, version = main.version, state = stateOf(head, situation),
            footer = footerOf(editor, situation, head) }
    end)
end

--- RPC restore : { done, version, state, footer }.
function cycle.restore(ctx, id, version, token)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not head then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('restore', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return false, refusal end
    return locked({ index.key(editor.id, kind.def.id, id) }, function()
        local plan, err = restorePlan(ctx, head, version)
        if not plan then return false, err end
        if plan.token ~= token then return false, 'stale' end
        if plan.errors then return refusedBy(plan.errors) end
        local by = actorOf(ctx)
        local batch = plan.items[1].sourceRow
        local steps, rows, inserted = {}, {}, {}
        for i, item in ipairs(plan.items) do
            item.previous = item.head.published and item.head.published.version or nil
            if item.head.published then
                steps[#steps + 1] = store.archiveStep(item.head.published.row)
                rows[#rows + 1] = { id = item.head.published.row, before = 'published' }
            end
            steps[#steps + 1] = store.restoreStep(item.sourceRow, item.version, batch, ctx.accountId, by,
                i == 1 and plan.summary or format(texts.summaries.restored, item.restoredFrom))
            inserted[#inserted + 1] = { kind = item.head.kind, id = item.head.id, version = item.version }
        end
        local written, dbErr = store.transaction(steps)
        if not written then return false, dbErr end
        for _, item in ipairs(plan.items) do
            local copy = store.version(editor.id, item.head.kind, item.head.id, item.version)
            markPublished(editor, item, copy and index.toInt(copy.id) or nil, by)
        end
        entries.invalidate(editor.id)
        local applied, why = applyLot(editor, plan.items, 'restore')
        if not applied then return rollback(editor, { rows = rows, inserted = inserted }, why) end
        local main = plan.items[1]
        journal.write(ctx.source, { editor = editor.id, kind = head.kind, id = id, action = 'restored',
            title = calls.titleOf(main.kind, main.entry.data, id), summary = plan.summary, version = main.version })
        publishedHooks(ctx, plan.items, 'restore', by)
        for _, item in ipairs(plan.items) do
            calls.notify(editor.id, item.head.kind, item.head.id, 'restored', ctx.source)
        end
        local situation = situationOf(head, ctx)
        return true, { done = true, version = main.version, state = stateOf(head, situation),
            footer = footerOf(editor, situation, head) }
    end)
end

-- Abandonner, retirer, reprendre ----------------------------------------------------------------------------------

--- Abandon d'un brouillon (sous verrou) : { done, state, footer } ou { done, gone = true }.
local function discardLocked(ctx, head, rev)
    local editor = ctx.editor
    local draft = head.draft
    if rev ~= draft.rev then return false, 'stale' end
    if draft.status == 'trial' then trials.finish(ctx.accountId, 'discard', { requester = ctx.source }) end
    local affected, err = store.deleteDraft(draft.row, rev)
    if not affected then return false, err end
    if affected == 0 then return false, 'stale' end
    local title = head.title
    head.draft = nil
    index.touch(editor.id, head)
    entries.invalidate(editor.id, head.kind)
    journal.write(ctx.source, { editor = editor.id, kind = head.kind, id = head.id, action = 'discarded',
        title = title })
    calls.notify(editor.id, head.kind, head.id, 'discarded', ctx.source)
    if not head.published then return true, { done = true, gone = true } end
    return true, answer(ctx, head)
end

--- RPC discard.
function cycle.discard(ctx, id, rev)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('discard', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return false, refusal end
    return locked({ index.key(editor.id, kind.def.id, id) }, discardLocked, ctx, head, rev)
end

--- RPC retire : brouillon de retrait d'une publiée (data copiée) ; brouillon jamais publié : abandon.
function cycle.retire(ctx, id)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('retire', situationOf(head, ctx), true, head.published ~= nil)
    if allowed == 'discard' then
        return locked({ index.key(editor.id, kind.def.id, id) }, discardLocked, ctx, head, head.draft.rev)
    end
    if not allowed then return false, refusal end
    if tooManyDrafts(ctx.accountId) then return false, 'full' end
    return locked({ index.key(editor.id, kind.def.id, id) }, function()
        if head.draft then return false, 'draft_taken' end
        local row, err = store.row(head.published.row)
        if err then return false, err end
        if not row then return false, 'stale' end
        local author = actorOf(ctx)
        local rowId, dbErr = store.insertDraft({
            editor = editor.id, kind = kind.def.id, defId = id, removal = true, format = index.toInt(row.format) or 1,
            title = row.title, parent = row.parent, data = row.data, place = row.place or '',
            fingerprint = row.fingerprint, base = head.published.version, accountId = ctx.accountId, author = author,
        })
        if not rowId then return false, dbErr end
        head.draft = { row = rowId, rev = 1, status = 'draft', removal = true, holder = ctx.accountId,
            holderLabel = author, base = head.published.version, title = row.title, parent = row.parent, at = time() }
        index.touch(editor.id, head)
        entries.invalidate(editor.id, kind.def.id)
        journal.write(ctx.source, { editor = editor.id, kind = kind.def.id, id = id, action = 'saved',
            title = head.title, summary = texts.summaries.removalPrepared, version = head.published.version })
        calls.notify(editor.id, kind.def.id, id, 'saved', ctx.source)
        return true, answer(ctx, head)
    end)
end

--- RPC take : reprise du brouillon d'un autre membre (son essai prend fin, il est prévenu).
function cycle.take(ctx, id, rev)
    local editor, kind = ctx.editor, ctx.kind
    local ok, code = available(editor)
    if not ok then return false, code end
    local head = index.get(editor.id, kind.def.id, id)
    if not index.alive(head) then return false, 'unknown_entry' end
    local allowed, refusal = lc.allowed('take', situationOf(head, ctx), true, head.published ~= nil)
    if not allowed then return false, refusal end
    if rev ~= head.draft.rev then return false, 'stale' end
    if tooManyDrafts(ctx.accountId) then return false, 'full' end
    return locked({ index.key(editor.id, kind.def.id, id) }, function()
        local draft = head.draft
        if not draft or draft.rev ~= rev then return false, 'stale' end
        local author = actorOf(ctx)
        local previous, previousHolder = draft.holderLabel, draft.holder
        if draft.status == 'trial' and previousHolder then
            trials.finish(previousHolder, 'taken', { requester = ctx.source, by = author })
        end
        local affected, err = store.takeDraft(draft.row, draft.rev, ctx.accountId, author)
        if not affected then return false, err end
        if affected == 0 then return false, 'stale' end
        draft.holder, draft.holderLabel, draft.rev, draft.status, draft.at = ctx.accountId, author, draft.rev + 1,
            'draft', time()
        index.touch(editor.id, head)
        entries.invalidate(editor.id, kind.def.id)
        journal.write(ctx.source, { editor = editor.id, kind = kind.def.id, id = id, action = 'taken',
            title = head.title, summary = text.truncate(format(texts.summaries.takenFrom, tostring(previous)),
                OUT.summary) })
        calls.notify(editor.id, kind.def.id, id, 'taken', ctx.source)
        return true, answer(ctx, head)
    end)
end

