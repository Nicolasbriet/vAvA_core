local helper = require('tests.helper')

-- Débit montant d'un joueur filmé (T-047) :
--   - modules/vava_cameras/shared/budget.lua : admission (une seule vue en grand, planchers sous le budget) et
--     répartition (planchers, puis la vue en grand jusqu'à son plafond, puis les cases à parts égales). Valeurs
--     documentées : config.lua (`qualities`, `budget`) et README du module (« Débit montant du joueur filmé ») ;
--   - modules/vava_cameras/server/sessions.lua : refus `budget` après `too_many_viewers`, part de la nouvelle caméra
--     dans son ordre de départ, parts changées des autres annoncées au seul joueur filmé, débit rendu au départ d'un
--     spectateur, rien quand le joueur filmé s'en va.

local function loadBudget()
    helper.reset()
    helper.loadAll({
        'modules/vava_cameras/shared/constants.lua',
        'modules/vava_cameras/config.lua',
        'modules/vava_cameras/shared/budget.lua',
    })
    return VavaCameras.budget, VavaCameras.config
end

describe('vava_cameras budget (règle pure)', function()
    local budget, cfg

    before_each(function()
        budget, cfg = loadBudget()
    end)

    after_each(function()
        _G.VavaCameras = nil
    end)

    local function rates(full, tile)
        return budget.rates({ full = full, tile = tile }, cfg.qualities, cfg.budget.uplinkKbps)
    end

    it('garde les valeurs documentées (1 500 kbit/s, plafonds 1 200 et 250, planchers 600 et 120)', function()
        assert.equal(1500, cfg.budget.uplinkKbps)
        assert.equal(1, cfg.budget.perQuality.full)
        assert.same({ 1200, 600 }, { cfg.qualities.full.bitrateKbps, cfg.qualities.full.minKbps })
        assert.same({ 250, 120 }, { cfg.qualities.tile.bitrateKbps, cfg.qualities.tile.minKbps })
    end)

    -- { vues en grand, cases, débit de la vue en grand, débit d'une case } : tableau du README
    local TABLE = {
        { 1, 0, 1200, nil },
        { 0, 1, nil, 250 },
        { 0, 6, nil, 250 },
        { 1, 1, 1200, 250 },
        { 1, 2, 1200, 150 },
        { 1, 3, 1140, 120 },
        { 1, 4, 1020, 120 },
        { 1, 5, 900, 120 },
    }
    for _, row in ipairs(TABLE) do
        it(('répartit %d vue en grand et %d cases : %s / %s kbit/s'):format(row[1], row[2], tostring(row[3]),
            tostring(row[4])), function()
            local got = rates(row[1], row[2])
            assert.equal(row[3], got.full)
            assert.equal(row[4], got.tile)
        end)
    end

    it('ne dépasse jamais le budget, et donne à chacun au moins son plancher, au plus son plafond', function()
        for full = 0, 1 do
            for tile = 0, cfg.limits.viewersPerPlayer - full do
                local got = rates(full, tile)
                local total = (got.full or 0) * full + (got.tile or 0) * tile
                assert.is_true(total <= cfg.budget.uplinkKbps, ('%d + %d : %d'):format(full, tile, total))
                for quality, kbps in pairs(got) do
                    assert.is_true(math.type(kbps) == 'integer')
                    assert.is_true(kbps >= cfg.qualities[quality].minKbps)
                    assert.is_true(kbps <= cfg.qualities[quality].bitrateKbps)
                end
            end
        end
    end)

    it('ne rend une part que pour les qualités présentes', function()
        assert.same({}, rates(0, 0))
        assert.same({}, budget.rates({}, cfg.qualities, 1500))
        local got = rates(0, 3)
        assert.is_nil(got.full)
        assert.equal(250, got.tile)
    end)

    it('sert la vue en grand avant les cases', function()
        -- budget serré : la vue en grand prend le reste, les cases restent au plancher
        local got = budget.rates({ full = 1, tile = 2 }, cfg.qualities, 1000)
        assert.equal(1000 - 240, got.full)
        assert.equal(120, got.tile)
    end)

    it('réduit les planchers à proportion quand ils dépassent le budget, sans jamais le dépasser', function()
        local got = budget.rates({ full = 1, tile = 5 }, cfg.qualities, 600)
        assert.equal(300, got.full)
        assert.equal(60, got.tile)
        assert.is_true(got.full + 5 * got.tile <= 600)
    end)

    describe('admission', function()
        it('refuse une seconde vue en grand', function()
            assert.is_true(budget.admits({}, 'full', cfg.qualities, cfg.budget))
            assert.is_false(budget.admits({ full = 1 }, 'full', cfg.qualities, cfg.budget))
            assert.is_true(budget.admits({ full = 1 }, 'tile', cfg.qualities, cfg.budget))
        end)

        it('admet six spectateurs dont une vue en grand avec la configuration par défaut', function()
            assert.is_true(budget.admits({ full = 1, tile = 4 }, 'tile', cfg.qualities, cfg.budget))
            assert.is_true(budget.admits({ tile = 5 }, 'full', cfg.qualities, cfg.budget))
            assert.is_true(budget.admits({ tile = 5 }, 'tile', cfg.qualities, cfg.budget))
        end)

        it('refuse quand la somme des planchers dépasserait le budget', function()
            local rules = { uplinkKbps = 800, perQuality = { full = 1 } }
            assert.is_true(budget.admits({ full = 1 }, 'tile', cfg.qualities, rules))      -- 720
            assert.is_false(budget.admits({ full = 1, tile = 1 }, 'tile', cfg.qualities, rules))   -- 840
            assert.is_true(budget.admits({ tile = 5 }, 'tile', cfg.qualities, rules))      -- 720
        end)

        it('refuse une qualité inconnue', function()
            assert.is_false(budget.admits({}, 'huge', cfg.qualities, cfg.budget))
        end)

        it('laisse sans borne de nombre une qualité absente de perQuality (le budget seul la limite)', function()
            assert.is_true(budget.admits({ tile = 11 }, 'tile', cfg.qualities, { uplinkKbps = 1440, perQuality = {} }))
            assert.is_false(budget.admits({ tile = 12 }, 'tile', cfg.qualities, { uplinkKbps = 1440, perQuality = {} }))
        end)
    end)
end)

describe('vava_cameras sessions et budget', function()
    local sessions, events, cfg, active

    local WEB = { kind = 'web' }
    local function member(source) return { kind = 'game', source = source } end

    local function sent(name, target)
        local out = {}
        for _, event in ipairs(events) do
            if event.name == name and (not target or event.target == target) then out[#out + 1] = event end
        end
        return out
    end

    local function lastStart()
        local starts = sent(VavaCameras.EVENTS.START)
        return starts[#starts].payload
    end

    --- Part annoncée pour une caméra dans la dernière annonce de parts, ou nil.
    local function rateOf(id)
        local all = sent(VavaCameras.EVENTS.RATES)
        if #all == 0 then return nil end
        for _, rate in ipairs(all[#all].payload.rates) do
            if rate.session == id then return rate.kbps end
        end
        return nil
    end

    before_each(function()
        helper.reset()
        events, active = {}, { [5] = true, [6] = true }
        _G.GetGameTimer = function() return 1000 end
        _G.TriggerClientEvent = function(name, target, payload)
            events[#events + 1] = { name = name, target = target, payload = payload }
        end
        _G.TriggerLatentClientEvent = function(name, target, bps, payload)
            events[#events + 1] = { name = name, target = target, payload = payload, bps = bps }
        end
        helper.loadAll({
            'modules/vava_cameras/shared/constants.lua', 'modules/vava_cameras/config.lua',
            'modules/vava_cameras/shared/budget.lua',
        })
        cfg = VavaCameras.config
        VavaCameras.players = { active = function(target) return active[target] == true end }
        VavaCameras.core = { hooks = { runAfter = function() end } }
        helper.load('modules/vava_cameras/server/sessions.lua')
        sessions = VavaCameras.sessions
        for source = 1, 4 do sessions.openWall(source) end
    end)

    after_each(function()
        _G.TriggerClientEvent, _G.TriggerLatentClientEvent, _G.VavaCameras = nil, nil, nil
    end)

    it('refuse une seconde vue en grand du même joueur, sans rien lui demander', function()
        assert.is_true((sessions.start(member(1), 5, 'full')))
        local before = #events
        local ok, code = sessions.start(member(2), 5, 'full')
        assert.is_false(ok)
        assert.equal('budget', code)
        assert.equal(before, #events)
        assert.equal(1, sessions.count())
    end)

    it('juge une caméra accordable comme l\'ouverture, sans rien ouvrir ni envoyer (pont du web)', function()
        assert.is_true((sessions.check(WEB, 5, 'full')))
        assert.equal(0, #events)
        assert.equal(0, sessions.count())
        sessions.start(member(1), 5, 'full')
        local before = #events
        local ok, code = sessions.check(WEB, 5, 'full')
        assert.is_false(ok)
        assert.equal('budget', code)
        assert.is_true((sessions.check(WEB, 5, 'tile')))
        assert.equal('not_playing', select(2, sessions.check(WEB, 7, 'full')))
        assert.equal('invalid_quality', select(2, sessions.check(WEB, 5, 'huge')))
        assert.equal(before, #events)
        assert.equal(1, sessions.count())
    end)

    it('compte la vue en grand du web comme celle d\'un membre en jeu', function()
        assert.is_true((sessions.start(WEB, 5, 'full')))
        local ok, code = sessions.start(member(1), 5, 'full')
        assert.is_false(ok)
        assert.equal('budget', code)
    end)

    it('accorde la vue en grand d\'un autre joueur filmé, et de nouveau celle-ci une fois la première fermée', function()
        local _, first = sessions.start(member(1), 5, 'full')
        assert.is_true((sessions.start(member(2), 6, 'full')))
        sessions.close(first, function() return true end)
        assert.is_true((sessions.start(member(2), 5, 'full')))
    end)

    it('place le refus budget après too_many_viewers, et wall_closed avant', function()
        for i = 1, cfg.limits.viewersPerPlayer - 1 do
            local source = 10 + i
            sessions.openWall(source)
            assert.is_true((sessions.start(member(source), 5, i == 1 and 'full' or 'tile')))
        end
        assert.is_true((sessions.start(WEB, 5, 'tile')))
        -- seconde vue en grand d'un joueur déjà regardé six fois : le nombre d'abord
        local ok, code = sessions.start(WEB, 5, 'full')
        assert.is_false(ok)
        assert.equal('too_many_viewers', code)
        -- case sans mur ouvert : refusée avant toute limite (elle ne compte dans aucun budget)
        local closed, closedCode = sessions.start(member(9), 5, 'tile')
        assert.is_false(closed)
        assert.equal('wall_closed', closedCode)
    end)

    it('donne sa part à la nouvelle caméra dans son ordre de départ, et annonce au seul joueur filmé les parts changées',
        function()
            local _, full = sessions.start(member(1), 5, 'full')
            assert.equal(1200, lastStart().quality.bitrateKbps)
            local _, tile1 = sessions.start(member(2), 5, 'tile')
            assert.equal(250, lastStart().quality.bitrateKbps)
            assert.equal(0, #sent(VavaCameras.EVENTS.RATES))   -- 1 200 + 250 : rien à revoir
            local _, tile2 = sessions.start(WEB, 5, 'tile')
            assert.equal(150, lastStart().quality.bitrateKbps)
            local rates = sent(VavaCameras.EVENTS.RATES)
            assert.equal(1, #rates)
            assert.equal(5, rates[1].target)
            assert.equal(1, #rates[1].payload.rates)            -- la vue en grand n'a pas changé
            assert.equal(150, rateOf(tile1))
            local _, tile3 = sessions.start(member(3), 5, 'tile')
            assert.equal(120, lastStart().quality.bitrateKbps)
            assert.equal(3, #sent(VavaCameras.EVENTS.RATES)[2].payload.rates)
            assert.equal(1140, rateOf(full))
            assert.equal(120, rateOf(tile1))
            assert.equal(120, rateOf(tile2))
            assert.is_nil(rateOf(tile3))                        -- sa part est dans son ordre de départ
            for _, event in ipairs(sent(VavaCameras.EVENTS.RATES)) do assert.equal(5, event.target) end
        end)

    it('baisse les autres parts avant le départ de la nouvelle caméra', function()
        sessions.start(member(1), 5, 'full')
        sessions.start(member(2), 5, 'tile')
        sessions.start(member(3), 5, 'tile')
        local last = events[#events]
        local previous = events[#events - 1]
        assert.equal(VavaCameras.EVENTS.START, last.name)
        assert.equal(VavaCameras.EVENTS.RATES, previous.name)
    end)

    it('rend le débit aux spectateurs qui restent quand l\'un s\'en va', function()
        local _, full = sessions.start(member(1), 5, 'full')
        local _, tile1 = sessions.start(member(2), 5, 'tile')
        local _, tile2 = sessions.start(member(3), 5, 'tile')
        sessions.start(member(4), 5, 'tile')
        sessions.closeViewer(4)
        assert.equal(1200, rateOf(full))
        assert.equal(150, rateOf(tile1))
        assert.equal(150, rateOf(tile2))
        sessions.close(full, function() return true end)
        assert.equal(250, rateOf(tile1))
        assert.equal(250, rateOf(tile2))
    end)

    it('n\'annonce aucune part au joueur filmé qui s\'en va', function()
        sessions.start(member(1), 5, 'full')
        sessions.start(member(2), 5, 'tile')
        sessions.start(member(3), 5, 'tile')
        local before = #sent(VavaCameras.EVENTS.RATES)
        sessions.forget(5, 'dropped')
        assert.equal(before, #sent(VavaCameras.EVENTS.RATES))
        assert.equal(0, sessions.count())
    end)

    it('ne dépasse jamais le budget du joueur filmé au fil des arrivées et des départs', function()
        local opened = {}
        local function open(viewer, quality)
            local ok, id = sessions.start(viewer, 5, quality)
            if ok then opened[#opened + 1] = id end
        end
        -- parts tenues par le serveur pour chaque caméra encore ouverte de ce joueur
        local function check()
            local sum = 0
            for _, id in ipairs(opened) do
                local camera = sessions.get(id)
                if camera then sum = sum + camera.kbps end
            end
            assert.is_true(sum <= cfg.budget.uplinkKbps, tostring(sum))
        end
        open(member(1), 'tile'); check()
        open(member(2), 'tile'); check()
        open(WEB, 'full'); check()
        open(member(3), 'tile'); check()
        open(WEB, 'tile'); check()
        sessions.close(opened[3], function() return true end); check()
        open(member(4), 'full'); check()
        open(WEB, 'tile'); check()
        sessions.closeViewer(1); check()
    end)
end)
