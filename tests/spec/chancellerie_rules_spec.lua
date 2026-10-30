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

    describe('netQuery', function()
        it('lit la vue d\'ensemble, valeur absente ou vide', function()
            assert.same({ scope = 'all', opening = true }, rules.netQuery('all', nil, true))
            assert.same({ scope = 'all', opening = false }, rules.netQuery('all', '', false))
            assert.same({ scope = 'all', opening = false }, rules.netQuery('all', '', nil))
        end)

        it('refuse une valeur donnée à la vue d\'ensemble', function()
            assert.is_nil(rules.netQuery('all', 'vava_codex', true))
            assert.is_nil(rules.netQuery('all', 3, false))
            assert.is_nil(rules.netQuery('all', {}, false))
        end)

        it('lit un module au nom de ressource accepté par core.net.stats (48 signes)', function()
            assert.same({ scope = 'resource', resource = 'vAvA_core', opening = false },
                rules.netQuery('resource', 'vAvA_core', false))
            assert.same({ scope = 'resource', resource = 'vava-ui.2', opening = true },
                rules.netQuery('resource', 'vava-ui.2', true))
            local long = string.rep('a', 48)
            assert.equal(long, rules.netQuery('resource', long, false).resource)
        end)

        it('refuse un nom de ressource vide, trop long ou hors du motif', function()
            for _, name in ipairs({
                '', string.rep('a', 49), 'a/b', 'a b', 'vava_codex\n', '*', '<autres>', 'é', 'a;b', '../x',
            }) do
                local query, err = rules.netQuery('resource', name, false)
                assert.is_nil(query, name)
                assert.equal('invalid_args', err)
            end
            assert.is_nil(rules.netQuery('resource', nil, false))
            assert.is_nil(rules.netQuery('resource', 12, false))
        end)

        it('lit un joueur par son numéro, entier ou flottant entier venu du JSON', function()
            assert.same({ scope = 'player', target = 12, opening = false }, rules.netQuery('player', 12, false))
            assert.equal(7, rules.netQuery('player', 7.0, false).target)
            assert.equal(math.type(rules.netQuery('player', 7.0, false).target), 'integer')
            assert.equal(1, rules.netQuery('player', 1, false).target)
            assert.equal(65535, rules.netQuery('player', 65535, false).target)
        end)

        it('refuse un numéro de joueur hors bornes, fractionnaire, infini, NaN ou en texte', function()
            for _, value in ipairs({ 0, -1, 65536, 1.5, math.huge, -math.huge, 0 / 0, '12', true }) do
                local query, err = rules.netQuery('player', value, false)
                assert.is_nil(query, tostring(value))
                assert.equal('invalid_args', err)
            end
            assert.is_nil(rules.netQuery('player', nil, false))
        end)

        it('refuse une portée inconnue et une ouverture qui n\'est pas un booléen', function()
            for _, scope in ipairs({ 'ALL', 'joueur', '', 1 }) do
                assert.is_nil(rules.netQuery(scope, '', false), tostring(scope))
            end
            assert.is_nil(rules.netQuery(nil, '', false))
            assert.is_nil(rules.netQuery('all', '', 1))
            assert.is_nil(rules.netQuery('all', '', 'true'))
            assert.is_nil(rules.netQuery('player', 3, {}))
        end)
    end)

    describe('netJournal', function()
        local EVERY = 1800000

        local function query(scope, value, opening)
            return rules.netQuery(scope, value, opening)
        end

        it('inscrit l\'ouverture de la page, et la première lecture connue du pont même sans ouverture', function()
            assert.same({ true, false }, { rules.netJournal({}, query('all', '', true), 1000, EVERY) })
            assert.same({ true, false }, { rules.netJournal({}, query('all', '', false), 1000, EVERY) })
            assert.same({ true, false }, { rules.netJournal({ pageAt = 900 }, query('all', '', true), 1000, EVERY) })
        end)

        it('n\'inscrit pas une relecture, d\'un module ou de l\'ensemble, avant l\'échéance', function()
            local state = { pageAt = 1000 }
            assert.same({ false, false }, { rules.netJournal(state, query('all', '', false), 1000 + EVERY - 1, EVERY) })
            assert.same({ false, false },
                { rules.netJournal(state, query('resource', 'vava_codex', false), 5000, EVERY) })
            assert.same({ true, false }, { rules.netJournal(state, query('all', '', false), 1000 + EVERY, EVERY) })
        end)

        it('inscrit chaque autre joueur lu, et le même au plus une fois par échéance', function()
            local state = { pageAt = 2000 }
            assert.same({ false, true }, { rules.netJournal(state, query('player', 4, false), 2000, EVERY) })
            state.player, state.playerAt = 4, 2000
            assert.same({ false, false }, { rules.netJournal(state, query('player', 4, false), 2000 + EVERY - 1, EVERY) })
            assert.same({ false, true }, { rules.netJournal(state, query('player', 5, false), 3000, EVERY) })
            assert.is_true(select(2, rules.netJournal(state, query('player', 4, false), 2000 + EVERY, EVERY)))
        end)

        it('ne compte aucun joueur pour l\'ensemble ou un module', function()
            local state = { pageAt = 1000, player = 4, playerAt = 1000 }
            assert.is_false(select(2, rules.netJournal(state, query('all', '', true), 2000, EVERY)))
            assert.is_false(select(2, rules.netJournal(state, query('resource', 'vAvA_core', true), 2000, EVERY)))
        end)

        it('les deux lignes du journal tiennent dans les 32 octets du Registre', function()
            assert.is_true(#cfg.messages.logNet <= 32)
            assert.is_true(#cfg.messages.logNetPlayer <= 32)
        end)

        it('la page ne peut pas relire plus vite que le pont ne l\'accepte', function()
            assert.is_true(cfg.net.minIntervalMs < 5000)
            assert.is_true(cfg.net.lines >= 1 and cfg.net.lines <= 50)
            assert.equal('tools', cfg.net.permission)
        end)
    end)
end)
