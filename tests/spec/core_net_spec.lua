local helper = require('tests.helper')

-- Envois serveur → client du core (server/core/net.lua, core 0.10.0), au regard de la section « core.net » de
-- docs/api.md : cibles (jamais -1), préfixe de l'évènement, nombre de valeurs, seuil du latent, taille maximale,
-- volume latent en route par joueur, joueurs proches (positions lues côté serveur), compteur.
-- D'abord en estimation (pas de msgpack.pack_args hors jeu), puis en mesure exacte avec des doublures des fonctions
-- internes du runtime. Toutes les natives sont des doublures.
describe('vAvA.net', function()
    local net, now, sent, printed, existing, peds, positions, buckets, characters, realPrint
    local packCalls, packError, internalSent

    local OWNER = 'vava_test'

    before_each(function()
        helper.reset()
        now = 0
        sent, printed, internalSent = {}, {}, {}
        packCalls, packError = 0, false
        existing = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true }
        peds, positions, buckets, characters = {}, {}, {}, {}
        realPrint = _G.print
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        _G.GetGameTimer = function() return now end
        _G.DoesPlayerExist = function(src) return existing[src] == true end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function(ped) return positions[ped] end
        _G.GetPlayerRoutingBucket = function(src) return buckets[src] or 0 end
        _G.TriggerClientEvent = function(event, target, ...)
            sent[#sent + 1] = { event = event, target = target, latent = false, args = table.pack(...) }
        end
        _G.TriggerLatentClientEvent = function(event, target, rate, ...)
            sent[#sent + 1] = { event = event, target = target, latent = true, rate = rate, args = table.pack(...) }
        end
        _G.msgpack = nil
        _G.TriggerClientEventInternal = nil
        _G.TriggerLatentClientEventInternal = nil
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/string.lua',
            'shared/core/logger.lua',
            'config/server.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
        })
        net = vAvA.net
        vAvA.characters = {
            forEachActive = function(fn)
                for _, character in ipairs(characters) do fn(character) end
            end,
        }
        vAvA.sync = { isCurrent = function(character) return character.current ~= false end }
    end)

    after_each(function()
        _G.print = realPrint
        _G.msgpack = nil
        _G.TriggerClientEventInternal = nil
        _G.TriggerLatentClientEventInternal = nil
    end)

    --- Joueur dont le personnage est apparu, ped à (x, y, z).
    local function place(src, x, y, z, extra)
        local ped = 100 + src
        peds[src], positions[ped] = ped, { x = x, y = y, z = z }
        local character = { source = src, spawned = true }
        for key, value in pairs(extra or {}) do character[key] = value end
        characters[#characters + 1] = character
    end

    --- Chaîne qui donne un message de `bytes` octets en estimation (une valeur, chaîne de 256 à 65 535 octets).
    local function payloadFor(event, bytes)
        return string.rep('x', bytes - #event - 1 - 3)
    end

    local function printedMatching(pattern)
        for _, line in ipairs(printed) do
            if line:find(pattern) then return true end
        end
        return false
    end

    describe('cibles', function()
        it('refuse -1, 0, un flottant, une chaîne, une liste vide, trop longue ou mixte', function()
            local long = {}
            for i = 1, vAvA.config.server.net.maxTargets + 1 do long[i] = 1 end
            for _, target in ipairs({ -1, 0, 1.5, '1', {}, long, { 1, extra = 2 }, { 1, -1 }, { 1, 0 }, { 1, 2.5 } }) do
                assert.same({ false, 'invalid_target' }, { net.send(OWNER, nil, target, 'vava_test:e', 1) })
            end
            assert.equal(0, #sent)
        end)

        it('écrit en console qu’un envoi à tous est refusé', function()
            net.send(OWNER, nil, -1, 'vava_test:e', 1)
            assert.is_true(printedMatching('envoi à tous refusé'))
            assert.is_true(printedMatching('vava_test'))
        end)

        it('refuse un joueur absent', function()
            assert.same({ false, 'invalid_target' }, { net.send(OWNER, nil, 9, 'vava_test:e', 1) })
        end)

        it('dans une liste, retire les doublons et saute les joueurs partis', function()
            local ok, count, bytes, latent = net.send(OWNER, nil, { 1, 1, 2, 9 }, 'vava_test:e', 'bonjour')
            assert.is_true(ok)
            assert.equal(2, count)
            assert.is_true(bytes > 0)
            assert.is_false(latent)
            assert.equal(2, #sent)
            assert.equal(1, sent[1].target)
            assert.equal(2, sent[2].target)
            assert.equal('bonjour', sent[1].args[1])
        end)

        it('une liste dont tous les joueurs sont partis : rien envoyé, rien mesuré', function()
            assert.same({ true, 0, 0, false }, { net.send(OWNER, nil, { 9, 10 }, 'vava_test:e', 1) })
            assert.equal(0, #sent)
        end)
    end)

    describe('évènement, valeurs et options', function()
        it('exige le préfixe de la ressource appelante, jamais celui du core', function()
            for _, event in ipairs({ 'e', 'autre:e', 'vAvA:rpc:response', 'core:x', 'vava_test', 'vava_test:a b', 12 }) do
                assert.same({ false, 'invalid_event' }, { net.send(OWNER, nil, 1, event, 1) })
            end
            assert.same({ false, 'invalid_event' }, { net.send('vAvA', nil, 1, 'vAvA:rpc:response', 1) })
            assert.equal(0, #sent)
        end)

        it('refuse plus de net.maxArgs valeurs', function()
            local values = {}
            for i = 1, vAvA.config.server.net.maxArgs + 1 do values[i] = i end
            assert.same({ false, 'invalid_args' }, { net.send(OWNER, nil, 1, 'vava_test:e', table.unpack(values)) })
            assert.is_true(net.send(OWNER, nil, 1, 'vava_test:e', table.unpack(values, 1, #values - 1)))
        end)

        it('refuse des options inconnues ou hors bornes', function()
            for _, options in ipairs({ 'auto', { foo = 1 }, { latent = 'oui' }, { 'never' }, { exclude = 1 } }) do
                assert.same({ false, 'invalid_options' }, { net.send(OWNER, options, 1, 'vava_test:e', 1) })
            end
            for _, options in ipairs({ { exclude = 0 }, { bucket = -1 }, { bucket = 1.5 }, { warnLarge = true } }) do
                assert.same({ false, 'invalid_options' }, { net.sendNear(OWNER, options, { x = 0, y = 0, z = 0 }, 5.0, 'vava_test:e') })
            end
        end)

        it('refuse des valeurs impossibles à envoyer (fonction, cycle)', function()
            assert.same({ false, 'unserializable' }, { net.send(OWNER, nil, 1, 'vava_test:e', function() end) })
            local loop = {}
            loop[1] = loop
            assert.same({ false, 'unserializable' }, { net.send(OWNER, nil, 1, 'vava_test:e', loop) })
            assert.equal(0, #sent)
        end)
    end)

    describe('seuil du latent', function()
        local EVENT = 'vava_test:e'

        it('8 192 octets : fiable ; 8 193 : latent, au débit configuré', function()
            local ok, count, bytes, latent = net.send(OWNER, nil, 1, EVENT, payloadFor(EVENT, 8192))
            assert.same({ true, 1, 8192, false }, { ok, count, bytes, latent })
            ok, count, bytes, latent = net.send(OWNER, nil, 1, EVENT, payloadFor(EVENT, 8193))
            assert.same({ true, 1, 8193, true }, { ok, count, bytes, latent })
            assert.is_false(sent[1].latent)
            assert.is_true(sent[2].latent)
            assert.equal(vAvA.config.server.net.latent.bytesPerSecond, sent[2].rate)
        end)

        it('never : fiable à 20 Ko ; always : latent à 100 octets', function()
            local _, _, _, latent = net.send(OWNER, { latent = 'never' }, 1, EVENT, payloadFor(EVENT, 20480))
            assert.is_false(latent)
            _, _, _, latent = net.send(OWNER, { latent = 'always' }, 1, EVENT, string.rep('x', 80))
            assert.is_true(latent)
            assert.is_false(sent[1].latent)
            assert.is_true(sent[2].latent)
        end)

        it('au-delà de maxBytes : too_large, rien n’est envoyé, erreur en console', function()
            local max = vAvA.config.server.net.maxBytes
            assert.same({ false, 'too_large' }, { net.send(OWNER, nil, 1, EVENT, string.rep('x', max)) })
            assert.equal(0, #sent)
            assert.is_true(printedMatching('refusé'))
        end)
    end)

    describe('volume latent en route', function()
        local EVENT = 'vava_test:big'
        local whole

        before_each(function()
            -- message entier : 1 (liste) + 5 (str32) + charge + nom de l'évènement = maxBytes
            whole = string.rep('x', vAvA.config.server.net.maxBytes - 6 - #EVENT)
        end)

        it('refuse le troisième envoi de 256 Ko au même instant, l’accepte 4 s plus tard', function()
            assert.is_true(net.send(OWNER, nil, 1, EVENT, whole))
            assert.is_true(net.send(OWNER, nil, 1, EVENT, whole))
            assert.same({ false, 'saturated' }, { net.send(OWNER, nil, 1, EVENT, whole) })
            assert.equal(2, #sent)
            assert.is_true(net.wouldSaturate(1, 262144))
            now = 4000
            assert.is_false(net.wouldSaturate(1, 262144))
            assert.is_true(net.send(OWNER, nil, 1, EVENT, whole))
            -- un autre joueur n'est pas concerné
            now = 0
            assert.is_true(net.send(OWNER, nil, 2, EVENT, whole))
        end)

        it('dans une liste, la cible saturée est sautée et les autres reçoivent', function()
            net.send(OWNER, nil, 1, EVENT, whole)
            net.send(OWNER, nil, 1, EVENT, whole)
            sent = {}
            local ok, count = net.send(OWNER, nil, { 1, 2, 3 }, EVENT, whole)
            assert.is_true(ok)
            assert.equal(2, count)
            assert.equal(2, sent[1].target)
            assert.equal(3, sent[2].target)
        end)

        -- relecture de T-013 : le préavis doit compter ce qui est déjà en route vers le joueur
        it('le préavis reçoit le délai jusqu’à l’arrivée, latents déjà en route compris', function()
            local delays = {}
            local function notice(target, packet, delay) delays[#delays + 1] = { target, packet.bytes, delay } end
            local packet = net.prepare(OWNER, EVENT, EVENT, whole)
            assert.is_true(net.deliver(OWNER, EVENT, 1, nil, packet, notice))
            now = 1000
            assert.is_true(net.deliver(OWNER, EVENT, 1, nil, packet, notice))
            -- 262 144 octets à 64 Ko/s : 4 000 ms ; le second attend le premier (3 000 ms restants)
            assert.same({ 1, 262144, 4000 }, delays[1])
            assert.same({ 1, 262144, 7000 }, delays[2])
            assert.equal('integer', math.type(delays[2][3]))
            assert.is_true(net.deliver(OWNER, EVENT, 2, nil, packet, notice))
            assert.equal(4000, delays[3][3])
        end)

        it('liste : la 5e valeur donne les joueurs sautés, nil s’il n’y en a aucun', function()
            local ok, count, _, _, skipped = net.send(OWNER, nil, { 1, 2 }, EVENT, 'petit')
            assert.same({ true, 2 }, { ok, count })
            assert.is_nil(skipped)
            net.send(OWNER, nil, 1, EVENT, whole)
            net.send(OWNER, nil, 1, EVENT, whole)
            ok, count, _, _, skipped = net.send(OWNER, nil, { 2, 1, 3 }, EVENT, whole)
            assert.same({ true, 2 }, { ok, count })
            assert.same({ 1 }, skipped)
            -- un seul joueur : pas de liste, saturated
            assert.same({ false, 'saturated' }, { net.send(OWNER, nil, 1, EVENT, whole) })
        end)

        it('rayon : la 5e valeur donne les joueurs sautés', function()
            place(1, 1, 0, 0)
            place(2, 2, 0, 0)
            net.send(OWNER, nil, 2, EVENT, whole)
            net.send(OWNER, nil, 2, EVENT, whole)
            local ok, count, _, latent, skipped = net.sendNear(OWNER, nil, { x = 0, y = 0, z = 0 }, 10.0, EVENT, whole)
            assert.same({ true, 1, true }, { ok, count, latent })
            assert.same({ 2 }, skipped)
        end)

        it('plafond global : 4 Mo en route, un second envoi vers un joueur qui attend déjà est refusé, accepté 4 s plus tard', function()
            for src = 1, 20 do existing[src] = true end
            assert.equal(4194304, vAvA.config.server.net.latent.maxTotalInFlightBytes)
            for src = 1, 16 do
                assert.is_true(net.send(OWNER, nil, src, EVENT, whole))
            end
            printed = {}
            -- le joueur 1 a 256 Ko en route (son plafond de 512 Ko le permettrait) : refusé par le plafond global
            assert.is_true(net.wouldSaturate(1, 262144))
            assert.same({ false, 'saturated' }, { net.send(OWNER, nil, 1, EVENT, whole) })
            assert.is_true(printedMatching('plafond global du latent atteint'))
            assert.is_true(printedMatching('4194304 octets en route'))
            -- un petit message fiable passe toujours
            assert.is_true(net.send(OWNER, nil, 1, EVENT, 'petit'))
            now = 4000
            assert.is_false(net.wouldSaturate(1, 262144))
            assert.is_true(net.send(OWNER, nil, 1, EVENT, whole))
        end)

        -- relecture de T-014 (sécurité M-2) : un joueur n'est jamais privé de tout gros envoi par les autres
        it('plafond global atteint : le premier envoi latent vers un joueur qui n’a rien en route passe toujours', function()
            for src = 1, 20 do existing[src] = true end
            for src = 1, 16 do net.send(OWNER, nil, src, EVENT, whole) end
            assert.is_false(net.wouldSaturate(17, 262144))
            assert.is_true(net.send(OWNER, nil, 17, EVENT, whole))
            -- le second, lui, attend
            assert.same({ false, 'saturated' }, { net.send(OWNER, nil, 17, EVENT, whole) })
        end)

        it('plafond global dans une liste : les cibles qui attendent déjà sont sautées et rendues', function()
            for src = 1, 20 do existing[src] = true end
            for src = 1, 16 do net.send(OWNER, nil, src, EVENT, whole) end
            local list = { 1, 17, 2, 18 }
            local ok, count, _, _, skipped = net.send(OWNER, nil, list, EVENT, whole)
            assert.same({ true, 2 }, { ok, count })
            assert.same({ 1, 2 }, skipped)
            -- la liste du module n'est pas touchée
            assert.same({ 1, 17, 2, 18 }, list)
        end)

        it('deliverList : rend des listes neuves de servis et de sautés, sans toucher la liste donnée', function()
            net.send(OWNER, nil, 2, EVENT, whole)
            net.send(OWNER, nil, 2, EVENT, whole)
            local packet = net.prepare(OWNER, EVENT, EVENT, whole)
            local list = { 1, 2, 3, 9 }
            local notices = {}
            local ok, served, skipped, bytes, latent = net.deliverList(OWNER, EVENT, list, nil, packet,
                function(target) notices[#notices + 1] = target end)
            assert.is_true(ok)
            assert.same({ 1, 3 }, served)
            assert.same({ 2 }, skipped)
            assert.equal(packet.bytes, bytes)
            assert.is_true(latent)
            assert.same({ 1, 3 }, notices)
            assert.same({ 1, 2, 3, 9 }, list)
            ok, served, skipped, bytes, latent = net.deliverList(OWNER, EVENT, { 9 }, nil, packet)
            assert.same({ true, {}, {}, 0, false }, { ok, served, skipped, bytes, latent })
        end)

        it('purgePlayer oublie le volume en route et les totaux du joueur', function()
            net.send(OWNER, nil, 1, EVENT, whole)
            net.send(OWNER, nil, 1, EVENT, whole)
            net.purgePlayer(1)
            assert.is_true(net.send(OWNER, nil, 1, EVENT, whole))
            net.purgePlayer(1)
            assert.equal(0, net.stats({ target = 1 }).total.messages)
        end)
    end)

    describe('joueurs proches', function()
        local CENTER = { x = 0.0, y = 0.0, z = 0.0 }

        it('compte la distance en 3D, rayon compris', function()
            place(1, 9.9, 0, 0)
            place(2, 10.1, 0, 0)
            place(3, 0, 0, 9.9)
            place(4, 0, 7.0, 7.2)   -- 10,04 m
            local list = net.playersNear(CENTER, 10.0)
            table.sort(list)
            assert.same({ 1, 3 }, list)
            local ok, count = net.sendNear(OWNER, nil, CENTER, 10.0, 'vava_test:e', 'son')
            assert.same({ true, 2 }, { ok, count })
            assert.equal(2, #sent)
        end)

        it('saute l’exclu, les autres routing buckets, un personnage non apparu, sans ped ou d’un joueur parti', function()
            place(1, 1, 0, 0)
            place(2, 2, 0, 0)
            place(3, 3, 0, 0, { spawned = false })
            place(4, 4, 0, 0)
            peds[4] = nil
            place(5, 5, 0, 0, { current = false })
            place(6, 6, 0, 0)
            buckets[6] = 3
            local list = net.playersNear(CENTER, 50.0, { exclude = 1 })
            table.sort(list)
            assert.same({ 2, 6 }, list)
            assert.same({ 6 }, net.playersNear(CENTER, 50.0, { bucket = 3 }))
            assert.same({ 2 }, net.playersNear(CENTER, 50.0, { exclude = 1, bucket = 0 }))
        end)

        it('personne à portée : true, 0, 0, false et rien n’est envoyé', function()
            place(1, 500, 0, 0)
            assert.same({ true, 0, 0, false }, { net.sendNear(OWNER, nil, CENTER, 20.0, 'vava_test:e', 'son') })
            assert.equal(0, #sent)
        end)

        it('refuse un rayon nul, négatif, NaN, infini ou au-delà du maximum, et des coordonnées non finies', function()
            local maxRadius = vAvA.config.server.net.near.maxRadius
            for _, radius in ipairs({ 0, -1, 0 / 0, math.huge, maxRadius + 0.1, '5' }) do
                assert.same({ false, 'invalid_radius' }, { net.sendNear(OWNER, nil, CENTER, radius, 'vava_test:e') })
                assert.same({ nil, 'invalid_radius' }, { net.playersNear(CENTER, radius) })
            end
            assert.is_true(net.sendNear(OWNER, nil, CENTER, maxRadius, 'vava_test:e'))
            for _, coords in ipairs({ { x = 0 / 0, y = 0, z = 0 }, { 0, 0, 0 }, 'ici', { x = 1, y = 2 } }) do
                assert.same({ false, 'invalid_coords' }, { net.sendNear(OWNER, nil, coords, 5.0, 'vava_test:e') })
            end
        end)

        -- relecture de T-013 : le joueur d'origine donne l'exclu et l'instance
        it('from : saute le joueur d’origine et ne garde que son routing bucket', function()
            place(1, 1, 0, 0)
            place(2, 2, 0, 0)
            place(3, 3, 0, 0)
            buckets[1], buckets[2], buckets[3] = 7, 7, 0
            assert.same({ 2 }, net.playersNear(CENTER, 50.0, { from = 1 }))
            local ok, count = net.sendNear(OWNER, { from = 1 }, CENTER, 50.0, 'vava_test:e', 'son')
            assert.same({ true, 1 }, { ok, count })
            assert.equal(2, sent[1].target)
            -- exclude ou bucket donnés l'emportent
            local list = net.playersNear(CENTER, 50.0, { from = 1, bucket = 0 })
            assert.same({ 3 }, list)
            list = net.playersNear(CENTER, 50.0, { from = 1, exclude = 2 })
            assert.same({ 1 }, list)
            for _, from in ipairs({ 0, -1, 1.5, '1', 9 }) do
                assert.same({ nil, 'invalid_options' }, { net.playersNear(CENTER, 50.0, { from = from }) })
            end
            assert.same({ false, 'invalid_options' }, { net.send(OWNER, { from = 1 }, 2, 'vava_test:e') })
        end)

        -- 0.11.0 (T-014) : positions gardées near.positionCacheMs (50 ms) au lieu d'une milliseconde
        it('lit chaque position au plus une fois pendant 50 ms', function()
            local reads = 0
            _G.GetEntityCoords = function(ped)
                reads = reads + 1
                return positions[ped]
            end
            helper.load('server/core/net.lua')
            net = vAvA.net
            assert.equal(50, vAvA.config.server.net.near.positionCacheMs)
            place(1, 1, 0, 0)
            place(2, 2, 0, 0)
            net.playersNear(CENTER, 10.0)
            net.playersNear(CENTER, 10.0)
            assert.equal(2, reads)
            now = 49
            net.playersNear(CENTER, 10.0)
            assert.is_table(net.positionOf(1))
            assert.equal(2, reads)
            now = 50
            net.playersNear(CENTER, 10.0)
            assert.equal(4, reads)
        end)

        it('positionOf : une lecture à 0 et 49 ms, deux à 50 ms ; sans ped : nil', function()
            local reads = 0
            _G.GetEntityCoords = function(ped)
                reads = reads + 1
                return positions[ped]
            end
            helper.load('server/core/net.lua')
            net = vAvA.net
            place(1, 1, 2, 3)
            assert.same({ x = 1, y = 2, z = 3 }, net.positionOf(1))
            now = 49
            net.positionOf(1)
            assert.equal(1, reads)
            now = 50
            net.positionOf(1)
            assert.equal(2, reads)
            assert.is_nil(net.positionOf(5))
        end)
    end)

    describe('compteur', function()
        it('un envoi à 3 joueurs compte 3 messages et 3 fois la taille, sous la ressource et l’évènement', function()
            local _, _, bytes = net.send(OWNER, nil, { 1, 2, 3 }, 'vava_test:e', 'bonjour')
            local stats = net.stats()
            assert.equal('estimate', stats.mode)
            assert.equal(60000, stats.windowMs)
            assert.same({ messages = 3, bytes = 3 * bytes, latent = 0 }, stats.total)
            assert.same({ resource = OWNER, label = 'vava_test:e', messages = 3, bytes = 3 * bytes, latent = 0, largest = bytes },
                stats.events[1])
            assert.equal(1, net.stats({ target = 2 }).total.messages)
        end)

        it('détaille chaque joueur évènement par évènement, sans suivi à lancer (0.12.0), avec son personnage', function()
            assert.is_nil(net.watch)
            vAvA.characters.describeActive = function(src)
                return src == 2 and { firstName = 'Aldric', lastName = 'Morn' } or nil
            end
            net.send(OWNER, nil, 2, 'vava_test:e', 1)
            local stats = net.stats({ target = 2 })
            assert.is_nil(stats.watched)
            assert.equal('vava_test:e', stats.events[1].label)
            assert.equal('Aldric Morn', stats.name)
            assert.is_nil(net.stats({ target = 3 }).name)
        end)

        it('liste les joueurs connectés, les plus chargés d’abord, avec leur personnage', function()
            _G.GetPlayers = function() return { '1', '2', '3' } end
            vAvA.characters.describeActive = function(src)
                return src == 3 and { firstName = 'Ysolde', lastName = 'Var' } or nil
            end
            net.send(OWNER, nil, { 1, 3 }, 'vava_test:e', 'bonjour')
            net.send(OWNER, nil, 3, 'vava_test:f', 'encore')
            local stats = net.stats({ players = true })
            assert.equal(3, stats.playerCount)
            assert.equal(3, #stats.players)
            assert.equal(3, stats.players[1].source)
            assert.equal('Ysolde Var', stats.players[1].name)
            assert.equal(2, stats.players[1].messages)
            assert.equal(1, stats.players[2].source)
            assert.is_nil(stats.players[2].name)
            assert.same({ source = 2, messages = 0, bytes = 0, latent = 0 }, stats.players[3])
            -- avec la liste, seul le total du royaume : aucun évènement construit
            assert.same(net.stats().total, stats.total)
            assert.same({}, stats.events)
            assert.equal(60000, stats.windowMs)
            assert.is_nil(net.stats().players)
            -- runtime sans GetPlayers : refus, pas une liste vide trompeuse
            _G.GetPlayers = nil
            assert.same({ nil, 'unsupported' }, { net.stats({ players = true }) })
        end)

        it('nom du personnage seulement si prénom et nom sont des chaînes', function()
            vAvA.characters.describeActive = function(src)
                if src == 1 then return { firstName = 'Aldric', lastName = 7 } end
                if src == 2 then return 'Aldric Morn' end
                return { firstName = 'Ysolde', lastName = 'Var' }
            end
            assert.is_nil(net.stats({ target = 1 }).name)
            assert.is_nil(net.stats({ target = 2 }).name)
            assert.equal('Ysolde Var', net.stats({ target = 3 }).name)
        end)

        it('garde les net.counter.playerKeys (6) évènements les plus lourds d’un joueur, le reste sous <autres>', function()
            local keys = vAvA.config.server.net.counter.playerKeys
            assert.equal(6, keys)
            for i = 1, keys + 3 do net.send(OWNER, nil, 4, 'vava_test:e' .. i, string.rep('x', 300)) end
            local events = net.stats({ target = 4, limit = 50 }).events
            assert.equal(keys + 1, #events)
            local other = 0
            for _, event in ipairs(events) do
                if event.label == '<autres>' then other = event.messages end
            end
            assert.equal(3, other)
        end)

        it('plafonne la liste des joueurs à 128', function()
            local list = {}
            for i = 1, 200 do list[i] = tostring(i) end
            _G.GetPlayers = function() return list end
            local stats = net.stats({ players = true })
            assert.equal(200, stats.playerCount)
            assert.equal(128, #stats.players)
            _G.GetPlayers = nil
        end)

        it('refuse des options de lecture inconnues ou hors bornes', function()
            for _, options in ipairs({ 'x', { foo = 1 }, { limit = 0 }, { limit = 51 }, { limit = 1.5 },
                { resource = 'a b' }, { resource = string.rep('a', 49) }, { target = 0 }, { players = 1 },
                { players = true, target = 1 }, { players = true, resource = 'vava_test' } }) do
                assert.same({ nil, 'invalid_options' }, { net.stats(options) })
            end
            assert.is_table(net.stats({ limit = 50, resource = 'vava_test', target = 1 }))
            assert.is_table(net.stats({ limit = 50, players = false, target = 1 }))
        end)
    end)

    describe('dispatch du core', function()
        it('envoie ses évènements sans contrôle de préfixe, mais jamais à -1', function()
            assert.is_true(net.dispatch('vAvA_core', 'chat:addMessage', 1, net.NEVER, 'chat:addMessage', { args = { 'a' } }))
            assert.same({ false, 'invalid_target' }, { net.dispatch('vAvA_core', 'x', -1, nil, 'vAvA:x') })
            assert.equal(1, #sent)
        end)

        it('RELIABLE : jamais latent, alerte en console au-delà du seuil une fois par minute', function()
            local event = 'vAvA:character:loaded'
            local big = payloadFor(event, 12288)
            assert.same({ true, 1, 12288, false }, { net.dispatch('vAvA_core', event, 1, net.RELIABLE, event, big) })
            net.dispatch('vAvA_core', event, 1, net.RELIABLE, event, big)
            local warnings = 0
            for _, line in ipairs(printed) do
                if line:find(event, 1, true) and line:find('fiable', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(1, warnings)
            assert.is_false(sent[1].latent)
            now = 60000
            net.dispatch('vAvA_core', event, 1, net.RELIABLE, event, big)
            warnings = 0
            for _, line in ipairs(printed) do
                if line:find(event, 1, true) and line:find('fiable', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(2, warnings)
        end)
    end)

    describe('mesure exacte', function()
        before_each(function()
            _G.msgpack = {
                pack_args = function(...)
                    packCalls = packCalls + 1
                    if packError then error('valeur refusée') end
                    local parts = {}
                    for i = 1, select('#', ...) do parts[i] = tostring((select(i, ...))) end
                    return 'P' .. table.concat(parts, '|')
                end,
            }
            _G.TriggerClientEventInternal = function(event, target, payload, length)
                internalSent[#internalSent + 1] = { event = event, target = target, payload = payload, length = length }
            end
            _G.TriggerLatentClientEventInternal = function(event, target, payload, length, rate)
                internalSent[#internalSent + 1] = {
                    event = event, target = target, payload = payload, length = length, rate = rate, latent = true,
                }
            end
            net.start()
            assert.equal('exact', net.mode())
            assert.is_true(printedMatching('mesure exacte'))
        end)

        it('sérialise une seule fois pour 5 joueurs et envoie la même chaîne à chacun', function()
            local ok, count, bytes = net.send(OWNER, nil, { 1, 2, 3, 4, 5 }, 'vava_test:e', 'bonjour', 7)
            assert.same({ true, 5 }, { ok, count })
            assert.equal(1, packCalls)
            assert.equal(5, #internalSent)
            local payload = internalSent[1].payload
            assert.equal(#payload + #'vava_test:e', bytes)
            for i = 1, 5 do
                assert.equal(payload, internalSent[i].payload)
                assert.equal(#payload, internalSent[i].length)
                assert.equal(tostring(i), internalSent[i].target)
            end
            assert.equal(0, #sent)
        end)

        describe('sendPacked et sendNearPacked (0.11.0)', function()
            it('envoie la chaîne telle quelle, sans appeler pack_args', function()
                local payload = '\147\1\2\3'
                local ok, count, bytes, latent = net.sendPacked(OWNER, nil, { 1, 2 }, 'vava_test:e', payload)
                assert.same({ true, 2, #payload + #'vava_test:e', false }, { ok, count, bytes, latent })
                assert.equal(0, packCalls)
                assert.equal(2, #internalSent)
                assert.equal(payload, internalSent[1].payload)
                assert.equal(#payload, internalSent[1].length)
                assert.equal('2', internalSent[2].target)
                assert.equal(2, net.stats({ resource = OWNER }).total.messages)
            end)

            it('latent au-delà du seuil, par l’envoi latent interne', function()
                local _, _, _, latent = net.sendPacked(OWNER, nil, 1, 'vava_test:e', string.rep('x', 9000))
                assert.is_true(latent)
                assert.is_true(internalSent[1].latent)
            end)

            it('refuse une chaîne vide ou autre chose, trop grande, une autre ressource, -1, des options inconnues', function()
                -- en premier : les erreurs en console sont limitées à une par intervalle et par ressource
                assert.same({ false, 'invalid_target' }, { net.sendPacked(OWNER, nil, -1, 'vava_test:e', 'x') })
                assert.is_true(printedMatching('envoi à tous refusé'))
                assert.same({ false, 'invalid_args' }, { net.sendPacked(OWNER, nil, 1, 'vava_test:e', '') })
                assert.same({ false, 'invalid_args' }, { net.sendPacked(OWNER, nil, 1, 'vava_test:e', { 1 }) })
                assert.same({ false, 'invalid_args' }, { net.sendPacked(OWNER, nil, 1, 'vava_test:e', nil) })
                local max = vAvA.config.server.net.maxBytes
                assert.same({ false, 'too_large' },
                    { net.sendPacked(OWNER, nil, 1, 'vava_test:e', string.rep('x', max - #'vava_test:e' + 1)) })
                assert.is_true(net.sendPacked(OWNER, nil, 1, 'vava_test:e', string.rep('x', max - #'vava_test:e')))
                assert.same({ false, 'invalid_event' }, { net.sendPacked(OWNER, nil, 1, 'autre:e', 'x') })
                assert.same({ false, 'invalid_event' }, { net.sendPacked(OWNER, nil, 1, 'vAvA:zone:state', 'x') })
                assert.same({ false, 'invalid_target' }, { net.sendPacked(OWNER, nil, { 1, -1 }, 'vava_test:e', 'x') })
                assert.same({ false, 'invalid_options' }, { net.sendPacked(OWNER, { from = 1 }, 1, 'vava_test:e', 'x') })
                assert.equal(1, #internalSent)
            end)

            it('sendNearPacked : joueurs proches, personne à portée → true, 0, 0, false', function()
                place(1, 1, 0, 0)
                place(2, 50, 0, 0)
                local ok, count = net.sendNearPacked(OWNER, nil, { x = 0, y = 0, z = 0 }, 10.0, 'vava_test:e', 'abc')
                assert.same({ true, 1 }, { ok, count })
                assert.equal('1', internalSent[1].target)
                assert.same({ true, 0, 0, false },
                    { net.sendNearPacked(OWNER, nil, { x = 900, y = 0, z = 0 }, 10.0, 'vava_test:e', 'abc') })
                assert.same({ false, 'invalid_radius' },
                    { net.sendNearPacked(OWNER, nil, { x = 0, y = 0, z = 0 }, 0, 'vava_test:e', 'abc') })
                assert.same({ false, 'invalid_coords' }, { net.sendNearPacked(OWNER, nil, 'ici', 5.0, 'vava_test:e', 'abc') })
                assert.equal(0, packCalls)
            end)

            it('envoi interne en échec : la cible n’est pas servie (rien à rejouer), sautée dans une liste', function()
                _G.TriggerClientEventInternal = function() error('cible refusée') end
                helper.load('server/core/net.lua')
                net = vAvA.net
                net.start()
                assert.same({ false, 'unsupported' }, { net.sendPacked(OWNER, nil, 1, 'vava_test:e', 'abc') })
                assert.equal(0, #sent)
                assert.is_true(printedMatching('impossible à envoyer'))
                -- désormais en estimation : unsupported avant tout envoi, le module renvoie par send
                assert.same({ false, 'unsupported' }, { net.sendPacked(OWNER, nil, { 1, 2 }, 'vava_test:e', 'abc') })
                assert.is_true(net.send(OWNER, nil, 1, 'vava_test:e', 'abc'))
            end)

            it('liste dont la première cible fait échouer l’envoi interne : toutes sautées', function()
                _G.TriggerClientEventInternal = function() error('cible refusée') end
                helper.load('server/core/net.lua')
                net = vAvA.net
                net.start()
                local ok, count, _, _, skipped = net.sendPacked(OWNER, nil, { 1, 2 }, 'vava_test:e', 'abc')
                assert.same({ true, 0 }, { ok, count })
                assert.same({ 1, 2 }, skipped)
            end)
        end)

        it('latent : par l’envoi latent interne, au débit configuré', function()
            local _, _, _, latent = net.send(OWNER, { latent = 'always' }, 1, 'vava_test:e', 1)
            assert.is_true(latent)
            assert.is_true(internalSent[1].latent)
            assert.equal(vAvA.config.server.net.latent.bytesPerSecond, internalSent[1].rate)
        end)

        it('pack_args en erreur : unserializable, rien n’est envoyé', function()
            packError = true
            assert.same({ false, 'unserializable' }, { net.send(OWNER, nil, 1, 'vava_test:e', 1) })
            assert.equal(0, #internalSent)
        end)

        it('personne à portée : rien n’est sérialisé', function()
            place(1, 500, 0, 0)
            assert.same({ true, 0, 0, false }, { net.sendNear(OWNER, nil, { x = 0, y = 0, z = 0 }, 20.0, 'vava_test:e', 1) })
            assert.equal(0, packCalls)
        end)

        it('un envoi interne en échec repasse par TriggerClientEvent et bascule en estimation', function()
            _G.TriggerClientEventInternal = function() error('cible refusée') end
            helper.load('server/core/net.lua')
            net = vAvA.net
            net.start()
            local ok = net.send(OWNER, nil, { 1, 2 }, 'vava_test:e', 'bonjour')
            assert.is_true(ok)
            assert.equal(2, #sent)
            assert.equal('bonjour', sent[1].args[1])
            assert.equal('estimate', net.mode())
            assert.is_true(printedMatching('estimation à partir de maintenant'))
        end)

        it('mode forcé par la config : estimation même si le runtime offre la mesure exacte', function()
            vAvA.config.server.net.mode = 'estimate'
            net.start()
            assert.equal('estimate', net.mode())
            net.send(OWNER, nil, 1, 'vava_test:e', 1)
            assert.equal(0, packCalls)
            assert.equal(1, #sent)
        end)
    end)

    it('sans les fonctions du runtime : estimation, dite en console', function()
        net.start()
        assert.equal('estimate', net.mode())
        assert.is_true(printedMatching('msgpack.pack_args'))
    end)

    it('sendPacked en estimation : unsupported, rien n’est envoyé', function()
        net.start()
        assert.same({ false, 'unsupported' }, { net.sendPacked(OWNER, nil, 1, 'vava_test:e', 'abc') })
        place(1, 1, 0, 0)
        assert.same({ false, 'unsupported' },
            { net.sendNearPacked(OWNER, nil, { x = 0, y = 0, z = 0 }, 10.0, 'vava_test:e', 'abc') })
        assert.equal(0, #sent)
    end)
end)
