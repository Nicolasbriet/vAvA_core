local helper = require('tests.helper')

-- Règles partagées de la magie (modules/vava_magic/shared/text.lua, progression.lua, geometry.lua). Valeurs
-- documentées : README du module (tableau « Configuration », « Sorts d'eau et de terre », « Verrouiller une cible »)
-- et docs/api.md (section vava_magic) :
--   5 niveaux par sort, seuils d'XP 0, 100, 300, 700, 1500 ; mana maximale 100 ;
--   zones protégées : cercles au sol { label, x, y, radius } ;
--   Vague : cône devant soi, portée de 4 à 10 m ; Rempart : ligne face au regard, deux pans en chevron au niveau 5 ;
--   longueur d'un texte comptée en signes (un « é » compte pour un).

local function load()
    helper.reset()
    helper.loadAll({
        'modules/vava_magic/shared/constants.lua',
        'modules/vava_magic/config.lua',
        'modules/vava_magic/shared/text.lua',
        'modules/vava_magic/shared/progression.lua',
        'modules/vava_magic/shared/geometry.lua',
    })
    return VavaMagic
end

describe('vava_magic text', function()
    local text, cfg

    before_each(function()
        local magic = load()
        text, cfg = magic.text, magic.config
    end)

    describe('clean', function()
        it('refuse ce qui n’est pas un texte', function()
            assert.is_nil(text.clean(nil))
            assert.is_nil(text.clean(12))
            assert.is_nil(text.clean({}))
            assert.is_nil(text.clean(true))
        end)

        it('refuse un texte UTF-8 invalide (octet isolé, forme trop longue, demi-paire)', function()
            assert.is_nil(text.clean('abc\255'))
            assert.is_nil(text.clean('\192\175'))            -- « / » encodé sur deux octets
            assert.is_nil(text.clean('\237\160\128'))        -- U+D800
            assert.is_nil(text.clean('\195'))                -- « é » coupé
        end)

        it('remplace les caractères de contrôle par des espaces, réduit et retire les espaces en trop', function()
            assert.equal('Bonjour à tous', text.clean('  Bonjour \t  à\ntous  '))
            assert.equal('a b c', text.clean('a\0b\127c'))
            assert.equal('ligne une ligne deux', text.clean('ligne une\r\nligne deux'))
        end)

        it('garde les lettres accentuées intactes (l’octet 0xA0 du « à » n’est pas une espace)', function()
            assert.equal('voilà déjà à', text.clean('voilà déjà à'))
            assert.equal('Œuvre ÿ ñ', text.clean('Œuvre ÿ ñ'))
        end)

        it('rend un texte vide pour des espaces seuls', function()
            assert.equal('', text.clean('    '))
            assert.equal('', text.clean(''))
        end)
    end)

    describe('length', function()
        it('compte les signes et non les octets', function()
            assert.equal(3, text.length('été'))
            assert.equal(5, #'été')
            assert.equal(1, text.length('🔥'))
            assert.equal(0, text.length(''))
        end)

        it('rend 0 pour un texte invalide', function()
            assert.equal(0, text.length('abc\255'))
        end)
    end)

    describe('truncate', function()
        it('garde les premiers signes sans jamais couper un caractère', function()
            assert.equal('Bon', text.truncate('Bonjour', 3))
            assert.equal('éè', text.truncate('éèàù', 2))
            assert.equal('🔥🔥', text.truncate('🔥🔥🔥', 2))
        end)

        it('rend le texte tel quel s’il est assez court', function()
            assert.equal('éèàù', text.truncate('éèàù', 4))
            assert.equal('abc', text.truncate('abc', 10))
            assert.equal('', text.truncate('', 3))
        end)

        it('rend un texte vide pour 0 signe', function()
            assert.equal('', text.truncate('Bonjour', 0))
        end)
    end)

    describe('words et join', function()
        it('découpe un texte nettoyé en mots et le recompose', function()
            local words = text.words(text.clean('  un  deux\ttrois '))
            assert.same({ 'un', 'deux', 'trois' }, words)
            assert.equal('un deux trois', text.join(words))
            assert.same({}, text.words(''))
            assert.equal('', text.join({}))
        end)

        it('garde un mot accentué entier', function()
            assert.same({ 'à', 'déjà', 'là' }, text.words('à déjà là'))
        end)
    end)

    describe('name', function()
        it('nettoie un nom de contact', function()
            assert.equal(24, cfg.sigils.nameMax)
            assert.equal('Aldric le Roux', text.name('  Aldric   le Roux ', cfg.sigils.nameMax))
        end)

        it('compte la limite en signes : 24 « é » passent, 25 non', function()
            assert.equal(string.rep('é', 24), text.name(string.rep('é', 24), 24))
            assert.is_nil(text.name(string.rep('é', 25), 24))
        end)

        it('refuse un nom vide, blanc, invalide ou qui n’est pas un texte', function()
            assert.is_nil(text.name('', 24))
            assert.is_nil(text.name('   ', 24))
            assert.is_nil(text.name('\255', 24))
            assert.is_nil(text.name(nil, 24))
            assert.is_nil(text.name(42, 24))
        end)
    end)

    it('Murmure : la borne réseau en octets laisse passer le plus long message de chaque niveau, même en signes de 4 octets', function()
        local murmure = cfg.spells.murmure
        for level, levelCfg in ipairs(murmure.levels) do
            local longest = string.rep('🔥', levelCfg.maxLength)
            assert.is_true(#longest <= murmure.textMaxBytes, 'niveau ' .. level)
            assert.equal(levelCfg.maxLength, text.length(text.truncate(longest .. 'x', levelCfg.maxLength)))
        end
    end)
end)

describe('vava_magic progression', function()
    local progression, cfg

    before_each(function()
        local magic = load()
        progression, cfg = magic.progression, magic.config
    end)

    it('compte 5 niveaux et 1 500 XP au dernier (docs/api.md : niveau 1 à 5)', function()
        assert.equal(5, progression.MAX_LEVEL)
        assert.equal(1500, progression.MAX_XP)
    end)

    it('donne 5 niveaux à chaque sort de la config', function()
        for name, spell in pairs(cfg.spells) do
            assert.equal(progression.MAX_LEVEL, #spell.levels, name)
        end
    end)

    it('place les seuils documentés : 0, 100, 300, 700, 1500', function()
        assert.same({ 0, 100, 300, 700, 1500 }, cfg.progression.thresholds)
        local cases = { { 0, 1 }, { 99, 1 }, { 100, 2 }, { 299, 2 }, { 300, 3 }, { 699, 3 }, { 700, 4 }, { 1499, 4 },
            { 1500, 5 }, { 99999, 5 } }
        for _, case in ipairs(cases) do
            assert.equal(case[2], progression.levelOf(case[1]), case[1] .. ' XP')
        end
        assert.equal(0, progression.threshold(1))
        assert.equal(100, progression.threshold(2))
        assert.equal(1500, progression.threshold(5))
        assert.is_nil(progression.threshold(6))
    end)

    it('donne le niveau 1 à une XP négative ou NaN, le niveau 5 à une XP infinie', function()
        assert.equal(1, progression.levelOf(-10))
        assert.equal(1, progression.levelOf(0 / 0))
        assert.equal(5, progression.levelOf(math.huge))
    end)

    it('réduit le coût en mana avec le niveau (× 1 ; 0,9 ; 0,8 ; 0,7 ; 0,6), arrondi à l’entier', function()
        assert.same({ 1.0, 0.9, 0.8, 0.7, 0.6 }, cfg.progression.costMultipliers)
        local fireball = cfg.spells.boule_de_feu                 -- coût de base 14
        local expected = { 14, 13, 11, 10, 8 }                   -- 14 ; 12,6 ; 11,2 ; 9,8 ; 8,4
        for level = 1, 5 do
            local cost = progression.cost(fireball, level)
            assert.equal(expected[level], cost, 'niveau ' .. level)
            assert.equal('integer', math.type(cost))
        end
    end)

    it('docs/tests/magie.md : grimoire « Mana : 14 » (Boule de feu N1), Nova N1 à 30, parchemin « Mana : 12 » (Murmure N1)', function()
        assert.equal(14, progression.cost(cfg.spells.boule_de_feu, 1))
        assert.equal(30, progression.cost(cfg.spells.nova_ardente, 1))
        assert.equal(12, progression.cost(cfg.spells.murmure, 1))
        -- « 100 → 70 → 40 → 10 ; la quatrième : mana trop faible »
        assert.equal(10, cfg.mana.max - 3 * progression.cost(cfg.spells.nova_ardente, 1))
    end)

    it('applique la part propre à une action (orbe ancré de la Lueur : × 1,5)', function()
        local lueur = cfg.spells.lueur
        assert.equal(1.5, lueur.anchor.costShare)
        assert.equal(8, progression.cost(lueur, 4, lueur.anchor.costShare))   -- 8 × 0,7 × 1,5 = 8,4
        assert.equal(7, progression.cost(lueur, 5, lueur.anchor.costShare))   -- 8 × 0,6 × 1,5 = 7,2
    end)

    it('aucun sort ne coûte plus que la mana maximale (100), ni davantage à un niveau plus haut', function()
        assert.equal(100, cfg.mana.max)
        for name, spell in pairs(cfg.spells) do
            local previous = math.huge
            for level = 1, progression.MAX_LEVEL do
                local cost = progression.cost(spell, level)
                assert.is_true(cost > 0 and cost <= cfg.mana.max, name .. ' niveau ' .. level)
                assert.is_true(cost <= previous, name .. ' niveau ' .. level)
                previous = cost
            end
        end
    end)

    describe('sigils mémorisables', function()
        it('donne la limite des non-mages (10) à qui n’est pas mage ou ne connaît pas le Murmure', function()
            assert.equal(10, cfg.sigils.nonMageLimit)
            assert.equal(10, progression.sigilLimit(false, nil))
            assert.equal(10, progression.sigilLimit(false, 1500))
            assert.equal(10, progression.sigilLimit(true, nil))
        end)

        it('suit le niveau du Murmure : 10, 15, 25, 40, 60', function()
            assert.equal('murmure', cfg.sigils.spell)
            assert.equal(10, progression.sigilLimit(true, 0))
            assert.equal(15, progression.sigilLimit(true, 100))
            assert.equal(25, progression.sigilLimit(true, 300))
            assert.equal(40, progression.sigilLimit(true, 700))
            assert.equal(60, progression.sigilLimit(true, 1500))
        end)

        it('retombe sur la limite des non-mages si le sort des sigils n’existe pas', function()
            cfg.sigils.spell = 'sort_absent'
            assert.equal(10, progression.sigilLimit(true, 1500))
        end)
    end)
end)

describe('vava_magic geometry', function()
    local geometry, cfg

    before_each(function()
        local magic = load()
        geometry, cfg = magic.geometry, magic.config
    end)

    local function p(x, y, z) return { x = x, y = y, z = z or 0 } end

    describe('distances et directions', function()
        it('mesure une distance en 3D et au sol', function()
            assert.equal(5, geometry.distance(p(0, 0, 0), p(3, 4, 0)))
            assert.equal(13, geometry.distance(p(0, 0, 0), p(3, 4, 12)))
            assert.equal(5, geometry.distance2d(p(0, 0, 0), p(3, 4, 12)))
        end)

        it('rend un vecteur unitaire', function()
            local v = geometry.normalize(3, 4, 0)
            assert.is_near(0.6, v.x, 1e-12)
            assert.is_near(0.8, v.y, 1e-12)
            assert.equal(0, v.z)
        end)

        it('rend nil pour un vecteur nul, minuscule ou non fini', function()
            assert.is_nil(geometry.normalize(0, 0, 0))
            assert.is_nil(geometry.normalize(1e-7, 0, 0))
            assert.is_nil(geometry.normalize(0 / 0, 1, 0))
            assert.is_nil(geometry.normalize(math.huge, 0, 0))
            assert.is_nil(geometry.normalize(-math.huge, 1, 1))
        end)

        it('rend la direction au sol, nil pour deux points confondus au sol', function()
            local d = geometry.direction2d(p(1, 1, 0), p(1, 6, 40))
            assert.is_near(0, d.x, 1e-12)
            assert.is_near(1, d.y, 1e-12)
            assert.is_nil(geometry.direction2d(p(1, 1, 0), p(1, 1, 40)))
        end)
    end)

    describe('angle', function()
        it('mesure l’écart entre une direction et un point (0, 90, 180 degrés)', function()
            local north = { x = 0, y = 1, z = 0 }
            assert.is_near(0, geometry.angle(north, p(0, 0), p(0, 10)), 1e-6)
            assert.is_near(90, geometry.angle(north, p(0, 0), p(10, 0)), 1e-9)
            assert.is_near(180, geometry.angle(north, p(0, 0), p(0, -10)), 1e-6)
        end)

        it('rend nil pour un point confondu avec l’origine', function()
            assert.is_nil(geometry.angle({ x = 0, y = 1, z = 0 }, p(2, 2, 2), p(2, 2, 2)))
        end)

        it('borne de l’axe d’un projectile (25°) : un impact à 24° passe, à 26° non', function()
            local limit = cfg.projectiles.angleDeg
            assert.equal(25, limit)
            local north = { x = 0, y = 1, z = 0 }
            local function at(deg)
                local r = math.rad(deg)
                return p(20 * math.sin(r), 20 * math.cos(r))
            end
            assert.is_true(geometry.angle(north, p(0, 0), at(24)) <= limit)
            assert.is_true(geometry.angle(north, p(0, 0), at(26)) > limit)
        end)
    end)

    describe('zones protégées', function()
        it('n’en trouve aucune avec la config livrée (liste vide)', function()
            assert.same({}, cfg.combat.protectedZones)
            assert.is_nil(geometry.protectedZone(p(0, 0, 0)))
        end)

        it('reconnaît un point dans le cercle au sol, bord compris, quelle que soit la hauteur', function()
            local chapel = { label = 'Chapelle de la Grâce', x = 0.0, y = 0.0, radius = 40.0 }
            table.insert(cfg.combat.protectedZones, chapel)
            assert.equal(chapel, geometry.protectedZone(p(40, 0, 0)))
            assert.equal(chapel, geometry.protectedZone(p(24, 31, 500)))      -- 2D : 39,2 m
            assert.is_nil(geometry.protectedZone(p(40.01, 0, 0)))
        end)

        it('rend la première zone qui contient le point', function()
            local first = { label = 'A', x = 0.0, y = 0.0, radius = 10.0 }
            local second = { label = 'B', x = 5.0, y = 0.0, radius = 10.0 }
            table.insert(cfg.combat.protectedZones, first)
            table.insert(cfg.combat.protectedZones, second)
            assert.equal(first, geometry.protectedZone(p(4, 0)))
            assert.equal(second, geometry.protectedZone(p(14, 0)))
        end)
    end)

    describe('segments au sol', function()
        it('mesure la distance d’un point au segment (projection, puis extrémités)', function()
            local a, b = p(0, 0), p(10, 0)
            assert.equal(3, geometry.segmentDistance2d(p(5, 3, 50), a, b))
            assert.equal(5, geometry.segmentDistance2d(p(13, 4), a, b))
            assert.equal(5, geometry.segmentDistance2d(p(-3, -4), a, b))
        end)

        it('traite un segment réduit à un point', function()
            assert.equal(5, geometry.segmentDistance2d(p(4, 5), p(1, 1), p(1, 1)))
        end)

        it('dit si deux segments se croisent', function()
            assert.is_true(geometry.segmentsCross2d(p(0, 0), p(10, 10), p(0, 10), p(10, 0)))
            assert.is_false(geometry.segmentsCross2d(p(0, 0), p(10, 0), p(0, 1), p(10, 1)))     -- parallèles
            assert.is_false(geometry.segmentsCross2d(p(0, 0), p(4, 4), p(0, 10), p(10, 0)))     -- trop court
        end)

        it('rend la position du croisement le long du premier segment', function()
            assert.is_near(0.4, geometry.crossing2d(p(0, 0), p(10, 0), p(4, -1), p(4, 1)), 1e-12)
            assert.is_near(1, geometry.crossing2d(p(0, 0), p(10, 0), p(10, -1), p(10, 1)), 1e-12)
            assert.is_nil(geometry.crossing2d(p(0, 0), p(10, 0), p(12, -1), p(12, 1)))
            assert.is_nil(geometry.crossing2d(p(0, 0), p(10, 0), p(0, 1), p(10, 1)))
        end)
    end)

    describe('cône de la Vague', function()
        local north = { x = 0, y = 1 }

        local function point(distance, deg)
            local r = math.rad(deg)
            return p(distance * math.sin(r), distance * math.cos(r))
        end

        it('README : portée de 4 m au niveau 1 à 10 m au niveau 5', function()
            local levels = cfg.spells.vague.levels
            assert.equal(4, levels[1].range)
            assert.equal(10, levels[5].range)
            assert.is_true(geometry.inCone2d(point(3.9, 0), p(0, 0), north, levels[1].range, levels[1].halfAngle))
            assert.is_false(geometry.inCone2d(point(4.1, 0), p(0, 0), north, levels[1].range, levels[1].halfAngle))
            assert.is_true(geometry.inCone2d(point(9.9, 0), p(0, 0), north, levels[5].range, levels[5].halfAngle))
            assert.is_false(geometry.inCone2d(point(10.1, 0), p(0, 0), north, levels[5].range, levels[5].halfAngle))
        end)

        it('suit l’ouverture du niveau (30° au niveau 1, 40° au niveau 5)', function()
            local levels = cfg.spells.vague.levels
            assert.is_false(geometry.inCone2d(point(3, 35), p(0, 0), north, levels[1].range, levels[1].halfAngle))
            assert.is_true(geometry.inCone2d(point(3, 35), p(0, 0), north, levels[5].range, levels[5].halfAngle))
            assert.is_true(geometry.inCone2d(point(3, -25), p(0, 0), north, levels[1].range, levels[1].halfAngle))
        end)

        it('ne touche pas derrière le lanceur, sauf tout contre la pointe', function()
            assert.is_false(geometry.inCone2d(p(0, -2), p(0, 0), north, 10, 40))
            assert.is_true(geometry.inCone2d(p(0, -0.3), p(0, 0), north, 10, 40))
        end)
    end)

    describe('cap de GTA', function()
        it('vaut 0 au nord, 90 à l’ouest, 180 au sud, 270 à l’est', function()
            assert.is_near(0, geometry.heading(0, 1), 1e-9)
            assert.is_near(90, geometry.heading(-1, 0), 1e-9)
            assert.is_near(180, geometry.heading(0, -1), 1e-9)
            assert.is_near(270, geometry.heading(1, 0), 1e-9)
            assert.is_near(315, geometry.heading(1, 1), 1e-9)
        end)

        it('reste entre 0 et 360', function()
            for deg = 0, 359, 7 do
                local r = math.rad(deg)
                local heading = geometry.heading(math.cos(r), math.sin(r))
                assert.is_true(heading >= 0 and heading < 360, tostring(deg))
            end
        end)
    end)

    describe('segments d’un mur (Rempart, Mur de flammes)', function()
        local function length(segment)
            return geometry.distance2d(segment.a, segment.b)
        end

        it('rend nil quand le lanceur et le point visé sont confondus au sol', function()
            assert.is_nil(geometry.wallSegments(p(5, 5, 0), p(5, 5, 3), 3))
        end)

        it('dresse un segment perpendiculaire au regard, centré sur le point visé, à sa hauteur', function()
            local segments = geometry.wallSegments(p(0, 0, 0), p(0, 10, 2), 3)
            assert.equal(1, #segments)
            local s = segments[1]
            assert.is_near(3, length(s), 1e-9)
            assert.is_near(0, (s.a.x + s.b.x) / 2, 1e-9)
            assert.is_near(10, (s.a.y + s.b.y) / 2, 1e-9)
            assert.is_near(0, s.b.y - s.a.y, 1e-9)                    -- perpendiculaire au regard (vers le nord)
            assert.equal(2, s.a.z)
            assert.equal(2, s.b.z)
        end)

        it('Rempart niveau 1 : un mur de trois mètres', function()
            local level = cfg.spells.rempart.levels[1]
            local segments = geometry.wallSegments(p(0, 0), p(0, 10), level.length, level.segments, cfg.spells.rempart.bendDeg)
            assert.equal(1, #segments)
            assert.is_near(3, length(segments[1]), 1e-9)
        end)

        it('Rempart niveau 5 : deux pans de quatre mètres en chevron, rabattus de 25° vers le lanceur', function()
            local spell = cfg.spells.rempart
            local level = spell.levels[5]
            assert.equal(2, level.segments)
            assert.equal(25, spell.bendDeg)
            local from, aimed = p(0, 0), p(0, 10)
            local segments = geometry.wallSegments(from, aimed, level.length, level.segments, spell.bendDeg)
            assert.equal(2, #segments)
            local back = 4 * math.sin(math.rad(25))
            local side = 4 * math.cos(math.rad(25))
            for _, s in ipairs(segments) do
                assert.is_near(4, length(s), 1e-9)
                assert.same(aimed, { x = s.a.x, y = s.a.y, z = s.a.z })       -- chaque bras part du point visé
                assert.is_near(10 - back, s.b.y, 1e-9)                         -- rabattu vers le lanceur
                assert.is_near(side, math.abs(s.b.x), 1e-9)
            end
            assert.is_near(0, segments[1].b.x + segments[2].b.x, 1e-9)        -- symétriques
        end)

        it('ne dresse qu’un segment par défaut, ou si on en demande moins de deux', function()
            assert.equal(1, #geometry.wallSegments(p(0, 0), p(0, 10), 3))
            assert.equal(1, #geometry.wallSegments(p(0, 0), p(0, 10), 3, 1, 25))
        end)
    end)
end)
