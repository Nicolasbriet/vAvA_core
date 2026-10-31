local helper = require('tests.helper')

-- Règles pures de la chaîne de dégâts (modules/vava_health/shared/chain.lua, spec T-110 § 5.2, § 7.2 et § 11.1) :
-- contrôle d'une entrée du registre, ordre d'appel, pas d'un rendu, déroulé avec invocateur et horloge injectés.
describe('vava_health chaîne de dégâts', function()
    local chain, KINDS, MAX

    local function noop() end

    local function entry(key, stage, priority, extra)
        local e = { key = key, stage = stage, priority = priority, label = key, apply = noop }
        for k, v in pairs(extra or {}) do e[k] = v end
        return e
    end

    before_each(function()
        helper.reset()
        VavaHealth = nil
        helper.loadAll({
            'modules/vava_health/shared/constants.lua',
            'modules/vava_health/config.lua',
            'modules/vava_health/shared/chain.lua',
        })
        chain = VavaHealth.chain
        KINDS = {}
        for _, kind in ipairs(VavaHealth.config.chain.kinds) do KINDS[kind] = true end
        MAX = VavaHealth.config.chain.maxAmount
    end)

    describe('ordre', function()
        it('trie par étape, puis priorité, puis clé, sans toucher la liste donnée', function()
            local given = {
                entry('m:resistance', 'resistance', 0),
                entry('z:bouclier', 'bouclier', 50),
                entry('a:bouclier', 'bouclier', 50),
                entry('m:annulation', 'annulation', 99),
                entry('m:esquive', 'esquive', nil),
                entry('m:blocage', 'blocage', 0),
                entry('m:parade', 'parade', 50),
            }
            local keys = {}
            for i, e in ipairs(given) do keys[i] = e.key end
            local sorted = chain.sort(given)
            local order = {}
            for i, e in ipairs(sorted) do order[i] = e.key end
            assert.same({ 'm:annulation', 'm:esquive', 'm:parade', 'm:blocage', 'a:bouclier', 'z:bouclier',
                'm:resistance' }, order)
            for i, e in ipairs(given) do assert.equal(keys[i], e.key) end

            -- deux tris du même ensemble, présenté autrement, donnent le même ordre
            local reversed = {}
            for i = #given, 1, -1 do reversed[#reversed + 1] = given[i] end
            local again = {}
            for i, e in ipairs(chain.sort(reversed)) do again[i] = e.key end
            assert.same(order, again)
        end)

        it('place la priorité dans l\'étape (défaut 50)', function()
            local sorted = chain.sort({
                entry('b:x', 'bouclier', 60), entry('c:x', 'bouclier', nil), entry('d:x', 'bouclier', 40),
                entry('e:x', 'esquive', 99),
            })
            assert.same({ 'e:x', 'd:x', 'c:x', 'b:x' }, { sorted[1].key, sorted[2].key, sorted[3].key, sorted[4].key })
        end)
    end)

    describe('contrôle d\'une entrée', function()
        local function check(key, changes)
            local data = { stage = 'bouclier', priority = 50, label = 'Protections', kinds = { 'feu', 'eau' }, apply = noop }
            for k, v in pairs(changes or {}) do
                if v == 'nil' then data[k] = nil else data[k] = v end
            end
            return chain.checkEntry(key, data, KINDS)
        end

        it('accepte une entrée complète, et sans priorité ni types', function()
            assert.is_true(check('vava_magic:protections'))
            assert.is_true(check('vava_magic:protections', { priority = 'nil', kinds = 'nil' }))
            assert.is_true(check('vava_magic:protections', { priority = 0 }))
            assert.is_true(check('vava_magic:protections', { priority = 99 }))
            -- référence de fonction d'une autre ressource : table appelable
            assert.is_true(check('a:b', { apply = setmetatable({}, { __call = noop }) }))
        end)

        it('refuse chaque défaut avec une raison', function()
            local cases = {
                { 'a:b', { stage = 'nil' } },
                { 'a:b', { stage = 'application' } },
                { 'a:b', { priority = -1 } },
                { 'a:b', { priority = 100 } },
                { 'a:b', { priority = 1.5 } },
                { 'a:b', { label = '' } },
                { 'a:b', { label = string.rep('x', 49) } },
                { 'a:b', { kinds = {} } },
                { 'a:b', { kinds = { 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur', 'privation', 'monde',
                    'tranchant', 'contondant', 'percant', 'feu' } } },
                { 'a:b', { kinds = { 'glace' } } },
                { 'a:b', { kinds = { 'feu', 'feu' } } },
                { 'a:b', { apply = 'nil' } },
                { 'a:b', { apply = {} } },
                { 'sans_prefixe', {} },
                { 'a:b c', {} },
                { 'é:b', {} },
            }
            for i, case in ipairs(cases) do
                local ok, reason = check(case[1], case[2])
                assert.is_false(ok, 'cas ' .. i)
                assert.is_string(reason, 'cas ' .. i)
            end
            assert.is_false((chain.checkEntry('a:b', 'x', KINDS)))
            assert.is_false((chain.checkEntry(12, {}, KINDS)))
        end)
    end)

    describe('pas d\'un rendu', function()
        local function stepOn(amount, result, base)
            local state = chain.newState(base or amount)
            state.amount = amount
            local ok, code = chain.step(state, result, 'blocage', MAX)
            return state, ok, code
        end

        it('ne change rien pour nil et true', function()
            for _, result in ipairs({ true }) do
                local state, ok = stepOn(12, result)
                assert.is_true(ok)
                assert.equal(12, state.amount)
            end
            local state, ok = stepOn(12, nil)
            assert.is_true(ok)
            assert.equal(12, state.amount)
        end)

        it('retire blocked, absorbed, resisted au plus le montant courant', function()
            local state = stepOn(12, { blocked = 3 })
            assert.equal(9, state.amount)
            assert.equal(3, state.blocked)
            state = stepOn(12, { blocked = 50 })
            assert.equal(0, state.amount)
            assert.equal(12, state.blocked)
            state = stepOn(12, { blocked = 2, absorbed = 3 })
            assert.equal(7, state.amount)
            assert.equal(2, state.blocked)
            assert.equal(3, state.absorbed)
            state = stepOn(12, { resisted = 5 })
            assert.equal(7, state.amount)
            assert.equal(5, state.resisted)
        end)

        it('ignore tout un rendu invalide', function()
            for i, result in ipairs({ { absorbed = -1 }, { resisted = 0 / 0 }, 'x', 5, { blocked = 2, added = math.huge },
                { blocked = '3' } }) do
                local state, ok, code = stepOn(12, result)
                assert.is_false(ok, 'cas ' .. i)
                assert.equal('invalid_result', code, 'cas ' .. i)
                assert.equal(12, state.amount, 'cas ' .. i)
                assert.equal(0, state.blocked, 'cas ' .. i)
            end
        end)

        it('annule : montant à 0, raison et étape notées, le reste ignoré', function()
            local state = stepOn(12, { cancel = 'esquive' })
            assert.equal(0, state.amount)
            assert.equal('esquive', state.cancelled)
            assert.equal('blocage', state.stage)
            for _, reason in ipairs({ string.rep('trop_long', 5), 'a b', 'é', true, 3 }) do
                assert.equal('cancelled', stepOn(12, { cancel = reason }).cancelled, tostring(reason))
            end
            state = stepOn(12, { cancel = 'x', blocked = 3 })
            assert.equal('x', state.cancelled)
            assert.equal(0, state.blocked)
        end)

        it('ajoute au plus la base par rendu, total au plus maxAmount', function()
            local state = stepOn(10, { added = 30 }, 10)
            assert.equal(20, state.amount)
            assert.equal(10, state.added)
            state = stepOn(150, { added = 150 }, 150)
            assert.equal(MAX, state.amount)
            assert.equal(50, state.added)
        end)
    end)

    describe('déroulé', function()
        local calls, clock, slow, errors

        local function options(costs)
            return {
                maxAmount = MAX, slowMs = 5,
                clock = function() return clock end,
                invoke = function(e, ctx)
                    calls[#calls + 1] = { key = e.key, amount = ctx.amount, stage = ctx.stage }
                    clock = clock + ((costs or {})[e.key] or 0)
                    return pcall(e.apply, ctx)
                end,
                onError = function(e, err) errors[#errors + 1] = { key = e.key, err = err } end,
                onSlow = function(e, ms) slow[#slow + 1] = { key = e.key, ms = ms } end,
            }
        end

        before_each(function()
            calls, clock, slow, errors = {}, 1000, {}, {}
        end)

        local function list(results)
            local out = {}
            for i, stage in ipairs(VavaHealth.STAGES) do
                local result = results[stage]
                out[i] = entry('m:' .. stage, stage, 50, { apply = function()
                    if type(result) == 'function' then return result() end
                    return result
                end })
            end
            return chain.sort(out)
        end

        it('appelle chaque modificateur dans l\'ordre, avec le montant laissé par le précédent', function()
            local state = chain.run(list({ blocage = { blocked = 2 }, bouclier = { absorbed = 4 } }),
                { kind = 'tranchant', amount = 12 }, chain.newState(12), options())
            assert.equal(6, #calls)
            local expected = { 12, 12, 12, 12, 10, 6 }
            for i, call in ipairs(calls) do
                assert.equal(VavaHealth.STAGES[i], call.stage)
                assert.equal(expected[i], call.amount)
            end
            assert.equal(6, state.amount)
        end)

        it('s\'arrête à la première annulation', function()
            local state = chain.run(list({ parade = { cancel = 'parade' } }), { kind = 'tranchant' }, chain.newState(12),
                options())
            assert.same({ 'm:annulation', 'm:esquive', 'm:parade' }, { calls[1].key, calls[2].key, calls[3].key })
            assert.equal(3, #calls)
            assert.equal('parade', state.cancelled)
            assert.equal('parade', state.stage)
            assert.equal(0, state.amount)
        end)

        it('ignore un modificateur en erreur et appelle les suivants', function()
            local state = chain.run(list({ blocage = function() error('panne') end, bouclier = { absorbed = 2 } }),
                { kind = 'tranchant' }, chain.newState(12), options())
            assert.equal(6, #calls)
            assert.equal(1, #errors)
            assert.equal('m:blocage', errors[1].key)
            assert.equal(10, state.amount)
        end)

        it('n\'appelle un modificateur à types que pour ces types', function()
            local only = { entry('m:feu', 'resistance', 50, { kinds = { feu = true }, apply = function() return { resisted = 1 } end }) }
            local state = chain.run(only, { kind = 'tranchant' }, chain.newState(12), options())
            assert.equal(0, #calls)
            assert.equal(12, state.amount)
            state = chain.run(only, { kind = 'feu' }, chain.newState(12), options())
            assert.equal(1, #calls)
            assert.equal(11, state.amount)
        end)

        it('signale un appel lent sans couper le coup', function()
            local state = chain.run(list({ blocage = { blocked = 1 } }), { kind = 'tranchant' }, chain.newState(12),
                options({ ['m:blocage'] = 6, ['m:esquive'] = 5 }))
            assert.equal(1, #slow)
            assert.equal('m:blocage', slow[1].key)
            assert.equal(6, slow[1].ms)
            assert.equal(6, #calls)
            assert.equal(11, state.amount)
        end)

        it('suit les exemples de COMBAT_V1.md', function()
            local state = chain.run(list({ blocage = { blocked = 3 } }), { kind = 'tranchant' }, chain.newState(12), options())
            assert.equal(9, state.amount)
            assert.equal(3, state.blocked)
            assert.equal(0, state.absorbed)

            local reserve = 20
            local shieldAndResistance = chain.sort({
                entry('m:resistance', 'resistance', 50, { apply = function(ctx) return { resisted = ctx.amount * 0.4 } end }),
                entry('m:bouclier', 'bouclier', 50, { apply = function(ctx)
                    local taken = math.min(reserve, ctx.amount)
                    reserve = reserve - taken
                    return { absorbed = taken }
                end }),
            })
            state = chain.run(shieldAndResistance, { kind = 'feu' }, chain.newState(60), options())
            assert.equal(20, state.absorbed)
            assert.equal(16, state.resisted)
            assert.equal(24, state.amount)
        end)
    end)

    describe('source à terre (1.4.0)', function()
        local MAX_MS = 4000

        it('un effet qui dure et un renvoi passent toujours ; un coup simple, jamais', function()
            assert.is_true(chain.passesDownedSource({ overTime = true }, nil, nil, 1000, MAX_MS))
            assert.is_true(chain.passesDownedSource({ reflected = true }, nil, 500, 1000, MAX_MS))
            assert.is_false(chain.passesDownedSource({ spell = true, ranged = true }, nil, 500, 1000, MAX_MS))
            assert.is_false(chain.passesDownedSource({}, 900, 950, 1000, MAX_MS))
        end)

        it('lancé debout puis la source tombe : porte, dans le délai', function()
            assert.is_true(chain.passesDownedSource({ launched = true }, 10000, 10500, 11200, MAX_MS))
            assert.is_true(chain.passesDownedSource({ launched = true }, 10000, 10001, 14000, MAX_MS))
        end)

        it('lancé à terre, ou mise à terre inconnue : refusé', function()
            assert.is_false(chain.passesDownedSource({ launched = true }, 10000, 9000, 10500, MAX_MS))
            assert.is_false(chain.passesDownedSource({ launched = true }, 10000, 10000, 10500, MAX_MS))
            assert.is_false(chain.passesDownedSource({ launched = true }, 10000, nil, 10500, MAX_MS))
        end)

        it('délai dépassé, instant dans le futur ou absent : refusé', function()
            assert.is_false(chain.passesDownedSource({ launched = true }, 10000, 10500, 14001, MAX_MS))
            assert.is_false(chain.passesDownedSource({ launched = true }, 12000, 12500, 11000, MAX_MS))
            assert.is_false(chain.passesDownedSource({ launched = true }, nil, 10500, 11000, MAX_MS))
            assert.is_false(chain.passesDownedSource({ launched = true }, 10000.5, 10500, 11000, MAX_MS))
        end)
    end)
end)
