local helper = require('tests.helper')

-- Sorts sur les mannequins d'entraînement (vava_magic 2.14.0, T-156 spec § 7.10 et § 11.1) : server/combat.lua,
-- server/projectiles.lua, Boule de feu, Trait de glace, Nova ardente et Secousse réels ; bridge simulé (DummiesNear rend
-- les mannequins du rayon, du plus proche au plus loin ; DummyHit noté ; Hit noté), monde, combinaisons, états,
-- obstacles et zones simulés. Puis le bridge réel : exports de vava_combat absents, plus anciens ou en erreur.
-- Un mannequin reçoit le même paquet qu'un joueur (type de l'élément, étiquettes de la nature, instant du lancement) ;
-- ni état, ni bonus d'XP, ni `touched` ; jamais dans une zone de paix ; jamais pour un lanceur qui joue un autre
-- personnage ; rien quand `dummies.enabled = false` ou sans vava_combat.
describe('vava_magic sorts sur les mannequins (serveur)', function()
    local cfg, combat, projectiles, defs, impact, quake
    local now, positions, characters, hits, dummyHits, nearCalls, dummyList, combatPresent, blocked
    local stateCalls, bonuses
    local realRandom = math.random

    local CASTER, VICTIM = 3, 7
    local LAUNCH_AT = 10000

    local function distance(a, b)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    before_each(function()
        helper.reset()
        VavaMagic = nil
        helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
        cfg = VavaMagic.config
        cfg.combat.protectedZones = {}
        helper.loadAll({ 'modules/vava_magic/shared/geometry.lua', 'modules/vava_magic/shared/harm.lua' })
        now = LAUNCH_AT
        positions = { [CASTER] = { x = 0, y = 0, z = 0 }, [VICTIM] = { x = 0, y = 9.6, z = 0.7 } }
        characters = { [CASTER] = 42, [VICTIM] = 77 }
        hits, dummyHits, nearCalls, stateCalls, bonuses = {}, {}, 0, {}, {}
        -- centres visés : le 1 à 10 m devant le lanceur, le 2 à 2 m de lui
        dummyList = { { n = 1, x = 0.0, y = 10.0, z = 1.0 }, { n = 2, x = 2.0, y = 10.0, z = 1.0 } }
        combatPresent, blocked = true, nil
        defs, impact, quake = {}, nil, nil

        _G.GetGameTimer = function() return now end
        _G.SetTimeout = function() end
        _G.GetPlayerPing = function() return 0 end
        _G.TriggerClientEvent = function() end
        math.random = function() return 0.99 end   -- la Boule de feu ne s'éteint jamais entre les mains

        VavaMagic.resource = 'vava_magic'
        VavaMagic.ready = true
        VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
        VavaMagic.numbers = { add = function() end }
        VavaMagic.bridge = {
            GetCharacterId = function(src) return characters[src] end,
            IsDowned = function() return false end,
            IsInvulnerable = function() return false end,
            Notify = function() end,
            SendTo = function() return true end,
            Hit = function(target, packet)
                hits[#hits + 1] = { target = target, packet = packet }
                return { amount = packet.amount, applied = packet.amount, blocked = 0, absorbed = 0, resisted = 0,
                    added = 0, downed = false }
            end,
            ChainHealthPoints = function() return 100 end,
            ChainPvp = function() return true end,
            ChainKnowsLaunched = function() return true end,
            DummiesNear = function(point, radius)
                nearCalls = nearCalls + 1
                if not combatPresent then return {} end
                local out = {}
                for _, d in ipairs(dummyList) do
                    if distance(point, d) <= radius then out[#out + 1] = { n = d.n, x = d.x, y = d.y, z = d.z } end
                end
                table.sort(out, function(a, b) return distance(point, a) < distance(point, b) end)
                return out
            end,
            DummyHit = function(n, packet)
                dummyHits[#dummyHits + 1] = { n = n, packet = packet }
                return { outcome = 'hit', amount = packet.amount }
            end,
            db = { update = function() return 0 end },
        }
        VavaMagic.world = {
            position = function(src)
                local p = positions[src]
                return p and { x = p.x, y = p.y, z = p.z } or nil
            end,
            near = function(point, radius, except)
                local out = {}
                for src, p in pairs(positions) do
                    if src ~= except and distance(point, p) <= radius then
                        out[#out + 1] = { source = src, position = { x = p.x, y = p.y, z = p.z } }
                    end
                end
                return out
            end,
            broadcast = function() end,
        }
        VavaMagic.spells = {
            get = function(name) return defs[name] and { config = defs[name].config } or nil end,
            onLeave = function() end,
            register = function(name, def)
                defs[name] = def
                return true
            end,
            addRpc = function(_, _, _, fn) impact = fn end,
        }
        VavaMagic.states = {
            apply = function(src, name)
                stateCalls[#stateCalls + 1] = { src, name }
                return true
            end,
            has = function() return false end,
        }
        VavaMagic.combos = {
            hit = function(_, _, _, points) return { damage = points, burn = false } end,
            commit = function() end,
            zone = function() return nil end,
            quake = function() end,
        }
        VavaMagic.obstacles = { blocked = function(a, b) return blocked and blocked(a, b) or false end }
        VavaMagic.experience = { bonus = function(src, spell) bonuses[#bonuses + 1] = { src, spell } end }
        VavaMagic.sheets = { get = function(src) return characters[src] and { characterId = characters[src] } or nil end }
        VavaMagic.zones = {
            CIRCLE = 'circle',
            crossedBy = function() return {} end,
            define = function(kind, handlers) if kind == 'quake' then quake = handlers end end,
            contains = function(zone, point)
                local dx, dy = point.x - zone.center.x, point.y - zone.center.y
                return math.abs(point.z - zone.center.z) <= 2.5 and math.sqrt(dx * dx + dy * dy) <= zone.radius
            end,
        }
        helper.loadAll({
            'modules/vava_magic/server/combat.lua',
            'modules/vava_magic/server/projectiles.lua',
            'modules/vava_magic/server/spells/boule_de_feu.lua',
            'modules/vava_magic/server/spells/trait_de_glace.lua',
            'modules/vava_magic/server/spells/nova_ardente.lua',
            'modules/vava_magic/server/spells/secousse.lua',
        })
        combat, projectiles = VavaMagic.combat, VavaMagic.projectiles
    end)

    after_each(function()
        for _, name in ipairs({ 'SetTimeout', 'GetPlayerPing', 'TriggerClientEvent' }) do _G[name] = nil end
        math.random = realRandom
        VavaMagic = nil
    end)

    --- Lance `spell` au niveau `level` vers le nord, puis signale l'impact (cible, point) 700 ms plus tard.
    local function cast(spell, level, target, point)
        now = LAUNCH_AT
        local result = defs[spell].finish({ source = CASTER, level = level, characterId = 42, data = {} }, 0, 1, 0)
        assert.is_true(result.success)
        now = LAUNCH_AT + 700
        return impact(CASTER, result.result.id, target, point.x, point.y, point.z)
    end

    local function hitsOn(n)
        local out = {}
        for _, h in ipairs(dummyHits) do
            if h.n == n then out[#out + 1] = h end
        end
        return out
    end

    describe('projectiles', function()
        it('Boule de feu sur le décor à 0,4 m du mannequin 1 : coup confié à vava_combat, rien d\'autre', function()
            dummyList[2] = nil
            assert.is_true(cast('boule_de_feu', 1, 0, { x = 0, y = 9.6, z = 1.0 }))
            assert.equal(1, #dummyHits)
            assert.equal(1, dummyHits[1].n)
            assert.same({ amount = cfg.spells.boule_de_feu.levels[1].damage, kind = 'feu', source = CASTER,
                sourceCharacter = 42, spell = 'boule_de_feu', tags = { spell = true, ranged = true, launched = true },
                launchedAt = LAUNCH_AT }, dummyHits[1].packet)
            assert.equal(0, #hits)
            assert.equal(0, #bonuses)
            assert.equal(0, #stateCalls)
        end)

        it('sans l\'étiquette `launched` connue de la chaîne : le coup part sans elle, comme pour un joueur', function()
            dummyList[2] = nil
            VavaMagic.bridge.ChainKnowsLaunched = function() return false end
            cast('boule_de_feu', 1, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.same({ spell = true, ranged = true }, dummyHits[1].packet.tags)
            assert.is_nil(dummyHits[1].packet.launchedAt)
        end)

        it('niveau 3 sur le joueur B, mannequin 2 à 2 m : B frappé, le mannequin reçoit la part des éclats', function()
            table.remove(dummyList, 1)
            local levels = cfg.spells.boule_de_feu.levels
            assert.is_true(cast('boule_de_feu', 3, VICTIM, { x = 0, y = 9.8, z = 1.0 }))
            assert.equal(1, #hits)
            assert.equal(VICTIM, hits[1].target)
            assert.equal(1, #dummyHits)
            assert.equal(2, dummyHits[1].n)
            assert.equal(levels[3].damage * levels[3].aoeShare, dummyHits[1].packet.amount)
            assert.same({ spell = true, area = true, launched = true }, dummyHits[1].packet.tags)
            -- le bonus d'XP vient de B, jamais du mannequin
            assert.equal(0, #bonuses)
        end)

        it('niveau 3 sur le décor près du mannequin 1 : frappé une seule fois (direct), le 2 par les éclats', function()
            local levels = cfg.spells.boule_de_feu.levels
            cast('boule_de_feu', 3, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(1, #hitsOn(1))
            assert.equal(levels[3].damage, hitsOn(1)[1].packet.amount)
            assert.same({ spell = true, ranged = true, launched = true }, hitsOn(1)[1].packet.tags)
            assert.equal(1, #hitsOn(2))
            assert.equal(levels[3].damage * levels[3].aoeShare, hitsOn(2)[1].packet.amount)
        end)

        it('un rempart entre le point et le mannequin 2 : pas d\'éclats sur lui', function()
            blocked = function(a, b) return b.n == 2 and b or false end
            cast('boule_de_feu', 3, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(1, #hitsOn(1))
            assert.equal(0, #hitsOn(2))
        end)

        it('un rempart sur le trajet : le projectile s\'y arrête, aucun mannequin derrière n\'est frappé', function()
            blocked = function(a, b)
                if a.x == 0 and a.y == 0 and b.y > 9 then return { x = 0, y = 8.0, z = 0.6 } end
                return false
            end
            -- le mannequin 1 est à 2,04 m du rempart (moins que targetMargin) : derrière lui, il n'a rien
            cast('boule_de_feu', 1, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(0, #dummyHits)
        end)

        it('Trait de glace sur le décor près d\'un mannequin : frappé (eau), ni ralenti ni mouillé', function()
            dummyList[2] = nil
            cast('trait_de_glace', 1, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(1, #dummyHits)
            assert.equal('eau', dummyHits[1].packet.kind)
            assert.equal(cfg.spells.trait_de_glace.levels[1].damage, dummyHits[1].packet.amount)
            assert.equal(0, #stateCalls)
        end)

        it('impact sur le décor loin de tout mannequin : rien', function()
            cast('boule_de_feu', 1, 0, { x = 0, y = 6.0, z = 1.0 })
            assert.equal(0, #dummyHits)
        end)
    end)

    describe('zones', function()
        it('Nova ardente : les mannequins du rayon, sans rempart ; touched inchangé, aucun bonus', function()
            dummyList = { { n = 1, x = 1.0, y = 0.0, z = 1.0 }, { n = 2, x = 0.0, y = 2.0, z = 1.0 },
                { n = 3, x = 0.0, y = 9.0, z = 1.0 } }
            positions[VICTIM] = nil
            blocked = function(_, b) return b.n == 2 and b or false end
            local result = defs.nova_ardente.finish({ source = CASTER, level = 1, characterId = 42, data = {} })
            assert.is_true(result.success)
            assert.equal(0, result.result.touched)
            result.rewarded(true)
            assert.equal(0, #bonuses)
            assert.equal(1, #dummyHits)
            assert.equal(1, dummyHits[1].n)
            assert.equal(cfg.spells.nova_ardente.levels[1].damage, dummyHits[1].packet.amount)
            assert.same({ spell = true, area = true }, dummyHits[1].packet.tags)
            assert.equal('feu', dummyHits[1].packet.kind)
        end)

        it('Secousse : les mannequins du cercle au moment où le sol se soulève, avec l\'instant du présage', function()
            dummyList = { { n = 1, x = 0.0, y = 20.0, z = 1.0 }, { n = 2, x = 2.0, y = 20.0, z = 1.0 },
                { n = 3, x = 4.5, y = 20.0, z = 1.0 } }   -- le 3 : assez près pour être demandé, hors du cercle
            local zone = { kind = 'quake', spell = 'secousse', level = 1, owner = CASTER, ownerCharacter = 42,
                shape = 'circle', center = { x = 0.0, y = 20.0, z = 0.0 }, radius = 3.0, createdAt = 9000,
                data = { damage = 4, control = 'stagger', controlMs = 1000, rewarded = true } }
            quake.onEnd(zone, 'expired')
            assert.equal(2, #dummyHits)
            local seen = { [dummyHits[1].n] = true, [dummyHits[2].n] = true }
            assert.is_true(seen[1] and seen[2])
            assert.equal(4, dummyHits[1].packet.amount)
            assert.equal('terre', dummyHits[1].packet.kind)
            assert.same({ spell = true, area = true, launched = true }, dummyHits[1].packet.tags)
            assert.equal(9000, dummyHits[1].packet.launchedAt)
            assert.equal(0, #stateCalls)
            assert.equal(0, #bonuses)
            -- présage nettoyé : rien
            dummyHits = {}
            quake.onEnd(zone, 'cleared')
            assert.equal(0, #dummyHits)
        end)
    end)

    describe('refus', function()
        it('mannequin dans une zone de paix : aucun appel', function()
            table.insert(cfg.combat.protectedZones, { x = 0.0, y = 10.0, radius = 3.0 })
            cast('boule_de_feu', 3, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(0, #dummyHits)
        end)

        it('lanceur qui joue un autre personnage : aucun appel', function()
            local result = defs.boule_de_feu.finish({ source = CASTER, level = 1, characterId = 42, data = {} }, 0, 1, 0)
            characters[CASTER] = 99
            now = LAUNCH_AT + 700
            impact(CASTER, result.result.id, 0, 0, 9.6, 1.0)
            assert.equal(0, #dummyHits)
            assert.is_nil(combat.dummyStrike(CASTER, 1, 'nova_ardente', 10, combat.KIND.ZONE, 42))
        end)

        it('vava_combat absent : aucun appel, aucune erreur', function()
            combatPresent = false
            assert.has_no.errors(function() cast('boule_de_feu', 3, 0, { x = 0, y = 9.6, z = 1.0 }) end)
            assert.equal(0, #dummyHits)
        end)

        it('dummies.enabled = false : vava_combat n\'est même pas interrogé', function()
            cfg.dummies.enabled = false
            cast('boule_de_feu', 3, 0, { x = 0, y = 9.6, z = 1.0 })
            defs.nova_ardente.finish({ source = CASTER, level = 1, characterId = 42, data = {} })
            assert.equal(0, nearCalls)
            assert.equal(0, #dummyHits)
            assert.is_nil(combat.dummyStrike(CASTER, 1, 'nova_ardente', 10, combat.KIND.ZONE, 42))
        end)

        it('combat.pvp = false n\'empêche pas l\'exercice (un mannequin n\'est pas un habitant)', function()
            cfg.combat.pvp = false
            dummyList[2] = nil
            cast('boule_de_feu', 1, 0, { x = 0, y = 9.6, z = 1.0 })
            assert.equal(1, #dummyHits)
            cfg.combat.pvp = true
        end)
    end)
end)

describe('vava_magic bridge : exports des mannequins de vava_combat', function()
    local Bridge, now, combatState, warnings, calls, nearAnswer, hooks

    before_each(function()
        helper.reset()
        VavaMagic = nil
        helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
        now, combatState, warnings, calls, hooks = 1000, 'started', {}, {}, {}
        nearAnswer = function() return {} end
        _G.GetGameTimer = function() return now end
        _G.GetResourceState = function(name) return name == 'vava_combat' and combatState or 'missing' end
        _G.exports = {
            vava_combat = setmetatable({}, { __index = function(_, fn)
                return function(_, ...)
                    calls[#calls + 1] = { fn = fn, args = { ... } }
                    if fn == 'dummiesNear' then return nearAnswer(...) end
                    if fn == 'dummyHit' then return { outcome = 'hit', amount = 8 } end
                    error('No such export ' .. fn .. ' in resource vava_combat')
                end
            end }),
        }
        VavaMagic.resource = 'vava_magic'
        VavaMagic.log = { warn = function(fmt, ...) warnings[#warnings + 1] = fmt:format(...) end, info = function() end,
            error = function() end }
        VavaMagic.core = {
            hooks = { after = function(name, fn) hooks[name] = fn return 1 end },
            registry = { exists = function() return false end },
        }
        helper.load('modules/vava_magic/bridge/server.lua')
        Bridge = VavaMagic.bridge
    end)

    after_each(function()
        _G.GetResourceState, _G.exports = nil, nil
        VavaMagic = nil
    end)

    it('vava_combat arrêté : liste vide, aucun appel, aucune ligne de console', function()
        combatState = 'stopped'
        assert.same({}, Bridge.DummiesNear({ x = 0, y = 0, z = 0 }, 5))
        local result, code = Bridge.DummyHit(1, {})
        assert.is_nil(result)
        assert.equal('combat_unavailable', code)
        assert.equal(0, #calls)
        assert.equal(0, #warnings)
    end)

    it('rend les mannequins relus (entrées illisibles écartées), le point copié', function()
        nearAnswer = function(point, radius)
            assert.same({ x = 1, y = 2, z = 3 }, point)
            assert.equal(5, radius)
            return { { n = 1, id = 'a', x = 1, y = 2, z = 3, distance = 0 }, { n = 1.5, x = 0, y = 0, z = 0 },
                { n = 2, x = 0 / 0, y = 0, z = 0 }, 'x', { n = 3, x = 4, y = 5, z = 6 } }
        end
        assert.same({ { n = 1, x = 1, y = 2, z = 3 }, { n = 3, x = 4, y = 5, z = 6 } },
            Bridge.DummiesNear({ x = 1, y = 2, z = 3, extra = true }, 5))
        assert.same({ outcome = 'hit', amount = 8 }, Bridge.DummyHit(1, { amount = 8 }))
    end)

    it('vava_combat plus ancien (export inconnu) : liste vide, une ligne, plus cherché pendant une minute', function()
        nearAnswer = function() error('No such export dummiesNear in resource vava_combat') end
        for _ = 1, 3 do assert.same({}, Bridge.DummiesNear({ x = 0, y = 0, z = 0 }, 5)) end
        assert.equal(1, #calls)
        assert.equal(1, #warnings)
        assert.matches('1.5.0', warnings[1])
        -- son redémarrage le fait relire aussitôt
        assert.is_true(Bridge.start())
        hooks['core:module:ready']({ name = 'vava_combat' })
        nearAnswer = function() return {} end
        Bridge.DummiesNear({ x = 0, y = 0, z = 0 }, 5)
        assert.equal(2, #calls)
    end)

    it('vava_combat en erreur : liste vide, une ligne de console par minute au plus', function()
        nearAnswer = function() error('panne voulue') end
        for _ = 1, 4 do assert.same({}, Bridge.DummiesNear({ x = 0, y = 0, z = 0 }, 5)) end
        assert.equal(4, #calls)
        assert.equal(1, #warnings)
    end)
end)
