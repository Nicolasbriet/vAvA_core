local helper = require('tests.helper')

-- Garde des ressources d'examples/ (T-024) : mode développement (`set vava_env dev`) et accès (droit vava_admin ou
-- ACE), même fichier dans quatre ressources ; plafond des notes de vava_example ; libellés du journal.
local COPIES = {
    { path = 'examples/vava_dev_characters/shared/guard.lua', global = 'VavaDevCharacters' },
    { path = 'examples/vava_example/shared/guard.lua', global = 'VavaExample' },
    { path = 'examples/vava_anim_test/shared/guard.lua', global = 'VavaAnimTest' },
    { path = 'examples/vava_example_combat/shared/guard.lua', global = 'VavaExampleCombat' },
}

local function loadGuard(copy)
    helper.reset()
    _G[copy.global] = {}
    helper.load(copy.path)
    local guard = _G[copy.global].guard
    _G[copy.global] = nil
    return guard
end

for _, copy in ipairs(COPIES) do
    describe(copy.path, function()
        local guard

        --- Faits d'un appel en mode développement (le cas étudié par chaque test d'accès).
        local function dev(facts)
            facts.devMode = true
            return facts
        end

        before_each(function()
            guard = loadGuard(copy)
        end)

        it('n\'ouvre le mode développement que pour la valeur exacte « dev »', function()
            assert.is_true(guard.isDevMode('dev'))
            assert.equal('vava_env', guard.CONVAR)
            for _, value in ipairs({ 'prod', '', 'DEV', 'Dev', ' dev', 'dev ', 'development', 'true', '1' }) do
                assert.is_false(guard.isDevMode(value), value)
            end
            assert.is_false(guard.isDevMode(nil))
            assert.is_false(guard.isDevMode(1))
            assert.is_false(guard.isDevMode(true))
        end)

        it('ferme par défaut : convar absente → valeur de repli refusée', function()
            assert.is_false(guard.isDevMode(guard.FALLBACK))
            assert.matches('mode développement absent', guard.REFUSAL, 1, true)
        end)

        it('accorde l\'accès par le droit vava_admin', function()
            assert.is_true(guard.allowed(dev({ adminStarted = true, adminCalled = true, adminCan = true, ace = false })))
        end)

        it('accorde l\'accès par l\'ACE, avec ou sans vava_admin', function()
            assert.is_true(guard.allowed(dev({ adminStarted = false, adminCalled = false, adminCan = nil, ace = true })))
            assert.is_true(guard.allowed(dev({ adminStarted = true, adminCalled = true, adminCan = false, ace = true })))
            assert.is_true(guard.allowed(dev({ adminStarted = true, adminCalled = false, adminCan = 'boom', ace = true })))
        end)

        it('refuse sans droit ni ACE', function()
            assert.is_false(guard.allowed(dev({ adminStarted = true, adminCalled = true, adminCan = false, ace = false })))
            assert.is_false(guard.allowed(dev({ adminStarted = false, adminCalled = false, adminCan = nil, ace = false })))
        end)

        it('refuse un export en erreur ou une réponse qui n\'est pas exactement true', function()
            -- pcall échoué : la valeur rendue est le message d'erreur, jamais un droit
            assert.is_false(guard.allowed(dev({ adminStarted = true, adminCalled = false, adminCan = true, ace = false })))
            -- vava_admin arrêté : sa réponse (périmée) ne compte pas
            assert.is_false(guard.allowed(dev({ adminStarted = false, adminCalled = true, adminCan = true, ace = false })))
            for _, value in ipairs({ 1, 'true', {}, 'staff' }) do
                assert.is_false(guard.allowed(dev({ adminStarted = true, adminCalled = true, adminCan = value, ace = false })))
                assert.is_false(guard.allowed(dev({ adminStarted = false, adminCalled = false, ace = value })))
            end
        end)

        it('refuse tout hors du mode développement, droit et ACE compris', function()
            local full = { adminStarted = true, adminCalled = true, adminCan = true, ace = true }
            assert.is_true(guard.allowed(dev(full)))
            for _, mode in ipairs({ false, 'dev', 1 }) do
                full.devMode = mode
                assert.is_false(guard.allowed(full), tostring(mode))
            end
            full.devMode = nil
            assert.is_false(guard.allowed(full))
        end)

        it('refuse sans faits', function()
            assert.is_false(guard.allowed(nil))
            assert.is_false(guard.allowed('staff'))
            assert.is_false(guard.allowed({}))
        end)
    end)
end

describe('garde des examples : copies identiques', function()
    --- Corps du fichier sans les lignes propres à la copie (chemin, renvoi aux autres copies, table du module).
    local function body(path)
        local file = assert(io.open((os.getenv('VAVA_ROOT') or '.') .. '/' .. path, 'r'))
        local lines = {}
        for line in file:lines() do
            line = line:gsub('\r$', '')
            if not line:find('^    vava_[%w_]+/shared/guard%.lua$')
                and not line:find('^    Même fichier dans ') and not line:find('^Vava%w+%.guard = guard$') then
                lines[#lines + 1] = line
            end
        end
        file:close()
        return table.concat(lines, '\n')
    end

    it('les copies ne diffèrent que par leur chemin et leur table', function()
        local reference = body(COPIES[1].path)
        for i = 2, #COPIES do
            assert.equal(reference, body(COPIES[i].path), COPIES[i].path)
        end
    end)
end)

describe('vava_example limits.check', function()
    local limits

    before_each(function()
        helper.reset()
        _G.VavaExample = {}
        helper.load('examples/vava_example/shared/limits.lua')
        limits = _G.VavaExample.limits
        _G.VavaExample = nil
    end)

    it('permet une note sous le plafond', function()
        assert.is_true(limits.check(0, 20))
        assert.is_true(limits.check(19, 20))
    end)

    it('refuse au plafond et au-delà', function()
        assert.same({ false, 'too_many' }, { limits.check(20, 20) })
        assert.same({ false, 'too_many' }, { limits.check(25, 20) })
        assert.same({ false, 'too_many' }, { limits.check(0, 0) })
    end)

    it('lit un compte rendu en texte par oxmysql', function()
        assert.is_true(limits.check('3', 20))
        assert.same({ false, 'too_many' }, { limits.check('20', 20) })
    end)

    it('refuse un compte illisible (erreur de base)', function()
        assert.same({ false, 'count_unknown' }, { limits.check(nil, 20) })
        for _, value in ipairs({ 'abc', '', -1, 1.5, '2.5', {}, true }) do
            assert.same({ false, 'count_unknown' }, { limits.check(value, 20) }, tostring(value))
        end
    end)
end)

describe('vava_dev_characters config', function()
    it('libellés du journal acceptés par vava_admin:log (32 octets au plus)', function()
        helper.reset()
        helper.load('examples/vava_dev_characters/config.lua')
        local cfg = _G.VavaDevCharacters.config
        _G.VavaDevCharacters = nil
        local count = 0
        for key, label in pairs(cfg.journal) do
            count = count + 1
            assert.is_true(#label > 0 and #label <= 32, key .. ' : ' .. #label .. ' octets')
        end
        assert.equal(5, count)
        assert.equal('staff', cfg.access.permission)
        assert.equal('vava.dev', cfg.access.ace)
    end)
end)
