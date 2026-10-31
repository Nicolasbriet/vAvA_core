local helper = require('tests.helper')

-- Identifiant d'une fiche créée dans l'Atelier (T-101, shared/slug.lua), tiré de son nom à la première sauvegarde.
describe('vava_atelier slug', function()
    local slug
    local PATTERN = '^[%w_%-]+$'

    before_each(function()
        helper.reset()
        VavaAtelier = nil
        helper.loadAll({
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/shared/slug.lua',
        })
        slug = VavaAtelier.slug
    end)

    local function free() return false end

    local function takenSet(list)
        local set = {}
        for _, id in ipairs(list) do set[id] = true end
        return function(id) return set[id] == true end
    end

    it('nom normalisé', function()
        assert.equal('foret_de_brume', slug.pick('Forêt de Brume', 'zone', free))
        assert.equal('l_ancre_rouge', slug.pick('L\'Ancre-Rouge', 'station', free))
        assert.equal('eclat', slug.pick('ÉCLAT', 'sort', free))
        assert.equal('coeur_de_chene', slug.pick('Cœur de chêne', 'zone', free))
        assert.equal('a_b', slug.pick('  a   --  b  ', 'zone', free))
        assert.equal('panneau_2', slug.pick('Panneau 2', 'panneau', free))
        assert.equal('l_ancre_rouge', slug.pick('L’Ancre — Rouge', 'station', free))
    end)

    it('vide → nom du type', function()
        assert.equal('panneau', slug.pick('---', 'panneau', free))
        assert.equal('affiche', slug.pick('', 'Affiche', free))
        assert.equal('fiche', slug.pick('', '***', free))
    end)

    it('60 caractères → 40 octets, sans trait bas final', function()
        local id = slug.pick(string.rep('abcde ', 10), 'zone', free)
        assert.is_true(#id <= 40, id)
        assert.is_nil(id:find('_$'))
        assert.equal(40, #slug.base(string.rep('x', 60)))
    end)

    it('collisions : _2, _3, au-delà de _99 refus', function()
        assert.equal('foret_2', slug.pick('Forêt', 'zone', takenSet({ 'foret' })))
        assert.equal('foret_3', slug.pick('Forêt', 'zone', takenSet({ 'foret', 'foret_2' })))
        local all = { 'foret' }
        for n = 2, 99 do all[#all + 1] = 'foret_' .. n end
        local id, err = slug.pick('Forêt', 'zone', takenSet(all))
        assert.is_nil(id)
        assert.equal('full', err)
    end)

    it('identifiant retiré compté comme pris (l\'appelant le dit pris)', function()
        -- `taken` couvre la base entière, tous statuts : une fiche retirée garde son identifiant
        local retired = takenSet({ 'lanterne_du_port' })
        assert.equal('lanterne_du_port_2', slug.pick('Lanterne du port', 'panneau', retired))
    end)

    it('résultat toujours au motif des identifiants', function()
        local samples = { 'Forêt de Brume', 'ÉCLAT', '日本語', '<b>x</b>', 'a\0b', string.rep('é', 80), 'Ï í Ý', '' }
        for _, name in ipairs(samples) do
            local id = slug.pick(name, 'panneau', free)
            assert.truthy(id:find(PATTERN), name)
            assert.is_true(#id <= 48, name)
        end
        assert.equal('i_i_y', slug.pick('Ï í Ý', 'zone', free))
    end)
end)
