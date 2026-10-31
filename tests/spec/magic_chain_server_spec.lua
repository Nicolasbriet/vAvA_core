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
    local spellDefs, chainPvp, chainLaunched, ranks, staff, adminLogs

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
        chainPvp, chainLaunched, ranks, staff, adminLogs = true, true, {}, {}, {}

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
            ChainPvp = function() return chainPvp end,
            ChainKnowsLaunched = function() return chainLaunched end,
            RankLevel = function(src)
                if src == 0 then return math.huge end
                if ranks[src] == false then return false end
                return ranks[src] or 0
            end,
            IsStaff = function(src) return src == 0 or staff[src] == true end,
            IsAdmin = function() return true end,
            AdminLog = function(src, label, details) adminLogs[#adminLogs + 1] = { src = src, label = label, details = details } end,
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

        it('lanceur parti : source gardée, personnage du paquet ; autre personnage : coup refusé (S-1)', function()
            characters[CASTER] = nil
            combat.damage(CASTER, VICTIM, 'mur_de_flammes', 6, combat.KIND.AURA, 42)
            assert.equal(CASTER, hits[1].packet.source)
            assert.equal(42, hits[1].packet.sourceCharacter)
            -- le lanceur joue un autre personnage : son mur ne blesse plus (un coup sans source échapperait à
            -- chain.pvp, au débit par paire et au journal)
            characters[CASTER] = 99
            assert.is_false(combat.damage(CASTER, VICTIM, 'mur_de_flammes', 6, combat.KIND.AURA, 42))
            assert.equal(1, #hits)
            -- une brûlure sans lanceur connu reste un coup sans source
            combat.damage(0, VICTIM, 'boule_de_feu', 2, combat.KIND.BURN, 0, 'feu')
            assert.is_nil(hits[2].packet.source)
            assert.is_nil(hits[2].packet.sourceCharacter)
        end)

        it('coup déjà lancé : l’instant du lancement part avec le coup, si la chaîne le connaît', function()
            combat.damage(CASTER, VICTIM, 'projectile_de_roche', 14, combat.KIND.IMPACT, nil, nil, 4321)
            assert.equal(4321, hits[1].packet.launchedAt)
            assert.same({ spell = true, ranged = true, launched = true }, hits[1].packet.tags)
            combat.damage(CASTER, VICTIM, 'secousse', 4, combat.KIND.ZONE, 42, nil, 4000)
            assert.same({ spell = true, area = true, launched = true }, hits[2].packet.tags)
            -- sans instant : un coup ordinaire
            combat.damage(CASTER, VICTIM, 'nova_ardente', 10, combat.KIND.ZONE)
            assert.is_nil(hits[3].packet.launchedAt)
            assert.is_nil(hits[3].packet.tags.launched)
            -- vava_health 1.3.0 ne connaît pas l'étiquette (invalid_tags) : le coup part sans elle
            chainLaunched = false
            combat.damage(CASTER, VICTIM, 'projectile_de_roche', 14, combat.KIND.IMPACT, nil, nil, 4321)
            assert.is_nil(hits[4].packet.launchedAt)
            assert.is_nil(hits[4].packet.tags.launched)
        end)

        it('combats entre joueurs coupés par vava_health : aucun effet sans dégâts non plus (S-3)', function()
            assert.is_table(combat.affects(VICTIM))
            chainPvp = false
            assert.is_nil(combat.affects(VICTIM))
            chainPvp = true
            cfg.combat.pvp = false
            assert.is_nil(combat.affects(VICTIM))
            cfg.combat.pvp = true
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
            -- types couverts (R-1) : la résistance pour les seuls types auxquels on résiste ; le bouclier pour tous sauf
            -- la faim, la soif et les pertes natives
            assert.same(cfg.protections.kinds, modifiers['vava_magic:resistances'].kinds)
            local except = modifiers['vava_magic:protections'].exceptKinds
            assert.is_true(except.privation)
            assert.is_true(except.monde)
            assert.is_nil(except.feu)
            assert.is_nil(except.tranchant)

            loadMagic({ { label = 'Chapelle', x = 0.0, y = 0.0, radius = 10.0 } })
            protections.start()
            local zones = modifiers['vava_magic:zones']
            assert.equal('annulation', zones.stage)
            assert.same({ cancel = 'zone_protegee' }, zones.apply({ target = VICTIM, kind = 'tranchant', amount = 10 }))
            assert.is_nil(zones.apply({ target = OTHER, kind = 'tranchant', amount = 10 }))
            assert.is_nil(zones.apply({ target = VICTIM, kind = 'privation', amount = 10 }))
            assert.is_true(zones.exceptKinds.privation)
        end)

        it('zone de paix : l’attaquant posté dedans ne blesse personne au dehors (S-2)', function()
            loadMagic({ { label = 'Chapelle', x = 0.0, y = 0.0, radius = 2.0 } })
            protections.start()
            local zones = modifiers['vava_magic:zones'].apply
            -- CASTER (0, 0) dans la chapelle, VICTIM (5, 0) et OTHER (50, 0) dehors
            assert.same({ cancel = 'zone_protegee' },
                zones({ target = VICTIM, source = CASTER, kind = 'tranchant', amount = 10, origin = 'vava_combat' }))
            assert.is_nil(zones({ target = VICTIM, source = OTHER, kind = 'tranchant', amount = 10, origin = 'vava_combat' }))
            -- un sort a déjà vérifié sa cible : seule la place de son lanceur est relue (R-4)
            positions[VICTIM] = { x = 0.5, y = 0, z = 0 }
            assert.is_nil(zones({ target = VICTIM, source = OTHER, kind = 'feu', amount = 10, origin = 'vava_magic' }))
            assert.same({ cancel = 'zone_protegee' },
                zones({ target = VICTIM, source = OTHER, kind = 'feu', amount = 10, origin = 'vava_combat' }))
            -- se blesser soi-même dans la chapelle : seule la place de la cible compte
            assert.is_nil(zones({ target = OTHER, source = OTHER, kind = 'feu', amount = 1, origin = 'vava_combat' }))
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

    describe('/magie proteger : rangs du Conseil (S-7)', function()
        local run

        before_each(function()
            loadMagic()
            VavaMagic.sheets = { get = function(src) return characters[src] and { characterId = characters[src] } or nil end }
            for _, name in ipairs({ 'mana', 'casting', 'experience', 'registers', 'progression' }) do VavaMagic[name] = {} end
            local registered = {}
            _G.RegisterCommand = function(name, fn) registered[name] = fn end
            helper.load('modules/vava_magic/server/admin.lua')
            VavaMagic.admin.start()
            run = function(src, ...) registered[cfg.commands.admin](src, { ... }) end
        end)

        after_each(function() _G.RegisterCommand = nil end)

        local function shields(src) return (protections.count(src)) end

        it('un membre protège un rang plus bas que le sien, pas un égal ni un supérieur', function()
            ranks[CASTER], ranks[VICTIM], ranks[OTHER] = 2, 1, 2
            run(CASTER, 'proteger', tostring(VICTIM), 'bouclier', '10')
            assert.equal(1, shields(VICTIM))
            run(CASTER, 'proteger', tostring(OTHER), 'bouclier', '10')
            assert.equal(0, shields(OTHER))
            ranks[OTHER] = 3
            run(CASTER, 'proteger', tostring(OTHER), 'bouclier', '10')
            assert.equal(0, shields(OTHER))
            -- ni retirer celles d'un supérieur
            protections.shield(OTHER, { points = 10 })
            run(CASTER, 'proteger', tostring(OTHER), 'aucune')
            assert.equal(1, shields(OTHER))
            assert.equal(1, #adminLogs)
        end)

        it('se protéger soi-même ou poser une faiblesse : staff ; retirer les siennes : permis', function()
            ranks[CASTER], ranks[VICTIM] = 2, 0
            run(CASTER, 'proteger', 'bouclier', '10')
            assert.equal(0, shields(CASTER))
            run(CASTER, 'proteger', tostring(VICTIM), 'resistance', 'feu', '-50')
            assert.equal(0, select(3, protections.count(VICTIM)))
            run(CASTER, 'proteger', tostring(VICTIM), 'resistance', 'feu', '50')
            assert.equal(1, select(3, protections.count(VICTIM)))
            protections.shield(CASTER, { points = 10 })
            run(CASTER, 'proteger', 'aucune')
            assert.equal(0, shields(CASTER))
            staff[CASTER], ranks[CASTER] = true, 3
            run(CASTER, 'proteger', 'bouclier', '10')
            assert.equal(1, shields(CASTER))
            run(CASTER, 'proteger', tostring(VICTIM), 'resistance', 'eau', '-50')
            assert.equal(2, select(3, protections.count(VICTIM)))
        end)

        it('sans staff, sur soi, ne retirer que ce qui protège ; rang illisible : refusé (C-4)', function()
            ranks[CASTER], ranks[VICTIM] = 2, 0
            protections.shield(CASTER, { points = 10 })
            protections.resist(CASTER, { kind = 'feu', share = 0.5 })
            protections.resist(CASTER, { kind = 'eau', share = -0.5 })
            run(CASTER, 'proteger', 'aucune')
            local shieldsLeft, _, resistancesLeft = protections.count(CASTER)
            assert.equal(0, shieldsLeft)
            -- la faiblesse posée par un Souverain reste
            assert.equal(1, resistancesLeft)
            -- un Souverain retire tout, sur lui aussi
            staff[CASTER] = true
            run(CASTER, 'proteger', 'aucune')
            assert.equal(0, select(3, protections.count(CASTER)))
            staff[CASTER] = nil
            -- vava_admin tourne mais le rang de la cible est illisible : refusé
            ranks[VICTIM] = false
            run(CASTER, 'proteger', tostring(VICTIM), 'bouclier', '10')
            assert.equal(0, shields(VICTIM))
            ranks[VICTIM], ranks[CASTER] = 0, false
            run(CASTER, 'proteger', tostring(VICTIM), 'bouclier', '10')
            assert.equal(0, shields(VICTIM))
        end)

        it('la console peut tout', function()
            ranks[VICTIM] = 3
            -- la réponse à la console part par print : gardée hors de la sortie des essais
            local print = _G.print
            _G.print = function() end
            run(0, 'proteger', tostring(VICTIM), 'resistance', 'feu', '-20')
            _G.print = print
            assert.equal(1, select(3, protections.count(VICTIM)))
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

    describe('bridge : vocabulaire de la chaîne et types des modificateurs (R-1, S-3, S-5)', function()
        local Bridge, registryEntries, readyHooks, health, healthState

        local KINDS = { 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur',
            'privation', 'monde' }

        local function loadBridge(vocabulary)
            helper.reset()
            VavaMagic = nil
            helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
            VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
            registryEntries, readyHooks, healthState = {}, {}, 'started'
            health = {
                vocabulary = function() return vocabulary end,
                get = function() return { health = 0.5 } end,
            }
            _G.exports = { vava_health = setmetatable({}, { __index = function(_, fn)
                return function(_, ...) return health[fn](...) end
            end }) }
            _G.GetResourceState = function(name) return name == 'vava_health' and healthState or 'missing' end
            VavaMagic.core = {
                registry = {
                    exists = function() return true end,
                    has = function(_, key) return registryEntries[key] ~= nil end,
                    add = function(_, key, def)
                        registryEntries[key] = def
                        return true
                    end,
                },
                hooks = { after = function(name, fn)
                    readyHooks[#readyHooks + 1] = { name = name, fn = fn }
                    return #readyHooks
                end },
            }
            helper.load('modules/vava_magic/bridge/server.lua')
            Bridge = VavaMagic.bridge
            VavaMagic.ready = true
        end

        after_each(function()
            _G.exports, _G.GetResourceState = nil, nil
        end)

        local function definitions()
            return {
                ['vava_magic:protections'] = { stage = 'bouclier', label = 'b', apply = function() end,
                    exceptKinds = { privation = true, monde = true } },
                ['vava_magic:resistances'] = { stage = 'resistance', label = 'r', apply = function() end,
                    kinds = { 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'inconnu' } },
            }
        end

        it('déclare chaque modificateur avec les seuls types qu’il couvre, sans champ étranger au registre', function()
            loadBridge({ healthPoints = 100, kinds = KINDS, tags = { 'spell', 'launched' }, pvp = true })
            Bridge.SetModifiers(definitions())
            local shield = registryEntries['vava_magic:protections']
            assert.same({ 'tranchant', 'contondant', 'percant', 'feu', 'eau', 'terre', 'lumiere', 'esprit', 'pur' },
                shield.kinds)
            assert.is_nil(shield.exceptKinds)
            assert.same({ 'feu', 'eau', 'terre', 'lumiere', 'esprit' }, registryEntries['vava_magic:resistances'].kinds)
            assert.equal('bouclier', shield.stage)
            assert.is_function(shield.apply)
            assert.equal(100, Bridge.ChainHealthPoints())
            assert.is_true(Bridge.ChainKnowsLaunched())
            assert.is_true(Bridge.ChainPvp())
            assert.equal(0.5, Bridge.GetHealth(3))
        end)

        it('vava_health 1.3.0 : ni launched, ni pvp ; relu à son redémarrage', function()
            loadBridge({ healthPoints = 100, kinds = KINDS, tags = { 'spell' } })
            Bridge.SetModifiers(definitions())
            assert.is_false(Bridge.ChainKnowsLaunched())
            assert.is_true(Bridge.ChainPvp())
            -- redémarré en 1.4.0, combats entre joueurs coupés
            health.vocabulary = function()
                return { healthPoints = 100, kinds = KINDS, tags = { 'launched' }, pvp = false }
            end
            assert.is_true(Bridge.start())
            for _, hook in ipairs(readyHooks) do
                if hook.name == 'core:module:ready' then hook.fn({ name = 'vava_health' }) end
            end
            assert.is_true(Bridge.ChainKnowsLaunched())
            assert.is_false(Bridge.ChainPvp())
        end)

        it('sans chaîne connue (vava_health plus ancien), la vie n’est jamais demandée : get lisait le ped (S-5)', function()
            loadBridge(nil)
            health.vocabulary = function() error('export inconnu') end
            Bridge.SetModifiers(definitions())
            assert.is_nil(Bridge.ChainHealthPoints())
            assert.is_nil(Bridge.GetHealth(3))
            -- sans vocabulaire, les listes restent celles du module (aucune intersection possible)
            assert.is_nil(registryEntries['vava_magic:protections'].kinds)
        end)

        it('vocabulaire devenu illisible : tout revient aux valeurs par défaut (C-5)', function()
            loadBridge({ healthPoints = 100, kinds = KINDS, tags = { 'launched' }, pvp = false })
            Bridge.SetModifiers(definitions())
            assert.is_true(Bridge.ChainKnowsLaunched())
            assert.is_false(Bridge.ChainPvp())
            -- retour à une version plus ancienne de vava_health
            health.vocabulary = function() error('export inconnu') end
            for _, hook in ipairs(readyHooks) do
                if hook.name == 'core:module:ready' then hook.fn({ name = 'vava_health' }) end
            end
            assert.is_true(Bridge.start())
            for _, hook in ipairs(readyHooks) do
                if hook.name == 'core:module:ready' then hook.fn({ name = 'vava_health' }) end
            end
            assert.is_nil(Bridge.ChainHealthPoints())
            assert.is_false(Bridge.ChainKnowsLaunched())
            assert.is_true(Bridge.ChainPvp())
            assert.is_nil(Bridge.GetHealth(3))
        end)
    end)

    describe('combinaisons et effets sans dégâts (C-3)', function()
        local combos, stateCalls, has

        before_each(function()
            loadMagic({ { label = 'Chapelle', x = 0.0, y = 0.0, radius = 2.0 } })
            stateCalls, has = {}, {}
            VavaMagic.sheets = { discover = function() return false end }
            VavaMagic.states = {
                has = function(src, name) return has[src] and has[src][name] or false end,
                apply = function(src, name) stateCalls[#stateCalls + 1] = { 'apply', src, name } return true end,
                remove = function(src, name) stateCalls[#stateCalls + 1] = { 'remove', src, name } end,
            }
            VavaMagic.zones = { define = function() end }
            VavaMagic.world.broadcast = function() end
            helper.load('modules/vava_magic/server/combos.lua')
            combos = VavaMagic.combos
            -- le lanceur hors de la chapelle, la cible aussi
            positions[CASTER] = { x = 20, y = 0, z = 0 }
        end)

        it('combat.affects : refuse un lanceur qui joue un autre personnage, ou posté en zone de paix', function()
            assert.is_table(combat.affects(VICTIM, CASTER, 42))
            assert.is_nil(combat.affects(VICTIM, CASTER, 41))
            -- personnage inconnu (0) ou lanceur parti : comme pour un coup, pas de refus sur ce point
            assert.is_table(combat.affects(VICTIM, CASTER, 0))
            positions[CASTER] = { x = 0.5, y = 0, z = 0 }
            assert.is_nil(combat.affects(VICTIM, CASTER, 42))
            -- sur soi-même, la place du lanceur ne compte pas
            positions[VICTIM] = { x = 30, y = 0, z = 0 }
            positions[CASTER] = { x = 0.5, y = 0, z = 0 }
            assert.is_nil(combat.affects(CASTER, CASTER, 42))
        end)

        it('les états d’une combinaison attendent que le coup ait porté', function()
            has[VICTIM] = { wet = true }
            -- gel : rien n'est posé ni retiré avant le coup
            local hit = combos.hit(CASTER, VICTIM, 'trait_de_glace', 5, nil, 42)
            assert.equal(0, #stateCalls)
            combos.commit(hit)
            assert.same({ 'apply', VICTIM, 'frozen' }, stateCalls[1])
            assert.same({ 'remove', VICTIM, 'wet' }, stateCalls[2])
            assert.is_true(hit.frozen)
            -- une seule fois
            combos.commit(hit)
            assert.equal(2, #stateCalls)
            -- séchage : dégâts et brûlure réglés avant le coup, mouillé retiré seulement s'il a porté
            stateCalls = {}
            hit = combos.hit(CASTER, VICTIM, 'boule_de_feu', 12, nil, 42)
            assert.equal(6, hit.damage)
            assert.is_false(hit.burn)
            assert.equal(0, #stateCalls)
            -- lanceur qui joue un autre personnage : aucune combinaison
            hit = combos.hit(CASTER, VICTIM, 'trait_de_glace', 5, nil, 41)
            combos.commit(hit)
            assert.equal(0, #stateCalls)
            assert.equal(5, hit.damage)
        end)
    end)

    describe('projectiles : personnage du lanceur et instant du lancement (C-1, C-2)', function()
        local projectiles, bonuses, ping

        before_each(function()
            loadMagic()
            bonuses, ping = {}, 80
            _G.GetPlayerPing = function() return ping end
            for _, name in ipairs({ 'states', 'zones', 'combos', 'obstacles' }) do VavaMagic[name] = VavaMagic[name] or {} end
            VavaMagic.experience = { bonus = function(src, spell, xp) bonuses[#bonuses + 1] = { src, spell, xp } end }
            VavaMagic.spells.addRpc = function() end
            VavaMagic.spells.register = function() return true end
            helper.load('modules/vava_magic/server/projectiles.lua')
            projectiles = VavaMagic.projectiles
        end)

        after_each(function() _G.GetPlayerPing = nil end)

        it('instant du lancement joint seulement dans le temps d’un vol, plus la marge et le ping (sans la grâce)', function()
            local hit = setmetatable({}, { __index = cfg.projectiles })
            -- roche N1 : 18 m à 12 m/s, 1,5 s de vol
            local launch = { launchedAt = 1000, range = 18, speed = 12 }
            local limit = 1500 + hit.timeMarginMs + ping
            now = 1000 + limit
            assert.equal(1000, projectiles.strikeLaunchedAt(launch, hit, CASTER))
            now = 1000 + limit + 1
            assert.is_nil(projectiles.strikeLaunchedAt(launch, hit, CASTER))
            -- le ping compte au plus une seconde
            ping = 60000
            now = 1000 + 1500 + hit.timeMarginMs + 1000 + 1
            assert.is_nil(projectiles.strikeLaunchedAt(launch, hit, CASTER))
            -- la grâce de l'impact (3 s) n'est jamais comptée
            assert.is_true(1500 + hit.timeMarginMs + 1000 < 1500 + hit.launchGraceMs + 1000)
        end)

        it('bonus d’XP au seul personnage qui a lancé', function()
            projectiles.bonus({ source = CASTER, spell = 'boule_de_feu', rewarded = true, casterCharacter = 42 })
            assert.equal(1, #bonuses)
            characters[CASTER] = 99
            projectiles.bonus({ source = CASTER, spell = 'boule_de_feu', rewarded = true, casterCharacter = 42 })
            assert.equal(1, #bonuses)
        end)

        it('un impact compté après un changement de personnage ne blesse pas (personnage du lancement)', function()
            characters[CASTER] = 99
            assert.is_false(combat.damage(CASTER, VICTIM, 'boule_de_feu', 8, combat.KIND.IMPACT, 42, nil, 1000))
            assert.equal(0, #hits)
        end)
    end)
end)
