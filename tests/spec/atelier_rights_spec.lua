local helper = require('tests.helper')

-- Droits de l'Atelier (T-100) : droit effectif d'un éditeur (déclaré, plancher de la famille, surcharge du porteur du
-- projet), droits détenus d'un membre, ateliers visibles.
describe('vava_atelier rights', function()
    local rights, settings

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/rights.lua',
        })
        rights = VavaAtelier.rights
        local cfg = VavaAtelier.config
        local floors = {}
        for _, family in ipairs(cfg.families) do floors[family.id] = family.floor end
        settings = { allowed = cfg.rights.allowed, overrides = {}, floors = floors }
    end)

    it('garde le droit déclaré quand il atteint le plancher', function()
        assert.equal('metiers', rights.effective('vava_gathering:zones', 'metiers', 'monde', settings))
        assert.equal('staff', rights.effective('vava_gathering:zones', 'staff', 'monde', settings))
    end)

    it('relève au plancher de la famille', function()
        assert.equal('staff', rights.effective('vava_magic:sorts', 'metiers', 'arts', settings))
        assert.equal('staff', rights.effective('vava_guilds:confreries', 'metiers', 'societe', settings))
    end)

    it('applique la surcharge du porteur du projet, même sous le plancher', function()
        settings.overrides['vava_magic:sorts'] = 'metiers'
        assert.equal('metiers', rights.effective('vava_magic:sorts', 'staff', 'arts', settings))
        settings.overrides['vava_gathering:zones'] = 'staff'
        assert.equal('staff', rights.effective('vava_gathering:zones', 'metiers', 'monde', settings))
    end)

    it('ignore une surcharge hors des droits permis', function()
        settings.overrides['vava_magic:sorts'] = 'view'
        assert.equal('staff', rights.effective('vava_magic:sorts', 'metiers', 'arts', settings))
    end)

    it('donne le droit le plus fort à un droit déclaré inconnu', function()
        assert.equal('staff', rights.effective('x:y', 'view', 'monde', settings))
    end)

    it('droits détenus d\'un Sénéchal et d\'un Souverain, dans l\'ordre des droits permis', function()
        local senechal = { metiers = true }
        local souverain = { metiers = true, staff = true }
        assert.same({ 'metiers' }, rights.held(settings.allowed, function(right) return senechal[right] == true end))
        assert.same({ 'metiers', 'staff' }, rights.held(settings.allowed, function(right) return souverain[right] == true end))
        assert.same({}, rights.held(settings.allowed, function() return false end))
        -- seule une réponse exactement vraie compte
        assert.same({}, rights.held(settings.allowed, function() return 1 end))
    end)

    it('ateliers visibles d\'un Sénéchal et d\'un Souverain', function()
        local editors = {
            { id = 'vava_example_atelier:panneaux', right = 'metiers' },
            { id = 'vava_example_atelier:proclamations', right = 'staff' },
            { id = 'vava_gathering:zones', right = 'metiers' },
        }
        assert.same({ 'vava_example_atelier:panneaux', 'vava_gathering:zones' }, rights.visible(editors, { 'metiers' }))
        assert.same({ 'vava_example_atelier:panneaux', 'vava_example_atelier:proclamations', 'vava_gathering:zones' },
            rights.visible(editors, { 'metiers', 'staff' }))
        assert.same({}, rights.visible(editors, {}))
    end)

    it('rang d\'un droit', function()
        assert.equal(1, rights.rank(settings.allowed, 'metiers'))
        assert.equal(2, rights.rank(settings.allowed, 'staff'))
        assert.is_nil(rights.rank(settings.allowed, 'view'))
        assert.is_true(rights.holds({ 'metiers' }, 'metiers'))
        assert.is_false(rights.holds({ 'metiers' }, 'staff'))
    end)
end)
