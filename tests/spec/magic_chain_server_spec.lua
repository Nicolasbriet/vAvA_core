local helper = require('tests.helper')

-- La magie branchée sur la chaîne de dégâts, côté serveur (modules/vava_magic/server/combat.lua, protections.lua,
-- casting.lua ; T-116), avec des doublures : bridge (hit noté et réglable, personnages, vie de vava_health, hook des
-- coups capturé, modificateurs capturés, notifications notées), monde (positions), sorts, horloge fixe.
--   combat.damage : un seul appel à hit par coup, paquet { amount = points, kind de l'élément, source = lanceur,
--     sourceCharacter, spell, tags selon la nature } ; vrai seulement si le coup a retiré de la vie ; réaction de la
--     victime sauf pour une brûlure ; sans vava_health, aucun dégât, aucun envoi au client, une notification au
--     lanceur par minute ;
--   modificateurs déclarés : vava_magic:protections (bouclier) et vava_magic:resistances (resistance), plus
--     vava_magic:zones (annulation) seulement si une zone de paix est réglée ;
--   incantation : un coup qui retire de la vie au lanceur (hook after) ou sa vie de vava_health plus basse qu'au
--     début la brise (`hurt`) ; jamais la vie du ped.
describe('vava_magic sur la chaîne de dégâts (serveur)', function()
    local combat, protections, casting, cfg
    local now, hits, hitResult, hitCode, notified, clientEvents, characters, positions, health, modifiers, onHit
    local spellDefs

    local CASTER, VICTIM, OTHER = 3, 7, 9

    local function loadMagic(zones)
        helper.reset()
        VavaMagic = nil
        helper.loadAll({
            'modules/vava_magic/shared/constants.lua',
            'modules/vava_magic/config.lua',
        })
        cfg = VavaMagic.config
        cfg.combat.protectedZones = zones or {}
        helper.loadAll({ 'modules/vava_magic/shared/geometry.lua', 'modules/vava_magic/shared/harm.lua' })

        now, hits, hitResult, hitCode, notified, clientEvents = 1000, {}, nil, nil, {}, {}
        characters = { [CASTER] = 42, [VICTIM] = 77, [OTHER] = 88 }
        positions = { [CASTER] = { x = 0, y = 0, z = 0 }, [VICTIM] = { x = 5, y = 0, z = 0 }, [OTHER] = { x = 50, y = 0, z = 0 } }
        health = { [CASTER] = 1.0, [VICTIM] = 1.0 }
        modifiers, onHit = nil, nil

        _G.GetGameTimer = function() return now end
        _G.TriggerClientEvent = function(event, target, ...)
            clientEvents[#clientEvents + 1] = { event = event, target = target, args = { ... } }
        end
        VavaMagic.resource = 'vava_magic'
        VavaMagic.ready = true
        VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
        VavaMagic.core = {
            hooks = {
                runBefore = function() return true end,
                runAfter = function() return true end,
            },
        }
        VavaMagic.bridge = {
            GetCharacterId = function(src) return characters[src] end,
            IsDowned = function() return false end,
            Notify = function(src, message, kind) notified[#notified + 1] = { target = src, message = message, kind = kind } end,
            Hit = function(target, packet)
                hits[#hits + 1] = { target = target, packet = packet }
                if hitCode then return nil, hitCode end
                return hitResult or { applied = packet.amount, absorbed = 0, resisted = 0, added = 0, downed = false }
            end,
            ChainHealthPoints = function() return 100 end,
            GetHealth = function(src) return health[src] end,
            OnHit = function(handler)
                onHit = handler
                return true
            end,
            SetModifiers = function(list) modifiers = list end,
            db = { update = function() return 0 end },
        }
        VavaMagic.world = {
            position = function(src)
                local p = positions[src]
                return p and { x = p.x, y = p.y, z = p.z } or nil
            end,
            setState = function() end,
            inVehicle = function() return false end,
        }
        spellDefs = {}
        for name, spellCfg in pairs(cfg.spells) do
            spellDefs[name] = {
                config = spellCfg,
                begin = function() return true, {} end,
                finish = function() return { success = true } end,
            }
        end
        VavaMagic.spells = {
            get = function(name) return spellDefs[name] end,
            onLeave = function() end,
        }
        helper.loadAll({ 'modules/vava_magic/server/combat.lua', 'modules/vava_magic/server/protections.lua' })
        combat, protections = VavaMagic.combat, VavaMagic.protections
    end

    -- les doublures posées en global ne survivent pas à ces essais
    after_each(function()
        _G.TriggerClientEvent = nil
        VavaMagic = nil
    end)

    local function loadCasting()
        VavaMagic.sheets = {
            get = function(src)
                if not characters[src] then return nil end
                local list = {}
                for name in pairs(cfg.spells) do list[name] = { xp = 0 } end
                return { isMage = true, characterId = characters[src], spells = list }
            end,
        }
        VavaMagic.mana = {
            current = function() return 100 end,
            spend = function() return true end,
            give = function() end,
        }
        VavaMagic.experience = { grant = function() return 0 end }
        VavaMagic.progression = { levelOf = function() return 1 end, cost = function() return 5 end }
        helper.load('modules/vava_magic/server/casting.lua')
        casting = VavaMagic.casting
        assert.is_true(casting.start())
        assert.is_function(onHit)
    end

    local function cast(src, spell)
        local ok, info = casting.begin(src, spell)
        assert.is_true(ok, tostring(info))
        now = now + info.ms
        return info.id
    end

    describe('combat.damage', function()
        before_each(function() loadMagic() end)

        it('un coup par la chaîne : paquet du sort, source et personnage du lanceur', function()
            assert.is_true(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            assert.equal(1, #hits)
            local p = hits[1].packet
            assert.equal(VICTIM, hits[1].target)
            assert.same({
                amount = 12, kind = 'feu', source = CASTER, sourceCharacter = 42, spell = 'boule_de_feu',
                tags = { spell = true, ranged = true },
            }, p)
        end)

        it('chaque nature et chaque élément', function()
            combat.damage(CASTER, VICTIM, 'trait_de_glace', 5, combat.KIND.IMPACT)
            combat.damage(CASTER, VICTIM, 'secousse', 4, combat.KIND.ZONE, 42)
            combat.damage(CASTER, VICTIM, 'mur_de_flammes', 6, combat.KIND.AURA, 42)
            combat.damage(CASTER, VICTIM, 'projectile_de_roche', 2, combat.KIND.BURN, 42, 'feu')
            combat.damage(CASTER, VICTIM, 'vapeur', 1, combat.KIND.AURA, 42, 'eau')
            assert.equal('eau', hits[1].packet.kind)
            assert.same({ spell = true, area = true }, hits[2].packet.tags)
            assert.equal('terre', hits[2].packet.kind)
            assert.same({ spell = true, area = true, overTime = true }, hits[3].packet.tags)
            assert.equal('feu', hits[4].packet.kind)
            assert.same({ spell = true, overTime = true }, hits[4].packet.tags)
            assert.equal('eau', hits[5].packet.kind)
            assert.equal('vapeur', hits[5].packet.spell)
        end)

        it('les points de chaque niveau partent tels quels (une vie pleine au plus)', function()
            for _, level in ipairs(cfg.spells.projectile_de_roche.levels) do
                combat.damage(CASTER, VICTIM, 'projectile_de_roche', level.damage, combat.KIND.IMPACT)
                assert.equal(level.damage, hits[#hits].packet.amount)
            end
            combat.damage(CASTER, VICTIM, 'projectile_de_roche', 250, combat.KIND.IMPACT)
            assert.equal(100, hits[#hits].packet.amount)
        end)

        it('la victime réagit, sauf à une brûlure', function()
            combat.damage(CASTER, VICTIM, 'boule_de_feu', 8, combat.KIND.IMPACT)
            combat.damage(CASTER, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 42, 'feu')
            local reactions = 0
            for _, e in ipairs(clientEvents) do
                if e.event == VavaMagic.EVENTS.HIT then
                    reactions = reactions + 1
                    assert.equal(VICTIM, e.target)
                end
            end
            assert.equal(1, reactions)
        end)

        it('faux sans vie retirée : annulé, tout absorbé, refusé', function()
            hitResult = { applied = 0, absorbed = 12, resisted = 0, added = 0 }
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            hitResult = { applied = 0, cancelled = 'pvp_off' }
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            hitResult = { applied = 0, cancelled = 'source_downed' }
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            hitResult, hitCode = nil, 'too_many_hits'
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            assert.equal(0, #clientEvents)
        end)

        it('lanceur parti : source gardée, personnage du paquet ; autre personnage : plus de source', function()
            characters[CASTER] = nil
            combat.damage(CASTER, VICTIM, 'mur_de_flammes', 6, combat.KIND.AURA, 42)
            assert.equal(CASTER, hits[1].packet.source)
            assert.equal(42, hits[1].packet.sourceCharacter)
            characters[CASTER] = 99
            combat.damage(CASTER, VICTIM, 'mur_de_flammes', 6, combat.KIND.AURA, 42)
            assert.is_nil(hits[2].packet.source)
            assert.equal(42, hits[2].packet.sourceCharacter)
            combat.damage(0, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 0, 'feu')
            assert.is_nil(hits[3].packet.source)
            assert.is_nil(hits[3].packet.sourceCharacter)
        end)

        it('filtres de la magie avant la chaîne : pvp coupé, cible absente, points nuls', function()
            cfg.combat.pvp = false
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            cfg.combat.pvp = true
            assert.is_false(combat.damage(CASTER, 99, 'boule_de_feu', 12, combat.KIND.IMPACT))
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 0, combat.KIND.IMPACT))
            assert.equal(0, #hits)
        end)

        it('sans vava_health : aucun dégât, rien au client de la victime, le lanceur prévenu une fois par minute', function()
            hitCode = 'health_unavailable'
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT))
            assert.equal(0, #clientEvents)
            assert.equal(1, #notified)
            assert.equal(CASTER, notified[1].target)
            assert.equal(cfg.texts.notify.noHarm, notified[1].message)
            now = now + 60000
            combat.damage(CASTER, VICTIM, 'boule_de_feu', 12, combat.KIND.IMPACT)
            assert.equal(2, #notified)
        end)
    end)

    describe('modificateurs de la magie', function()
        it('bouclier et résistances déclarés ; zones de paix seulement s’il y en a', function()
            loadMagic()
            protections.start()
            assert.equal('bouclier', modifiers['vava_magic:protections'].stage)
            assert.equal('resistance', modifiers['vava_magic:resistances'].stage)
            assert.is_nil(modifiers['vava_magic:zones'])
            for key, def in pairs(modifiers) do
                assert.is_function(def.apply, key)
                assert.is_true(#def.label >= 1 and #def.label <= 48, key)
            end

            loadMagic({ { label = 'Chapelle', x = 0.0, y = 0.0, radius = 10.0 } })
            protections.start()
            local zones = modifiers['vava_magic:zones']
            assert.equal('annulation', zones.stage)
            assert.same({ cancel = 'zone_protegee' }, zones.apply({ target = VICTIM, kind = 'tranchant', amount = 10 }))
            assert.is_nil(zones.apply({ target = OTHER, kind = 'tranchant', amount = 10 }))
            assert.is_nil(zones.apply({ target = VICTIM, kind = 'privation', amount = 10 }))
        end)

        it('bouclier : absorbe sorts et lames, se brise et prévient son porteur', function()
            loadMagic()
            protections.start()
            local shield = modifiers['vava_magic:protections'].apply
            assert.is_nil(shield({ target = VICTIM, kind = 'feu', amount = 12 }))
            assert.is_not_nil(protections.shield(VICTIM, { points = 20 }))
            assert.same({ absorbed = 12 }, shield({ target = VICTIM, kind = 'feu', amount = 12 }))
            assert.equal(0, #notified)
            assert.same({ absorbed = 8 }, shield({ target = VICTIM, kind = 'tranchant', amount = 30 }))
            assert.equal(1, #notified)
            assert.equal(cfg.texts.notify.shieldBroken, notified[1].message)
            assert.is_nil(shield({ target = VICTIM, kind = 'tranchant', amount = 30 }))
            -- la faim n'est pas un coup
            protections.shield(VICTIM, { points = 20 })
            assert.is_nil(shield({ target = VICTIM, kind = 'privation', amount = 5 }))
            -- fin du bouclier
            now = now + cfg.protections.defaultDurationMs
            assert.is_nil(shield({ target = VICTIM, kind = 'feu', amount = 5 }))
            assert.equal(0, (protections.count(VICTIM)))
        end)

        it('résistance et faiblesse au type du coup', function()
            loadMagic()
            protections.start()
            local resist = modifiers['vava_magic:resistances'].apply
            assert.is_not_nil(protections.resist(VICTIM, { kind = 'feu', share = 0.4 }))
            assert.same({ resisted = 24 }, resist({ target = VICTIM, kind = 'feu', amount = 60 }))
            assert.is_nil(resist({ target = VICTIM, kind = 'tranchant', amount = 60 }))
            protections.clear(VICTIM)
            protections.resist(VICTIM, { kind = 'eau', share = -0.5 })
            assert.same({ added = 10 }, resist({ target = VICTIM, kind = 'eau', amount = 20 }))
        end)

        it('pose bornée : réserve, durée, type, nombre, personnage en jeu', function()
            loadMagic()
            local P = cfg.protections
            assert.is_nil(protections.shield(VICTIM, { points = 0 }))
            assert.is_nil(protections.shield(VICTIM, { points = P.maxPoints + 1 }))
            assert.is_nil(protections.shield(VICTIM, { points = 0 / 0 }))
            assert.is_nil(protections.shield(VICTIM, { points = 10, durationMs = P.maxDurationMs + 1 }))
            assert.is_nil(protections.shield(VICTIM, { points = 10, durationMs = 2.5 }))
            assert.is_nil(protections.shield(99, { points = 10 }))
            for _ = 1, P.maxShields do assert.is_not_nil(protections.shield(VICTIM, { points = 10 })) end
            local id, code = protections.shield(VICTIM, { points = 10 })
            assert.is_nil(id)
            assert.equal('too_many', code)
            assert.is_nil(protections.resist(VICTIM, { kind = 'tranchant', share = 0.5 }))
            assert.is_nil(protections.resist(VICTIM, { kind = 'feu', share = 0 }))
            assert.is_nil(protections.resist(VICTIM, { kind = 'feu', share = 1.5 }))
            assert.is_not_nil(protections.resist(VICTIM, { kind = 'feu', share = -1 }))
            local shields, points, resistances = protections.count(VICTIM)
            assert.equal(P.maxShields, shields)
            assert.equal(10 * P.maxShields, points)
            assert.equal(1, resistances)
            assert.is_true(protections.clear(VICTIM))
            assert.is_false(protections.clear(VICTIM))
        end)
    end)

    describe('incantation brisée par une blessure (sans lire le ped)', function()
        before_each(function()
            loadMagic()
            loadCasting()
        end)

        it('un coup qui retire de la vie au lanceur brise son incantation', function()
            local id = cast(CASTER, 'lueur')
            onHit({ target = CASTER, applied = 5 })
            local ok, code = casting.finish(CASTER, 'lueur', id)
            assert.is_false(ok)
            assert.equal('hurt', code)
        end)

        it('un coup sans vie retirée, ou sur un autre joueur, ne brise rien', function()
            local id = cast(CASTER, 'lueur')
            onHit({ target = CASTER, applied = 0, absorbed = 10 })
            onHit({ target = VICTIM, applied = 20 })
            onHit({ target = CASTER })
            local ok = casting.finish(CASTER, 'lueur', id)
            assert.is_true(ok)
        end)

        it('une vie de vava_health plus basse qu’au début la brise aussi ; plus haute (soin), non', function()
            local id = cast(CASTER, 'lueur')
            health[CASTER] = 0.8
            local ok, code = casting.finish(CASTER, 'lueur', id)
            assert.is_false(ok)
            assert.equal('hurt', code)
            now = now + 5000
            id = cast(CASTER, 'lueur')
            health[CASTER] = 0.9
            assert.is_true((casting.finish(CASTER, 'lueur', id)))
        end)

        it('sort qui ne craint pas la douleur (interruptOnHurt = false)', function()
            spellDefs.lueur.config = setmetatable({ interruptOnHurt = false }, { __index = cfg.spells.lueur })
            local id = cast(CASTER, 'lueur')
            onHit({ target = CASTER, applied = 5 })
            assert.is_true((casting.finish(CASTER, 'lueur', id)))
        end)

        it('sans vava_health : aucune vie connue, rien ne brise', function()
            health[CASTER] = nil
            local id = cast(CASTER, 'lueur')
            assert.is_true((casting.finish(CASTER, 'lueur', id)))
        end)
    end)
end)
