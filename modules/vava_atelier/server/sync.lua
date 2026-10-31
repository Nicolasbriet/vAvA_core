--[[
    vava_atelier/server/sync.lua
    Rôle : la base fait foi (§ 5.8, § 7.5 de la spec T-101).
             - Réparation au démarrage : essais rendus aux brouillons, doublons (deux publiées : la plus haute reste ;
               deux brouillons : le plus récent reste), chacun avec une ligne en console.
             - Synchronisation d'un atelier gardé, dans son propre fil, à chaque déclaration de l'éditeur, après un
               refus d'`apply`, un retour à l'original ou un import : graine (chaque identifiant rendu par `index` du
               module jamais vu en base devient la version 1 publiée, `origin = seed`, auteur « Console » ; jamais une
               fiche déjà connue, même retirée), rapprochement (empreintes : `apply` de ce qui diffère chez le module,
               `remove` de ce qu'il a sans version publiée ; retraits des enfants d'abord, applications des parents
               d'abord), têtes en mémoire, listes oubliées. Les empreintes gardées en base sont comparées d'abord :
               seules les publiées qui diffèrent sont relues (en lot) et décodées ; après un refus ou un import, les
               seules fiches du lot sont rapprochées (`only`). Pauses du fil au temps (`sync.sliceMs`). Pendant ce
               temps l'atelier rend `syncing`. Base muette :
               `sync.retries` essais espacés de `sync.retryMs`, puis « à synchroniser » (le module tourne sur sa
               config). Un `apply` refusé : la fiche reste publiée en base, « refusée en jeu », retentée à la prochaine.
    Dépendances : shared/constants.lua, config.lua, shared/lifecycle.lua, shared/stored.lua, bridge/server.lua,
                  server/core.lua, server/editors.lua, server/journal.lua, server/entries.lua, server/store.lua,
                  server/index.lua, server/calls.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local sort = table.sort
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local editors, journal, entries = VavaAtelier.editors, VavaAtelier.journal, VavaAtelier.entries
local store, index, calls = VavaAtelier.store, VavaAtelier.index, VavaAtelier.calls
local lc = VavaAtelier.lifecycle
local stored = VavaAtelier.stored

local sync = {}
VavaAtelier.sync = sync

-- génération de synchronisation par atelier : une synchronisation plus récente, ou l'atelier retiré, arrête l'ancienne
local generations = {}
-- paquets d'insertions de la graine
local SEED_CHUNK = 100
-- attente d'une écriture en cours avant de relire les têtes
local LOCK_POLL_MS = 50
-- portée de la synchronisation en cours (true : tout l'atelier) ; ateliers entièrement rapprochés depuis leur déclaration
local active, synced = {}, {}

--- Une synchronisation est-elle toujours d'actualité ?
local function current(editor, generation)
    return editors.get(editor.id) == editor and generations[editor.id] == generation
end

--- Pause du fil au temps : `Wait(0)` dès que `sync.sliceMs` se sont écoulées depuis la dernière pause (une fiche de
--- 16 Ko pèse bien plus qu'une de 1 Ko : compter les fiches laisserait des tranches de 30 à 100 ms). Serveur : cède la
--- main au reste du tour. Aussi pour les commandes d'archives.
---@return fun()
local function yielder()
    local since = GetGameTimer()
    return function()
        if GetGameTimer() - since >= cfg.sync.sliceMs then
            Wait(0) -- audit: ok (fil serveur, pas une boucle d'affichage)
            since = GetGameTimer()
        end
    end
end
sync.yielder = yielder

--- Graine : identifiants du module jamais vus en base, importés en version 1 publiée. Rend le nombre importé, ou nil.
---@param editor vAvA.AtelierEditor
---@param known table<string, boolean>
---@param step fun()
---@return integer|nil
local function seed(editor, known, step)
    local steps = {}
    for _, kindId in ipairs(editor.kindOrder) do
        local kind = editor.kinds[kindId]
        local ids = calls.moduleIndex(editor, kindId)
        local set = {}
        for _, id in ipairs(ids or {}) do
            set[id] = true
            if not known[kindId .. '|' .. id] then
                step()
                local entry = calls.moduleRead(editor, kind, id)
                if entry then
                    if #entry.reset > 0 then
                        VavaAtelier.log.warn("%s, %s '%s' : valeur de départ pour %s", editor.id, kindId, id,
                            table.concat(entry.reset, ', '))
                    end
                    local dataJson, placeJson = calls.encode(entry.data, entry.place)
                    if dataJson then
                        steps[#steps + 1] = store.insertPublishedStep({
                            editor = editor.id, kind = kindId, defId = id, version = 1, origin = 'seed',
                            format = editor.format, title = calls.titleOf(kind, entry.data, id), parent = entry.parent,
                            data = dataJson, place = placeJson, fingerprint = entry.fingerprint, author = texts.console,
                        })
                    else
                        VavaAtelier.log.error("%s, %s '%s' : fiche trop lourde, non importée", editor.id, kindId, id)
                    end
                end
            end
        end
        index.setModuleIds(editor.id, kindId, set)
    end
    for first = 1, #steps, SEED_CHUNK do
        local chunk = {}
        for i = first, math.min(#steps, first + SEED_CHUNK - 1) do chunk[#chunk + 1] = steps[i] end
        if not store.transaction(chunk) then return nil end
    end
    return #steps
end

--- Rapprochement : le module reçoit l'état de la base. L'empreinte du module est d'abord comparée à celle gardée dans
--- la ligne (sans data) ; seules les publiées qui diffèrent (ou d'un autre format) sont relues, en lot, et décodées.
--- `scope` : `true` (tout l'atelier) ou les seules fiches { ['type|id'] = true } d'un lot refusé ou importé. Rend les
--- nombres d'applications et de retraits, ou nil si la base ne répond pas.
---@param editor vAvA.AtelierEditor
---@param rows table[]  lignes vivantes (sans data)
---@param step fun()
---@param generation integer
---@param scope true|table<string, boolean>
---@return integer|nil applied
---@return integer removed
local function reconcile(editor, rows, step, generation, scope)
    local published = {}
    for _, row in ipairs(rows) do
        if row.status == 'published' then published[row.kind .. '|' .. row.def_id] = row end
    end
    local function inScope(key) return scope == true or scope[key] == true end
    local depth = editor.kindDepth
    local items, toRead = {}, {}
    -- applications : publiées en base dont le module a une autre empreinte (ou rien)
    for key, row in pairs(published) do
        local kind = editor.kinds[row.kind]
        if kind and inScope(key) then
            step()
            local mine = calls.moduleRead(editor, kind, row.def_id)
            if not mine or (index.toInt(row.format) or 1) ~= editor.format or mine.fingerprint ~= row.fingerprint then
                toRead[#toRead + 1] = { key = key, row = row, kind = kind, mine = mine }
            end
        end
    end
    if #toRead > 0 then
        local ids = {}
        for i, wanted in ipairs(toRead) do ids[i] = index.toInt(wanted.row.id) end
        local full = store.rows(ids)
        if not full then return nil, 0 end
        for _, wanted in ipairs(toRead) do
            step()
            local row = wanted.row
            local fullRow = full[index.toInt(row.id)]
            local entry = fullRow and calls.entryOf(editor, wanted.kind, fullRow) or nil
            if entry then
                -- même data revue par le formulaire en vigueur : rien à appliquer
                if not wanted.mine or wanted.mine.fingerprint ~= entry.fingerprint then
                    items[#items + 1] = { kind = row.kind, id = row.def_id, depth = depth[row.kind] or 1,
                        entry = entry, version = index.toInt(row.version), key = wanted.key }
                end
            else
                local head = index.get(editor.id, row.kind, row.def_id)
                if head then head.refused = true end
            end
        end
    end
    -- retraits : identifiants du module sans version publiée en base
    local entry = index.all()[editor.id]
    for kindId, ids in pairs(entry and entry.moduleIds or {}) do
        for id in pairs(ids) do
            local key = kindId .. '|' .. id
            if not published[key] and inScope(key) then
                items[#items + 1] = { kind = kindId, id = id, depth = depth[kindId] or 1, removal = true }
            end
        end
    end
    local applied, removed = 0, 0
    for _, item in ipairs(lc.callOrder(items)) do
        if not current(editor, generation) then break end
        step()
        local info = { reason = 'sync', last = item.last == true }
        if item.removal then
            local ok, why = calls.remove(editor, item.kind, item.id, info)
            if ok then
                removed = removed + 1
            else
                VavaAtelier.log.error("%s, %s '%s' : retrait refusé en jeu : %s", editor.id, item.kind, item.id, why)
            end
        else
            local def = stored.def(item.entry, item.id, item.version)
            local ok, why = calls.apply(editor, item.kind, def, info)
            local head = index.get(editor.id, item.kind, item.id)
            if ok then
                applied = applied + 1
                if head then head.refused = nil end
            else
                if head then head.refused = true end
                VavaAtelier.log.error("%s, %s '%s' : version publiée refusée en jeu : %s", editor.id, item.kind,
                    item.id, why)
            end
        end
    end
    return applied, removed
end

--- Une passe de synchronisation. Rend true, ou false (base muette ; atelier retiré : true, rien à faire).
---@param editor vAvA.AtelierEditor
---@param generation integer
---@param scope true|table<string, boolean>
---@return boolean
local function once(editor, generation, scope)
    local step = yielder()
    -- une écriture en cours (transaction, appels au module) finit avant que les têtes soient relues et reconstruites ;
    -- au-delà de `limits.busyMs`, la synchronisation sera retentée (`sync.retryMs`)
    local started = GetGameTimer()
    while index.busy(editor.id) do
        if GetGameTimer() - started >= cfg.limits.busyMs then
            VavaAtelier.log.warn("atelier '%s' : une écriture tient encore ses verrous, synchronisation remise", editor.id)
            return false
        end
        Wait(LOCK_POLL_MS)
    end
    local knownRows = store.known(editor.id)
    if not knownRows then return false end
    local known = {}
    for _, row in ipairs(knownRows) do known[row.kind .. '|' .. row.def_id] = true end
    local seeded = seed(editor, known, step)
    if not seeded then return false end
    if not current(editor, generation) then return true end
    local rows, retired, tops = store.heads(editor.id), store.retired(editor.id), store.tops(editor.id)
    if not rows or not retired or not tops then return false end
    -- « refusée en jeu » des fiches hors de la portée : gardé à travers la reconstruction des têtes
    local refused = {}
    if scope ~= true then
        for kindId, kind in pairs(index.kinds(editor.id)) do
            for id, head in pairs(kind.byId) do
                if head.refused and not scope[kindId .. '|' .. id] then refused[#refused + 1] = { kindId, id } end
            end
        end
    end
    index.build(editor.id, rows, retired, tops)
    for _, ref in ipairs(refused) do
        local head = index.get(editor.id, ref[1], ref[2])
        if head and head.published then head.refused = true end
    end
    if seeded > 0 then
        local ok, code = journal.write(0, { editor = editor.id, kind = editor.firstKind, action = 'seeded',
            title = editor.label, summary = VavaAtelier.changes.count(seeded, texts.counts.seeded) })
        if not ok then VavaAtelier.log.warn('graine non journalisée : %s', tostring(code)) end
    end
    local applied, removed = reconcile(editor, rows, step, generation, scope)
    if not applied then return false end
    if not current(editor, generation) then return true end
    local total = 0
    for _, kindId in ipairs(editor.kindOrder) do total = total + index.liveCount(editor.id, kindId) end
    index.setState(editor.id, 'ready')
    entries.invalidate(editor.id)
    VavaAtelier.log.info("atelier '%s' : %d fiches en base, %d venues de la config, %d rapprochée(s), %d retirée(s)%s",
        editor.id, total, seeded, applied, removed, scope == true and '' or ' (fiches du lot seulement)')
    return true
end

--- Lance la synchronisation d'un atelier gardé dans un fil (l'atelier rend `syncing` jusqu'à la fin). `only` : les
--- seules fiches à rapprocher ({ ['type|id'] = true } : lot refusé par le module, fiches importées), si l'atelier a
--- déjà été entièrement rapproché ; sinon (ou si une synchronisation entière tourne), tout l'atelier.
---@param editor vAvA.AtelierEditor
---@param reason string  declare | refusal | reimport | import | retry
---@param only? table<string, boolean>
function sync.start(editor, reason, only)
    if not editor or not editor.stored then return end
    local scope = lc.syncScope(active[editor.id], synced[editor.id] == true, only)
    local generation = (generations[editor.id] or 0) + 1
    generations[editor.id] = generation
    active[editor.id] = scope
    if scope == true then synced[editor.id] = nil end
    index.setState(editor.id, 'syncing')
    CreateThread(function()
        for attempt = 1, cfg.sync.retries do
            if not current(editor, generation) then return end
            if once(editor, generation, scope) then
                if current(editor, generation) then
                    active[editor.id] = nil
                    synced[editor.id] = true
                end
                return
            end
            VavaAtelier.log.warn("atelier '%s' : synchronisation (%s) en échec, essai %d sur %d", editor.id,
                tostring(reason), attempt, cfg.sync.retries)
            if attempt < cfg.sync.retries then Wait(cfg.sync.retryMs) end
        end
        if current(editor, generation) then
            active[editor.id], synced[editor.id] = nil, nil
            index.setState(editor.id, 'failed')
            VavaAtelier.log.error("atelier '%s' : à synchroniser (registres muets) ; le module tourne sur sa config. "
                .. '/%s etat le montre ; il sera retenté à la prochaine écriture.', editor.id, cfg.archives.command)
        end
    end)
end

--- Arrête toute synchronisation en cours d'un atelier (retiré du registre).
---@param editorId string
function sync.cancel(editorId)
    generations[editorId] = (generations[editorId] or 0) + 1
    active[editorId], synced[editorId] = nil, nil
end

--- Clés { ['type|id'] = true } des fiches d'un lot ({ { kind, id } } ou { { head } }), pour `sync.start`.
---@param items table[]
---@return table<string, boolean>
function sync.keysOf(items)
    local out = {}
    for _, item in ipairs(items) do
        local kindId = item.head and item.head.kind or item.kind
        local id = item.head and item.head.id or item.id
        out[kindId .. '|' .. id] = true
    end
    return out
end

--- Réparation au démarrage (avant editorsReady) : essais rendus, doublons réglés. À appeler dans un fil.
---@return boolean
function sync.repair()
    local reset = store.resetTrials()
    if reset == nil then return false end
    if reset > 0 then VavaAtelier.log.warn('définitions : %d essai(s) rendu(s) aux brouillons (redémarrage)', reset) end
    local rows = store.liveRows()
    if not rows then return false end
    local byFiche = {}
    for _, row in ipairs(rows) do
        local key = row.editor .. '|' .. row.kind .. '|' .. row.def_id
        local list = byFiche[key]
        if not list then
            list = {}
            byFiche[key] = list
        end
        list[#list + 1] = { id = index.toInt(row.id), version = index.toInt(row.version), status = row.status,
            at = index.toInt(row.at) }
    end
    local archive, delete = {}, {}
    local keys = {}
    for key in pairs(byFiche) do keys[#keys + 1] = key end
    sort(keys)
    for _, key in ipairs(keys) do
        local plan = lc.repair(byFiche[key])
        for _, id in ipairs(plan.archive) do archive[#archive + 1] = id end
        for _, id in ipairs(plan.delete) do delete[#delete + 1] = id end
        if #plan.archive > 0 then
            VavaAtelier.log.warn('définitions : %s avait plusieurs versions publiées, archivées : %s', key,
                store.describe(plan.archive))
        end
        if #plan.delete > 0 then
            VavaAtelier.log.warn('définitions : %s avait plusieurs brouillons, retirés : %s', key,
                store.describe(plan.delete))
        end
    end
    if #archive > 0 or #delete > 0 then return store.repair(archive, delete) == true end
    return true
end

--- Atelier « à synchroniser » : nouvel essai (appelé à une écriture refusée pour cette raison).
---@param editorId string
function sync.retry(editorId)
    if index.state(editorId) ~= 'failed' then return end
    sync.start(editors.get(editorId), 'retry')
end
