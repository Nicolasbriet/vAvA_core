local helper = require('tests.helper')

-- État d'une zone (server/core/zonestate.lua, core 0.11.0, T-014) : clés, valeurs, bornes, différences regroupées,
-- révisions, tailles et budget commun. Tout ou rien à chaque opération.
describe('vAvA.zonestate', function()
    local zonestate, budget, limits

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'server/core/netsize.lua', 'server/core/zonestate.lua' })
        zonestate = vAvA.zonestate
        limits = { maxKeys = 256, keyMaxLength = 48, maxChanges = 64, maxValueBytes = 4096, maxStateBytes = 32768 }
        budget = zonestate.budget(8388608)
    end)

    local function fresh()
        return zonestate.new(limits, budget)
    end

    describe('load', function()
        it('révision 1, état gardé, tailles comptées', function()
            local zone = fresh()
            assert.is_true(zone:load({ a = 1, b = 'deux' }))
            assert.equal(1, zone.revision)
            assert.same({ a = 1, b = 'deux' }, zone.state)
            assert.equal(2, zone.keys)
            assert.is_true(zone.bytes > 0)
            assert.equal(zone.bytes, budget.used)
            assert.is_false(zone:hasPending())
            assert.is_true(fresh():load(nil))
        end)

        it('refuse les clés invalides', function()
            for _, state in ipairs({ { [''] = 1 }, { [string.rep('a', 49)] = 1 }, { ['a b'] = 1 }, { [1] = 1 },
                { 'liste' }, { [true] = 1 } }) do
                assert.same({ false, 'invalid_key' }, { fresh():load(state) })
            end
            assert.is_true(fresh():load({ [string.rep('a', 48)] = 1, ['n:chene_1'] = 2, ['a.b-c'] = 3 }))
            assert.same({ false, 'invalid_value' }, { fresh():load('état') })
        end)

        it('refuse une fonction, un cycle ou une valeur trop profonde', function()
            assert.same({ false, 'invalid_value' }, { fresh():load({ a = function() end }) })
            local loop = {}
            loop.self = loop
            assert.same({ false, 'invalid_value' }, { fresh():load({ a = loop }) })
            local deep = {}
            local node = deep
            for _ = 1, 40 do
                node.next = {}
                node = node.next
            end
            assert.same({ false, 'invalid_value' }, { fresh():load({ a = deep }) })
        end)

        it('valeur de 4 097 octets estimés : too_large ; 4 096 : acceptée', function()
            -- chaîne de 4 093 caractères : 3 octets d'en-tête (str16) → 4 096
            assert.is_true(fresh():load({ a = string.rep('x', 4093) }))
            assert.same({ false, 'too_large' }, { fresh():load({ a = string.rep('x', 4094) }) })
        end)

        it('257 clés : too_many_keys ; état de plus de 32 768 octets : too_large', function()
            local many = {}
            for i = 1, 257 do many['k' .. i] = i end
            assert.same({ false, 'too_many_keys' }, { fresh():load(many) })
            many.k257 = nil
            assert.is_true(fresh():load(many))
            local big = {}
            for i = 1, 9 do big['k' .. i] = string.rep('x', 4000) end
            assert.same({ false, 'too_large' }, { fresh():load(big) })
        end)
    end)

    describe('set et flush', function()
        it('set puis flush : révision 2, valeurs et retraits attendus', function()
            local zone = fresh()
            zone:load({ a = 1, b = 2, c = 3 })
            assert.same({ true, nil, true }, { zone:set({ a = 10, d = 'nouveau' }, { 'c' }) })
            assert.same({ a = 10, b = 2, d = 'nouveau' }, zone.state)
            local diff = zone:flush()
            assert.equal(2, diff.revision)
            assert.same({ a = 10, d = 'nouveau' }, diff.set)
            assert.same({ 'c' }, diff.removed)
            assert.is_true(diff.bytes > 0)
            assert.equal(2, zone.revision)
            assert.is_nil(zone:flush())
            assert.equal(2, zone.revision)
        end)

        it('une clé changée puis retirée dans le même tour n’est que retirée, et l’inverse', function()
            local zone = fresh()
            zone:load({ a = 1, b = 2 })
            zone:set({ a = 5 })
            zone:set(nil, { 'a' })
            zone:set(nil, { 'b' })
            zone:set({ b = 7 })
            local diff = zone:flush()
            assert.same({ 'a' }, diff.removed)
            assert.same({ b = 7 }, diff.set)
        end)

        it('valeur scalaire identique : rien en attente ; table identique : en attente', function()
            local zone = fresh()
            zone:load({ a = 1, t = { x = 1 } })
            assert.same({ true, nil, false }, { zone:set({ a = 1 }) })
            assert.is_false(zone:hasPending())
            assert.is_nil(zone:flush())
            assert.same({ true, nil, true }, { zone:set({ t = { x = 1 } }) })
            assert.same({ t = { x = 1 } }, zone:flush().set)
        end)

        it('retirer une clé absente ne met rien en attente', function()
            local zone = fresh()
            zone:load({ a = 1 })
            assert.same({ true, nil, false }, { zone:set(nil, { 'z' }) })
            assert.is_nil(zone:flush())
        end)

        it('65 clés en un appel : refus, rien d’appliqué (tout ou rien)', function()
            local zone = fresh()
            zone:load({ a = 1 })
            local changes = {}
            for i = 1, 65 do changes['k' .. i] = i end
            assert.same({ false, 'too_many_keys' }, { zone:set(changes) })
            assert.same({ a = 1 }, zone.state)
            assert.is_false(zone:hasPending())
            -- 60 changées et 5 retirées : 65 aussi
            changes.k65, changes.k64, changes.k63, changes.k62, changes.k61 = nil, nil, nil, nil, nil
            assert.same({ false, 'too_many_keys' }, { zone:set(changes, { 'a', 'b', 'c', 'd', 'e' }) })
            assert.same({ a = 1 }, zone.state)
        end)

        it('un élément refusé : rien d’appliqué', function()
            local zone = fresh()
            zone:load({ a = 1, b = 2 })
            local before = zone.bytes
            assert.same({ false, 'invalid_value' }, { zone:set({ a = 2, c = function() end }) })
            assert.same({ false, 'invalid_key' }, { zone:set({ a = 2 }, { 'b', 'mauvaise clé' }) })
            assert.same({ false, 'invalid_key' }, { zone:set({ a = 2 }, { 'a' }) })
            assert.same({ false, 'invalid_key' }, { zone:set(nil, { b = true }) })
            assert.same({ false, 'invalid_key' }, { zone:set({ [3] = 1 }) })
            assert.same({ false, 'too_large' }, { zone:set({ a = string.rep('x', 5000) }) })
            assert.same({ a = 1, b = 2 }, zone.state)
            assert.equal(before, zone.bytes)
            assert.equal(before, budget.used)
            assert.is_false(zone:hasPending())
        end)

        it('tient la taille et le nombre de clés à jour, et le budget commun', function()
            local zone = fresh()
            zone:load({ a = 'x' })
            local small = zone.bytes
            zone:set({ a = string.rep('x', 100) })
            -- au-delà de 31 caractères, l'en-tête de la chaîne passe de 1 à 2 octets
            assert.equal(small + 100, zone.bytes)
            zone:set({ b = 1 })
            assert.equal(2, zone.keys)
            zone:set(nil, { 'a', 'a' })
            assert.equal(1, zone.keys)
            assert.equal(#'b' + 1 + 1, zone.bytes)
            assert.equal(zone.bytes, budget.used)
            local other = fresh()
            other:load({ c = 'abc' })
            assert.equal(zone.bytes + other.bytes, budget.used)
            other:release()
            assert.equal(zone.bytes, budget.used)
        end)

        it('257e clé ou état au-delà de 32 Ko par set : refus', function()
            local zone = fresh()
            local many = {}
            for i = 1, 256 do many['k' .. i] = i end
            zone:load(many)
            assert.same({ false, 'too_many_keys' }, { zone:set({ extra = 1 }) })
            -- remplacer une clé existante reste permis
            assert.is_true(zone:set({ k1 = 2 }))
            -- une retirée, une ajoutée : 256
            assert.is_true(zone:set({ extra = 1 }, { 'k2' }))
            local big = fresh()
            local changes = {}
            for i = 1, 8 do changes['k' .. i] = string.rep('x', 4000) end
            assert.is_true(big:set(changes))
            assert.same({ false, 'too_large' }, { big:set({ k9 = string.rep('x', 4000) }) })
        end)

        it('budget global dépassé : full, rien d’appliqué', function()
            budget = zonestate.budget(200)
            local zone = fresh()
            assert.is_true(zone:load({ a = string.rep('x', 100) }))
            local other = fresh()
            assert.same({ false, 'full' }, { other:load({ b = string.rep('x', 100) }) })
            assert.same({ false, 'full' }, { zone:set({ c = string.rep('x', 100) }) })
            assert.is_nil(zone.state.c)
            -- remplacer par plus petit libère de la place
            assert.is_true(zone:set({ a = 'x' }))
            assert.is_true(other:load({ b = string.rep('x', 100) }))
        end)

        it('flush rend la taille de la différence regroupée', function()
            local zone = fresh()
            zone:load({})
            zone:set({ a = string.rep('x', 4000) })
            zone:set({ b = string.rep('x', 4000) })
            zone:set({ c = string.rep('x', 4000) })
            local diff = zone:flush()
            assert.is_true(diff.bytes > 12000)
            assert.is_true(diff.bytes < 12100)
        end)
    end)

    describe('replace', function()
        it('changements en attente oubliés, révision + 1, ancien état remplacé entièrement', function()
            local zone = fresh()
            zone:load({ a = 1, b = 2 })
            zone:set({ a = 3 })
            assert.is_true(zone:replace({ c = 4 }))
            assert.equal(2, zone.revision)
            assert.same({ c = 4 }, zone.state)
            assert.is_false(zone:hasPending())
            assert.is_nil(zone:flush())
            assert.equal(zone.bytes, budget.used)
            assert.same({ false, 'invalid_key' }, { zone:replace({ ['x y'] = 1 }) })
            assert.same({ c = 4 }, zone.state)
            assert.equal(2, zone.revision)
        end)

        it('l’état gardé est une copie : la table donnée peut changer ensuite', function()
            local zone = fresh()
            local given = { a = 1 }
            zone:load(given)
            given.a = 2
            assert.equal(1, zone.state.a)
        end)
    end)
end)
