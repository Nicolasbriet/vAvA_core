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

    it('rappelle un refus durable au plus toutes les 10 min, avec le nombre de refus', function()
        local now = 1000
        _G.GetGameTimer = function() return now end
        helper.load('modules/vava_gathering/server/share.lua')
        share = VavaGathering.share
        answers.define = {}
        for _ = 1, 4 do answers.define[#answers.define + 1] = { false, 'full' } end
        assert.is_false(share.declare(FORET, {}))
        now = now + 60000
        assert.is_false(share.declare(FORET, {}))
        assert.is_false(share.declare(FORET, {}))
        assert.equal(1, #errors)
        now = now + 600000
        assert.is_false(share.declare(FORET, {}))
        assert.equal(2, #errors)
        assert.truthy(errors[2]:find('toujours refusée', 1, true))
        assert.truthy(errors[2]:find('3 refus', 1, true))
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

-- T-102 : diffusion des changements de l'Atelier (server/share.lua › touch, flush). Règles documentées : spec T-102
-- § 6.4, README du module (« Atelier de la récolte ») :
--   une zone changée est seulement notée ; `flush` (au dernier appel d'un lot, ou par la boucle lente au-delà de
--   `editor.flushGraceMs`) traite chaque zone notée une fois : déclarée si elle est nouvelle ; déplacée si son cercle
--   change, puis sa différence envoyée par paquets de 64 clés dans le même tour ; rien si rien de visible ne change ;
--   retirée si elle n'existe plus ; l'empreinte de la carte est recalculée après.
describe('vava_gathering share : diffusion de l’Atelier', function()
    local share, calls, answers, errors, now, flushed
    local zonestate
    -- zones et nœuds du « catalogue » de l'essai
    local zones, nodes

    local function answer(fn)
        local queued = answers[fn]
        if queued and #queued > 0 then return table.unpack(table.remove(queued, 1)) end
        return true
    end

    local function names()
        local list = {}
        for i, call in ipairs(calls) do list[i] = call.fn end
        return list
    end

    local function build(id)
        local def = zones[id]
        if not def then return nil, nil end
        return def, zonestate.build({ band = 'normal', scarred = false }, nodes[id] or {}, function() return 3 end, def)
    end

    before_each(function()
        helper.reset()
        calls, answers, errors, flushed = {}, {}, {}, 0
        now = 1000
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
        })
        zonestate = VavaGathering.zonestate
        _G.GetGameTimer = function() return now end
        VavaGathering.log = { error = function(fmt, ...) errors[#errors + 1] = fmt:format(...) end }
        local function record(fn)
            return function(...)
                calls[#calls + 1] = { fn = fn, args = table.pack(...) }
                return answer(fn)
            end
        end
        VavaGathering.bridge = {
            ZoneDefine = record('define'), ZoneMove = record('move'), ZoneSet = record('set'),
            ZoneReplace = record('replace'), ZoneRemove = record('remove'),
        }
        zones = { bois = { id = 'bois', label = 'Bois des Essais', kind = 'foret', x = 2000.0, y = 2000.0, z = 30.0,
            radius = 60.0 } }
        nodes = { bois = {} }
        VavaGathering.catalog = { nodesOf = function(id) return nodes[id] or {} end }
        helper.load('modules/vava_gathering/server/share.lua')
        share = VavaGathering.share
        share.configure(build, function() flushed = flushed + 1 end)
    end)

    local function point(id, x)
        return { id = id, resource = 'chene', x = x, y = 2000.0, z = 30.0, heading = 0.0 }
    end

    it('ne diffuse rien à la note, tout au flush : zone nouvelle déclarée entière avec ses points', function()
        for i = 1, 5 do nodes.bois[i] = point('chene_' .. i, 2000.0 + 3 * i) end
        share.touch('bois')
        share.touch('bois')
        assert.same({}, names())
        share.flush()
        assert.same({ 'define' }, names())
        local state = calls[1].args[3]
        assert.same({ l = 'Bois des Essais', k = 'foret', x = 2000.0, y = 2000.0, z = 30.0, r = 60.0 }, state.def)
        assert.is_not_nil(state['p:chene_5'])
        assert.equal(1, flushed)
        -- déjà diffusée : un second flush ne fait rien partir
        calls = {}
        share.flush()
        assert.same({}, names())
        assert.equal(1, flushed)
    end)

    it('cinq points ajoutés à une zone déclarée : une seule différence, sans déplacement', function()
        share.touch('bois')
        share.flush()
        calls = {}
        for i = 1, 5 do nodes.bois[i] = point('chene_' .. i, 2000.0 + 3 * i) end
        share.touch('bois')
        share.flush()
        assert.same({ 'set' }, names())
        local changes, removed = calls[1].args[2], calls[1].args[3]
        local count = 0
        for _ in pairs(changes) do count = count + 1 end
        assert.equal(10, count)
        assert.is_nil(removed)
    end)

    it('point retiré : ses deux clés retirées ; rien à envoyer si rien de visible ne change', function()
        nodes.bois = { point('chene_1', 2003.0), point('chene_2', 2006.0) }
        share.touch('bois')
        share.flush()
        calls = {}
        nodes.bois = { point('chene_1', 2003.0) }
        share.touch('bois')
        share.flush()
        assert.same({ 'set' }, names())
        assert.same({}, calls[1].args[2])
        assert.same({ 'n:chene_2', 'p:chene_2' }, calls[1].args[3])
        calls = {}
        zones.bois.cost = 9.5
        share.touch('bois')
        share.flush()
        assert.same({}, names())
    end)

    it('zone redessinée : déplacée puis sa `def` changée, dans le même passage', function()
        share.touch('bois')
        share.flush()
        calls = {}
        zones.bois.radius = 80.0
        share.touch('bois')
        share.flush()
        assert.same({ 'move', 'set' }, names())
        assert.equal(80.0, calls[1].args[2].radius)
        assert.same({ 'def' }, (function()
            local keys = {}
            for key in pairs(calls[2].args[2]) do keys[#keys + 1] = key end
            return keys
        end)())
    end)

    it('un point qui sort du rayon élargit le cercle d’intérêt (déplacement) sans redéclarer', function()
        share.touch('bois')
        share.flush()
        calls = {}
        nodes.bois = { point('chene_1', 2064.0) }
        share.touch('bois')
        share.flush()
        assert.same({ 'move', 'set' }, names())
        assert.equal(64.0, calls[1].args[2].radius)
    end)

    it('zone retirée : retirée du core, puis plus rien ; une zone jamais déclarée ne fait rien partir', function()
        share.touch('bois')
        share.flush()
        calls = {}
        zones.bois = nil
        share.touch('bois')
        share.flush()
        assert.same({ 'remove' }, names())
        assert.is_false(share.isDeclared('bois'))
        calls = {}
        share.touch('autre')
        share.flush()
        assert.same({}, names())
    end)

    it('envoie une différence de plus de 64 clés en plusieurs paquets dans le même passage', function()
        share.touch('bois')
        share.flush()
        calls = {}
        for i = 1, 40 do nodes.bois[i] = point(string.format('p%02d', i), 2000.0 + i) end
        share.touch('bois')
        share.flush()
        assert.same({ 'set', 'set' }, names())
    end)

    it('un envoi refusé fait oublier la zone : elle sera redéclarée entière', function()
        share.touch('bois')
        share.flush()
        answers.set = { { false, 'too_many_keys' } }
        nodes.bois = { point('chene_1', 2003.0) }
        share.touch('bois')
        share.flush()
        assert.is_false(share.isDeclared('bois'))
        assert.equal(1, #errors)
        calls = {}
        share.touch('bois')
        share.flush()
        assert.same({ 'define' }, names())
    end)

    it('garde de la boucle lente : seules les zones notées depuis plus du délai partent', function()
        zones.autre = { id = 'autre', label = 'Autre', kind = 'mine', x = 0.0, y = 0.0, z = 0.0, radius = 20.0 }
        share.touch('bois')
        now = now + 1500
        share.touch('autre')
        now = now + 600
        share.flush(2000)
        assert.same({ 'define' }, names())
        assert.equal('bois', calls[1].args[1])
        calls = {}
        now = now + 2000
        share.flush(2000)
        assert.same({ 'define' }, names())
        assert.equal('autre', calls[1].args[1])
    end)

    it('n’envoie plus rien après l’arrêt du module', function()
        share.touch('bois')
        share.stop()
        share.flush()
        assert.same({}, names())
    end)

    it('garde l’état déclaré à jour après une récolte : la différence suivante est juste', function()
        nodes.bois = { point('chene_1', 2003.0) }
        share.touch('bois')
        share.flush()
        assert.is_true(share.set('bois', 'n:chene_1', 2))
        calls = {}
        -- l'état neuf dit 3 charges (build) : la différence les renvoie, une seule clé
        share.touch('bois')
        share.flush()
        assert.same({ 'set' }, names())
        assert.same({ ['n:chene_1'] = 3 }, calls[1].args[2])
    end)
end)
