local helper = require('tests.helper')

-- Distances de la récolte (modules/vava_gathering/shared/geometry.lua). Valeur documentée : README du module, tableau
-- « Règles » : interaction à 2,5 m (+ 1,5 m de tolérance serveur), que server/harvest.lua vérifie par
-- geometry.within(…, interact.distance + interact.serverTolerance).

describe('vava_gathering geometry', function()
    local geometry, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/geometry.lua',
        })
        geometry = VavaGathering.geometry
        cfg = VavaGathering.config
    end)

    it('mesure une distance en 3D', function()
        assert.equal(5, geometry.distance(0, 0, 0, 3, 4, 0))
        assert.equal(3, geometry.distance(1, 1, 1, 2, 3, 3))
        assert.equal(13, geometry.distance(-320, -880, 31, -320, -892, 36))
    end)

    it('rend une distance nulle pour un même point et symétrique entre deux points', function()
        assert.equal(0, geometry.distance(-300, -900, 31, -300, -900, 31))
        assert.equal(geometry.distance(1, 2, 3, -4, 5, -6), geometry.distance(-4, 5, -6, 1, 2, 3))
    end)

    it('rend le carré de la distance sans racine', function()
        assert.equal(25, geometry.distanceSquared(0, 0, 0, 3, 4, 0))
        assert.equal(9, geometry.distanceSquared(1, 1, 1, 2, 3, 3))
        assert.equal(0, geometry.distanceSquared(5, 5, 5, 5, 5, 5))
    end)

    it('compte un point posé sur le bord comme à portée, pas un point au-delà', function()
        assert.is_true(geometry.within(3, 4, 0, 0, 0, 0, 5))
        assert.is_false(geometry.within(3, 4.01, 0, 0, 0, 0, 5))
        assert.is_true(geometry.within(0, 0, 0, 0, 0, 0, 0))
        assert.is_false(geometry.within(0.01, 0, 0, 0, 0, 0, 0))
    end)

    it('tient compte de la hauteur', function()
        assert.is_true(geometry.within(0, 0, 2.5, 0, 0, 0, 2.5))
        assert.is_false(geometry.within(0, 0, 3, 0, 0, 0, 2.5))
    end)

    it('README : récolte permise à 2,5 m du nœud, plus 1,5 m de tolérance côté serveur', function()
        assert.equal(2.5, cfg.interact.distance)
        assert.equal(1.5, cfg.interact.serverTolerance)
        local node = cfg.nodes[1]
        local reach = cfg.interact.distance + cfg.interact.serverTolerance
        assert.is_true(geometry.within(node.x + 2.5, node.y, node.z, node.x, node.y, node.z, cfg.interact.distance))
        assert.is_true(geometry.within(node.x + 4.0, node.y, node.z, node.x, node.y, node.z, reach))
        assert.is_false(geometry.within(node.x + 4.01, node.y, node.z, node.x, node.y, node.z, reach))
    end)

    it('chaque nœud de la config appartient à une zone déclarée et se trouve dans son cercle', function()
        local zones = {}
        for _, zone in ipairs(cfg.zones) do zones[zone.id] = zone end
        for _, node in ipairs(cfg.nodes) do
            local zone = zones[node.zone]
            assert.is_table(zone, node.id)
            assert.is_true(geometry.within(node.x, node.y, node.z, zone.x, zone.y, zone.z, zone.radius), node.id)
        end
    end)
end)
