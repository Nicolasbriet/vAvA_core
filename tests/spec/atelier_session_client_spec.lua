local helper = require('tests.helper')

-- Réponse de l'accueil vue du client (modules/vava_atelier/client/session.lua › absorbHome, T-101, relecture réseau
-- R-3) : les étiquettes des cartes (« 2 panneaux », « 1 en essai ») partent du serveur à chaque réponse, hors du
-- contenu gardé ; le client les transmet à la page, jamais il ne les jette.
-- Vue du client d'un membre du Conseil (T-132, T-157) : shared/constants.lua, config_client.lua et config_conseil.lua
-- (livré dans le paquet) sont chargés (helper.loadCouncilView), et rien d'autre : une clé lue par la séance et restée
-- dans config.lua y serait nil.
describe('vava_atelier accueil côté client', function()
    local session, handlers, forgotten

    before_each(function()
        helper.reset()
        local atelier = helper.loadCouncilView('modules/vava_atelier', 'VavaAtelier')
        assert.is_true(atelier.config.clientFile)
        assert.is_nil(atelier.config.rights, 'config.lua ne doit pas être chargé dans la vue du Conseil')
        -- doublures : core, page, amorce (rien n'est appelé au chargement), évènements du serveur gardés par nom
        VavaAtelier.core = { log = { warn = function() end } }
        VavaAtelier.nui = { send = function() end, setFocus = function() end }
        VavaAtelier.notice = { feed = function() end, refusal = function() return '' end }
        forgotten = 0
        VavaAtelier.loader = { forget = function() forgotten = forgotten + 1 end }
        handlers = {}
        _G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
        helper.load('modules/vava_atelier/client/session.lua')
        session = VavaAtelier.session
    end)

    after_each(function()
        VavaAtelier = nil
        _G.RegisterNetEvent = nil
    end)

    -- T-157 : la réponse de /atelier_archives est écoutée par l'amorce (client/notice.lua), plus par la séance
    it('la séance n\'écoute plus say ; feed est celui de l\'amorce, refusal lit tous les refus', function()
        assert.is_nil(handlers[VavaAtelier.EVENTS.SAY])
        assert.equal(VavaAtelier.notice.feed, session.feed)
        local refused = VavaAtelier.config.texts.refused
        assert.equal('L\'Atelier s\'est refermé : rouvrez-le.', session.refusal('not_open'))   -- config_conseil.lua
        assert.equal(refused.not_allowed, session.refusal('not_allowed'))                        -- config_client.lua
        assert.equal(refused.unavailable, session.refusal('inconnu'))
    end)

    it('revoked efface le stockage local du paquet (loader.forget)', function()
        handlers[VavaAtelier.EVENTS.REVOKED]()
        assert.equal(1, forgotten)
    end)

    local tags = { ['vava_example_atelier:panneaux'] = { text = '1 en essai', tone = 'trial' } }

    it('première réponse : contenu gardé, étiquettes transmises à la page', function()
        local message = session.absorbHome({ version = 'abc', content = { cards = {} }, tags = tags, drafts = {},
            journal = {}, rank = 'Souverain' })
        assert.same(tags, message.tags)
        assert.equal('abc', message.version)
        assert.same({ cards = {} }, message.content)
        assert.equal('abc', session.known().home)
    end)

    it('réponse suivante sans contenu (gardé par la page) : les étiquettes partent quand même', function()
        session.absorbHome({ version = 'abc', content = { cards = {} }, tags = {}, drafts = {}, journal = {}, rank = '' })
        local message = session.absorbHome({ version = 'abc', tags = tags, drafts = {}, journal = {}, rank = '' })
        assert.is_nil(message.content)
        assert.same(tags, message.tags)
    end)

    it('étiquettes absentes ou d\'une autre forme : liste vide, jamais nil', function()
        local message = session.absorbHome({ version = 'v', content = {}, drafts = {}, journal = {}, rank = '' })
        assert.same({}, message.tags)
        message = session.absorbHome({ version = 'v', content = {}, tags = 'non', drafts = {}, journal = {}, rank = '' })
        assert.same({}, message.tags)
    end)

    it('version inconnue sans contenu : rien n\'est gardé', function()
        assert.is_nil(session.absorbHome({ version = 'autre', tags = tags }))
        assert.equal('', session.known().home)
    end)
end)

-- Réponse de /atelier_archives (T-101), écoutée par l'amorce livrée à tous (client/notice.lua, T-157) : vue du client
-- de chaque joueur (constantes et config_client.lua seuls), sans paquet chargé.
describe('vava_atelier réponse de /atelier_archives (amorce)', function()
    local handlers, triggered, fed, started

    before_each(function()
        helper.reset()
        local atelier = helper.loadClientView('modules/vava_atelier', 'VavaAtelier')
        assert.is_nil(atelier.config.placement, 'config_conseil.lua ne doit pas être chargé dans la vue client')
        VavaAtelier.core = { log = { warn = function() end } }
        handlers, triggered, fed, started = {}, {}, {}, 'started'
        _G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
        _G.GetResourceState = function(name) return name == 'vava_chat' and started or 'missing' end
        _G.TriggerEvent = function(name, payload) triggered[#triggered + 1] = { name = name, payload = payload } end
        _G.BeginTextCommandThefeedPost = function() end
        _G.AddTextComponentSubstringPlayerName = function(text) fed[#fed + 1] = text end
        _G.EndTextCommandThefeedPostTicker = function() end
        helper.load('modules/vava_atelier/client/notice.lua')
    end)

    after_each(function()
        VavaAtelier = nil
        _G.RegisterNetEvent, _G.GetResourceState, _G.TriggerEvent = nil, nil, nil
        _G.BeginTextCommandThefeedPost, _G.AddTextComponentSubstringPlayerName = nil, nil
        _G.EndTextCommandThefeedPostTicker = nil
    end)

    it('au chat sous le nom texts.sayAuthor (config_client.lua)', function()
        handlers[VavaAtelier.EVENTS.SAY]('État : rien à dire.')
        assert.equal(1, #triggered)
        assert.equal('chat:addMessage', triggered[1].name)
        assert.same({ 'Atelier', 'État : rien à dire.' }, triggered[1].payload.args)
        assert.equal(VavaAtelier.config.texts.sayAuthor, triggered[1].payload.args[1])
    end)

    it('sans chat : en notification du jeu ; au-delà de 480 octets ou autre chose qu\'un texte : rien', function()
        started = 'stopped'
        handlers[VavaAtelier.EVENTS.SAY]('Archives écrites.')
        assert.same({ 'Archives écrites.' }, fed)
        handlers[VavaAtelier.EVENTS.SAY](string.rep('a', 481))
        handlers[VavaAtelier.EVENTS.SAY]({ 'table' })
        assert.same({ 'Archives écrites.' }, fed)
        assert.equal(0, #triggered)
    end)

    it('refus : texte de config_client.lua, repli « indisponible » ; la vue de l\'amorce n\'a que ses 7 refus', function()
        local refused = VavaAtelier.config.texts.refused
        for _, code in ipairs({ 'not_ready', 'no_character', 'not_allowed', 'unavailable', 'rate_limited', 'busy',
            'bad_request' }) do
            assert.is_string(refused[code])
            assert.equal(refused[code], VavaAtelier.notice.refusal(code))
        end
        local count = 0
        for _ in pairs(refused) do count = count + 1 end
        assert.equal(7, count)
        assert.equal(refused.unavailable, VavaAtelier.notice.refusal('not_open'))
        assert.equal(refused.unavailable, VavaAtelier.notice.refusal('inconnu'))
        assert.equal(refused.unavailable, VavaAtelier.notice.refusal(nil))
    end)
end)

-- Essai joué (T-102, spec § 8.4, écart 6 du rapport T-102-nui) : la page se met de côté, le jeu reprend la main, la
-- séance reste ouverte côté serveur ; `suspended` part sans ligne (la page compose la ligne d'essai de l'atelier et la
-- touche de retour) ; la visée s'arrête et les fantômes partent, les lieux gardés restent pour la visée suivante ;
-- l'état annoncé aux autres modules est « fermé » pendant l'essai, puis rendu.
describe('vava_atelier essai joué côté client', function()
    local session, sent, focus, states, tool, closed

    before_each(function()
        helper.reset()
        helper.loadCouncilView('modules/vava_atelier', 'VavaAtelier')
        sent, focus, states, tool, closed = {}, {}, {}, {}, 0
        VavaAtelier.notice = { feed = function() end, refusal = function() return '' end }
        VavaAtelier.core = {
            log = { warn = function() end },
            characters = { current = function() return 1 end },
            rpc = {
                call = function() return true, true, { version = 'v', content = {}, tags = {}, drafts = {}, journal = {},
                    rank = '' } end,
                emit = function() closed = closed + 1 end,
            },
            hooks = { runAfter = function(_, payload) states[#states + 1] = payload end },
        }
        VavaAtelier.nui = {
            send = function(action, payload) sent[#sent + 1] = { action = action, payload = payload } end,
            setFocus = function(on) focus[#focus + 1] = on end,
        }
        VavaAtelier.placer = {
            hide = function() tool[#tool + 1] = 'hide' end, show = function() tool[#tool + 1] = 'show' end,
            stop = function() tool[#tool + 1] = 'stop' end, leave = function() tool[#tool + 1] = 'leave' end,
        }
        _G.RegisterNetEvent = function() end
        _G.IsPauseMenuActive = function() return false end
        helper.load('modules/vava_atelier/client/session.lua')
        session = VavaAtelier.session
        session.open()
        sent, focus, states = {}, {}, {}
    end)

    after_each(function()
        VavaAtelier = nil
        _G.RegisterNetEvent, _G.IsPauseMenuActive = nil, nil
    end)

    it('met la page de côté sans ligne, rend le jeu, garde la séance ; F9 la rend', function()
        assert.is_true(session.suspend())
        assert.same({ { action = 'suspended', payload = { on = true } } }, sent)
        assert.same({ false }, focus)
        assert.same({ open = false, placing = false, suspended = true }, states[1])
        assert.same({ 'hide' }, tool)
        assert.is_true(session.isOpen())
        assert.is_true(session.isSuspended())
        assert.equal(0, closed)
        -- déjà de côté : rien
        assert.is_false(session.suspend())
        session.resume()
        assert.same({ action = 'suspended', payload = { on = false } }, sent[2])
        assert.same({ false, true }, focus)
        assert.same({ open = true, placing = false, suspended = false }, states[2])
        assert.same({ 'hide', 'show' }, tool)
        assert.is_false(session.isSuspended())
    end)

    it('fermer pendant l’essai joué : visée et fantômes retirés, séance rendue au serveur', function()
        session.suspend()
        tool = {}
        session.close(true)
        assert.same({ 'stop', 'leave' }, tool)
        assert.is_false(session.isOpen())
        assert.is_false(session.isSuspended())
        assert.equal(1, closed)
    end)
end)
