local helper = require('tests.helper')

-- Réglages du joueur (vava_pause 1.0.0, T-145 § 5.2) : logique pure de shared/settings.lua, sur la vue client.
describe('vava_pause : réglages du joueur', function()
    local settings, list
    local DEFAULTS = { ['ui.scale'] = 100, ['hud.notifyDuration'] = 'normale', ['voice.circle'] = true }

    -- aller-retour sans JSON : la table encodée est rendue telle quelle par le « décodeur »
    local stored = {}
    local function encode(value) stored[#stored + 1] = value; return '#' .. #stored end
    local function decode(text)
        local index = tonumber(text:match('^#(%d+)$'))
        if not index then error('illisible') end
        return stored[index]
    end

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_pause', 'VavaPause')
        helper.load('modules/vava_pause/shared/settings.lua')
        settings = VavaPause.settings
        list = VavaPause.config.settings.list
    end)

    it('défauts', function()
        assert.same(DEFAULTS, settings.defaults(list))
    end)

    it('texte absent, vide, illisible ou trop long : défauts', function()
        assert.same(DEFAULTS, settings.read(nil, list, decode))
        assert.same(DEFAULTS, settings.read('', list, decode))
        assert.same(DEFAULTS, settings.read('pas du json', list, decode))
        assert.same(DEFAULTS, settings.read(string.rep('x', 5000), list, decode))
        assert.same(DEFAULTS, settings.normalize('texte', list))
    end)

    it('clé inconnue retirée, valeurs permises gardées', function()
        local values = settings.normalize({ ['ui.scale'] = 115, ['hud.notifyDuration'] = 'longue', ['voice.circle'] = false,
            ['autre.chose'] = 1 }, list)
        assert.same({ ['ui.scale'] = 115, ['hud.notifyDuration'] = 'longue', ['voice.circle'] = false }, values)
    end)

    it('choix hors liste, type faux, NaN : défaut de la clé', function()
        assert.equal(100, settings.normalize({ ['ui.scale'] = 120 }, list)['ui.scale'])
        assert.equal(100, settings.normalize({ ['ui.scale'] = '115' }, list)['ui.scale'])
        assert.equal(100, settings.normalize({ ['ui.scale'] = 0 / 0 }, list)['ui.scale'])
        assert.equal('normale', settings.normalize({ ['hud.notifyDuration'] = 'éternelle' }, list)['hud.notifyDuration'])
    end)

    it('un choix lu en flottant (115.0) rend la valeur de la liste', function()
        local value = settings.normalize({ ['ui.scale'] = 115.0 }, list)['ui.scale']
        assert.equal(115, value)
        assert.equal('integer', math.type(value))
    end)

    it('levier : booléen seulement', function()
        assert.is_true(settings.normalize({ ['voice.circle'] = 0 }, list)['voice.circle'])
        assert.is_true(settings.normalize({ ['voice.circle'] = 'false' }, list)['voice.circle'])
        assert.is_false(settings.normalize({ ['voice.circle'] = false }, list)['voice.circle'])
    end)

    it('validate : unknown_setting, invalid_value, valeur canonique', function()
        assert.same({ false, 'unknown_setting' }, { settings.validate(list, 'rien', 1) })
        assert.same({ false, 'unknown_setting' }, { settings.validate(list, 12, 1) })
        assert.same({ false, 'invalid_value' }, { settings.validate(list, 'ui.scale', 101) })
        assert.same({ false, 'invalid_value' }, { settings.validate(list, 'voice.circle', 'oui') })
        assert.same({ true, 90 }, { settings.validate(list, 'ui.scale', 90.0) })
        assert.same({ true, false }, { settings.validate(list, 'voice.circle', false) })
    end)

    it('uses : un réglage n\'apparaît que si une de ses ressources tourne', function()
        local running = { vava_pause = true }
        local visible = settings.visible(list, function(name) return running[name] == true end)
        assert.equal(1, #visible)
        assert.equal('ui.scale', visible[1].key)
        assert.is_nil(visible[1].uses)
        running.vava_hud, running.vava_voice = true, true
        assert.equal(3, #settings.visible(list, function(name) return running[name] == true end))
    end)

    it('aller-retour : encodable puis read rend les mêmes valeurs', function()
        local values = { ['ui.scale'] = 115, ['hud.notifyDuration'] = 'courte', ['voice.circle'] = false, extra = 1 }
        local kept = settings.encodable(values, list)
        assert.is_nil(kept.extra)
        assert.same({ ['ui.scale'] = 115, ['hud.notifyDuration'] = 'courte', ['voice.circle'] = false },
            settings.read(encode(kept), list, decode))
    end)

    it('chaque réglage de la config est bien formé (défaut permis, libellés, onglet)', function()
        for _, def in ipairs(list) do
            assert.same({ true, def.default }, { settings.validate(list, def.key, def.default) })
            assert.is_string(def.label)
            assert.is_string(def.help)
            assert.is_true(def.tab == 'interface' or def.tab == 'voix' or def.tab == 'touches')
            assert.is_true(#def.key <= VavaPause.MAX_SETTING_KEY)
            if def.kind == 'choice' then assert.equal(#def.choices, #def.labels) end
        end
    end)
end)
