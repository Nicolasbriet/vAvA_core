local helper = require('tests.helper')

-- Géométrie pure d'un coup (modules/vava_combat/shared/geometry.lua, T-112) avec la config livrée : avant d'un cap
-- (repère de GTA, cap 0 = nord, croissant vers l'ouest), cap d'un point vers un autre, angle à plat, cible dans l'arc
-- (portée, demi-angle, hauteur, contact), arc d'une technique avec une arme et les tolérances décidées (+ 0,25 m,
-- + 10°, hauteur + 0,4 m), ordre des candidats, bond plausible. Règles documentées : docs/plan/specs/T-112.md § 7.3 et
-- § 11.1 (valeurs recalculées avec les tolérances resserrées par le porteur du projet).

describe('vava_combat shared/geometry', function()
    local geometry, cfg

    local function p(x, y, z) return { x = x, y = y, z = z or 0 } end

    --- Point à `distance` mètres, à `angle` degrés de l'avant d'un attaquant au cap 0 (vers l'ouest pour un angle
    --- positif), hauteur `dz`.
    local function at(distance, angle, dz)
        local r = math.rad(angle)
        return p(-math.sin(r) * distance, math.cos(r) * distance, dz or 0)
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/geometry.lua',
        })
        geometry, cfg = VavaCombat.geometry, VavaCombat.config
    end)

    after_each(function() VavaCombat = nil end)

    describe('forward et headingTo', function()
        it('avant d\'un cap dans le repère de GTA', function()
            local f0, f90, f180 = geometry.forward(0), geometry.forward(90), geometry.forward(180)
            assert.near(0, f0.x, 1e-9)
            assert.near(1, f0.y, 1e-9)
            assert.near(-1, f90.x, 1e-9)
            assert.near(0, f90.y, 1e-9)
            assert.near(0, f180.x, 1e-9)
            assert.near(-1, f180.y, 1e-9)
            assert.is_nil(geometry.forward(0 / 0))
            assert.is_nil(geometry.forward(math.huge))
            assert.is_nil(geometry.forward('0'))
        end)

        it('cap d\'un point vers un autre ; nil au contact', function()
            assert.near(0, geometry.headingTo(p(0, 0), p(0, 1)), 1e-9)
            assert.near(90, geometry.headingTo(p(0, 0), p(-1, 0)), 1e-9)
            assert.near(270, geometry.headingTo(p(0, 0), p(1, 0)), 1e-9)
            assert.near(180, geometry.headingTo(p(0, 0), p(0, -1)), 1e-9)
            assert.is_nil(geometry.headingTo(p(0, 0), p(0, 0)))
            assert.is_nil(geometry.headingTo(p(0, 0), p(0 / 0, 1)))
            -- l'avant du cap rendu pointe bien vers la cible
            local h = geometry.headingTo(p(2, 3), p(-1, 7))
            assert.near(0, geometry.flatAngle(geometry.forward(h), p(2, 3), p(-1, 7)), 1e-6)
        end)
    end)

    describe('flat et flatAngle', function()
        it('distance au sol et écart de hauteur', function()
            local d, h = geometry.flat(p(0, 0, 1), p(3, 4, -1))
            assert.near(5, d, 1e-9)
            assert.near(2, h, 1e-9)
            assert.is_nil(geometry.flat(p(0, 0), { x = 1, y = 2 }))
        end)

        it('devant 0, de côté 90, derrière 180', function()
            local fwd = geometry.forward(0)
            assert.near(0, geometry.flatAngle(fwd, p(0, 0), p(0, 3)), 1e-9)
            assert.near(90, geometry.flatAngle(fwd, p(0, 0), p(-2, 0)), 1e-9)
            assert.near(90, geometry.flatAngle(fwd, p(0, 0), p(2, 0)), 1e-9)
            assert.near(180, geometry.flatAngle(fwd, p(0, 0), p(0, -1)), 1e-9)
            assert.equal(0, geometry.flatAngle(fwd, p(0, 0), p(0, 0, 3)))
        end)
    end)

    describe('arcOf', function()
        it('Taille descendante à l\'Épée courte : portée 2,45 m, demi-angle 45°, hauteur 2,0 m, contact 0,6 m', function()
            local arc = geometry.arcOf(cfg.techniques.taille_descendante, cfg.weapons.epee_courte, cfg)
            assert.near(2.45, arc.reach, 1e-9)
            assert.near(45, arc.halfAngle, 1e-9)
            assert.near(2.0, arc.maxHeight, 1e-9)
            assert.near(0.6, arc.closeRange, 1e-9)
        end)

        it('bonus de portée de l\'arme, plancher de 0,5 m, demi-angle plafonné à 180', function()
            local estoc = cfg.techniques.estoc_rapide
            assert.near(2.15, geometry.arcOf(estoc, cfg.weapons.dague, cfg).reach, 1e-9)        -- 2,4 − 0,5 + 0,25
            assert.near(3.25, geometry.arcOf(estoc, cfg.weapons.baton_ferre, cfg).reach, 1e-9)  -- 2,4 + 0,6 + 0,25
            local short = { hit = { range = 1.0, angle = 70 } }
            assert.equal(0.5, geometry.arcOf(short, { reachBonus = -1 }, cfg).reach)            -- 0,25 → 0,5
            assert.near(100, geometry.arcOf({ hit = { range = 2, angle = 180 } }, { reachBonus = 0 }, cfg).halfAngle, 1e-9)
            assert.equal(180, geometry.arcOf({ hit = { range = 2, angle = 360 } }, { reachBonus = 0 }, cfg).halfAngle)
        end)
    end)

    describe('inArc', function()
        local arc
        before_each(function()
            arc = geometry.arcOf(cfg.techniques.taille_descendante, cfg.weapons.epee_courte, cfg)
        end)

        local function judge(target, heading)
            return geometry.inArc(p(0, 0, 0), heading or 0, target, arc)
        end

        it('à portée devant : touché, avec distance et angle', function()
            local ok, distance, angle = judge(p(0, 2.44))
            assert.is_true(ok)
            assert.near(2.44, distance, 1e-9)
            assert.near(0, angle, 1e-9)
        end)

        it('hors de portée d\'un centimètre : range', function()
            assert.same({ false, 'range' }, { judge(p(0, 2.46)) })
            assert.same({ false, 'range' }, { judge(p(0, 3.5)) })
        end)

        it('angle : à 44,9° oui, à 45,1° non, de chaque côté', function()
            assert.is_true((judge(at(2, 44.9))))
            assert.is_true((judge(at(2, -44.9))))
            assert.same({ false, 'angle' }, { judge(at(2, 45.1)) })
            assert.same({ false, 'angle' }, { judge(at(2, -45.1)) })
        end)

        it('derrière à 1 m : angle ; à 0,5 m derrière : contact, touché', function()
            assert.same({ false, 'angle' }, { judge(p(0, -1)) })
            local ok, distance, angle = judge(p(0, -0.5))
            assert.is_true(ok)
            assert.near(0.5, distance, 1e-9)
            assert.equal(0, angle)
        end)

        it('hauteur : 2,01 m au-dessus refusé, 2,0 m en dessous admis', function()
            assert.same({ false, 'height' }, { judge(p(0, 1, 2.01)) })
            assert.is_true((judge(p(0, 1, -2.0))))
        end)

        it('le cap compte : la même cible de côté est devant quand on se tourne', function()
            assert.same({ false, 'angle' }, { judge(p(-2, 0), 0) })
            assert.is_true((judge(p(-2, 0), 90)))
        end)

        it('coordonnées ou cap illisibles : faux, jamais une erreur', function()
            assert.is_false((judge(p(0 / 0, 1))))
            assert.is_false((judge(p(0, 1), 0 / 0)))
            assert.is_false((geometry.inArc(p(0, 0), 0, p(0, 1), nil)))
            assert.is_false((geometry.inArc(nil, 0, p(0, 1), arc)))
        end)
    end)

    describe('order', function()
        it('cible verrouillée d\'abord même plus excentrée, puis angle, distance, numéro', function()
            local list = {
                { player = 7, distance = 2.0, angle = 10 },
                { player = 3, distance = 1.0, angle = 30 },
                { player = 5, distance = 1.5, angle = 10 },
                { player = 4, distance = 1.5, angle = 10 },
                { player = 9, distance = 1.0, angle = 5 },
            }
            local function players(sorted)
                local out = {}
                for i, entry in ipairs(sorted) do out[i] = entry.player end
                return out
            end
            assert.same({ 9, 4, 5, 7, 3 }, players(geometry.order(list)))
            assert.same({ 3, 9, 4, 5, 7 }, players(geometry.order(list, 3)))
            assert.equal(7, list[1].player)   -- la liste reçue n'est pas réordonnée
        end)
    end)

    describe('plausibleMove', function()
        it('8 m/s plus 0,5 m depuis la demande', function()
            local lunge = cfg.lunge
            assert.is_true(geometry.plausibleMove(p(0, 0), 1320, 1000, p(0, 3.0), lunge))
            assert.is_false(geometry.plausibleMove(p(0, 0), 1320, 1000, p(0, 3.1), lunge))
            assert.is_true(geometry.plausibleMove(p(0, 0), 1000, 1000, p(0.5, 0), lunge))
            assert.is_false(geometry.plausibleMove(p(0, 0), 1000, 1000, p(0.51, 0), lunge))
            -- seul le déplacement au sol compte
            assert.is_true(geometry.plausibleMove(p(0, 0, 0), 1000, 1000, p(0, 0, 5), lunge))
            assert.is_false(geometry.plausibleMove(p(0, 0), 0 / 0, 1000, p(0, 0), lunge))
        end)
    end)
end)
