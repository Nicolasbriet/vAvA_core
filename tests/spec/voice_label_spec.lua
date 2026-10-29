local helper = require('tests.helper')

describe('vava_voice nom de zone', function()
    local label

    before_each(function()
        helper.reset()
        VavaVoice = nil
        helper.loadAll({
            'modules/vava_voice/shared/constants.lua',
            'modules/vava_voice/config.lua',
            'modules/vava_voice/shared/label.lua',
        })
        label = VavaVoice.label
    end)

    it('compte en signes : 40 signes accentués passent, 41 non', function()
        assert.equal(40, VavaVoice.config.zones.labelMax)
        local name = 'Chapelle des évêques et crypte du prieur'
        assert.equal(40, utf8.len(name))
        assert.equal(42, #name)
        assert.equal(name, label.clean(name))
        assert.equal(string.rep('é', 40), label.clean(string.rep('é', 40)))
        local refused, code = label.clean(string.rep('é', 41))
        assert.is_nil(refused)
        assert.equal('label_too_long', code)
    end)

    it('borne le réseau à 4 octets par signe, sans refuser 40 signes de 4 octets', function()
        assert.equal(160, label.BYTES_MAX)
        local emoji = '\u{1F56F}'
        assert.equal(4, #emoji)
        assert.equal(string.rep(emoji, 40), label.clean(string.rep(emoji, 40)))
        local _, code = label.clean(string.rep('a', 161))
        assert.equal('invalid_label', code)
    end)

    it('retire les espaces superflus, compte après nettoyage', function()
        assert.equal('Place du marché', label.clean('  Place   du  marché '))
        assert.equal(string.rep('a', 40), label.clean('   ' .. string.rep('a', 40) .. '   '))
    end)

    it('refuse un nom vide, illisible ou porteur de caractères de contrôle', function()
        for _, value in ipairs({ '', '    ', 'Tri\tbune', 'Tri\nbune', 'Tri\0bune', 'Tri\127bune', '\xff\xfe', 12 }) do
            local refused, code = label.clean(value)
            assert.is_nil(refused)
            assert.equal('invalid_label', code)
        end
        local _, code = label.clean(nil)
        assert.equal('invalid_label', code)
    end)

    it('fournit au schéma du RPC un motif ancré qui refuse les caractères de contrôle', function()
        assert.truthy(('Tribune'):find(label.PATTERN))
        assert.truthy(('Chapelle des évêques'):find(label.PATTERN))
        assert.falsy(('Tri\tbune'):find(label.PATTERN))
        assert.falsy((''):find(label.PATTERN))
    end)

    it('donne au core un schéma réseau valide : tout nom permis passe la barrière du RPC', function()
        local permis, depasse = string.rep('é', 40), string.rep('é', 41)
        helper.loadAll({ 'shared/init.lua', 'config/shared.lua', 'shared/lib/schema.lua', 'config/server.lua' })
        local schema = vAvA.lib.schema
        local bounds = vAvA.config.server.schema
        -- mêmes options que NET_SCHEMA dans server/core/rpc.lua ; même définition que LABEL dans server/main.lua
        local compiled, err = schema.compile({ type = 'string', min = 1, max = label.BYTES_MAX, pattern = label.PATTERN }, {
            net = true, maxStringLength = bounds.maxStringLength,
            maxArrayLength = bounds.maxArrayLength, maxMapEntries = bounds.maxMapEntries,
        })
        assert(compiled, err)
        assert.is_true((schema.validate(compiled, permis)))
        assert.is_true((schema.validate(compiled, string.rep('\u{1F56F}', 40))))
        -- 41 signes passent la barrière en octets : c'est le compte en signes du serveur qui les refuse
        assert.is_true((schema.validate(compiled, depasse)))
        assert.is_nil((label.clean(depasse)))
        assert.is_false((schema.validate(compiled, string.rep('a', label.BYTES_MAX + 1))))
        assert.is_false((schema.validate(compiled, 'Tri\tbune')))
    end)
end)
