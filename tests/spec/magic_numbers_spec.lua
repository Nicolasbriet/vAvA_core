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
        -- plus aucun envoi direct (relecture réseau R-1)
        _G.TriggerClientEvent = function() error('TriggerClientEvent direct') end
        VavaMagic.resource = 'vava_magic'
        VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
        VavaMagic.bridge = {
            GetCharacterId = function(src) return characters[src] end,
            Notify = function() end,
            -- envois comptés par core.net (relecture réseau R-1) : seul chemin des chiffres et des réactions
            SendTo = function(target, event, ...)
                assert.equal('integer', math.type(target))
                events[#events + 1] = { event = event, target = target, args = table.pack(...) }
                return true
            end,
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

    it('17 touchés dans un tour : maxPerMessage (10, relecture réseau R-3) entrées', function()
        load()
        for id = 20, 36 do combat.damage(CASTER, id, 'nova_ardente', 5, combat.KIND.ZONE) end
        endOfTurn()
        local dealt = of(DEALT, CASTER)
        assert.equal(1, #dealt)
        assert.equal(10, cfg.numbers.maxPerMessage)
        assert.equal(10, #dealt[1][1])
        assert.same({ 29, 'hit', 50 }, dealt[1][1][10])
        load(function(n) n.maxPerMessage = 16 end)
        for id = 20, 36 do combat.damage(CASTER, id, 'nova_ardente', 5, combat.KIND.ZONE) end
        endOfTurn()
        assert.equal(16, #of(DEALT, CASTER)[1][1])
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
        -- issue et montant relus par vava_hud (hitText), pas ici
        net['vava_magic:hit'](false, 20, 'soin')
        assert.same({ 'taken', 7, 'soin', 20 }, args(4))
        assert.equal(4, #texts)
    end)

    it('vava_magic:dealt : une entrée (table) par touché, relue par vava_hud ; plus de 32 ou pas une table : ignoré',
        function()
            net['vava_magic:dealt']({ { 9, 'hit', 140 }, { 12, 'dodge' }, 'x', 5 })
            assert.equal(2, #texts)
            assert.same({ 'dealt', 9, 'hit', 140 }, args(1))
            assert.same({ 'dealt', 12, 'dodge', nil }, args(2))
            local long = {}
            for i = 1, 33 do long[i] = { i, 'hit', 10 } end
            net['vava_magic:dealt'](long)
            net['vava_magic:dealt']({})
            net['vava_magic:dealt']('x')
            assert.equal(2, #texts)
            long[33] = nil
            net['vava_magic:dealt'](long)
            assert.equal(34, #texts)
        end)
end)

-- Bridge serveur réel (vava_magic/bridge/server.lua) : Bridge.SendTo passe par core.net.send (compté par /vava_reseau),
-- à un joueur ou à une liste ; destinataires invalides refusés (une ligne de console par minute) ; core sans core.net :
-- envoi direct à chacun (relecture réseau R-1).
describe('vava_magic : Bridge.SendTo (serveur)', function()
    local bridge, sends, direct, warns, clock, netAnswer

    before_each(function()
        helper.reset()
        VavaMagic = nil
        helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
        sends, direct, warns, clock, netAnswer = {}, {}, {}, 1000, { true, 1, 20 }
        _G.GetGameTimer = function() return clock end
        _G.TriggerClientEvent = function(event, target, ...)
            direct[#direct + 1] = { event = event, target = target, args = table.pack(...) }
        end
        VavaMagic.resource = 'vava_magic'
        VavaMagic.log = { warn = function(fmt, ...) warns[#warns + 1] = fmt:format(...) end, info = function() end }
        VavaMagic.core = {
            net = {
                send = function(target, event, ...)
                    sends[#sends + 1] = { target = target, event = event, args = table.pack(...) }
                    return table.unpack(netAnswer)
                end,
            },
        }
        helper.load('modules/vava_magic/bridge/server.lua')
        bridge = VavaMagic.bridge
    end)

    after_each(function()
        _G.TriggerClientEvent = nil
        VavaMagic = nil
    end)

    it('un joueur, une liste : core.net.send, rien en direct ; valeurs gardées (false compris)', function()
        assert.is_true(bridge.SendTo(7, 'vava_magic:hit', false, false, 'dodge'))
        assert.is_true(bridge.SendTo({ 3, 7 }, 'vava_magic:dealt', { { 7, 'hit', 140 } }))
        assert.equal(2, #sends)
        assert.equal(7, sends[1].target)
        assert.same({ false, false, 'dodge', n = 3 }, sends[1].args)
        assert.same({ 3, 7 }, sends[2].target)
        assert.equal(0, #direct)
    end)

    it('liste vide : rien, vrai ; -1, 0, flottant, texte, plus de 256 : refusé, une ligne par minute', function()
        assert.is_true(bridge.SendTo({}, 'vava_magic:hit', 'feu'))
        for _, bad in ipairs({ -1, 0, 1.5, '7' }) do assert.is_false(bridge.SendTo(bad, 'vava_magic:hit', 'feu')) end
        local long = {}
        for i = 1, 257 do long[i] = i end
        assert.is_false(bridge.SendTo(long, 'vava_magic:hit', 'feu'))
        assert.equal(0, #sends)
        assert.equal(0, #direct)
        assert.equal(1, #warns)
        clock = clock + 60000
        bridge.SendTo(-1, 'vava_magic:hit', 'feu')
        assert.equal(2, #warns)
    end)

    it('refus de core.net : faux, une ligne de console par minute et par évènement', function()
        netAnswer = { false, 'invalid_target' }
        assert.is_false(bridge.SendTo(7, 'vava_magic:hit', 'feu'))
        assert.is_false(bridge.SendTo(7, 'vava_magic:hit', 'feu'))
        assert.is_false(bridge.SendTo(7, 'vava_magic:dealt', {}))
        assert.equal(2, #warns)
        assert.matches('invalid_target', warns[1])
    end)

    it('core sans core.net (avant 0.10.0) : envoi direct à chacun', function()
        VavaMagic.core.net = nil
        assert.is_true(bridge.SendTo({ 3, 7 }, 'vava_magic:hit', 'feu', 140))
        assert.equal(2, #direct)
        assert.same({ 3, 'feu', 140 }, { direct[1].target, direct[1].args[1], direct[1].args[2] })
        assert.equal(7, direct[2].target)
    end)
end)
