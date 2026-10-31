local helper = require('tests.helper')

-- Réponse de l'accueil vue du client (modules/vava_atelier/client/session.lua › absorbHome, T-101, relecture réseau
-- R-3) : les étiquettes des cartes (« 2 panneaux », « 1 en essai ») partent du serveur à chaque réponse, hors du
-- contenu gardé ; le client les transmet à la page, jamais il ne les jette.
describe('vava_atelier accueil côté client', function()
    local session

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
        })
        -- doublures : core et page (rien n'est appelé au chargement), évènements du serveur ignorés
        VavaAtelier.core = { log = { warn = function() end } }
        VavaAtelier.nui = { send = function() end, setFocus = function() end }
        _G.RegisterNetEvent = function() end
        helper.load('modules/vava_atelier/client/session.lua')
        session = VavaAtelier.session
    end)

    after_each(function()
        VavaAtelier = nil
        _G.RegisterNetEvent = nil
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
