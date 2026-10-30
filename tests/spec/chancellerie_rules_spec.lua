local helper = require('tests.helper')

describe('vava_chancellerie règles du pont', function()
    local rules, cfg

    before_each(function()
        helper.reset()
        VavaBridge = nil
        helper.loadAll({
            'modules/vava_chancellerie/shared/constants.lua',
            'modules/vava_chancellerie/config.lua',
            'modules/vava_chancellerie/shared/rules.lua',
        })
        rules, cfg = VavaBridge.rules, VavaBridge.config
    end)

    describe('validKey', function()
        it('accepte la clé de la Chancellerie : 64 signes hexadécimaux', function()
            assert.is_true(rules.validKey(string.rep('a1', 32), cfg.tokenMin, cfg.key.max))
            assert.is_true(rules.validKey(string.rep('F', 64), cfg.tokenMin, cfg.key.max))
        end)

        it('borne la longueur aux deux bouts', function()
            assert.is_true(rules.validKey(string.rep('0', cfg.tokenMin), cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(string.rep('0', cfg.tokenMin - 1), cfg.tokenMin, cfg.key.max))
            assert.is_true(rules.validKey(string.rep('0', cfg.key.max), cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(string.rep('0', cfg.key.max + 1), cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey('', cfg.tokenMin, cfg.key.max))
        end)

        it('refuse tout signe non hexadécimal, y compris en bout de chaîne', function()
            local base = string.rep('ab', 32)
            assert.is_false(rules.validKey(base:sub(1, 63) .. 'g', cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(' ' .. base:sub(2), cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(base:sub(1, 63) .. '\n', cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(base:sub(1, 32) .. ';' .. base:sub(34), cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(base:sub(1, 63) .. '\0', cfg.tokenMin, cfg.key.max))
        end)

        it('refuse ce qui n\'est pas une chaîne', function()
            assert.is_false(rules.validKey(nil, cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(12345678901234567890, cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey({ string.rep('a', 64) }, cfg.tokenMin, cfg.key.max))
            assert.is_false(rules.validKey(true, cfg.tokenMin, cfg.key.max))
        end)
    end)

    describe('canSync', function()
        it('donne un rang seulement à un compte vu relié en jeu', function()
            assert.is_true(rules.canSync('souverain', true))
            assert.is_true(rules.canSync('gardien', true))
            local ok, err = rules.canSync('souverain', false)
            assert.is_false(ok)
            assert.equal('not_linked_in_game', err)
        end)

        it('retire toujours un rang, compte connu ou non', function()
            assert.is_true(rules.canSync('', false))
            assert.is_true(rules.canSync('', true))
        end)

        it('refuse un rang mal formé pour un compte inconnu, sans le tenir pour un retrait', function()
            assert.is_false(rules.canSync(nil, false))
            assert.is_false(rules.canSync(false, false))
            assert.is_false(rules.canSync(' ', false))
            assert.is_false(rules.canSync('souverain', nil))
            assert.is_false(rules.canSync('souverain', 1))
        end)
    end)

    it('la marque et la commande de la clé sont celles de la Chancellerie (chancellerie/lib/bridge.js)', function()
        local file = assert(io.open((os.getenv('VAVA_ROOT') or '.') .. '/chancellerie/lib/bridge.js', 'r'))
        local source = file:read('a')
        file:close()
        assert.equal(VavaBridge.KEY_COMMAND, source:match("const KEY_COMMAND = '([^']+)'"))
        assert.equal(VavaBridge.KEY_ASK, source:match("const KEY_ASK = '([^']+)'"))
        -- lignes exactes guettées par la Chancellerie (demande de la clé, clé refusée)
        assert.equal(VavaBridge.KEY_ASK_LINE, source:match("const KEY_ASK_LINE = '([^']+)'"))
        assert.equal(VavaBridge.KEY_CONFLICT_LINE, source:match("const KEY_CONFLICT_LINE = '([^']+)'"))
        assert.truthy(VavaBridge.KEY_ASK_LINE:find(VavaBridge.KEY_ASK, 1, true))
        -- aucune clé n'est plus posée sur la ligne de commande
        assert.is_nil(source:find('vava_chancellerie_token', 1, true))
    end)

    it('l\'attente d\'une liaison reste sous le délai d\'une demande de la Chancellerie', function()
        local file = assert(io.open((os.getenv('VAVA_ROOT') or '.') .. '/chancellerie/lib/bridge.js', 'r'))
        local source = file:read('a')
        file:close()
        local timeout = tonumber(source:match('const TIMEOUT_MS = (%d+);'))
        assert.is_number(timeout)
        assert.is_true(cfg.links.waitMs < timeout)
    end)

    describe('forgetsLink', function()
        it('oublie le compte au retrait d\'une déliaison seulement', function()
            assert.is_true(rules.forgetsLink('', true))
            assert.is_false(rules.forgetsLink('', nil))
            assert.is_false(rules.forgetsLink('', 'true'))
            assert.is_false(rules.forgetsLink('gardien', true))
        end)
    end)

    describe('validPanelUrl', function()
        it('accepte la machine elle-même avec un port', function()
            assert.is_true(rules.validPanelUrl('http://127.0.0.1:40120'))
            assert.is_true(rules.validPanelUrl('http://127.0.0.1:1'))
            assert.is_true(rules.validPanelUrl('http://127.0.0.1:65535'))
        end)

        it('refuse toute autre adresse, un port hors bornes ou un chemin', function()
            for _, url in ipairs({
                'http://127.0.0.1:0', 'http://127.0.0.1:65536', 'http://127.0.0.1:123456', 'http://127.0.0.1',
                'https://127.0.0.1:40120', 'http://127.0.0.2:40120', 'http://localhost:40120', 'http://10.0.0.5:40120',
                'http://127.0.0.1:40120/x', 'http://127.0.0.1:40120@evil.example:80', 'http://127a0b0c1:40120',
                ' http://127.0.0.1:40120', '',
            }) do
                assert.is_false(rules.validPanelUrl(url), url)
            end
            assert.is_false(rules.validPanelUrl(nil))
            assert.is_false(rules.validPanelUrl(40120))
        end)
    end)
end)
