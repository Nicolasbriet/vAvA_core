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
            'modules/vava_combat/shared/admission.lua',
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
            refused(function(c) c.styles.epee_une_main.keys.garde = 'garde_epee' end, 'touche inconnue')
            refused(function(c) c.styles.epee_une_main.keys.parade = 'revers' end, 'touche parade')
            refused(function(c) c.styles.epee_une_main.keys.parade = 'garde_epee' end, 'touche parade')
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

        -- relecture sécurité S-5 : Échap et P (lus par vava_pause) ne sont jamais coupés par le mode combat
        it('mode.blocked : jamais 199, 200 ni 322 ; entiers de 0 à 360 ; 32 au plus', function()
            for _, control in ipairs({ 199, 200, 322, 199.0 }) do
                refusedEngine(function(c) c.mode.blocked[#c.mode.blocked + 1] = control end, 'vava_pause')
            end
            refusedEngine(function(c) c.mode.blocked = { 24, 25.5 } end, 'entiers')
            refusedEngine(function(c) c.mode.blocked = { -1 } end, 'entiers')
            refusedEngine(function(c) c.mode.blocked = { 361 } end, 'entiers')
            refusedEngine(function(c) c.mode.blocked = { '24' } end, 'entiers')
            refusedEngine(function(c) c.mode.blocked = { 24, nil, 25 } end, 'mode.blocked')
            refusedEngine(function(c) c.mode.blocked = { 24, pause = 200 } end, 'mode.blocked')
            refusedEngine(function(c) c.mode.blocked = nil end, 'mode.blocked')
            refusedEngine(function(c) c.mode = nil end, 'mode.blocked')
            local many = {}
            for i = 1, 33 do many[i] = i end
            refusedEngine(function(c) c.mode.blocked = many end, '32')
            many[33] = nil
            assert.is_true(weapons.checkEngine(variant(function(c) c.mode.blocked = many end)))
            assert.is_true(weapons.checkEngine(variant(function(c) c.mode.blocked = {} end)))
            -- la liste livrée ne contient aucun des trois
            for _, control in ipairs(cfg.mode.blocked) do
                assert.is_false(control == 199 or control == 200 or control == 322)
            end
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

-- Défense (T-113) : format selon le type, touches de défense, garde ouverte (plan, pick, admit), réglages de la
-- défense. Règles documentées : docs/plan/specs/T-113.md § 4, § 5.1, § 7.1 et § 11.1.
describe('vava_combat techniques défensives', function()
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
            'modules/vava_combat/shared/admission.lua',
        })
        techniques, weapons, cfg = VavaCombat.techniques, VavaCombat.weapons, VavaCombat.config
    end)

    after_each(function() VavaCombat = nil end)

    describe('format selon le type', function()
        it('config livrée : sept techniques, un style à cinq touches, sans avertissement', function()
            local count = 0
            for _ in pairs(cfg.techniques) do count = count + 1 end
            assert.equal(7, count)
            local slots = {}
            for slot in pairs(cfg.styles.epee_une_main.keys) do slots[#slots + 1] = slot end
            table.sort(slots)
            assert.same({ 'blocage', 'esquive', 'legere', 'lourde', 'parade' }, slots)
            assert.same({ true, {} }, { weapons.checkTechniques(cfg) })
        end)

        it('un geste défensif n\'a ni dégâts, ni parryable, ni staggers, ni portée ; l\'esquive n\'a pas de hit', function()
            refused(function(c) c.techniques.garde_epee.damage = 1.0 end, "damage n'a pas de sens pour un blocage")
            refused(function(c) c.techniques.garde_epee.parryable = true end, 'parryable')
            refused(function(c) c.techniques.parade_epee.staggers = false end, 'staggers n\'a pas de sens pour une parade')
            refused(function(c) c.techniques.garde_epee.hit.range = 2 end, 'hit.range')
            refused(function(c) c.techniques.pas_de_cote.hit = { angle = 90 } end, "hit n'a pas de sens pour une esquive")
            refused(function(c) c.techniques.parade_epee.hit = nil end, 'arc protégé')
            refused(function(c) c.techniques.parade_epee.hit.angle = 181 end, 'hit.angle')
            refused(function(c) c.techniques.garde_epee.stamina = 41 end, 'stamina')
        end)

        it('préparation : dès 0 pour un geste défensif, 80 au moins pour une attaque', function()
            refused(function(c) c.techniques.parade_epee.phases.windup = -1 end, 'windup entier de 0')
            refused(function(c) c.techniques.revers.phases.windup = 0 end, 'windup entier de 80')
            assert.is_true((weapons.checkTechniques(variant(function(c) c.techniques.garde_epee.phases.windup = 0 end))))
            refused(function(c) c.techniques.pas_de_cote.phases.active = 501 end, 'active')
        end)

        it('touches : une technique du type de la touche ; touche absente permise ; `garde` inconnue', function()
            refused(function(c) c.styles.epee_une_main.keys.parade = 'garde_epee' end, 'touche parade')
            refused(function(c) c.styles.epee_une_main.keys.esquive = 'parade_epee' end, 'touche esquive')
            refused(function(c) c.styles.epee_une_main.keys.garde = 'garde_epee' end, 'touche inconnue')
            local ok, warnings = weapons.checkTechniques(variant(function(c) c.styles.epee_une_main.keys.esquive = nil end))
            assert.is_true(ok)
            assert.matches("'pas_de_cote'", warnings[1])
        end)

        it('type garde (posture) : contrôlé comme une attaque', function()
            refused(function(c)
                c.techniques.posture = copy(c.techniques.garde_epee)
                c.techniques.posture.type = 'garde'
            end, 'hit.range')
        end)
    end)

    describe('réglages de la défense', function()
        it('config livrée acceptée', function()
            assert.is_true(weapons.checkEngine(cfg))
        end)

        it('bornes : délais, étiquettes, compteur, priorité, mémoire, gestes, contrôles, débit de lower', function()
            refusedEngine(function(c) c.rateLimits.lower = nil end, 'rateLimits.lower')
            refusedEngine(function(c) c.defense.parry.missCooldownMs = 5001 end, 'missCooldownMs')
            refusedEngine(function(c) c.defense.dodgeCooldownMs = -1 end, 'dodgeCooldownMs')
            refusedEngine(function(c) c.defense.dodge.kinds = {} end, 'defense.dodge')
            refusedEngine(function(c) c.defense.dodge.kinds = { 'feu', 'feu' } end, 'defense.dodge')
            refusedEngine(function(c) c.defense.dodge.kinds = { 'Feu' } end, 'defense.dodge')
            refusedEngine(function(c) c.defense.dodge.tags = {} end, 'defense.dodge')
            refusedEngine(function(c) c.defense.dodge.never = { 'melee', 'x y' } end, 'defense.dodge')
            refusedEngine(function(c) c.defense.block.shieldArcBonus = 91 end, 'defense.block')
            refusedEngine(function(c) c.defense.parryTags = { melee = true } end, 'parryTags')
            refusedEngine(function(c) c.defense.guardBreak.points = 0 end, 'guardBreak')
            refusedEngine(function(c) c.defense.guardBreak.resetMs = 100 end, 'guardBreak')
            refusedEngine(function(c) c.defense.modifierPriority = 100 end, 'modifierPriority')
            refusedEngine(function(c) c.defense.memoMax = 4 end, 'memoMax')
            refusedEngine(function(c) c.defense.guardBrokenMs = 6000 end, 'guardBrokenMs')
            refusedEngine(function(c) c.defense.brokenGesture.clip = '' end, 'brokenGesture')
            refusedEngine(function(c) c.defense.dodgeGestures.arriere = c.defense.dodgeGestures.avant end, 'dodgeGestures')
            refusedEngine(function(c) c.defense.dodgeGestures.gauche = nil end, 'dodgeGestures')
            refusedEngine(function(c) c.defense.guardBlocked = { 21, 200 } end, 'vava_pause')
            refusedEngine(function(c) c.defense.guardBlocked = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } end, 'guardBlocked')
        end)

        it('reactions.silent : issues connues, jamais parry ni break', function()
            refusedEngine(function(c) c.reactions.silent = { 'dodge', 'parry' } end, 'parry')
            refusedEngine(function(c) c.reactions.silent = { 'break' } end, 'break')
            refusedEngine(function(c) c.reactions.silent = { 'esquive' } end, 'silent')
            assert.is_true(weapons.checkEngine(variant(function(c) c.reactions.silent = {} end)))
        end)

        it('mode.blocked livré : saut (22) et recharger (45) coupés en mode actif', function()
            local set = {}
            for _, control in ipairs(cfg.mode.blocked) do set[control] = true end
            assert.is_true(set[22] and set[45])
        end)

        it('étiquettes de la défense, pour le recoupement avec vava_health', function()
            assert.same({ 'melee', 'ranged', 'undodgeable', 'area', 'overTime', 'native', 'reflected', 'melee', 'melee' },
                weapons.defenseTags(cfg))
        end)
    end)

    describe('garde ouverte', function()
        local rules
        before_each(function() rules = { earlyMs = 60, chainMax = 3, styles = cfg.styles } end)

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

        it('plan d\'une garde : ni closeAt ni endAt ; d\'une parade : fenêtre dès la demande', function()
            assert.same({ startedAt = 1000, openAt = 1100 }, techniques.plan(cfg.techniques.garde_epee, 1000))
            assert.same({ startedAt = 0, openAt = 0, closeAt = 200, endAt = 450 }, techniques.plan(cfg.techniques.parade_epee, 0))
        end)

        it('admit : garde ouverte → guarding, sans attente, pour une attaque comme pour une parade', function()
            local garde = swing('garde_epee', 0)
            assert.same({ false, 'guarding' }, admit('taille_descendante', 60000, garde))
            assert.same({ false, 'guarding' }, admit('parade_epee', 50, garde))
        end)

        it('admit : parade puis garde (chaîne) à 140, pas à 139 ; parade puis Taille à 390, pas à 389', function()
            local parade = swing('parade_epee', 0)
            assert.same({ false, 'busy', 1 }, admit('garde_epee', 139, parade))
            assert.same({ true, 1 }, admit('garde_epee', 140, parade))
            assert.same({ false, 'busy', 1 }, admit('taille_descendante', 389, parade))
            assert.same({ true, 0 }, admit('taille_descendante', 390, parade))
        end)

        it('pick : garde ouverte → rien ; pendant la récupération d\'une parade, blocage → garde ; libre, parade', function()
            local style = cfg.styles.epee_une_main
            local garde = techniques.plan(cfg.techniques.garde_epee, 0)
            assert.same({ nil, nil }, { techniques.pick(style, 'legere', garde, cfg.techniques.garde_epee, 5000,
                cfg.techniques) })
            local parade = techniques.plan(cfg.techniques.parade_epee, 0)
            assert.equal('garde_epee', (techniques.pick(style, 'blocage', parade, cfg.techniques.parade_epee, 200,
                cfg.techniques)))
            assert.same({ nil, 100 }, { techniques.pick(style, 'blocage', parade, cfg.techniques.parade_epee, 100,
                cfg.techniques) })
            assert.equal('parade_epee', (techniques.pick(style, 'parade', nil, nil, 0, cfg.techniques)))
            assert.equal('pas_de_cote', (techniques.pick(style, 'esquive', nil, nil, 0, cfg.techniques)))
        end)
    end)
end)
