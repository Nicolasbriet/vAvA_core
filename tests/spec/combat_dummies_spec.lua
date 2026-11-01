local helper = require('tests.helper')

-- T-114 : états d'endurance envoyés au seul porteur (doublure bridge.Send)
local staminaSent = {}

-- Mannequins d'entraînement côté serveur (T-156, spec § 5.1, § 7.3 à § 7.9 et § 11.1) : règles pures de
-- shared/dummies.lua, issue « comme si » (weapons.trialOutcome), part du serveur contrôlée (weapons.checkEngine), puis
-- server/dummies.lua, swings.lua (relevés réels), api.lua avec des doublures du bridge (comme combat_use_spec) : coup
-- d'essai de vava_health simulé et noté, envois notés (jamais -1, jamais une liste vide), hooks notés, horloge et
-- minuteries réglées par le test. Un mannequin n'est frappé que si aucun joueur ne l'est, une fois par coup, dans
-- l'instance de l'attaquant ; rien de ce qu'un vrai coup déclenche (hit, réactions, chancellement, défense) ne part.

local A, B, C = 1, 2, 3
local CHAR_A, CHAR_B, CHAR_C = 100, 200, 300
local T0 = 100000

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

--- Mannequins d'essai : le 1 à 1,8 m devant A (centre à hauteur de A), les autres loin.
local function testList()
    return {
        { id = 'essai_1', x = 0.0, y = 1.8, z = -1.0, heading = 180.0 },
        { id = 'essai_2', x = 50.0, y = 50.0, z = -1.0, heading = 0.0, label = 'Mannequin du maître' },
        { id = 'essai_3', x = 100.0, y = 100.0, z = -1.0, heading = 0.0, model = 'prop_haybale_03', bucket = 3 },
    }
end

