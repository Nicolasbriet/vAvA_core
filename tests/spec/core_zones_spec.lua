local helper = require('tests.helper')

-- Abonnements de zone côté serveur (server/core/zones.lua, core 0.11.0, T-014) : déclaration, passage (entrées,
-- sorties, hystérésis, instances), instantanés groupés, différences regroupées, latent et préavis, budget, purges,
-- resync, compteur. vAvA.net réel (estimation, puis mesure exacte avec des doublures du runtime) ; natives, personnages
-- et RPC en doublures.
describe('vAvA.zones', function()
    local zones, net, now, sent, internalSent, printed, existing, peds, positions, buckets, characters, registered
    local packCalls, realPrint, cfg

    local OWNER, OTHER = 'vava_test', 'vava_autre'
    local STATE, PENDING, DIFF, LEAVE = 'vAvA:zone:state', 'vAvA:zone:pending', 'vAvA:zone:diff', 'vAvA:zone:leave'

    before_each(function()
        helper.reset()
        now = 0
        sent, internalSent, printed, registered = {}, {}, {}, {}
        packCalls = 0
        existing, peds, positions, buckets, characters = {}, {}, {}, {}, {}
        for src = 1, 40 do existing[src] = true end
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
        vAvA.rpc = {
            register = function(owner, name, options, handler)
                registered[name] = { owner = owner, options = options, handler = handler }
                return true
            end,
        }
        helper.loadAll({ 'server/core/zonegrid.lua', 'server/core/zonestate.lua', 'server/core/zones.lua' })
        net, zones, cfg = vAvA.net, vAvA.zones, vAvA.config.server.zones
        vAvA.characters = {
            forEachActive = function(fn)
                for _, character in ipairs(characters) do fn(character) end
            end,
        }
        vAvA.sync = { isCurrent = function(character) return character.current ~= false end }
        assert.is_true(zones.registerRpc())
        zones.start()
    end)

    after_each(function()
        _G.print = realPrint
        _G.msgpack = nil
        _G.TriggerClientEventInternal = nil
        _G.TriggerLatentClientEventInternal = nil
    end)

    --- Personnage apparu du joueur src, ped à (x, y, z).
    local function place(src, x, y, z, extra)
        local ped = 100 + src
        peds[src], positions[ped] = ped, { x = x, y = y, z = z or 0.0 }
        local character = { source = src, spawned = true }
        for key, value in pairs(extra or {}) do character[key] = value end
        characters[#characters + 1] = character
        return character
    end

    local function go(src, x, y, z)
        positions[100 + src] = { x = x, y = y, z = z or 0.0 }
    end

    --- Un passage, une seconde plus tard (le cache des positions de net a expiré).
    local function runPass()
        now = now + 1000
        for i = #helper.timers, 1, -1 do
            local timer = helper.timers[i]
            if timer.ms == cfg.passMs and not timer.done then
                timer.done = true
                timer.fn()
                return
            end
        end
        error('aucun passage programmé')
    end

    --- Fin du tour : minuteries à 0 ms (envoi des différences regroupées).
    local function endTurn()
        for _, timer in ipairs(helper.timers) do
            if timer.ms == 0 and not timer.done then
                timer.done = true
                timer.fn()
            end
        end
    end

    local function of(event, target)
        local list = {}
        for _, entry in ipairs(sent) do
            if entry.event == event and (target == nil or entry.target == target) then list[#list + 1] = entry end
        end
        return list
    end

    local function events(target)
        local list = {}
        for _, entry in ipairs(sent) do
            if target == nil or entry.target == target then list[#list + 1] = entry.event end
        end
        return list
    end

    local function printedMatching(pattern)
        for _, line in ipairs(printed) do
            if line:find(pattern, 1, true) then return true end
        end
        return false
    end

    --- État d'environ `kb` Ko (kb / 2 valeurs de 2 048 octets, un peu plus avec les clés et les en-têtes).
    local function bigState(kb)
        local state = {}
        for i = 1, kb // 2 do state['k' .. i] = string.rep('x', 2048) end
        return state
    end

    local AREA = { x = 0.0, y = 0.0, z = 30.0, radius = 100.0, margin = 50.0 }

    describe('déclaration', function()
        it('define rend un numéro ; info et list', function()
            local ok, handle = zones.define(OWNER, 'place', AREA, { a = 1 })
            assert.same({ true, 1 }, { ok, handle })
            assert.same({ handle = 1, revision = 1, subscribers = 0, keys = 1, bytes = zones.stateBytes() },
                zones.info(OWNER, 'place'))
            zones.define(OWNER, 'autre', AREA)
            assert.same({ 'autre', 'place' }, zones.list(OWNER))
            assert.same({}, zones.list(OTHER))
            assert.same({ nil, 'unknown_zone' }, { zones.info(OWNER, 'rien') })
        end)

        it('refuse un identifiant invalide ou pris, un lieu invalide', function()
            assert.is_true(zones.define(OWNER, 'place', AREA))
            assert.same({ false, 'exists' }, { zones.define(OWNER, 'place', AREA) })
            for _, id in ipairs({ '', 'a b', string.rep('a', 49), 12, nil }) do
                assert.same({ false, 'invalid_id' }, { zones.define(OWNER, id, AREA) })
            end
            local bad = {
                { x = 0.0, y = 0.0, radius = 0 },
                { x = 0.0, y = 0.0, radius = 500.1 },
                { x = 0.0, y = 0.0, radius = 10, margin = -1 },
                { x = 0.0, y = 0.0, radius = 10, margin = 500.1 },
                { x = 0 / 0, y = 0.0, radius = 10 },
                { x = 60000, y = 0.0, radius = 10 },
                { x = 0.0, y = -60000, radius = 10 },
                { x = 0.0, y = 0.0, z = math.huge, radius = 10 },
                { x = 0.0, y = 0.0, radius = 10, bucket = -1 },
                { x = 0.0, y = 0.0, radius = 10, bucket = 1.5 },
                { x = 0.0, y = 0.0, radius = 10, couleur = 'rouge' },
                { 0.0, 0.0, 10 },
                'ici',
            }
            for i, area in ipairs(bad) do
                assert.same({ false, 'invalid_area' }, { zones.define(OWNER, 'z' .. i, area) }, 'lieu ' .. i)
            end
            assert.is_true(zones.define(OWNER, 'bord', { x = 50000, y = -50000, radius = 500, margin = 500, bucket = 0 }))
        end)

        it('état refusé : rien n’est déclaré', function()
            assert.same({ false, 'invalid_key' }, { zones.define(OWNER, 'place', AREA, { [1] = 'a' }) })
            assert.same({ false, 'invalid_value' }, { zones.define(OWNER, 'place', AREA, { a = function() end }) })
            assert.same({}, zones.list(OWNER))
            assert.equal(0, zones.stats().zones)
        end)

        it('deux modules peuvent avoir le même identifiant ; numéros jamais redonnés', function()
            local _, first = zones.define(OWNER, 'place', AREA)
            local _, second = zones.define(OTHER, 'place', AREA)
            assert.equal(first + 1, second)
            assert.is_true(zones.remove(OWNER, 'place'))
            local _, third = zones.define(OWNER, 'place', AREA)
            assert.equal(second + 1, third)
        end)

        it('plafonds : 1 025e zone d’un module, 2 049e en tout → full', function()
            local area = { x = 0.0, y = 0.0, radius = 1 }
            for i = 1, 1024 do assert.is_true(zones.define(OWNER, 'a' .. i, area)) end
            assert.same({ false, 'full' }, { zones.define(OWNER, 'a1025', area) })
            for i = 1, 1024 do assert.is_true(zones.define(OTHER, 'b' .. i, area)) end
            assert.same({ false, 'full' }, { zones.define('vava_trois', 'c', area) })
            assert.is_true(zones.remove(OTHER, 'b1'))
            assert.is_true(zones.define('vava_trois', 'c', area))
        end)
    end)

    describe('passage', function()
        it('entrée au bord du cercle d’intérêt, hystérésis, sortie au-delà de la marge de sortie', function()
            local _, handle = zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 149.9, 0)
            runPass()
            local states = of(STATE, 1)
            assert.equal(1, #states)
            assert.same({ handle, OWNER .. ':place', 1, { a = 1 } }, { table.unpack(states[1].args, 1, 4) })
            assert.same({ OWNER .. ':place' }, zones.ofPlayer(1))
            sent = {}
            go(1, 160, 0)
            runPass()
            assert.same({}, events(1))
            assert.same({ OWNER .. ':place' }, zones.ofPlayer(1))
            go(1, 175.1, 0)
            runPass()
            assert.same({ LEAVE }, events(1))
            assert.same({ handle }, of(LEAVE, 1)[1].args[1])
            assert.same({}, zones.ofPlayer(1))
        end)

        it('distance au sol seulement : 500 m au-dessus, toujours abonné', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 10, 10, 530)
            runPass()
            assert.equal(1, #of(STATE, 1))
        end)

        it('hors du cercle d’intérêt : rien', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 150.1, 0)
            runPass()
            assert.same({}, events(1))
        end)

        it('personnage non apparu : pas d’entrée ; apparu puis renvoyé à une apparition : abonnements gardés', function()
            zones.define(OWNER, 'place', AREA)
            local character = place(1, 0, 0, 0, { spawned = false })
            runPass()
            assert.same({}, events(1))
            character.spawned = true
            runPass()
            assert.equal(1, #of(STATE, 1))
            character.spawned = false
            sent = {}
            runPass()
            assert.same({}, events(1))
            assert.equal(1, #zones.ofPlayer(1))
            -- les nouvelles entrées attendent l'apparition
            zones.define(OWNER, 'voisine', AREA)
            runPass()
            assert.same({}, events(1))
        end)

        it('pas de ped : rien ne change ; personnage qui n’est plus celui du joueur : ignoré', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 0, 0)
            place(2, 0, 0, 0, { current = false })
            runPass()
            assert.equal(1, #of(STATE, 1))
            assert.same({}, events(2))
            peds[1] = nil
            sent = {}
            runPass()
            assert.same({}, events(1))
            assert.equal(1, #zones.ofPlayer(1))
        end)

        it('instances : zone du bucket 3 jamais suivie depuis le 0 ; joueur passé du 3 au 0 → sortie', function()
            zones.define(OWNER, 'cachot', { x = 0.0, y = 0.0, radius = 20, bucket = 3 })
            zones.define(OWNER, 'partout', { x = 0.0, y = 0.0, radius = 20 })
            place(1, 0, 0)
            place(2, 0, 0)
            buckets[2] = 3
            runPass()
            assert.same({ OWNER .. ':partout' }, zones.ofPlayer(1))
            assert.same({ OWNER .. ':cachot', OWNER .. ':partout' }, zones.ofPlayer(2))
            buckets[2] = 0
            sent = {}
            runPass()
            assert.same({ LEAVE }, events(2))
            assert.same({ OWNER .. ':partout' }, zones.ofPlayer(2))
        end)

        it('téléportation : sorties et entrées au même passage', function()
            zones.define(OWNER, 'ici', AREA)
            zones.define(OWNER, 'labas', { x = 5000.0, y = 5000.0, radius = 50 })
            place(1, 0, 0)
            runPass()
            sent = {}
            go(1, 5000, 5000)
            runPass()
            assert.same({ LEAVE, STATE }, events(1))
            assert.same({ OWNER .. ':labas' }, zones.ofPlayer(1))
        end)

        it('refreshPlayer : ce seul joueur, sans attendre le passage', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 0, 0)
            place(2, 0, 0)
            now = now + 1000
            zones.refreshPlayer(2)
            assert.same({}, events(1))
            assert.equal(1, #of(STATE, 2))
            zones.refreshPlayer(9)
        end)

        it('durée du passage gardée ; stats et zones d’un joueur', function()
            zones.define(OWNER, 'a', AREA)
            zones.define(OWNER, 'b', AREA)
            zones.define(OTHER, 'c', AREA)
            place(1, 0, 0)
            runPass()
            local stats = zones.stats()
            assert.equal(3, stats.zones)
            assert.equal(3, stats.subscriptions)
            assert.same({ { owner = OWNER, count = 2 }, { owner = OTHER, count = 1 } }, stats.owners)
            assert.is_number(stats.lastPassMs)
            assert.is_true(stats.maxPassMs >= stats.lastPassMs)
            assert.is_true(stats.meanPassMs <= stats.maxPassMs)
            assert.equal(1000, stats.passMs)
            assert.same({ OTHER .. ':c', OWNER .. ':a', OWNER .. ':b' }, zones.ofPlayer(1))
        end)

        it('un passage en erreur est écrit en console et le suivant reste programmé', function()
            zones.define(OWNER, 'place', AREA)
            vAvA.characters.forEachActive = function() error('panne') end
            runPass()
            assert.is_true(printedMatching('passage en erreur'))
            vAvA.characters.forEachActive = function(fn)
                for _, character in ipairs(characters) do fn(character) end
            end
            place(1, 0, 0)
            runPass()
            assert.equal(1, #of(STATE, 1))
        end)
    end)

    describe('différences', function()
        it('deux set dans le même tour : une différence (révision + 1, deux clés) aux seuls abonnés à jour', function()
            local _, handle = zones.define(OWNER, 'place', AREA, { a = 1, b = 1 })
            place(1, 0, 0)
            place(2, 400, 0)
            runPass()
            sent = {}
            assert.is_true(zones.set(OWNER, 'place', { a = 2 }))
            assert.is_true(zones.set(OWNER, 'place', { b = 3 }, nil))
            assert.same({}, events())
            endTurn()
            local diffs = of(DIFF)
            assert.equal(1, #diffs)
            assert.equal(1, diffs[1].target)
            assert.is_false(diffs[1].latent)
            assert.same({ handle, 2, { a = 2, b = 3 } }, { table.unpack(diffs[1].args, 1, 3) })
            assert.is_nil(diffs[1].args[4])
            assert.equal(2, zones.info(OWNER, 'place').revision)
        end)

        it('valeur scalaire inchangée : rien ne part', function()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'place', { a = 1 })
            endTurn()
            assert.same({}, events())
        end)

        it('différence regroupée de plus de 8 Ko : l’instantané part à sa place', function()
            zones.define(OWNER, 'place', AREA, {})
            place(1, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'place', { k1 = string.rep('x', 4000), k2 = string.rep('x', 4000) })
            zones.set(OWNER, 'place', { k3 = string.rep('x', 4000) })
            endTurn()
            assert.equal(0, #of(DIFF))
            local states = of(STATE, 1)
            assert.equal(1, #states)
            assert.equal(2, states[1].args[3])
        end)

        it('aucun abonné : la révision avance, rien ne part', function()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            zones.set(OWNER, 'place', { a = 2 })
            endTurn()
            assert.equal(2, zones.info(OWNER, 'place').revision)
            assert.same({}, events())
        end)

        it('set refusé : rien en attente', function()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            assert.same({ false, 'invalid_key' }, { zones.set(OWNER, 'place', { ['a b'] = 1 }) })
            assert.same({ false, 'unknown_zone' }, { zones.set(OWNER, 'rien', { a = 1 }) })
            assert.same({ false, 'unknown_zone' }, { zones.set(OTHER, 'place', { a = 1 }) })
            endTurn()
            assert.equal(1, zones.info(OWNER, 'place').revision)
        end)

        it('différence en attente au début d’un passage : envoyée avant l’instantané d’un nouvel entrant', function()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'place', { a = 2 })
            place(2, 0, 0)
            runPass()
            assert.same({ DIFF, STATE }, events())
            assert.equal(1, sent[1].target)
            assert.equal(2, sent[2].target)
            assert.equal(2, sent[2].args[3])
            assert.same({ a = 2 }, sent[2].args[4])
            -- la minuterie de fin de tour ne renvoie rien
            sent = {}
            endTurn()
            assert.same({}, events())
        end)
    end)

    describe('instantanés', function()
        it('trois joueurs entrent au même passage : une sérialisation, trois envois (mesure exacte)', function()
            _G.msgpack = {
                pack_args = function(...)
                    packCalls = packCalls + 1
                    return 'P' .. tostring(select('#', ...))
                end,
            }
            _G.TriggerClientEventInternal = function(event, target, payload)
                internalSent[#internalSent + 1] = { event = event, target = target, payload = payload }
            end
            _G.TriggerLatentClientEventInternal = function(event, target, payload)
                internalSent[#internalSent + 1] = { event = event, target = target, payload = payload, latent = true }
            end
            net.start()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 0, 0)
            place(2, 10, 0)
            place(3, 20, 0)
            runPass()
            assert.equal(1, packCalls)
            assert.equal(3, #internalSent)
            for i = 1, 3 do assert.equal(STATE, internalSent[i].event) end
        end)

        it('instantané de 20 Ko : préavis puis envoi latent, dans cet ordre', function()
            local _, handle = zones.define(OWNER, 'place', AREA, bigState(20))
            place(1, 0, 0)
            runPass()
            assert.same({ PENDING, STATE }, events(1))
            assert.is_false(sent[1].latent)
            assert.same({ handle, 1 }, { sent[1].args[1], sent[1].args[2] })
            assert.equal('integer', math.type(sent[1].args[3]))
            assert.is_true(sent[1].args[3] > 0)
            assert.is_true(sent[2].latent)
        end)

        it('joueur saturé : reste en attente, sans différences ; reçoit l’instantané plus tard', function()
            zones.define(OWNER, 'place', AREA, bigState(20))
            place(1, 0, 0)
            local whole = string.rep('x', vAvA.config.server.net.maxBytes - 6 - #'vava_test:big')
            net.send(OWNER, nil, 1, 'vava_test:big', whole)
            net.send(OWNER, nil, 1, 'vava_test:big', whole)
            sent = {}
            now = now - 1000 + 1   -- passage presque aussitôt : 512 Ko encore en route
            runPass()
            assert.same({}, events(1))
            assert.equal(1, #zones.ofPlayer(1))
            -- en attente : aucune différence
            zones.set(OWNER, 'place', { k1 = 'petit' })
            endTurn()
            assert.same({}, events(1))
            -- 8 s plus tard, tout est arrivé
            now = now + 8000
            runPass()
            local states = of(STATE, 1)
            assert.equal(1, #states)
            assert.equal(2, states[1].args[3])
            assert.equal('petit', states[1].args[4].k1)
        end)

        it('budget du passage : cinq zones de 10 Ko → trois au premier passage (les plus proches), deux au suivant', function()
            for i = 1, 5 do
                zones.define(OWNER, 'z' .. i, { x = i * 10.0, y = 0.0, radius = 100 }, bigState(10))
            end
            place(1, 0, 0)
            runPass()
            local first = of(STATE, 1)
            assert.equal(3, #first)
            local names = {}
            for i, entry in ipairs(first) do names[i] = entry.args[2] end
            table.sort(names)
            assert.same({ OWNER .. ':z1', OWNER .. ':z2', OWNER .. ':z3' }, names)
            assert.equal(5, #zones.ofPlayer(1))
            sent = {}
            runPass()
            names = {}
            for i, entry in ipairs(of(STATE, 1)) do names[i] = entry.args[2] end
            table.sort(names)
            assert.same({ OWNER .. ':z4', OWNER .. ':z5' }, names)
            sent = {}
            runPass()
            assert.same({}, events(1))
        end)

        it('un instantané plus gros que le budget part seul', function()
            -- l'état d'une zone (32 Ko au plus) tient dans le budget par défaut : budget réduit pour l'essai
            cfg.snapshotBudgetBytes = 16384
            zones.define(OWNER, 'grande', AREA, bigState(20))
            zones.define(OWNER, 'loin', { x = 120.0, y = 0.0, radius = 100 }, { a = 1 })
            place(1, 0, 0)
            runPass()
            assert.equal(1, #of(STATE, 1))
            assert.equal(OWNER .. ':grande', of(STATE, 1)[1].args[2])
            sent = {}
            runPass()
            assert.equal(OWNER .. ':loin', of(STATE, 1)[1].args[2])
            cfg.snapshotBudgetBytes = 32768
        end)

        it('plafond de zones suivies : les plus lointaines attendent, alerte une fois par minute', function()
            cfg.maxSubscriptionsPerPlayer = 2
            for i = 1, 3 do zones.define(OWNER, 'z' .. i, { x = i * 1.0, y = 0.0, radius = 50 }) end
            place(1, 0, 0)
            runPass()
            assert.same({ OWNER .. ':z1', OWNER .. ':z2' }, zones.ofPlayer(1))
            local warnings = 0
            for _, line in ipairs(printed) do
                if line:find('les plus lointaines attendent', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(1, warnings)
            runPass()
            warnings = 0
            for _, line in ipairs(printed) do
                if line:find('les plus lointaines attendent', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(1, warnings)
            cfg.maxSubscriptionsPerPlayer = 256
        end)
    end)

    describe('retrait, remplacement, déplacement', function()
        it('remove : sortie aux abonnés à jour et en attente', function()
            local _, handle = zones.define(OWNER, 'place', AREA, bigState(20))
            place(1, 0, 0)
            place(2, 0, 0)
            local whole = string.rep('x', vAvA.config.server.net.maxBytes - 6 - #'vava_test:big')
            net.send(OWNER, nil, 2, 'vava_test:big', whole)
            net.send(OWNER, nil, 2, 'vava_test:big', whole)
            now = now - 999
            runPass()
            assert.equal(1, #of(STATE, 1))
            assert.equal(0, #of(STATE, 2))
            sent = {}
            assert.is_true(zones.remove(OWNER, 'place'))
            assert.same({ handle }, of(LEAVE, 1)[1].args[1])
            assert.same({ handle }, of(LEAVE, 2)[1].args[1])
            assert.equal(0, zones.stats().subscriptions)
            assert.equal(0, zones.stateBytes())
            assert.same({ false, 'unknown_zone' }, { zones.remove(OWNER, 'place') })
        end)

        it('replace : instantané aux abonnés à jour, révision + 1', function()
            zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'place', { a = 5 })
            assert.is_true(zones.replace(OWNER, 'place', { b = 2 }))
            local states = of(STATE, 1)
            assert.equal(1, #states)
            assert.same({ 2, { b = 2 } }, { states[1].args[3], states[1].args[4] })
            endTurn()
            assert.equal(0, #of(DIFF))
            local many = {}
            for i = 1, 257 do many['k' .. i] = i end
            assert.same({ false, 'too_many_keys' }, { zones.replace(OWNER, 'place', many) })
            assert.same({ false, 'too_large' }, { zones.replace(OWNER, 'place', bigState(40)) })
            assert.same({ false, 'unknown_zone' }, { zones.replace(OWNER, 'rien', {}) })
        end)

        it('move hors de portée : sortie au passage suivant ; move refusé', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 0, 0)
            runPass()
            assert.is_true(zones.move(OWNER, 'place', { x = 3000.0, y = 0.0, radius = 10 }))
            sent = {}
            runPass()
            assert.same({ LEAVE }, events(1))
            assert.same({ false, 'invalid_area' }, { zones.move(OWNER, 'place', { x = 0.0 }) })
            assert.same({ false, 'unknown_zone' }, { zones.move(OWNER, 'rien', AREA) })
            -- revenue à portée : entrée
            zones.move(OWNER, 'place', AREA)
            runPass()
            assert.equal(1, #of(STATE, 1))
        end)

        it('subscribers : liste triée des abonnés ; zone d’un autre module invisible', function()
            zones.define(OWNER, 'place', AREA)
            place(3, 0, 0)
            place(1, 0, 0)
            runPass()
            assert.same({ 1, 3 }, zones.subscribers(OWNER, 'place'))
            assert.same({ nil, 'unknown_zone' }, { zones.subscribers(OTHER, 'place') })
        end)
    end)

    describe('purges', function()
        it('purgePlayer : rien d’envoyé, plus aucune trace ; numéro redonné sans abonnement hérité', function()
            zones.define(OWNER, 'place', AREA)
            place(1, 0, 0)
            runPass()
            sent = {}
            characters = {}
            zones.purgePlayer(1)
            assert.same({}, events())
            assert.same({}, zones.ofPlayer(1))
            assert.equal(0, zones.stats().subscriptions)
            assert.same({}, zones.subscribers(OWNER, 'place'))
            runPass()
            assert.same({}, events())
            -- nouveau venu sur le même numéro, loin
            place(1, 4000, 4000)
            runPass()
            assert.same({}, events())
            assert.same({ false, 'not_subscribed' }, { registered['core:zones:resync'].handler(1, 1) })
        end)

        it('purgeOwner : zones du module oubliées sans envoi, celles des autres gardées', function()
            zones.define(OWNER, 'a', AREA, { x = 'abc' })
            zones.define(OTHER, 'b', AREA)
            place(1, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'a', { x = 'def' })
            zones.purgeOwner(OWNER)
            endTurn()
            assert.same({}, events())
            assert.same({}, zones.list(OWNER))
            assert.same({ OTHER .. ':b' }, zones.ofPlayer(1))
            assert.equal(1, zones.stats().subscriptions)
            runPass()
            assert.same({}, events())
            -- le module redémarré redéclare : nouveau numéro, entrée au passage
            local _, handle = zones.define(OWNER, 'a', AREA)
            assert.equal(3, handle)
            runPass()
            assert.equal(3, of(STATE, 1)[1].args[1])
        end)
    end)

    describe('resync', function()
        it('RPC du core : schéma borné, limite de la config', function()
            local entry = registered['core:zones:resync']
            assert.equal('core', entry.owner)
            assert.same({ { type = 'integer', min = 1, max = vAvA.RPC_MAX_ID } }, entry.options.args)
            assert.same(cfg.rateLimit, entry.options.rateLimit)
        end)

        it('non abonné → not_subscribed ; abonné → instantané à lui seul ; en attente → true sans envoi', function()
            local resync = registered['core:zones:resync'].handler
            local _, handle = zones.define(OWNER, 'place', AREA, { a = 1 })
            assert.same({ false, 'not_subscribed' }, { resync(1, handle) })
            assert.same({ false, 'not_subscribed' }, { resync(1, 999) })
            place(1, 0, 0)
            place(2, 0, 0)
            runPass()
            sent = {}
            zones.set(OWNER, 'place', { a = 2 })
            assert.same({ true }, { resync(1, handle) })
            -- différence en attente envoyée d'abord, puis l'instantané au seul demandeur
            assert.same({ DIFF, DIFF, STATE }, events())
            assert.equal(1, sent[3].target)
            assert.equal(2, sent[3].args[3])
            -- joueur en attente (saturé) : rien de plus
            local big = zones.define(OWNER, 'grande', { x = 0.0, y = 0.0, radius = 10 }, bigState(20))
            assert.is_true(big)
            local whole = string.rep('x', vAvA.config.server.net.maxBytes - 6 - #'vava_test:big')
            net.send(OWNER, nil, 2, 'vava_test:big', whole)
            net.send(OWNER, nil, 2, 'vava_test:big', whole)
            now = now - 999
            runPass()
            sent = {}
            assert.same({ true }, { resync(2, 2) })
            assert.same({}, events(2))
        end)
    end)

    -- relecture réseau de T-014
    describe('coût du passage', function()
        local candidatesCalls, sorts

        --- Recharge le service avec une grille espionnée et un tri compté.
        local function reloadSpied()
            candidatesCalls, sorts = 0, 0
            local realSort, realNew = table.sort, vAvA.zonegrid.new
            table.sort = function(...)
                sorts = sorts + 1
                return realSort(...)
            end
            vAvA.zonegrid.new = function(size)
                local grid = realNew(size)
                local candidates = grid.candidates
                grid.candidates = function(self, x, y)
                    candidatesCalls = candidatesCalls + 1
                    return candidates(self, x, y)
                end
                return grid
            end
            helper.load('server/core/zones.lua')
            table.sort, vAvA.zonegrid.new = realSort, realNew
            zones = vAvA.zones
            zones.start()
        end

        it('au plafond de zones suivies : rien n’est construit ni trié, alerte une fois par minute', function()
            reloadSpied()
            cfg.maxSubscriptionsPerPlayer = 10
            for i = 1, 50 do zones.define(OWNER, 'z' .. i, { x = i * 1.0, y = 0.0, radius = 100 }) end
            place(1, 0, 0)
            runPass()
            -- les 10 plus proches, choisies sans tri complet
            local names = zones.ofPlayer(1)
            local expected = {}
            for i = 1, 10 do expected[i] = OWNER .. ':z' .. i end
            table.sort(expected)
            assert.same(expected, names)
            local before = sorts
            for step = 1, 5 do
                go(1, step * 2.0, 0)   -- bouge : calcul complet à chaque passage
                runPass()
            end
            assert.equal(before, sorts)
            local warnings = 0
            for _, line in ipairs(printed) do
                if line:find('les plus lointaines attendent', 1, true) then warnings = warnings + 1 end
            end
            assert.equal(1, warnings)
        end)

        it('sélection partielle : les plus proches, quel que soit l’ordre des candidates', function()
            cfg.maxSubscriptionsPerPlayer = 7
            local distances = { 40, 3, 77, 12, 5, 90, 1, 66, 25, 8, 50, 2, 31, 99, 14 }
            for i, d in ipairs(distances) do zones.define(OWNER, 'z' .. i, { x = d * 1.0, y = 0.0, radius = 100 }) end
            place(1, 0, 0)
            runPass()
            local got = {}
            for _, name in ipairs(zones.ofPlayer(1)) do got[#got + 1] = distances[tonumber(name:match('z(%d+)$'))] end
            table.sort(got)
            assert.same({ 1, 2, 3, 5, 8, 12, 14 }, got)
        end)

        it('joueur immobile : pas recalculé ; recalculé au-delà de 1 m, à un changement d’instance ou de zones', function()
            reloadSpied()
            zones.define(OWNER, 'place', AREA)
            place(1, 0, 0)
            runPass()
            assert.equal(1, candidatesCalls)
            runPass()
            go(1, 0.6, 0)
            runPass()
            assert.equal(1, candidatesCalls)
            go(1, 0.6, 0.9)   -- 1,08 m du dernier calcul
            runPass()
            assert.equal(2, candidatesCalls)
            runPass()
            assert.equal(2, candidatesCalls)
            buckets[1] = 4
            runPass()
            assert.equal(3, candidatesCalls)
            buckets[1] = 0
            runPass()
            assert.equal(4, candidatesCalls)
            -- une zone déclarée à côté d'un joueur immobile lui arrive au passage suivant
            sent = {}
            zones.define(OWNER, 'voisine', AREA)
            runPass()
            assert.equal(5, candidatesCalls)
            assert.equal(1, #of(STATE, 1))
            -- zone déplacée ou retirée : recalcul (sortie)
            zones.move(OWNER, 'voisine', { x = 3000.0, y = 0.0, radius = 10 })
            sent = {}
            runPass()
            assert.same({ LEAVE }, events(1))
        end)

        it('joueur immobile : ses instantanés en attente partent quand même', function()
            for i = 1, 5 do
                zones.define(OWNER, 'z' .. i, { x = i * 10.0, y = 0.0, radius = 100 }, bigState(10))
            end
            place(1, 0, 0)
            runPass()
            assert.equal(3, #of(STATE, 1))
            sent = {}
            runPass()
            assert.equal(2, #of(STATE, 1))
        end)

        it('refreshPlayer relit la position (cache de 50 ms oublié) et recalcule', function()
            zones.define(OWNER, 'ici', AREA)
            zones.define(OWNER, 'labas', { x = 5000.0, y = 0.0, radius = 50 })
            place(1, 0, 0)
            runPass()
            sent = {}
            go(1, 5000, 0)          -- même instant : la position gardée serait l'ancienne
            zones.refreshPlayer(1)
            assert.same({ LEAVE, STATE }, events(1))
        end)
    end)

    -- relecture sécurité de T-014 (M-1)
    it('purgeOwner d’une ressource encore démarrée (setup en échec) : sorties envoyées, une par joueur', function()
        _G.GetResourceState = function(resource) return resource == OWNER and 'started' or 'stopped' end
        local _, a = zones.define(OWNER, 'a', AREA)
        local _, b = zones.define(OWNER, 'b', AREA)
        zones.define(OTHER, 'c', AREA)
        place(1, 0, 0)
        place(2, 0, 0)
        runPass()
        sent = {}
        zones.purgeOwner(OWNER)
        assert.same({ LEAVE, LEAVE }, events())
        assert.same({ a, b }, of(LEAVE, 1)[1].args[1])
        assert.same({ a, b }, of(LEAVE, 2)[1].args[1])
        sent = {}
        zones.purgeOwner(OTHER)
        assert.same({}, events())
        _G.GetResourceState = nil
    end)

    describe('compteur et cibles', function()
        it('état et différence comptés sous la ressource de la zone, sorties sous vAvA_core ; jamais -1', function()
            local targets = {}
            local realTrigger = _G.TriggerClientEvent
            _G.TriggerClientEvent = function(event, target, ...)
                targets[#targets + 1] = target
                return realTrigger(event, target, ...)
            end
            zones.define(OWNER, 'place', AREA, { a = 1 })
            place(1, 0, 0)
            runPass()
            zones.set(OWNER, 'place', { a = 2 })
            endTurn()
            zones.remove(OWNER, 'place')
            local mine = net.stats({ resource = OWNER })
            local labels = {}
            for _, event in ipairs(mine.events) do labels[#labels + 1] = event.label end
            table.sort(labels)
            assert.same({ DIFF, STATE }, labels)
            local core = net.stats({ resource = 'vAvA_core' })
            assert.equal(LEAVE, core.events[1].label)
            for _, target in ipairs(targets) do assert.is_true(target > 0) end
        end)
    end)
end)
