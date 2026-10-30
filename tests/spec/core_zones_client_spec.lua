local helper = require('tests.helper')

-- Zones suivies côté client (client/core/zones.lua, core 0.11.0, T-014) : réception, notifications aux modules,
-- instantané redemandé (préavis dépassé, trou, échec de transport), nettoyage. Évènements, minuteries, RPC et threads en
-- doublures ; hooks réels.
describe('vAvA.zones (client)', function()
    local zones, hooks, EVENTS, cfg, netHandlers, calls, answers, waits, printed, realPrint

    local OWNER, OTHER = 'vava_test', 'vava_autre'

    before_each(function()
        helper.reset()
        netHandlers, calls, answers, waits, printed = {}, {}, {}, {}, {}
        realPrint = _G.print
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        _G.GetGameTimer = function() return 0 end
        _G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
        _G.Wait = function(ms) waits[#waits + 1] = ms end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/lib/zonereplica.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
        })
        vAvA.rpc = {
            call = function(_, name, ...)
                calls[#calls + 1] = { name = name, args = table.pack(...) }
                local answer = table.remove(answers, 1) or { true, true }
                return table.unpack(answer)
            end,
        }
        helper.load('client/core/zones.lua')
        zones, hooks, EVENTS, cfg = vAvA.zones, vAvA.hooks, vAvA.EVENTS, vAvA.config.shared.zones
        zones.start()
        hooks.runAfter('core:character:loaded', { id = 1 })
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function state(handle, name, revision, value)
        netHandlers[EVENTS.ZONE_STATE](handle, name, revision, value)
    end

    local function diff(handle, revision, set, removed)
        netHandlers[EVENTS.ZONE_DIFF](handle, revision, set, removed)
    end

    --- Échéance des minuteries posées jusqu'ici (pas de celles qu'elles posent elles-mêmes).
    local function fire(ms)
        local count = #helper.timers
        for i = 1, count do
            local timer = helper.timers[i]
            if (ms == nil or timer.ms == ms) and not timer.done then
                timer.done = true
                timer.fn()
            end
        end
    end

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    --- Gestionnaire qui garde une copie de ce qu'il reçoit (en jeu, le module reçoit une copie : autre ressource).
    local function recorder()
        local received = {}
        local handler = function(kind, id, a, b) received[#received + 1] = { kind, id, copy(a), copy(b) } end
        return handler, received
    end

    it('instantané, puis différences : enter, change ; leave à la sortie', function()
        local handler, received = recorder()
        assert.is_true(zones.watch(OWNER, handler))
        state(4, OWNER .. ':place', 1, { a = 1 })
        diff(4, 2, { a = 2 }, nil)
        diff(4, 3, nil, { 'a' })
        netHandlers[EVENTS.ZONE_LEAVE]({ 4 })
        assert.same({
            { 'enter', 'place', { a = 1 } },
            { 'change', 'place', { a = 2 }, {} },
            { 'change', 'place', {}, { 'a' } },
            { 'leave', 'place' },
        }, received)
        assert.same({}, zones.list(OWNER))
    end)

    it('get et list : zones du module seulement, à jour', function()
        state(1, OWNER .. ':b', 3, { x = 1 })
        state(2, OWNER .. ':a', 1, {})
        state(3, OTHER .. ':c', 1, {})
        assert.same({ 'a', 'b' }, zones.list(OWNER))
        local value, revision = zones.get(OWNER, 'b')
        assert.same({ x = 1 }, value)
        assert.equal(3, revision)
        assert.is_nil(zones.get(OWNER, 'c'))
        assert.is_nil(zones.get(OTHER, 'b'))
        assert.is_nil(zones.get(OWNER, 12))
    end)

    it('watch rejoue enter, au tour suivant, pour les zones déjà à jour', function()
        state(1, OWNER .. ':a', 1, { v = 1 })
        state(2, OWNER .. ':b', 1, { v = 2 })
        state(3, OTHER .. ':c', 1, {})
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        assert.same({}, received)
        fire(0)
        assert.same({ { 'enter', 'a', { v = 1 } }, { 'enter', 'b', { v = 2 } } }, received)
        -- un second watch remplace le premier et rejoue
        local second, again = recorder()
        zones.watch(OWNER, second)
        fire(0)
        assert.equal(2, #again)
        assert.equal(2, #received)
        assert.same({ false, 'handler non appelable' }, { zones.watch(OWNER, 'pas une fonction') })
    end)

    it('gestionnaire en erreur : isolé, écrit en console, les autres modules notifiés', function()
        zones.watch(OWNER, function() error('panne') end)
        local handler, received = recorder()
        zones.watch(OTHER, handler)
        state(1, OWNER .. ':a', 1, {})
        state(2, OTHER .. ':b', 1, {})
        assert.same({ { 'enter', 'b', {} } }, received)
        local found = false
        for _, line in ipairs(printed) do
            if line:find(OWNER, 1, true) and line:find('panne', 1, true) then found = true end
        end
        assert.is_true(found)
        -- la sortie part quand même au module qui avait reçu enter
        netHandlers[EVENTS.ZONE_LEAVE]({ 2 })
        assert.same({ 'leave', 'b' }, received[2])
    end)

    it('zones d’un autre module jamais notifiées', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        state(1, OTHER .. ':a', 1, {})
        diff(1, 2, { x = 1 })
        netHandlers[EVENTS.ZONE_LEAVE]({ 1 })
        assert.same({}, received)
    end)

    it('préavis puis échéance sans instantané : instantané redemandé', function()
        netHandlers[EVENTS.ZONE_PENDING](5, 1, 2000)
        local timer = helper.timers[#helper.timers]
        assert.equal(2000 + cfg.awaitMarginMs, timer.ms)
        -- différences arrivées avant l'instantané : gardées
        diff(5, 2, { a = 2 })
        assert.same({}, calls)
        timer.fn()
        assert.equal(1, #calls)
        assert.equal('core:zones:resync', calls[1].name)
        assert.equal(5, calls[1].args[1])
    end)

    it('préavis puis instantané à temps : rien de redemandé, différences gardées appliquées', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        netHandlers[EVENTS.ZONE_PENDING](5, 1, 99999999)
        assert.equal(cfg.maxAwaitMs, helper.timers[#helper.timers].ms)
        diff(5, 2, { a = 2 })
        state(5, OWNER .. ':place', 1, { a = 1, b = 1 })
        assert.same({ { 'enter', 'place', { a = 2, b = 1 } } }, received)
        fire()
        assert.same({}, calls)
    end)

    it('trou dans les révisions : instantané redemandé aussitôt', function()
        state(1, OWNER .. ':place', 1, {})
        diff(1, 3, { a = 3 })
        assert.equal(1, #calls)
        assert.equal(1, calls[1].args[1])
    end)

    it('not_subscribed : zone retirée, leave au module', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        state(1, OWNER .. ':place', 1, {})
        answers = { { true, false, 'not_subscribed' } }
        diff(1, 3, { a = 3 })
        assert.same({ 'leave', 'place' }, received[#received])
        assert.same({}, zones.list(OWNER))
    end)

    it('rate_limited : nouvel essai à 5 s puis 10 s, jusqu’à la réponse', function()
        state(1, OWNER .. ':place', 1, {})
        answers = { { false, 'rate_limited' }, { false, 'timeout' }, { true, true } }
        diff(1, 3, { a = 3 })
        assert.equal(3, #calls)
        assert.same({ cfg.resyncRetryMs, cfg.resyncRetryMs * 2 }, waits)
        -- accepté : l'instantané reste attendu, redemandé s'il n'arrive pas
        assert.equal(cfg.maxAwaitMs, helper.timers[#helper.timers].ms)
    end)

    it('une seule demande à la fois par zone', function()
        state(1, OWNER .. ':place', 1, {})
        local blocked = true
        vAvA.rpc.call = function(_, name, ...)
            calls[#calls + 1] = { name = name, args = table.pack(...) }
            if blocked then
                blocked = false
                diff(1, 5, { a = 5 })   -- arrive pendant la demande
            end
            return true, true
        end
        diff(1, 3, { a = 3 })
        assert.equal(1, #calls)
    end)

    it('valeurs mal formées ignorées', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        state(0, OWNER .. ':a', 1, {})
        state(1.5, OWNER .. ':a', 1, {})
        state(1, 'sans_deux_points', 1, {})
        state(1, OWNER .. ':a b', 1, {})
        state(1, OWNER .. ':' .. string.rep('a', 120), 1, {})
        state(1, OWNER .. ':a', 0, {})
        state(1, OWNER .. ':a', 1, 'état')
        state(1, 12, 1, {})
        netHandlers[EVENTS.ZONE_PENDING](1, 1, -5)
        netHandlers[EVENTS.ZONE_PENDING]('1', 1, 5)
        diff(1, 2, 'valeurs')
        diff(1, 2, nil, { 1, 2 })
        diff(1, 2, nil, { a = 'b' })
        netHandlers[EVENTS.ZONE_LEAVE]('tout')
        local many = {}
        for i = 1, 257 do many[i] = i end
        netHandlers[EVENTS.ZONE_LEAVE](many)
        assert.same({}, received)
        assert.same({}, calls)
        assert.same({}, zones.list(OWNER))
    end)

    it('déchargement : leave partout ; rien n’est gardé avant le chargement suivant', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        state(1, OWNER .. ':a', 1, {})
        state(2, OWNER .. ':b', 1, {})
        hooks.runAfter('core:character:unloaded', { id = 1 })
        assert.same({ { 'enter', 'a', {} }, { 'enter', 'b', {} }, { 'leave', 'a' }, { 'leave', 'b' } }, received)
        assert.same({}, zones.list(OWNER))
        -- un instantané latent parti avant le déchargement, arrivé après : ignoré
        state(3, OWNER .. ':c', 1, {})
        assert.same({}, zones.list(OWNER))
        hooks.runAfter('core:character:selection', {})
        hooks.runAfter('core:character:loaded', { id = 2 })
        state(3, OWNER .. ':c', 1, {})
        assert.same({ 'c' }, zones.list(OWNER))
    end)

    it('arrêt d’une ressource : ses zones et son gestionnaire oubliés, sans notification', function()
        local handler, received = recorder()
        zones.watch(OWNER, handler)
        local other, otherReceived = recorder()
        zones.watch(OTHER, other)
        state(1, OWNER .. ':a', 1, {})
        state(2, OTHER .. ':b', 1, {})
        zones.purgeOwner(OWNER)
        assert.same({ { 'enter', 'a', {} } }, received)
        assert.same({}, zones.list(OWNER))
        assert.same({ 'b' }, zones.list(OTHER))
        assert.equal(1, #otherReceived)
        -- minuterie d'une zone oubliée : sans effet
        netHandlers[EVENTS.ZONE_PENDING](9, 1, 0)
        zones.purgeOwner('personne')
        fire()
    end)
end)
