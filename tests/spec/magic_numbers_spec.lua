local helper = require('tests.helper')

-- Chiffres des sorts (vava_magic 2.13.0, T-155 § 7.3 et § 11.1) : server/numbers.lua et server/combat.lua réels, avec
-- des doublures : bridge (hit réglable, personnages), monde (positions), sorts, envois aux clients notés, minuteries
-- (SetTimeout) déclenchées à la main par l'essai (fin du tour). Vérifie : la victime reçoit le montant dans
-- vava_magic:hit (avec sa réaction, ou seul pour une morsure, une esquive, un coup absorbé) ; le lanceur reçoit UN
-- vava_magic:dealt par tour avec tous ses touchés (16 au plus) ; rien pour un coup retenu, rien au lanceur qui se
-- blesse lui-même ou qui est parti ; numbers coupés : comportement de 2.12.0 ; la valeur rendue par combat.damage ne
-- change jamais.
describe('vava_magic : chiffres des sorts (serveur)', function()
    local combat, numbers, cfg
    local events, characters, positions, hitResult, left
    local CASTER, VICTIM, OTHER = 3, 7, 9
    local HIT, DEALT = 'vava_magic:hit', 'vava_magic:dealt'

    local function load(tune)
        helper.reset()
        VavaMagic = nil
        helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
        cfg = VavaMagic.config
        cfg.combat.protectedZones = {}
        if tune then tune(cfg.numbers) end
        helper.loadAll({ 'modules/vava_magic/shared/geometry.lua', 'modules/vava_magic/shared/harm.lua' })
        events, hitResult, left = {}, nil, {}
        characters = { [CASTER] = 42, [VICTIM] = 77, [OTHER] = 88 }
        positions = { [CASTER] = { x = 0, y = 0, z = 0 }, [VICTIM] = { x = 5, y = 0, z = 0 }, [OTHER] = { x = 6, y = 0, z = 0 } }
        for id = 20, 40 do
            characters[id] = 1000 + id
            positions[id] = { x = id, y = 0, z = 0 }
        end
        _G.TriggerClientEvent = function(event, target, ...)
            events[#events + 1] = { event = event, target = target, args = table.pack(...) }
        end
        VavaMagic.resource = 'vava_magic'
        VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
        VavaMagic.bridge = {
            GetCharacterId = function(src) return characters[src] end,
            Notify = function() end,
            Hit = function(_, packet)
                if hitResult then return hitResult(packet) end
                return { amount = packet.amount, applied = packet.amount, blocked = 0, absorbed = 0, resisted = 0,
                    added = 0, downed = false }
            end,
            ChainHealthPoints = function() return 100 end,
            ChainPvp = function() return true end,
            ChainKnowsLaunched = function() return true end,
            db = { update = function() return 0 end },
        }
        VavaMagic.world = {
            position = function(src)
                local p = positions[src]
                return p and { x = p.x, y = p.y, z = p.z } or nil
            end,
        }
        local defs = {}
        for name, spellCfg in pairs(cfg.spells) do defs[name] = { config = spellCfg } end
        VavaMagic.spells = {
            get = function(name) return defs[name] end,
            onLeave = function(fn) left[#left + 1] = fn end,
        }
        helper.loadAll({ 'modules/vava_magic/server/numbers.lua', 'modules/vava_magic/server/combat.lua' })
        combat, numbers = VavaMagic.combat, VavaMagic.numbers
    end

    after_each(function()
        _G.TriggerClientEvent = nil
        VavaMagic = nil
    end)

    --- Fin du tour : les minuteries posées jusque-là, dans l'ordre.
    local function endOfTurn()
        local list = helper.timers
        helper.timers = {}
        for _, timer in ipairs(list) do
            assert.equal(0, timer.ms)
            timer.fn()
        end
    end

    local function of(event, target)
        local out = {}
        for _, e in ipairs(events) do
            if e.event == event and (target == nil or e.target == target) then
                out[#out + 1] = { table.unpack(e.args, 1, e.args.n) }
            end
        end
        return out
    end

    it('impact qui blesse : la réaction et le montant à la victime ; au lanceur, à la fin du tour', function()
        load()
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        assert.same({ { 'feu', 140 } }, of(HIT, VICTIM))
        assert.equal(0, #of(DEALT))
        endOfTurn()
        assert.same({ { { { VICTIM, 'hit', 140 } } } }, of(DEALT, CASTER))
        assert.equal(2, #events)
    end)

    it('éclats sur trois joueurs dans le même tour : UN dealt à trois entrées, une seule minuterie', function()
        load()
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        combat.damage(CASTER, OTHER, 'boule_de_feu', 6, combat.KIND.ZONE)
        combat.damage(CASTER, 20, 'boule_de_feu', 6, combat.KIND.ZONE)
        assert.equal(1, #helper.timers)
        endOfTurn()
        local dealt = of(DEALT, CASTER)
        assert.equal(1, #dealt)
        assert.same({ { VICTIM, 'hit', 140 }, { OTHER, 'hit', 60 }, { 20, 'hit', 60 } }, dealt[1][1])
        -- tour suivant : un nouveau message
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        endOfTurn()
        assert.equal(2, #of(DEALT, CASTER))
    end)

    it('17 touchés dans un tour : 16 entrées', function()
        load()
        for id = 20, 36 do combat.damage(CASTER, id, 'nova_ardente', 5, combat.KIND.ZONE) end
        endOfTurn()
        local dealt = of(DEALT, CASTER)
        assert.equal(1, #dealt)
        assert.equal(cfg.numbers.maxPerMessage, #dealt[1][1])
        assert.equal(16, #dealt[1][1])
        assert.same({ 35, 'hit', 50 }, dealt[1][1][16])
    end)

    it('morsure de brûlure : (false, 20, tick) à la victime, tick au lanceur ; overTime coupé : rien', function()
        load()
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 42, 'feu'))
        assert.same({ { false, 20, 'tick' } }, of(HIT, VICTIM))
        endOfTurn()
        assert.same({ { { { VICTIM, 'tick', 20 } } } }, of(DEALT, CASTER))
        load(function(n) n.overTime = false end)
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 42, 'feu'))
        endOfTurn()
        assert.equal(0, #events)
    end)

    it('zone qui dure : réaction et petit chiffre ; overTime coupé : la réaction seule', function()
        load()
        combat.damage(CASTER, VICTIM, 'mur_de_flammes', 3.5, combat.KIND.AURA, 42)
        assert.same({ { 'feu', 35, 'tick' } }, of(HIT, VICTIM))
        load(function(n) n.overTime = false end)
        combat.damage(CASTER, VICTIM, 'mur_de_flammes', 3.5, combat.KIND.AURA, 42)
        assert.same({ { 'feu' } }, of(HIT, VICTIM))
        endOfTurn()
        assert.equal(0, #of(DEALT))
    end)

    it('esquive, bouclier qui absorbe : le mot aux deux, sans montant ; la valeur rendue reste fausse', function()
        load()
        hitResult = function() return { amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' } end
        assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        hitResult = function() return { amount = 0, applied = 0, blocked = 0, absorbed = 14, downed = false } end
        assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        assert.same({ { false, false, 'dodge' }, { false, false, 'absorb' } }, of(HIT, VICTIM))
        endOfTurn()
        assert.same({ { { { VICTIM, 'dodge' }, { VICTIM, 'absorb' } } } }, of(DEALT, CASTER))
    end)

    it('à terre : le montant du coup, jamais la vie retirée', function()
        load()
        hitResult = function() return { amount = 12, applied = 3, blocked = 0, absorbed = 0, downed = true } end
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
        assert.same({ { 'feu', 120, 'down' } }, of(HIT, VICTIM))
        endOfTurn()
        assert.same({ { { { VICTIM, 'down', 120 } } } }, of(DEALT, CASTER))
    end)

    it('zone de paix, combats coupés, crochet : rien à personne', function()
        load()
        for _, r in ipairs({
            { amount = 0, applied = 0, cancelled = 'zone_protegee', stage = 'annulation' },
            { amount = 0, applied = 0, cancelled = 'pvp_off' },
            { amount = 0, applied = 0, cancelled = 'treve', stage = 'before' },
        }) do
            hitResult = function() return r end
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        end
        endOfTurn()
        assert.equal(0, #events)
        assert.equal(0, #helper.timers)
    end)

    it('le lanceur se blesse à son propre mur : chiffre reçu, aucun dealt à lui-même', function()
        load()
        combat.damage(CASTER, CASTER, 'mur_de_flammes', 3, combat.KIND.AURA, 42)
        assert.same({ { 'feu', 30, 'tick' } }, of(HIT, CASTER))
        endOfTurn()
        assert.equal(0, #of(DEALT))
    end)

    it('lanceur parti avant la fin du tour, ou sans personnage : rien ; départ : sa file oubliée', function()
        load()
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        characters[CASTER] = nil
        endOfTurn()
        assert.equal(0, #of(DEALT))
        characters[CASTER] = 42
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        for _, fn in ipairs(left) do fn(CASTER) end
        endOfTurn()
        assert.equal(0, #of(DEALT))
    end)

    it('numbers.target coupé : la victime n\'a que sa réaction ; numbers.caster coupé : rien au lanceur', function()
        load(function(n) n.target = false end)
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 42, 'feu')
        assert.same({ { 'feu' } }, of(HIT, VICTIM))
        endOfTurn()
        assert.equal(1, #of(DEALT, CASTER))
        load(function(n) n.caster = false end)
        combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT)
        endOfTurn()
        assert.same({ { 'feu', 140 } }, of(HIT, VICTIM))
        assert.equal(0, #of(DEALT))
    end)

    it('numbers.enabled coupé : vava_magic:hit(\'feu\') seul, comme en 2.12.0, aucune minuterie', function()
        load(function(n) n.enabled = false end)
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 42, 'feu'))
        hitResult = function() return { amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive' } end
        assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 14, combat.KIND.IMPACT))
        assert.equal(1, #events)
        assert.same({ event = HIT, target = VICTIM, args = { 'feu', n = 1 } }, events[1])
        assert.equal(0, #helper.timers)
    end)

    it('une vague (sans dégâts) réagit comme avant : un seul élément', function()
        load()
        combat.react(VICTIM, 'vague')
        assert.equal(1, events[1].args.n)
    end)
end)

-- Côté joueur (client/states.lua et client/numbers.lua réels, sur la seule vue client) : vava_magic:hit à la victime et
-- vava_magic:dealt au lanceur → bridge.HitText, valeurs relues et bornées.
describe('vava_magic : chiffres des sorts (client)', function()
    local net, texts, played
    local STUBBED = { 'RegisterNetEvent', 'PlayerId', 'GetPlayerServerId', 'PlayerPedId', 'IsPedRagdoll', 'IsEntityDead' }

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_magic', 'VavaMagic')
        net, texts, played = {}, {}, {}
        _G.RegisterNetEvent = function(name, fn) net[name] = fn end
        _G.PlayerId = function() return 0 end
        _G.GetPlayerServerId = function() return 7 end
        _G.PlayerPedId = function() return 70 end
        _G.IsPedRagdoll = function() return false end
        _G.IsEntityDead = function() return false end
        VavaMagic.nui = { send = function() end }
        VavaMagic.casting = {
            isCasting = function() return false end,
            playOnce = function(anim) played[#played + 1] = anim end,
            addBlocker = function() end,
        }
        VavaMagic.bridge = { HitText = function(...) texts[#texts + 1] = table.pack(...) end }
        helper.loadAll({ 'modules/vava_magic/client/states.lua', 'modules/vava_magic/client/numbers.lua' })
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        VavaMagic = nil
    end)

    local function args(i) return { table.unpack(texts[i], 1, texts[i].n) } end

    it('vava_magic:hit : réaction de 2.12.0, puis le chiffre reçu sur soi', function()
        net['vava_magic:hit']('feu')
        assert.equal(1, #played)
        assert.equal(0, #texts)
        net['vava_magic:hit']('feu', 140)
        assert.equal(2, #played)
        assert.same({ 'taken', 7, 'hit', 140 }, args(1))
        net['vava_magic:hit'](false, 20, 'tick')
        assert.equal(2, #played)
        assert.same({ 'taken', 7, 'tick', 20 }, args(2))
        net['vava_magic:hit'](false, false, 'dodge')
        assert.same({ 'taken', 7, 'dodge', nil }, args(3))
        -- issue inconnue : rien ; montant invalide : chiffre sans montant
        net['vava_magic:hit'](false, 20, 'soin')
        net['vava_magic:hit']('feu', 7.5)
        assert.equal(4, #texts)
        assert.same({ 'taken', 7, 'hit', nil }, args(4))
    end)

    it('vava_magic:dealt : une entrée par touché, les entrées invalides sautées, une liste invalide ignorée', function()
        net['vava_magic:dealt']({ { 9, 'hit', 140 }, { 12, 'dodge' }, { 0, 'hit', 5 }, { 13, 'soin', 5 },
            { 14, 'hit', 2001 }, { 15, 'tick', 7.5 }, { 16 }, { 17, 'down', 120, 'x' }, 'x', { x = 1 } })
        assert.equal(2, #texts)
        assert.same({ 'dealt', 9, 'hit', 140 }, args(1))
        assert.same({ 'dealt', 12, 'dodge', nil }, args(2))
        local long = {}
        for i = 1, 33 do long[i] = { i, 'hit', 10 } end
        net['vava_magic:dealt'](long)
        net['vava_magic:dealt']({ [1] = { 9, 'hit', 1 }, extra = true })
        net['vava_magic:dealt']({})
        net['vava_magic:dealt']('x')
        assert.equal(2, #texts)
    end)
end)
