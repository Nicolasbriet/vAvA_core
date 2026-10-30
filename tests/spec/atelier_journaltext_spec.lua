local helper = require('tests.helper')

-- Journal de l'Atelier (T-100) : phrase d'une ligne, âge, résumé borné, ligne pour l'interface.
describe('vava_atelier journaltext', function()
    local jt, verbs

    local NOW = 1761800000
    local MIN, HOUR, DAY = 60, 3600, 86400

    local function fixedDate(fmt, at)
        assert.equal('%d/%m', fmt)
        return 'jj/mm@' .. at
    end

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/journaltext.lua',
        })
        jt = VavaAtelier.journaltext
        verbs = VavaAtelier.config.texts.verbs
    end)

    it('a un verbe pour chaque action du journal', function()
        for _, action in ipairs(VavaAtelier.ACTIONS) do
            assert.is_string(verbs[action], action)
            local mirror = VavaAtelier.config.texts.mirror[action]
            assert.is_string(mirror, action)
            assert.is_true(#mirror <= 32, mirror)
        end
    end)

    it('compose la phrase de chaque action avec les trois articles', function()
        assert.equal('A publié la station', jt.lead(verbs.published, 'la', 'station'))
        assert.equal('A créé l\'enclume', jt.lead(verbs.created, 'l\'', 'enclume'))
        assert.equal('A annoté le panneau', jt.lead(verbs.note, 'le', 'panneau'))
        assert.equal('A enregistré le brouillon du panneau', jt.lead(verbs.saved, 'le', 'panneau'))
        assert.equal('A enregistré le brouillon de la zone', jt.lead(verbs.saved, 'la', 'zone'))
        assert.equal('A enregistré le brouillon de l\'affiche', jt.lead(verbs.saved, 'l\'', 'affiche'))
        assert.equal('A mis à l\'essai le sort', jt.lead(verbs.trial, 'le', 'sort'))
        for _, action in ipairs(VavaAtelier.ACTIONS) do
            local lead = jt.lead(verbs[action], 'la', 'zone')
            assert.equal('A ', lead:sub(1, 2), action)
            assert.equal(' zone', lead:sub(-5), action)
        end
    end)

    it('se contente du verbe sans type connu', function()
        assert.equal('A publié', jt.lead(verbs.published, nil, nil))
        assert.equal('A publié', jt.lead(verbs.published, 'la', ''))
        assert.equal('', jt.lead(nil, 'la', 'zone'))
    end)

    it('dit l\'âge d\'une ligne aux bornes', function()
        local function age(seconds) return jt.age(NOW, NOW - seconds, fixedDate) end
        assert.equal('à l\'instant', age(0))
        assert.equal('à l\'instant', age(59))
        assert.equal('il y a 1 min', age(60))
        assert.equal('il y a 59 min', age(59 * MIN))
        assert.equal('il y a 1 h', age(60 * MIN))
        assert.equal('il y a 23 h', age(23 * HOUR + 59 * MIN))
        assert.equal('hier', age(24 * HOUR))
        assert.equal('hier', age(47 * HOUR))
        assert.equal('il y a 2 jours', age(48 * HOUR))
        assert.equal('il y a 6 jours', age(7 * DAY - 1))
        assert.equal('le jj/mm@' .. (NOW - 7 * DAY), age(7 * DAY))
        -- horloge en avance sur la base : jamais un âge négatif
        assert.equal('à l\'instant', age(-30))
    end)

    it('coupe le résumé à 160 octets sans briser un caractère', function()
        local long = string.rep('é', 100)
        local cut = jt.summary(long)
        assert.equal(160, #cut)
        assert.equal(string.rep('é', 80), cut)
        local odd = 'a' .. string.rep('é', 100)
        assert.equal(159, #jt.summary(odd))
        assert.is_true(utf8.len(jt.summary(odd)) ~= nil)
        assert.is_nil(jt.summary(nil))
        assert.is_nil(jt.summary(''))
        assert.equal('de 4 m', jt.summary('de 4 m'))
    end)

    it('compose une ligne pour l\'interface', function()
        local row = { id = 42, editor = 'vava_example_atelier:panneaux', kind = 'panneau', action = 'note',
            title = 'Panneau de la place', summary = 'Lettres repeintes', actor_label = 'Souverain Aldric Morn', at = NOW - 30 }
        assert.same({
            id = 42, lead = 'A annoté le panneau', title = 'Panneau de la place', summary = 'Lettres repeintes',
            actor = 'Souverain Aldric Morn', when = 'à l\'instant', editor = 'vava_example_atelier:panneaux',
        }, jt.line(row, verbs, { article = 'le', noun = 'panneau' }, NOW, fixedDate))
        row.summary = nil
        local line = jt.line(row, verbs, nil, NOW, fixedDate)
        assert.equal('A annoté', line.lead)
        assert.is_nil(line.summary)
    end)
end)
