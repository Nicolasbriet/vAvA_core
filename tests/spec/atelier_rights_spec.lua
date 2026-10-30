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

    describe('réglages de la config (refus de démarrer)', function()
        local function config(over)
            local cfg = {
                families = { { id = 'monde', floor = 'metiers' }, { id = 'arts', floor = 'staff' } },
                rights = { allowed = { 'metiers', 'staff' }, open = 'metiers', overrides = {} },
            }
            if over then over(cfg) end
            return cfg
        end

        local function refused(cfg, start)
            local ok, err = rights.checkSettings(cfg)
            assert.is_false(ok)
            assert.is_string(err)
            assert.equal(start, err:sub(1, #start), err)
        end

        it('accepte la config livrée et une surcharge permise', function()
            assert.same({ true }, { rights.checkSettings(VavaAtelier.config) })
            assert.same({ true }, { rights.checkSettings(config(function(c)
                c.rights.overrides['vava_magic:sorts'] = 'metiers'
            end)) })
            assert.same({ true }, { rights.checkSettings(config(function(c) c.rights.overrides = nil end)) })
        end)

        it('refuse un plancher de famille hors des droits permis', function()
            refused(config(function(c) c.families[2].floor = 'souverain' end),
                "families['arts'].floor = 'souverain' : pas un droit permis (metiers, staff)")
            refused(config(function(c) c.families[1].floor = nil end), "families['monde'].floor = 'nil'")
        end)

        it('refuse une surcharge hors des droits permis', function()
            refused(config(function(c) c.rights.overrides['vava_magic:sorts'] = 'view' end),
                "rights.overrides['vava_magic:sorts'] = 'view' : pas un droit permis")
            refused(config(function(c) c.rights.overrides = 'staff' end), 'rights.overrides : table attendue')
        end)

        it('refuse un droit d\'ouvrir hors des droits permis', function()
            refused(config(function(c) c.rights.open = 'tools' end), "rights.open = 'tools' : pas un droit permis")
            refused(config(function(c) c.rights.open = nil end), "rights.open = 'nil'")
        end)

        it('refuse une liste de droits permis vide ou fausse', function()
            refused(config(function(c) c.rights.allowed = {} end), 'rights.allowed : liste de droits attendue')
            refused(config(function(c) c.rights.allowed = { 'metiers', 3 } end), 'rights.allowed[2] : nom de droit')
            refused({}, 'rights.allowed')
        end)
    end)

    it('tous les droits permis détenus : aucun filtre de droit', function()
        assert.is_true(rights.coversAll(settings.allowed, { 'metiers', 'staff' }))
        assert.is_true(rights.coversAll(settings.allowed, { 'staff', 'metiers' }))
        assert.is_false(rights.coversAll(settings.allowed, { 'metiers' }))
        assert.is_false(rights.coversAll(settings.allowed, {}))
    end)

    it('rang d\'un droit', function()
        assert.equal(1, rights.rank(settings.allowed, 'metiers'))
        assert.equal(2, rights.rank(settings.allowed, 'staff'))
        assert.is_nil(rights.rank(settings.allowed, 'view'))
        assert.is_true(rights.holds({ 'metiers' }, 'metiers'))
        assert.is_false(rights.holds({ 'metiers' }, 'staff'))
    end)
end)
