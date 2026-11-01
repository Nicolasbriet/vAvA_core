local helper = require('tests.helper')

-- Endurance (modules/vava_combat, T-114) : règles pures de shared/endurance.lua (servi à tous) et shared/stamina.lua
-- (serveur seul), puis le serveur réel (swings, defense, stamina, reactions, strike, hands, wear, catalog, commands)
-- avec les doublures de combat_defense_spec : CHAÎNE D'ESSAI (modificateurs déclarés appelés dans l'ordre des étapes,
-- puis hook after), horloge et minuteries à la main, compte des lectures de vava_needs:get, des envois au seul porteur
-- (bridge.Send) et des envois de proximité. Règles documentées : docs/plan/specs/T-114.md § 7 et § 11.1. Le bridge réel
-- (NeedsValues : erreur, export absent) est essayé à la fin.

local A, B, C = 1, 2, 3
local CHAR_A, CHAR_B, CHAR_C = 100, 200, 300
local T0 = 100000
local SHIELD_ID = 50
local KEYS = { esquive = 'vava_combat:esquive', parade = 'vava_combat:parade', blocage = 'vava_combat:blocage' }
local STAGES = { 'esquive', 'parade', 'blocage' }

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
        'modules/vava_combat/shared/endurance.lua',
        'modules/vava_combat/shared/stamina.lua',
    })
    return VavaCombat.endurance, VavaCombat.stamina, VavaCombat.config
end

describe('vava_combat endurance : règles pures (shared/endurance.lua)', function()
    local endurance

    before_each(function() endurance = loadPure() end)
    after_each(function() VavaCombat = nil end)

    it('level : recharge après la reprise, plafonnée ; absent ou illisible : plein, jamais une erreur', function()
        local g = { value = 500, at = 0, restAt = 1000, rate = 200 }
        for _, now in ipairs({ 0, 999, 1000 }) do assert.equal(500, endurance.level(g, now), tostring(now)) end
        assert.equal(600, endurance.level(g, 1500))
        assert.equal(1000, endurance.level(g, 3500))
        assert.equal(1000, endurance.level(g, 60000))
        assert.equal('integer', math.type(endurance.level(g, 1234)))
        assert.equal(1000, endurance.level(nil, 0))
        assert.equal(1000, endurance.level({ value = 500, at = 0, restAt = 1000, rate = 0 / 0 }, 2000))
        assert.equal(1000, endurance.level({ value = 500, at = 0, restAt = 1000, rate = 200 }, 0 / 0))
        assert.equal(1000, endurance.level({ value = '500', at = 0, restAt = 0, rate = 200 }, 10))
        assert.equal(1000, endurance.level({ value = 500, at = 0, restAt = math.huge, rate = 200 }, 10))
        -- reprise avant `at` (rebase) : la recharge part de `at`
        assert.equal(700, endurance.level({ value = 600, at = 2000, restAt = 1000, rate = 100 }, 3000))
    end)

    it('read : trois entiers bornés, sinon nil', function()
        assert.same({ value = 1000, restIn = 0, rate = 200 }, endurance.read(1000, 0, 200))
        assert.same({ value = 0, restIn = 10000, rate = 0 }, endurance.read(0, 10000, 0))
        for _, bad in ipairs({ 1001, -1, 500.5, 500.0, '500' }) do assert.is_nil(endurance.read(bad, 0, 200), tostring(bad)) end
        assert.is_nil(endurance.read(500, 10001, 200))
        assert.is_nil(endurance.read(500, -1, 200))
        assert.is_nil(endurance.read(500, 0, 1001))
        assert.is_nil(endurance.read(500, 0, -1))
        assert.is_nil(endurance.read(nil, nil, nil))
        assert.is_nil(endurance.read(500, 0))
    end)

    it('fullAt : instant où elle est pleine ; pleine : maintenant ; sans pente : jamais', function()
        assert.equal(3500, endurance.fullAt({ value = 500, at = 0, restAt = 1000, rate = 200 }, 0))
        assert.equal(3500, endurance.fullAt({ value = 500, at = 0, restAt = 1000, rate = 200 }, 2000))
        assert.equal(7, endurance.fullAt(nil, 7))
        assert.equal(4000, endurance.fullAt({ value = 500, at = 0, restAt = 1000, rate = 200 }, 4000))
        assert.equal(math.huge, endurance.fullAt({ value = 500, at = 0, restAt = 1000, rate = 0 }, 0))
        -- arrondi par excès : à fullAt, le niveau est plein
        local g = { value = 1, at = 0, restAt = 0, rate = 150 }
        local at = endurance.fullAt(g, 0)
        assert.equal(1000, endurance.level(g, at))
        assert.is_true(endurance.level(g, at - 1) < 1000)
    end)
end)

