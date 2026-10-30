local helper = require('tests.helper')

-- Zones de récolte partagées par les abonnements de zone du core (modules/vava_gathering/server/share.lua, 1.6.0,
-- T-015), avec des doublures du bridge (core.zones) et du catalogue. Règles documentées : README du module (« Zones et
-- nœuds ») :
--   une zone du core par zone de récolte, déclarée avec son état entier ; un changement ne part que pour une zone
--   déclarée (sinon il partira entier à sa déclaration) ; une zone déjà connue du core est déplacée et son état
--   remplacé ; un refus est écrit une fois par raison et la zone redéclarée au passage suivant ; rien n'est envoyé
--   après l'arrêt du module ; anciennes clés GlobalState effacées seulement si elles existent.

describe('vava_gathering share', function()
    local share, calls, answers, errors, globals

    local FORET = { id = 'foret_brume', x = -320.0, y = -880.0, z = 31.0, radius = 120.0 }
    local NODES = {
        foret_brume = { { id = 'foret_brume_chene_1', x = -300.0, y = -900.0, z = 31.0 }, { id = 'foret_brume_pin_1', x = -320.0, y = -730.0, z = 31.0 } },
    }

    local function answer(fn)
        local queued = answers[fn]
        if queued and #queued > 0 then return table.unpack(table.remove(queued, 1)) end
        return true
    end

    before_each(function()
        helper.reset()
        calls, answers, errors = {}, {}, {}
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        globals = { ['vava_gathering:zone:foret_brume'] = { band = 'normal' } }
        local writes = {}
        _G.GlobalState = setmetatable({}, {
            __index = function(_, key) return globals[key] end,
            __newindex = function(_, key, value)
                writes[#writes + 1] = key
                globals[key] = value
            end,
        })
        globals.__writes = writes
        VavaGathering.log = { error = function(fmt, ...) errors[#errors + 1] = fmt:format(...) end }
        local function record(fn)
            return function(...)
                calls[#calls + 1] = { fn = fn, args = table.pack(...) }
                return answer(fn)
            end
        end
        VavaGathering.bridge = {
            ZoneDefine = record('define'), ZoneMove = record('move'), ZoneSet = record('set'), ZoneReplace = record('replace'),
        }
        VavaGathering.catalog = {
            nodesOf = function(id) return NODES[id] or {} end,
            zones = function() return { FORET } end,
            nodes = function() return { foret_brume_chene_1 = NODES.foret_brume[1], foret_brume_pin_1 = NODES.foret_brume[2] } end,
        }
        helper.load('modules/vava_gathering/server/share.lua')
        share = VavaGathering.share
    end)

    after_each(function()
        _G.GlobalState = nil
    end)

    local function names()
        local list = {}
        for i, call in ipairs(calls) do list[i] = call.fn end
        return list
    end

    it('déclare une zone avec son cercle (nœuds compris, marge de 100 m) et son état entier', function()
        local state = { zone = { band = 'normal', scarred = false }, ['n:foret_brume_chene_1'] = 3 }
        assert.is_true(share.declare(FORET, state))
        assert.same({ 'define' }, names())
        local args = calls[1].args
        assert.equal('foret_brume', args[1])
        assert.same({ x = -320.0, y = -880.0, z = 31.0, radius = 150.0, margin = 100.0 }, args[2])
        assert.same(state, args[3])
        assert.is_true(share.isDeclared('foret_brume'))
    end)

    it('n’envoie rien pour une zone pas encore déclarée', function()
        assert.is_false(share.set('foret_brume', 'n:foret_brume_chene_1', 2))
        assert.same({}, names())
    end)

    it('envoie une seule clé changée pour une zone déclarée', function()
        share.declare(FORET, {})
        calls = {}
        assert.is_true(share.set('foret_brume', 'n:foret_brume_chene_1', 2))
        assert.same({ 'set' }, names())
        assert.equal('foret_brume', calls[1].args[1])
        assert.same({ ['n:foret_brume_chene_1'] = 2 }, calls[1].args[2])
    end)

    it('redéclare une zone déjà déclarée : déplacée puis état remplacé', function()
        share.declare(FORET, {})
        calls = {}
        local state = { zone = { band = 'depleted', scarred = true } }
        assert.is_true(share.declare(FORET, state))
        assert.same({ 'move', 'replace' }, names())
        assert.same(state, calls[2].args[2])
    end)

    it('reprend une zone que le core connaît encore (exists) par déplacement et remplacement', function()
        answers.define = { { false, 'exists' } }
        assert.is_true(share.declare(FORET, {}))
        assert.same({ 'define', 'move', 'replace' }, names())
        assert.is_true(share.isDeclared('foret_brume'))
        assert.same({}, errors)
    end)

    it('écrit un refus une seule fois par raison, et le retente au passage suivant', function()
        answers.define = { { false, 'invalid_area' }, { false, 'invalid_area' }, { false, 'full' } }
        assert.is_false(share.declare(FORET, {}))
        assert.is_false(share.declare(FORET, {}))
        assert.equal(1, #errors)
        assert.truthy(errors[1]:find('invalid_area', 1, true))
        assert.is_false(share.declare(FORET, {}))
        assert.equal(2, #errors)
        assert.is_false(share.isDeclared('foret_brume'))
        assert.is_true(share.declare(FORET, {}))
        assert.is_true(share.isDeclared('foret_brume'))
    end)

    it('oublie une zone dont un changement est refusé : elle sera redéclarée entière', function()
        share.declare(FORET, {})
        answers.set = { { false, 'unknown_zone' } }
        assert.is_false(share.set('foret_brume', 'zone', { band = 'reduced', scarred = false }))
        assert.is_false(share.isDeclared('foret_brume'))
        assert.equal(1, #errors)
        calls = {}
        assert.is_false(share.set('foret_brume', 'zone', { band = 'normal', scarred = false }))
        assert.same({}, names())
    end)

    it('ne déclare ni n’envoie plus rien après l’arrêt du module', function()
        share.declare(FORET, {})
        calls = {}
        share.stop()
        assert.is_false(share.set('foret_brume', 'n:foret_brume_chene_1', 1))
        assert.is_false(share.declare(FORET, {}))
        assert.same({}, names())
        assert.same({}, errors)
    end)

    it('efface les seules anciennes clés GlobalState encore présentes', function()
        share.clearLegacy()
        assert.same({ 'vava_gathering:zone:foret_brume' }, globals.__writes)
        assert.is_nil(globals['vava_gathering:zone:foret_brume'])
        share.clearLegacy()
        assert.equal(1, #globals.__writes)
    end)
end)
