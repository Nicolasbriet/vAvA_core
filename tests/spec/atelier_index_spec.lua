local helper = require('tests.helper')

-- Têtes des fiches gardées (modules/vava_atelier/server/index.lua, T-101) : brouillons tenus par compte, comptés à
-- chaque changement de tête au lieu d'un parcours de toutes les fiches à chaque écriture (relecture réseau R-13), et
-- places réservées le temps d'une écriture (deux écritures parallèles d'un même compte ne dépassent jamais le plafond,
-- relecture sécurité S-3).
describe('vava_atelier têtes en mémoire', function()
    local index
    local ME, OTHER = 7, 9

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/fingerprint.lua',
        })
        VavaAtelier.core = {}
        VavaAtelier.log = { warn = function() end }
        helper.load('modules/vava_atelier/server/index.lua')
        index = VavaAtelier.index
    end)

    after_each(function()
        VavaAtelier = nil
    end)

    local function draftRow(id, defId, holder, status)
        return { id = id, kind = 'panneau', def_id = defId, status = status or 'draft', rev = 1, removal = 0,
            author_account_id = holder, author_label = 'Membre', title = defId }
    end

    it('reconstruction : brouillons comptés par tenant, publiées non comptées', function()
        index.build('a:x', {
            draftRow(1, 'p1', ME), draftRow(2, 'p2', ME, 'trial'), draftRow(3, 'p3', OTHER),
            { id = 4, kind = 'panneau', def_id = 'p4', status = 'published', version = 1, title = 'p4' },
        }, {}, {})
        assert.equal(2, index.draftCount(ME))
        assert.equal(1, index.draftCount(OTHER))
        assert.equal(0, index.draftCount(42))
        -- reconstruite de nouveau : jamais comptés deux fois
        index.build('a:x', { draftRow(1, 'p1', ME) }, {}, {})
        assert.equal(1, index.draftCount(ME))
        assert.equal(0, index.draftCount(OTHER))
    end)

    it('changements d\'une tête : nouveau brouillon, reprise par un autre, publication, abandon', function()
        index.build('a:x', {}, {}, {})
        local head = index.ensure('a:x', 'panneau', 'neuf')
        head.draft = { row = 10, rev = 1, status = 'draft', holder = ME }
        index.touch('a:x', head)
        assert.equal(1, index.draftCount(ME))
        head.draft.holder = OTHER
        index.touch('a:x', head)
        assert.equal(0, index.draftCount(ME))
        assert.equal(1, index.draftCount(OTHER))
        head.published, head.draft = { row = 10, version = 1 }, nil
        index.touch('a:x', head)
        assert.equal(0, index.draftCount(OTHER))
        head.draft = { row = 11, rev = 1, status = 'draft', holder = ME }
        index.touch('a:x', head)
        head.published, head.draft = nil, nil
        index.touch('a:x', head)
        assert.equal(0, index.draftCount(ME))
        assert.is_nil(index.get('a:x', 'panneau', 'neuf'))
    end)

    it('tête d\'avant une reconstruction : ni comptée, ni retirée de la liste', function()
        index.build('a:x', { draftRow(1, 'p1', ME) }, {}, {})
        local old = index.get('a:x', 'panneau', 'p1')
        index.build('a:x', { draftRow(1, 'p1', ME) }, {}, {})
        old.draft = nil
        index.touch('a:x', old)
        assert.equal(1, index.draftCount(ME))
        assert.is_not_nil(index.get('a:x', 'panneau', 'p1'))
    end)

    it('atelier retiré : ses brouillons ne comptent plus', function()
        index.build('a:x', { draftRow(1, 'p1', ME) }, {}, {})
        index.build('b:y', { draftRow(2, 'q1', ME) }, {}, {})
        assert.equal(2, index.draftCount(ME))
        index.drop('a:x')
        assert.equal(1, index.draftCount(ME))
    end)

    it('places réservées : jamais au-delà du plafond, rendues après l\'écriture', function()
        index.build('a:x', { draftRow(1, 'p1', ME) }, {}, {})
        assert.is_true(index.reserveDraft(ME, 3))
        assert.is_true(index.reserveDraft(ME, 3))
        -- 1 tenu + 2 réservés : la troisième écriture parallèle est refusée
        assert.is_false(index.reserveDraft(ME, 3))
        index.releaseDraft(ME)
        assert.is_true(index.reserveDraft(ME, 3))
        index.releaseDraft(ME)
        index.releaseDraft(ME)
        index.releaseDraft(ME)
        assert.is_true(index.reserveDraft(ME, 2))
        assert.is_false(index.reserveDraft(nil, 3))
    end)
end)
