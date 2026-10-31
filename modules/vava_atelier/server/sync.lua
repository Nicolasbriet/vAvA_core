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
               d'abord), têtes en mémoire, listes oubliées. Pendant ce temps l'atelier rend `syncing`. Base muette :
               `sync.retries` essais espacés de `sync.retryMs`, puis « à synchroniser » (le module tourne sur sa
               config). Un `apply` refusé : la fiche reste publiée en base, « refusée en jeu », retentée à la prochaine.
    Dépendances : shared/constants.lua, config.lua, shared/lifecycle.lua, shared/stored.lua, bridge/server.lua,
                  server/core.lua, server/editors.lua, server/journal.lua, server/entries.lua, server/store.lua,
                  server/index.lua, server/calls.lua
]]

local pairs, ipairs, tostring, format = pairs, ipairs, tostring, string.format
local sort = table.sort
local CreateThread, Wait = CreateThread, Wait

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

--- Une synchronisation est-elle toujours d'actualité ?
local function current(editor, generation)
    return editors.get(editor.id) == editor and generations[editor.id] == generation
end

--- Pause du fil toutes les `sync.yieldEvery` fiches (serveur : cède la main au reste du tour).
local function yielder()
    local count = 0
    return function()
        count = count + 1
        if count % cfg.sync.yieldEvery == 0 then Wait(0) end -- audit: ok (fil serveur, pas une boucle d'affichage)
    end
end

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

--- Rapprochement : le module reçoit l'état de la base. Rend les nombres d'applications et de retraits.
---@param editor vAvA.AtelierEditor
---@param rows table[]  lignes vivantes (données comprises)
---@param step fun()
---@param generation integer
---@return integer applied
---@return integer removed
local function reconcile(editor, rows, step, generation)
    local published = {}
    for _, row in ipairs(rows) do
        if row.status == 'published' then published[row.kind .. '|' .. row.def_id] = row end
    end
    local depth = editor.kindDepth
    local items = {}
    -- applications : publiées en base dont le module a une autre empreinte (ou rien)
    for key, row in pairs(published) do
        local kind = editor.kinds[row.kind]
        if kind then
            step()
            local entry = calls.entryOf(editor, kind, row)
            if entry then
                local mine = calls.moduleRead(editor, kind, row.def_id)
                if not mine or mine.fingerprint ~= entry.fingerprint then
                    items[#items + 1] = { kind = row.kind, id = row.def_id, depth = depth[row.kind] or 1, entry = entry,
                        version = index.toInt(row.version), key = key }
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
            if not published[kindId .. '|' .. id] then
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
---@return boolean
local function once(editor, generation)
    local step = yielder()
    local knownRows = store.known(editor.id)
    if not knownRows then return false end
    local known = {}
    for _, row in ipairs(knownRows) do known[row.kind .. '|' .. row.def_id] = true end
    local seeded = seed(editor, known, step)
    if not seeded then return false end
    if not current(editor, generation) then return true end
    local rows, retired, tops = store.heads(editor.id), store.retired(editor.id), store.tops(editor.id)
    if not rows or not retired or not tops then return false end
    index.build(editor.id, rows, retired, tops)
    if seeded > 0 then
        local ok, code = journal.write(0, { editor = editor.id, kind = editor.firstKind, action = 'imported',
            title = editor.label, summary = format(texts.summaries.seeded, seeded) })
        if not ok then VavaAtelier.log.warn('graine non journalisée : %s', tostring(code)) end
    end
    local applied, removed = reconcile(editor, rows, step, generation)
    if not current(editor, generation) then return true end
    local total = 0
    for _, kindId in ipairs(editor.kindOrder) do total = total + index.liveCount(editor.id, kindId) end
    index.setState(editor.id, 'ready')
    entries.invalidate(editor.id)
    VavaAtelier.log.info("atelier '%s' : %d fiches en base, %d venues de la config, %d rapprochée(s), %d retirée(s)",
        editor.id, total, seeded, applied, removed)
    return true
end

--- Lance la synchronisation d'un atelier gardé dans un fil (l'atelier rend `syncing` jusqu'à la fin).
---@param editor vAvA.AtelierEditor
---@param reason string  declare | refusal | reimport | import
function sync.start(editor, reason)
    if not editor or not editor.stored then return end
    local generation = (generations[editor.id] or 0) + 1
    generations[editor.id] = generation
    index.setState(editor.id, 'syncing')
    CreateThread(function()
        for attempt = 1, cfg.sync.retries do
            if not current(editor, generation) then return end
            if once(editor, generation) then return end
            VavaAtelier.log.warn("atelier '%s' : synchronisation (%s) en échec, essai %d sur %d", editor.id,
                tostring(reason), attempt, cfg.sync.retries)
            if attempt < cfg.sync.retries then Wait(cfg.sync.retryMs) end
        end
        if current(editor, generation) then
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
