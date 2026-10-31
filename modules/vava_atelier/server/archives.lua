--[[
    vava_atelier/server/archives.lua
    Rôle : commande /atelier_archives (§ 5.9, § 10.4 de la spec T-101), membres du Conseil et console, réponse dans le
           chat du seul membre ou dans la console, 2 s entre deux commandes d'un membre :
             - etat [atelier]            par atelier visible : publiées, brouillons, essais, retirées, « à
                                         synchroniser », refusées en jeu ;
             - original <atelier>        (Souverain) résumé du retour à l'original de tout l'atelier, puis `confirmer` ;
             - original_fiche <atelier> <type> <fiche>   (droit de l'atelier) la même chose pour une fiche ;
             - exporter <atelier|tout>   (Souverain) seules les versions publiées, écrites dans `archives.folder` ;
             - importer <fichier>        (Souverain) fichier lu, contrôlé, résumé par atelier, puis `confirmer` ;
             - confirmer                 exécute l'opération en attente (moins de `archives.confirmMs`, droit relu, et
                                         rien n'a changé entre-temps : empreinte des têtes de l'atelier).
           Aucun octet ne part vers les joueurs, aucun fichier hors du dossier des archives (nom contrôlé). Un retour
           à l'original ou un import publie de nouvelles versions (tout ou rien par atelier ; rien n'est jamais retiré,
           les brouillons sont gardés), puis le module les applique et l'atelier est resynchronisé.
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/place.lua, shared/stored.lua,
                  shared/exchange.lua, shared/lifecycle.lua, bridge/server.lua, server/core.lua, server/editors.lua,
                  server/journal.lua, server/check.lua, server/store.lua, server/index.lua, server/calls.lua,
                  server/sync.lua
]]

local type, ipairs, pairs, tostring, select = type, ipairs, pairs, tostring, select
local format = string.format
local sort = table.sort
local CreateThread, GetGameTimer, RegisterCommand = CreateThread, GetGameTimer, RegisterCommand
local date = os.date

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local T = texts.archives
local Bridge = VavaAtelier.bridge
local editors, journal, check = VavaAtelier.editors, VavaAtelier.journal, VavaAtelier.check
local store, index, calls, sync = VavaAtelier.store, VavaAtelier.index, VavaAtelier.calls, VavaAtelier.sync
local text, place, stored, exchange, lc = VavaAtelier.text, VavaAtelier.place, VavaAtelier.stored,
    VavaAtelier.exchange, VavaAtelier.lifecycle
