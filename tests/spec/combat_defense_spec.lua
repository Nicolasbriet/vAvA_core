local helper = require('tests.helper')

-- Défense (modules/vava_combat, T-113) : règles pures de shared/defense.lua, puis le serveur réel (swings, defense,
-- reactions, strike, hands, wear, catalog) avec des doublures et une CHAÎNE D'ESSAI : `Hit` appelle, dans l'ordre des
-- étapes (esquive, parade, blocage), les modificateurs déclarés par `DeclareModifiers` (copie du contexte, comme
-- vava_health, dans une coroutine qui ne doit jamais céder la main), calcule `applied`, puis le hook `after` donné à
-- `OnHitAfter`. Horloge et minuteries (SetTimeout) à la main. Règles documentées : docs/plan/specs/T-113.md § 7 et § 11.1.

local A, B, C = 1, 2, 3
local CHAR_A, CHAR_B, CHAR_C = 100, 200, 300
local T0 = 100000
local SHIELD_ID = 50
local KEYS = { esquive = 'vava_combat:esquive', parade = 'vava_combat:parade', blocage = 'vava_combat:blocage' }
local STAGES = { 'esquive', 'parade', 'blocage' }

--- Montant au dixième (les soustractions de la chaîne d'essai laissent des restes de virgule flottante).
local function tenth(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

local function loadPure()
    helper.reset()
    VavaCombat = nil
    helper.loadAll({
        'modules/vava_combat/shared/constants.lua',
        'modules/vava_combat/config.lua',
        'modules/vava_combat/shared/heading.lua',
        'modules/vava_combat/shared/geometry.lua',
        'modules/vava_combat/shared/defense.lua',
    })
    return VavaCombat.defense, VavaCombat.config
end

describe('vava_combat défense : règles pures', function()
    local defense, cfg

    before_each(function() defense, cfg = loadPure() end)
    after_each(function() VavaCombat = nil end)

    local function swing(id, now)
        local def = cfg.techniques[id]
        local p = def.phases
        local out = { def = def, startedAt = now, openAt = now + p.windup }
        if def.type ~= 'blocage' then
            out.closeAt = out.openAt + p.active
            out.endAt = out.closeAt + p.recovery
        end
        return out
    end

    it('open : parade à 0 ouverte de 0 à 200 ; réservée, refusée, annulée : fermée ; garde ouverte dès 100', function()
        local parade = swing('parade_epee', 0)
        for _, now in ipairs({ 0, 150, 200 }) do assert.is_true(defense.open(parade, now), tostring(now)) end
        assert.is_false(defense.open(parade, 201))
        for _, flag in ipairs({ 'pending', 'refused', 'cancelled' }) do
            local other = swing('parade_epee', 0)
            other[flag] = flag == 'cancelled' and 'stagger' or true
            assert.is_false(defense.open(other, 100), flag)
        end
        local garde = swing('garde_epee', 0)
        assert.is_false(defense.open(garde, 99))
        assert.is_true(defense.open(garde, 100))
        assert.is_true(defense.open(garde, 60000))
        assert.is_false(defense.open(garde, 0 / 0))
        assert.is_false(defense.open(nil, 100))
    end)

    it('close : abaissée à 150 → 300 / 550 ; à 1 000 → 1 000 / 1 250 ; déjà fermée ou parade : rien', function()
        local garde = swing('garde_epee', 0)
        assert.is_true(defense.close(garde, 150))
        assert.same({ 300, 550 }, { garde.closeAt, garde.endAt })
        assert.is_false(defense.close(garde, 5000))
        assert.same({ 300, 550 }, { garde.closeAt, garde.endAt })
        garde = swing('garde_epee', 0)
        defense.close(garde, 1000)
        assert.same({ 1000, 1250 }, { garde.closeAt, garde.endAt })
        assert.is_false(defense.close(swing('parade_epee', 0), 100))
        assert.is_false(defense.open(garde, 1001))
    end)

    it('frontal : arc 120 + 10° de tolérance, contact, hauteur, valeur illisible', function()
        local origin = { x = 0, y = 0, z = 0 }
        local function at(deg, distance, z)
            local r = math.rad(deg)
            return { x = -math.sin(r) * distance, y = math.cos(r) * distance, z = z or 0 }
        end
        assert.is_true(defense.frontal(origin, 0, { x = 0, y = 2, z = 0 }, 120, cfg))
        assert.is_true(defense.frontal(origin, 0, at(69.9, 2), 120, cfg))
        assert.is_false(defense.frontal(origin, 0, at(70.1, 2), 120, cfg))
        assert.is_false(defense.frontal(origin, 0, { x = 0, y = -2, z = 0 }, 120, cfg))
        assert.is_true(defense.frontal(origin, 0, { x = 0, y = -0.5, z = 0 }, 120, cfg))
        assert.is_false(defense.frontal(origin, 0, { x = 0, y = 1, z = 2.01 }, 120, cfg))
        assert.is_true(defense.frontal(origin, 0, at(89.9, 2), 160, cfg))
        assert.is_false(defense.frontal(origin, 0 / 0, { x = 0, y = 2, z = 0 }, 120, cfg))
        assert.is_false(defense.frontal(origin, 0, { x = 0 / 0, y = 2, z = 0 }, 120, cfg))
        assert.is_false(defense.frontal(origin, 0, { x = 0, y = 2, z = 0 }, 0 / 0, cfg))
    end)

    it('tagsMatch : une étiquette voulue, aucune interdite', function()
        local any, never = cfg.defense.dodge.tags, cfg.defense.dodge.never
        assert.is_true(defense.tagsMatch({ melee = true }, any, never))
        assert.is_true(defense.tagsMatch({ spell = true, ranged = true }, any, never))
        assert.is_false(defense.tagsMatch({ ranged = true, area = true }, any, never))
        assert.is_false(defense.tagsMatch({ spell = true }, any, never))
        assert.is_false(defense.tagsMatch({ melee = true, undodgeable = true }, any, never))
        assert.is_false(defense.tagsMatch(nil, any, never))
    end)

    it('blockFactor : épée, épée émoussée, bouclier encore accroché, émoussé, décroché', function()
        local wear = cfg.wear
        assert.same({ 0.40, 'weapon' }, { defense.blockFactor({ weaponBlock = 0.40 }, nil, wear) })
        assert.same({ 0.20, 'weapon' }, { defense.blockFactor({ weaponBlock = 0.40, weaponDull = true }, nil, wear) })
        local guard = { weaponBlock = 0.40, shieldInstanceId = SHIELD_ID, shieldBlock = 0.70 }
        assert.same({ 0.70, 'shield' }, { defense.blockFactor(guard, SHIELD_ID, wear) })
        guard.shieldDull = true
        assert.same({ 0.35, 'shield' }, { defense.blockFactor(guard, SHIELD_ID, wear) })
        assert.same({ 0.40, 'weapon' }, { defense.blockFactor(guard, 51, wear) })
        assert.same({ 0.40, 'weapon' }, { defense.blockFactor(guard, nil, wear) })
    end)

    it('blockedAmount : au dixième, jamais plus que le coup ; illisible : 0', function()
        assert.equal(4.8, defense.blockedAmount(12, 0.40))
        assert.equal(8.4, defense.blockedAmount(12, 0.70))
        assert.equal(15.1, defense.blockedAmount(21.6, 0.70))
        assert.equal(12, defense.blockedAmount(12, 1.0))
        assert.equal(12, defense.blockedAmount(12, 1.2))
        assert.equal(0, defense.blockedAmount(0 / 0, 0.4))
        assert.equal(0, defense.blockedAmount(12, -1))
    end)

    it('parryWait : 600 ms après la fin d\'une parade ratée ; réussie : rien ; annulée : ratée', function()
        local last = swing('parade_epee', 0)
        assert.equal(600, defense.parryWait(last, 200, cfg))
        assert.equal(1, defense.parryWait(last, 799, cfg))
        assert.is_nil(defense.parryWait(last, 800, cfg))
        last.parried = true
        assert.is_nil(defense.parryWait(last, 300, cfg))
        local cancelled = swing('parade_epee', 0)
        cancelled.cancelled = 'stagger'
        assert.equal(500, defense.parryWait(cancelled, 300, cfg))
        assert.is_nil(defense.parryWait(nil, 300, cfg))
    end)

    it('dodgeWait : 1 500 ms entre deux départs', function()
        assert.equal(1499, defense.dodgeWait(0, 1, cfg))
        assert.is_nil(defense.dodgeWait(0, 1500, cfg))
        assert.is_nil(defense.dodgeWait(nil, 1, cfg))
    end)

    it('addPoints : 4 coups (6 au bouclier), un lourd en vaut 2, remis à zéro après 3 s sans coup', function()
        local state, broken = nil, false
        for i = 1, 3 do
            state, broken = defense.addPoints(state, 1, i * 100, cfg, false)
            assert.is_false(broken)
        end
        state, broken = defense.addPoints(state, 1, 400, cfg, false)
        assert.is_true(broken)
        state = defense.addPoints(nil, defense.weightOf(cfg.techniques.fendant, cfg), 0, cfg, false)
        assert.equal(2, state.value)
        assert.is_true(select(2, defense.addPoints(state, 2, 1550, cfg, false)))
        state = nil
        for i = 1, 5 do
            state, broken = defense.addPoints(state, 1, i * 100, cfg, true)
            assert.is_false(broken)
        end
        assert.is_true(select(2, defense.addPoints(state, 1, 600, cfg, true)))
        state = nil
        for i = 1, 3 do state = defense.addPoints(state, 1, i * 100, cfg, false) end
        state, broken = defense.addPoints(state, 1, 3300, cfg, false)
        assert.same({ 1, false }, { state.value, broken })
        assert.equal(1, defense.weightOf(cfg.techniques.taille_descendante, cfg))
        assert.equal(1, defense.weightOf(nil, cfg))
    end)
end)

describe('vava_combat défense (serveur)', function()
    local cfg, swings, defense, reactions, hands
    local clock, timers, active, positions, headings, buckets, downed, vehicles, held, piles, magic, hung
    local hits, sent, notifies, befores, beforeAnswer, afters, patches, logs, calls, itemDefs
    local registry, registryExists, hitAfter, hitSeq, inChain, downOnHit
    local realRandom = math.random
    local STUBBED = { 'SetTimeout', 'GetGameTimer', 'exports', 'GetInvokingResource', 'Wait' }
    local COUNTED = { 'ActiveCharacterId', 'Held', 'IsDowned', 'InVehicle', 'MagicHardControl', 'Position', 'Heading',
        'Timer', 'Items' }

    local function pile(id, item, metadata)
        return { id = id, item = item, quantity = 1, metadata = metadata or {} }
    end

    local function arm(src, id, item)
        local entry = pile(id, item)
        piles[src][#piles[src] + 1] = entry
        held[src] = entry
        return entry
    end

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

    local function use(src, id, target)
        return { swings.use(src, id, target or 0) }
    end

    local function nativeCalls()
        local total = 0
        for _, count in pairs(calls) do total = total + count end
        return total
    end

    --- Chaîne d'essai : modificateurs déclarés, dans l'ordre des étapes, puis hook after.
    local function chainHit(target, packet)
        hitSeq = hitSeq + 1
        local ctx = { id = hitSeq, target = target, targetCharacter = active[target], origin = 'vava_combat',
            kind = packet.kind, amount = packet.amount, tags = copy(packet.tags or {}), source = packet.source,
            technique = packet.technique, weapon = packet.weapon }
        local amount, blocked, cancelled, stage = packet.amount, 0, nil, nil
        inChain = true
        for _, name in ipairs(STAGES) do
            local entry = registry[KEYS[name]]
            local fits = true
            if entry and entry.kinds then
                fits = false
                for _, kind in ipairs(entry.kinds) do fits = fits or kind == ctx.kind end
            end
            if entry and fits then
                local view = copy(ctx)
                view.amount, view.stage = amount, name
                -- un modificateur ne cède jamais la main : une coroutine qui ne finit pas fait échouer l'essai
                local co = coroutine.create(entry.apply)
                local ok, result = coroutine.resume(co, view)
                assert.is_true(ok, tostring(result))
                assert.equal('dead', coroutine.status(co))
                if type(result) == 'table' and result.cancel then
                    amount, cancelled, stage = 0, result.cancel, name
                    break
                end
                if type(result) == 'table' and result.blocked then
                    local taken = math.min(result.blocked, amount)
                    amount, blocked = amount - taken, blocked + taken
                end
            end
        end
        inChain = false
        local downedNow = not cancelled and downOnHit[target] == true
        local result = { id = hitSeq, amount = amount, applied = cancelled and 0 or amount, blocked = blocked,
            absorbed = 0, resisted = 0, added = 0, cancelled = cancelled, stage = stage, downed = downedNow,
            health = 0.5 }
        hits[#hits + 1] = { target = target, packet = copy(packet), at = clock - T0, result = copy(result) }
        local payload = copy(ctx)
        for key, value in pairs(result) do payload[key] = value end
        payload.stage = stage
        if hitAfter then hitAfter(payload) end
        return result
    end

    local function lastHit() return hits[#hits].result end

    local function outcomes()
        local out = {}
        for i, entry in ipairs(sent) do out[i] = entry.args[3] end
        return out
    end

    local function patched(src, id)
        local out = {}
        for _, entry in ipairs(patches) do
            if entry.src == src and entry.id == id then out[#out + 1] = entry end
        end
        return out
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, timers = T0, {}
        active = { [A] = CHAR_A, [B] = CHAR_B, [C] = CHAR_C }
        -- A au sud, tourné vers le nord ; B à 2 m au nord, tourné vers A
        positions = { [A] = { 0, 0, 0 }, [B] = { 0, 2, 0 }, [C] = { 30, 30, 0 } }
        headings = { [A] = 0, [B] = 180, [C] = 0 }
        buckets, downed, vehicles, held, piles, magic, hung = {}, {}, {}, {}, { [A] = {}, [B] = {}, [C] = {} }, {}, {}
        hits, sent, notifies, befores, beforeAnswer, afters, patches = {}, {}, {}, {}, nil, {}, {}
        logs, calls = { warn = {}, info = {} }, {}
        registry, registryExists, hitAfter, hitSeq, inChain, downOnHit = {}, true, nil, 0, false, {}
        itemDefs = { epee_courte = { label = 'Épée courte', stack = 1, held = { model = 'w_me_machette_lr' } } }

        _G.GetGameTimer = function() return clock end
        _G.SetTimeout = function(ms, fn) timers[#timers + 1] = { due = clock + ms, fn = fn } end
        _G.exports = setmetatable({}, { __call = function() end })
        _G.GetInvokingResource = function() return 'vava_example_combat' end
        _G.Wait = function() error('Wait appelé : rien ne doit attendre ici') end
        math.random = function() return 0 end   -- chaque coup qui touche use la pièce

        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/heading.lua',
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/shared/admission.lua',
            'modules/vava_combat/shared/defense.lua',
            'modules/vava_combat/shared/weapons.lua',
            'modules/vava_combat/shared/guard.lua',
        })
        cfg = VavaCombat.config
        VavaCombat.resource = 'vava_combat'
        VavaCombat.log = {
            warn = function(fmt, ...) logs.warn[#logs.warn + 1] = fmt:format(...) end,
            info = function(fmt, ...) logs.info[#logs.info + 1] = fmt:format(...) end,
        }
        local function position(src)
            local p = positions[src]
            if not p then return nil end
            return p[1], p[2], p[3]
        end
        local bridge = {
            CONSOLE = 0, INVENTORY = 'vava_inventory', HEALTH = 'vava_health', CRAFTING = 'vava_crafting',
            SKILLS = 'vava_skills',
            ActiveCharacterId = function(src) return active[src] end,
            ActivePlayers = function() return { A, B, C } end,
            Position = position,
            Heading = function(src) return positions[src] and headings[src] or nil end,
            Bucket = function(src) return buckets[src] or 0 end,
            SameBucket = function(a, b) return (buckets[a] or 0) == (buckets[b] or 0) end,
            IsDowned = function(src) return downed[src] == true end,
            InVehicle = function(src) return vehicles[src] == true end,
            MagicHardControl = function(src) return magic[src] end,
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
            SendNear = function(bucket, coords, radius, event, ...)
                assert.equal('integer', math.type(bucket))
                assert.is_true(bucket >= 0)
                sent[#sent + 1] = { bucket = bucket, coords = copy(coords), radius = radius, event = event, args = { ... } }
                return true
            end,
            Notify = function(target, text, kind)
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                notifies[#notifies + 1] = { target = target, text = text, kind = kind }
            end,
            Held = function(src) return held[src] end,
            Items = function(src, item)
                local out = {}
                for _, entry in ipairs(piles[src] or {}) do
                    if entry.item == item then out[#out + 1] = entry end
                end
                return out
            end,
            PatchMetadata = function(src, id, patch)
                patches[#patches + 1] = { src = src, id = id, patch = copy(patch), inChain = inChain }
                return true
            end,
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
            -- vocabulaire de vava_health (types du pas de côté recoupés, T-113)
            HealthKinds = function() return { 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur', 'privation', 'monde' } end,
            HealthTags = function() return { 'melee', 'ranged', 'spell', 'area', 'overTime', 'native', 'reflected',
                'parryable', 'unblockable', 'undodgeable' } end,
            DefineShieldField = function() return true end,
            Hit = chainHit,
            DeclareModifiers = function(list)
                if not registryExists then return 0 end
                local count = 0
                for _, entry in ipairs(list) do
                    if not registry[entry.key] then
                        registry[entry.key] = entry.def
                        count = count + 1
                    end
                end
                return count
            end,
            OnHitAfter = function(fn)
                hitAfter = fn
                return true
            end,
            RunBefore = function(name, payload)
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end,
            RunAfter = function(name, payload) afters[#afters + 1] = { name = name, payload = copy(payload) } end,
            SetShieldField = function() end,
            ShieldField = function() return nil end,
            Timer = function() return clock end,
        }
        for _, name in ipairs(COUNTED) do
            local fn = bridge[name]
            bridge[name] = function(...)
                calls[name] = (calls[name] or 0) + 1
                return fn(...)
            end
        end
        VavaCombat.bridge = bridge
        helper.loadAll({
            'modules/vava_combat/server/catalog.lua',
            'modules/vava_combat/server/pedstate.lua',
            'modules/vava_combat/server/wear.lua',
            'modules/vava_combat/server/shields.lua',
            'modules/vava_combat/server/strike.lua',
            'modules/vava_combat/server/hands.lua',
            'modules/vava_combat/server/reactions.lua',
            'modules/vava_combat/server/defense.lua',
            'modules/vava_combat/server/swings.lua',
            'modules/vava_combat/server/api.lua',
        })
        swings, defense, reactions, hands = VavaCombat.swings, VavaCombat.defense, VavaCombat.reactions, VavaCombat.hands
        VavaCombat.shields.hungOf = function(src) return hung[src] end
        local ok, err = VavaCombat.catalog.setup()
        assert.is_true(ok, err)
        assert.equal(0, #logs.warn, logs.warn[1])
        VavaCombat.ready = true
        assert.equal(3, defense.declare())
        bridge.OnHitAfter(defense.onHitAfter)
        arm(A, 10, 'epee_courte')
        arm(B, 20, 'epee_courte')
        calls = {}
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        math.random = realRandom
        VavaCombat = nil
    end)

    describe('parade', function()
        it('Taille dans la fenêtre : annulée à l\'étape parade, A chancelle, un seul envoi parry, usures, hook', function()
            at(800)
            assert.same({ true }, use(A, 'taille_descendante', B))      -- relevé à 1 120
            at(1000)
            assert.same({ true }, use(B, 'parade_epee'))                  -- fenêtre 1 000 à 1 200
            at(1120)
            assert.equal(1, #hits)
            assert.same({ 'parade', 'parade', 0 }, { lastHit().cancelled, lastHit().stage, lastHit().applied })
            assert.equal('parried', swings.of(A).cancelled)
            assert.same({ false, 'staggered', 890 }, (function() at(1130) return use(A, 'taille_descendante', B) end)())
            assert.same({ 'parry' }, outcomes())
            assert.same({ A, B, 'parry' }, sent[1].args)
            -- arme de A usée par strike (dans la chaîne), arme de B hors de la chaîne (SetTimeout 0)
            assert.equal(1, #patched(A, 10))
            local parryWear = patched(B, 20)
            assert.equal(1, #parryWear)
            assert.is_false(parryWear[1].inChain)
            assert.equal(1, #afters)
            assert.same({ name = 'vava_combat:defended', payload = { source = B, characterId = CHAR_B, outcome = 'parry',
                technique = 'parade_epee', attacker = A, attackerTechnique = 'taille_descendante', hitId = 1 } }, afters[1])
            assert.same({ 0, 0 }, { defense.memoSize() })
        end)

        it('Taille relevée à 1 201 : touchée, parade ratée (600 ms sans parade)', function()
            at(881)
            use(A, 'taille_descendante', B)          -- relevé à 1 201
            at(1000)
            use(B, 'parade_epee')
            at(1201)
            assert.equal(12, lastHit().applied)
            assert.same({ 'hit' }, outcomes())
            at(1500)
            assert.same({ false, 'parry_cooldown', 300 }, use(B, 'parade_epee'))
        end)

        it('parade ratée à 0 : refusée à 700 (attente 100), admise à 800 ; réussie : la suivante à endAt − 60', function()
            assert.same({ true }, use(B, 'parade_epee'))
            at(700)
            assert.same({ false, 'parry_cooldown', 100 }, use(B, 'parade_epee'))
            at(800)
            assert.same({ true }, use(B, 'parade_epee'))
            -- réussie (la parade de 800 a raté : plus de délai à 1 600)
            at(2080)
            use(A, 'taille_descendante', B)          -- relevé à 2 400
            at(2200)
            assert.same({ true }, use(B, 'parade_epee'))
            at(2400)
            assert.equal('parade', lastHit().cancelled)
            at(2589)
            assert.same({ false, 'busy', 1 }, use(B, 'parade_epee'))
            at(2590)
            assert.same({ true }, use(B, 'parade_epee'))
        end)

        it('Fendant (non parable) dans la fenêtre : porté, B chancelle', function()
            at(400)
            use(A, 'fendant', B)                       -- relevé à 1 050
            at(1000)
            use(B, 'parade_epee')
            at(1050)
            assert.equal(21.6, lastHit().applied)
            assert.same({ 'stagger' }, outcomes())
            assert.is_not_nil(reactions.staggeredLeft(B, clock))
        end)

        it('attaquant derrière B, ou coup sans parryable : porté', function()
            headings[B] = 0
            use(A, 'taille_descendante', B)
            at(100)
            use(B, 'parade_epee')
            at(320)
            assert.equal(12, lastHit().applied)
            headings[B] = 180
            at(1000)
            use(B, 'parade_epee')
            local result = VavaCombat.bridge.Hit(B, { amount = 10, kind = 'tranchant', source = A, tags = { melee = true } })
            assert.equal(10, result.applied)
        end)

        it('attaquant immunisé (chancelé 1 s avant) puis paré : chancelle quand même, immunité renouvelée', function()
            reactions.stagger(A, 900, clock)            -- immunisé jusqu'à 3 900
            at(1000)
            use(B, 'parade_epee')
            at(1000)
            local prevA = swings.of(A)
            assert.is_nil(prevA)
            VavaCombat.strike.run(A, B, { technique = 'taille_descendante', tags = { parryable = true } },
                { held = held[A], characterId = CHAR_A })
            assert.equal('parade', lastHit().cancelled)
            assert.equal(900, reactions.staggeredLeft(A, clock))
            -- immunité renouvelée : 1 000 + 900 + 3 000
            assert.is_false(reactions.stagger(A, 900, T0 + 4899))
            assert.is_true(reactions.stagger(A, 900, T0 + 4900))
        end)

        it('contrôle dur de la magie pendant la fenêtre (relecture S-1 de T-149) : rien n\'est paré', function()
            at(800)
            use(A, 'taille_descendante', B)
            at(1000)
            use(B, 'parade_epee')
            magic[B] = 'frozen'
            at(1120)
            assert.equal(12, lastHit().applied)
        end)
    end)

    describe('pas de côté', function()
        it('invulnérable de 1 050 à 1 300 : esquivé sans envoi ni usure, touché à 1 301 ; 1,5 s entre deux', function()
            at(780)
            use(A, 'taille_descendante', B)           -- relevé à 1 100
            at(1000)
            assert.same({ true }, use(B, 'pas_de_cote'))
            at(1100)
            assert.same({ 'esquive', 'esquive' }, { lastHit().cancelled, lastHit().stage })
            assert.equal(0, #sent)
            assert.equal(0, #patched(A, 10))
            assert.equal(0, #patched(B, 20))
            assert.same('dodge', afters[1].payload.outcome)
            at(1700)
            use(A, 'taille_descendante', B)
            at(2020)
            assert.equal(12, lastHit().applied)
            at(2499)
            assert.same({ false, 'dodge_cooldown', 1 }, use(B, 'pas_de_cote'))
            at(2500)
            assert.same({ true }, use(B, 'pas_de_cote'))
        end)

        it('zone et effet qui dure : appliqués ; projectile de sort : évité ; fin de fenêtre : touché', function()
            use(B, 'pas_de_cote')
            at(100)
            local bridge = VavaCombat.bridge
            assert.equal(10, bridge.Hit(B, { amount = 10, kind = 'feu', source = A, tags = { spell = true, area = true } })
                .applied)
            assert.equal(10, bridge.Hit(B, { amount = 10, kind = 'feu', tags = { overTime = true } }).applied)
            assert.equal('esquive', bridge.Hit(B, { amount = 10, kind = 'feu', source = A,
                tags = { spell = true, ranged = true } }).cancelled)
            at(301)
            assert.equal(10, bridge.Hit(B, { amount = 10, kind = 'feu', source = A,
                tags = { spell = true, ranged = true } }).applied)
        end)
    end)

    describe('garde', function()
        local function raise(ms)
            at(ms)
            assert.same({ true }, use(B, 'garde_epee'))
        end

        it('de face : 4,8 bloqués, 7,2 appliqués, issue block ; arme de B usée hors de la chaîne', function()
            at(800)
            use(A, 'taille_descendante', B)             -- relevé à 1 120
            raise(1000)                                  -- effective à 1 100
            at(1120)
            assert.same({ 4.8, 7.2 }, { lastHit().blocked, tenth(lastHit().applied) })
            assert.same({ 'block' }, outcomes())
            local guardWear = patched(B, 20)
            assert.equal(1, #guardWear)
            assert.is_false(guardWear[1].inChain)
            assert.equal('block', afters[1].payload.outcome)
            assert.is_true(defense.open(swings.of(B), clock))
        end)

        it('pas encore effective (avant openAt) : rien de bloqué', function()
            at(730)
            use(A, 'taille_descendante', B)             -- relevé à 1 050
            raise(1000)
            at(1050)
            assert.equal(12, lastHit().applied)
        end)

        it('de dos : 12 appliqués, issue hit, garde toujours levée', function()
            headings[B] = 0
            raise(0)
            at(800)
            use(A, 'taille_descendante', B)
            at(1120)
            assert.same({ 12, 0 }, { lastHit().applied, lastHit().blocked })
            assert.same({ 'hit' }, outcomes())
            assert.is_true(defense.open(swings.of(B), clock))
        end)

        it('bouclier au bras : 8,4 bloqués, bouclier usé (pas l\'épée) ; décroché pendant la garde : 4,8', function()
            piles[B][#piles[B] + 1] = pile(SHIELD_ID, 'bouclier_rond')
            hung[B] = { instanceId = SHIELD_ID, item = 'bouclier_rond', characterId = CHAR_B }
            raise(0)
            assert.equal(160, swings.of(B).guard.arc)
            use(A, 'taille_descendante', B)
            at(320)
            assert.same({ 8.4, 3.6 }, { lastHit().blocked, tenth(lastHit().applied) })
            at(330)
            assert.equal(1, #patched(B, SHIELD_ID))
            assert.equal(0, #patched(B, 20))
            hung[B] = nil
            at(900)
            use(A, 'taille_descendante', B)
            at(1220)
            assert.equal(4.8, lastHit().blocked)
            assert.equal(1, #patched(B, 20))
        end)

        it('quatrième coup bloqué : garde brisée, B chancelle 1 200 ms, ni garde ni parade avant', function()
            raise(0)
            for k = 0, 3 do
                at(k * 900)
                assert.same({ true }, use(A, 'taille_descendante', B))
                at(k * 900 + 320)
            end
            assert.same({ 'block', 'block', 'block', 'break' }, outcomes())
            assert.equal('broken', swings.of(B).cancelled)
            assert.is_false(defense.open(swings.of(B), clock))
            assert.equal(1200, reactions.staggeredLeft(B, clock))
            assert.equal('break', afters[4].payload.outcome)
            at(3020 + 1199)
            -- le chancellement passe en premier (même durée) ; oublié, la garde brisée reste
            assert.same({ false, 'staggered', 1 }, use(B, 'garde_epee'))
            reactions.onDowned(B)
            assert.same({ false, 'guard_broken', 1 }, use(B, 'garde_epee'))
            assert.same({ false, 'guard_broken', 1 }, use(B, 'parade_epee'))
            assert.same({ true }, use(B, 'pas_de_cote'))
            swings.forget(B)
            at(3020 + 1200)
            assert.same({ true }, use(B, 'garde_epee'))
        end)

        it('deux Fendants bloqués : le premier sans chancellement (block), le second brise la garde', function()
            raise(0)
            use(A, 'fendant', B)
            at(650)
            assert.same({ 8.6, 13.0 }, { lastHit().blocked, tenth(lastHit().applied) })
            assert.same({ 'block' }, outcomes())
            assert.is_nil(reactions.staggeredLeft(B, clock))
            at(1550)
            use(A, 'fendant', B)
            at(2200)
            assert.same({ 'block', 'break' }, outcomes())
        end)

        it('coup bloqué qui met B à terre : issue down, compteur inchangé', function()
            raise(0)
            for k = 0, 2 do
                at(k * 900)
                use(A, 'taille_descendante', B)
                at(k * 900 + 320)
            end
            downOnHit[B] = true
            at(2700)
            use(A, 'taille_descendante', B)
            at(3020)
            assert.same({ 'block', 'block', 'block', 'down' }, outcomes())
            assert.is_nil(defense.brokenLeft(B, clock))
            downOnHit[B] = nil
            at(3600)
            use(A, 'taille_descendante', B)
            at(3920)
            assert.equal('break', outcomes()[5])
        end)

        it('defense.spend remplaçable : une doublure qui brise dès le premier coup → break', function()
            defense.spend = function() return true, true end
            raise(0)
            use(A, 'taille_descendante', B)
            at(320)
            assert.same({ 'break' }, outcomes())
        end)
    end)

    describe('abaisser', function()
        it('sans garde : no_guard ; levée à 1 000, abaissée à 1 050 → fermée à 1 300, attaque à 1 490 pas à 1 489', function()
            assert.same({ false, 'no_guard' }, { defense.lowerRpc(B) })
            at(1000)
            use(B, 'garde_epee')
            at(1050)
            assert.same({ true }, { defense.lowerRpc(B) })
            assert.same({ 1300, 1550 }, { swings.of(B).closeAt - T0, swings.of(B).endAt - T0 })
            assert.same({ false, 'no_guard' }, { defense.lowerRpc(B) })
            at(1489)
            assert.same({ false, 'busy', 1 }, use(B, 'taille_descendante', A))
            at(1490)
            assert.same({ true }, use(B, 'taille_descendante', A))
        end)

        it('attaque demandée garde levée : guarding, sans attente', function()
            use(B, 'garde_epee')
            at(5000)
            assert.same({ false, 'guarding' }, use(B, 'taille_descendante', A))
            assert.same({ false, 'guarding' }, use(B, 'parade_epee'))
        end)

        it('module pas prêt : not_ready', function()
            VavaCombat.ready = false
            assert.same({ false, 'not_ready' }, { defense.lowerRpc(B) })
        end)
    end)

    describe('annulations', function()
        it('main changée (hook hold) pendant la garde : fermée, cycle compté ; la Taille suivante porte', function()
            use(B, 'garde_epee')
            at(150)
            hands.onHold({ source = B, instanceId = 0, previous = 20 })
            assert.equal('hands', swings.of(B).cancelled)
            assert.same({ 300, 550 }, { swings.of(B).closeAt - T0, swings.of(B).endAt - T0 })
            use(A, 'taille_descendante', B)
            at(470)
            assert.equal(12, lastHit().applied)
        end)

        it('mis à terre : garde fermée, plus rien de bloqué', function()
            use(B, 'garde_epee')
            at(200)
            swings.onDowned(B)
            defense.onDowned(B)
            assert.is_nil(defense.activeOf(B))
            use(A, 'taille_descendante', B)
            at(520)
            assert.equal(12, lastHit().applied)
        end)

        it('en véhicule : les modificateurs ne bloquent rien', function()
            use(B, 'garde_epee')
            vehicles[B] = true
            at(200)
            assert.equal(12, VavaCombat.bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A,
                tags = { melee = true } }).applied)
        end)

        it('Fendant de dos pendant la garde : B chancelle, garde fermée', function()
            headings[B] = 0
            use(B, 'garde_epee')
            use(A, 'fendant', B)
            at(650)
            assert.same({ 'stagger' }, outcomes())
            assert.equal('stagger', swings.of(B).cancelled)
            assert.is_false(defense.open(swings.of(B), clock))
        end)

        it('personnage changé : la garde ne protège plus', function()
            use(B, 'garde_epee')
            at(200)
            active[B] = 201
            assert.equal(12, VavaCombat.bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A,
                tags = { melee = true } }).applied)
        end)

        it('départ : tout est oublié', function()
            use(B, 'pas_de_cote')
            defense.forget(B)
            swings.forget(B)
            assert.is_nil(defense.activeOf(B))
            assert.same({ true }, use(B, 'pas_de_cote'))
        end)
    end)

    describe('réservation (crochet using qui cède la main)', function()
        local paused
        before_each(function()
            paused = true
            VavaCombat.bridge.RunBefore = function(name, payload)
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                if paused then coroutine.yield('paused') end
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end
        end)

        local function request(src, id)
            local co = coroutine.create(function() return swings.use(src, id, 0) end)
            local out = { coroutine.resume(co) }
            assert.is_true(table.remove(out, 1), tostring(out[1]))
            if coroutine.status(co) == 'dead' then return co, out end
            return co, nil
        end

        local function finish(co)
            local out = { coroutine.resume(co) }
            assert.is_true(table.remove(out, 1), tostring(out[1]))
            return out
        end

        it('défense réservée : invisible aux modificateurs ; refusée : rien d\'ouvert', function()
            local co = request(B, 'parade_epee')
            assert.is_true(swings.of(B).pending)
            assert.equal(12, VavaCombat.bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A,
                tags = { melee = true, parryable = true } }).applied)
            beforeAnswer = { false, 'Ligoté.' }
            assert.same({ false, 'refused', 'Ligoté.' }, finish(co))
            assert.is_nil(defense.activeOf(B))
        end)

        it('garde réservée, lower pendant l\'attente : true, garde fermée dès l\'acceptation', function()
            local co = request(B, 'garde_epee')
            at(20)
            assert.same({ true }, { defense.lowerRpc(B) })
            assert.same({ true }, finish(co))
            local guard = swings.of(B)
            assert.same({ 300, 550 }, { guard.closeAt - T0, guard.endAt - T0 })
        end)

        it('contrôle dur posé pendant le crochet (relecture S-1 de T-149) : refusé', function()
            local co = request(B, 'pas_de_cote')
            magic[B] = 'knockdown'
            assert.same({ false, 'controlled' }, finish(co))
            assert.is_nil(defense.activeOf(B))
        end)
    end)

    describe('fenêtres', function()
        it('une attaque acceptée ferme une parade encore ouverte (chaîne admise 60 ms avant closeAt)', function()
            cfg.techniques.parade_epee.chain = { 'garde_epee', 'taille_descendante' }
            at(830)
            use(A, 'taille_descendante', B)             -- relevé à 1 150
            at(1000)
            use(B, 'parade_epee')
            at(1140)
            assert.same({ true }, use(B, 'taille_descendante', A))
            assert.is_nil(defense.activeOf(B))
            at(1150)
            assert.equal(12, hits[1].result.applied)
        end)

        it('parade puis garde enchaînée : la garde remplace la parade', function()
            use(B, 'parade_epee')
            at(140)
            assert.same({ true }, use(B, 'garde_epee'))
            assert.equal('garde_epee', defense.activeOf(B).id)
            assert.equal(1, swings.of(B).chainCount)
        end)
    end)

    describe('modificateurs', function()
        it('déclarés une fois (étapes, priorité, types) ; registre absent : rien', function()
            assert.same({ 'esquive', 50 }, { registry[KEYS.esquive].stage, registry[KEYS.esquive].priority })
            -- relecture réseau R-2 : ni la faim (privation) ni les pertes du monde n'appellent le pas de côté
            assert.same({ 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur' },
                registry[KEYS.esquive].kinds)
            assert.same({ 'tranchant', 'contondant', 'percant' }, registry[KEYS.parade].kinds)
            assert.equal('Garde', registry[KEYS.blocage].label)
            assert.equal(0, defense.declare())
            registry, registryExists = {}, false
            assert.equal(0, defense.declare())
            registryExists = true
            assert.equal(3, defense.declare())
        end)

        -- relecture réseau R-3 : tests en mémoire et de face avant les exports (véhicule, magie)
        it('attaquant de dos : ni véhicule ni contrôle de la magie lus', function()
            headings[B] = 0
            use(B, 'garde_epee')
            at(200)
            calls = {}
            VavaCombat.bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A, tags = { melee = true } })
            assert.is_nil(calls.InVehicle)
            assert.is_nil(calls.MagicHardControl)
        end)

        it('personne ne se défend : aucun appel de native ni d\'export dans les modificateurs', function()
            calls = {}
            VavaCombat.bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A, tags = { melee = true, parryable = true } })
            assert.equal(0, nativeCalls())
        end)

        it('mémoire pleine : aucune défense, une ligne de console ; décision sans suite purgée après memoMs', function()
            cfg.defense.memoMax = 8
            use(B, 'pas_de_cote')
            at(100)
            local apply = registry[KEYS.esquive].apply
            local function ctx(id)
                return { id = id, target = B, targetCharacter = CHAR_B, kind = 'tranchant', amount = 5, source = A,
                    tags = { melee = true } }
            end
            for id = 1, 8 do assert.same({ cancel = 'esquive' }, apply(ctx(1000 + id))) end
            assert.is_nil(apply(ctx(2000)))
            assert.is_nil(apply(ctx(2001)))
            assert.equal(1, #logs.warn)
            assert.matches('décisions en attente', logs.warn[1])
            -- décisions sans suite (coups tombés en erreur) : oubliées après memoMs
            use(B, 'pas_de_cote')
            at(1100)
            assert.same({ false, 'dodge_cooldown', 400 }, use(B, 'pas_de_cote'))
            at(1500)
            use(B, 'pas_de_cote')
            at(1600)
            assert.same({ cancel = 'esquive' }, apply(ctx(3000)))
            assert.same({ 1, 0 }, { defense.memoSize() })
        end)

        it('suite d\'un coup d\'une autre ressource : suites serveur, aucune issue imposée gardée', function()
            use(B, 'garde_epee')
            at(200)
            local bridge = VavaCombat.bridge
            local realHit = bridge.Hit
            -- coup venu d'une autre ressource (export strike de l'exemple, /frapper)
            bridge.Hit = function(target, packet)
                local saved = hitAfter
                hitAfter = function(payload)
                    payload.origin = 'vava_example_combat'
                    saved(payload)
                end
                local result = realHit(target, packet)
                hitAfter = saved
                return result
            end
            local result = bridge.Hit(B, { amount = 12, kind = 'tranchant', source = A, tags = { melee = true } })
            assert.equal(4.8, result.blocked)
            assert.equal('block', afters[1].payload.outcome)
            assert.same({ 0, 0 }, { defense.memoSize() })
            assert.equal(0, #sent)
        end)
    end)

    -- relecture sécurité S-1 : l'arc du bouclier ne vaut que s'il est encore accroché
    describe('arc de la garde', function()
        local function at75()
            local r = math.rad(75)
            -- B à (0, 2) tourné vers le sud (cap 180) : A à 75° de son avant, à 2 m
            positions[A] = { math.sin(r) * 2, 2 - math.cos(r) * 2, 0 }
        end

        it('bouclier au bras : un coup à 75° du cap est bloqué ; décroché : arc de l\'arme, il porte', function()
            piles[B][#piles[B] + 1] = pile(SHIELD_ID, 'bouclier_rond')
            hung[B] = { instanceId = SHIELD_ID, item = 'bouclier_rond', characterId = CHAR_B }
            use(B, 'garde_epee')
            at(200)
            at75()
            local bridge = VavaCombat.bridge
            local packet = { amount = 12, kind = 'tranchant', source = A, tags = { melee = true } }
            assert.equal(8.4, bridge.Hit(B, copy(packet)).blocked)
            hung[B] = nil
            local result = bridge.Hit(B, copy(packet))
            assert.same({ 0, 12 }, { result.blocked, result.applied })
        end)
    end)

    -- relecture sécurité S-2 : une issue ou une décision laissée en mémoire ne vaut que pour son coup
    describe('mémoire des issues', function()
        it('issue laissée par strike, numéro repris (vava_health redémarré) sur une autre cible : ignorée', function()
            use(B, 'garde_epee')
            at(200)
            -- coup de l'export strike : l'issue imposée n'est jamais consommée par reactions.after
            VavaCombat.strike.run(A, B, { technique = 'taille_descendante' }, { held = held[A], characterId = CHAR_A })
            assert.equal(4.8, lastHit().blocked)
            assert.same({ 0, 1 }, { defense.memoSize() })
            -- vava_health redémarre : ses numéros repartent de 1 ; un coup de A sur C reprend le numéro 1
            hitSeq = 0
            positions[C] = { 0.3, 1.2, 0 }
            positions[B] = { 30, 30, 0 }
            at(1000)
            use(A, 'taille_descendante', C)
            at(1320)
            assert.equal(1, lastHit().id)
            assert.same({ 'hit' }, outcomes())
            assert.same({ 0, 0 }, { defense.memoSize() })
        end)

        it('issue trop vieille sur la même cible : ignorée ; resetMemo vide tout', function()
            use(B, 'garde_epee')
            at(200)
            VavaCombat.strike.run(A, B, { technique = 'taille_descendante' }, { held = held[A], characterId = CHAR_A })
            assert.equal('block', defense.takeOutcome(1, B))
            VavaCombat.strike.run(A, B, { technique = 'taille_descendante' }, { held = held[A], characterId = CHAR_A })
            at(200 + cfg.defense.memoMs)
            assert.is_nil(defense.takeOutcome(2, B))
            VavaCombat.strike.run(A, B, { technique = 'taille_descendante' }, { held = held[A], characterId = CHAR_A })
            assert.same({ 0, 1 }, { defense.memoSize() })
            defense.resetMemo()
            assert.same({ 0, 0 }, { defense.memoSize() })
            assert.is_nil(defense.takeOutcome(3, B))
        end)

        it('décision reprise par un coup d\'une autre cible : aucune suite', function()
            use(B, 'pas_de_cote')
            at(100)
            local apply = registry[KEYS.esquive].apply
            assert.same({ cancel = 'esquive' }, apply({ id = 7, target = B, targetCharacter = CHAR_B, kind = 'tranchant',
                amount = 5, source = A, tags = { melee = true } }))
            hitAfter({ id = 7, target = C, origin = 'vava_combat', stage = 'esquive', cancelled = 'esquive' })
            assert.equal(0, #afters)
            assert.same({ 0, 0 }, { defense.memoSize() })
        end)
    end)

    -- relecture sécurité S-3 : un coup paré ne frappe plus un autre adversaire dans le même relevé
    describe('plusieurs adversaires par coup', function()
        it('maxTargets 2 : B pare, C dans l\'arc n\'est pas touché', function()
            cfg.geometry.maxTargets = 2
            positions[C] = { 0.3, 1.8, 0 }
            use(A, 'taille_descendante', B)             -- relevé à 320
            at(200)
            assert.same({ true }, use(B, 'parade_epee'))  -- fenêtre 200 à 400
            at(320)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            assert.equal('parade', hits[1].result.cancelled)
        end)
    end)

    describe('réseau', function()
        it('un coup défendu = un envoi au plus, toujours dans l\'instance de l\'attaquant', function()
            buckets[A], buckets[B] = 4, 4
            use(B, 'garde_epee')
            use(A, 'taille_descendante', B)
            at(320)
            assert.equal(1, #sent)
            assert.equal(4, sent[1].bucket)
            assert.same({ x = 0, y = 2, z = 0 }, sent[1].coords)
            at(900)
            use(A, 'taille_descendante', B)
            at(901)
            use(B, 'pas_de_cote')                       -- garde levée : guarding
            assert.equal(1, #sent)
        end)
    end)
end)

describe('vava_combat défense : démarrage (server/main.lua)', function()
    it('modificateurs déclarés au setup, redéclarés au retour de vava_health ; RPC lower borné', function()
        helper.reset()
        VavaCombat = nil
        local hooks, rpcs, setup, registry = {}, {}, nil, {}
        local registryExists = true
        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/heading.lua',
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/shared/admission.lua',
            'modules/vava_combat/shared/defense.lua',
            'modules/vava_combat/shared/weapons.lua',
            'modules/vava_combat/shared/guard.lua',
        })
        local log = { warn = function() end, info = function() end, error = function() end }
        VavaCombat.resource, VavaCombat.log = 'vava_combat', log
        VavaCombat.core = {
            log = log,
            registry = { exists = function() return false end },
            hooks = { after = function(name, fn) hooks[name] = fn return 1 end },
            modules = { register = function(def) setup = def.setup return true end },
        }
        _G.GetResourceMetadata = function() return '1.3.0' end
        _G.AddEventHandler = function() end
        _G.RegisterCommand = function() end
        _G.exports = setmetatable({}, { __call = function() end })
        local held = {}
        VavaCombat.bridge = setmetatable({
            HEALTH = 'vava_health', INVENTORY = 'vava_inventory', CRAFTING = 'vava_crafting', SKILLS = 'vava_skills',
            ItemsReady = function() return false end,
            HealthKinds = function() return nil end,
            HealthTags = function() return nil end,
            DefineShieldField = function() return true end,
            RecipesReady = function() return false end,
            SkillRecipesReady = function() return false end,
            OnHold = function() return true end,
            OnDowned = function() return true end,
            OnHitAfter = function(fn) hooks['vava_health:hit'] = fn return true end,
            RegisterRpc = function(name, options, fn) rpcs[name] = { options = options, fn = fn } return true end,
            ActivePlayers = function() return {} end,
            Held = function(src) return held[src] end,
            DeclareModifiers = function(list)
                if not registryExists then return 0 end
                local count = 0
                for _, entry in ipairs(list) do
                    if not registry[entry.key] then
                        registry[entry.key] = entry.def
                        count = count + 1
                    end
                end
                return count
            end,
        }, { __index = function(_, name) return function() return nil end end })
        helper.loadAll({
            'modules/vava_combat/server/catalog.lua',
            'modules/vava_combat/server/pedstate.lua',
            'modules/vava_combat/server/wear.lua',
            'modules/vava_combat/server/shields.lua',
            'modules/vava_combat/server/strike.lua',
            'modules/vava_combat/server/hands.lua',
            'modules/vava_combat/server/reactions.lua',
            'modules/vava_combat/server/defense.lua',
            'modules/vava_combat/server/swings.lua',
            'modules/vava_combat/server/api.lua',
            'modules/vava_combat/server/commands.lua',
        })
        VavaCombat.pedState.start = function() return true end
        helper.load('modules/vava_combat/server/main.lua')
        local ok, err = setup()
        assert.is_true(ok, err)
        assert.same({ 'vava_combat:blocage', 'vava_combat:esquive', 'vava_combat:parade' },
            (function()
                local keys = {}
                for key in pairs(registry) do keys[#keys + 1] = key end
                table.sort(keys)
                return keys
            end)())
        assert.same({ args = {}, rateLimit = { capacity = 4, refillPerSecond = 3 } }, rpcs['vava_combat:lower'].options)
        assert.equal(VavaCombat.defense.lowerRpc, rpcs['vava_combat:lower'].fn)
        assert.equal(VavaCombat.defense.onHitAfter, hooks['vava_health:hit'])
        -- vava_health redémarre : son registre est neuf
        registry = {}
        hooks['core:module:ready']({ name = 'vava_health' })
        assert.is_not_nil(registry['vava_combat:parade'])
        for _, name in ipairs({ 'GetResourceMetadata', 'AddEventHandler', 'RegisterCommand', 'exports' }) do
            _G[name] = nil
        end
        VavaCombat = nil
    end)
end)
