local helper = require('tests.helper')

-- Règles pures de l'arrivée (modules/vava_arrival/shared/rules.lua, T-022) et config du module. Règles documentées :
-- README du module (« Règles ») et docs/plan/specs/T-022.md § 7 et § 11.

describe('vava_arrival rules', function()
    local rules, cfg

    before_each(function()
        helper.reset()
        VavaArrival = nil
        helper.loadAll({
            'modules/vava_arrival/shared/constants.lua',
            'modules/vava_arrival/config.lua',
            'modules/vava_arrival/shared/rules.lua',
        })
        rules, cfg = VavaArrival.rules, VavaArrival.config
    end)

    describe('validateKit', function()
        it('accepte la dotation par défaut et une dotation vide', function()
            assert.same({ true }, { rules.validateKit(cfg.kit.items) })
            assert.same({ true }, { rules.validateKit({}) })
        end)

        it('refuse plus de 8 entrées', function()
            local items = {}
            for i = 1, 9 do items[i] = { item = 'objet_' .. i, quantity = 1 } end
            assert.same({ false, 'too_many' }, { rules.validateKit(items) })
            items[9] = nil
            assert.is_true(rules.validateKit(items))
        end)

        it('refuse une quantité nulle, au-delà de 100 ou à virgule', function()
            for _, quantity in ipairs({ 0, 101, 1.5, -1, '2' }) do
                assert.same({ false, 'invalid_quantity' }, { rules.validateKit({ { item = 'pain', quantity = quantity } }) }, tostring(quantity))
            end
            assert.is_true(rules.validateKit({ { item = 'pain', quantity = 100 } }))
        end)

        it('refuse un objet vide, avec une espace ou de plus de 64 octets', function()
            for _, item in ipairs({ '', 'a b', string.rep('a', 65), 42 }) do
                assert.same({ false, 'invalid_item' }, { rules.validateKit({ { item = item, quantity = 1 } }) }, tostring(item))
            end
            assert.is_true(rules.validateKit({ { item = string.rep('a', 64), quantity = 1 } }))
        end)

        it('refuse un même objet deux fois', function()
            assert.same({ false, 'duplicate' }, { rules.validateKit({ { item = 'pain', quantity = 1 }, { item = 'pain', quantity = 2 } }) })
        end)

        it('refuse une table mixte ou qui n\'est pas une liste', function()
            assert.same({ false, 'invalid_list' }, { rules.validateKit({ { item = 'pain', quantity = 1 }, label = 'x' }) })
            assert.same({ false, 'invalid_list' }, { rules.validateKit({ pain = { item = 'pain', quantity = 1 } }) })
            assert.same({ false, 'invalid_list' }, { rules.validateKit({ [2] = { item = 'pain', quantity = 1 } }) })
            assert.same({ false, 'invalid_list' }, { rules.validateKit('pain') })
            assert.same({ false, 'invalid_item' }, { rules.validateKit({ 'pain' }) })
        end)
    end)

    describe('onLoad', function()
        it('crée la ligne d\'un personnage sans ligne et sans temps de jeu', function()
            assert.same({ action = 'create' }, rules.onLoad(nil, 0))
        end)

        it('ignore un personnage ancien (temps de jeu non nul, ou inconnu)', function()
            assert.same({ action = 'ignore' }, rules.onLoad(nil, 1))
            assert.same({ action = 'ignore' }, rules.onLoad(nil, nil))
        end)

        it('reprend une ligne existante telle quelle', function()
            assert.same({ action = 'resume', kit = 'due', uncertain = false }, rules.onLoad({ kit = 'due' }, 500))
            assert.same({ action = 'resume', kit = 'given', uncertain = false }, rules.onLoad({ kit = 'given' }, 0))
        end)

        it('passe une dotation réservée ou un état inconnu à « incertaine »', function()
            assert.same({ action = 'resume', kit = 'uncertain', uncertain = true }, rules.onLoad({ kit = 'claimed' }, 0))
            assert.same({ action = 'resume', kit = 'uncertain', uncertain = true }, rules.onLoad({ kit = 'x' }, 0))
            assert.same({ action = 'resume', kit = 'uncertain', uncertain = false }, rules.onLoad({ kit = 'uncertain' }, 0))
        end)
    end)

    describe('plan', function()
        local function entry(fields)
            local base = { kit = 'due', welcomeSends = 0, busy = false, awaitingAck = false }
            for key, value in pairs(fields or {}) do base[key] = value end
            return base
        end

        it('dotation et accueil pour une arrivée jamais vue', function()
            assert.same({ kit = true, welcome = true }, rules.plan(entry(), 3))
        end)

        it('rien pour une dotation donnée et un accueil vu', function()
            assert.same({ kit = false, welcome = false }, rules.plan(entry({ kit = 'given', welcomedAt = 100, welcomeSends = 1 }), 3))
        end)

        it('accueil seul tant qu\'il reste des envois, rien après le dernier', function()
            assert.same({ kit = false, welcome = true }, rules.plan(entry({ kit = 'given', welcomeSends = 2 }), 3))
            assert.same({ kit = false, welcome = false }, rules.plan(entry({ kit = 'given', welcomeSends = 3 }), 3))
        end)

        it('accueil seul pour une dotation retenue', function()
            assert.same({ kit = false, welcome = true }, rules.plan(entry({ kit = 'withheld' }), 3))
        end)

        it('rien pendant une arrivée en cours, et l\'accueil une fois par session', function()
            assert.same({ kit = false, welcome = false }, rules.plan(entry({ busy = true }), 3))
            assert.same({ kit = true, welcome = false }, rules.plan(entry({ awaitingAck = true, welcomeSends = 1 }), 3))
        end)
    end)

    it('limite du compte', function()
        assert.is_false(rules.capReached(2, 3))
        assert.is_true(rules.capReached(3, 3))
        assert.is_true(rules.capReached(4, 3))
        assert.is_false(rules.capReached(10, 0))
        assert.equal(1000000 - 2592000, rules.capSince(1000000, 30))
        assert.equal('integer', math.type(rules.capSince(1000000, 30)))
    end)

    it('écran prêt seulement sans pause, sans focus d\'interface et fondu fini', function()
        assert.is_true(rules.welcomeReady({ paused = false, nuiFocused = false, fadedIn = true }))
        assert.is_false(rules.welcomeReady({ paused = true, nuiFocused = false, fadedIn = true }))
        assert.is_false(rules.welcomeReady({ paused = false, nuiFocused = true, fadedIn = true }))
        assert.is_false(rules.welcomeReady({ paused = false, nuiFocused = false, fadedIn = false }))
    end)

    describe('parseCommand', function()
        it('lit une action et un numéro de joueur', function()
            assert.same({ 'etat', 3 }, { rules.parseCommand({ 'etat', '3' }) })
            assert.same({ 'redoter', 65535 }, { rules.parseCommand({ 'redoter', '65535' }) })
            assert.same({ 'rejouer', 12 }, { rules.parseCommand({ 'rejouer', '12', 'reste' }) })
        end)

        it('refuse le reste', function()
            for _, args in ipairs({ { 'redoter', '0' }, { 'redoter', '3.5' }, { 'rejouer', '70000' }, { 'x', '3' }, {}, { 'etat' },
                { 'etat', '-3' }, { 'etat', '3e1' }, { 'etat', '000000003' } }) do
                assert.same({ nil, 'usage' }, { rules.parseCommand(args) }, table.concat(args, ' '))
            end
            assert.same({ nil, 'usage' }, { rules.parseCommand(nil) })
        end)
    end)

    describe('describe', function()
        local messages, who
        local AT = 1761832800

        before_each(function()
            messages = cfg.messages.admin
            who = { name = 'Aldric Morn', source = 4, characterId = 17 }
        end)

        local function line(kitText, welcomeText)
            return string.format(messages.state, 'Aldric Morn', 4, 17, kitText, welcomeText)
        end

        it('écrit chaque état de la dotation avec sa date', function()
            local date = os.date(messages.dateFormat, AT)
            local never = messages.welcomeStates.never
            assert.equal(line('à donner', never), rules.describe({ kit = 'due', welcomeSends = 0 }, messages, who))
            assert.equal(line('en cours', never), rules.describe({ kit = 'claimed', kitAt = AT, welcomeSends = 0 }, messages, who))
            assert.equal(line('donnée le ' .. date, never), rules.describe({ kit = 'given', kitAt = AT, welcomeSends = 0 }, messages, who))
            assert.equal(line('retenue le ' .. date .. ' (limite du compte)', never),
                rules.describe({ kit = 'withheld', kitAt = AT, welcomeSends = 0 }, messages, who))
            assert.equal(line('incertaine depuis le ' .. date .. ' (à vérifier)', never),
                rules.describe({ kit = 'uncertain', kitAt = AT, welcomeSends = 0 }, messages, who))
            assert.equal(line('aucune (arrivé avant l\'accueil)', never), rules.describe({ kit = 'none', welcomeSends = 0 }, messages, who))
        end)

        it('écrit chaque état de l\'accueil', function()
            local date = os.date(messages.dateFormat, AT)
            assert.equal(line('à donner', 'vu le ' .. date), rules.describe({ kit = 'due', welcomedAt = AT, welcomeSends = 1 }, messages, who))
            assert.equal(line('à donner', 'envoyé 2 fois, pas encore vu'), rules.describe({ kit = 'due', welcomeSends = 2 }, messages, who))
            assert.equal(line('à donner', 'jamais envoyé'), rules.describe({ kit = 'due', welcomeSends = 0 }, messages, who))
        end)

        it('dit qu\'un personnage sans ligne est arrivé avant l\'accueil', function()
            assert.equal(string.format(messages.unknown, 'Aldric Morn', 4, 17), rules.describe(nil, messages, who))
        end)

        it('écrit une date manquante et un état inconnu sans erreur', function()
            assert.matches('donnée le %?', rules.describe({ kit = 'given', welcomeSends = 0 }, messages, who))
            assert.matches('dotation bizarre', rules.describe({ kit = 'bizarre', welcomeSends = 0 }, messages, who))
        end)
    end)

    it('donne le libellé d\'un code, ou le code tel quel', function()
        local codes = cfg.messages.admin.codes
        assert.equal('besace pleine', rules.codeLabel('no_space', codes))
        assert.equal('le joueur a changé de personnage', rules.codeLabel('changed', codes))
        assert.equal('db_error', rules.codeLabel('db_error', codes))
    end)

    describe('config', function()
        it('a une dotation valide dont chaque objet est déclaré par le module', function()
            assert.is_true(rules.validateKit(cfg.kit.items))
            for _, entry in ipairs(cfg.kit.items) do
                assert.is_table(cfg.items[entry.item], entry.item)
            end
            assert.is_table(cfg.items.pain)
            assert.is_table(cfg.items.eau)
        end)

        it('déclare des objets à la forme attendue par l\'inventaire, sans image écrite en dur', function()
            for name, def in pairs(cfg.items) do
                assert.is_true(rules.isId(name), name)
                assert.is_string(def.label, name)
                assert.equal('integer', math.type(def.width), name)
                assert.equal('integer', math.type(def.height), name)
                assert.equal('integer', math.type(def.weight), name)
                assert.equal('integer', math.type(def.stack), name)
                assert.is_nil(def.image, name)
            end
        end)

        it('vise un chapitre du Codex au bon motif', function()
            assert.is_true(rules.isId(cfg.codex.chapter))
        end)

        it('tient ses textes dans une notification du HUD et ses libellés dans le journal du Registre', function()
            for _, key in ipairs({ 'welcome', 'kit', 'codexHint' }) do
                local text = cfg.messages[key]
                assert.is_true(utf8.len(text) ~= nil, key)
                -- le HUD coupe au-delà de 200 octets : la limite tient en octets (plus stricte qu'en caractères)
                assert.is_true(#text <= VavaArrival.MAX_NOTIFICATION, key .. ' : ' .. #text .. ' octets')
            end
            for key, label in pairs(cfg.messages.journal) do
                assert.is_true(#label <= VavaArrival.MAX_JOURNAL_LABEL, key)
            end
        end)

        it('a des bornes sensées', function()
            local cap = cfg.kit.perAccount
            assert.equal('integer', math.type(cap.max))
            assert.is_true(cap.max >= 0 and cap.days > 0)
            assert.is_true(cfg.welcome.maxSends >= 1)
            assert.is_true(cfg.welcome.retryMs > 0 and cfg.welcome.maxWaitMs >= cfg.welcome.retryMs)
            assert.is_true(cfg.rateLimits.welcomed.capacity >= 1 and cfg.rateLimits.welcomed.refillPerSecond >= 0.01)
        end)
    end)
end)
