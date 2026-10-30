local helper = require('tests.helper')

-- SetTimeout, promise.new et Citizen.Await sont des doublures de tests/helper.lua : une minuterie ne part que
-- lorsque le test appelle helper.timers[i].fn(), et attendre une promesse non résolue est une erreur.
describe('vAvA.lib.pending', function()
    local pending

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'shared/lib/pending.lua' })
        pending = vAvA.lib.pending
    end)

    it('attribue des identifiants croissants à partir de 1 et garde la méta de l’appelant', function()
        local store = pending.create(8, 100)
        local meta = { source = 12 }
        local id1, entry1 = store:add(meta, 1000)
        local id2 = store:add({}, 1000)
        local id3 = store:add({}, 1000)
        assert.same({ 1, 2, 3 }, { id1, id2, id3 })
        assert.equal(3, store.size)
        assert.equal(entry1, store:get(id1))
        assert.equal(meta, store:get(id1).meta)
    end)

    it('refuse une requête de plus quand maxPending est atteint, puis l’accepte après une résolution', function()
        local store = pending.create(2, 100)
        assert.is_not_nil(store:add({}, 1000))
        assert.is_not_nil(store:add({}, 1000))
        local id, entry = store:add({}, 1000)
        assert.is_nil(id)
        assert.is_nil(entry)
        assert.equal(2, store.size)
        store:settle(1, true)
        assert.is_not_nil(store:add({}, 1000))
    end)

    it('résout une seule fois et retire l’entrée', function()
        local store = pending.create(8, 100)
        local id, entry = store:add({}, 1000)
        assert.is_true(store:settle(id, true, 'ok'))
        assert.is_false(store:settle(id, true, 'encore'))
        assert.is_nil(store:get(id))
        assert.equal(0, store.size)
        local ok, value = pending.await(entry)
        assert.is_true(ok)
        assert.equal('ok', value)
    end)

    it('rend les valeurs telles quelles, nil intermédiaires et finaux compris', function()
        local store = pending.create(8, 100)
        local id, entry = store:add({}, 1000)
        store:settle(id, true, nil, 3, nil)
        local results = table.pack(pending.await(entry))
        assert.equal(4, results.n)
        assert.same({ n = 4, true, nil, 3, nil }, results)
    end)

    it('ignore un identifiant inconnu', function()
        local store = pending.create(8, 100)
        store:add({}, 1000)
        assert.is_false(store:settle(999, true))
        assert.is_false(store:settle(nil, true))
        assert.equal(1, store.size)
    end)

    it('résout par (false, « timeout ») quand personne ne répond à temps', function()
        local store = pending.create(8, 100)
        local id, entry = store:add({}, 5000)
        assert.equal(1, #helper.timers)
        assert.equal(5000, helper.timers[1].ms)
        helper.timers[1].fn()
        assert.is_nil(store:get(id))
        assert.equal(0, store.size)
        local ok, reason = pending.await(entry)
        assert.is_false(ok)
        assert.equal('timeout', reason)
    end)

    it('une minuterie après une réponse ne fait rien', function()
        local store = pending.create(8, 100)
        local id, entry = store:add({}, 5000)
        store:settle(id, true, 'réponse')
        helper.timers[1].fn()
        assert.equal(0, store.size)
        local ok, value = pending.await(entry)
        assert.is_true(ok)
        assert.equal('réponse', value)
    end)

    it('une minuterie périmée ne résout pas la requête qui a repris le même identifiant', function()
        local store = pending.create(1, 1)
        local first = store:add({ n = 1 }, 1000)
        store:settle(first, true)
        local second, entry = store:add({ n = 2 }, 1000)
        assert.equal(first, second)
        helper.timers[1].fn() -- minuterie de la première requête
        assert.equal(entry, store:get(second))
        assert.equal(1, store.size)
        helper.timers[2].fn() -- la sienne
        assert.is_nil(store:get(second))
    end)

    it('reboucle après maxId en sautant les identifiants encore occupés', function()
        local store = pending.create(3, 3)
        store:add({}, 1000) -- 1
        store:add({}, 1000) -- 2
        store:add({}, 1000) -- 3
        store:settle(2, true)
        assert.equal(2, store:add({}, 1000))
    end)

    it('settleWhere résout les requêtes dont la méta correspond et rend leur nombre', function()
        local store = pending.create(8, 100)
        local _, a = store:add({ source = 1 }, 1000)
        local idB = store:add({ source = 2 }, 1000)
        local _, c = store:add({ source = 1 }, 1000)
        local count = store:settleWhere(function(meta) return meta.source == 1 end, false, 'player_dropped')
        assert.equal(2, count)
        assert.equal(1, store.size)
        assert.is_not_nil(store:get(idB))
        assert.same({ false, 'player_dropped' }, { pending.await(a) })
        assert.same({ false, 'player_dropped' }, { pending.await(c) })
    end)

    it('settleWhere ne résout rien quand aucune méta ne correspond', function()
        local store = pending.create(8, 100)
        store:add({ source = 1 }, 1000)
        assert.equal(0, store:settleWhere(function() return false end, false, 'x'))
        assert.equal(1, store.size)
    end)

    -- 0.10.0 : réponse annoncée en latent (préavis), demande serveur → client partie en latent
    describe('extend', function()
        local now

        before_each(function()
            now = 0
            -- horloge réglée par le test : pending.lua la garde en local à son chargement
            _G.GetGameTimer = function() return now end
            helper.load('shared/lib/pending.lua')
            pending = vAvA.lib.pending
        end)

        it('repousse l’échéance : la première minuterie ne résout plus rien, la seconde résout timeout', function()
            local store = pending.create(8, 100)
            local id, entry = store:add({}, 1000)
            now = 500
            assert.is_true(store:extend(id, 3000))
            assert.equal(2, #helper.timers)
            assert.equal(3000, helper.timers[2].ms)
            helper.timers[1].fn()
            assert.equal(entry, store:get(id))
            helper.timers[2].fn()
            assert.is_nil(store:get(id))
            assert.same({ false, 'timeout' }, { pending.await(entry) })
        end)

        it('une échéance plus proche que l’actuelle ne raccourcit rien', function()
            local store = pending.create(8, 100)
            local id, entry = store:add({}, 5000)
            now = 1000
            assert.is_true(store:extend(id, 2000))   -- 3 000 < 5 000 : rien ne change
            assert.equal(1, #helper.timers)
            helper.timers[1].fn()
            assert.same({ false, 'timeout' }, { pending.await(entry) })
        end)

        it('deux allongements : seule la dernière minuterie résout', function()
            local store = pending.create(8, 100)
            local id = store:add({}, 1000)
            store:extend(id, 2000)
            store:extend(id, 4000)
            helper.timers[2].fn()
            assert.is_not_nil(store:get(id))
            helper.timers[3].fn()
            assert.is_nil(store:get(id))
        end)

        it('un identifiant inconnu ou déjà résolu rend false', function()
            local store = pending.create(8, 100)
            assert.is_false(store:extend(42, 1000))
            local id = store:add({}, 1000)
            store:settle(id, true)
            assert.is_false(store:extend(id, 1000))
            assert.equal(1, #helper.timers)
        end)
    end)
end)
