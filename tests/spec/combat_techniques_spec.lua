local helper = require('tests.helper')

-- Techniques (modules/vava_combat/shared/techniques.lua et weapons.checkTechniques, checkEngine, outcome, noticeOf,
-- reasonText de shared/weapons.lua, T-112) avec la config livrée : contrôle du format de COMBAT_V1.md § 3 (bornes des
-- curseurs de la maquette Combat), cycle d'un coup, admission par le serveur (délai, enchaînement, nombre de coups),
-- choix d'une technique par le client, style d'une arme, issue d'un coup. Règles documentées :
-- docs/plan/specs/T-112.md § 5.1, § 7.2, § 7.6 et § 11.1.

describe('vava_combat techniques', function()
    local techniques, weapons, cfg

    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}
        for key, item in pairs(value) do out[key] = copy(item) end
        return out
    end

    local function variant(change)
        local c = copy(cfg)
        change(c)
        return c
    end

    local function refused(change, pattern)
        local ok, err = weapons.checkTechniques(variant(change))
        assert.is_false(ok)
        assert.is_string(err)
        if pattern then assert.matches(pattern, err) end
    end

    local function refusedEngine(change, pattern)
        local ok, err = weapons.checkEngine(variant(change))
        assert.is_false(ok)
        if pattern then assert.matches(pattern, err) end
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/weapons.lua',
            'modules/vava_combat/shared/techniques.lua',
        })
        techniques, weapons, cfg = VavaCombat.techniques, VavaCombat.weapons, VavaCombat.config
    end)

    after_each(function() VavaCombat = nil end)

    describe('checkTechniques', function()
        it('accepte la config livrée, sans avertissement', function()
            assert.same({ true, {} }, { weapons.checkTechniques(cfg) })
            assert.is_true(weapons.checkEngine(cfg))
        end)

        it('refuse un identifiant, un libellé, un style ou un type invalides', function()
            refused(function(c) c.techniques.Taille = copy(c.techniques.revers) end, 'identifiant')
            refused(function(c) c.techniques[string.rep('a', 33)] = copy(c.techniques.revers) end, 'identifiant')
            refused(function(c) c.techniques.revers.label = '' end, 'label')
            refused(function(c) c.techniques.revers.label = string.rep('a', 49) end, 'label')
            refused(function(c) c.techniques.revers.style = 'hache_une_main' end, 'style inconnu')
            refused(function(c) c.techniques.revers.type = 'charge' end, 'type inconnu')
        end)

        it('refuse un geste mal formé', function()
            refused(function(c) c.techniques.revers.gesture.clip = nil end, 'dict et clip')
            refused(function(c) c.techniques.revers.gesture.flag = 1.5 end, 'flag')
            refused(function(c) c.techniques.revers.gesture.flag = 65536 end, 'flag')
            refused(function(c) c.techniques.revers.gesture.speed = 2 end, "clé inconnue 'speed'")
            refused(function(c) c.techniques.revers.gesture = 'melee' end, 'geste')
        end)

        it('borne les phases : préparation 80 à 1 500, frappe 40 à 500, récupération 0 à 2 000, 3 000 en tout', function()
            refused(function(c) c.techniques.revers.phases.windup = 79 end, 'windup')
            refused(function(c) c.techniques.revers.phases.windup = 320.5 end, 'windup')
            refused(function(c) c.techniques.revers.phases.active = 501 end, 'active')
            refused(function(c) c.techniques.revers.phases.recovery = -1 end, 'recovery')
            refused(function(c) c.techniques.revers.phases = { windup = 1500, active = 500, recovery = 1001 } end, '3 000')
            assert.is_true((weapons.checkTechniques(variant(function(c)
                c.techniques.revers.phases = { windup = 1500, active = 500, recovery = 1000 }
            end))))
        end)

        it('borne la portée, l\'angle, les dégâts et l\'endurance (curseurs de la maquette)', function()
            refused(function(c) c.techniques.revers.hit.range = 0.9 end, 'hit.range')
            refused(function(c) c.techniques.revers.hit.range = 4.1 end, 'hit.range')
            refused(function(c) c.techniques.revers.hit.angle = 9 end, 'hit.angle')
            refused(function(c) c.techniques.revers.hit.angle = 181 end, 'hit.angle')
            refused(function(c) c.techniques.revers.hit.angle = 0 / 0 end, 'hit.angle')
            refused(function(c) c.techniques.revers.damage = 0.4 end, 'damage')
            refused(function(c) c.techniques.revers.damage = 2.1 end, 'damage')
            refused(function(c) c.techniques.revers.stamina = 41 end, 'stamina')
            refused(function(c) c.techniques.revers.parryable = 'oui' end, 'parryable')
            refused(function(c) c.techniques.revers.staggers = nil end, 'staggers')
        end)

        it('refuse une chaîne vers soi, un autre style, une inconnue, un doublon, plus de 4', function()
            refused(function(c) c.techniques.revers.chain = { 'revers' } end, 'elle%-même')
            refused(function(c)
                c.styles.hache_une_main = { label = 'Hache', keys = { legere = 'coup_de_hache' } }
                c.techniques.coup_de_hache = copy(c.techniques.revers)
                c.techniques.coup_de_hache.style = 'hache_une_main'
                c.techniques.coup_de_hache.chain = {}
                c.techniques.revers.chain = { 'coup_de_hache' }
            end, 'autre style')
            refused(function(c) c.techniques.revers.chain = { 'moulinet' } end, 'inconnue')
            refused(function(c) c.techniques.revers.chain = { 'fendant', 'fendant' } end, 'deux fois')
            refused(function(c)
                c.techniques.revers.chain = { 'fendant', 'estoc_rapide', 'taille_descendante', 'fendant', 'estoc_rapide' }
            end, 'chain')
            refused(function(c) c.techniques.revers.chain = { first = 'fendant' } end, 'chain')
        end)

        it('refuse un learn mal formé et toute clé en trop', function()
            refused(function(c) c.techniques.revers.learn.level = 101 end, 'learn')
            refused(function(c) c.techniques.revers.learn.skill = 'Armes' end, 'learn')
            refused(function(c) c.techniques.revers.learn.xp = 5 end, 'learn')
            refused(function(c) c.techniques.revers.cooldown = 500 end, "clé inconnue 'cooldown'")
            assert.is_true((weapons.checkTechniques(variant(function(c) c.techniques.revers.learn = nil end))))
        end)

        it('refuse un style dont une touche n\'ouvre pas une technique de son type et de ce style', function()
            refused(function(c) c.styles.epee_une_main.keys.legere = 'fendant' end, 'touche legere')
            refused(function(c) c.styles.epee_une_main.keys.lourde = 'moulinet' end, 'touche lourde')
            refused(function(c) c.styles.epee_une_main.keys.parade = 'revers' end, 'touche inconnue')
            refused(function(c) c.styles.epee_une_main.label = nil end, 'label')
        end)

        it('technique que rien n\'ouvre ni n\'atteint : avertissement seulement', function()
            local ok, warnings = weapons.checkTechniques(variant(function(c)
                c.techniques.estoc_rapide.chain = { 'fendant' }   -- plus rien n'atteint le Revers
                c.techniques.taille_descendante.chain = { 'estoc_rapide' }
            end))
            assert.is_true(ok)
            assert.equal(1, #warnings)
            assert.matches("'revers'", warnings[1])
        end)
    end)

    describe('checkEngine', function()
        it('borne les tolérances (portée ≤ 1 m, angle ≤ 30°, hauteur ≤ 1 m) et les réglages du cycle', function()
            refusedEngine(function(c) c.tolerance.range = 1.01 end, 'tolerance')
            refusedEngine(function(c) c.tolerance.angle = 31 end, 'tolerance')
            refusedEngine(function(c) c.tolerance.height = 1.5 end, 'tolerance')
            refusedEngine(function(c) c.timing.samples = 3 end, 'timing')
            refusedEngine(function(c) c.timing.earlyMs = 600 end, 'timing')
            refusedEngine(function(c) c.geometry.maxTargets = 0 end, 'geometry')
            refusedEngine(function(c) c.lunge.maxSpeed = 0 end, 'lunge')
            refusedEngine(function(c) c.reactions.radius = 500 end, 'reactions')
            refusedEngine(function(c) c.rateLimits.use.capacity = 0 end, 'rateLimits')
            refusedEngine(function(c) c.draw.drawMs = 0.5 end, 'draw')
            refusedEngine(function(c) c.draw.sheatheGesture.clip = '' end, 'draw')
            refusedEngine(function(c) c.stagger.gesture = nil end, 'stagger')
            refusedEngine(function(c) c.debug.logSamples = 'oui' end, 'debug')
        end)

        it('les tolérances livrées sont celles décidées par le porteur du projet (+ 0,25 m, + 10°)', function()
            assert.equal(0.25, cfg.tolerance.range)
            assert.equal(10, cfg.tolerance.angle)
            assert.equal(800, cfg.draw.drawMs)
            assert.equal(1500, cfg.draw.sheatheMs)
        end)
    end)

    describe('styleOf', function()
        it('famille et catégorie de l\'arme', function()
            assert.equal('epee_une_main', techniques.styleOf(cfg.weaponClasses.epee_courte))
            assert.equal('epee_deux_mains', techniques.styleOf(cfg.weaponClasses.epee_longue))
            assert.is_nil(cfg.styles[techniques.styleOf(cfg.weaponClasses.epee_longue)])
            assert.equal('dague_dague', techniques.styleOf(cfg.weaponClasses.dague))
            assert.is_nil(techniques.styleOf(nil))
            assert.is_nil(techniques.styleOf({ family = 'epee' }))
        end)
    end)

    describe('plan', function()
        it('Taille descendante à t = 1 000 : ouverture 1 320, fin de frappe 1 480, fin 1 900', function()
            assert.same({ startedAt = 1000, openAt = 1320, closeAt = 1480, endAt = 1900 },
                techniques.plan(cfg.techniques.taille_descendante, 1000))
        end)
    end)

    describe('admit', function()
        local rules
        before_each(function() rules = { earlyMs = 60, chainMax = 3, styles = cfg.styles } end)

        --- Coup admis à `now`, tel que le serveur le garde.
        local function swing(id, now, prev)
            local def = cfg.techniques[id]
            local ok, chainCount = techniques.admit(prev, def, id, now, rules)
            assert.is_true(ok, id .. ' à ' .. now .. ' : ' .. tostring(chainCount))
            local plan = techniques.plan(def, now)
            plan.def, plan.chainCount = def, chainCount
            return plan
        end

        local function admit(id, now, prev)
            return { techniques.admit(prev, cfg.techniques[id], id, now, rules) }
        end

        it('libre : seule la technique qui ouvre sa touche', function()
            assert.same({ true, 0 }, admit('taille_descendante', 0))
            assert.same({ true, 0 }, admit('fendant', 0))
            assert.same({ false, 'not_opener' }, admit('estoc_rapide', 0))
            assert.same({ false, 'not_opener' }, admit('revers', 0))
        end)

        it('enchaînement pendant la récupération seulement, à earlyMs près', function()
            local taille = swing('taille_descendante', 0)
            assert.same({ false, 'busy', 1 }, admit('estoc_rapide', 419, taille))
            assert.same({ true, 1 }, admit('estoc_rapide', 420, taille))
            assert.same({ true, 1 }, admit('fendant', 450, taille))
            -- le Revers n'est pas dans la chaîne de la Taille : attendre la fin du coup
            assert.same({ false, 'busy', 340 }, admit('revers', 500, taille))
            -- pendant la préparation : même la technique qui ouvre est refusée
            assert.same({ false, 'busy', 640 }, admit('taille_descendante', 200, taille))
        end)

        it('quatre coups enchaînés au plus, puis la récupération', function()
            local a = swing('taille_descendante', 0)
            local b = swing('estoc_rapide', 420, a)
            assert.equal(1, b.chainCount)
            local c = swing('revers', b.closeAt - 60, b)
            assert.equal(2, c.chainCount)
            local d = swing('taille_descendante', c.closeAt - 60, c)
            assert.equal(3, d.chainCount)
            local at = d.closeAt
            assert.same({ false, 'chain_limit', d.endAt - 60 - at }, admit('estoc_rapide', at, d))
            -- la récupération passée, l'Estoc n'ouvre pas : not_opener ; la Taille repart
            assert.same({ false, 'not_opener' }, admit('estoc_rapide', d.endAt - 60, d))
            assert.same({ true, 0 }, admit('taille_descendante', d.endAt - 60, d))
        end)

        it('le Fendant n\'enchaîne sur rien', function()
            local fendant = swing('fendant', 0)
            assert.same({ false, 'busy', 1490 }, admit('taille_descendante', 0, fendant))
            assert.same({ true, 0 }, admit('taille_descendante', 1490, fendant))
        end)
    end)

    describe('pick', function()
        local style
        before_each(function() style = cfg.styles.epee_une_main end)

        local function current(id, now)
            local plan = techniques.plan(cfg.techniques[id], now)
            return plan, cfg.techniques[id]
        end

        it('libre : la technique qui ouvre la touche', function()
            assert.equal('taille_descendante', (techniques.pick(style, 'legere', nil, nil, 0, cfg.techniques)))
            assert.equal('fendant', (techniques.pick(style, 'lourde', nil, nil, 0, cfg.techniques)))
            local prev, def = current('taille_descendante', 0)
            assert.equal('taille_descendante', (techniques.pick(style, 'legere', prev, def, 900, cfg.techniques)))
        end)

        it('pendant la récupération : la suite de la chaîne du type de la touche', function()
            local prev, def = current('taille_descendante', 0)
            assert.equal('estoc_rapide', (techniques.pick(style, 'legere', prev, def, 480, cfg.techniques)))
            assert.equal('fendant', (techniques.pick(style, 'lourde', prev, def, 600, cfg.techniques)))
        end)

        it('pendant la frappe : rien, et l\'attente jusqu\'à la fin de la frappe', function()
            local prev, def = current('taille_descendante', 0)
            assert.same({ nil, 80 }, { techniques.pick(style, 'legere', prev, def, 400, cfg.techniques) })
        end)

        it('Fendant en cours : chaîne vide, attente jusqu\'à la fin du coup', function()
            local prev, def = current('fendant', 0)
            assert.same({ nil, 1050 }, { techniques.pick(style, 'legere', prev, def, 500, cfg.techniques) })
        end)

        it('aucun style : rien', function()
            assert.same({ nil, nil }, { techniques.pick(nil, 'legere', nil, nil, 0, cfg.techniques) })
        end)
    end)

    describe('issue d\'un coup', function()
        it('outcome : à terre, esquive, parade, blocage, bouclier, porté ; rien pour une autre annulation', function()
            assert.equal('down', weapons.outcome({ applied = 12, downed = true }))
            assert.equal('dodge', weapons.outcome({ cancelled = 'esquive', stage = 'esquive' }))
            assert.equal('parry', weapons.outcome({ cancelled = 'parade', stage = 'parade' }))
            assert.equal('block', weapons.outcome({ cancelled = 'garde', stage = 'blocage' }))
            assert.equal('absorb', weapons.outcome({ cancelled = 'egide', stage = 'bouclier' }))
            assert.equal('block', weapons.outcome({ applied = 0, blocked = 12, absorbed = 0 }))
            assert.equal('absorb', weapons.outcome({ applied = 0, blocked = 0, absorbed = 12 }))
            assert.equal('hit', weapons.outcome({ applied = 4, blocked = 8 }))
            assert.equal('hit', weapons.outcome({ applied = 12 }))
            assert.is_nil(weapons.outcome({ cancelled = 'pvp_off' }))
            assert.is_nil(weapons.outcome({ cancelled = 'zone_protegee', stage = 'annulation' }))
            assert.is_nil(weapons.outcome({ cancelled = 'treve', stage = 'before' }))
            assert.is_nil(weapons.outcome({ cancelled = 'downed' }))
            assert.is_nil(weapons.outcome(nil))
        end)

        it('noticeOf : combats coupés, lieu de paix, crochet ; rien d\'autre', function()
            assert.equal('pvpOff', weapons.noticeOf({ cancelled = 'pvp_off' }))
            assert.equal('peace', weapons.noticeOf({ cancelled = 'zone_protegee', stage = 'annulation' }))
            assert.equal('held', weapons.noticeOf({ cancelled = 'treve', stage = 'before' }))
            assert.is_nil(weapons.noticeOf({ cancelled = 'downed' }))
            assert.is_nil(weapons.noticeOf({ applied = 3 }))
        end)

        it('reasonText : sans contrôle, coupée sans casser un caractère, vide → nil', function()
            assert.equal('Vous êtes au cachot.', weapons.reasonText('  Vous êtes au cachot.\n', 120))
            assert.equal('a b', weapons.reasonText('a\0b', 120))
            assert.is_nil(weapons.reasonText('   ', 120))
            assert.is_nil(weapons.reasonText(42, 120))
            -- « é » occupe deux octets : la coupe à 4 octets ne le casse pas
            assert.equal('abc', weapons.reasonText('abcé', 4))
            assert.equal('abcé', weapons.reasonText('abcé', 5))
            assert.equal(120, #weapons.reasonText(string.rep('x', 300), 120))
        end)
    end)
end)
