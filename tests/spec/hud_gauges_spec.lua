local helper = require('tests.helper')

-- Jauges de vava_hud (modules/vava_hud/client/gauges.lua réel, 1.8.0, T-114) avec un faux pont vers la page qui note
-- chaque message : remontée animée par la page (`setGauge(id, valeur, refill)`), validée, gardée, projetée au
-- rechargement de la page ; sans remontée, le comportement de 1.7.0. Contrat des messages :
-- docs/plan/rapports/T-114-contrat.md.

local OWNER, ID = 'vava_combat', 'vava_combat:endurance'

describe('vava_hud jauges : remontée (1.8.0)', function()
    local gauges, messages, clock

    local function last() return messages[#messages] end

    before_each(function()
        helper.reset()
        VavaHud = nil
        messages, clock = {}, 10000
        _G.GetGameTimer = function() return clock end
        helper.load('modules/vava_hud/config_client.lua')
        VavaHud.nui = { send = function(action, payload) messages[#messages + 1] = { action = action, payload = payload } end }
        helper.load('modules/vava_hud/client/gauges.lua')
        gauges = VavaHud.gauges
        assert.is_true(gauges.define(OWNER, ID, { label = 'Endurance', icon = 'nui://vava_combat/web/icons/endurance.svg',
            order = 60, low = 0.25, critical = 0.1 }))
        messages = {}
    end)

    after_each(function()
        _G.GetGameTimer = nil
        VavaHud = nil
    end)

    it('sans remontée : comme 1.7.0 (même valeur : aucun message)', function()
        assert.is_true(gauges.set(OWNER, ID, 0.5))
        assert.same({ action = 'value', payload = { id = ID, value = 0.5 } }, last())
        assert.is_true(gauges.set(OWNER, ID, 0.5))
        assert.equal(1, #messages)
        assert.same({ false, 'not_owner' }, { gauges.set('vava_needs', ID, 0.4) })
        assert.same({ false, 'invalid_value' }, { gauges.set(OWNER, ID, 0 / 0) })
        assert.equal(1, #messages)
    end)

    it('remontée : un message avec refill ; la même aussitôt : aucun ; une autre : un message', function()
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 1000 }))
        assert.same({ action = 'value', payload = { id = ID, value = 0.3, refill = { perSecond = 0.2, delayMs = 1000 } } },
            last())
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 1000 }))
        assert.equal(1, #messages)
        -- même départ à 1 ms près (l'appel arrive 1 ms plus tard, le départ est le même)
        clock = clock + 1
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 999 }))
        assert.equal(1, #messages)
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 0.15, delayMs = 999 }))
        assert.equal(2, #messages)
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 0.15, delayMs = 500 }))
        assert.equal(3, #messages)
    end)

    it('remontée invalide : invalid_refill, aucun message', function()
        for _, bad in ipairs({
            { perSecond = 0, delayMs = 0 }, { perSecond = -1, delayMs = 0 }, { perSecond = 11, delayMs = 0 },
            { perSecond = 0 / 0, delayMs = 0 }, { perSecond = math.huge, delayMs = 0 },
            { perSecond = 0.2, delayMs = -1 }, { perSecond = 0.2, delayMs = 60001 }, { perSecond = 0.2, delayMs = 1.5 },
            { perSecond = 0.2, delayMs = 0 / 0 }, { perSecond = 0.2 }, { delayMs = 0 },
            { perSecond = 0.2, delayMs = 0, color = 'ambre' }, { 0.2, 0 }, 'vite', 1,
        }) do
            assert.same({ false, 'invalid_refill' }, { gauges.set(OWNER, ID, 0.3, bad) })
        end
        assert.equal(0, #messages)
        -- bornes comprises
        assert.is_true(gauges.set(OWNER, ID, 0.3, { perSecond = 10, delayMs = 60000 }))
        assert.is_true(gauges.set(OWNER, ID, 0.4, { perSecond = 0.001, delayMs = 0 }))
        assert.equal(2, #messages)
    end)

    it('jauge pleine : jamais de remontée envoyée', function()
        assert.is_true(gauges.set(OWNER, ID, 0.5))
        assert.is_true(gauges.set(OWNER, ID, 1, { perSecond = 0.2, delayMs = 1000 }))
        assert.same({ id = ID, value = 1 }, last().payload)
        assert.is_true(gauges.set(OWNER, ID, 1.4, { perSecond = 0.2, delayMs = 1000 }))
        assert.equal(2, #messages)
    end)

    it('all() : valeur projetée et attente restante ; pleine : sans refill', function()
        gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 1000 })
        local start = clock
        clock = start + 2000
        local entry = gauges.all()[1]
        assert.near(0.5, entry.value, 1e-9)
        assert.same({ perSecond = 0.2, delayMs = 0 }, entry.refill)
        clock = start + 500
        entry = gauges.all()[1]
        assert.equal(0.3, entry.value)
        assert.same({ perSecond = 0.2, delayMs = 500 }, entry.refill)
        clock = start + 6000
        entry = gauges.all()[1]
        assert.equal(1, entry.value)
        assert.is_nil(entry.refill)
        -- forme de 1.7.0 gardée
        assert.same({ 'active', 'critical', 'icon', 'id', 'label', 'low', 'order', 'value' }, (function()
            local keys = {}
            for key in pairs(entry) do keys[#keys + 1] = key end
            table.sort(keys)
            return keys
        end)())
    end)

    it('redéclarée pendant une remontée : valeur et remontée gardées, define projeté', function()
        gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 1000 })
        clock = clock + 1500
        assert.is_true(gauges.define(OWNER, ID, { label = 'Endurance', icon = 'nui://vava_combat/web/icons/endurance.svg',
            order = 60, low = 0.25, critical = 0.1 }))
        local payload = last().payload
        assert.equal('define', last().action)
        assert.near(0.4, payload.value, 1e-9)
        assert.same({ perSecond = 0.2, delayMs = 0 }, payload.refill)
    end)

    it('valeur sans remontée après une remontée : remontée oubliée, un message (même valeur de départ)', function()
        gauges.set(OWNER, ID, 0.3, { perSecond = 0.2, delayMs = 1000 })
        assert.is_true(gauges.set(OWNER, ID, 0.3))
        assert.equal(2, #messages)
        assert.same({ id = ID, value = 0.3 }, last().payload)
        clock = clock + 5000
        assert.equal(0.3, gauges.all()[1].value)
        assert.is_nil(gauges.all()[1].refill)
    end)
end)
