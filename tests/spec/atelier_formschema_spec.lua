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
            'modules/vava_atelier/shared/bounds.lua',
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

    -- T-101 : ateliers gardés (apply, remove, essai, format, montée de format, genre, chaîne des parents)
    describe('définitions gardées (T-101)', function()
        local function stored(over)
            local def = editor()
            def.apply, def.remove = noop, noop
            for k, v in pairs(over or {}) do def[k] = v end
            return def
        end

        local function kind(id, parent)
            return { id = id, noun = id, nounPlural = id .. 's', article = 'le', newLabel = 'Nouveau ' .. id,
                layout = 'side', parent = parent, form = editor().kinds[1].form }
        end

        it('éditeur T-100 sans apply toujours accepté ; gardé avec apply et remove, essai, format, upgrade', function()
            assert.same({ true }, { check(editor()) })
            assert.same({ true }, { check(stored()) })
            assert.same({ true }, { check(stored({ trial = noop, endTrial = noop, diff = noop, upgrade = noop, format = 3 })) })
            assert.same({ true }, { check(stored({ format = 1 })) })
            assert.same({ true }, { check(stored({ format = 65535 })) })
        end)

        it('format 0 et 65 536 refusés', function()
            refused(stored({ format = 0 }), 'format')
            refused(stored({ format = 65536 }), 'format')
            refused(stored({ format = 1.5 }), 'format')
            refused(stored({ format = '1' }), 'format')
        end)

        it('apply sans remove (et l\'inverse), trial sans endTrial, trial sans apply refusés', function()
            local def = editor()
            def.apply = noop
            refused(def, 'remove')
            def = editor()
            def.remove = noop
            refused(def, 'apply')
            refused(stored({ trial = noop }), 'endTrial')
            refused(stored({ endTrial = noop }), 'trial')
            def = editor()
            def.trial, def.endTrial = noop, noop
            refused(def, 'trial')
        end)

        it('upgrade non fonction refusée', function()
            refused(stored({ upgrade = 'monter' }), 'upgrade')
        end)

        it('validateLot : fonction facultative d\'un atelier gardé seulement (R-1)', function()
            assert.same({ true }, { check(stored({ validateLot = noop })) })
            refused(stored({ validateLot = 'lot' }), 'validateLot')
            local def = editor()
            def.validateLot = noop
            refused(def, 'validateLot')
        end)

        it('texts.trialLine de 81 octets refusé, 80 accepté', function()
            local def = stored()
            def.texts.trialLine = string.rep('a', 81)
            refused(def, 'texts.trialLine')
            def.texts.trialLine = string.rep('a', 80)
            assert.same({ true }, { check(def) })
        end)

        it('feminine non booléen refusé', function()
            local def = stored()
            def.kinds[1].feminine = 'oui'
            refused(def, 'kinds[1].feminine')
            def.kinds[1].feminine = true
            assert.same({ true }, { check(def) })
        end)

        it('parent en cycle (A → B → A) et chaîne de profondeur 4 refusés ; profondeur 3 acceptée', function()
            local def = stored()
            def.kinds = { kind('a', 'b'), kind('b', 'a') }
            refused(def, 'kinds[1].parent')
            def.kinds = { kind('a'), kind('b', 'a'), kind('c', 'b') }
            assert.same({ true }, { check(def) })
            def.kinds = { kind('a'), kind('b', 'a'), kind('c', 'b'), kind('d', 'c') }
            refused(def, 'kinds[4].parent')
        end)
    end)
end)

