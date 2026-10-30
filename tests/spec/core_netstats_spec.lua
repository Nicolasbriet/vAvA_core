local helper = require('tests.helper')

-- Compteur des envois serveur → client (server/core/netstats.lua, core 0.10.0) : fenêtre glissante d'une minute en
-- 12 cases de 5 s, temps passé en argument ; mémoire bornée (clés ; évènements détaillés par joueur, tous suivis
-- d'office depuis 0.12.0, les plus lourds gardés, le reste sous <autres>).
describe('vAvA.netstats', function()
    local netstats, counter

    local CFG = { bucketMs = 5000, buckets = 12, maxKeys = 4, playerKeys = 2 }

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
        it('tient pour chaque joueur, sans suivi à lancer, son total et son détail par évènement', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2 })
            counter:record(1000, 'vava_a', 'vava_a:y', 30, true, 1)
            local result = read(1000, { target = 1 })
            assert.same({ messages = 2, bytes = 40, latent = 1 }, result.total)
            assert.is_nil(result.watched)
            assert.equal(2, #result.events)
            assert.same({ resource = 'vava_a', label = 'vava_a:y', messages = 1, bytes = 30, latent = 1, largest = 30 },
                result.events[1])
            assert.equal('vava_a:x', result.events[2].label)
            -- seulement ce que ce joueur a reçu
            result = read(1000, { target = 2 })
            assert.equal(1, #result.events)
            assert.equal('vava_a:x', result.events[1].label)
            assert.same({ messages = 0, bytes = 0, latent = 0 }, read(1000, { target = 9 }).total)
            assert.same({}, read(1000, { target = 9 }).events)
        end)

        it('filtre le détail d’un joueur par ressource et le limite', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            counter:record(0, 'vava_b', 'vava_b:x', 50, false, 1)
            local result = read(0, { target = 1, resource = 'vava_a' })
            assert.equal(1, #result.events)
            assert.equal('vava_a:x', result.events[1].label)
            assert.equal(1, #read(0, { target = 1, limit = 1 }).events)
            assert.equal('vava_b:x', read(0, { target = 1, limit = 1 }).events[1].label)
        end)

        it('au-delà de playerKeys, un petit évènement nouveau part dans <autres> du joueur', function()
            counter:record(0, 'vava_a', 'vava_a:x', 100, false, 1)
            counter:record(0, 'vava_a', 'vava_a:y', 100, false, 1)
            counter:record(0, 'vava_b', 'vava_b:z', 10, false, 1)
            local events = read(0, { target = 1 }).events
            assert.equal(3, #events)
            assert.equal(10, find(events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL).bytes)
            assert.is_nil(find(events, 'vava_b', 'vava_b:z'))
            assert.equal(2, counter.players[1].keyCount)
            -- un autre joueur a ses propres places
            counter:record(0, 'vava_b', 'vava_b:z', 10, false, 2)
            assert.is_not_nil(find(read(0, { target = 2 }).events, 'vava_b', 'vava_b:z'))
        end)

        it('un message plus lourd que tout l’évènement le plus léger du joueur prend sa place ; le plus léger rejoint <autres>',
            function()
                counter:record(0, 'vava_a', 'vava_a:lourd', 500, false, 1)
                counter:record(0, 'vava_a', 'vava_a:leger', 20, false, 1)
                counter:record(5000, 'vava_a', 'vava_a:leger', 20, false, 1)  -- 40 o en deux cases
                counter:record(6000, 'vava_c', 'vava_c:gros', 41, true, 1)
                local events = read(6000, { target = 1 }).events
                assert.equal(3, #events)
                assert.same({ resource = 'vava_c', label = 'vava_c:gros', messages = 1, bytes = 41, latent = 1, largest = 41 },
                    find(events, 'vava_c', 'vava_c:gros'))
                assert.is_nil(find(events, 'vava_a', 'vava_a:leger'))
                -- rien n'est perdu : ses deux cases sont dans <autres>, total du joueur inchangé
                local other = find(events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL)
                assert.same({ messages = 2, bytes = 40, latent = 0, largest = 20 },
                    { messages = other.messages, bytes = other.bytes, latent = other.latent, largest = other.largest })
                assert.same({ messages = 4, bytes = 581, latent = 1 }, read(6000, { target = 1 }).total)
                assert.equal(2, counter.players[1].keyCount)
                -- un message égal à ce qu'a envoyé le plus léger ne le chasse pas
                counter:record(6000, 'vava_d', 'vava_d:pareil', 41, false, 1)
                assert.is_nil(find(read(6000, { target = 1 }).events, 'vava_d', 'vava_d:pareil'))
            end)

        it('le plus léger gardé en cache est relu avant d’écarter : un évènement devenu lourd n’est pas chassé', function()
            local c = netstats.create({ bucketMs = 5000, buckets = 12, maxKeys = 512, playerKeys = 3 })
            c:record(1000, 'r', 'r:A', 100, false, 7)
            c:record(1000, 'r', 'r:B', 2000, false, 7)
            c:record(1000, 'r', 'r:C', 2000, false, 7)
            -- D, plus petit que tout : <autres> ; le plus léger (A, 100 o) est mis en cache pour la case
            c:record(1100, 'r', 'r:D', 50, false, 7)
            -- A devient de loin le plus lourd, dans la même case
            for _ = 1, 20 do c:record(1200, 'r', 'r:A', 1000, false, 7) end
            -- E (500 o) : plus gros que l'ancien poids de A, plus petit que tout ce qui est suivi → <autres>
            c:record(1300, 'r', 'r:E', 500, false, 7)
            local result = c:read(4999, { limit = 10, target = 7 })
            assert.equal(20100, find(result.events, 'r', 'r:A').bytes)
            assert.is_nil(find(result.events, 'r', 'r:E'))
            assert.equal(550, find(result.events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL).bytes)
            -- rien de perdu : la somme des évènements vaut le total du joueur
            local sum = 0
            for _, event in ipairs(result.events) do sum = sum + event.bytes end
            assert.equal(result.total.bytes, sum)
        end)

        it('l’anneau écarté sert au nouvel évènement, vidé, même dans la ressource du plus léger', function()
            counter:record(0, 'vava_a', 'vava_a:lourd', 500, false, 1)
            counter:record(0, 'vava_b', 'vava_b:leger', 20, false, 1)
            local reused = counter.players[1].keys.vava_b['vava_b:leger']
            -- même ressource que le plus léger, dont c'était le seul évènement
            counter:record(0, 'vava_b', 'vava_b:gros', 300, false, 1)
            assert.equal(reused, counter.players[1].keys.vava_b['vava_b:gros'])
            assert.is_nil(counter.players[1].keys.vava_b['vava_b:leger'])
            assert.equal(2, counter.players[1].keyCount)
            local event = find(read(0, { target = 1 }).events, 'vava_b', 'vava_b:gros')
            assert.same({ messages = 1, bytes = 300, latent = 0, largest = 300 },
                { messages = event.messages, bytes = event.bytes, latent = event.latent, largest = event.largest })
            -- ressource nouvelle
            counter:record(0, 'vava_c', 'vava_c:enorme', 900, false, 1)
            assert.is_not_nil(counter.players[1].keys.vava_c['vava_c:enorme'])
            assert.is_nil(counter.players[1].keys.vava_b)
            assert.equal(500 + 20 + 300 + 900, read(0, { target = 1 }).total.bytes)
        end)

        it('un anneau neuf est vide et à sa taille', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, 1)
            local ring = counter.players[1].keys.vava_a['vava_a:x']
            assert.equal(60, #ring)
            assert.equal(0, ring[1])          -- case 0 remplie par cet envoi
            assert.equal(-1, ring[6])         -- les autres vides
            assert.equal(0, ring[60])
        end)

        it('total : tous les envois de la fenêtre, comme read', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2 })
            counter:record(1000, 'vava_b', 'vava_b:y', 30, true, 1)
            assert.same(read(1000).total, counter:total(1000))
            assert.same({ messages = 0, bytes = 0, latent = 0 }, counter:total(70000))
        end)

        it('l’évincé ne garde dans <autres> que ses cases encore dans la fenêtre', function()
            counter:record(55000, 'vava_a', 'vava_a:lourd', 500, false, 1)  -- encore dans la fenêtre à 60 000
            counter:record(0, 'vava_a', 'vava_a:vieux', 30, false, 1)       -- case 0, sortie à 60 000
            counter:record(55000, 'vava_a', 'vava_a:vieux', 5, false, 1)    -- case 11
            counter:record(60000, 'vava_b', 'vava_b:neuf', 6, false, 1)     -- 6 > 5 : chasse vava_a:vieux
            local events = read(60000, { target = 1 }).events
            assert.is_not_nil(find(events, 'vava_b', 'vava_b:neuf'))
            local other = find(events, netstats.OTHER_RESOURCE, netstats.OTHER_LABEL)
            assert.equal(1, other.messages)
            assert.equal(5, other.bytes)
        end)

        it('forget efface tout d’un joueur', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2 })
            counter:forget(1)
            assert.is_nil(counter.players[1])
            local result = read(0, { target = 1 })
            assert.equal(0, result.total.messages)
            assert.same({}, result.events)
            assert.equal(1, read(0, { target = 2 }).total.messages)
            -- le compteur général garde l'envoi
            assert.equal(2, read(0).total.messages)
        end)

        it('liste les joueurs donnés, du plus chargé au moins chargé, ceux sans envoi compris, bornée', function()
            counter:record(0, 'vava_a', 'vava_a:x', 10, false, { 1, 2, 3 })
            counter:record(0, 'vava_a', 'vava_a:y', 100, true, 2)
            counter:record(0, 'vava_a', 'vava_a:z', 10, false, 3)
            local list = counter:listPlayers(0, { 1, 2, 3, 4 }, 10)
            assert.same({
                { source = 2, messages = 2, bytes = 110, latent = 1 },
                { source = 3, messages = 2, bytes = 20, latent = 0 },
                { source = 1, messages = 1, bytes = 10, latent = 0 },
                { source = 4, messages = 0, bytes = 0, latent = 0 },
            }, list)
            assert.equal(2, #counter:listPlayers(0, { 1, 2, 3, 4 }, 2))
            assert.equal(2, counter:listPlayers(0, { 1, 2, 3, 4 }, 2)[1].source)
            -- à égalité : le plus petit numéro d'abord ; hors fenêtre : zéro
            assert.same({ 1, 2 }, { counter:listPlayers(60000, { 2, 1 }, 10)[1].source,
                counter:listPlayers(60000, { 2, 1 }, 10)[2].source })
            assert.same({}, counter:listPlayers(0, {}, 10))
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
