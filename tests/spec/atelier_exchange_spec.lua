local helper = require('tests.helper')

-- Archives JSON de l'Atelier (T-101, shared/exchange.lua) : noms de fichier, forme d'un fichier reçu (tout ou rien par
-- atelier), plan d'un import.
describe('vava_atelier exchange', function()
    local exchange
    local PANNEAUX, PROCL = 'vava_example_atelier:panneaux', 'vava_example_atelier:proclamations'

    local known
    local LIMITS = { editors = 32, perKind = 1000 }

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/exchange.lua',
        })
        exchange = VavaAtelier.exchange
        known = {
            [PANNEAUX] = { stored = true, format = 1, kinds = { panneau = true, affiche = true } },
            [PROCL] = { stored = true, format = 2, kinds = { proclamation = true } },
            ['vava_x:lecture'] = { stored = false, format = 1, kinds = { chose = true } },
        }
    end)

    local function entry(id, over)
        local e = { id = id, version = 1, data = { titre = 'Titre ' .. id } }
        for k, v in pairs(over or {}) do e[k] = v end
        return e
    end

    local function doc(editors)
        return { atelier = 1, exported_at = '2026-10-30T14:05:00Z', editors = editors }
    end

    describe('noms', function()
        it('permis et refusés', function()
            assert.is_true(exchange.validName('a.json'))
            assert.is_true(exchange.validName('atelier_20261030_140500.json'))
            assert.is_true(exchange.validName(string.rep('a', 59) .. '.json'))
            for _, name in ipairs({ '../a.json', 'a/b.json', 'a\\b.json', 'a.lua', 'a..json', '.json', '', 'a.json ',
                string.rep('a', 60) .. '.json', 'é.json', 'a.JSON', 'a.json/x', 'C:a.json' }) do
                assert.is_false(exchange.validName(name), name)
            end
            assert.is_false(exchange.validName(nil))
        end)

        it('nom d\'un export', function()
            assert.equal('atelier_20261030_140500.json', exchange.exportName(nil, '20261030_140500'))
            assert.equal('vava_example_atelier_panneaux_20261030_140500.json', exchange.exportName(PANNEAUX, '20261030_140500'))
            local long = exchange.exportName(string.rep('a', 30) .. ':' .. string.rep('b', 33), '20261030_140500')
            assert.is_true(exchange.validName(long), long)
        end)
    end)

    describe('fichier', function()
        it('forme d\'un export', function()
            local built = exchange.build({ { editor = PANNEAUX, format = 1, kinds = { panneau = { entry('a') } } } },
                '2026-10-30T14:05:00Z')
            assert.equal(1, built.atelier)
            assert.equal('a', built.editors[PANNEAUX].kinds.panneau[1].id)
            local parsed = exchange.parse(built, known, LIMITS)
            assert.is_nil(parsed.error)
            assert.is_nil(parsed.editors[1].error)
            assert.equal(1, #parsed.editors[1].entries)
        end)

        it('atelier ≠ 1, editors absent', function()
            assert.truthy(exchange.parse({ atelier = 2, editors = {} }, known, LIMITS).error)
            assert.truthy(exchange.parse({ atelier = 1 }, known, LIMITS).error)
            assert.truthy(exchange.parse('x', known, LIMITS).error)
        end)

        local function refusal(editors, needle)
            local parsed = exchange.parse(doc(editors), known, LIMITS)
            assert.is_nil(parsed.error)
            local err = parsed.editors[1].error
            assert.is_string(err)
            assert.truthy(err:find(needle, 1, true), err)
            assert.is_nil(parsed.editors[1].entries)
        end

        it('refus avec leur chemin', function()
            refusal({ ['vava_x:inconnu'] = { kinds = {} } }, 'vava_x:inconnu : atelier inconnu')
            refusal({ ['vava_x:lecture'] = { kinds = {} } }, 'vava_x:lecture : atelier inconnu, ou qui ne garde rien')
            refusal({ [PANNEAUX] = { kinds = { lanterne = {} } } }, PANNEAUX .. '.kinds.lanterne : type inconnu')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('../x') } } } }, PANNEAUX .. '.kinds.panneau[1].id')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('a'), entry('b'), entry('a') } } } },
                PANNEAUX .. '.kinds.panneau[3].id : « a » en double')
            refusal({ [PANNEAUX] = { format = 2, kinds = {} } }, PANNEAUX .. '.format : 2 plus récent')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('a', { data = 'x' }) } } } }, '[1].data')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('a', { intrus = 1 }) } } } }, '[1].intrus : clé inconnue')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('a', { version = 0 }) } } } }, '[1].version')
            refusal({ [PANNEAUX] = { kinds = { panneau = { entry('a', { parent = 'a/b' }) } } } }, '[1].parent')
            refusal({ [PANNEAUX] = { kinds = { panneau = { a = 1 } } } }, '.kinds.panneau : liste de fiches attendue')
        end)

        it('profondeur 7 refusée, 6 acceptée', function()
            local deep = entry('a', { data = { x = { { { { {} } } } } } })     -- fiche 1, data 2, x 3 … 7
            refusal({ [PANNEAUX] = { kinds = { panneau = { deep } } } }, 'plus de 6 niveaux')
            local ok = entry('a', { data = { x = { { { {} } } } } })            -- 6
            local parsed = exchange.parse(doc({ [PANNEAUX] = { kinds = { panneau = { ok } } } }), known, LIMITS)
            assert.is_nil(parsed.editors[1].error)
            -- un polygone tient dans la borne (fiche, lieu, sommets, sommet)
            local poly = entry('b', { place = { z = 0, points = { { x = 0, y = 0 }, { x = 1, y = 0 }, { x = 1, y = 1 } } } })
            parsed = exchange.parse(doc({ [PANNEAUX] = { kinds = { panneau = { poly } } } }), known, LIMITS)
            assert.is_nil(parsed.editors[1].error)
            assert.equal(7, exchange.depth({ { { { { { {} } } } } } }, 10))
            assert.equal(4, exchange.depth({ { { { { { {} } } } } } }, 3))
        end)

        it('une fiche refusée : rien pour son atelier, les autres passent', function()
            local parsed = exchange.parse(doc({
                [PANNEAUX] = { kinds = { panneau = { entry('a'), entry('b c') } } },
                [PROCL] = { format = 2, kinds = { proclamation = { entry('couronnement') } } },
            }), known, LIMITS)
            assert.is_nil(parsed.error)
            local byId = {}
            for _, e in ipairs(parsed.editors) do byId[e.id] = e end
            assert.is_string(byId[PANNEAUX].error)
            assert.is_nil(byId[PANNEAUX].entries)
            assert.is_nil(byId[PROCL].error)
            assert.equal('couronnement', byId[PROCL].entries[1].id)
            assert.equal(PROCL .. '.kinds.proclamation[1]', byId[PROCL].entries[1].path)
        end)

        -- fichier hostile : bornes globales, clés jamais citées hors motif, textes bornés
        it('trop d\'ateliers ou trop de fiches d\'un genre : le fichier entier est refusé', function()
            local many = {}
            for i = 1, 3 do many['vava_x:a' .. i] = { kinds = {} } end
            assert.truthy(exchange.parse(doc(many), known, { editors = 2, perKind = 1000 }).error:find('plus de 2 ateliers', 1, true))
            local list = {}
            for i = 1, 4 do list[i] = entry('f' .. i) end
            local parsed = exchange.parse(doc({ [PANNEAUX] = { kinds = { panneau = list } } }), known, { editors = 32, perKind = 3 })
            assert.truthy(parsed.error:find('plus de 3 fiches', 1, true), parsed.error)
            assert.same({}, parsed.editors)
            assert.is_nil(exchange.parse(doc({ [PANNEAUX] = { kinds = { panneau = list } } }), known, { editors = 32, perKind = 4 }).error)
        end)

        it('une clé hors de son motif n\'est jamais citée', function()
            local hostile = '<script>' .. string.rep('x', 300)
            local parsed = exchange.parse(doc({ [hostile] = { kinds = {} } }), known, LIMITS)
            assert.is_nil(parsed.editors[1].id)
            assert.is_nil(parsed.editors[1].error:find('<script>', 1, true))
            parsed = exchange.parse(doc({ [PANNEAUX] = { kinds = { [hostile] = {} } } }), known, LIMITS)
            assert.is_nil(parsed.editors[1].error:find('<script>', 1, true))
            assert.truthy(parsed.editors[1].error:find('genre au nom invalide', 1, true))
            local bad = entry('a')
            bad[hostile] = 1
            parsed = exchange.parse(doc({ [PANNEAUX] = { kinds = { panneau = { bad } } } }), known, LIMITS)
            assert.truthy(parsed.editors[1].error:find('clé au nom invalide', 1, true), parsed.editors[1].error)
            assert.is_nil(parsed.editors[1].error:find('script', 1, true))
        end)

        it('texte d\'un refus borné à 160 octets sans briser un caractère', function()
            local longId = string.rep('a', 31) .. ':' .. string.rep('b', 32)          -- 64 octets
            local longKind = 'k' .. string.rep('é', 15)                               -- hors motif : jamais cité
            local kind = string.rep('k', 32)
            known[longId] = { stored = true, format = 1, kinds = { [kind] = true } }
            local dup = string.rep('a', 48)
            local parsed = exchange.parse(doc({ [longId] = { kinds = { [kind] = { entry(dup), entry(dup) } } } }), known, LIMITS)
            local err = parsed.editors[1].error
            assert.is_true(#err <= 160, tostring(#err))
            assert.is_not_nil(utf8.len(err))
            parsed = exchange.parse(doc({ [longId] = { kinds = { [longKind] = {} } } }), known, LIMITS)
            assert.is_nil(parsed.editors[1].error:find('é', 1, true))
        end)
    end)

    describe('plan', function()
        it('inchangée, changée, retirée → reprise, inconnue → nouvelle ; rien n\'est retiré', function()
            local entries = {
                { kind = 'panneau', id = 'a', fingerprint = 'f1' },
                { kind = 'panneau', id = 'b', fingerprint = 'f2' },
                { kind = 'panneau', id = 'c', fingerprint = 'f3' },
                { kind = 'panneau', id = 'd', fingerprint = 'f4' },
            }
            local current = {
                ['panneau|a'] = { fingerprint = 'f1' },
                ['panneau|b'] = { fingerprint = 'autre' },
                ['panneau|c'] = { retired = true },
                ['panneau|z'] = { fingerprint = 'absente du fichier' },
            }
            local plan = exchange.plan(entries, current)
            assert.equal(1, plan.unchanged)
            assert.equal(1, plan.changed)
            assert.equal(1, plan.revived)
            assert.equal(1, plan.new)
            local actions = {}
            for _, item in ipairs(plan.items) do actions[item.id] = item.action end
            assert.same({ a = 'unchanged', b = 'changed', c = 'revived', d = 'new' }, actions)
            assert.is_nil(actions.z)
            for _, item in ipairs(plan.items) do assert.not_equal('remove', item.action) end
        end)
    end)

    describe('poids d\'un export', function()
        it('data et lieu bruts additionnés avant tout décodage ; faux dès que le plafond est dépassé (C-3)', function()
            local within = exchange.budget(10)
            assert.is_true(within({ data = '{"a":1}' }))
            assert.is_true(within({ data = '{}', place = '' }))
            assert.is_false(within({ data = '{}' }))
            assert.is_false(within({}))
            assert.is_true(exchange.budget(0)({}))
        end)
    end)
end)