describe('vava_combat mannequins : règles pures', function()
    local rules, weapons, cfg, check

    before_each(function()
        helper.reset()
        VavaCombat = nil
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/dummies.lua',
            'modules/vava_combat/shared/weapons.lua',
        })
        rules, weapons, cfg = VavaCombat.dummyRules, VavaCombat.weapons, VavaCombat.config
        check = weapons.checkDummies
    end)

    after_each(function() VavaCombat = nil end)

    --- Part client copiée, changée par `changes` (clé = 'nil' pour retirer).
    local function partWith(changes)
        local part = copy(cfg.dummies)
        for key, value in pairs(changes or {}) do
            if value == 'nil' then part[key] = nil else part[key] = value end
        end
        return part
    end

    local function listWith(index, changes)
        local list = copy(cfg.dummies.list)
        for key, value in pairs(changes) do
            if value == 'nil' then list[index][key] = nil else list[index][key] = value end
        end
        return partWith({ list = list })
    end

    it('la config livrée est admise ; fx = false aussi ; liste vide aussi', function()
        assert.is_true(check(cfg.dummies))
        assert.is_true(check(partWith({ fx = false })))
        assert.is_true(check(partWith({ list = {} })))
        assert.equal(3, #cfg.dummies.list)
    end)

    it('refuse chaque défaut de la liste avec une raison', function()
        local long = string.rep('a', 33)
        local cases = {
            listWith(2, { id = 'paleto_1' }),
            listWith(1, { id = 'Paleto_1' }),
            listWith(1, { id = long }),
            listWith(1, { id = '' }),
            listWith(1, { x = 0 / 0 }),
            listWith(1, { y = 50001 }),
            listWith(1, { z = 2001 }),
            listWith(1, { heading = 361 }),
            listWith(1, { heading = 'nord' }),
            listWith(1, { bucket = -1 }),
            listWith(1, { bucket = 1.5 }),
            listWith(1, { model = '' }),
            listWith(1, { label = string.rep('x', 49) }),
            listWith(1, { couleur = 'rouge' }),
        }
        local mixed = copy(cfg.dummies.list)
        mixed.extra = { id = 'x', x = 0, y = 0, z = 0, heading = 0 }
        cases[#cases + 1] = partWith({ list = mixed })
        local many = {}
        for i = 1, 65 do many[i] = { id = 'm' .. i, x = i, y = 0, z = 0, heading = 0 } end
        cases[#cases + 1] = partWith({ list = many })
        cases[#cases + 1] = partWith({ list = 'paleto' })
        for i, part in ipairs(cases) do
            local ok, reason = check(part)
            assert.is_false(ok, 'cas ' .. i)
            assert.is_string(reason, 'cas ' .. i)
        end
        -- 64 mannequins : admis
        many[65] = nil
        assert.is_true(check(partWith({ list = many })))
    end)

    it('refuse chaque défaut des réglages du client', function()
        local cases = {
            { keepRadius = 60.0 }, { keepRadius = 50.0 }, { streamRadius = 5.0 }, { keepRadius = 201.0 },
            { nearPollMs = 50 }, { nearPollMs = 500.5 }, { farPollMs = 20000 }, { centerHeight = 0.1 },
            { anchorHeight = 4 }, { label = '' }, { model = 'nil' }, { fallbackModel = string.rep('m', 65) },
            { modelTimeoutMs = 100 }, { wobble = { ms = 900, angle = 46, cycles = 2 } },
            { wobble = { ms = 900, angle = 14, cycles = 2.5 } }, { wobble = { ms = 4000, angle = 14, cycles = 2 } },
            { wobble = { ms = 900, angle = 14, cycles = 2, extra = 1 } }, { fx = true },
            { fx = { asset = 'core', name = 'x', scale = 6 } }, { fx = { asset = 'core', scale = 1 } },
        }
        for i, changes in ipairs(cases) do
            local ok, reason = check(partWith(changes))
            assert.is_false(ok, 'cas ' .. i)
            assert.is_string(reason, 'cas ' .. i)
        end
        assert.is_false((check(nil)))
    end)

    it('index : numéro = place dans la liste, centre au-dessus du pied, valeurs par défaut', function()
        local part = partWith({ list = testList() })
        assert.is_true(check(part))
        local byN, byId = rules.index(part.list, cfg.dummies.model, cfg.dummies.centerHeight, cfg.dummies.label)
        assert.equal(3, #byN)
        assert.same({ n = 1, id = 'essai_1', x = 0.0, y = 1.8, z = -1.0, heading = 180.0, model = cfg.dummies.model,
            bucket = 0, label = cfg.dummies.label, center = { x = 0.0, y = 1.8, z = 0.0 } }, byN[1])
        assert.equal('Mannequin du maître', byN[2].label)
        assert.equal('prop_haybale_03', byN[3].model)
        assert.equal(3, byN[3].bucket)
        assert.equal(byN[2], byId.essai_2)
    end)

    it('trialOutcome : issue « comme si » et montant en dixièmes, jamais down ni break', function()
        local function result(amount, extra)
            local r = { trial = true, amount = amount, base = amount, blocked = 0, absorbed = 0, resisted = 0, added = 0 }
            for k, v in pairs(extra or {}) do r[k] = v end
            return r
        end
        local taille, fendant = cfg.techniques.taille_descendante, cfg.techniques.fendant
        assert.same({ 'hit', 120 }, { weapons.trialOutcome(result(12), taille) })
        assert.same({ 'stagger', 216 }, { weapons.trialOutcome(result(21.6), fendant) })
        assert.same({ 'hit', 80 }, { weapons.trialOutcome(result(8), nil) })
        assert.same({ 'dodge' }, { weapons.trialOutcome(result(0, { cancelled = 'esquive', stage = 'esquive' }), taille) })
        assert.same({ 'parry' }, { weapons.trialOutcome(result(0, { cancelled = 'pare', stage = 'parade' }), taille) })
        assert.is_nil(weapons.trialOutcome(result(0, { cancelled = 'source_downed' }), taille))
        assert.is_nil(weapons.trialOutcome(result(0, { cancelled = 'treve', stage = 'annulation' }), taille))
        assert.same({ 'block' }, { weapons.trialOutcome(result(0, { blocked = 3 }), taille) })
        assert.same({ 'absorb' }, { weapons.trialOutcome(result(0, { absorbed = 5 }), fendant) })
        -- un mannequin ne tombe pas : un champ `downed` ne change rien
        assert.same({ 'hit', 120 }, { weapons.trialOutcome(result(12, { downed = true }), taille) })
        assert.same({ 'hit', 0 }, { weapons.trialOutcome(result(0, { resisted = 12 }), taille) })
        assert.is_nil(weapons.trialOutcome(nil, taille))
        assert.is_nil(weapons.trialOutcome({ amount = 0 / 0 }, taille))
        assert.is_nil(weapons.trialOutcome({ amount = -1 }, taille))
    end)

    it('part du serveur bornée au démarrage (checkEngine)', function()
        assert.is_true(weapons.checkEngine(cfg))
        local d = cfg.dummies
        local cases = {
            { 'wearChance', 1.5 }, { 'wearChance', -0.1 }, { 'witnessRadius', 31 }, { 'witnessMinMs', 800.5 },
            { 'witnessMinMs', 10001 }, { 'callers', { 'vava_magic', extra = 'x' } }, { 'callers', { 'vava magic' } },
            { 'callers', { 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i' } }, { 'spellMaxDistance', 0.5 },
            { 'nearMax', 17 }, { 'nearMax', 0 }, { 'nearMaxRadius', 101 }, { 'xpMaxLevel', 101 }, { 'xpMaxLevel', 9.5 },
        }
        for i, case in ipairs(cases) do
            local before = d[case[1]]
            d[case[1]] = case[2]
            local ok, reason = weapons.checkEngine(cfg)
            assert.is_false(ok, 'cas ' .. i)
            assert.matches('dummies', reason, 'cas ' .. i)
            d[case[1]] = before
        end
        -- aucune ressource admise : permis (les sorts ne frappent alors aucun mannequin)
        d.callers = {}
        assert.is_true(weapons.checkEngine(cfg))
    end)
end)

describe('vava_combat mannequins (serveur)', function()
    local cfg, swings, reactions, dummies, catalog
    local clock, timers, active, positions, headings, buckets, held, piles
    local hits, trials, trialAnswer, sent, afters, logs, bucketReads, aroundCalls, wearCalls, staggerCalls, exported
    local roll, invoker, onHit
    local realRandom = math.random
    local STUBBED = { 'SetTimeout', 'GetGameTimer', 'exports', 'GetInvokingResource' }

    local function at(ms)
        local target = T0 + ms
        while true do
            local index, due = nil, nil
            for i, timer in ipairs(timers) do
                if timer.due <= target and (not due or timer.due < due) then index, due = i, timer.due end
            end
            if not index then break end
            local timer = table.remove(timers, index)
            clock = timer.due
            timer.fn()
        end
        clock = target
    end

    --- Réponse de swings.use. Geste accepté (T-114) : l'état d'endurance qui suit `true` (trois entiers bornés) est
    --- contrôlé puis retiré ; ses valeurs sont essayées dans combat_endurance_spec.
    local function use(src, id, target)
        local out = { swings.use(src, id, target or 0) }
        if out[1] == true then
            assert.equal(4, #out)
            assert.is_not_nil(VavaCombat.endurance.read(out[2], out[3], out[4]))
            return { true }
        end
        return out
    end

    local function sentOf(event)
        local out = {}
        for _, s in ipairs(sent) do
            if s.event == event then out[#out + 1] = s end
        end
        return out
    end

    local function aftersOf(name)
        local out = {}
        for _, a in ipairs(afters) do
            if a.name == name then out[#out + 1] = a end
        end
        return out
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, timers = T0, {}
        active = { [A] = CHAR_A, [B] = CHAR_B, [C] = CHAR_C }
        -- B et C loin de l'arc de A ; le mannequin 1 à 1,8 m devant A
        positions = { [A] = { 0, 0, 0 }, [B] = { 30, -30, 0 }, [C] = { 60, -60, 0 } }
        headings = { [A] = 0, [B] = 180, [C] = 0 }
        buckets, held, piles = {}, {}, { [A] = {}, [B] = {}, [C] = {} }
        hits, trials, trialAnswer, sent, afters = {}, {}, nil, {}, {}
        logs, bucketReads, aroundCalls, wearCalls, staggerCalls, exported = { warn = {}, info = {} }, 0, 0, {}, {}, {}
        roll, invoker, onHit = 0.99, 'vava_magic', nil

        _G.GetGameTimer = function() return clock end
        _G.SetTimeout = function(ms, fn) timers[#timers + 1] = { due = clock + ms, fn = fn } end
        _G.exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })
        _G.GetInvokingResource = function() return invoker end
        math.random = function() return roll end

        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/dummies.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/heading.lua',
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/shared/admission.lua',
            'modules/vava_combat/shared/defense.lua',
            'modules/vava_combat/shared/endurance.lua',
            'modules/vava_combat/shared/stamina.lua',
            'modules/vava_combat/shared/weapons.lua',
            'modules/vava_combat/shared/guard.lua',
        })
        cfg = VavaCombat.config
        cfg.dummies.list = testList()
        VavaCombat.resource = 'vava_combat'
        VavaCombat.log = {
            warn = function(fmt, ...) logs.warn[#logs.warn + 1] = fmt:format(...) end,
            info = function(fmt, ...) logs.info[#logs.info + 1] = fmt:format(...) end,
        }
        local itemDefs = { epee_courte = { label = 'Épée courte', stack = 1, held = { model = 'w_me_machette_lr' } } }
        VavaCombat.bridge = {
            CONSOLE = 0, INVENTORY = 'vava_inventory', HEALTH = 'vava_health', CRAFTING = 'vava_crafting',
            SKILLS = 'vava_skills',
            ActiveCharacterId = function(src) return active[src] end,
            ActivePlayers = function() return { A, B, C } end,
            Position = function(src)
                local p = positions[src]
                if not p then return nil end
                return p[1], p[2], p[3]
            end,
            Heading = function(src) return positions[src] and headings[src] or nil end,
            Bucket = function(src)
                bucketReads = bucketReads + 1
                return buckets[src] or 0
            end,
            SameBucket = function(a, b) return (buckets[a] or 0) == (buckets[b] or 0) end,
            IsDowned = function() return false end,
            InVehicle = function() return false end,
            MagicHardControl = function() return nil end,
            PlayersNear = function(coords, radius, src)
                local out = {}
                for other in pairs(active) do
                    local p = positions[other]
                    if other ~= src and p and (buckets[other] or 0) == (buckets[src] or 0) then
                        local dx, dy, dz = p[1] - coords.x, p[2] - coords.y, p[3] - coords.z
                        if dx * dx + dy * dy + dz * dz <= radius * radius then out[#out + 1] = other end
                    end
                end
                table.sort(out)
                return out
            end,
            PlayersAround = function(bucket, coords, radius)
                assert.equal('integer', math.type(bucket))
                aroundCalls = aroundCalls + 1
                local out = {}
                for other in pairs(active) do
                    local p = positions[other]
                    if p and (buckets[other] or 0) == bucket then
                        local dx, dy, dz = p[1] - coords.x, p[2] - coords.y, p[3] - coords.z
                        if dx * dx + dy * dy + dz * dz <= radius * radius then out[#out + 1] = other end
                    end
                end
                table.sort(out)
                return out
            end,
            -- jamais -1, jamais une liste vide ni mixte
            SendTo = function(list, event, ...)
                assert.equal('table', type(list))
                assert.is_true(#list >= 1)
                for key, id in pairs(list) do
                    assert.equal('integer', math.type(key))
                    assert.equal('integer', math.type(id))
                    assert.is_true(id > 0)
                end
                local args = table.pack(...)
                args.n = nil
                sent[#sent + 1] = { list = copy(list), event = event, args = args }
                return true
            end,
            SendNear = function() error('aucun envoi de proximité pour un mannequin') end,
            Notify = function() end,
            Held = function(src) return held[src] end,
            Items = function(src, item)
                local out = {}
                for _, entry in ipairs(piles[src] or {}) do
                    if entry.item == item then out[#out + 1] = entry end
                end
                return out
            end,
            PatchMetadata = function() return true end,
            ContainerOf = function() return nil end,
            ItemsReady = function() return true end,
            HasItem = function(name) return itemDefs[name] ~= nil end,
            ItemDefinition = function(name) return copy(itemDefs[name]) end,
            AddItem = function(name, def)
                itemDefs[name] = def
                return true
            end,
            ModuleVersion = function() return nil end,
            RecipesReady = function() return false end,
            Recipe = function() return nil end,
            SkillRecipesReady = function() return false end,
            HealthKinds = function() return { 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur', 'privation', 'monde' } end,
            HealthTags = function() return { 'melee', 'ranged', 'area', 'overTime', 'native', 'reflected', 'parryable',
                'unblockable', 'undodgeable' } end,
            DefineShieldField = function() return true end,
            Hit = function(target, packet)
                hits[#hits + 1] = { target = target, packet = copy(packet) }
                if onHit then onHit(target) end
                return { id = #hits, amount = packet.amount, applied = packet.amount, blocked = 0, absorbed = 0,
                    resisted = 0, added = 0, downed = false, health = 0.5 }
            end,
            Trial = function(packet, place)
                trials[#trials + 1] = { packet = copy(packet), place = copy(place), at = clock - T0 }
                if trialAnswer then return trialAnswer(packet, place) end
                return { trial = true, amount = packet.amount, base = packet.amount, blocked = 0, absorbed = 0,
                    resisted = 0, added = 0 }
            end,
            RunBefore = function() return true end,
            RunAfter = function(name, payload) afters[#afters + 1] = { name = name, payload = copy(payload) } end,
            SetShieldField = function() end,
            ShieldField = function() return nil end,
            Timer = function() return clock end,
            -- T-114 : faim et soif (vava_needs absent : facteur 1) ; état d'endurance au seul porteur
            NeedsValues = function() return nil end,
            Send = function(target, event, ...)
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                staminaSent[#staminaSent + 1] = { target = target, event = event, args = { ... } }
                return true
            end,
        }
        helper.loadAll({
            'modules/vava_combat/server/catalog.lua',
            'modules/vava_combat/server/pedstate.lua',
            'modules/vava_combat/server/wear.lua',
            'modules/vava_combat/server/shields.lua',
            'modules/vava_combat/server/strike.lua',
            'modules/vava_combat/server/hands.lua',
            'modules/vava_combat/server/reactions.lua',
            'modules/vava_combat/server/dummies.lua',
            'modules/vava_combat/server/stamina.lua',
            'modules/vava_combat/server/defense.lua',
            'modules/vava_combat/server/swings.lua',
            'modules/vava_combat/server/api.lua',
        })
        catalog, swings, reactions, dummies = VavaCombat.catalog, VavaCombat.swings, VavaCombat.reactions,
            VavaCombat.dummies
        local ok, err = catalog.setup()
        assert.is_true(ok, err)
        ok, err = dummies.start()
        assert.is_true(ok, err)
        VavaCombat.ready = true
        local apply = VavaCombat.wear.apply
        VavaCombat.wear.apply = function(...)
            wearCalls[#wearCalls + 1] = { ... }
            return apply(...)
        end
        local stagger = reactions.stagger
        reactions.stagger = function(...)
            staggerCalls[#staggerCalls + 1] = { ... }
            return stagger(...)
        end
        local entry = { id = 10, item = 'epee_courte', quantity = 1, metadata = {} }
        piles[A][1] = entry
        held[A] = entry
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        math.random = realRandom
        VavaCombat = nil
    end)

    describe('un coup d\'arme', function()
        it('Taille face au mannequin 1 à 1,8 m : un essai, l\'issue et le montant à A seul', function()
            assert.same({ true }, use(A, 'taille_descendante'))
            at(320)
            assert.equal(1, #trials)
            assert.same({ amount = 12, kind = 'tranchant', source = A, weapon = 'epee_courte',
                technique = 'taille_descendante', tags = { melee = true, parryable = true } }, trials[1].packet)
            assert.same({ x = 0.0, y = 1.8, z = 0.0 }, trials[1].place)
            assert.equal(0, #hits)
            assert.same({ { list = { A }, event = 'vava_combat:dummy', args = { 1, A, 'hit', 120 } } }, sent)
            assert.equal(0, #sentOf('vava_combat:hit'))
            -- second relevé : le mannequin n'est frappé qu'une fois par coup
            at(480)
            assert.equal(1, #trials)
            assert.equal(1, #sent)
        end)

        -- T-114 : une Taille sur un mannequin coûte ce qu'elle coûte dans le vide ou sur un joueur (payée à l'acceptation)
        it('endurance : la Taille sur le mannequin est payée comme une autre (880), rien n\'est rendu', function()
            assert.same({ true, 880, 1000, 200 }, { swings.use(A, 'taille_descendante', 0) })
            at(320)
            assert.equal(1, #trials)
            at(900)
            assert.equal(880, VavaCombat.stamina.inspect(A).value)
            assert.equal(0, #staminaSent)
        end)

        it('témoin C à 10 m : balancement seul ; à 20 m : rien', function()
            positions[C] = { 10, 1.8, 0 }
            use(A, 'taille_descendante')
            at(320)
            assert.equal(2, #sent)
            assert.same({ list = { C }, event = 'vava_combat:dummy', args = { 1, A } }, sent[2])
            -- un autre coup plus tard : C à 20 m, plus rien pour lui
            sent = {}
            positions[C] = { 20, 1.8, 0 }
            at(2000)
            use(A, 'taille_descendante')
            at(2320)
            assert.equal(1, #sent)
            assert.same({ A }, sent[1].list)
        end)

        it('au plus un balancement aux témoins par mannequin et par 0,8 s, quel que soit le nombre de coups', function()
            positions[C] = { 10, 1.8, 0 }
            use(A, 'taille_descendante')         -- relevé à 320
            at(500)
            use(A, 'estoc_rapide')               -- enchaîné, relevé à 720 : 400 ms après, C rien
            at(900)
            use(A, 'revers')                     -- enchaîné, relevé à 1180 : 860 ms après, C de nouveau
            at(1200)
            local toA, toC = {}, {}
            for _, s in ipairs(sent) do
                if s.list[1] == A then toA[#toA + 1] = s else toC[#toC + 1] = s end
            end
            assert.equal(3, #toA)
            assert.equal(2, #toC)
            assert.same({ 1, A, 'hit', 96 }, toA[2].args)   -- estoc : 12 × 0,8
            -- la recherche des témoins ne se refait pas avant le délai
            assert.equal(2, aroundCalls)
        end)

        it('derrière A, hors de portée ou trop haut : rien ; aucune instance lue sans mannequin proche', function()
            local cases = {
                { 0.0, -1.8, -1.0 },   -- derrière
                { 0.0, 2.9, -1.0 },    -- 2,9 m : au-delà de la portée (2,2 + 0,25)
                { 0.0, 1.8, 1.5 },     -- centre 2,5 m plus haut que A
            }
            for i, place in ipairs(cases) do
                local list = testList()
                list[1].x, list[1].y, list[1].z = place[1], place[2], place[3]
                dummies.replace(list)
                clock = T0 + (i - 1) * 2000
                timers = {}
                swings.forget(A)
                swings.use(A, 'taille_descendante', 0)
                at((i - 1) * 2000 + 480)
                assert.equal(0, #trials, 'cas ' .. i)
                assert.equal(0, #sent, 'cas ' .. i)
            end
            -- mannequins à plus de portée + marge : jugés en mémoire, aucune lecture d'instance
            local far = testList()
            far[1].y = 10.0
            dummies.replace(far)
            bucketReads = 0
            at(10000)
            swings.use(A, 'taille_descendante', 0)
            at(10480)
            assert.equal(0, bucketReads)
        end)

        it('B dans l\'arc avec le mannequin : B est frappé, le mannequin n\'a rien', function()
            positions[B] = { 0.3, 1.5, 0 }
            use(A, 'taille_descendante')
            at(480)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            assert.equal(0, #trials)
            assert.equal(0, #sentOf('vava_combat:dummy'))
        end)

        it('S-1 : un mannequin n\'empêche jamais de frapper un joueur entré dans l\'arc au relevé suivant', function()
            positions[B] = { 0.3, 6.0, 0 }   -- hors de portée à l'ouverture de la frappe
            use(A, 'taille_descendante')
            at(320)
            assert.equal(1, #trials)
            assert.equal(0, #hits)
            positions[B] = { 0.3, 1.5, 0 }   -- entré dans l'arc avant le second relevé
            at(480)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            assert.equal(1, #trials)       -- le mannequin n'est pas frappé une seconde fois
        end)

        it('S-1 : aucun mannequin si un joueur a été frappé, même avec deux adversaires par coup', function()
            cfg.geometry.maxTargets = 2
            positions[B] = { 0.3, 1.5, 0 }
            use(A, 'taille_descendante')
            at(480)
            assert.equal(1, #hits)
            assert.equal(0, #trials)
        end)

        it('S-3 : bouclier tenu (ou objet inconnu) : rien, aucun essai', function()
            local swing = { source = A, id = 'taille_descendante', def = cfg.techniques.taille_descendante,
                characterId = CHAR_A }
            local at0 = { x = 0, y = 0, z = 0 }
            assert.is_nil(dummies.strike(swing, 1, { id = 11, item = 'bouclier_rond', metadata = {} }, at0))
            assert.is_nil(dummies.strike(swing, 1, { id = 12, item = 'caillou', metadata = {} }, at0))
            assert.equal(0, #trials)
            -- contre-essai : l'épée tenue frappe
            assert.equal('hit', dummies.strike(swing, 1, held[A], at0))
            assert.equal(1, #trials)
        end)

        it('A dans une autre instance : rien ; contre-essai : mannequin de son instance frappé', function()
            buckets[A] = 3
            use(A, 'taille_descendante')
            at(480)
            assert.equal(0, #trials)
            local list = testList()
            list[1].bucket = 3
            dummies.replace(list)
            at(2000)
            use(A, 'taille_descendante')
            at(2480)
            assert.equal(1, #trials)
        end)

        it('coup annulé avant la frappe (A chancelle) : rien', function()
            use(A, 'taille_descendante')
            at(100)
            reactions.stagger(A, 900, clock)
            at(480)
            assert.equal(0, #trials)
            assert.equal(0, #sent)
        end)

        it('Fendant : « Chancelle » montré, personne ne chancelle, aucun vava_combat:hit', function()
            use(A, 'fendant')
            at(650)
            assert.equal(1, #trials)
            assert.same({ melee = true }, trials[1].packet.tags)
            assert.same({ 1, A, 'stagger', 216 }, sent[1].args)
            assert.equal(0, #staggerCalls)
            assert.equal(0, #sentOf('vava_combat:hit'))
            assert.is_nil(reactions.staggeredLeft(A, clock))
        end)

        it('usure réduite : tirage 0,2 → l\'arme s\'use ; 0,3 → non', function()
            roll = 0.2
            use(A, 'taille_descendante')
            at(480)
            assert.equal(1, #wearCalls)
            assert.same({ A, 10, 'epee_courte' }, { wearCalls[1][1], wearCalls[1][2], wearCalls[1][3] })
            assert.equal(CHAR_A, wearCalls[1][5])
            roll = 0.3
            at(2000)
            use(A, 'taille_descendante')
            at(2480)
            assert.equal(1, #wearCalls)
            -- un essai annulé n'use jamais, même au tirage le plus bas
            roll = 0.0
            local before = #sent
            trialAnswer = function()
                return { trial = true, amount = 0, base = 12, blocked = 0, absorbed = 0, resisted = 0, added = 0,
                    cancelled = 'source_downed' }
            end
            at(4000)
            use(A, 'taille_descendante')
            at(4480)
            assert.equal(1, #wearCalls)
            assert.equal(before, #sent)
        end)

        it('hook trained une fois, charge complète ; aucun hook defended', function()
            use(A, 'taille_descendante')
            at(480)
            local trained = aftersOf('vava_combat:trained')
            assert.equal(1, #trained)
            assert.same({ source = A, characterId = CHAR_A, dummy = 'essai_1', n = 1, kind = 'melee',
                technique = 'taille_descendante', item = 'epee_courte', amount = 12, outcome = 'hit' }, trained[1].payload)
            assert.equal(0, #aftersOf('vava_combat:defended'))
        end)

        it('chiffres coupés (numbers.enabled ou attacker) : issue sans montant ; witnessRadius 0 : aucun témoin', function()
            positions[C] = { 10, 1.8, 0 }
            cfg.numbers.enabled = false
            cfg.dummies.witnessRadius = 0
            use(A, 'taille_descendante')
            at(480)
            assert.same({ { list = { A }, event = 'vava_combat:dummy', args = { 1, A, 'hit' } } }, sent)
            assert.equal(0, aroundCalls)
            cfg.numbers.enabled, cfg.numbers.attacker = true, false
            sent = {}
            at(2000)
            use(A, 'taille_descendante')
            at(2480)
            assert.same({ 1, A, 'hit' }, sent[1].args)
        end)

        it('issue sans montant (bloqué par un modificateur inscrit) : false en 4e valeur', function()
            trialAnswer = function()
                return { trial = true, amount = 0, base = 12, blocked = 12, absorbed = 0, resisted = 0, added = 0 }
            end
            use(A, 'taille_descendante')
            at(480)
            assert.same({ 1, A, 'block', false }, sent[1].args)
        end)

        it('vava_health muet : rien d\'envoyé, une ligne de console par minute', function()
            trialAnswer = function() return nil, 'health_unavailable' end
            for i = 0, 2 do
                at(i * 2000)
                use(A, 'taille_descendante')
                at(i * 2000 + 480)
            end
            assert.equal(3, #trials)
            assert.equal(0, #sent)
            assert.equal(0, #afters)
            local lines = 0
            for _, line in ipairs(logs.warn) do
                if line:find('health_unavailable', 1, true) then lines = lines + 1 end
            end
            assert.equal(1, lines)
        end)

        it('filet de 6 m : un coup sur un mannequin trop loin des positions du serveur est retenu', function()
            local swing = { source = A, id = 'taille_descendante', def = cfg.techniques.taille_descendante,
                characterId = CHAR_A }
            assert.is_nil(dummies.strike(swing, 1, held[A], { x = 0, y = 8, z = 0 }))
            assert.equal(0, #trials)
            assert.equal('hit', dummies.strike(swing, 1, held[A], { x = 0, y = 0, z = 0 }))
            assert.equal(1, #trials)
        end)
    end)

    describe('exports', function()
        it('dummyHit : réservé à dummies.callers, une ligne de console par minute et par ressource', function()
            invoker = 'vava_autre'
            local packet = { amount = 8, kind = 'feu', source = A, spell = 'boule_de_feu', tags = { spell = true, ranged = true } }
            for _ = 1, 3 do
                local result, code = exported.dummyHit(1, packet)
                assert.is_nil(result)
                assert.equal('not_allowed', code)
            end
            assert.equal(1, #logs.warn)
            clock = clock + 60000
            exported.dummyHit(1, packet)
            assert.equal(2, #logs.warn)
            assert.equal(0, #trials)
        end)

        it('dummyHit : admis, paquet tel quel, envoi au lanceur, hook trained (spell)', function()
            local packet = { amount = 8, kind = 'feu', source = A, sourceCharacter = CHAR_A, spell = 'boule_de_feu',
                tags = { spell = true, ranged = true } }
            positions[A] = { 0, -20, 0 }
            local result, code = exported.dummyHit(1, packet)
            assert.is_nil(code)
            assert.same({ outcome = 'hit', amount = 8 }, result)
            assert.same(packet, trials[1].packet)
            assert.same({ x = 0.0, y = 1.8, z = 0.0 }, trials[1].place)
            assert.same({ { list = { A }, event = 'vava_combat:dummy', args = { 1, A, 'hit', 80 } } }, sent)
            local trained = aftersOf('vava_combat:trained')
            assert.equal(1, #trained)
            assert.same({ source = A, characterId = CHAR_A, dummy = 'essai_1', n = 1, kind = 'spell',
                spell = 'boule_de_feu', amount = 8, outcome = 'hit' }, trained[1].payload)
        end)

        it('dummyHit : refus par code', function()
            local function packet(src) return { amount = 8, kind = 'feu', source = src, spell = 'boule_de_feu' } end
            for _, n in ipairs({ 0, 99, 1.5, 'a', nil }) do
                assert.equal('invalid_dummy', select(2, exported.dummyHit(n, packet(A))), tostring(n))
            end
            assert.equal('no_character', select(2, exported.dummyHit(1, packet(9))))
            assert.equal('no_character', select(2, exported.dummyHit(1, 'paquet')))
            assert.equal('no_character', select(2, exported.dummyHit(1, packet(-1))))
            -- autre instance ; 81 m ; contre-essai : 79 m
            buckets[A] = 2
            assert.equal('too_far', select(2, exported.dummyHit(1, packet(A))))
            buckets[A] = nil
            positions[A] = { 0, 1.8 - 81, 0 }
            assert.equal('too_far', select(2, exported.dummyHit(1, packet(A))))
            positions[A] = { 0, 1.8 - 79, 0 }
            assert.is_table(exported.dummyHit(1, packet(A)))
            -- code de vava_health rendu tel quel
            trialAnswer = function() return nil, 'invalid_amount' end
            assert.equal('invalid_amount', select(2, exported.dummyHit(1, packet(A))))
            -- module pas prêt
            VavaCombat.ready = false
            assert.equal('not_ready', select(2, exported.dummyHit(1, packet(A))))
        end)

        it('dummyHit : essai annulé (lanceur à terre) → issue nil, rien d\'envoyé, aucun hook', function()
            trialAnswer = function()
                return { trial = true, amount = 0, base = 8, blocked = 0, absorbed = 0, resisted = 0, added = 0,
                    cancelled = 'source_downed' }
            end
            local result = exported.dummyHit(1, { amount = 8, kind = 'feu', source = A, spell = 'boule_de_feu' })
            assert.same({ amount = 0 }, result)
            assert.equal(0, #sent)
            assert.equal(0, #afters)
        end)

        it('dummiesNear : bornes, tri par distance puis numéro, au plus nearMax, copies', function()
            assert.same({}, exported.dummiesNear({ x = 0, y = 0, z = 0 }, 0))
            assert.same({}, exported.dummiesNear({ x = 0, y = 0, z = 0 }, 51))
            assert.same({}, exported.dummiesNear({ x = 0 / 0, y = 0, z = 0 }, 5))
            assert.same({}, exported.dummiesNear('ici', 5))
            local list = {}
            for i = 1, 10 do list[i] = { id = 'm' .. i, x = 11 - i, y = 0.0, z = -1.0, heading = 0.0 } end
            list[11] = { id = 'egal', x = 3.0, y = 0.0, z = -1.0, heading = 0.0 }
            dummies.replace(list)
            local near = exported.dummiesNear({ x = 0, y = 0, z = 0 }, 50)
            assert.equal(cfg.dummies.nearMax, #near)
            assert.same({ n = 10, id = 'm10', x = 1.0, y = 0.0, z = 0.0, distance = 1.0 }, near[1])
            -- même distance : le plus petit numéro d'abord
            assert.equal(8, near[3].n)
            assert.equal(11, near[4].n)
            near[1].x = 999
            assert.equal(1.0, exported.dummiesNear({ x = 0, y = 0, z = 0 }, 50)[1].x)
            VavaCombat.ready = false
            assert.same({}, exported.dummiesNear({ x = 0, y = 0, z = 0 }, 50))
        end)

        it('dummies() : copies de la liste chargée', function()
            local view = exported.dummies()
            assert.equal(3, #view)
            assert.same({ n = 1, id = 'essai_1', label = cfg.dummies.label, x = 0.0, y = 1.8, z = -1.0, heading = 180.0,
                bucket = 0, model = cfg.dummies.model }, view[1])
            view[1].x = 50
            assert.equal(0.0, exported.dummies()[1].x)
        end)

        it('démarrage refusé pour une liste invalide ; arrêt : tout est oublié', function()
            cfg.dummies.list = { { id = 'a', x = 0, y = 0, z = 0, heading = 400 } }
            local ok, reason = dummies.start()
            assert.is_false(ok)
            assert.matches('heading', reason)
            cfg.dummies.list = testList()
            assert.is_true(dummies.start())
            dummies.stop()
            assert.equal(0, dummies.count())
            assert.same({}, exported.dummies())
        end)
    end)
end)
