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

        it('lit chaque position au plus une fois par tour du serveur', function()
            local reads = 0
            _G.GetEntityCoords = function(ped)
                reads = reads + 1
                return positions[ped]
            end
            helper.load('server/core/net.lua')
            net = vAvA.net
            place(1, 1, 0, 0)
            place(2, 2, 0, 0)
            net.playersNear(CENTER, 10.0)
            net.playersNear(CENTER, 10.0)
            assert.equal(2, reads)
            now = 1
            net.playersNear(CENTER, 10.0)
            assert.equal(4, reads)
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

        it('suit un joueur évènement par évènement', function()
            assert.same({ true, 'started' }, { net.watch(2) })
            net.send(OWNER, nil, 2, 'vava_test:e', 1)
            local stats = net.stats({ target = 2 })
            assert.is_true(stats.watched)
            assert.equal('vava_test:e', stats.events[1].label)
        end)

        it('refuse des options de lecture inconnues ou hors bornes', function()
            for _, options in ipairs({ 'x', { foo = 1 }, { limit = 0 }, { limit = 51 }, { limit = 1.5 },
                { resource = 'a b' }, { resource = string.rep('a', 49) }, { target = 0 } }) do
                assert.same({ nil, 'invalid_options' }, { net.stats(options) })
            end
            assert.is_table(net.stats({ limit = 50, resource = 'vava_test', target = 1 }))
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
end)
