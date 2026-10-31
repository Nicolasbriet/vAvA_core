local helper = require('tests.helper')

-- Exemple de l'Atelier (T-100, examples/vava_example_atelier) : garde du mode développement, règles propres au module
-- (nom unique, lanterne, runes), encadré « Pour comparer ».
describe('vava_example_atelier', function()
    local guard, rules, cfg, previousLocale

    before_each(function()
        -- T-133 : sous une locale Windows à octet unique si le système en a une
        previousLocale = helper.legacyLocale()
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
        helper.restoreLocale(previousLocale)
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

        -- T-133 : `%s` et `string.lower` suivent la locale du système ; sous Windows (cp1252), l'octet 0xA0 de « Š »
        -- passait pour un blanc et le premier octet d'un caractère accentué pour une majuscule. Échoue avec l'ancien
        -- code sous une telle locale (helper.legacyLocale) ; sinon, fixe la règle.
        it('clé du nom : chaque caractère de U+00A0 à U+017F et U+2010 reste de l\'UTF-8 entier', function()
            local codes = {}
            for code = 0xA0, 0x17F do codes[#codes + 1] = code end
            codes[#codes + 1] = 0x2010
            for _, code in ipairs(codes) do
                local key = rules.key(' Panneau ' .. utf8.char(code) .. ' ')
                assert.is_not_nil(utf8.len(key), string.format('U+%04X', code))
            end
            -- majuscule du latin étendu ramenée à sa minuscule, accent gardé ; le reste tel quel
            for _, pair in ipairs({ { 'Š', 'š' }, { 'Ł', 'ł' }, { 'Ġ', 'ġ' }, { 'ı', 'ı' }, { '§', '§' },
                { '\u{2010}', '\u{2010}' } }) do
                assert.equal('panneau ' .. pair[2], rules.key('\tPANNEAU ' .. pair[1] .. ' \r\n'), pair[1])
            end
            assert.equal('chateau', rules.key(' \tChâteau\v\f'))
        end)

        it('clé du nom : apostrophe typographique et casse du latin étendu repliées', function()
            assert.equal(rules.key("L'Ancre"), rules.key('L’ANCRE'))
            assert.equal(rules.key('štěpán łódź'), rules.key('ŠTĚPÁN ŁÓDŹ'))
            assert.equal(rules.key('weiss'), rules.key('Weiß'))
            assert.equal(rules.key('istanbul'), rules.key('İstanbul'))
            -- chaque majuscule de U+0100 à U+017F qui a sa minuscule juste après se replie sur elle
            for _, range in ipairs({ { 0x100, 0x12E }, { 0x132, 0x136 }, { 0x139, 0x147 }, { 0x14A, 0x176 },
                { 0x179, 0x17D } }) do
                for code = range[1], range[2], 2 do
                    assert.equal(utf8.char(code + 1), rules.key(utf8.char(code)), string.format('U+%04X', code))
                end
            end
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

    -- T-101 : fiches en mémoire tenues par l'Atelier (apply, remove, read, index), aller-retour exact, diff
    describe('magasin', function()
        local Store

        before_each(function()
            helper.load('examples/vava_example_atelier/shared/store.lua')
            Store = VavaExampleAtelier.store
        end)

        local function seeded()
            return Store.new({ panneau = cfg.boards, affiche = cfg.posters })
        end

        it('la config est la graine : index dans l\'ordre, affiche avec son panneau', function()
            local s = seeded()
            assert.same({ { id = 'place_du_marche', title = 'Panneau de la place' },
                { id = 'porte_nord', title = 'Pancarte de la porte nord' } }, s:index('panneau'))
            assert.equal('place_du_marche', s:read('affiche', 'foire').parent)
            assert.same({ x = -250.0, y = -930.0, z = 31.2, h = 90.0 }, s:read('panneau', 'place_du_marche').place)
            assert.is_nil(s:read('panneau', 'place_du_marche').id)
        end)

        it('apply d\'une fiche nouvelle → dans index', function()
            local s = seeded()
            assert.is_true(s:apply('panneau', { id = 'lanterne_du_port', version = 1, titre = 'Lanterne du port',
                texte = '' }))
            local index = s:index('panneau')
            assert.equal('lanterne_du_port', index[3].id)
        end)

        it('changement : read rend la nouvelle data, le lieu et le parent exacts ; aller-retour', function()
            local s = seeded()
            local def = s:read('affiche', 'foire')
            def.id, def.version = 'foire', 2
            def.couleur, def.parent = 'rouge', 'porte_nord'
            s:apply('affiche', def)
            local back = s:read('affiche', 'foire')
            assert.equal('rouge', back.couleur)
            assert.equal('porte_nord', back.parent)
            assert.is_nil(back.place)
            local board = s:read('panneau', 'porte_nord')
            board.id, board.version = 'porte_nord', 3
            board.place = { x = 1.0, y = 2.0, z = 3.0, h = 45.0 }
            board.texte = 'Autre'
            s:apply('panneau', board)
            local again = s:read('panneau', 'porte_nord')
            again.id, again.version = 'porte_nord', 3
            assert.same(board, again)
            -- la place d'une fiche connue dans l'ordre ne change pas
            assert.equal('porte_nord', s:index('panneau')[2].id)
            -- les tables rendues sont des copies
            again.place.x = 99
            assert.equal(1.0, s:read('panneau', 'porte_nord').place.x)
        end)

        it('remove → absente', function()
            local s = seeded()
            assert.is_true(s:remove('panneau', 'place_du_marche'))
            assert.is_nil(s:read('panneau', 'place_du_marche'))
            assert.equal(1, #s:index('panneau'))
            assert.is_false(s:remove('panneau', 'place_du_marche'))
        end)

        it('diff : « Texte repeint » si seul le texte change', function()
            local before = seeded():read('panneau', 'place_du_marche')
            local after = seeded():read('panneau', 'place_du_marche')
            after.texte = 'Autre texte'
            assert.equal('Texte repeint', Store.diff('panneau', before, after))
            after.taille = 2
            assert.is_nil(Store.diff('panneau', before, after))
            assert.is_nil(Store.diff('affiche', before, after))
            assert.is_nil(Store.diff('panneau', before, before))
        end)
    end)
end)