local HOOK_PUBLISHED = VavaAtelier.HOOKS.PUBLISHED
local CONSOLE = 0
local STAFF = cfg.rights.allowed[#cfg.rights.allowed]

local archives = {}
VavaAtelier.archives = archives

-- opération résumée en attente, par joueur (0 : console) ; dernière commande d'un membre
local pending, lastUse = {}, {}

local function say(source, line, ...)
    if select('#', ...) > 0 then line = format(line, ...) end
    Bridge.Say(source, line)
end

--- Droit relu (la console a tous les droits).
local function can(source, right)
    return source == CONSOLE or Bridge.Can(source, right)
end

--- Compte et nom d'un membre (journal) ; console : nil, « Console ».
local function actorOf(source)
    if source == CONSOLE then return nil, texts.console end
    return Bridge.AccountId(source), Bridge.ActorLabel(source) or texts.console
end

--- Atelier gardé, ou nil (et la réponse est donnée).
local function storedEditor(source, editorId)
    local editor = type(editorId) == 'string' and editors.get(editorId) or nil
    if not editor or not editor.stored then
        say(source, T.unknownEditor, tostring(editorId))
        return nil
    end
    return editor
end

-- État -------------------------------------------------------------------------------------------------------------

local function stateLine(editor)
    local published, drafts, running, retired, refused = 0, 0, 0, 0, 0
    for _, kind in pairs(index.kinds(editor.id)) do
        for _, head in pairs(kind.byId) do
            if head.published then published = published + 1 end
            if head.draft then
                drafts = drafts + 1
                if head.draft.status == 'trial' then running = running + 1 end
            end
            if head.retired and not index.alive(head) then retired = retired + 1 end
            if head.refused then refused = refused + 1 end
        end
    end
    local tail = ''
    local state = index.state(editor.id)
    if state == 'syncing' then tail = T.stateSyncing elseif state == 'failed' then tail = T.stateFailed end
    if refused > 0 then tail = tail .. format(T.stateRefused, refused) end
    return format(T.state, editor.label, published, drafts, running, retired, tail)
end

local function stateCommand(source, editorId)
    local count = 0
    for _, editor in ipairs(editors.list()) do
        if editor.stored and (editorId == nil or editor.id == editorId) and can(source, editor.right) then
            say(source, stateLine(editor))
            count = count + 1
        end
    end
    if count == 0 then say(source, editorId and format(T.unknownEditor, editorId) or T.nothing) end
end

-- Plans (original, import) --------------------------------------------------------------------------------------

--- État en base des fiches d'un atelier pour un plan : 'type|id' → { fingerprint?, retired? }.
local function currentOf(editor)
    local current = {}
    for kindId, kind in pairs(index.kinds(editor.id)) do
        for id, head in pairs(kind.byId) do
            local entry = nil
            if head.published then
                local row = store.row(head.published.row)
                entry = row and calls.entryOf(editor, editor.kinds[kindId], row) or nil
            end
            current[kindId .. '|' .. id] = { fingerprint = entry and entry.fingerprint or (head.published and '?'),
                retired = head.retired ~= nil and not head.published }
        end
    end
    return current
end

--- Fiches à publier d'un atelier, contrôlées comme une saisie (forme, lieu, monde, module `import`), tout ou rien.
--- items : { { kind, id, entry } } avec `entry.fingerprint` ; rend le plan, ou nil et « fiche : raison ».
local function planFor(editor, source, items)
    local accountId = source ~= CONSOLE and Bridge.AccountId(source) or nil
    local current = currentOf(editor)
    local refs = {}
    for i, item in ipairs(items) do
        refs[i] = { kind = item.kind, id = item.id, fingerprint = item.entry.fingerprint }
    end
    local plan = exchange.plan(refs, current)
    local inPlan = {}
    for _, item in ipairs(items) do inPlan[item.kind .. '|' .. item.id] = true end
    local isPublished = function(kindId, id)
        local head = index.get(editor.id, kindId, id)
        return head ~= nil and head.published ~= nil
    end
    local bundle = {}
    for _, item in ipairs(items) do
        bundle[#bundle + 1] = { kind = item.kind, id = item.id, data = item.entry.data, parent = item.entry.parent,
            place = item.entry.place, removal = false }
    end
    local todo = {}
    for i, item in ipairs(items) do
        local action = plan.items[i].action
        if action ~= 'unchanged' then
            local kind = editor.kinds[item.kind]
            local ready = lc.parentReady(item.kind, item.entry.parent, editor.parents, isPublished, inPlan)
            if not ready then
                return nil, format(T.entryPlan, kind.def.noun, item.id, texts.refused.parent_missing)
            end
            local found, code = check.stored(editor, kind, item.entry.data, {
                source = source ~= CONSOLE and source or nil, accountId = accountId, id = item.id, action = 'import',
                parent = item.entry.parent, place = item.entry.place, bundle = bundle,
            })
            if not found then return nil, texts.refused[code] or tostring(code) end
            if #found > 0 then return nil, format(T.entryPlan, kind.def.noun, item.id, found[1].text) end
            todo[#todo + 1] = { kind = item.kind, id = item.id, entry = item.entry, action = action }
        end
    end
    plan.todo = todo
    return plan
end

--- Fiches de l'original (module) d'un atelier, ou d'une seule fiche : { { kind, id, entry } }.
local function originalItems(editor, onlyKind, onlyId)
    local out = {}
    for _, kindId in ipairs(editor.kindOrder) do
        if not onlyKind or onlyKind == kindId then
            local kind = editor.kinds[kindId]
            for _, id in ipairs(calls.moduleIndex(editor, kindId, true) or {}) do
                if not onlyId or onlyId == id then
                    local entry = calls.moduleRead(editor, kind, id, true)
                    if entry then out[#out + 1] = { kind = kindId, id = id, entry = entry } end
                end
            end
        end
    end
    return out
end

--- Fiches d'un atelier lues d'un fichier d'archives, normalisées : liste, ou nil et « chemin : raison ».
local function fileItems(editor, block, parsed)
    local fileFormat = type(block) == 'table' and type(block.format) == 'number' and block.format or 1
    local out = {}
    for _, raw in ipairs(parsed.entries) do
        local kind = editor.kinds[raw.kind]
        local data = raw.data
        if fileFormat < editor.format and editor.fns.upgrade then
            local called, upgraded = Bridge.CallEditor(editor.id, 'upgrade', editor.fns.upgrade, raw.kind, data,
                fileFormat)
            if not called or type(upgraded) ~= 'table' then return nil, raw.path .. ' : montée de format refusée' end
            data = upgraded
        end
        local normalized, reset = stored.normalize(kind.def.form, data)
        -- une valeur présente mais refusée par le formulaire (hors bornes, choix inconnu) : refus, avec son chemin ;
        -- un champ absent (fichier d'un format plus ancien) prend sa valeur de départ
        for _, fieldId in ipairs(reset) do
            if data[fieldId] ~= nil then
                local field = kind.fields[fieldId]
                return nil, format('%s.data.%s : %s', raw.path, fieldId, T.badValue:format(field and field.label
                    or fieldId))
            end
        end
        local where, err = place.check(kind.def.placement, raw.place, cfg.place)
        if kind.def.placement and raw.place ~= nil and not where then
            return nil, raw.path .. '.place : ' .. tostring(err)
        end
        local parent = kind.def.parent and stored.parentOf(raw.parent) or nil
        out[#out + 1] = { kind = raw.kind, id = raw.id, entry = {
            data = normalized, place = where, parent = parent, reset = {},
            fingerprint = stored.fingerprint(normalized, where, parent),
        } }
    end
    return out
end

-- Exécution -------------------------------------------------------------------------------------------------------

--- Publie les fiches d'un plan confirmé en nouvelles versions (`origin` seed ou import), applique au module, journal,
--- hooks, puis resynchronise l'atelier. Rend le nombre publié, ou nil et un code.
local function publishPlan(source, editor, todo, origin, reason)
    local keys = {}
    for i, item in ipairs(todo) do keys[i] = index.key(editor.id, item.kind, item.id) end
    local token, busy = index.lock(keys)
    if not token then return nil, busy end
    index.setState(editor.id, 'syncing')
    local accountId, author = actorOf(source)
    local steps, items = {}, {}
    for _, item in ipairs(todo) do
        local head = index.get(editor.id, item.kind, item.id)
        local kind = editor.kinds[item.kind]
        local version = lc.nextVersion(head and head.top or nil)
        if head and head.published then steps[#steps + 1] = store.archiveStep(head.published.row) end
        local dataJson, placeJson = calls.encode(item.entry.data, item.entry.place)
        if not dataJson then
            index.unlock(token)
            index.setState(editor.id, 'ready')
            return nil, placeJson
        end
        steps[#steps + 1] = store.insertPublishedStep({
            editor = editor.id, kind = item.kind, defId = item.id, version = version, origin = origin,
            format = editor.format, title = calls.titleOf(kind, item.entry.data, item.id), parent = item.entry.parent,
            data = dataJson, place = placeJson, fingerprint = item.entry.fingerprint, accountId = accountId,
            author = author,
        })
        items[#items + 1] = { kind = item.kind, id = item.id, entry = item.entry, version = version,
            depth = editor.kindDepth[item.kind] or 1, previous = head and head.published and head.published.version,
            title = calls.titleOf(kind, item.entry.data, item.id) }
    end
    local written = store.transaction(steps)
    if not written then
        index.unlock(token)
        index.setState(editor.id, 'ready')
        return nil, 'db_error'
    end
    for _, item in ipairs(lc.callOrder(items)) do
        local ok, why = calls.apply(editor, item.kind, stored.def(item.entry, item.id, item.version),
            { reason = reason, last = item.last == true, previous = item.previous })
        if not ok then
            VavaAtelier.log.error("%s, %s '%s' : refusée en jeu (%s) ; resynchronisation", editor.id, item.kind,
                item.id, tostring(why))
        end
        core.hooks.runAfter(HOOK_PUBLISHED, {
            editor = editor.id, kind = item.kind, id = item.id, version = item.version, previous = item.previous,
            action = reason, actor = { accountId = accountId, label = author },
        })
    end
    index.unlock(token)
    -- têtes reconstruites depuis la base, module rapproché (les fiches refusées sont signalées)
    sync.start(editor, reason)
    return #items, items
end

--- Exécute l'opération en attente d'un membre.
local function confirm(source)
    local op = pending[source]
    pending[source] = nil
    if not op then return say(source, T.noPending) end
    if GetGameTimer() - op.at > cfg.archives.confirmMs then return say(source, T.expired) end
    for _, part in ipairs(op.parts) do
        local editor = editors.get(part.editor)
        if not editor or not can(source, op.right or editor.right) then return say(source, T.deniedEditor) end
        if index.state(editor.id) ~= 'ready' then return say(source, T.busy, editor.label) end
        if index.digest(editor.id) ~= part.digest then return say(source, T.changed) end
    end
    for _, part in ipairs(op.parts) do
        local editor = editors.get(part.editor)
        local count, items = publishPlan(source, editor, part.todo, op.origin, op.reason)
        if not count then
            say(source, T.failed, editor.label, texts.refused[items] or tostring(items))
        else
            say(source, T.done, editor.label, count)
            if op.kind == 'original_fiche' then
                local item = items[1]
                if item then
                    journal.write(source, { editor = editor.id, kind = item.kind, id = item.id, action = 'imported',
                        title = item.title, version = item.version })
                end
            elseif op.kind == 'original' then
                journal.write(source, { editor = editor.id, kind = editor.firstKind, action = 'imported',
                    title = editor.label, summary = format(texts.summaries.reimported, part.plan.changed,
                        part.plan.revived, part.plan.new) })
            else
                journal.write(source, { editor = editor.id, kind = editor.firstKind, action = 'received',
                    title = editor.label, summary = text.truncate(format(texts.summaries.received, count,
                        part.plan.unchanged), VavaAtelier.OUT.summary) })
            end
        end
    end
end

--- Garde une opération résumée et dit comment la confirmer.
local function hold(source, op)
    op.at = GetGameTimer()
    pending[source] = op
    say(source, T.confirmHint, cfg.archives.command, cfg.archives.confirmMs // 1000)
end

-- Actions ---------------------------------------------------------------------------------------------------------

local function originalCommand(source, editorId, kindId, id)
    local editor = storedEditor(source, editorId)
    if not editor then return end
    local single = kindId ~= nil
    if single then
        if not can(source, editor.right) then return say(source, T.deniedEditor) end
        if not editor.kinds[kindId] then return say(source, T.unknownKind, tostring(kindId)) end
    elseif not can(source, STAFF) then
        return say(source, T.denied)
    end
    if index.state(editor.id) ~= 'ready' then return say(source, T.busy, editor.label) end
    local items = originalItems(editor, kindId, id)
    if single and #items == 0 then return say(source, T.unknownEntry, tostring(id)) end
    local plan, err = planFor(editor, source, items)
    if not plan then return say(source, T.refusedPlan, editor.label, err) end
    if #plan.todo == 0 then return say(source, T.originalSame) end
    if single then
        local item = plan.todo[1]
        local head = index.get(editor.id, item.kind, item.id)
        local summary = ''
        if head and head.published then
            local row = store.row(head.published.row)
            local before = row and calls.entryOf(editor, editor.kinds[item.kind], row) or nil
            if before then
                summary = VavaAtelier.changes.summary(editor.kinds[item.kind].def.form, before.data, item.entry.data,
                    texts.changes, calls.diff(editor, item.kind, before.data, item.entry.data))
            end
        end
        say(source, T.entryPlan, editor.kinds[item.kind].def.noun, item.id, summary ~= '' and summary or item.action)
    else
        say(source, T.originalPlan, editor.label, plan.changed, plan.revived, plan.new, plan.unchanged)
    end
    hold(source, { kind = single and 'original_fiche' or 'original', origin = 'seed', reason = 'reimport',
        right = not single and STAFF or nil,
        parts = { { editor = editor.id, todo = plan.todo, plan = plan, digest = index.digest(editor.id) } } })
end

local function exportCommand(source, target)
    if not can(source, STAFF) then return say(source, T.denied) end
    local list, count = {}, 0
    local chosen = {}
    for _, editor in ipairs(editors.list()) do
        if editor.stored and (target == 'tout' or editor.id == target) then chosen[#chosen + 1] = editor end
    end
    if #chosen == 0 then return say(source, T.unknownEditor, tostring(target)) end
    local perEditor = {}
    for _, editor in ipairs(chosen) do
        local kinds, n = {}, 0
        for _, kindId in ipairs(editor.kindOrder) do
            local rows = {}
            local heads = {}
            for _, head in pairs((index.kinds(editor.id)[kindId] or { byId = {} }).byId) do
                if head.published then heads[#heads + 1] = head end
            end
            sort(heads, function(a, b) return a.id < b.id end)
            for _, head in ipairs(heads) do
                local row = store.row(head.published.row)
                local entry = row and calls.entryOf(editor, editor.kinds[kindId], row)
                if entry then
                    rows[#rows + 1] = { id = head.id, version = head.published.version, parent = entry.parent,
                        place = entry.place, data = entry.data }
                end
            end
            kinds[kindId] = rows
            n = n + #rows
        end
        list[#list + 1] = { editor = editor.id, format = editor.format, kinds = kinds }
        perEditor[#perEditor + 1] = { editor = editor, count = n }
        count = count + n
    end
    local doc = exchange.build(list, date('!%Y-%m-%dT%H:%M:%SZ'))
    local name = exchange.exportName(target ~= 'tout' and target or nil, date('%Y%m%d_%H%M%S'))
    local content = Bridge.JsonEncode(doc)
    if not content then return say(source, T.exportFailed, 'JSON') end
    local ok, err = Bridge.SaveArchive(name, content)
    if not ok then return say(source, T.exportFailed, tostring(err)) end
    for _, part in ipairs(perEditor) do
        journal.write(source, { editor = part.editor.id, kind = part.editor.firstKind, action = 'exported',
            title = part.editor.label, summary = format(texts.summaries.exported, name, part.count) })
    end
    say(source, T.exported, name, count)
end

local function importCommand(source, name)
    if not can(source, STAFF) then return say(source, T.denied) end
    if not exchange.validName(name) then return say(source, T.badName) end
    local content, err = Bridge.LoadArchive(name)
    if not content then return say(source, T.unreadableFile, tostring(err)) end
    local doc = Bridge.JsonDecode(content)
    local known = {}
    for _, editor in ipairs(editors.list()) do
        local kinds = {}
        for kindId in pairs(editor.kinds) do kinds[kindId] = true end
        known[editor.id] = { stored = editor.stored, format = editor.format, kinds = kinds }
    end
    local parsed = exchange.parse(doc, known)
    if parsed.error then return say(source, T.unreadableFile, parsed.error) end
    local parts = {}
    for _, result in ipairs(parsed.editors) do
        local editor = editors.get(result.id)
        if result.error then
            say(source, T.refusedPlan, editor and editor.label or result.id, result.error)
        elseif index.state(editor.id) ~= 'ready' then
            say(source, T.busy, editor.label)
        else
            local items, itemsErr = fileItems(editor, doc.editors[result.id], result)
            local plan, planErr
            if items then plan, planErr = planFor(editor, source, items) end
            if not plan then
                say(source, T.refusedPlan, editor.label, tostring(itemsErr or planErr))
            else
                say(source, T.importPlan, editor.label, #plan.todo, plan.unchanged)
                if #plan.todo > 0 then
                    parts[#parts + 1] = { editor = editor.id, todo = plan.todo, plan = plan,
                        digest = index.digest(editor.id) }
                end
            end
        end
    end
    if #parts == 0 then return end
    hold(source, { kind = 'import', origin = 'import', reason = 'import', right = STAFF, parts = parts })
end

--- Commande /atelier_archives.
local function handler(source, args)
    if source ~= CONSOLE then
        if not Bridge.AdminReady() then return say(source, T.notReady) end
        if not Bridge.Can(source, cfg.rights.open) then return say(source, texts.refused.not_allowed) end
        local now = GetGameTimer()
        if lastUse[source] and now - lastUse[source] < cfg.archives.cooldownMs then return say(source, T.cooldown) end
        lastUse[source] = now
    end
    local action = args[1]
    if action == 'etat' then
        stateCommand(source, args[2])
    elseif action == 'original' and args[2] then
        originalCommand(source, args[2])
    elseif action == 'original_fiche' and args[2] and args[3] and args[4] then
        originalCommand(source, args[2], args[3], args[4])
    elseif action == 'exporter' and args[2] then
        exportCommand(source, args[2])
    elseif action == 'importer' and args[2] then
        importCommand(source, args[2])
    elseif action == 'confirmer' then
        confirm(source)
    else
        say(source, T.usage, cfg.archives.command)
    end
end

--- Arguments bornés (texte de joueur) : au plus 4, 64 octets chacun, UTF-8 sans contrôle ; sinon rien.
---@param args any
---@return string[]|nil
local function cleanArgs(args)
    if type(args) ~= 'table' or #args > 4 then return nil end
    local out = {}
    for i = 1, #args do
        local value = args[i]
        if type(value) ~= 'string' or #value > 64 or not text.isUtf8(value) or text.hasControl(value) then
            return nil
        end
        out[i] = value
    end
    return out
end

--- Enregistre la commande (setup).
function archives.register()
    RegisterCommand(cfg.archives.command, function(source, args)
        local clean = cleanArgs(args)
        CreateThread(function()
            if not clean then return say(source, T.usage, cfg.archives.command) end
            handler(source, clean)
        end)
    end, false)
end

--- Joueur parti : opération en attente et délai oubliés.
---@param source integer
function archives.forget(source)
    pending[source], lastUse[source] = nil, nil
end

--- Ateliers gardés (Codex : liste `ateliers`) : { { value, label } }.
---@return { value: string, label: string }[]
function archives.codexList()
    local out = {}
    for _, editor in ipairs(editors.list()) do
        if editor.stored then out[#out + 1] = { value = editor.id, label = editor.label } end
    end
    return out
end

