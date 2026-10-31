local helper = require('tests.helper')

-- Écriture d'une pose (modules/vava_atelier/server/lifecycle.lua › cycle.place, 1.3.0, T-102), avec les vraies têtes
-- en mémoire (server/index.lua : verrous, places de brouillon), les vraies règles pures et des doublures de la base, du
-- journal et des modules. Relecture sécurité de T-102 :
--   S-2 : le brouillon du parent copié de sa publiée par une pose a sa ligne `saved` au journal (l'enfant posé, aucune) ;
--   S-3 : l'écriture passe par la garde des écritures de T-101 (verrous encore à nous, atelier inchangé, épinglage) :
--         rien n'est écrit si l'atelier a changé pendant la pose ; dans une transaction, la révision de l'enfant mis à
--         jour est relue après coup, sinon `stale` et les fiches de la pose sont rapprochées.
describe('vava_atelier écriture d’une pose', function()
    local index, cycle, editor, kinds, ctx, rows, draftRows, journal, transactions, synced, inserted, nextRow

    local EDITOR, ACCOUNT = 'vava_gathering:zones', 7

    before_each(function()
        helper.reset()
        VavaAtelier, VavaGathering = nil, nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/editing.lua',
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
            'modules/vava_atelier/shared/journaltext.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
            'modules/vava_atelier/shared/place.lua',
            'modules/vava_atelier/shared/slug.lua',
            'modules/vava_atelier/shared/changes.lua',
            'modules/vava_atelier/shared/stored.lua',
            'modules/vava_atelier/shared/lifecycle.lua',
        })
        VavaAtelier.core = {}
        VavaAtelier.log = { warn = function() end, error = function() end, info = function() end }
        helper.load('modules/vava_atelier/server/index.lua')
        index = VavaAtelier.index

        kinds = {}
        for _, def in ipairs(VavaGathering.editing.declaration(VavaGathering.config).kinds) do
            kinds[def.id] = { def = def, fields = {} }
        end
        editor = { id = EDITOR, kinds = kinds, format = 1, stored = true, parents = { node = 'zone' },
            children = { zone = { 'node' } } }
        rows, draftRows, journal, transactions, synced, inserted, nextRow = {}, {}, {}, {}, {}, {}, 100

        VavaAtelier.bridge = {}
        VavaAtelier.journal = { write = function(_, entry)
            journal[#journal + 1] = entry
            return true
        end }
        VavaAtelier.entries = { invalidate = function() end }
        VavaAtelier.check = {}
        local current = editor
        VavaAtelier.editors = { get = function() return current end, swap = function(other) current = other end }
        VavaAtelier.store = {
            row = function(id) return rows[id] end,
            draftRow = function(_, kindId, id) return draftRows[kindId .. '|' .. id] end,
            insertDraftStep = function(d) return { insert = d } end,
            updateDraftStep = function(rowId, rev, d) return { update = rowId, rev = rev, d = d } end,
            transaction = function(steps)
                transactions[#transactions + 1] = steps
                for _, step in ipairs(steps) do
                    if step.insert then
                        nextRow = nextRow + 1
                        draftRows[step.insert.kind .. '|' .. step.insert.defId] = { id = nextRow, rev = 1 }
                    end
                end
                return true
            end,
            insertDraft = function(d)
                nextRow = nextRow + 1
                inserted[#inserted + 1] = d
                return nextRow
            end,
            updateDraft = function() return 1 end,
        }
        VavaAtelier.calls = {
            encode = function() return '{}', '{}' end,
            titleOf = function(kind, data, fallback) return data and data[kind.def.form.titleField] or fallback end,
            notify = function() end,
            entryOf = function(_, _, row) return { data = row.decoded, place = row.where, parent = row.parent } end,
        }
        VavaAtelier.trials = { of = function() return nil end }
        VavaAtelier.sync = { start = function(_, reason, keys) synced[#synced + 1] = { reason = reason, keys = keys } end }
        helper.load('modules/vava_atelier/server/lifecycle.lua')
        cycle = VavaAtelier.cycle

        index.build(EDITOR, {}, {}, {})
        local zone = index.ensure(EDITOR, 'zone', 'bois')
        zone.title, zone.published = 'Bois des Essais', { row = 1, version = 1 }
        index.touch(EDITOR, zone)
        rows[1] = { id = 1, format = 1, title = 'Bois des Essais', parent = '', data = '{}', place = '{}',
            fingerprint = 'f', decoded = { nom = 'Bois des Essais', genre = 'foret', fatigue = 2, repos = 4,
                cicatrice = 172800 }, where = { x = 100.0, y = 100.0, z = 30.0, r = 60.0 } }
        ctx = { editor = editor, kind = kinds.node, accountId = ACCOUNT, source = 3, label = 'Sénéchal',
            generation = index.generation(EDITOR) }
    end)

    after_each(function()
        VavaAtelier, VavaGathering = nil, nil
    end)

    local function newChild()
        return { kind = kinds.node, head = nil, id = 'bois_chene_1', rev = 0,
            where = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 },
            data = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 }, title = 'Chêne 1',
            parentId = 'bois', parentHead = index.get(EDITOR, 'zone', 'bois') }
    end

    it('enfant nouveau sous une zone publiée : une transaction, une ligne `saved` pour la zone, aucune pour le point', function()
        local ok, result = cycle.place(ctx, newChild())
        assert.is_true(ok, tostring(result))
        assert.equal(1, #transactions)
        assert.equal(2, #transactions[1])
        assert.equal(1, #journal)
        assert.same({ 'zone', 'bois', 'saved', 1 }, { journal[1].kind, journal[1].id, journal[1].action, journal[1].version })
        assert.equal(ACCOUNT, index.get(EDITOR, 'zone', 'bois').draft.holder)
        assert.equal(1, result.head.draft.rev)
    end)

    -- contre-relecture C-3 : écrit en base, la ligne du parent part même si une relecture échoue ensuite
    it('relecture du parent impossible après la transaction : ligne `saved` du parent écrite quand même', function()
        local draftRow = VavaAtelier.store.draftRow
        VavaAtelier.store.draftRow = function(_, kindId, id)
            if kindId == 'zone' then return nil, 'db_error' end
            return draftRow(_, kindId, id)
        end
        assert.same({ false, 'db_error' }, { cycle.place(ctx, newChild()) })
        assert.equal(1, #transactions)
        assert.equal(1, #journal)
        assert.same({ 'zone', 'saved' }, { journal[1].kind, journal[1].action })
        assert.equal(1, #synced)
    end)

    -- seconde contre-relecture D-3 : point publié déplacé (copie) sous une zone publiée sans brouillon
    it('point publié déplacé, relecture du parent impossible : lignes `saved` du parent ET du point écrites', function()
        local point = index.ensure(EDITOR, 'node', 'bois_chene_1')
        point.title, point.published = 'Chêne 1', { row = 60, version = 1 }
        index.touch(EDITOR, point)
        rows[60] = { id = 60, decoded = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
            where = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
        local draftRow = VavaAtelier.store.draftRow
        VavaAtelier.store.draftRow = function(_, kindId, id)
            if kindId == 'zone' then return nil, 'db_error' end
            return draftRow(_, kindId, id)
        end
        local req = { kind = kinds.node, head = point, id = 'bois_chene_1', rev = 0,
            where = { x = 113.0, y = 100.0, z = 30.0, h = 0.0 }, parentId = 'bois',
            parentHead = index.get(EDITOR, 'zone', 'bois') }
        assert.same({ false, 'db_error' }, { cycle.place(ctx, req) })
        assert.equal(1, #transactions)
        assert.equal(2, #journal)
        assert.same({ 'zone', 'saved' }, { journal[1].kind, journal[1].action })
        assert.same({ 'node', 'saved', 1 }, { journal[2].kind, journal[2].action, journal[2].version })
    end)

    it('point publié déplacé sous une zone publiée : une ligne `saved` chacun, jamais deux pour le point', function()
        local point = index.ensure(EDITOR, 'node', 'bois_chene_1')
        point.title, point.published = 'Chêne 1', { row = 60, version = 1 }
        index.touch(EDITOR, point)
        rows[60] = { id = 60, decoded = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
            where = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
        local req = { kind = kinds.node, head = point, id = 'bois_chene_1', rev = 0,
            where = { x = 113.0, y = 100.0, z = 30.0, h = 0.0 }, parentId = 'bois',
            parentHead = index.get(EDITOR, 'zone', 'bois') }
        assert.is_true((cycle.place(ctx, req)))
        assert.equal(2, #journal)
    end)

    it('ligne relue d’un autre brouillon que celui de la tête : stale (contre-relecture C-3)', function()
        local point = index.ensure(EDITOR, 'node', 'bois_chene_1')
        point.title, point.draft = 'Chêne 1', { row = 50, rev = 2, status = 'draft', holder = ACCOUNT, removal = false,
            parent = 'bois' }
        index.touch(EDITOR, point)
        rows[50] = { id = 50, decoded = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
            where = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
        draftRows['node|bois_chene_1'] = { id = 51, rev = 3 }
        local req = { kind = kinds.node, head = point, id = 'bois_chene_1', rev = 2,
            where = { x = 113.0, y = 100.0, z = 30.0, h = 0.0 }, parentId = 'bois',
            parentHead = index.get(EDITOR, 'zone', 'bois') }
        assert.same({ false, 'stale' }, { cycle.place(ctx, req) })
        assert.equal(1, #synced)
    end)

    it('atelier changé pendant la pose : rien n’est écrit (syncing)', function()
        VavaAtelier.editors.swap({ id = EDITOR })
        assert.same({ false, 'syncing' }, { cycle.place(ctx, newChild()) })
        assert.equal(0, #transactions)
        assert.equal(0, #journal)
        assert.is_nil(index.get(EDITOR, 'zone', 'bois').draft)
    end)

    it('atelier changé avant une pose simple : rien n’est écrit non plus', function()
        local zone = index.get(EDITOR, 'zone', 'bois')
        zone.draft = { row = 2, rev = 1, status = 'draft', holder = ACCOUNT, removal = false }
        index.touch(EDITOR, zone)
        VavaAtelier.editors.swap({ id = EDITOR })
        assert.same({ false, 'syncing' }, { cycle.place(ctx, newChild()) })
        assert.same({}, inserted)
    end)

    it('révision de l’enfant dépassée dans la transaction : stale, fiches de la pose rapprochées', function()
        local point = index.ensure(EDITOR, 'node', 'bois_chene_1')
        point.title, point.draft = 'Chêne 1', { row = 50, rev = 2, status = 'draft', holder = ACCOUNT, removal = false,
            parent = 'bois' }
        index.touch(EDITOR, point)
        rows[50] = { id = 50, decoded = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
            where = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
        -- un autre écrit entre-temps : la ligne est déjà à la révision 3, notre UPDATE … WHERE rev = 2 n'a rien touché
        draftRows['node|bois_chene_1'] = { id = 50, rev = 4 }
        local req = { kind = kinds.node, head = point, id = 'bois_chene_1', rev = 2,
            where = { x = 113.0, y = 100.0, z = 30.0, h = 0.0 }, parentId = 'bois',
            parentHead = index.get(EDITOR, 'zone', 'bois') }
        assert.same({ false, 'stale' }, { cycle.place(ctx, req) })
        assert.equal(1, #transactions)
        assert.equal(1, #synced)
        assert.equal(2, #synced[1].keys)
        -- révision bien relue : la pose passe
        draftRows['node|bois_chene_1'] = { id = 50, rev = 3 }
        synced = {}
        local zone = index.get(EDITOR, 'zone', 'bois')
        zone.draft = nil
        index.touch(EDITOR, zone)
        point.draft.rev = 2
        local ok = cycle.place(ctx, req)
        assert.is_true(ok)
        assert.equal(0, #synced)
    end)
end)