describe('vava_combat endurance : règles pures (shared/stamina.lua)', function()
    local endurance, stamina, cfg

    before_each(function() endurance, stamina, cfg = loadPure() end)
    after_each(function() VavaCombat = nil end)

    local function full(now) return { value = 1000, at = now, restAt = now, rate = 200, factor = 1 } end

    it('needOf : stamina × 10 ; sans stamina : 0', function()
        local t = cfg.techniques
        assert.same({ 120, 250, 250, 60, 200 }, { stamina.needOf(t.taille_descendante), stamina.needOf(t.fendant),
            stamina.needOf(t.garde_epee), stamina.needOf(t.parade_epee), stamina.needOf(t.pas_de_cote) })
        assert.equal(0, stamina.needOf({}))
        assert.equal(0, stamina.needOf(nil))
        assert.equal(0, stamina.needOf({ stamina = 0 / 0 }))
        assert.equal(0, stamina.needOf({ stamina = -3 }))
    end)

    it('spend : 1 000 − 120 → 880, reprise 1 s après ; Taille, Estoc, Revers, Taille → 560 ; pas assez : rien ; 0 : rien',
        function()
        local g, ok = stamina.spend(nil, 120, 0, cfg)
        assert.same({ 880, 0, 1000, 200, true }, { g.value, g.at, g.restAt, g.rate, ok })
        g = full(0)
        for i, cost in ipairs({ 120, 90, 110, 120 }) do g = stamina.spend(g, cost, i * 300, cfg) end
        assert.equal(560, g.value)
        local low = { value = 100, at = 0, restAt = 1000, rate = 200, characterId = 7 }
        local same, refused = stamina.spend(low, 120, 500, cfg)
        assert.equal(low, same)
        assert.is_false(refused)
        assert.same({ value = 100, at = 0, restAt = 1000, rate = 200, characterId = 7 }, low)
        local kept, zero = stamina.spend(low, 0, 500, cfg)
        assert.equal(low, kept)
        assert.is_true(zero)
        -- les champs du porteur sont gardés
        assert.equal(7, stamina.spend(full(0), 60, 10, cfg).characterId or 7)
        local carried = stamina.spend({ value = 1000, at = 0, restAt = 0, rate = 150, factor = 0.75, characterId = 9 },
            60, 10, cfg)
        assert.same({ 940, 150, 0.75, 9 }, { carried.value, carried.rate, carried.factor, carried.characterId })
    end)

    it('blockCost : 25 (lourd × 2, bouclier × 0,67) → 250, 500, 168, 335', function()
        local garde = cfg.techniques.garde_epee
        assert.same({ 250, 500, 168, 335 }, { stamina.blockCost(garde, 1, false, cfg), stamina.blockCost(garde, 2, false, cfg),
            stamina.blockCost(garde, 1, true, cfg), stamina.blockCost(garde, 2, true, cfg) })
        assert.equal(250, stamina.blockCost(garde, 0 / 0, false, cfg))
        assert.equal(0, stamina.blockCost({}, 1, false, cfg))
    end)

    it('drain : épée 4 coups, bouclier 6, deux Fendants, bouclier trois Fendants, Fendant puis deux Tailles', function()
        local function count(costs, start)
            local g, broken = start, false
            for i, cost in ipairs(costs) do
                g, broken = stamina.drain(g, cost, i * 10, cfg)
                if broken then return i, g end
            end
            return nil, g
        end
        local n, g = count({ 250, 250, 250, 250, 250 })
        assert.same({ 4, 0 }, { n, g.value })
        assert.equal(250, select(2, count({ 250, 250, 250 })).value)
        n, g = count({ 168, 168, 168, 168, 168 })
        assert.same({ nil, 160 }, { n, g.value })
        assert.equal(6, (count({ 168, 168, 168, 168, 168, 168 })))
        assert.equal(2, (count({ 500, 500 })))
        assert.equal(3, (count({ 335, 335, 335 })))
        assert.equal(330, select(2, count({ 335, 335 })).value)
        assert.equal(3, (count({ 500, 250, 250 })))
        -- coût nul à 0 : rien ne cède, rien ne change
        local empty = { value = 0, at = 0, restAt = 1000, rate = 200 }
        local same, broken = stamina.drain(empty, 0, 10, cfg)
        assert.same({ empty, false }, { same, broken })
        -- coup bloqué à 0, puis un autre 1 500 ms plus tard : 750 → 850 (500 ms de recharge) → 600
        g = stamina.drain(full(0), 250, 0, cfg)
        assert.equal(750, g.value)
        assert.equal(850, endurance.level(g, 1500))
        g = stamina.drain(g, 250, 1500, cfg)
        assert.same({ 600, 2500 }, { g.value, g.restAt })
    end)

    it('waitFor : reprise puis remontée ; payable : nil ; sans pente : 30 000 ; plafond 30 000', function()
        local g = { value = 0, at = 0, restAt = 1000, rate = 200 }
        assert.equal(2250, stamina.waitFor(g, 250, 0))
        assert.equal(1050, stamina.waitFor(g, 250, 1200))
        assert.is_nil(stamina.waitFor(g, 250, 2250))
        assert.equal(1, stamina.waitFor(g, 250, 2249))
        assert.equal(3500, stamina.waitFor({ value = 0, at = 0, restAt = 1000, rate = 100 }, 250, 0))
        assert.equal(30000, stamina.waitFor({ value = 0, at = 0, restAt = 1000, rate = 0 }, 250, 0))
        assert.equal(30000, stamina.waitFor({ value = 0, at = 0, restAt = 1000, rate = 1 }, 250, 0))
        assert.is_nil(stamina.waitFor(nil, 400, 0))
        -- l'attente donnée suffit toujours (arrondi par excès)
        local slow = { value = 3, at = 0, restAt = 0, rate = 150 }
        for _, now in ipairs({ 0, 1, 7, 13 }) do
            local wait = stamina.waitFor(slow, 120, now)
            assert.is_true(endurance.level(slow, now + wait) >= 120, tostring(now))
        end
    end)

    it('needsFactor : le besoin le plus bas ; paliers 30 → 0,75 et 10 → 0,5 ; rien de lisible : 1', function()
        local tiers = cfg.endurance.needs
        assert.equal(1, stamina.needsFactor({ hunger = 80, thirst = 60 }, tiers))
        assert.equal(0.75, stamina.needsFactor({ hunger = 50, thirst = 25 }, tiers))
        assert.equal(0.5, stamina.needsFactor({ hunger = 8, thirst = 90 }, tiers))
        assert.equal(0.75, stamina.needsFactor({ hunger = 30, thirst = 90 }, tiers))
        assert.equal(0.5, stamina.needsFactor({ hunger = 90, thirst = 10 }, tiers))
        assert.equal(1, stamina.needsFactor({ hunger = 31, thirst = 11.5 + 20 }, tiers))
        assert.equal(1, stamina.needsFactor({}, tiers))
        assert.equal(1, stamina.needsFactor({ hunger = 'x' }, tiers))
        assert.equal(1, stamina.needsFactor({ hunger = 0 / 0 }, tiers))
        assert.equal(1, stamina.needsFactor({ hunger = 5 }, {}))
        assert.equal(1, stamina.needsFactor(nil, tiers))
        -- un besoin ajouté plus tard compte aussi
        assert.equal(0.5, stamina.needsFactor({ hunger = 90, thirst = 90, fatigue = 4 }, tiers))
    end)

    it('rateOf : 20 / s → 200, 150, 100 ; jamais sous 1', function()
        assert.same({ 200, 150, 100, 1 }, { stamina.rateOf(1, cfg), stamina.rateOf(0.75, cfg), stamina.rateOf(0.5, cfg),
            stamina.rateOf(0.001, cfg) })
        assert.equal(200, stamina.rateOf(0 / 0, cfg))
    end)

    it('rebase : la part déjà rechargée l\'a été à l\'ancienne pente ; reprise gardée', function()
        local g = { value = 400, at = 500, restAt = 1000, rate = 200, factor = 1, characterId = 4 }
        local r = stamina.rebase(g, 2000, 100, 0.5)
        assert.same({ 600, 2000, 1000, 100, 0.5, 4 }, { r.value, r.at, r.restAt, r.rate, r.factor, r.characterId })
        assert.equal(700, endurance.level(r, 3000))
        -- avant la reprise : rien de rechargé, la reprise attend toujours
        local early = stamina.rebase(g, 800, 100, 0.5)
        assert.same({ 400, 800 }, { early.value, endurance.level(early, 1000) == 400 and 800 or -1 })
        assert.equal(450, endurance.level(early, 1500))
    end)

    it('wireOf : trois entiers ; reprise bornée à 10 000 ; pleine : 0 ; absente : 1 000, 0, pente de base', function()
        assert.same({ 880, 1000, 200 }, { stamina.wireOf({ value = 880, at = 0, restAt = 1000, rate = 200 }, 0, 200) })
        assert.same({ 880, 10000, 200 }, { stamina.wireOf({ value = 880, at = 0, restAt = 50000, rate = 200 }, 0, 200) })
        assert.same({ 900, 0, 200 }, { stamina.wireOf({ value = 880, at = 0, restAt = 1000, rate = 200 }, 1100, 200) })
        assert.same({ 1000, 0, 150 }, { stamina.wireOf({ value = 880, at = 0, restAt = 1000, rate = 150 }, 60000, 200) })
        assert.same({ 1000, 0, 200 }, { stamina.wireOf(nil, 0, 200) })
        for _, v in ipairs({ stamina.wireOf({ value = 880, at = 0, restAt = 1000.0, rate = 200.0 }, 0, 200) }) do
            assert.equal('integer', math.type(v))
        end
    end)
end)

