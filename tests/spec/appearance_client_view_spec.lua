local helper = require('tests.helper')

-- Apparence vue du client (T-142, lot 3 de T-132 ; relecture réseau R-2) : shared/appearance.lua, servi aux joueurs,
-- lit la config (emplacements proposés, apparences de départ) ; il est essayé sur la SEULE vue client (constantes et
-- config_client.lua, comme chez un joueur ; config.lua n'est pas lu), et doit rendre la même apparence de départ que
-- sur la config complète du serveur.

local DIR = 'modules/vava_appearance'

local function load(full)
    helper.reset()
    if full then
        helper.loadAll({ DIR .. '/shared/constants.lua', DIR .. '/config.lua', DIR .. '/shared/appearance.lua' })
    else
        helper.loadClientView(DIR, 'VavaAppearance')
        helper.load(DIR .. '/shared/appearance.lua')
    end
    return VavaAppearance
end

describe('vava_appearance vu du client (config_client.lua seul)', function()
    after_each(function() VavaAppearance = nil end)

    it('la vue client ne contient pas les réglages du seul serveur', function()
        local mod = load(false)
        assert.is_true(mod.config.clientFile)
        assert.is_nil(mod.config.maxDrawable)
        assert.is_nil(mod.config.createRateLimit)
    end)

    it('apparence de départ de chaque sexe : complète, aux emplacements proposés', function()
        local mod = load(false)
        for _, sex in ipairs({ 'm', 'f' }) do
            local look = mod.default(sex)
            assert.equal(mod.LIMITS.features, #look.features)
            assert.equal(#mod.OVERLAYS, #look.overlays)
            assert.equal(#mod.config.components, #look.components)
            for i, id in ipairs(mod.config.components) do
                assert.equal(id, look.components[i].id)
                assert.equal(mod.config.defaults[sex].components[id] or 0, look.components[i].drawable)
            end
            assert.equal(#mod.config.props, #look.props)
            for _, prop in ipairs(look.props) do assert.equal(-1, prop.drawable) end
        end
        -- sexe inconnu : celle de 'm'
        assert.same(mod.default('m'), mod.default('x'))
    end)

    it('même apparence de départ que sur la config complète du serveur', function()
        local server = { m = load(true).default('m'), f = VavaAppearance.default('f') }
        local client = load(false)
        assert.same(server.m, client.default('m'))
        assert.same(server.f, client.default('f'))
    end)
end)
