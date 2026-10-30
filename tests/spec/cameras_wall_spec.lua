local helper = require('tests.helper')

-- Caméras du Conseil (T-026) :
--   - modules/vava_cameras/server/sessions.lua : une seule offre relayée par caméra (`already_offered` ensuite) ; une
--     case de mur (`tile`) n'est accordée à un membre en jeu que mur ouvert (`wall_closed` sinon), état posé par
--     l'ouverture du mur et levé par sa fermeture, le départ ou le droit retiré ; la vue en grand et le web n'en
--     dépendent pas (journalisés autrement) ;
--   - modules/vava_chancellerie/server/routes.lua : une case demandée depuis le web par un compte qui n'a ouvert
--     aucun mur depuis `cameras.tileLogMs` inscrit sa propre ligne au journal ; une ouverture du mur la couvre.

describe('vava_cameras sessions', function()
    local sessions, events, webEvents, active

    local GAME = { kind = 'game', source = 1 }
    local WEB = { kind = 'web' }

    local function sent(name)
        local out = {}
        for _, event in ipairs(events) do
            if event.name == name then out[#out + 1] = event end
        end
        return out
    end

    local clock

    before_each(function()
        helper.reset()
        events, webEvents, active, clock = {}, {}, { [5] = true, [6] = true }, 1000
        _G.GetGameTimer = function() return clock end
        _G.TriggerClientEvent = function(name, target, payload)
            events[#events + 1] = { name = name, target = target, payload = payload }
        end
        -- offre relayée au membre en envoi latent (T-047)
        _G.TriggerLatentClientEvent = function(name, target, bps, payload)
            events[#events + 1] = { name = name, target = target, payload = payload, bps = bps }
        end
        helper.loadAll({
            'modules/vava_cameras/shared/constants.lua', 'modules/vava_cameras/config.lua',
            'modules/vava_cameras/shared/budget.lua',
        })
        VavaCameras.players = { active = function(target) return active[target] == true end }
        VavaCameras.core = { hooks = { runAfter = function(_, payload) webEvents[#webEvents + 1] = payload end } }
        helper.load('modules/vava_cameras/server/sessions.lua')
        sessions = VavaCameras.sessions
    end)

    after_each(function()
        _G.TriggerClientEvent, _G.TriggerLatentClientEvent, _G.VavaCameras = nil, nil, nil
    end)

    describe('offre du joueur filmé', function()
        it('relaie la première offre au spectateur, refuse les suivantes sans rien relayer', function()
            sessions.openWall(1)
            local ok, id = sessions.start(GAME, 5, 'tile')
            assert.is_true(ok)
            assert.is_true(sessions.offer(5, id, 'v=0 offre'))
            local again, code = sessions.offer(5, id, 'v=0 offre')
            assert.is_false(again)
            assert.equal('already_offered', code)
            local offers = sent(VavaCameras.EVENTS.OFFER)
            assert.equal(1, #offers)
            assert.equal(1, offers[1].target)
            assert.equal(VavaCameras.config.limits.offerBytesPerSecond, offers[1].bps)
        end)

        it('refuse l\'offre d\'un autre que le joueur filmé, sans consommer celle du vrai', function()
            local _, id = sessions.start(GAME, 5, 'full')
            local ok, code = sessions.offer(6, id, 'v=0')
            assert.is_false(ok)
            assert.equal('unknown_session', code)
            assert.is_true(sessions.offer(5, id, 'v=0'))
        end)

        it('ne relaie qu\'une offre vers le web aussi', function()
            local _, id = sessions.start(WEB, 5, 'tile')
            assert.is_true(sessions.offer(5, id, 'v=0'))
            assert.is_false(sessions.offer(5, id, 'v=0'))
            assert.equal(1, #webEvents)
            assert.equal('v=0', webEvents[1].offer)
        end)

        it('compte les offres par caméra : une nouvelle caméra a droit à la sienne', function()
            -- une vue en grand et une case : deux vues en grand d'un même joueur sont refusées (budget, T-047)
            sessions.openWall(1)
            local _, first = sessions.start(GAME, 5, 'full')
            local _, second = sessions.start(GAME, 5, 'tile')
            assert.is_true(sessions.offer(5, first, 'a'))
            assert.is_true(sessions.offer(5, second, 'b'))
        end)
    end)

    describe('mur ouvert', function()
        it('refuse une case à un membre en jeu sans mur ouvert, sans rien demander au joueur filmé', function()
            local ok, code = sessions.start(GAME, 5, 'tile')
            assert.is_false(ok)
            assert.equal('wall_closed', code)
            assert.equal(0, #events)
            assert.equal(0, sessions.count())
        end)

        it('accorde la case une fois le mur ouvert', function()
            assert.is_false(sessions.wallOpen(1))
            sessions.openWall(1)
            assert.is_true(sessions.wallOpen(1))
            assert.is_true((sessions.start(GAME, 5, 'tile')))
            assert.equal(1, #sent(VavaCameras.EVENTS.START))
        end)

        it('n\'exige pas le mur pour la vue en grand ni pour le web (journalisés autrement)', function()
            assert.is_true((sessions.start(GAME, 5, 'full')))
            assert.is_true((sessions.start(WEB, 5, 'tile')))
        end)

        it('ne prête pas le mur d\'un membre à un autre', function()
            sessions.openWall(2)
            local ok, code = sessions.start(GAME, 5, 'tile')
            assert.is_false(ok)
            assert.equal('wall_closed', code)
        end)

        local closers = {
            { 'fermeture du mur', function() sessions.closeViewer(1) end },
            { 'départ ou retour à la sélection', function() sessions.forget(1, 'dropped') end },
            { 'droit retiré', function() sessions.revoke(1) end },
        }
        for _, closer in ipairs(closers) do
            it('lève le mur à la ' .. closer[1] .. ' : plus aucune case sans le rouvrir', function()
                sessions.openWall(1)
                assert.is_true((sessions.start(GAME, 5, 'tile')))
                closer[2]()
                assert.is_false(sessions.wallOpen(1))
                assert.equal(0, sessions.count())
                local ok, code = sessions.start(GAME, 5, 'tile')
                assert.is_false(ok)
                assert.equal('wall_closed', code)
                sessions.openWall(1)
                assert.is_true((sessions.start(GAME, 5, 'tile')))
            end)
        end

        it('demande de rouvrir un mur ouvert depuis wall.maxOpenMs (nouvelle ligne au journal)', function()
            sessions.openWall(1)
            clock = clock + VavaCameras.config.wall.maxOpenMs - 1
            assert.is_true((sessions.start(GAME, 5, 'tile')))
            clock = clock + 1
            assert.is_false(sessions.wallOpen(1))
            local ok, code = sessions.start(GAME, 6, 'tile')
            assert.is_false(ok)
            assert.equal('wall_closed', code)
            sessions.openWall(1)
            assert.is_true((sessions.start(GAME, 6, 'tile')))
        end)

        it('garde le mur d\'un membre quand un autre part', function()
            sessions.openWall(1)
            sessions.forget(2, 'dropped')
            sessions.closeViewer(2)
            sessions.revoke(2)
            assert.is_true(sessions.wallOpen(1))
        end)
    end)
end)

describe('vava_chancellerie routes des caméras', function()
    local routes, calls, now, rights, started, logRefused, checkRefusal

    local ALICE = { label = 'alice', rank = 'gardien' }
    local BRUNO = { label = 'bruno', rank = 'gardien' }

    local function logs(label)
        local out = {}
        for _, c in ipairs(calls) do
            if c.fn == 'webLog' and (not label or c.args[2] == label) then out[#out + 1] = c end
        end
        return out
    end

    local function post(path, body)
        return routes.find('POST', path)(body)
    end

    before_each(function()
        helper.reset()
        calls, now, rights, started, logRefused, checkRefusal = {}, 1000, { alice = true, bruno = true }, true, false, nil
        _G.GetGameTimer = function() return now end
        helper.loadAll({ 'modules/vava_chancellerie/shared/constants.lua', 'modules/vava_chancellerie/config.lua' })
        VavaBridge.call = function(resource, fn, ...)
            calls[#calls + 1] = { resource = resource, fn = fn, args = { ... } }
            if fn == 'webCan' then return true, rights[(...).label] == true end
            if fn == 'webPlayers' then return true, {} end
            if fn == 'webStart' then
                if not started then return true, false, 'not_playing' end
                return true, true, { session = 'abc', label = 'B', iceServers = {} }
            end
            if fn == 'webLog' and logRefused then return true, false, 'invalid_args' end
            if fn == 'webCheck' and checkRefusal then return true, false, checkRefusal end
            return true, true
        end
        helper.load('modules/vava_chancellerie/server/routes.lua')
        routes = VavaBridge.routes
    end)

    after_each(function()
        _G.VavaBridge = nil
    end)

    it('inscrit au journal la première case d\'un compte qui n\'a pas ouvert de mur, une fois', function()
        assert.is_true(post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' }).ok)
        assert.is_true(post('/camera/start', { actor = ALICE, target = 8, quality = 'tile' }).ok)
        local lines = logs(VavaBridge.config.messages.logTiles)
        assert.equal(1, #lines)
        assert.equal(ALICE, lines[1].args[1])
        assert.equal(7, lines[1].args[3].numero)
    end)

    it('n\'ajoute rien quand le mur vient d\'être ouvert : l\'ouverture couvre les cases', function()
        assert.is_true(post('/cameras/wall', { actor = ALICE }).ok)
        assert.is_true(post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' }).ok)
        assert.equal(1, #logs())
        assert.equal(1, #logs(VavaBridge.config.messages.logWall))
    end)

    it('inscrit une nouvelle ligne passé tileLogMs sans ouverture du mur', function()
        post('/cameras/wall', { actor = ALICE })
        now = now + VavaBridge.config.cameras.tileLogMs - 1
        post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' })
        assert.equal(0, #logs(VavaBridge.config.messages.logTiles))
        now = now + 1
        post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' })
        assert.equal(1, #logs(VavaBridge.config.messages.logTiles))
    end)

    it('ne compte pas la relecture des joueurs comme une ouverture du mur', function()
        post('/cameras/players', { actor = ALICE })
        post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' })
        assert.equal(1, #logs(VavaBridge.config.messages.logTiles))
    end)

    it('tient le journal par compte : le mur d\'un compte ne couvre pas un autre', function()
        post('/cameras/wall', { actor = ALICE })
        post('/camera/start', { actor = BRUNO, target = 7, quality = 'tile' })
        local lines = logs(VavaBridge.config.messages.logTiles)
        assert.equal(1, #lines)
        assert.equal(BRUNO, lines[1].args[1])
    end)

    it('n\'inscrit rien pour une case refusée ou une caméra qui ne s\'ouvre pas', function()
        rights.alice = false
        assert.equal('forbidden', post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' }).error)
        rights.alice, started = true, false
        assert.equal('not_playing', post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' }).error)
        assert.equal(0, #logs())
    end)

    it('ne tient pour écrite qu\'une ligne réellement acceptée par le Registre (ouverture comme case)', function()
        logRefused = true
        post('/cameras/wall', { actor = ALICE })
        post('/camera/start', { actor = ALICE, target = 7, quality = 'tile' })
        post('/camera/start', { actor = ALICE, target = 8, quality = 'tile' })
        assert.equal(2, #logs(VavaBridge.config.messages.logTiles))
        logRefused = false
        post('/camera/start', { actor = ALICE, target = 9, quality = 'tile' })
        post('/camera/start', { actor = ALICE, target = 10, quality = 'tile' })
        assert.equal(3, #logs(VavaBridge.config.messages.logTiles))
    end)

    it('laisse la vue en grand au Registre (demande watchScreen, déjà au journal)', function()
        assert.is_true(post('/camera/start', { actor = ALICE, target = 7, quality = 'full' }).ok)
        assert.equal(0, #logs())
        local order = {}
        for _, c in ipairs(calls) do order[#order + 1] = c.fn end
        -- droit lu, caméra jugée accordable (T-047), puis demande au Registre, qui l'inscrit, et ouverture
        assert.same({ 'webCan', 'webCheck', 'webRequest', 'webStart' }, order)
    end)

    it('ne fait rien inscrire pour une vue en grand refusée faute de débit (retentée toutes les 10 s)', function()
        checkRefusal = 'budget'
        for _ = 1, 3 do
            assert.equal('budget', post('/camera/start', { actor = ALICE, target = 7, quality = 'full' }).error)
        end
        for _, c in ipairs(calls) do
            assert.is_true(c.fn == 'webCan' or c.fn == 'webCheck', c.fn)
        end
    end)

    it('ne dit rien de la caméra à un compte sans le droit', function()
        rights.alice, checkRefusal = false, 'budget'
        assert.equal('forbidden', post('/camera/start', { actor = ALICE, target = 7, quality = 'full' }).error)
        for _, c in ipairs(calls) do assert.equal('webCan', c.fn) end
    end)

    it('garde le libellé du journal dans les bornes du Registre', function()
        assert.truthy(#VavaBridge.config.messages.logTiles <= 32)
    end)
end)
