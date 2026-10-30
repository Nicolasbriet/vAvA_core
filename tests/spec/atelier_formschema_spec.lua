local helper = require('tests.helper')

-- Déclaration d'un éditeur de l'Atelier (T-100) : ce que le validateur du registre vava_atelier:editors accepte et ce
-- qu'il refuse, chaque refus avec son chemin.
describe('vava_atelier formschema', function()
    local fs, ctx, forms

    local function noop() end

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for k, v in pairs(value) do out[k] = copy(v) end
        return out
    end

    --- Éditeur minimal valide : un type, un formulaire d'un seul champ titre.
    local function editor(form)
        return {
            family = 'monde', label = 'Panneaux', description = 'Exemple.', icon = 'parchemin', right = 'metiers',
            texts = { trial = 'Voir', publish = 'Dresser' },
            kinds = { {
                id = 'panneau', noun = 'panneau', nounPlural = 'panneaux', article = 'le', newLabel = 'Nouveau panneau',
                layout = 'page', form = form or { titleField = 'titre', fields = {
                    { id = 'titre', widget = 'text', charset = 'name', min = 3, max = 40, label = 'Nom', help = 'Aide.' },
                } },
            } },
            index = noop, read = noop, validate = noop,
        }
    end

    --- Formulaire du titre suivi de `field`, à la place n° 2.
    local function withField(field)
        return { titleField = 'titre', fields = {
            { id = 'titre', widget = 'text', charset = 'name', min = 3, max = 40, label = 'Nom', help = 'Aide.' },
            field,
        } }
    end

    local function check(def)
        return fs.checkEditor(def, ctx)
    end

    --- Refus attendu dont le message commence par `path` (« kinds[1].form.fields[2].max »).
    local function refused(def, path)
        local ok, err = check(def)
        assert.is_false(ok, path)
        assert.is_string(err)
        assert.equal(path .. ' :', err:sub(1, #path + 2), err)
    end

    local F = 'kinds[1].form.fields[2]'

    before_each(function()
        helper.reset()
        VavaAtelier, VavaExampleAtelier = nil, nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
            'modules/vava_atelier/shared/formschema.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
            'examples/vava_example_atelier/config.lua',
            'examples/vava_example_atelier/shared/forms.lua',
        })
        fs = VavaAtelier.formschema
        forms = VavaExampleAtelier.forms
        local families, rights, icons = {}, {}, {}
        for _, family in ipairs(VavaAtelier.config.families) do families[family.id] = true end
        for _, right in ipairs(VavaAtelier.config.rights.allowed) do rights[right] = true end
        for _, icon in ipairs(VavaAtelier.ICONS) do icons[icon] = true end
        ctx = { families = families, rights = rights, icons = icons }
    end)

    describe('acceptés', function()
        it('les formulaires de l\'exemple (huit widgets, groupes, volet)', function()
            for _, name in ipairs({ 'panneau', 'affiche', 'proclamation' }) do
                local ok, err = fs.checkForm(forms[name])
                assert.is_true(ok, tostring(err))
            end
            local def = editor(forms.panneau)
            def.options, def.compare = noop, noop
            def.kinds[2] = { id = 'affiche', noun = 'affiche', nounPlural = 'affiches', article = 'l\'',
                newLabel = 'Nouvelle affiche', layout = 'side', parent = 'panneau', placement = 'point', form = forms.affiche }
            assert.same({ true }, { check(def) })
            local widgets = {}
            for _, field in ipairs(forms.panneau.fields) do widgets[field.widget] = true end
            for _, widget in ipairs(VavaAtelier.WIDGETS) do assert.is_true(widgets[widget], widget) end
        end)

        it('un formulaire minimal (un texte titre)', function()
            assert.same({ true }, { check(editor()) })
        end)

        it('40 champs', function()
            local form = { titleField = 'f1', fields = {} }
            for i = 1, 40 do
                form.fields[i] = { id = 'f' .. i, widget = i <= 20 and 'text' or 'slider', charset = i <= 20 and 'name' or nil,
                    max = i <= 20 and 40 or 10, min = i > 20 and 0 or nil, step = i > 20 and 1 or nil, label = 'Champ', help = 'Aide.' }
            end
            assert.same({ true }, { check(editor(form)) })
        end)

        it('une fonction venue d\'une autre ressource (table à __call)', function()
            local def = editor()
            def.validate = setmetatable({}, { __call = noop })
            assert.is_true(fs.isCallable(def.validate))
            assert.same({ true }, { check(def) })
            assert.is_false(fs.isCallable({}))
            assert.is_false(fs.isCallable('validate'))
        end)
    end)

    describe('slider', function()
        local function slider(over)
            local field = { id = 'part', widget = 'slider', min = 0, max = 10, step = 1, label = 'Part', help = 'Aide.' }
            for k, v in pairs(over) do field[k] = v end
            return editor(withField(field))
        end

        it('refuse des bornes, un pas ou un défaut faux', function()
            refused(slider({ max = 0 }), F .. '.max')
            refused(slider({ max = -1 }), F .. '.max')
            refused(slider({ step = 0 }), F .. '.step')
            refused(slider({ max = 2001 }), F .. '.step')
            refused(slider({ max = 10, step = 3 }), F .. '.step')
            refused(slider({ default = 2.5 }), F .. '.default')
            refused(slider({ default = 11 }), F .. '.default')
            refused(slider({ integer = true, step = 0.5 }), F .. '.step')
            refused(slider({ min = 0 / 0 }), F .. '.min')
            refused(slider({ max = math.huge }), F .. '.max')
            refused(slider({ min = -2e9 }), F .. '.min')
            refused(slider({ decimals = 4 }), F .. '.decimals')
            refused(slider({ unit = 'mètres!!' }), F .. '.unit')
        end)

        it('accepte 2 000 pas et un pas décimal juste', function()
            assert.is_true((check(slider({ max = 2000 }))))
            assert.is_true((check(slider({ min = 0.5, max = 3, step = 0.1, default = 1.5, decimals = 1, unit = 'm' }))))
        end)
    end)

    describe('segmented, select, toggle', function()
        local function seg(options, default)
            return editor(withField({ id = 'matiere', widget = 'segmented', options = options, default = default, label = 'Matière', help = 'Aide.' }))
        end
        local function opts(n)
            local out = {}
            for i = 1, n do out[i] = { value = 'v' .. i, label = 'Choix ' .. i } end
            return out
        end

        it('segmented : 2 à 8 choix, valeurs uniques, défaut parmi eux', function()
            refused(seg(opts(1)), F .. '.options')
            refused(seg(opts(9)), F .. '.options')
            local double = opts(2)
            double[2].value = 'v1'
            refused(seg(double), F .. '.options[2].value')
            refused(seg(opts(3), 'v9'), F .. '.default')
            local bad = opts(2)
            bad[1].value = 'a b'
            refused(seg(bad), F .. '.options[1].value')
            assert.is_true((check(seg(opts(8), 'v8'))))
        end)

        it('select : options ou source, jamais les deux ni aucun', function()
            local base = { id = 'langue', widget = 'select', label = 'Langue', help = 'Aide.' }
            local both = copy(base)
            both.options, both.source = opts(2), 'langues'
            refused(editor(withField(both)), F)
            refused(editor(withField(copy(base))), F)
            local source = copy(base)
            source.source = 'langues'
            refused(editor(withField(source)), 'options')        -- source sans fonction options
            local def = editor(withField(source))
            def.options = noop
            assert.is_true((check(def)))
            local static = copy(base)
            static.options, static.default = opts(2), 'v3'
            refused(editor(withField(static)), F .. '.default')
        end)

        it('toggle : défaut booléen obligatoire', function()
            refused(editor(withField({ id = 'eclaire', widget = 'toggle', label = 'Éclairé', help = 'Aide.' })), F .. '.default')
            refused(editor(withField({ id = 'eclaire', widget = 'toggle', default = 'non', label = 'Éclairé', help = 'Aide.' })), F .. '.default')
        end)
    end)

    describe('text, duration, model', function()
        local function textField(over)
            local field = { id = 'texte', widget = 'text', charset = 'free', max = 80, label = 'Texte', help = 'Aide.' }
            for k, v in pairs(over) do field[k] = v end
            return editor(withField(field))
        end

        it('text : longueurs, jeu de caractères, défaut', function()
            refused(textField({ max = 81 }), F .. '.max')
            refused(textField({ max = 301, multiline = true }), F .. '.max')
            assert.is_true((check(textField({ max = 300, multiline = true }))))
            refused(textField({ charset = 'latin' }), F .. '.charset')
            local noCharset = textField({})
            noCharset.kinds[1].form.fields[2].charset = nil
            refused(noCharset, F .. '.charset')
            refused(textField({ charset = 'name', default = 'a;b' }), F .. '.default')
            refused(textField({ charset = 'id', default = 'Forêt' }), F .. '.default')
            refused(textField({ min = 90 }), F .. '.min')
            assert.is_true((check(textField({ charset = 'name', default = 'Forêt de Brume' }))))
        end)

        it('duration : bornes en secondes, unités connues', function()
            local function duration(over)
                local field = { id = 'duree', widget = 'duration', min = 60, max = 3600, units = { 'min', 'h' }, label = 'Durée', help = 'Aide.' }
                for k, v in pairs(over) do field[k] = v end
                return editor(withField(field))
            end
            refused(duration({ min = 0 }), F .. '.min')
            refused(duration({ max = 31536001 }), F .. '.max')
            refused(duration({ units = {} }), F .. '.units')
            refused(duration({ units = { 'semaine' } }), F .. '.units[1]')
            refused(duration({ default = 30 }), F .. '.default')
            assert.is_true((check(duration({ max = 31536000, units = { 's', 'min', 'h', 'j' } }))))
        end)

        it('model : choix ou source, motif des valeurs', function()
            refused(editor(withField({ id = 'modele', widget = 'model', label = 'Modèle', help = 'Aide.' })), F)
            refused(editor(withField({ id = 'modele', widget = 'model', label = 'Modèle', help = 'Aide.',
                choices = { { value = 'prop a', label = 'A' } } })), F .. '.choices[1].value')
            refused(editor(withField({ id = 'modele', widget = 'model', label = 'Modèle', help = 'Aide.', default = 'prop_z',
                choices = { { value = 'prop_a', label = 'A' } } })), F .. '.default')
            assert.is_true((check(editor(withField({ id = 'modele', widget = 'model', label = 'Modèle', help = 'Aide.',
                default = 'prop_z', free = true, choices = { { value = 'prop_a', label = 'A', provisional = true } } })))))
        end)
    end)

    describe('champs et formulaire', function()
        local function field(over)
            local f = { id = 'eclaire', widget = 'toggle', default = false, label = 'Éclairé', help = 'Aide.' }
            for k, v in pairs(over) do f[k] = v end
            return editor(withField(f))
        end

        it('aide, libellé, identifiant', function()
            refused(field({ help = false }), F .. '.help')
            refused(field({ help = string.rep('a', 141) }), F .. '.help')
            refused(field({ label = string.rep('a', 41) }), F .. '.label')
            refused(field({ id = 'titre' }), F .. '.id')
            refused(field({ id = 'place' }), F .. '.id')
            refused(field({ id = '2e' }), F .. '.id')
            refused(field({ id = 'a-b' }), F .. '.id')
            refused(field({ group = 'inconnu' }), F .. '.group')
            refused(field({ widget = 'couleur' }), F .. '.widget')
            refused(field({ couleur = 'rouge' }), F .. '.couleur')
            refused(field({ optional = true }), F .. '.optional')
            refused(field({ width = 'third' }), F .. '.width')
        end)

        it('41 champs, 25 en carte s', function()
            local form = { titleField = 'f1', fields = {} }
            for i = 1, 41 do form.fields[i] = { id = 'f' .. i, widget = 'toggle', default = true, label = 'C', help = 'A.' } end
            form.fields[1] = { id = 'f1', widget = 'text', charset = 'name', max = 40, label = 'Nom', help = 'Aide.' }
            refused(editor(form), 'kinds[1].form.fields')
            local strings = { titleField = 'f1', fields = {} }
            for i = 1, 25 do strings.fields[i] = { id = 'f' .. i, widget = 'text', charset = 'name', max = 40, label = 'C', help = 'A.' } end
            refused(editor(strings), 'kinds[1].form.fields')
        end)

        it('titleField : présent, texte sur une ligne, non facultatif', function()
            local form = withField({ id = 'eclaire', widget = 'toggle', default = false, label = 'Éclairé', help = 'Aide.' })
            form.titleField = nil
            refused(editor(form), 'kinds[1].form.titleField')
            form.titleField = 'eclaire'
            refused(editor(form), 'kinds[1].form.titleField')
            local multi = { titleField = 't', fields = { { id = 't', widget = 'text', charset = 'free', multiline = true, max = 80, label = 'T', help = 'A.' } } }
            refused(editor(multi), 'kinds[1].form.titleField')
            local optional = { titleField = 't', fields = { { id = 't', widget = 'text', charset = 'name', optional = true, max = 40, label = 'T', help = 'A.' } } }
            refused(editor(optional), 'kinds[1].form.titleField')
        end)

        it('clé inconnue du formulaire', function()
            local form = withField({ id = 'eclaire', widget = 'toggle', default = false, label = 'Éclairé', help = 'Aide.' })
            form.sections = {}
            refused(editor(form), 'kinds[1].form.sections')
        end)
    end)

    describe('éditeur', function()
        it('types : nombre, doublons, énumérations, parent', function()
            local def = editor()
            def.kinds = {}
            refused(def, 'kinds')
            def = editor()
            for i = 2, 9 do def.kinds[i] = copy(def.kinds[1]); def.kinds[i].id = 'k' .. i end
            refused(def, 'kinds')
            def = editor()
            def.kinds[2] = copy(def.kinds[1])
            refused(def, 'kinds[2].id')
            for key, value in pairs({ layout = 'fenetre', article = 'les', placement = 'carre' }) do
                def = editor()
                def.kinds[1][key] = value
                refused(def, 'kinds[1].' .. key)
            end
            def = editor()
            def.kinds[1].parent = 'inconnu'
            refused(def, 'kinds[1].parent')
            def.kinds[1].parent = 'panneau'
            refused(def, 'kinds[1].parent')
        end)

        it('droit, famille, icône, fonctions, clé inconnue', function()
            local cases = {
                { 'right', 'view' }, { 'family', 'mer' }, { 'icon', 'dragon' }, { 'validate', false },
                { 'index', 'index' }, { 'label', string.rep('a', 33) }, { 'order', 1000 }, { 'couleur', 'rouge' },
                { 'compare', 'oui' }, { 'texts', nil },
            }
            for _, case in ipairs(cases) do
                local def = editor()
                def[case[1]] = case[2]
                if case[2] == false then def[case[1]] = nil end
                refused(def, case[1])
            end
            local def = editor()
            def.texts.publish = nil
            refused(def, 'texts.publish')
        end)

        it('refuse ce qui n\'est pas une table', function()
            local ok, err = check('éditeur')
            assert.is_false(ok)
            assert.is_string(err)
        end)
    end)

    -- Plafond global d'un descripteur (server/editors.lua : taille du codage canonique ≤ limits.descriptorBytes).
    describe('plafond du descripteur', function()
        --- Descripteur comme le fait l'Atelier : la déclaration sans ses fonctions ni son droit.
        local function descriptorSize(id, def)
            local descriptor = { id = id, hasCompare = def.compare ~= nil }
            for key, value in pairs(def) do
                if type(value) ~= 'function' and key ~= 'right' then descriptor[key] = copy(value) end
            end
            local version, size = VavaAtelier.fingerprintSized(descriptor)
            assert.is_string(version)
            return size
        end

        it('rend la taille du codage canonique avec l\'empreinte', function()
            -- « s5:Codex » et « T2{i1;s1:ai2;s1:b} »
            assert.same({ '37e0166994ef71cc', 8 }, { VavaAtelier.fingerprintSized('Codex') })
            assert.same({ '3ec51810f8a1ab41', 18 }, { VavaAtelier.fingerprintSized({ 'a', 'b' }) })
            assert.equal('37e0166994ef71cc', VavaAtelier.fingerprint('Codex'))
            assert.equal(1, select('#', VavaAtelier.fingerprint('Codex')))
            assert.same({ nil, 'unsupported' }, { VavaAtelier.fingerprintSized(noop) })
        end)

        it('l\'exemple des panneaux tient très en dessous du plafond', function()
            local def = editor(forms.panneau)
            def.kinds[2] = { id = 'affiche', noun = 'affiche', nounPlural = 'affiches', article = 'l\'',
                newLabel = 'Nouvelle affiche', layout = 'side', parent = 'panneau', placement = 'point', form = forms.affiche }
            local size = descriptorSize('vava_example_atelier:panneaux', def)
            assert.is_true(size < VavaAtelier.config.limits.descriptorBytes / 4, tostring(size))
        end)

        it('un éditeur accepté borne par borne peut dépasser le plafond : il sera refusé au chargement', function()
            local help = string.rep('Une aide. ', 14)            -- 140 octets
            local def = editor()
            for k = 1, VavaAtelier.LIMITS.kinds do
                local form = { titleField = 'f1', fields = {} }
                for i = 1, VavaAtelier.LIMITS.fields do
                    local text = i <= 20
                    form.fields[i] = { id = 'f' .. i, widget = text and 'text' or 'slider', charset = text and 'name' or nil,
                        max = text and 40 or 10, min = not text and 0 or nil, step = not text and 1 or nil,
                        label = string.rep('L', 40), help = help }
                end
                def.kinds[k] = { id = 'type' .. k, noun = 'type', nounPlural = 'types', article = 'le',
                    newLabel = 'Nouveau type', layout = 'page', form = form }
            end
            assert.same({ true }, { check(def) })
            assert.is_true(descriptorSize('vava_example_atelier:lourd', def) > VavaAtelier.config.limits.descriptorBytes)
        end)
    end)
end)
