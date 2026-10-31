local helper = require('tests.helper')

-- Cycle de vie d'une fiche gardée (T-101, shared/lifecycle.lua) : transitions par rôle, numéros, lots, cascades,
-- ordre des appels, purge, réparation, annulation, pied de fiche.
describe('vava_atelier lifecycle', function()
    local lc

    local ME, OTHER = 7, 9

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
            'modules/vava_atelier/shared/lifecycle.lua',
        })
        lc = VavaAtelier.lifecycle
    end)

    local function head(over)
        local out = {}
        for k, v in pairs(over or {}) do out[k] = v end
        return out
    end
    local published = { version = 3 }
    local function draft(holder, status, removal) return { holder = holder, status = status or 'draft', removal = removal } end

    describe('situations', function()
        it('vue par l\'appelant', function()
            assert.equal('new', lc.situation(nil, ME))
            assert.equal('published', lc.situation(head({ published = published }), ME))
            assert.equal('retired', lc.situation(head({ retired = { version = 4 } }), ME))
            assert.equal('own_draft', lc.situation(head({ published = published, draft = draft(ME) }), ME))
            assert.equal('own_trial', lc.situation(head({ draft = draft(ME, 'trial') }), ME))
            assert.equal('own_removal', lc.situation(head({ published = published, draft = draft(ME, 'draft', true) }), ME))
            assert.equal('other_draft', lc.situation(head({ draft = draft(OTHER) }), ME))
            assert.equal('other_trial', lc.situation(head({ draft = draft(OTHER, 'trial') }), ME))
            assert.equal('other_removal', lc.situation(head({ draft = draft(OTHER, 'draft', true) }), ME))
            -- console (sans compte) : jamais tenant
            assert.equal('other_draft', lc.situation(head({ draft = draft(nil) }), nil))
        end)
    end)

    describe('transitions (§ 5.6.2)', function()
        local function ok(action, situation, isPublished)
            local verdict = lc.allowed(action, situation, true, isPublished ~= false)
            assert.is_true(verdict, action .. ' ' .. situation)
            local refused, code = lc.allowed(action, situation, false, isPublished ~= false)
            assert.is_false(refused, action .. ' sans droit')
            assert.equal('not_allowed', code)
        end
        local function no(action, situation, expected, isPublished)
            local verdict, code = lc.allowed(action, situation, true, isPublished ~= false)
            assert.is_false(verdict, action .. ' ' .. situation)
            assert.equal(expected, code, action .. ' ' .. situation)
        end

        it('enregistrer', function()
            ok('save', 'new')
            ok('save', 'published')
            ok('save', 'own_draft')
            ok('save', 'own_trial')
            no('save', 'other_draft', 'draft_taken')
            no('save', 'other_trial', 'draft_taken')
            no('save', 'own_removal', 'draft_open')
            no('save', 'retired', 'unknown_entry')
        end)

        it('essayer, arrêter l\'essai', function()
            ok('trial', 'own_draft')
            no('trial', 'other_draft', 'not_holder')
            no('trial', 'own_trial', 'trial_busy')
            no('trial', 'own_removal', 'not_allowed')
            no('trial', 'published', 'no_draft')
            ok('endTrial', 'own_trial')
            no('endTrial', 'other_trial', 'not_holder')
            no('endTrial', 'own_draft', 'stale')
        end)

        it('publier, abandonner', function()
            for _, situation in ipairs({ 'own_draft', 'own_trial', 'own_removal' }) do
                ok('publish', situation)
                ok('discard', situation)
            end
            no('publish', 'other_draft', 'not_holder')
            no('publish', 'other_removal', 'not_holder')
            no('publish', 'published', 'no_draft')
            no('discard', 'other_trial', 'not_holder')
            no('publish', 'new', 'unknown_entry')
        end)

        it('retirer', function()
            ok('retire', 'published')
            assert.equal('discard', lc.allowed('retire', 'own_draft', true, false))
            assert.equal('discard', lc.allowed('retire', 'own_trial', true, false))
            no('retire', 'own_draft', 'draft_open')
            no('retire', 'other_draft', 'draft_taken')
            no('retire', 'own_removal', 'draft_open')
            no('retire', 'retired', 'unknown_entry')
            assert.is_false((lc.allowed('retire', 'own_draft', false, false)))
        end)

        it('reprendre', function()
            ok('take', 'other_draft')
            ok('take', 'other_trial')
            ok('take', 'other_removal')
            no('take', 'own_draft', 'not_allowed')
            no('take', 'published', 'no_draft')
        end)

        it('rétablir', function()
            ok('restore', 'published')
            ok('restore', 'retired')
            ok('restore', 'other_draft')
            no('restore', 'new', 'unknown_entry')
        end)

        it('interdits : rien ne repasse en brouillon, ni essai d\'un brouillon d\'autrui, ni publication sans brouillon', function()
            no('trial', 'published', 'no_draft')
            no('trial', 'other_trial', 'not_holder')
            no('publish', 'published', 'no_draft')
            no('discard', 'published', 'no_draft')
            no('take', 'retired', 'unknown_entry')
            assert.is_false((lc.allowed('inconnue', 'own_draft', true, true)))
        end)
    end)

    describe('numéros', function()
        it('fiche nouvelle → 1, après v1..v3 → 4, rétablir v2 → 4, retrait → n + 1', function()
            assert.equal(1, lc.nextVersion(nil))
            assert.equal(4, lc.nextVersion(3))
            -- rétablir la version 2 d'une fiche à v1..v3 : nouvelle version 4 (copie, restored_from = 2)
            assert.same({ version = 4, restoredFrom = 2 }, lc.restorePlan({ status = 'archived', removal = 0, version = 2 }, 3))
            -- retrait d'une fiche publiée en v5 : version de retrait 6
            assert.equal(6, lc.nextVersion(5))
        end)

        it('rétablir un retrait, la publiée ou un brouillon : refusé', function()
            assert.same({ nil, 'not_archived' }, { lc.restorePlan({ status = 'archived', removal = 1, version = 4 }, 4) })
            assert.same({ nil, 'not_archived' }, { lc.restorePlan({ status = 'archived', removal = true, version = 4 }, 4) })
            assert.same({ nil, 'not_archived' }, { lc.restorePlan({ status = 'published', removal = 0, version = 3 }, 3) })
            assert.same({ nil, 'not_archived' }, { lc.restorePlan({ status = 'draft', removal = 0 }, 3) })
        end)
    end)

    describe('lots', function()
        local kinds = { zone = false, node = 'zone', tree = 'node', leaf = 'tree' }

        local function ref(kind, id, parent, holder, removal)
            return { kind = kind, id = id, parent = parent, holder = holder, removal = removal }
        end

        it('enfants du seul tenant, retraits compris, triés', function()
            local drafts = {
                ref('node', 'n2', 'foret', ME), ref('node', 'n1', 'foret', ME, true), ref('node', 'n3', 'foret', OTHER),
                ref('node', 'n4', 'autre', ME), ref('tree', 't1', 'n1', ME),
            }
            local out = lc.bundle({ kind = 'zone', id = 'foret' }, drafts, kinds, ME, 200)
            local ids = {}
            for i, item in ipairs(out) do ids[i] = item.id .. ':' .. item.depth end
            assert.same({ 'n1:2', 'n2:2', 't1:3' }, ids)
            assert.is_true(out[1].removal)
        end)

        it('profondeur 3 au plus', function()
            local drafts = { ref('node', 'n1', 'foret', ME), ref('tree', 't1', 'n1', ME), ref('leaf', 'l1', 't1', ME) }
            local out = lc.bundle({ kind = 'zone', id = 'foret' }, drafts, kinds, ME, 200)
            assert.equal(2, #out)
        end)

        it('plus de 200 → full', function()
            local drafts = {}
            for i = 1, 201 do drafts[i] = ref('node', 'n' .. i, 'foret', ME) end
            local out, err = lc.bundle({ kind = 'zone', id = 'foret' }, drafts, kinds, ME, 200)
            assert.is_nil(out)
            assert.equal('full', err)
            drafts[201] = nil
            assert.equal(200, #lc.bundle({ kind = 'zone', id = 'foret' }, drafts, kinds, ME, 200))
        end)

        it('parent publié ou dans le lot', function()
            local function isPublished(kind, id) return kind == 'zone' and id == 'foret' end
            assert.is_true(lc.parentReady('zone', nil, kinds, isPublished))
            assert.is_true(lc.parentReady('node', 'foret', kinds, isPublished))
            assert.same({ false, 'parent_missing' }, { lc.parentReady('node', 'lande', kinds, isPublished) })
            assert.same({ false, 'parent_missing' }, { lc.parentReady('node', nil, kinds, isPublished) })
            assert.is_true(lc.parentReady('node', 'lande', kinds, isPublished, { ['zone|lande'] = true }))
        end)

        it('retrait en cascade', function()
            local pub = {
                { kind = 'node', id = 'n1', parent = 'foret' }, { kind = 'node', id = 'n2', parent = 'foret' },
                { kind = 'tree', id = 't1', parent = 'n1' }, { kind = 'node', id = 'n9', parent = 'lande' },
            }
            local out = lc.cascade('zone', 'foret', kinds, pub, 200)
            local ids = {}
            for i, item in ipairs(out) do ids[i] = item.id end
            assert.same({ 'n1', 'n2', 't1' }, ids)
        end)

        it('rétablissement en cascade du seul même lot', function()
            local retired = {
                { kind = 'zone', id = 'foret', batch = 40, version = 4 },
                { kind = 'node', id = 'n1', batch = 40, version = 3 },
                { kind = 'node', id = 'n2', batch = 40, version = 2 },
                { kind = 'node', id = 'n3', batch = 12, version = 5 },
            }
            assert.same({ { kind = 'node', id = 'n1', version = 2 }, { kind = 'node', id = 'n2', version = 1 } },
                lc.restoreCascade(40, { kind = 'zone', id = 'foret' }, retired))
            assert.same({}, lc.restoreCascade(nil, { kind = 'zone', id = 'foret' }, retired))
        end)

        it('ordre des appels : retraits des enfants au parent, puis applications du parent aux enfants', function()
            local items = {
                { kind = 'zone', id = 'foret', depth = 1 },
                { kind = 'node', id = 'n2', depth = 2 },
                { kind = 'node', id = 'n1', depth = 2, removal = true },
                { kind = 'tree', id = 't1', depth = 3, removal = true },
                { kind = 'tree', id = 't2', depth = 3 },
            }
            local out = lc.callOrder(items)
            local seq = {}
            for i, item in ipairs(out) do seq[i] = (item.removal and '-' or '+') .. item.id .. (item.last and '!' or '') end
            assert.same({ '-t1', '-n1', '+foret', '+n2', '+t2!' }, seq)
            assert.is_nil(items[5].last)
            local removalOnly = lc.callOrder({ { kind = 'zone', id = 'a', depth = 1, removal = true },
                { kind = 'node', id = 'b', depth = 2, removal = true } })
            assert.equal('b', removalOnly[1].id)
            assert.is_true(removalOnly[2].last)
        end)

        it('lot vu par le module : références légères sans data pour validate, data pour validateLot (R-1)', function()
            local place = { x = 1.0, y = 2.0, z = 3.0 }
            local big = { texte = string.rep('a', 2000) }
            local items = {
                { kind = 'zone', id = 'foret', data = big, place = place },
                { kind = 'node', id = 'n1', data = { taille = 2 }, parent = 'foret', removal = true, extra = 'jamais' },
            }
            local refs = lc.lot(items)
            assert.same({
                { kind = 'zone', id = 'foret', place = place, removal = false },
                { kind = 'node', id = 'n1', parent = 'foret', removal = true },
            }, refs)
            for _, ref in ipairs(refs) do assert.is_nil(ref.data) end
            local full = lc.lot(items, true)
            assert.equal(big, full[1].data)
            assert.same({ taille = 2 }, full[2].data)
            assert.is_nil(full[2].extra)
            assert.is_false(full[1].removal)
            assert.same({}, lc.lot({}))
        end)

        it('portée d\'une synchronisation : les seules fiches d\'un lot si l\'atelier est déjà rapproché (R-2 d)', function()
            local only = { ['zone|a'] = true }
            assert.same({ ['zone|a'] = true }, lc.syncScope(nil, true, only))
            -- jamais rapproché entièrement (démarrage, échec) : tout
            assert.is_true(lc.syncScope(nil, false, only))
            -- sans liste : tout
            assert.is_true(lc.syncScope(nil, true, nil))
            -- une synchronisation entière en cours : la nouvelle la reprend entière
            assert.is_true(lc.syncScope(true, true, only))
            -- une limitée en cours : l'union, sans toucher aux listes reçues
            local running = { ['node|b'] = true }
            assert.same({ ['zone|a'] = true, ['node|b'] = true }, lc.syncScope(running, true, only))
            assert.same({ ['zone|a'] = true }, only)
            assert.same({ ['node|b'] = true }, running)
        end)
    end)

    describe('purge', function()
        local function versions(n, publishedAt, retiredTop)
            local out = {}
            for v = 1, n do
                local status = 'archived'
                if v == publishedAt then status = 'published' end
                out[v] = { id = 100 + v, version = v, status = status, removal = retiredTop and v == n or nil }
            end
            return out
        end

        it('garde 20', function()
            local ids = lc.purge(versions(25, 25), 20)
            assert.same({ 101, 102, 103, 104, 105 }, ids)
            assert.same({}, lc.purge(versions(20, 20), 20))
        end)

        it('jamais la publiée', function()
            local ids = lc.purge(versions(25, 2), 20)
            for _, id in ipairs(ids) do assert.not_equal(102, id) end
            assert.equal(4, #ids)
        end)

        it('jamais la dernière ligne d\'une fiche retirée', function()
            local ids = lc.purge(versions(3, nil, true), 0)
            assert.same({ 101, 102 }, ids)
        end)
    end)

    describe('réparation', function()
        it('deux publiées → la plus haute reste ; deux brouillons → le plus récent reste', function()
            local plan = lc.repair({
                { id = 1, version = 2, status = 'published' }, { id = 2, version = 5, status = 'published' },
                { id = 3, version = 1, status = 'archived' },
                { id = 4, status = 'draft', at = 100 }, { id = 5, status = 'trial', at = 300 }, { id = 6, status = 'draft', at = 200 },
            })
            assert.same({ 1 }, plan.archive)
            assert.same({ 4, 6 }, plan.delete)
            assert.same({ archive = {}, delete = {} }, lc.repair({ { id = 1, version = 1, status = 'published' } }))
        end)
    end)

    describe('annulation d\'un lot', function()
        it('lignes rendues à leur statut d\'avant, lignes créées supprimées', function()
            local undo = lc.undo({
                rows = { { id = 10, before = 'published' }, { id = 11, before = 'draft' }, { id = 12, before = 'trial' } },
                inserted = { { kind = 'node', id = 'n1', version = 4 } },
            })
            assert.same({ 11, 12 }, undo.toDraft)
            assert.same({ 10 }, undo.toPublished)
            assert.same({ { kind = 'node', id = 'n1', version = 4 } }, undo.delete)
        end)
    end)

    describe('lot écrit (S-4, R-7)', function()
        local expected = {
            { kind = 'zone', id = 'foret', version = 4, status = 'published' },
            { kind = 'node', id = 'n1', version = 2, status = 'archived' },
        }

        it('chaque fiche a sa ligne au statut attendu : numéros des lignes écrites', function()
            local ok, ids = lc.lotComplete(expected, {
                { id = '31', kind = 'zone', def_id = 'foret', version = '4', status = 'published' },
                { id = 32, kind = 'node', def_id = 'n1', version = 2, status = 'archived' },
                -- une ligne plus ancienne du même numéro de lot (autre version) ne gêne pas
                { id = 12, kind = 'zone', def_id = 'foret', version = 2, status = 'archived' },
            })
            assert.is_true(ok)
            assert.same({ ['zone|foret'] = 31, ['node|n1'] = 32 }, ids)
        end)

        it('une ligne absente (copie d\'une source disparue, révision changée) ou d\'un autre statut : à défaire', function()
            assert.is_false(lc.lotComplete(expected, {
                { id = 31, kind = 'zone', def_id = 'foret', version = 4, status = 'published' },
            }))
            assert.is_false(lc.lotComplete(expected, {
                { id = 31, kind = 'zone', def_id = 'foret', version = 4, status = 'draft' },
                { id = 32, kind = 'node', def_id = 'n1', version = 2, status = 'archived' },
            }))
            assert.is_true((lc.lotComplete({}, {})))
        end)
    end)

    describe('jeton', function()
        it('16 hexadécimaux, change avec une révision', function()
            local a = lc.token({ what = 'publish', main = { 1, 3 }, children = { { 2, 1 } }, published = 3 })
            local b = lc.token({ what = 'publish', main = { 1, 4 }, children = { { 2, 1 } }, published = 3 })
            assert.truthy(a:find('^%x+$'))
            assert.equal(16, #a)
            assert.not_equal(a, b)
        end)
    end)

    describe('pied de fiche', function()
        local function ids(list)
            local out = {}
            for i, b in ipairs(list) do
                out[i] = b.id .. (b.primary and '*' or '') .. (b.link and '~' or '') .. (b.removal and '-' or '')
            end
            return out
        end
        local opts = { stored = true, hasTrial = true, versioned = true }

        it('par situation (§ 9.1)', function()
            assert.same({ 'save*', 'check~' }, ids(lc.footer('new', opts)))
            assert.same({ 'save*', 'history~', 'retire~', 'check~' }, ids(lc.footer('published', opts)))
            assert.same({ 'save', 'trial', 'publish*', 'history~', 'discard~', 'check~' }, ids(lc.footer('own_draft', opts)))
            assert.same({ 'save', 'publish*', 'discard~', 'check~' },
                ids(lc.footer('own_draft', { stored = true, hasTrial = false, versioned = false })))
            assert.same({ 'save', 'endTrial', 'publish*', 'history~', 'discard~' }, ids(lc.footer('own_trial', opts)))
            assert.same({ 'publish*-', 'history~', 'discard~-' }, ids(lc.footer('own_removal', opts)))
            assert.same({ 'take', 'history~' }, ids(lc.footer('other_trial', opts)))
            assert.same({ 'restore*' }, ids(lc.footer('published', { stored = true, archived = { removal = false } })))
            assert.same({}, ids(lc.footer('published', { stored = true, archived = { removal = true } })))
            assert.same({}, ids(lc.footer('published', { stored = true, archived = { unreadable = true } })))
            assert.same({ 'check*' }, ids(lc.footer('published', { stored = false })))
        end)
    end)
end)
