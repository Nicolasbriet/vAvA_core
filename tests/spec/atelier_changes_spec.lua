local helper = require('tests.helper')

-- Résumés d'un changement (T-101, shared/changes.lua) : champs changés, enfants d'un lot, numéros, brouillons.
describe('vava_atelier changes', function()
    local changes, texts, drafts, form

    local DAY = 86400

    local function board(over)
        local data = {
            titre = 'Panneau de la place', texte = 'Foire.', langue = 'commun', matiere = 'bois', quartier = 'marche',
            taille = 1.5, portee = 3, eclaire = false, duree = 7 * DAY, offrande = '', modele = 'prop_sign_road_01a',
        }
        for k, v in pairs(over or {}) do data[k] = v end
        return data
    end

    before_each(function()
        helper.reset()
        VavaAtelier, VavaExampleAtelier = nil, nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/changes.lua',
            'examples/vava_example_atelier/config.lua',
            'examples/vava_example_atelier/shared/forms.lua',
        })
        changes = VavaAtelier.changes
        texts = VavaAtelier.config.texts.changes
        drafts = VavaAtelier.config.texts.drafts
        form = VavaExampleAtelier.forms.panneau
    end)

    after_each(function()
        VavaExampleAtelier = nil
    end)

    describe('champs', function()
        it('un nombre', function()
            assert.equal('Hauteur de 1,5 m à 2 m', (changes.fields(form, board(), board({ taille = 2 }), texts)))
        end)

        it('une durée', function()
            assert.equal('Reste affiché de 7 jours à 30 jours',
                (changes.fields(form, board(), board({ duree = 30 * DAY }), texts)))
        end)

        it('un choix (libellé du choix, sans capitale)', function()
            assert.equal('Matière : pierre', (changes.fields(form, board(), board({ matiere = 'pierre' }), texts)))
            assert.equal('Langue : runes', (changes.fields(form, board(), board({ langue = 'runes' }), texts)))
        end)

        it('un interrupteur', function()
            assert.equal('Éclairé la nuit : oui', (changes.fields(form, board(), board({ eclaire = true }), texts)))
            assert.equal('Éclairé la nuit : non', (changes.fields(form, board({ eclaire = true }), board(), texts)))
        end)

        it('textes groupés', function()
            local summary, count = changes.fields(form, board(), board({ titre = 'Autre nom', texte = 'Autre.' }), texts)
            assert.equal('Retouché : Nom du panneau, Ce qui est écrit', summary)
            assert.equal(2, count)
        end)

        it('quatre champs', function()
            local summary, count = changes.fields(form, board(),
                board({ titre = 'X y z', taille = 2, eclaire = true, matiere = 'pierre' }), texts)
            assert.equal(4, count)
            assert.equal('4 réglages changés : Nom du panneau, Matière, Hauteur, Éclairé la nuit', summary)
        end)

        it('rien de changé', function()
            assert.same({ '', 0 }, { changes.fields(form, board(), board(), texts) })
        end)

        it('coupe à 160 octets sans briser un caractère', function()
            local long = { titleField = 'a', fields = {} }
            local before, after = {}, {}
            for i = 1, 30 do
                long.fields[i] = { id = 'f' .. i, widget = 'slider', min = 0, max = 10, step = 1,
                    label = 'Réglage éé numéro ' .. i, help = 'Aide.' }
                before['f' .. i], after['f' .. i] = 0, 1
            end
            local summary = changes.fields(long, before, after, texts)
            assert.equal('30 réglages changés', summary)
            local cut = changes.fit(string.rep('é', 100))
            assert.is_true(#cut <= 160)
            assert.is_not_nil(utf8.len(cut))
        end)

        it('le texte du module passe devant, borné', function()
            assert.equal('Texte repeint', changes.summary(form, board(), board({ texte = 'x' }), texts, 'Texte repeint'))
            assert.equal('Retouché : Ce qui est écrit', changes.summary(form, board(), board({ texte = 'x' }), texts, nil))
            assert.equal('Retouché : Ce qui est écrit', changes.summary(form, board(), board({ texte = 'x' }), texts, ''))
            assert.equal('Retouché : Ce qui est écrit', changes.summary(form, board(), board({ texte = 'x' }), texts, 42))
            assert.equal('Retouché : Ce qui est écrit',
                changes.summary(form, board(), board({ texte = 'x' }), texts, 'a\1b'))
            local long = changes.summary(form, board(), board({ texte = 'x' }), texts, string.rep('é', 200))
            assert.is_true(#long <= 160)
            assert.is_not_nil(utf8.len(long))
        end)
    end)

    describe('enfants d\'un lot', function()
        local point = { noun = 'point', nounPlural = 'points', feminine = false }
        local affiche = { noun = 'affiche', nounPlural = 'affiches', feminine = true }

        local function group(kind, added, removed, changed)
            return { noun = kind.noun, nounPlural = kind.nounPlural, feminine = kind.feminine,
                added = added, removed = removed, changed = changed }
        end

        it('accords en genre et en nombre', function()
            assert.equal('2 points ajoutés, 1 retiré', (changes.children({ group(point, 2, 1, 0) }, texts)))
            assert.equal('1 affiche ajoutée', (changes.children({ group(affiche, 1, 0, 0) }, texts)))
            assert.equal('2 affiches retirées', (changes.children({ group(affiche, 0, 2, 0) }, texts)))
            assert.equal('1 point changé', (changes.children({ group(point, 0, 0, 1) }, texts)))
            assert.equal('1 point ajouté, 3 affiches changées',
                (changes.children({ group(point, 1, 0, 0), group(affiche, 0, 0, 3) }, texts)))
            assert.same({ '', 0 }, { changes.children({ group(point, 0, 0, 0) }, texts) })
            assert.equal(3, select(2, changes.children({ group(point, 2, 1, 0) }, texts)))
        end)

        it('participes', function()
            assert.equal('ajouté', changes.agree('ajouté', false, false))
            assert.equal('ajoutée', changes.agree('ajouté', true, false))
            assert.equal('ajoutés', changes.agree('ajouté', false, true))
            assert.equal('ajoutées', changes.agree('ajouté', true, true))
            assert.equal('1 réglage changé', changes.settingsCount(1, texts))
            assert.equal('3 réglages changés', changes.settingsCount(3, texts))
        end)

        it('retrait', function()
            local panneau = { noun = 'panneau', article = 'le' }
            local removal, children = changes.removal(panneau, { { count = 2, noun = 'affiche', nounPlural = 'affiches' } }, texts)
            assert.equal('Retrait du panneau', removal)
            assert.equal('et de ses 2 affiches', children)
            local _, journal = changes.removal(panneau, { { count = 5, noun = 'point', nounPlural = 'points' } }, texts, true)
            assert.equal('et ses 5 points', journal)
            assert.equal('', select(2, changes.removal(panneau, {}, texts)))
        end)
    end)

    describe('numéros', function()
        it('publication, première version, retour en arrière', function()
            assert.equal('La version 3 sera archivée ; celle-ci deviendra la version 4.',
                changes.versionLine('publish', texts, 3, 4))
            assert.equal('Ce sera la version 1.', changes.versionLine('publish', texts, nil, 1))
            assert.equal('La version 2 sera rétablie et deviendra la version 5.', changes.versionLine('restore', texts, 2, 5))
        end)
    end)

    describe('lignes de brouillon', function()
        local zone = { noun = 'zone', article = 'la', newLabel = 'Nouvelle zone' }
        local panneau = { noun = 'panneau', article = 'le', newLabel = 'Nouveau panneau' }
        local affiche = { noun = 'affiche', article = 'l\'', newLabel = 'Nouvelle affiche', feminine = true }

        it('nouvelle fiche, essai, retrait, changements', function()
            assert.equal('Nouvelle zone, pas encore publiée', changes.draftLine(zone, { new = true }, drafts))
            assert.equal('Nouveau panneau, pas encore publié', changes.draftLine(panneau, { new = true }, drafts))
            assert.equal('Zone en essai, vous seul la voyez en jeu', changes.draftLine(zone, { trial = true }, drafts))
            assert.equal('Panneau en essai, vous seul le voyez en jeu', changes.draftLine(panneau, { trial = true }, drafts))
            assert.equal('Retrait de l\'affiche, pas encore publié', changes.draftLine(affiche, { removal = true }, drafts))
            assert.equal('Retrait du panneau, pas encore publié', changes.draftLine(panneau, { removal = true }, drafts))
            assert.equal('Retrait de la zone, pas encore publié', changes.draftLine(zone, { removal = true }, drafts))
            assert.equal('1 réglage changé, pas encore publié',
                changes.draftLine(panneau, { summary = '1 réglage changé', count = 1 }, drafts))
            assert.equal('2 points ajoutés, pas encore publiés',
                changes.draftLine(zone, { summary = '2 points ajoutés', count = 2 }, drafts))
            assert.equal('Rien de changé, pas encore publié', changes.draftLine(zone, {}, drafts))
        end)

        it('genre : feminine déclaré, sinon « la »', function()
            assert.is_true(changes.feminine(zone))
            assert.is_false(changes.feminine(panneau))
            assert.is_true(changes.feminine(affiche))
            assert.is_false(changes.feminine({ article = 'l\'' }))
        end)

        it('capitales et minuscules accentuées', function()
            assert.equal('Épée', changes.capital('épée'))
            assert.equal('éclat', changes.lowerFirst('Éclat'))
            assert.equal('', changes.capital(''))
        end)
    end)

    it('valeurs d\'un message d\'erreur (décimales du champ)', function()
        local taille = form.fields[6]
        assert.equal('taille', taille.id)
        assert.equal('3,0 m', changes.show(taille, 3))
        assert.equal('3 m', changes.brief(taille, 3))
        assert.equal('7 jours', changes.show(form.fields[9], 7 * DAY))
    end)
end)

-- T-102 : résumé d'un lieu changé (shared/changes.lua › place, combine). Règles documentées : spec T-102 § 3
-- (shared/changes.lua) et § 7.5 : déplacement dit à partir de 0,5 m, rotation à partir de 1°.
describe('vava_atelier changes : lieu (T-102)', function()
    local changes, place

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/changes.lua',
        })
        changes = VavaAtelier.changes
        place = VavaAtelier.config.texts.changes.place
    end)

    it('« déplacée de 12 m » (zone, féminin), « déplacé de 4 m » (point), 0,4 m : rien', function()
        assert.equal('déplacée de 12 m', changes.place({ x = 0, y = 0, z = 0, r = 120 }, { x = 12, y = 0, z = 5, r = 120 },
            true, place))
        assert.equal('déplacé de 4 m', changes.place({ x = 0, y = 0, z = 0, h = 0 }, { x = 0, y = 4, z = 0, h = 0 },
            false, place))
        assert.equal('', changes.place({ x = 0, y = 0, z = 0, h = 0 }, { x = 0.4, y = 0, z = 0, h = 0 }, false, place))
        assert.equal('déplacé de 1 m', changes.place({ x = 0, y = 0, z = 0 }, { x = 0.6, y = 0, z = 0 }, false, place))
    end)

    it('« tournée de 40° », au plus court ; moins de 1° : rien', function()
        assert.equal('tournée de 40°', changes.place({ x = 0, y = 0, z = 0, h = 350 }, { x = 0, y = 0, z = 0, h = 30 },
            true, place))
        assert.equal('', changes.place({ x = 0, y = 0, z = 0, h = 10 }, { x = 0, y = 0, z = 0, h = 10.5 }, true, place))
    end)

    it('« rayon de 120 m à 140 m » ; avec un déplacement', function()
        assert.equal('rayon de 120 m à 140 m', changes.place({ x = 0, y = 0, z = 0, r = 120 },
            { x = 0, y = 0, z = 0, r = 140 }, true, place))
        assert.equal('déplacée de 12 m, rayon de 120 m à 140 m', changes.place({ x = 0, y = 0, z = 0, r = 120 },
            { x = 0, y = 12, z = 0, r = 140 }, true, place))
    end)

    it('« tracé redessiné (6 sommets) » ; même tracé : rien', function()
        local before = { z = 0, points = { { x = 0, y = 0 }, { x = 10, y = 0 }, { x = 0, y = 10 } } }
        local after = { z = 0, points = {} }
        for i = 1, 6 do after.points[i] = { x = i, y = i * i } end
        assert.equal('tracé redessiné (6 sommets)', changes.place(before, after, false, place))
        assert.equal('', changes.place(before, before, false, place))
    end)

    it('« posée » (premier lieu) ; lieu absent : rien', function()
        assert.equal('posée', changes.place(nil, { x = 0, y = 0, z = 0, r = 60 }, true, place))
        assert.equal('posé', changes.place(nil, { x = 0, y = 0, z = 0 }, false, place))
        assert.equal('', changes.place({ x = 0, y = 0, z = 0 }, nil, false, place))
    end)

    it('avec les enfants : « déplacée de 12 m, 2 points ajoutés » ; réglages séparés par « ; »', function()
        assert.equal('déplacée de 12 m, 2 points ajoutés', changes.combine('', 'déplacée de 12 m', '2 points ajoutés'))
        assert.equal('Fatigue de 2 à 3 ; déplacée de 12 m', changes.combine('Fatigue de 2 à 3', 'déplacée de 12 m', ''))
        assert.equal('2 points ajoutés', changes.combine('', '', '2 points ajoutés'))
        assert.equal('', changes.combine('', '', ''))
    end)
end)