describe('vava_combat endurance (serveur)', function()
    local cfg, swings, defense, reactions, stamina, commands
    local clock, timers, active, positions, headings, buckets, downed, vehicles, held, piles, magic, hung
    local hits, sent, staminaSent, notifies, befores, beforeAnswer, afters, chats, logs
    local registry, hitAfter, hitSeq, downOnHit, needsCalls, needsAnswer, timersCreated
    local realRandom = math.random
    local STUBBED = { 'SetTimeout', 'GetGameTimer', 'exports', 'GetInvokingResource', 'Wait' }

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

    local function level(src) return stamina.inspect(src).value end

    --- Chaîne d'essai (comme combat_defense_spec) : modificateurs dans l'ordre des étapes, puis hook after.
    local function chainHit(target, packet)
        hitSeq = hitSeq + 1
        local ctx = { id = hitSeq, target = target, targetCharacter = active[target], origin = 'vava_combat',
            kind = packet.kind, amount = packet.amount, tags = copy(packet.tags or {}), source = packet.source,
            technique = packet.technique, weapon = packet.weapon }
        local amount, blocked, cancelled, stage = packet.amount, 0, nil, nil
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
                local result = entry.apply(view)
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
        local downedNow = not cancelled and downOnHit[target] == true
        local result = { id = hitSeq, amount = amount, applied = cancelled and 0 or amount, blocked = blocked,
            absorbed = 0, resisted = 0, added = 0, cancelled = cancelled, stage = stage, downed = downedNow,
            health = 0.5 }
        hits[#hits + 1] = { target = target, packet = copy(packet), result = copy(result) }
        local payload = copy(ctx)
        for key, value in pairs(result) do payload[key] = value end
        payload.stage = stage
        if hitAfter then hitAfter(payload) end
        return result
    end

    --- Issues reçues par `src` (vava_combat:hit, listes calculées par le serveur).
    local function outcomesFor(src)
        local out = {}
        for _, entry in ipairs(sent) do
            for _, id in ipairs(entry.list or {}) do
                if id == src then out[#out + 1] = entry.args[3] end
            end
        end
        return out
    end

    local function staminaTo(src)
        local out = {}
        for _, entry in ipairs(staminaSent) do
            if entry.target == src then out[#out + 1] = entry.args end
        end
        return out
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, timers, timersCreated = T0, {}, 0
        active = { [A] = CHAR_A, [B] = CHAR_B, [C] = CHAR_C }
        -- A au sud, tourné vers le nord ; B à 2 m au nord, tourné vers A ; C témoin à 5 m
        positions = { [A] = { 0, 0, 0 }, [B] = { 0, 2, 0 }, [C] = { 5, 0, 0 } }
        headings = { [A] = 0, [B] = 180, [C] = 0 }
        buckets, downed, vehicles, held, piles, magic, hung = {}, {}, {}, {}, { [A] = {}, [B] = {}, [C] = {} }, {}, {}
        hits, sent, staminaSent, notifies, befores, beforeAnswer, afters, chats = {}, {}, {}, {}, {}, nil, {}, {}
        logs = { warn = {}, info = {} }
        registry, hitAfter, hitSeq, downOnHit, needsCalls, needsAnswer = {}, nil, 0, {}, {}, nil

        _G.GetGameTimer = function() return clock end
        _G.SetTimeout = function(ms, fn)
            timersCreated = timersCreated + 1
            timers[#timers + 1] = { due = clock + ms, fn = fn }
        end
        _G.exports = setmetatable({}, { __call = function() end })
        _G.GetInvokingResource = function() return 'vava_example_combat' end
        _G.Wait = function() error('Wait appelé : rien ne doit attendre ici') end
        math.random = function() return 0.99 end

        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/heading.lua',
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/shared/endurance.lua',
            'modules/vava_combat/shared/admission.lua',
            'modules/vava_combat/shared/defense.lua',
            'modules/vava_combat/shared/stamina.lua',
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
        local function near(coords, radius, bucket, except)
            local out = {}
            for other in pairs(active) do
                local p = positions[other]
                if other ~= except and p and (buckets[other] or 0) == bucket then
                    local dx, dy, dz = p[1] - coords.x, p[2] - coords.y, p[3] - coords.z
                    if dx * dx + dy * dy + dz * dz <= radius * radius then out[#out + 1] = other end
                end
            end
            table.sort(out)
            return out
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
            PlayersNear = function(coords, radius, src) return near(coords, radius, buckets[src] or 0, src) end,
            PlayersAround = function(bucket, coords, radius)
                sent.lastAround = near(coords, radius, bucket, nil)
                return sent.lastAround
            end,
            SendTo = function(list, event, ...)
                for _, id in ipairs(list) do assert.is_true(math.type(id) == 'integer' and id > 0) end
                sent[#sent + 1] = { list = copy(list), event = event, args = table.pack(...) }
                sent[#sent].args.n = nil
                return true
            end,
            SendNear = function(bucket, coords, radius, event, ...)
                sent[#sent + 1] = { near = true, event = event, args = { ... } }
                return true
            end,
            Send = function(target, event, ...)
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                staminaSent[#staminaSent + 1] = { target = target, event = event, args = { ... } }
                return true
            end,
            Notify = function(target, text, kind) notifies[#notifies + 1] = { target = target, text = text } end,
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
            HasItem = function() return true end,
            ItemDefinition = function() return { label = 'Épée courte', stack = 1, held = { model = 'w_me_machette_lr' } } end,
            AddItem = function() return true end,
            ModuleVersion = function() return nil end,
            RecipesReady = function() return false end,
            Recipe = function() return nil end,
            SkillRecipesReady = function() return false end,
            HealthKinds = function() return nil end,
            HealthTags = function() return nil end,
            DefineShieldField = function() return true end,
            Hit = chainHit,
            DeclareModifiers = function(list)
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
            NeedsValues = function(src)
                needsCalls[#needsCalls + 1] = { src = src, at = clock - T0 }
                if type(needsAnswer) == 'function' then return needsAnswer(src) end
                return needsAnswer
            end,
            IsAllowed = function() return true end,
            AdminLog = function() end,
            Chat = function(src, text) chats[#chats + 1] = { src = src, text = text } end,
            ChatLines = function() end,
        }
        VavaCombat.bridge = bridge
        helper.loadAll({
            'modules/vava_combat/server/catalog.lua',
            'modules/vava_combat/server/pedstate.lua',
            'modules/vava_combat/server/wear.lua',
            'modules/vava_combat/server/shields.lua',
            'modules/vava_combat/server/strike.lua',
            'modules/vava_combat/server/hands.lua',
            'modules/vava_combat/server/reactions.lua',
            'modules/vava_combat/server/stamina.lua',
            'modules/vava_combat/server/defense.lua',
            'modules/vava_combat/server/swings.lua',
            'modules/vava_combat/server/api.lua',
            'modules/vava_combat/server/commands.lua',
        })
        swings, defense, reactions = VavaCombat.swings, VavaCombat.defense, VavaCombat.reactions
        stamina, commands = VavaCombat.stamina, VavaCombat.commands
        VavaCombat.shields.hungOf = function(src) return hung[src] end
        local ok, err = VavaCombat.catalog.setup()
        assert.is_true(ok, err)
        VavaCombat.ready = true
        assert.equal(3, defense.declare())
        bridge.OnHitAfter(defense.onHitAfter)
        arm(A, 10, 'epee_courte')
        arm(B, 20, 'epee_courte')
        arm(C, 30, 'epee_courte')
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        math.random = realRandom
        VavaCombat = nil
    end)

    describe('attaques', function()
        it('Taille acceptée : 880, reprise dans 1 s, 20 / s ; Estoc enchaîné : 790', function()
            assert.same({ true, 880, 1000, 200 }, use(A, 'taille_descendante', B))
            at(480)
            assert.same({ true, 790, 1000, 200 }, use(A, 'estoc_rapide', B))
        end)

        it('Tailles toutes les 900 ms depuis 100 : huit acceptées, la 9e refusée avant la réservation', function()
            for k = 0, 7 do
                at(k * 900)
                assert.equal(true, use(A, 'taille_descendante')[1], tostring(k))
            end
            assert.equal(40, level(A))
            at(8 * 900)
            local before, calls, prev = #befores, #needsCalls, swings.of(A)
            -- 100 ms avant la reprise, puis 80 dixièmes à 200 / s : 500 ms
            assert.same({ false, 'exhausted', 500, 40, 100, 200 }, use(A, 'taille_descendante'))
            assert.equal(before, #befores)
            assert.equal(calls, #needsCalls)
            assert.equal(prev, swings.of(A))
            at(8 * 900 + 500)
            assert.equal(true, use(A, 'taille_descendante')[1])
            assert.equal(0, level(A))
        end)

        it('coup manqué payé ; coup paré : l\'attaquant ne récupère rien, la parade coûte 6', function()
            headings[B] = 0
            positions[B] = { 0, -2, 0 }                   -- dans le dos de A : rien dans l'arc
            use(A, 'taille_descendante')
            at(900)
            assert.equal(0, #hits)
            assert.equal(880, level(A))
            positions[B] = { 0, 2, 0 }
            headings[B] = 180
            use(A, 'taille_descendante', B)                 -- relevé à 1 220
            at(1100)
            assert.same({ true, 940, 1000, 200 }, use(B, 'parade_epee'))
            at(1220)
            assert.equal('parade', hits[#hits].result.cancelled)
            assert.equal(760, level(A))
            assert.equal(940, level(B))
        end)

        it('geste refusé (crochet, autre raison) : rien n\'est dépensé', function()
            beforeAnswer = { false, 'Trêve.' }
            assert.same({ false, 'refused', 'Trêve.' }, use(A, 'fendant', B))
            assert.equal(1000, level(A))
        end)
    end)

    describe('prise au dernier pas (crochet using qui cède la main)', function()
        before_each(function()
            VavaCombat.bridge.RunBefore = function(name, payload)
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                coroutine.yield('paused')
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end
        end)

        local function request(src, id)
            local co = coroutine.create(function() return swings.use(src, id, 0) end)
            local out = { coroutine.resume(co) }
            assert.is_true(table.remove(out, 1), tostring(out[1]))
            assert.equal('suspended', coroutine.status(co))
            return co
        end

        local function finish(co)
            local out = { coroutine.resume(co) }
            assert.is_true(table.remove(out, 1), tostring(out[1]))
            return out
        end

        it('coup bloqué pendant l\'attente qui vide la jauge : exhausted, place rendue, rien dépensé', function()
            local co = request(B, 'pas_de_cote')
            assert.is_true(swings.of(B).pending)
            -- deux coups lourds bloqués arrivent pendant que le crochet cède la main
            stamina.block(B, cfg.techniques.garde_epee, 2, false, clock, CHAR_B)
            stamina.block(B, cfg.techniques.garde_epee, 2, false, clock, CHAR_B)
            assert.same({ false, 'exhausted', 2000, 0, 1000, 200 }, finish(co))
            assert.is_nil(swings.of(B))
            assert.is_nil(defense.activeOf(B))
            assert.equal(0, level(B))
        end)

        it('réservation refusée pour une autre raison : rien dépensé', function()
            local co = request(B, 'pas_de_cote')
            beforeAnswer = { false, 'Ligoté.' }
            assert.same({ false, 'refused', 'Ligoté.' }, finish(co))
            assert.equal(1000, level(B))
        end)

        it('accepté après l\'attente : dépensé une fois, au dernier pas', function()
            local co = request(B, 'pas_de_cote')
            at(40)
            assert.equal(1000, level(B))
            assert.same({ true, 800, 1000, 200 }, finish(co))
        end)
    end)

    describe('garde', function()
        it('levée à 24 : exhausted ; à 25 : acceptée, jauge inchangée', function()
            stamina.block(B, { stamina = 76 }, 1, false, clock, CHAR_B)      -- 1 000 − 760
            staminaSent = {}
            assert.same({ false, 'exhausted', 1050, 240, 1000, 200 }, use(B, 'garde_epee'))
            at(1050)
            assert.same({ true, 250, 0, 200 }, use(B, 'garde_epee'))
            assert.equal(250, level(B))
        end)

        it('quatre Tailles de face : 750, 500, 250, puis break ; un état au seul défenseur par coup bloqué', function()
            assert.same({ true, 1000, 0, 200 }, use(B, 'garde_epee'))
            for k = 0, 3 do
                at(k * 900)
                assert.equal(true, use(A, 'taille_descendante', B)[1])
                at(k * 900 + 320)
            end
            assert.same({ 'block', 'block', 'block', 'break' }, outcomesFor(B))
            assert.same({ { 750, 1000, 200 }, { 500, 1000, 200 }, { 250, 1000, 200 }, { 0, 1000, 200 } }, staminaTo(B))
            assert.equal(4, #staminaSent)
            for _, entry in ipairs(staminaSent) do assert.equal('vava_combat:stamina', entry.event) end
            assert.same({}, staminaTo(A))
            assert.same({}, staminaTo(C))
            -- vava_combat:hit inchangé : jamais l'endurance (4 valeurs aux participants, 3 au témoin)
            for _, entry in ipairs(sent) do
                assert.is_true(#entry.args == 3 or #entry.args == 4)
                if #entry.args == 4 then assert.is_true(entry.args[4] == false or math.type(entry.args[4]) == 'integer') end
            end
            -- après la garde brisée : chancelle 1,2 s, puis à bout de souffle jusqu'à 2,25 s
            at(3020 + 1199)
            assert.same({ false, 'staggered', 1 }, use(B, 'garde_epee'))
            at(3020 + 1200)
            assert.same({ false, 'exhausted', 1050, 40, 0, 200 }, use(B, 'garde_epee'))
            at(3020 + 2249)
            assert.equal('exhausted', use(B, 'garde_epee')[2])
            at(3020 + 2250)
            assert.same({ true, 250, 0, 200 }, use(B, 'garde_epee'))
        end)

        it('bouclier au bras : six coups, cède au 6e ; décroché pendant la garde : coût de l\'arme', function()
            piles[B][#piles[B] + 1] = pile(SHIELD_ID, 'bouclier_rond')
            hung[B] = { instanceId = SHIELD_ID, item = 'bouclier_rond', characterId = CHAR_B }
            use(B, 'garde_epee')
            for k = 0, 5 do
                at(k * 900)
                use(A, 'taille_descendante', B)
                at(k * 900 + 320)
                if k == 4 then assert.equal(160, level(B)) end
            end
            assert.same({ 'block', 'block', 'block', 'block', 'block', 'break' }, outcomesFor(B))
            -- garde neuve, bouclier décroché après le premier coup : 832 puis 582
            stamina.forget(B)
            swings.forget(B)
            defense.forget(B)
            reactions.forget(B)
            at(10000)
            use(B, 'garde_epee')
            use(A, 'taille_descendante', B)
            at(10320)
            assert.equal(832, level(B))
            hung[B] = nil
            at(10900)
            use(A, 'taille_descendante', B)
            at(11220)
            assert.equal(582, level(B))
        end)

        it('deux Fendants (deux attaquants, à moins d\'1 s) : break au second ; Fendant qui met à terre : rien dépensé',
            function()
            positions[C], headings[C] = { 1, 0, 0 }, 26.6
            use(B, 'garde_epee')
            use(A, 'fendant', B)
            at(300)
            use(C, 'fendant', B)
            at(950)
            assert.same({ 'block', 'break' }, outcomesFor(B))
            -- garde neuve ; le Fendant bloqué met B à terre : issue down, rien dépensé (la mise à terre l'emporte)
            stamina.forget(B)
            swings.forget(B)
            defense.forget(B)
            reactions.forget(B)
            at(5000)
            use(B, 'garde_epee')
            downOnHit[B] = true
            use(A, 'fendant', B)
            at(5650)
            assert.equal('down', outcomesFor(B)[3])
            assert.equal(1000, level(B))
        end)
    end)

    describe('parade, pas de côté', function()
        it('parade : − 6, ratée ou réussie ; pas : − 20', function()
            assert.same({ true, 940, 1000, 200 }, use(B, 'parade_epee'))
            at(800)
            assert.same({ true, 880, 1000, 200 }, use(B, 'parade_epee'))
            at(2000)
            -- 1 800 → 2 000 : 200 ms de recharge (+ 40), puis − 200
            assert.same({ true, 720, 1000, 200 }, use(B, 'pas_de_cote'))
        end)

        it('Espace toutes les 1 500 ms depuis 100 : neuf pas acceptés, le 10e à bout de souffle', function()
            for k = 0, 8 do
                at(k * 1500)
                assert.equal(true, use(B, 'pas_de_cote')[1], tostring(k))
            end
            assert.equal(0, level(B))
            at(9 * 1500)
            -- 500 ms de recharge depuis le 9e (+ 100) ; 100 de plus : 500 ms
            assert.same({ false, 'exhausted', 500, 100, 0, 200 }, use(B, 'pas_de_cote'))
        end)

        -- relecture sécurité de T-113 : l'alternance pas de côté / parades ratées protégeait ≈ 35 % du temps
        it('borne : pas de côté et parades ratées dès que permis pendant 60 s : ≤ 20 % protégé, ≤ 17 % de 10 à 60 s',
            function()
            local protected, protectedLate, steps, lateSteps = 0, 0, 0, 0
            for ms = 0, 59990, 10 do
                at(ms)
                local ok = swings.use(B, 'pas_de_cote', 0)
                if ok ~= true then swings.use(B, 'parade_epee', 0) end
                local open = defense.open(defense.activeOf(B), clock)
                steps = steps + 1
                if open then protected = protected + 1 end
                if ms >= 10000 then
                    lateSteps = lateSteps + 1
                    if open then protectedLate = protectedLate + 1 end
                end
            end
            local share, late = protected / steps, protectedLate / lateSteps
            assert.is_true(share <= 0.20, ('%.3f sur 60 s'):format(share))
            assert.is_true(late <= 0.17, ('%.3f de 10 à 60 s'):format(late))
            -- ≈ 15,4 % en régime établi : une parade toutes les 1,3 s ; jamais nul (on se défend encore)
            assert.is_true(late >= 0.13, ('%.3f de 10 à 60 s'):format(late))
            assert.equal(0, #staminaSent)
        end)
    end)

    describe('faim et soif', function()
        it('premier geste : une lecture ; 10 s plus tard : aucune ; 30 s : une ; qui ne combat pas : aucune', function()
            needsAnswer = { hunger = 80, thirst = 70 }
            use(A, 'taille_descendante')
            assert.equal(1, #needsCalls)
            at(10000)
            use(A, 'taille_descendante')
            assert.equal(1, #needsCalls)
            at(30000)
            use(A, 'taille_descendante')
            assert.equal(2, #needsCalls)
            for _, call in ipairs(needsCalls) do assert.equal(A, call.src) end
            assert.equal(0, stamina.inspect(C).value - 1000)
        end)

        it('faim à 25 : pente 150 dans la réponse ; soif à 5 : 100 ; manger : 200 à la relecture suivante', function()
            needsAnswer = { hunger = 25, thirst = 90 }
            assert.same({ true, 880, 1000, 150 }, use(A, 'taille_descendante'))
            assert.same({ 880, 150, 0.75 }, { stamina.inspect(A).value, stamina.inspect(A).rate, stamina.inspect(A).factor })
            needsAnswer = { hunger = 80, thirst = 5 }
            at(30000)
            assert.same({ true, 880, 1000, 100 }, use(A, 'taille_descendante'))
            needsAnswer = { hunger = 80, thirst = 80 }
            at(45000)
            assert.same({ true, 880, 1000, 100 }, use(A, 'taille_descendante'))   -- pas encore relu
            at(60000)
            assert.same({ true, 880, 1000, 200 }, use(A, 'taille_descendante'))
        end)

        it('pente changée en recharge : la part déjà rechargée l\'a été à l\'ancienne pente', function()
            use(A, 'taille_descendante')                                       -- 880, reprise à 1 000
            needsAnswer = { hunger = 5, thirst = 50 }
            at(30500)
            -- relu à 30 500 : plein (rien n'avait à recharger après 1 600) ; la dépense part de 1 000
            assert.same({ true, 880, 1000, 100 }, use(A, 'taille_descendante'))
            at(31500 + 600)
            assert.equal(940, level(A))
        end)

        it('vava_needs absent ou en refus : facteur 1, aucune erreur ; autre personnage sur le numéro : jauge neuve', function()
            needsAnswer = nil
            assert.same({ true, 880, 1000, 200 }, use(A, 'taille_descendante'))
            active[A] = 101
            at(900)
            assert.same({ true, 880, 1000, 200 }, use(A, 'taille_descendante'))
            assert.equal(2, #needsCalls)
        end)

        it('/armes voir : l\'endurance du joueur, ralentie par la faim', function()
            needsAnswer = { hunger = 25, thirst = 90 }
            use(B, 'fendant')                                                 -- 750 ; le Conseil lit 425 ensuite
            stamina.block(B, cfg.techniques.garde_epee, 2, false, clock, CHAR_B)
            assert.equal(250, level(B))
            at(1000 + 1167)
            commands.handle(A, { 'voir', tostring(B) })
            assert.equal('Endurance : 42,5 / 100, recharge 15 / s (ralentie par la faim ou la soif)', chats[#chats].text)
            commands.handle(A, { 'voir', tostring(C) })
            assert.equal('Endurance : 100 / 100, recharge 20 / s', chats[#chats].text)
        end)
    end)

    describe('mise à terre, départ, arrêt', function()
        it('jauge à 40 en recharge : un envoi (1 000, 0, 200), oubliée ; pleine : aucun envoi', function()
            stamina.block(B, { stamina = 96 }, 1, false, clock, CHAR_B)
            staminaSent = {}
            stamina.onDowned(B)
            assert.same({ { target = B, event = 'vava_combat:stamina', args = { 1000, 0, 200 } } }, staminaSent)
            assert.equal(0, stamina.count())
            stamina.onDowned(B)
            use(A, 'taille_descendante')
            at(10000)                                                         -- A de nouveau plein
            stamina.onDowned(A)
            assert.equal(1, #staminaSent)
        end)

        it('déchargement, départ : rien envoyé, oubliée ; arrêt : tout oublié', function()
            use(A, 'taille_descendante')
            use(B, 'parade_epee')
            assert.equal(2, stamina.count())
            stamina.forget(A)
            assert.equal(1, stamina.count())
            stamina.stop()
            assert.equal(0, stamina.count())
            assert.equal(0, #staminaSent)
        end)
    end)

    describe('réseau', function()
        it('60 s de recharge sans geste : aucun envoi, aucune minuterie ; une dépense ne crée aucune minuterie', function()
            use(B, 'parade_epee')
            use(C, 'pas_de_cote')
            stamina.block(A, cfg.techniques.garde_epee, 1, false, clock, CHAR_A)
            local sends, created = #staminaSent + #sent, timersCreated
            for ms = 100, 60000, 100 do at(ms) end
            assert.equal(sends, #staminaSent + #sent)
            assert.equal(created, timersCreated)
            -- une attaque crée ses seuls relevés (2), la dépense rien de plus
            at(61000)
            use(A, 'taille_descendante')
            assert.equal(created + cfg.timing.samples, timersCreated)
        end)
    end)
end)

-- bridge/server.lua réel : vava_needs:get isolé (erreur : une ligne par minute ; export absent : plus cherché 60 s,
-- relu au démarrage de vava_needs)
describe('vava_combat bridge : faim et soif (vava_needs:get)', function()
    local handlers, clock, answer, invoked, state, warns

    before_each(function()
        helper.reset()
        VavaCombat = nil
        handlers, clock, answer, invoked, state, warns = {}, 1000, nil, 0, 'started', {}
        helper.loadAll({ 'modules/vava_combat/shared/constants.lua', 'modules/vava_combat/config.lua' })
        local log = { warn = function(fmt, ...) warns[#warns + 1] = fmt:format(...) end, info = function() end }
        VavaCombat.log, VavaCombat.resource, VavaCombat.core = log, 'vava_combat', { log = log }
        _G.GetGameTimer = function() return clock end
        _G.GetResourceState = function(name) return name == 'vava_needs' and state or 'missing' end
        _G.AddEventHandler = function(name, fn) handlers[name] = fn end
        _G.exports = { vava_needs = { get = function(_, src)
            invoked = invoked + 1
            if type(answer) == 'string' then error(answer) end
            return answer
        end } }
        helper.load('modules/vava_combat/bridge/server.lua')
    end)

    after_each(function()
        for _, name in ipairs({ 'GetGameTimer', 'GetResourceState', 'AddEventHandler', 'exports' }) do _G[name] = nil end
        VavaCombat = nil
    end)

    it('table rendue telle quelle ; autre chose : nil ; arrêté : nil sans appel', function()
        local bridge = VavaCombat.bridge
        answer = { hunger = 40, thirst = 60 }
        assert.same({ hunger = 40, thirst = 60 }, bridge.NeedsValues(1))
        answer = 'x'
        answer = nil
        assert.is_nil(bridge.NeedsValues(1))
        state = 'stopped'
        assert.is_nil(bridge.NeedsValues(1))
        assert.equal(2, invoked)
    end)

    it('en erreur : nil, une ligne de console par minute', function()
        local bridge = VavaCombat.bridge
        answer = 'panne'
        for _ = 1, 3 do assert.is_nil(bridge.NeedsValues(1)) end
        assert.equal(3, invoked)
        assert.equal(1, #warns)
        clock = clock + 60000
        bridge.NeedsValues(1)
        assert.equal(2, #warns)
    end)

    it('export absent : plus cherché pendant 60 s ; vava_needs redémarré : relu aussitôt', function()
        local bridge = VavaCombat.bridge
        answer = 'No such export get in resource vava_needs'
        assert.is_nil(bridge.NeedsValues(1))
        answer = { hunger = 10, thirst = 10 }
        clock = clock + 30000
        assert.is_nil(bridge.NeedsValues(1))
        assert.equal(1, invoked)
        assert.equal(0, #warns)
        handlers.onResourceStart('vava_magic')
        assert.is_nil(bridge.NeedsValues(1))
        handlers.onResourceStart('vava_needs')
        assert.same({ hunger = 10, thirst = 10 }, bridge.NeedsValues(1))
        assert.equal(2, invoked)
    end)
end)
