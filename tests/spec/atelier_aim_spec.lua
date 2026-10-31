local helper = require('tests.helper')

-- Visée de l'outil de placement (T-102, modules/vava_atelier/shared/aim.lua), sur la seule vue client (constantes et
-- config_client.lua). Règles documentées : spec T-102 § 8.1 et § 8.2, README de vava_atelier :
--   molette : ±15° (±1° avec Maj), cap dans [0, 360) ; rayon ±5 m (±0,5 m avec Maj), arrondi au pas, borné par les
--   règles du type ; candidat selon la forme ; pile d'annulation de 20 gestes (le plus ancien sort) : création →
--   abandon du brouillon, déplacement → lieu d'avant, sommet non envoyé → retiré sans RPC ; clic droit : l'élément le
--   plus proche à 2,5 m au plus ; 12 étiquettes les plus proches ; barre des touches de chaque mode.
describe('vava_atelier aim', function()
    local aim, placement

    before_each(function()
        helper.reset()
        VavaAtelier = helper.loadClientView('modules/vava_atelier', 'VavaAtelier')
        helper.load('modules/vava_atelier/shared/aim.lua')
        aim = VavaAtelier.aim
        placement = VavaAtelier.config.placement
    end)

    after_each(function()
        VavaAtelier = nil
    end)

    describe('molette', function()
        it('cap : 350° + 15° → 5°, 0° − 1° → 359° (pas fin), 345 + 15 → 0', function()
            assert.equal(5.0, aim.turn(350, 1, false, placement.steps))
            assert.equal(359.0, aim.turn(0, -1, true, placement.steps))
            assert.equal(0.0, aim.turn(345, 1, false, placement.steps))
            assert.equal(41.0, aim.turn(40, 1, true, placement.steps))
        end)

        it('rayon : ±5 m, ±0,5 m avec Maj, arrondi au pas et borné', function()
            local bounds = { min = 10, max = 300 }
            local r = 60
            for _ = 1, 4 do r = aim.resize(r, 1, false, placement.steps, bounds) end
            assert.equal(80, r)
            for _ = 1, 3 do r = aim.resize(r, 1, true, placement.steps, bounds) end
            assert.equal(81.5, r)
            assert.equal(85, aim.resize(81.5, 1, false, placement.steps, bounds))
            assert.equal(10, aim.resize(12, -1, false, placement.steps, bounds))
            assert.equal(300, aim.resize(299.5, 1, false, placement.steps, bounds))
        end)
    end)

    describe('candidat', function()
        local hit = { x = 1, y = 2, z = 3 }

        it('selon la forme', function()
            assert.same({ x = 1, y = 2, z = 3 }, aim.candidate('point', hit, {}))
            assert.same({ x = 1, y = 2, z = 3, h = 40 }, aim.candidate('oriented', hit, { heading = 40 }))
            assert.same({ x = 1, y = 2, z = 3, r = 60 }, aim.candidate('circle', hit, { radius = 60 }))
            local poly = aim.candidate('polygon', hit, { vertices = { { x = 0, y = 0, z = 9 }, { x = 5, y = 0, z = 9 } } })
            assert.same({ z = 9, points = { { x = 0, y = 0 }, { x = 5, y = 0 }, { x = 1, y = 2 } } }, poly)
        end)

        it('sans sol visé : rien, sauf un tracé déjà commencé', function()
            assert.is_nil(aim.candidate('point', nil, {}))
            assert.is_nil(aim.candidate('polygon', nil, { vertices = {} }))
            assert.same({ z = 4, points = { { x = 0, y = 0 } } }, aim.candidate('polygon', nil, { vertices = { { x = 0, y = 0, z = 4 } } }))
        end)

        it('a bougé : 5 cm au sol, cap, rayon, sommets', function()
            local a = { x = 0, y = 0, z = 0, h = 0 }
            assert.is_false(aim.moved(a, { x = 0.04, y = 0, z = 0, h = 0 }))
            assert.is_true(aim.moved(a, { x = 0.06, y = 0, z = 0, h = 0 }))
            assert.is_true(aim.moved(a, { x = 0, y = 0, z = 0, h = 1 }))
            assert.is_true(aim.moved(nil, a))
            assert.is_true(aim.moved({ points = { { x = 0, y = 0 } } }, { points = { { x = 0, y = 0 }, { x = 1, y = 1 } } }))
        end)

        it('direction de la caméra : vers le nord à l\'horizontale, vers le bas', function()
            local dx, dy, dz = aim.direction(0, 0)
            assert.is_true(math.abs(dx) < 1e-9 and math.abs(dy - 1) < 1e-9 and math.abs(dz) < 1e-9)
            local _, _, down = aim.direction(-90, 0)
            assert.is_true(math.abs(down + 1) < 1e-9)
        end)
    end)

    describe('annulation', function()
        it('20 gestes au plus : le plus ancien sort', function()
            local stack = aim.stack(placement.undoMax)
            for i = 1, 21 do aim.push(stack, { kind = 'create', entryKind = 'node', id = 'n' .. i }) end
            assert.equal(20, #stack.items)
            assert.equal('n2', stack.items[1].id)
            assert.equal('n21', aim.pop(stack).id)
        end)

        it('création → abandon, déplacement → lieu d\'avant, sommet → retiré sans RPC', function()
            assert.same({ action = 'discard', entryKind = 'node', id = 'chene_5' },
                aim.undoPlan({ kind = 'create', entryKind = 'node', id = 'chene_5' }))
            local before = { x = 1, y = 2, z = 3, h = 0 }
            assert.same({ action = 'place', entryKind = 'node', id = 'chene_3', place = before },
                aim.undoPlan({ kind = 'move', entryKind = 'node', id = 'chene_3', before = before }))
            assert.same({ action = 'vertex' }, aim.undoPlan({ kind = 'vertex' }))
            assert.is_nil(aim.undoPlan({ kind = 'move', id = 'x' }))
            assert.is_nil(aim.pop(aim.stack(3)))
        end)

        it('gestes d\'une fiche oubliés', function()
            local stack = aim.stack(5)
            aim.push(stack, { kind = 'create', id = 'a' })
            aim.push(stack, { kind = 'move', id = 'b', before = {} })
            aim.push(stack, { kind = 'move', id = 'a', before = {} })
            aim.forget(stack, 'a')
            assert.equal(1, #stack.items)
            assert.equal('b', stack.items[1].id)
        end)
    end)

    describe('éléments proches', function()
        local items = {
            { id = 'a', x = 1, y = 0, z = 0 }, { id = 'b', x = 2.4, y = 0, z = 0 }, { id = 'c', x = 3, y = 0, z = 0 },
        }

        it('clic droit : le plus proche à 2,5 m au plus, rien au-delà', function()
            assert.equal('a', aim.pick(items, 0, 0, placement.pickRadius).id)
            assert.equal('b', aim.pick(items, 2.3, 0, placement.pickRadius).id)
            assert.is_nil(aim.pick(items, -2.6, 0, placement.pickRadius))
        end)

        it('les 12 plus proches à moins de 40 m, du plus proche au plus lointain', function()
            local many = {}
            for i = 1, 20 do many[i] = { id = 'n' .. i, x = i * 3, y = 0, z = 0 } end
            local near = aim.nearest(many, 0, 0, 0, placement.labels.max, placement.labels.distance)
            assert.equal(12, #near)
            assert.equal('n1', near[1].id)
            assert.equal('n12', near[12].id)
            assert.equal(2, #aim.nearest(many, 0, 0, 0, 12, 7))
        end)
    end)

    describe('barre des touches', function()
        it('par mode et par forme', function()
            local keybar = placement.keybar
            assert.equal(keybar.children, aim.keys('children', 'oriented', false, keybar))
            assert.equal(keybar.picked, aim.keys('children', 'oriented', true, keybar))
            assert.equal(keybar.circle, aim.keys('self', 'circle', false, keybar))
            assert.equal(keybar.polygon, aim.keys('self', 'polygon', false, keybar))
            assert.equal(keybar.oriented, aim.keys('self', 'oriented', false, keybar))
            assert.equal(keybar.point, aim.keys('self', 'point', false, keybar))
            assert.equal('Poser ici', keybar.children[1].label)
            assert.equal('Lâcher le point', keybar.picked[4].label)
            assert.equal('Fermer le tracé', keybar.polygon[2].label)
        end)
    end)
end)
