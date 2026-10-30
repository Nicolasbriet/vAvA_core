local helper = require('tests.helper')

-- Compteur des envois serveur → client (server/core/netstats.lua, core 0.10.0) : fenêtre glissante d'une minute en
-- 12 cases de 5 s, temps passé en argument ; mémoire bornée (clés, joueurs suivis, clés par joueur suivi).
describe('vAvA.netstats', function()
    local netstats, counter

    local CFG = { bucketMs = 5000, buckets = 12, maxKeys = 4, maxWatched = 2, maxWatchedKeys = 2, watchMs = 300000 }

    before_each(function()
        helper.reset()
        helper.loadAll({ 'shared/init.lua', 'server/core/netstats.lua' })
        netstats = vAvA.netstats
        counter = netstats.create(CFG)
    end)

    local function read(now, options)
        options = options or {}
        options.limit = options.limit or 50
        return counter:read(now, options)
    end

    local function find(events, resource, label)
        for _, event in ipairs(events) do
            if event.resource == resource and event.label == label then return event end
        end
        return nil
    end

    describe('fenêtre', function()
        it('garde un envoi une minute : lu à 0 et à 59 999 ms, absent à 60 000 ms', function()
            counter:record(0, 'vava_a', 'vava_a:x', 100, false, 1)
            assert.equal(1, read(0).total.messages)
            assert.equal(1, read(59999).total.messages)
            assert.equal(0, read(60000).total.messages)
            assert.same({}, read(60000).events)
            assert.equal(60000, read(0).windowMs)
        end)

        it('remet à zéro une case réutilisée après un tour, sans additionner l’ancien contenu', function()
            counter:record(1000, 'vava_a', 'vava_a:x', 100, false, 1)
            counter:record(61000, 'vava_a', 'vava_a:x', 10, false, 1)   -- même case, un tour plus tard
            local event = read(61000).events[1]
            assert.equal(1, event.messages)
            assert.equal(10, event.bytes)
            assert.equal(10, event.largest)
        end)

        it('additionne les cases de la fenêtre ; le plus gros est celui de la fenêtre, pas d’une case', function()
            counter:record(0, 'vava_a', 'vava_a:x', 900, true, 1)
            counter:record(6000, 'vava_a', 'vava_a:x', 100, false, { 1, 2, 3 })
            local event = read(10000).events[1]
            assert.equal(4, event.messages)
            assert.equal(900 + 3 * 100, event.bytes)
            assert.equal(1, event.latent)
            assert.equal(900, event.largest)
            -- le message de 900 octets sort de la fenêtre : le plus gros redevient 100
            event = read(60000).events[1]
            assert.equal(3, event.messages)
            assert.equal(100, event.largest)
        end)
    end)

    describe('lecture', function()
        it('trie par octets décroissants, puis messages, puis ressource et évènement', function()
            counter:record(0, 'vava_b', 'vava_b:x', 10, false, { 1, 2 })   -- 20 o, 2 messages
            counter:record(0, 'vava_a', 'vava_a:y', 20, false, 1)          -- 20 o, 1 message
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2 })   -- 20 o, 2 messages
            counter:record(0, 'vava_c', 'vava_c:z', 500, false, 1)
            local events = read(0).events
            assert.equal('vava_c:z', events[1].label)
            assert.equal('vava_a:x', events[2].label)
            assert.equal('vava_b:x', events[3].label)
            assert.equal('vava_a:y', events[4].label)
        end)

        it('limite le nombre d’évènements et filtre par ressource (total de la ressource)', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            counter:record(0, 'vava_a', 'vava_a:y', 30, true, 1)
            counter:record(0, 'vava_b', 'vava_b:x', 50, false, 1)
            local result = read(0, { limit = 1 })
            assert.equal(1, #result.events)
            assert.equal('vava_b:x', result.events[1].label)
            assert.same({ messages = 3, bytes = 90, latent = 1 }, result.total)
            result = read(0, { resource = 'vava_a' })
            assert.equal(2, #result.events)
            assert.same({ messages = 2, bytes = 40, latent = 1 }, result.total)
        end)

        it('rend des tables à clés nommées et des listes pures (traversée d’export)', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            local event = read(0).events[1]
            assert.same({ resource = 'vava_a', label = 'vava_a:x', messages = 1, bytes = 10, latent = 0, largest = 10 }, event)
        end)
    end)

    describe('bornes', function()
        it('au-delà de maxKeys, une nouvelle clé part dans (*, <autres>) et les clés existantes continuent', function()
            for i = 1, 4 do counter:record(0, 'vava_a', 'vava_a:e' .. i, 10, false, 1) end
            counter:record(0, 'vava_b', 'vava_b:nouveau', 10, false, 1)
            counter:record(0, 'vava_c', 'vava_c:autre', 10, false, 1)
            counter:record(0, 'vava_a', 'vava_a:e1', 10, false, 1)
            local events = read(0).events
            assert.equal(5, #events)
            assert.equal(2, find(events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL).messages)
            assert.equal(2, find(events, 'vava_a', 'vava_a:e1').messages)
            assert.is_nil(find(events, 'vava_b', 'vava_b:nouveau'))
        end)
    end)

    describe('joueurs', function()
        it('tient les totaux par joueur ; le détail seulement pour un joueur suivi', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2 })
            local result = read(0, { target = 1 })
            assert.same({ messages = 1, bytes = 10, latent = 0 }, result.total)
            assert.is_false(result.watched)
            assert.same({}, result.events)
            assert.same({ true, 'started' }, { counter:watch(0, 1) })
            assert.same({ true, 'already' }, { counter:watch(0, 1) })
            counter:record(1000, 'vava_a', 'vava_a:y', 30, true, 1)
            result = read(1000, { target = 1 })
            assert.is_true(result.watched)
            assert.same({ messages = 2, bytes = 40, latent = 1 }, result.total)
            assert.equal(1, #result.events)   -- seul ce qui est arrivé depuis le début du suivi
            assert.equal('vava_a:y', result.events[1].label)
            assert.same({ messages = 0, bytes = 0, latent = 0 }, read(1000, { target = 9 }).total)
        end)

        it('refuse un suivi au-delà de maxWatched ; un suivi expire après watchMs', function()
            assert.is_true(counter:watch(0, 1))
            assert.is_true(counter:watch(0, 2))
            assert.same({ false, 'full' }, { counter:watch(0, 3) })
            assert.is_false(counter:isWatched(300000, 1))
            assert.same({ true, 'started' }, { counter:watch(300000, 3) })
        end)

        it('au-delà de maxWatchedKeys, les évènements du joueur suivi partent dans <autres>', function()
            counter:watch(0, 1)
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            counter:record(0, 'vava_a', 'vava_a:y', 10, false, 1)
            counter:record(0, 'vava_b', 'vava_b:z', 10, false, 1)
            local events = read(0, { target = 1 }).events
            assert.equal(3, #events)
            assert.is_not_nil(find(events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL))
        end)

        it('forget efface les totaux et le suivi d’un joueur', function()
            counter:watch(0, 1)
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            counter:forget(1)
            local result = read(0, { target = 1 })
            assert.equal(0, result.total.messages)
            assert.is_false(result.watched)
            -- la place du suivi est rendue
            assert.is_true(counter:watch(0, 2))
            assert.is_true(counter:watch(0, 3))
        end)
    end)

    describe('ménage', function()
        it('retire les clés sans envoi depuis une fenêtre, et rien d’autre', function()
            counter:record(0, 'vava_a', 'vava_a:vieux', 10, false, 1)
            counter:record(30000, 'vava_a', 'vava_a:recent', 10, false, 2)
            counter:sweep(60000)
            assert.is_nil(counter.keys.vava_a['vava_a:vieux'])
            assert.is_not_nil(counter.keys.vava_a['vava_a:recent'])
            assert.equal(1, counter.keyCount)
            assert.is_nil(counter.players[1])
            assert.is_not_nil(counter.players[2])
            assert.equal(1, read(60000).total.messages)
            -- la place libérée sert à une nouvelle clé
            for i = 1, 3 do counter:record(60000, 'vava_b', 'vava_b:e' .. i, 10, false, 1) end
            assert.is_nil(find(read(60000).events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL))
        end)
    end)

    it('écrit une taille à la française', function()
        assert.equal('512 o', netstats.formatBytes(512))
        assert.equal('1,0 Ko', netstats.formatBytes(1024))
        assert.equal('240,0 Ko', netstats.formatBytes(245760))
        assert.equal('1,50 Mo', netstats.formatBytes(1572864))
    end)
end)
