local helper = require('tests.helper')

-- Garde de la signature et de la solidité (modules/vava_crafting/server/guard.lua), abonnée au hook `before` de
-- `vava_inventory:metadata`. Règles documentées : README du module (« Signature protégée ») et docs/api.md, section
-- vava_crafting :
--   créateur, nom du créateur, date, poinçon et qualité ne changent jamais hors de l'artisanat (objet ordinaire compris :
--   pas de signature contrefaite) ; sur un objet signé, le palier et le nom non plus, la solidité (courante et
--   maximale) ne remonte ni ne disparaît, `broken` ne tombe pas ; l'artisanat lui-même écrit ce qu'il veut.

describe('vava_crafting guard', function()
    local guard

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_crafting/shared/constants.lua',
            'modules/vava_crafting/config.lua',
            'modules/vava_crafting/server/guard.lua',
        })
        guard = VavaCrafting.guard
    end)

    -- hache signée telle que la crée signature.build
    local function signed()
        return {
            quality = 47, tier = 3, durability = 80, max_durability = 100,
            crafter_id = 12, crafter_name = 'Aldric Ferrand', crafted_at = 1793000000, mark = '⚒',
            history = { { at = 1793000000, kind = 'creation', by = 'Aldric Ferrand' } },
        }
    end

    local function with(base, changes, removed)
        local copy = {}
        for key, value in pairs(base) do copy[key] = value end
        for key, value in pairs(changes or {}) do copy[key] = value end
        for _, key in ipairs(removed or {}) do copy[key] = nil end
        return copy
    end

    local function refused(before, after, reason, key, ceiling)
        local ok, gotReason, gotKey = guard.decide(before, after, false, ceiling)
        assert.is_false(ok)
        assert.equal(reason, gotReason)
        assert.equal(key, gotKey)
    end

    describe('clés de la signature', function()
        it('refuse de changer chacune des clés protégées d’un objet signé', function()
            local before = signed()
            refused(before, with(before, { crafter_id = 13 }), 'signature_locked', 'crafter_id')
            refused(before, with(before, { crafter_name = 'Un Autre' }), 'signature_locked', 'crafter_name')
            refused(before, with(before, { crafted_at = 1 }), 'signature_locked', 'crafted_at')
            refused(before, with(before, { mark = '✶' }), 'signature_locked', 'mark')
            refused(before, with(before, { quality = 100 }), 'signature_locked', 'quality')
            refused(before, with(before, { tier = 5 }), 'signature_locked', 'tier')
        end)

        it('refuse de retirer une clé protégée (patch avec retrait, ou set qui remplace tout)', function()
            local before = signed()
            refused(before, with(before, nil, { 'crafter_name' }), 'signature_locked', 'crafter_name')
            refused(before, with(before, nil, { 'mark' }), 'signature_locked', 'mark')
            refused(before, {}, 'signature_locked', 'crafter_id')
            refused(before, { registre = 4 }, 'signature_locked', 'crafter_id')
        end)

        it('refuse d’ajouter un poinçon à un objet signé qui n’en avait pas', function()
            local before = with(signed(), nil, { 'mark' })
            refused(before, with(before, { mark = '⚒' }), 'signature_locked', 'mark')
        end)

        it('refuse de nommer, renommer ou débaptiser un objet signé (le baptême seul le nomme)', function()
            local before = signed()
            refused(before, with(before, { name = 'Brisecroc' }), 'signature_locked', 'name')
            local named = with(before, { name = 'Brisecroc' })
            refused(named, with(named, { name = 'Autre' }), 'signature_locked', 'name')
            refused(named, with(named, nil, { 'name' }), 'signature_locked', 'name')
            assert.is_true(guard.decide(named, with(named, { durability = 10 }), false))
        end)

        it('refuse une valeur de même contenu mais d’un autre type', function()
            local before = signed()
            refused(before, with(before, { crafter_id = '12' }), 'signature_locked', 'crafter_id')
            refused(before, with(before, { crafter_name = { 'Aldric Ferrand' } }), 'signature_locked', 'crafter_name')
        end)

        it('admet un entier réécrit à l’identique, même en flottant', function()
            local before = signed()
            assert.is_true(guard.decide(before, with(before, { crafter_id = 12.0, quality = 47.0 }), false))
        end)

        it('admet ce qui ne touche pas la signature : histoire, lignes, usure', function()
            local before = signed()
            local history = { before.history[1], { at = 1793000100, kind = 'note', by = 'Graveur' } }
            assert.is_true(guard.decide(before, with(before, { history = history }), false))
            assert.is_true(guard.decide(before, with(before, { lines = { { label = 'Gravure', value = 'Au roi' } } }), false))
            assert.is_true(guard.decide(before, before, false))
        end)
    end)

    describe('solidité d’un objet signé', function()
        it('refuse d’augmenter la solidité maximale', function()
            local before = signed()
            refused(before, with(before, { max_durability = 101 }), 'durability_locked', 'max_durability')
            refused(before, with(before, { max_durability = 9999, durability = 9999 }), 'durability_locked', 'max_durability')
        end)

        it('refuse de retirer la solidité maximale ou de la remplacer par autre chose qu’un nombre', function()
            local before = signed()
            refused(before, with(before, nil, { 'max_durability' }), 'durability_locked', 'max_durability')
            refused(before, with(before, { max_durability = '50' }), 'durability_locked', 'max_durability')
            refused(before, with(before, { max_durability = true }), 'durability_locked', 'max_durability')
        end)

        it('admet une baisse de la solidité maximale (dommage, usure : aucun gain)', function()
            local before = signed()
            assert.is_true(guard.decide(before, with(before, { max_durability = 99 }), false))
            assert.is_true(guard.decide(before, with(before, { max_durability = 1, durability = 1 }), false))
        end)

        it('refuse de rendre de la solidité courante (réparation hors station)', function()
            local before = signed()
            refused(before, with(before, { durability = 81 }), 'durability_locked', 'durability')
            refused(before, with(before, nil, { 'durability' }), 'durability_locked', 'durability')
        end)

        it('admet l’usure de la récolte : solidité qui baisse, maximale réécrite à l’identique, brisé à 0', function()
            local before = signed()
            assert.is_true(guard.decide(before, with(before, { durability = 78, max_durability = 100 }), false))
            assert.is_true(guard.decide(before, with(before, { durability = 0, max_durability = 100, broken = true }), false))
        end)

        it('admet la solidité donnée à un objet signé qui n’en avait pas, jusqu’au plafond (usure de la récolte)', function()
            local before = with(signed(), nil, { 'durability', 'max_durability' })
            -- harvest.lua : maximale = toolDefaults.durability (100), courante = maximale − usure
            assert.is_true(guard.decide(before, with(before, { durability = 98, max_durability = 100 }), false, 100))
            assert.is_true(guard.decide(before, with(before, { durability = 0, max_durability = 100, broken = true }), false, 100))
            assert.is_true(guard.decide(before, with(before, { durability = 150 }), false, 150))
            assert.is_true(guard.decide(before, with(before, { history = {} }), false, 100))
        end)

        it('refuse une solidité qui naît au-delà du plafond, négative ou non numérique', function()
            local before = with(signed(), nil, { 'durability', 'max_durability' })
            refused(before, with(before, { max_durability = 1e9, durability = 1e9 }), 'durability_locked', 'max_durability', 100)
            refused(before, with(before, { max_durability = 101 }), 'durability_locked', 'max_durability', 100)
            refused(before, with(before, { durability = 101 }), 'durability_locked', 'durability', 100)
            refused(before, with(before, { max_durability = -1 }), 'durability_locked', 'max_durability', 100)
            refused(before, with(before, { max_durability = '50' }), 'durability_locked', 'max_durability', 100)
        end)

        it('refuse une solidité courante qui naît au-dessus de la maximale de l’objet', function()
            local before = with(signed(), nil, { 'durability' })
            assert.is_true(guard.decide(before, with(before, { durability = 97 }), false, 150))
            refused(before, with(before, { durability = 120 }), 'durability_locked', 'durability', 150)
            local bare = with(signed(), nil, { 'durability', 'max_durability' })
            refused(bare, with(bare, { durability = 90, max_durability = 80 }), 'durability_locked', 'durability', 100)
        end)

        it('refuse toute solidité qui naît quand aucun plafond n’est connu', function()
            local before = with(signed(), nil, { 'durability', 'max_durability' })
            refused(before, with(before, { max_durability = 1 }), 'durability_locked', 'max_durability')
            refused(before, with(before, { durability = 1 }), 'durability_locked', 'durability')
        end)

        it('plafond : solidité de la recette si elle dépasse celle de la récolte', function()
            assert.equal(100, guard.bornCeiling(80, 100))
            assert.equal(150, guard.bornCeiling(150, 100))
            assert.equal(100, guard.bornCeiling(nil, 100))
            assert.equal(0, guard.bornCeiling(nil, nil))
            assert.equal(100, VavaCrafting.config.guard.bornDurability)
        end)

        it('refuse de retirer `broken` d’un objet brisé', function()
            local before = with(signed(), { durability = 0, broken = true })
            refused(before, with(before, nil, { 'broken' }), 'durability_locked', 'broken')
            refused(before, with(before, { broken = false }), 'durability_locked', 'broken')
            assert.is_true(guard.decide(before, with(before, { history = {} }), false))
        end)
    end)

    describe('écriture de l’artisanat lui-même', function()
        it('admet la réparation : solidité rendue, maximale réduite, `broken` retiré', function()
            local before = with(signed(), { durability = 0, broken = true })
            local after = with(before, { durability = 95, max_durability = 95 }, { 'broken' })
            assert.is_true(guard.decide(before, after, true))
        end)

        it('admet toute écriture interne, même sur la signature', function()
            local before = signed()
            assert.is_true(guard.decide(before, with(before, { name = 'Brisecroc' }), true))
            assert.is_true(guard.decide(before, {}, true))
        end)

        it('ne reconnaît l’écriture interne qu’à la valeur vraie', function()
            local before = signed()
            local after = with(before, { crafter_id = 13 })
            for _, flag in ipairs({ 'true', 1, {}, nil }) do
                assert.is_false((guard.decide(before, after, flag)))
            end
        end)
    end)

    describe('objet ordinaire', function()
        it('admet les écritures d’un objet sans signature (seau, registre, outil du catalogue, matière)', function()
            assert.is_true(guard.decide({ water = 3 }, { water = 2 }, false))
            assert.is_true(guard.decide({}, { registre = 7 }, false))
            assert.is_true(guard.decide({}, { durability = 98, max_durability = 100 }, false))
            assert.is_true(guard.decide({ durability = 2, max_durability = 100 }, { durability = 100, max_durability = 200 }, false))
            assert.is_true(guard.decide({ durability = 0, max_durability = 100, broken = true }, { durability = 100, max_durability = 100 }, false))
        end)

        it('laisse libre le palier d’une matière', function()
            assert.is_true(guard.decide({ tier = 2, origin = 'foret' }, { tier = 3, origin = 'foret' }, false))
            assert.is_true(guard.decide({ tier = 2 }, {}, false))
            assert.is_true(guard.decide({}, { name = 'Lettre au bailli' }, false))
        end)

        it('refuse une signature contrefaite : créateur, date, poinçon ou qualité posés sur un objet ordinaire', function()
            refused({}, { crafter_id = 12 }, 'signature_locked', 'crafter_id')
            refused({ tier = 2 }, { tier = 2, crafter_name = 'Aldric Ferrand' }, 'signature_locked', 'crafter_name')
            refused({}, { crafted_at = 1 }, 'signature_locked', 'crafted_at')
            refused({}, { mark = '⚒' }, 'signature_locked', 'mark')
            refused({ tier = 3 }, { tier = 3, quality = 90 }, 'signature_locked', 'quality')
        end)

        it('tient des métadonnées absentes ou d’un autre type pour un objet vide, sans erreur', function()
            assert.is_true(guard.decide(nil, nil, false))
            assert.is_true(guard.decide('x', { water = 1 }, false))
            refused(nil, { crafter_id = 1 }, 'signature_locked', 'crafter_id')
            refused(signed(), 42, 'signature_locked', 'crafter_id')
        end)
    end)

    describe('abonné au hook', function()
        local logged, written

        before_each(function()
            logged, written = {}, {}
            VavaCrafting.log = { warn = function(...) logged[#logged + 1] = { ... } end }
            VavaCrafting.journal = { write = function(kind, entry) written[#written + 1] = { kind = kind, entry = entry } end }
            VavaCrafting.catalog = { recipeFor = function() return nil end }
        end)

        local function payload(before, after, owner)
            return { container = 5, instanceId = 901, item = 'hache_fer', owner = owner, reason = 'patch', before = before, after = after }
        end

        it('laisse passer une écriture admise sans rien journaliser (aucune valeur rendue)', function()
            local before = signed()
            assert.is_nil(guard.onMetadata(payload(before, with(before, { durability = 70 }), 'vava_gathering'), false))
            assert.equal(0, #written)
            assert.equal(0, #logged)
        end)

        it('refuse et journalise une signature réécrite par un autre module', function()
            local before = signed()
            local ok, reason = guard.onMetadata(payload(before, with(before, { crafter_name = 'X' }), 'vava_graveur'), false)
            assert.is_false(ok)
            assert.equal('signature_locked', reason)
            assert.equal(1, #written)
            assert.equal('signature_locked', written[1].kind)
            assert.equal(12, written[1].entry.characterId)
            assert.equal('hache_fer', written[1].entry.item)
            assert.equal(47, written[1].entry.quality)
            assert.equal('vava_graveur', written[1].entry.details.module)
            assert.equal('crafter_name', written[1].entry.details.key)
            assert.equal(901, written[1].entry.details.instance)
            assert.equal(1, #logged)
        end)

        it('ne journalise jamais une qualité ou un créateur hors des bornes de la table', function()
            local ok = guard.onMetadata(payload({ quality = 900, crafter_id = -3 }, { quality = 1 }, 'x'), false)
            assert.is_false(ok)
            assert.is_nil(written[1].entry.quality)
            assert.is_nil(written[1].entry.characterId)
            assert.is_false((guard.onMetadata(payload({ quality = 2.5, crafter_id = 1 << 40 }, {}, 'y'), false)))
            assert.is_nil(written[2].entry.quality)
            assert.is_nil(written[2].entry.characterId)
        end)

        it('ignore un payload qui n’est pas une table', function()
            assert.is_nil(guard.onMetadata(nil, false))
            assert.is_nil(guard.onMetadata('x', false))
        end)

        it('ne journalise et ne signale qu’une fois le même refus dans la fenêtre, mais refuse toujours', function()
            local before = signed()
            local forged = payload(before, with(before, { crafter_name = 'X' }), 'vava_graveur')
            for _ = 1, 50 do
                local ok, reason = guard.onMetadata(forged, false)
                assert.is_false(ok)
                assert.equal('signature_locked', reason)
            end
            assert.equal(1, #written)
            assert.equal(1, #logged)
            -- autre clé, autre objet, autre module : refus distincts, journalisés chacun une fois
            guard.onMetadata(payload(before, with(before, { mark = '✶' }), 'vava_graveur'), false)
            local other = payload(before, with(before, { crafter_name = 'X' }), 'vava_graveur')
            other.instanceId = 902
            guard.onMetadata(other, false)
            guard.onMetadata(payload(before, with(before, { crafter_name = 'X' }), 'vava_autre'), false)
            assert.equal(4, #written)
        end)

        it('borne la solidité qui naît par la recette de l’objet ou par la récolte (catalogue)', function()
            local asked
            VavaCrafting.catalog = { recipeFor = function(item) asked = item return { durability = 80 } end }
            local before = with(signed(), nil, { 'durability', 'max_durability' })
            -- usure de la récolte : maximale 100 (toolDefaults), au-dessus des 80 de la recette
            assert.is_nil(guard.onMetadata(payload(before, with(before, { durability = 98, max_durability = 100 }), 'vava_gathering'), false))
            assert.equal('hache_fer', asked)
            local ok, reason = guard.onMetadata(payload(before, with(before, { durability = 1e9, max_durability = 1e9 }), 'vava_x'), false)
            assert.is_false(ok)
            assert.equal('durability_locked', reason)
            assert.equal('max_durability', written[1].entry.details.key)
            VavaCrafting.catalog = { recipeFor = function() return { durability = 300 } end }
            assert.is_nil(guard.onMetadata(payload(before, with(before, { max_durability = 300 }), 'vava_x'), false))
            VavaCrafting.catalog = { recipeFor = function() return nil end }
            assert.is_false((guard.onMetadata(payload(before, with(before, { max_durability = 101 }), 'vava_x'), false)))
        end)

        it('ne consulte pas le catalogue quand la solidité est déjà connue', function()
            VavaCrafting.catalog = { recipeFor = function() error('catalogue consulté') end }
            local before = signed()
            assert.is_nil(guard.onMetadata(payload(before, with(before, { durability = 10 }), 'vava_gathering'), false))
        end)
    end)

    describe('limite du journal des refus', function()
        local WINDOW, MAX = 60000, 3

        it('signale le premier refus, tait les suivants pendant la fenêtre, puis les annonce', function()
            local state = guard.newRecords()
            assert.same({ true, 0 }, { guard.shouldRecord(state, 'a', 1000, WINDOW, MAX) })
            assert.same({ false, 0 }, { guard.shouldRecord(state, 'a', 2000, WINDOW, MAX) })
            assert.same({ false, 0 }, { guard.shouldRecord(state, 'a', 60999, WINDOW, MAX) })
            assert.same({ true, 2 }, { guard.shouldRecord(state, 'a', 61000, WINDOW, MAX) })
            assert.same({ false, 0 }, { guard.shouldRecord(state, 'a', 61001, WINDOW, MAX) })
        end)

        it('suit chaque refus à part', function()
            local state = guard.newRecords()
            assert.is_true((guard.shouldRecord(state, 'a', 0, WINDOW, MAX)))
            assert.is_true((guard.shouldRecord(state, 'b', 0, WINDOW, MAX)))
            assert.is_false((guard.shouldRecord(state, 'a', 10, WINDOW, MAX)))
        end)

        it('au-delà du nombre suivi, tait les refus nouveaux puis reprend après la purge', function()
            local state = guard.newRecords()
            for _, id in ipairs({ 'a', 'b', 'c' }) do assert.is_true((guard.shouldRecord(state, id, 0, WINDOW, MAX))) end
            assert.same({ false, 0 }, { guard.shouldRecord(state, 'd', 10, WINDOW, MAX) })
            assert.same({ false, 0 }, { guard.shouldRecord(state, 'e', 20, WINDOW, MAX) })
            assert.equal(3, state.count)
            -- fenêtre passée : les trois expirés sont purgés, la place revient, les deux refus tus sont annoncés
            assert.same({ true, 2 }, { guard.shouldRecord(state, 'd', WINDOW + 30, WINDOW, MAX) })
            assert.equal(1, state.count)
            assert.is_nil(state.entries.a)
        end)

        it('purge au plus une fois par fenêtre et garde les entrées encore valides', function()
            local state = guard.newRecords()
            guard.shouldRecord(state, 'a', 0, WINDOW, MAX)
            guard.shouldRecord(state, 'b', 30000, WINDOW, MAX)
            guard.shouldRecord(state, 'c', WINDOW, WINDOW, MAX)   -- purge : a expiré, b encore valide
            assert.is_nil(state.entries.a)
            assert.is_not_nil(state.entries.b)
            assert.equal(2, state.count)
            assert.equal(2 * WINDOW, state.purgeAt)
        end)

        it('règles par défaut : fenêtre de 60 s, 500 refus suivis', function()
            assert.equal(60000, VavaCrafting.config.guard.windowMs)
            assert.equal(500, VavaCrafting.config.guard.maxTracked)
        end)
    end)
end)
