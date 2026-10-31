local helper = require('tests.helper')

-- Réponse de l'accueil vue du client (modules/vava_atelier/client/session.lua › absorbHome, T-101, relecture réseau
-- R-3) : les étiquettes des cartes (« 2 panneaux », « 1 en essai ») partent du serveur à chaque réponse, hors du
-- contenu gardé ; le client les transmet à la page, jamais il ne les jette.
-- Vue du client (T-132) : seuls shared/constants.lua et config_client.lua sont chargés (helper.loadClientView), comme
-- chez un joueur (config.lua est servi au seul serveur) : une clé lue par le client et restée dans config.lua y serait
-- nil.
describe('vava_atelier accueil côté client', function()
    local session, handlers, triggered

    before_each(function()
        helper.reset()
        local atelier = helper.loadClientView('modules/vava_atelier', 'VavaAtelier')
        assert.is_true(atelier.config.clientFile)
        assert.is_nil(atelier.config.rights, 'config.lua ne doit pas être chargé dans la vue client')
        -- doublures : core et page (rien n'est appelé au chargement), évènements du serveur gardés par nom
        VavaAtelier.core = { log = { warn = function() end } }
        VavaAtelier.nui = { send = function() end, setFocus = function() end }
        handlers, triggered = {}, {}
        _G.RegisterNetEvent = function(name, fn) handlers[name] = fn end
        _G.GetResourceState = function() return 'started' end
        _G.TriggerEvent = function(name, payload) triggered[#triggered + 1] = { name = name, payload = payload } end
        helper.load('modules/vava_atelier/client/session.lua')
        session = VavaAtelier.session
    end)

    after_each(function()
        VavaAtelier = nil
        _G.RegisterNetEvent, _G.GetResourceState, _G.TriggerEvent = nil, nil, nil
    end)

    it('réponse de /atelier_archives au chat sous le nom texts.sayAuthor (config_client.lua)', function()
        handlers[VavaAtelier.EVENTS.SAY]('État : rien à dire.')
        assert.equal(1, #triggered)
        assert.equal('chat:addMessage', triggered[1].name)
        assert.same({ 'Atelier', 'État : rien à dire.' }, triggered[1].payload.args)
        assert.equal(VavaAtelier.config.texts.sayAuthor, triggered[1].payload.args[1])
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

-- Essai joué (T-102, spec § 8.4, écart 6 du rapport T-102-nui) : la page se met de côté, le jeu reprend la main, la
-- séance reste ouverte côté serveur ; `suspended` part sans ligne (la page compose la ligne d'essai de l'atelier et la
-- touche de retour) ; la visée s'arrête et les fantômes partent, les lieux gardés restent pour la visée suivante ;
-- l'état annoncé aux autres modules est « fermé » pendant l'essai, puis rendu.
describe('vava_atelier essai joué côté client', function()
    local session, sent, focus, states, tool, closed

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_atelier', 'VavaAtelier')
        sent, focus, states, tool, closed = {}, {}, {}, {}, 0
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
