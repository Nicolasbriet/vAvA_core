local helper = require('tests.helper')

-- Exemple de l'Atelier (T-100, examples/vava_example_atelier) : garde du mode développement, règles propres au module
-- (nom unique, lanterne, runes), encadré « Pour comparer ».
describe('vava_example_atelier', function()
    local guard, rules, cfg

    before_each(function()
        helper.reset()
        VavaExampleAtelier = nil
        helper.loadAll({
            'examples/vava_example_atelier/config.lua',
            'examples/vava_example_atelier/shared/guard.lua',
            'examples/vava_example_atelier/shared/rules.lua',
        })
        guard, rules, cfg = VavaExampleAtelier.guard, VavaExampleAtelier.rules, VavaExampleAtelier.config
    end)

    after_each(function()
        VavaExampleAtelier = nil
    end)

    describe('garde', function()
        it('n\'ouvre le mode développement que pour la valeur exacte « dev »', function()
            assert.is_true(guard.isDevMode('dev'))
            assert.equal('vava_env', guard.CONVAR)
            for _, value in ipairs({ 'prod', '', 'DEV', 'Dev', ' dev', 'dev ', 'development', 'true', '1' }) do
                assert.is_false(guard.isDevMode(value), value)
            end
            assert.is_false(guard.isDevMode(nil))
            assert.is_false(guard.isDevMode(true))
        end)

        it('ferme par défaut : convar absente → valeur de repli refusée', function()
            assert.is_false(guard.isDevMode(guard.FALLBACK))
            assert.truthy(guard.REFUSAL:find('mode développement absent', 1, true))
        end)
    end)

    describe('règles des panneaux', function()
        local others

        local function board(over)
            local data = { titre = 'Panneau neuf', texte = '', langue = 'commun', eclaire = false, duree = 3600 }
            for k, v in pairs(over or {}) do data[k] = v end
            return data
        end

        local function texts(errors)
            local out = {}
            for i, e in ipairs(errors) do out[i] = e.field .. ':' .. e.text end
            return out
        end

        before_each(function()
            others = {}
            for i, b in ipairs(cfg.boards) do others[i] = { id = b.id, titre = b.titre } end
        end)

        it('accepte un panneau sans reproche', function()
            assert.same({}, rules.board(board(), others, nil))
        end)

        it('nom unique : accents, casse et blancs ignorés', function()
            local errors = rules.board(board({ titre = 'pancarte de la porte nord' }), others, nil)
            assert.same({ 'titre:' .. rules.TEXTS.duplicate }, texts(errors))
            errors = rules.board(board({ titre = '  PANCARTE DE LA PORTE NÖRD ' }), others, nil)
            assert.same({ 'titre:' .. rules.TEXTS.duplicate }, texts(errors))
            assert.equal(rules.key('Château'), rules.key('chateau'))
        end)

        it('nom unique : l\'entrée elle-même est exclue', function()
            assert.same({}, rules.board(board({ titre = 'Pancarte de la porte nord' }), others, 'porte_nord'))
            assert.equal(1, #rules.board(board({ titre = 'Pancarte de la porte nord' }), others, 'place_du_marche'))
        end)

        it('panneau éclairé : au moins un jour', function()
            local errors = rules.board(board({ eclaire = true, duree = 7200 }), others, nil)
            assert.same({ 'duree:' .. rules.TEXTS.lit }, texts(errors))
            assert.same({}, rules.board(board({ eclaire = true, duree = 86400 }), others, nil))
            assert.same({}, rules.board(board({ eclaire = false, duree = 3600 }), others, nil))
        end)

        it('runes : 120 caractères au plus, comptés en caractères', function()
            local errors = rules.board(board({ langue = 'runes', texte = string.rep('a', 150) }), others, nil)
            assert.same({ 'texte:' .. rules.TEXTS.runes }, texts(errors))
            assert.same({}, rules.board(board({ langue = 'runes', texte = string.rep('é', 120) }), others, nil))
            assert.same({}, rules.board(board({ langue = 'commun', texte = string.rep('a', 150) }), others, nil))
        end)

        it('cumule les reproches', function()
            local errors = rules.board(board({ titre = 'Panneau de la place', eclaire = true, duree = 60,
                langue = 'runes', texte = string.rep('x', 121) }), others, nil)
            assert.equal(3, #errors)
        end)
    end)

    describe('pour comparer', function()
        it('l\'autre panneau du même quartier, sinon le premier autre', function()
            local place = cfg.boards[1]
            assert.same({ title = 'Pour comparer : Pancarte de la porte nord', text = '2,2 m, lisible à 5 m, 30 jours' },
                rules.compare(place, cfg.boards, place.id))
            local same = { id = 'neuf', quartier = 'remparts' }
            assert.equal('Pour comparer : Pancarte de la porte nord', rules.compare(same, cfg.boards, nil).title)
            local alone = { id = 'neuf', quartier = 'port' }
            assert.equal('Pour comparer : Panneau de la place', rules.compare(alone, cfg.boards, nil).title)
            assert.is_nil(rules.compare(place, { place }, place.id))
        end)
    end)
end)
