local helper = require('tests.helper')

-- Chiffres des coups (vava_hud 1.7.0, T-155 § 8.1 et § 11.1) : règles pures de modules/vava_hud/shared/numbers.lua,
-- sur la config du client (config_client.lua) : arguments de hitText, mise en forme, texte et classes, réglage du
-- joueur, cascade, fenêtre d'une seconde, contrôle de la config.
describe('vava_hud : règles des chiffres des coups', function()
    local rules, cfg

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    before_each(function()
        helper.reset()
        VavaHud = nil
        helper.loadAll({ 'modules/vava_hud/config_client.lua', 'modules/vava_hud/shared/numbers.lua' })
        rules, cfg = VavaHud.numberRules, VavaHud.config.numbers
    end)

    after_each(function() VavaHud = nil end)

    describe('check', function()
        it('côté : dealt et taken seulement', function()
            assert.is_nil(rules.check('dealt', 3, 'hit', 120))
            assert.is_nil(rules.check('taken', 3, 'hit', 120))
            assert.equal('invalid_side', rules.check('witness', 3, 'hit', 120))
            assert.equal('invalid_side', rules.check(nil, 3, 'hit', 120))
        end)

        it('ancre : joueur de 1 à 65 535, ou point fini et borné, jamais une table mixte', function()
            for _, bad in ipairs({ 0, 65536, 1.5, '3', true, -1, 0 / 0 }) do
                assert.equal('invalid_anchor', rules.check('dealt', bad, 'hit', 10))
            end
            assert.is_nil(rules.check('dealt', 65535, 'hit', 10))
            assert.is_nil(rules.check('dealt', 4.0, 'hit', 10))
            assert.is_nil(rules.check('dealt', { x = 1.5, y = -2, z = 30 }, 'hit', 10))
            assert.is_nil(rules.check('dealt', { 1.5, -2, 30 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 0 / 0, y = 0, z = 0 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 60000, y = 0, z = 0 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 0, y = 0, z = 5001 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 1, y = 2, z = 3, [1] = 1 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 1, y = 2 }, 'hit', 10))
            assert.equal('invalid_anchor', rules.check('dealt', { x = 1, y = 2, z = '3' }, 'hit', 10))
        end)

        it('issue : la liste fermée (combat et magie)', function()
            for _, issue in ipairs({ 'hit', 'tick', 'stagger', 'down', 'block', 'break', 'parry', 'dodge', 'absorb' }) do
                assert.is_nil(rules.check('dealt', 3, issue, nil))
            end
            assert.equal('invalid_issue', rules.check('dealt', 3, 'heal', nil))
            assert.equal('invalid_issue', rules.check('dealt', 3, nil, nil))
        end)

        it('dixièmes : nil, ou entier de 0 à 2 000', function()
            assert.is_nil(rules.check('dealt', 3, 'hit', nil))
            assert.is_nil(rules.check('dealt', 3, 'hit', 0))
            assert.is_nil(rules.check('dealt', 3, 'hit', 2000))
            for _, bad in ipairs({ -1, 2001, 7.5, '12', false, 0 / 0 }) do
                assert.equal('invalid_amount', rules.check('dealt', 3, 'hit', bad))
            end
        end)
    end)

    describe('format', function()
        it('entier : arrondi, au moins 1 dès que le coup porte, 0 → rien', function()
            assert.equal('7', rules.format(72, 0))
            assert.equal('8', rules.format(75, 0))
            assert.equal('1', rules.format(4, 0))
            assert.equal('200', rules.format(2000, 0))
            assert.is_nil(rules.format(0, 0))
            assert.is_nil(rules.format(nil, 0))
        end)

        it('un chiffre après la virgule', function()
            assert.equal('7,2', rules.format(72, 1))
            assert.equal('12', rules.format(120, 1))
            assert.equal('21,6', rules.format(216, 1))
            assert.equal('0,4', rules.format(4, 1))
        end)
    end)

    describe('compose', function()
        it('coup qui porte : le chiffre ; 0 : « Sans effet » en mot', function()
            assert.same({ text = '12', cls = 'dealt' }, rules.compose('dealt', 'hit', 120, cfg))
            assert.same({ text = '12', cls = 'taken' }, rules.compose('taken', 'hit', 120, cfg))
            assert.same({ text = 'Sans effet', cls = 'dealt word' }, rules.compose('dealt', 'hit', 0, cfg))
        end)

        it('bloqué : le reste et le mot dessous ; rien passé : le mot seul', function()
            assert.same({ text = '7', sub = 'Bloqué', cls = 'dealt' }, rules.compose('dealt', 'block', 72, cfg))
            assert.same({ text = 'Bloqué', cls = 'dealt word' }, rules.compose('dealt', 'block', nil, cfg))
            assert.same({ text = '4', sub = 'Garde brisée', cls = 'taken' }, rules.compose('taken', 'break', 40, cfg))
            assert.same({ text = 'Garde brisée', cls = 'taken word' }, rules.compose('taken', 'break', nil, cfg))
        end)

        it('chancelle, à terre, morsure : tailles', function()
            assert.same({ text = '22', sub = 'Chancelle', cls = 'dealt big' }, rules.compose('dealt', 'stagger', 216, cfg))
            assert.same({ text = '18', sub = 'À terre', cls = 'taken huge' }, rules.compose('taken', 'down', 180, cfg))
            assert.same({ text = '3', cls = 'dealt small' }, rules.compose('dealt', 'tick', 30, cfg))
            assert.same({ text = 'À terre', cls = 'dealt huge word' }, rules.compose('dealt', 'down', nil, cfg))
        end)

        it('paré, esquivé, absorbé : leurs mots, même si un montant arrive', function()
            assert.same({ text = 'Paré', cls = 'dealt word' }, rules.compose('dealt', 'parry', nil, cfg))
            assert.same({ text = 'Esquivé', cls = 'taken word' }, rules.compose('taken', 'dodge', nil, cfg))
            assert.same({ text = 'Absorbé', cls = 'dealt word' }, rules.compose('dealt', 'absorb', 50, cfg))
        end)

        it('un chiffre après la virgule si decimals = 1', function()
            cfg.decimals = 1
            assert.same({ text = '7,2', cls = 'dealt' }, rules.compose('dealt', 'hit', 72, cfg))
        end)
    end)

    describe('allowed', function()
        it('tous, infliges, aucun ; inconnu : le défaut', function()
            assert.is_true(rules.allowed('tous', 'dealt', 'tous'))
            assert.is_true(rules.allowed('tous', 'taken', 'tous'))
            assert.is_true(rules.allowed('infliges', 'dealt', 'tous'))
            assert.is_false(rules.allowed('infliges', 'taken', 'tous'))
            assert.is_false(rules.allowed('aucun', 'dealt', 'tous'))
            assert.is_false(rules.allowed('aucun', 'taken', 'tous'))
            assert.is_true(rules.allowed(nil, 'taken', 'tous'))
            assert.is_false(rules.allowed('bizarre', 'taken', 'infliges'))
            assert.is_true(rules.allowed(42, 'dealt', 'infliges'))
        end)
    end)

    describe('stack', function()
        local function half() return 0.5 end

        it('premier : cran 0 ; suivant dans stackMs : cran 1, de l\'autre côté ; au-delà : cran 0', function()
            local first, last = rules.stack(nil, 1000, cfg, half)
            assert.same({ step = 0, dx = 0, dy = 0 }, first)
            local second
            second, last = rules.stack(last, 1200, cfg, half)
            assert.equal(1, second.step)
            assert.near(cfg.stackStepVw, second.dx, 1e-9)
            assert.near(-cfg.stackStepVh, second.dy, 1e-9)
            local third = rules.stack(last, 1200 + cfg.stackMs, cfg, half)
            assert.equal(0, third.step)
        end)

        it('crans alternés, puis retour au premier après stackMax', function()
            local last, shifts = nil, {}
            for i = 1, 5 do
                shifts[i], last = rules.stack(last, 1000 + i * 100, cfg, half)
            end
            assert.same({ 0, 1, 2, 3, 0 }, { shifts[1].step, shifts[2].step, shifts[3].step, shifts[4].step, shifts[5].step })
            assert.is_true(shifts[2].dx > 0)
            assert.is_true(shifts[3].dx < 0)
            assert.is_true(shifts[4].dx > 0)
            assert.near(-3 * cfg.stackStepVh, shifts[4].dy, 1e-9)
        end)

        it('hasard borné à jitterVw', function()
            local low = rules.stack(nil, 0, cfg, function() return 0 end)
            local high = rules.stack(nil, 0, cfg, function() return 0.999999 end)
            assert.near(-cfg.jitterVw, low.dx, 1e-9)
            assert.is_true(high.dx <= cfg.jitterVw and high.dx > cfg.jitterVw - 1e-4)
        end)
    end)

    describe('window', function()
        it('16 admis dans la seconde, le 17e refusé, admis de nouveau 1 000 ms après le premier', function()
            local state = { at = -1e12, count = 0 }
            for i = 0, 15 do assert.is_true(rules.window(state, 5000 + i * 10, 16)) end
            assert.is_false(rules.window(state, 5999, 16))
            assert.is_true(rules.window(state, 6000, 16))
        end)
    end)

    describe('checkConfig', function()
        it('la config livrée est valide', function()
            assert.is_nil(rules.checkConfig(cfg))
        end)

        -- bornes qui évitent une erreur ou un coût (relecture réseau R-2 : les autres ne sont plus contrôlées)
        it('bornes qui évitent une erreur ou un coût, mots, repli : la raison', function()
            local cases = {
                { 'durationMs', 300 }, { 'durationMs', 900.5 }, { 'durationMs', nil }, { 'maxAlive', 0 },
                { 'maxAlive', 31 }, { 'maxPerSecond', 61 }, { 'followMs', 0 }, { 'followMs', 40 }, { 'stackMax', 0 },
                { 'stackMax', 1.5 },
            }
            for _, case in ipairs(cases) do
                local bad = copy(cfg)
                bad[case[1]] = case[2]
                assert.is_string(rules.checkConfig(bad), case[1])
            end
            local bad = copy(cfg)
            bad.takenFallback = { x = 1.5, y = 0.5 }
            assert.is_string(rules.checkConfig(bad))
            bad = copy(cfg)
            bad.words.parry = ''
            assert.matches('words.parry', rules.checkConfig(bad), 1, true)
            bad = copy(cfg)
            bad.words.parry = string.rep('x', 33)
            assert.is_string(rules.checkConfig(bad))
            bad = copy(cfg)
            bad.words.heal = 'Soigné'
            assert.matches('heal', rules.checkConfig(bad), 1, true)
            bad = copy(cfg)
            bad.words.none = nil
            assert.is_string(rules.checkConfig(bad))
            assert.is_string(rules.checkConfig(nil))
        end)
    end)
end)
