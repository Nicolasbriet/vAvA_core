local helper = require('tests.helper')

-- Réponse de l'accueil vue du client (modules/vava_atelier/client/session.lua › absorbHome, T-101, relecture réseau
-- R-3) : les étiquettes des cartes (« 2 panneaux », « 1 en essai ») partent du serveur à chaque réponse, hors du
-- contenu gardé ; le client les transmet à la page, jamais il ne les jette.
-- Vue du client (T-132) : seuls shared/constants.lua et config_client.lua sont chargés, comme chez un joueur
-- (config.lua est servi au seul serveur) : une clé lue par le client et restée dans config.lua y serait nil.
describe('vava_atelier accueil côté client', function()
    local session, handlers, triggered

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config_client.lua',
        })
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