-- T-102 : placement en jeu d'un type (rules, template, autoTitle, hintField, hintFormat, ghost) et clés d'éditeur
-- (trialPlay, placeCheck). Règles documentées : spec T-102 § 5.3, docs/api.md (§ vava_atelier, placement).
describe('vava_atelier formschema : placement (T-102)', function()
    local fs, ctx

    local function noop() end

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
            'modules/vava_atelier/shared/formschema.lua',
        })
        fs = VavaAtelier.formschema
        ctx = { families = { monde = true }, rights = { metiers = true }, icons = { recolte = true },
            place = VavaAtelier.config.place }
    end)

    --- Atelier gardé à deux types : une zone (cercle) et ses points (orientés, enfants).
    local function zones()
        return {
            family = 'monde', label = 'Récolte', description = 'Exemple.', icon = 'recolte', right = 'metiers',
            texts = { trial = 'Tester', publish = 'Publier' }, trialPlay = true,
            kinds = {
                { id = 'zone', noun = 'zone', nounPlural = 'zones', article = 'la', newLabel = 'Nouvelle zone',
                    layout = 'side', placement = 'circle', rules = { radius = { min = 10, max = 300, default = 60 } },
                    form = { titleField = 'nom', fields = {
                        { id = 'nom', widget = 'text', charset = 'name', min = 3, max = 40, label = 'Nom', help = 'Aide.' },
                    } } },
                { id = 'node', noun = 'point', nounPlural = 'points', article = 'le', newLabel = 'Nouveau point',
                    layout = 'side', parent = 'zone', placement = 'oriented',
                    rules = { inside = { slack = 5 }, spacing = 2 },
                    template = { 'ressource', 'charges' }, autoTitle = 'ressource', hintField = 'charges',
                    hintFormat = '%s récoltes',
                    ghost = { field = 'ressource', models = {
                        chene = { model = 'prop_tree_oak_01', label = 'chêne de GTA', provisional = true },
                    } },
                    form = { titleField = 'nom', fields = {
                        { id = 'nom', widget = 'text', charset = 'name', min = 1, max = 40, label = 'Nom', help = 'Aide.' },
                        { id = 'ressource', widget = 'select', label = 'Ressource', help = 'Aide.',
                            options = { { value = 'chene', label = 'Chêne' }, { value = 'pin', label = 'Pin' } } },
                        { id = 'charges', widget = 'slider', integer = true, min = 1, max = 20, step = 1,
                            label = 'Récoltes', help = 'Aide.' },
                        { id = 'repousse', widget = 'duration', min = 60, max = 86400, units = { 'min', 'h' },
                            label = 'Repousse', help = 'Aide.' },
                    } } },
            },
            index = noop, read = noop, validate = noop, apply = noop, remove = noop, trial = noop, endTrial = noop,
            placeCheck = noop,
        }
    end

    local function refused(def, path)
        local ok, err = fs.checkEditor(def, ctx)
        assert.is_false(ok, path)
        assert.equal(path .. ' :', err:sub(1, #path + 2), err)
    end

    it('un atelier de récolte complet est accepté', function()
        assert.same({ true }, { fs.checkEditor(zones(), ctx) })
    end)

    it('rules.radius sur un type non cercle refusé ; min > max refusé ; au-delà de config.place refusé', function()
        local def = zones()
        def.kinds[2].rules.radius = { min = 1, max = 5, default = 2 }
        refused(def, 'kinds[2].rules.radius')
        def = zones()
        def.kinds[1].rules.radius = { min = 50, max = 20, default = 30 }
        refused(def, 'kinds[1].rules.radius')
        def = zones()
        def.kinds[1].rules.radius = { min = 10, max = 501, default = 60 }
        refused(def, 'kinds[1].rules.radius')
        def = zones()
        def.kinds[1].rules.radius.default = 5
        refused(def, 'kinds[1].rules.radius')
    end)

    it('rules sans placement, clé inconnue, écart hors bornes refusés', function()
        local def = zones()
        def.kinds[1].placement = nil
        refused(def, 'kinds[1].rules')
        def = zones()
        def.kinds[2].rules.angle = 3
        refused(def, 'kinds[2].rules.angle')
        def = zones()
        def.kinds[2].rules.spacing = 101
        refused(def, 'kinds[2].rules.spacing')
    end)

    it('rules.vertices seulement pour un tracé, dans config.place.polygonPoints', function()
        local def = zones()
        def.kinds[1].rules.vertices = { min = 3, max = 8 }
        refused(def, 'kinds[1].rules.vertices')
        def = zones()
        def.kinds[1].placement, def.kinds[1].rules = 'polygon', { vertices = { min = 3, max = 33 } }
        refused(def, 'kinds[1].rules.vertices')
        def.kinds[1].rules.vertices.max = 32
        assert.same({ true }, { fs.checkEditor(def, ctx) })
    end)

    it('inside sans parent placé en cercle ou en tracé refusé ; slack de 51 m refusé', function()
        local def = zones()
        def.kinds[1].placement = 'point'
        def.kinds[1].rules = nil
        refused(def, 'kinds[2].rules.inside')
        def = zones()
        def.kinds[1].rules.inside = { slack = 1 }
        refused(def, 'kinds[1].rules.inside')
        def = zones()
        def.kinds[2].rules.inside.slack = 51
        refused(def, 'kinds[2].rules.inside.slack')
    end)

    it('template avec le champ titre, un champ inconnu, vide, ou sur un type sans parent refusé', function()
        local def = zones()
        def.kinds[2].template = { 'nom', 'charges' }
        refused(def, 'kinds[2].template[1]')
        def = zones()
        def.kinds[2].template = { 'ressource', 'inconnu' }
        refused(def, 'kinds[2].template[2]')
        def = zones()
        def.kinds[1].template = { 'nom' }
        refused(def, 'kinds[1].template')
        def = zones()
        def.kinds[2].template = {}
        refused(def, 'kinds[2].template')
    end)

    it('autoTitle sur un slider refusé ; sur un type sans parent refusé', function()
        local def = zones()
        def.kinds[2].autoTitle = 'charges'
        refused(def, 'kinds[2].autoTitle')
        def = zones()
        def.kinds[1].autoTitle = 'nom'
        refused(def, 'kinds[1].autoTitle')
    end)

    it('hintFormat sans %s, à deux %s, ou sans hintField refusé ; hintField d\'un autre widget refusé', function()
        local def = zones()
        def.kinds[2].hintFormat = 'récoltes'
        refused(def, 'kinds[2].hintFormat')
        def.kinds[2].hintFormat = '%s et %s'
        refused(def, 'kinds[2].hintFormat')
        def.kinds[2].hintFormat = '%d récoltes'
        refused(def, 'kinds[2].hintFormat')
        def.kinds[2].hintFormat = '%s récoltes (100 %%)'
        assert.same({ true }, { fs.checkEditor(def, ctx) })
        def = zones()
        def.kinds[2].hintField = nil
        refused(def, 'kinds[2].hintFormat')
        def = zones()
        def.kinds[2].hintField = 'ressource'
        refused(def, 'kinds[2].hintField')
        def.kinds[2].hintField = 'repousse'
        assert.same({ true }, { fs.checkEditor(def, ctx) })
    end)

    it('ghost.models de 65 entrées et modèle « a b » refusés ; sans models, un champ model est le modèle', function()
        local def = zones()
        local models = {}
        for i = 1, 65 do models['m' .. i] = { model = 'prop_' .. i } end
        def.kinds[2].ghost.models = models
        refused(def, 'kinds[2].ghost.models')
        def = zones()
        def.kinds[2].ghost.models.chene.model = 'a b'
        refused(def, 'kinds[2].ghost.models.chene.model')
        def = zones()
        def.kinds[2].ghost.models = nil
        refused(def, 'kinds[2].ghost.models')
        def = zones()
        def.kinds[2].ghost.field = 'charges'
        refused(def, 'kinds[2].ghost.field')
        def = zones()
        def.kinds[2].form.fields[2] = { id = 'ressource', widget = 'model', label = 'Apparence', help = 'Aide.',
            choices = { { value = 'prop_tree_oak_01', label = 'Chêne' } } }
        def.kinds[2].ghost = { field = 'ressource' }
        def.kinds[2].autoTitle = nil
        assert.same({ true }, { fs.checkEditor(def, ctx) })
    end)

    it('placeCheck sans apply refusé, non fonction refusé ; trialPlay non booléen, ou sans essai, refusé', function()
        local def = zones()
        def.apply, def.remove, def.trial, def.endTrial, def.trialPlay = nil, nil, nil, nil, nil
        refused(def, 'placeCheck')
        def = zones()
        def.placeCheck = 'oui'
        refused(def, 'placeCheck')
        def = zones()
        def.trialPlay = 'oui'
        refused(def, 'trialPlay')
        def = zones()
        def.trial, def.endTrial = nil, nil
        refused(def, 'trialPlay')
    end)
end)
