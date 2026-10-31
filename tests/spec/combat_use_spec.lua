local helper = require('tests.helper')

-- Un coup de technique côté serveur (modules/vava_combat/server/swings.lua, hands.lua, reactions.lua, strike.lua,
-- api.lua réels, T-112) avec des doublures : bridge (personnages, main tenue, positions et caps réglables, instances,
-- joueurs proches filtrés par instance et par rayon, à terre, véhicule, contrôle de la magie, hit qui note le paquet et
-- rend un résultat réglable, envoi de proximité qui note cibles et valeurs, notifications, hooks qui notent et peuvent
-- refuser, piles de la besace pour l'usure), horloge réglable et minuteries (SetTimeout) déclenchées à leur heure par
-- le test. Vérifie qu'aucun coup ne porte hors de portée, hors de l'arc, à travers le délai ni deux fois sur une même
-- cible. Règles documentées : docs/plan/specs/T-112.md § 7 et § 11.1 (tolérances resserrées : portée + 0,25 m, demi-angle
-- + 10°).

local A, B, C = 1, 2, 3
local CHAR_A, CHAR_B, CHAR_C = 100, 200, 300
local T0 = 100000

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

describe('vava_combat techniques (serveur)', function()
    local cfg, swings, hands, reactions, api, catalog
    local clock, timers, active, positions, headings, buckets, downed, vehicles, held, piles, magic
    local hits, hitAnswer, sent, notifies, befores, beforeAnswer, logs, calls, itemDefs, exported
    local realRandom = math.random
    local STUBBED = { 'SetTimeout', 'GetGameTimer', 'exports', 'GetInvokingResource' }
    -- fonctions du bridge qui appellent un autre module ou une native coûteuse (comptées)
    local COUNTED = { 'ActiveCharacterId', 'Held', 'IsDowned', 'InVehicle', 'MagicHardControl', 'RunBefore', 'Position',
        'Heading', 'PlayersNear' }

    local function pile(id, item, metadata)
        return { id = id, item = item, quantity = 1, metadata = metadata or {} }
    end

    --- Met une pile dans la besace et en main (sans passer par le hook : arme « en garde » d'emblée).
    local function arm(src, id, item)
        local entry = pile(id, item)
        piles[src][#piles[src] + 1] = entry
        held[src] = entry
        return entry
    end

    --- Avance l'horloge jusqu'à T0 + ms en déclenchant chaque minuterie à son heure, dans l'ordre.
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

    local function exportCalls()
        local total = 0
        for _, count in pairs(calls) do total = total + count end
        return total
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, timers = T0, {}
        active = { [A] = CHAR_A, [B] = CHAR_B, [C] = CHAR_C }
        positions = { [A] = { 0, 0, 0 }, [B] = { 0, 2, 0 }, [C] = { 30, 30, 0 } }
        headings = { [A] = 0, [B] = 180, [C] = 0 }
        buckets, downed, vehicles, held, piles, magic = {}, {}, {}, {}, { [A] = {}, [B] = {}, [C] = {} }, {}
        hits, hitAnswer, sent, notifies, befores, beforeAnswer = {}, nil, {}, {}, {}, nil
        logs, calls, exported = { warn = {}, info = {} }, {}, {}
        itemDefs = { epee_courte = { label = 'Épée courte', stack = 1, held = { model = 'w_me_machette_lr' } } }

        _G.GetGameTimer = function() return clock end
        _G.SetTimeout = function(ms, fn) timers[#timers + 1] = { due = clock + ms, fn = fn } end
        _G.exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })
        _G.GetInvokingResource = function() return 'vava_example_combat' end
        math.random = function() return 0.99 end   -- usure épargnée : les piles ne bougent pas

        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
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
                -- jamais à tous, jamais une liste
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
            HealthKinds = function() return { 'tranchant', 'contondant', 'percant' } end,
            DefineShieldField = function() return true end,
            Hit = function(target, packet)
                hits[#hits + 1] = { target = target, packet = copy(packet), at = clock - T0 }
                if hitAnswer then return hitAnswer(packet, target) end
                return { id = #hits, amount = packet.amount, applied = packet.amount, blocked = 0, absorbed = 0,
                    resisted = 0, added = 0, downed = false, health = 0.5 }
            end,
            RunBefore = function(name, payload)
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end,
            RunAfter = function() end,
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
            'modules/vava_combat/server/swings.lua',
            'modules/vava_combat/server/api.lua',
        })
        catalog, swings, hands = VavaCombat.catalog, VavaCombat.swings, VavaCombat.hands
        reactions, api = VavaCombat.reactions, VavaCombat.api
        local ok, err = catalog.setup()
        assert.is_true(ok, err)
        assert.equal(0, #logs.warn, logs.warn[1])
        VavaCombat.ready = true
        arm(A, 10, 'epee_courte')
        calls = {}
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        math.random = realRandom
        VavaCombat = nil
    end)

    describe('un coup qui porte', function()
        it('Taille sur B à 2 m : un hit à l\'ouverture de la frappe, un envoi aux proches, rien au second relevé', function()
            assert.same({ true }, use(A, 'taille_descendante', B))
            at(319)
            assert.equal(0, #hits)
            at(320)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            assert.same({ amount = 12, kind = 'tranchant', source = A, weapon = 'epee_courte',
                technique = 'taille_descendante', tags = { melee = true, parryable = true } }, hits[1].packet)
            assert.equal(1, #sent)
            assert.same({ bucket = 0, coords = { x = 0, y = 2, z = 0 }, radius = 30.0, event = 'vava_combat:hit',
                args = { A, B, 'hit' } }, sent[1])
            at(480)
            assert.equal(1, #hits)
            assert.equal(1, #sent)
            assert.equal(0, #timers)
        end)

        it('le Fendant n\'est pas parable : aucune étiquette parryable, dégâts × 1,8', function()
            use(A, 'fendant', B)
            at(650)
            assert.same({ melee = true }, hits[1].packet.tags)
            assert.equal(21.6, hits[1].packet.amount)
        end)

        it('B entre dans l\'arc entre les deux relevés : touché au second ; B sorti avant le premier : rien', function()
            positions[B] = { 0, 3, 0 }
            use(A, 'taille_descendante', B)
            at(320)
            assert.equal(0, #hits)
            positions[B] = { 0, 2, 0 }
            at(480)
            assert.equal(1, #hits)
            assert.equal(480, hits[1].at)

            hits, sent = {}, {}
            at(1000)
            use(A, 'taille_descendante', B)
            positions[B] = { 0, 4, 0 }   -- B recule pendant la préparation
            at(2000)
            assert.equal(0, #hits)
            assert.equal(0, #sent)
        end)

        it('le relevé de la main suffit : strike.run ne relit ni la pile ni le personnage de l\'attaquant', function()
            use(A, 'taille_descendante', B)
            calls = {}
            at(320)
            assert.equal(1, #hits)
            assert.equal(1, calls.Held)
        end)
    end)

    describe('hors de portée, hors de l\'arc : jamais touché', function()
        local cases = {
            { 'à 2,46 m (portée 2,2 + 0,25)', function() positions[B] = { 0, 2.46, 0 } end },
            { 'à 50° de l\'avant (demi-angle 35 + 10)', function()
                local r = math.rad(50)
                positions[B] = { -math.sin(r) * 2, math.cos(r) * 2, 0 }
            end },
            { 'à 60° de l\'avant', function() positions[B] = { -math.sin(math.rad(60)) * 2, math.cos(math.rad(60)) * 2, 0 } end },
            { 'derrière à 1 m', function() positions[B] = { 0, -1, 0 } end },
            { '2,1 m plus haut', function() positions[B] = { 0, 1.5, 2.1 } end },
            { 'dans une autre instance', function() buckets[B] = 5 end },
            { 'à terre', function() downed[B] = true end },
            { 'en véhicule', function() vehicles[B] = true end },
            { 'sans personnage', function() active[B] = nil end },
        }
        for _, case in ipairs(cases) do
            it('B ' .. case[1] .. ' : aucun hit ; C valable derrière lui touché à sa place', function()
                case[2]()
                use(A, 'taille_descendante', B)
                at(1000)
                assert.equal(0, #hits)
                assert.equal(0, #sent)

                positions[C] = { 0.3, 1.2, 0 }
                at(1000)
                use(A, 'taille_descendante', B)
                at(2000)
                assert.equal(1, #hits)
                assert.equal(C, hits[1].target)
            end)
        end

        it('l\'Épée courte au contact (0,5 m) touche même derrière', function()
            positions[B] = { 0, -0.5, 0 }
            use(A, 'taille_descendante', B)
            at(320)
            assert.equal(1, #hits)
        end)

        it('le cap lu par le serveur compte, pas celui du client', function()
            positions[B] = { -2, 0, 0 }
            use(A, 'taille_descendante', B)
            at(1000)
            assert.equal(0, #hits)
            headings[A] = 90
            use(A, 'taille_descendante', B)
            at(1320)
            assert.equal(1, #hits)
        end)

        it('B et C dans l\'arc, B verrouillé mais plus excentré : B seul touché (un adversaire par coup)', function()
            positions[B] = { -0.8, 1.8, 0 }
            positions[C] = { 0, 2.0, 0 }
            use(A, 'taille_descendante', B)
            at(1000)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            -- sans verrou : le plus en face
            hits = {}
            use(A, 'taille_descendante', 0)
            at(2000)
            assert.equal(1, #hits)
            assert.equal(C, hits[1].target)
        end)

        it('une cible annoncée qui n\'est pas un joueur en jeu est ignorée, sans erreur', function()
            assert.same({ true }, use(A, 'taille_descendante', 999))
            at(320)
            assert.equal(B, hits[1].target)
            assert.is_nil(befores[1].payload.target)
            at(1000)
            assert.same({ true }, use(A, 'taille_descendante', A))
            assert.is_nil(befores[2].payload.target)
        end)
    end)

    describe('refus, dans l\'ordre', function()
        it('technique inconnue, type de défense, pas l\'ouvreur, coup en cours : aucun export appelé', function()
            cfg.techniques.garde_haute = copy(cfg.techniques.revers)
            cfg.techniques.garde_haute.type = 'garde'
            assert.same({ false, 'unknown_technique' }, use(A, 'moulinet'))
            assert.same({ false, 'not_attack' }, use(A, 'garde_haute'))
            assert.same({ false, 'not_opener' }, use(A, 'estoc_rapide'))
            assert.equal(0, exportCalls())
            assert.same({ true }, use(A, 'taille_descendante'))
            calls = {}
            at(200)
            assert.same({ false, 'busy', 640 }, use(A, 'taille_descendante'))
            assert.equal(0, exportCalls())
        end)

        it('chancelant, ou arme prise il y a 500 ms (attente 300) : aucun export appelé', function()
            reactions.stagger(A, 900, clock)
            assert.same({ false, 'staggered', 900 }, use(A, 'taille_descendante'))
            at(5000)
            hands.onHold({ source = A, instanceId = 10, item = 'epee_courte', previous = 0 })
            at(5500)
            assert.same({ false, 'drawing', 300 }, use(A, 'taille_descendante'))
            assert.equal(0, exportCalls())
        end)

        it('rien en main, Épée longue, Dague : no_weapon, no_style, no_style', function()
            held[A] = nil
            assert.same({ false, 'no_weapon' }, use(A, 'taille_descendante'))
            held[A] = pile(11, 'hache_fer')
            assert.same({ false, 'no_weapon' }, use(A, 'taille_descendante'))
            arm(A, 12, 'epee_longue')
            assert.same({ false, 'no_style' }, use(A, 'taille_descendante'))
            arm(A, 13, 'dague')
            assert.same({ false, 'no_style' }, use(A, 'taille_descendante'))
            assert.equal(0, #timers)
        end)

        it('technique d\'un autre style avec une Épée : not_in_style', function()
            cfg.styles.hache_une_main = { label = 'Hache', keys = { legere = 'coup_de_hache' } }
            cfg.techniques.coup_de_hache = copy(cfg.techniques.revers)
            cfg.techniques.coup_de_hache.style = 'hache_une_main'
            assert.same({ false, 'not_in_style' }, use(A, 'coup_de_hache'))
        end)

        it('personnage absent, à terre, en véhicule, gelé par la magie', function()
            active[A] = nil
            assert.same({ false, 'no_character' }, use(A, 'taille_descendante'))
            active[A] = CHAR_A
            downed[A] = true
            assert.same({ false, 'downed' }, use(A, 'taille_descendante'))
            downed[A] = nil
            vehicles[A] = true
            assert.same({ false, 'vehicle' }, use(A, 'taille_descendante'))
            vehicles[A] = nil
            magic[A] = 'frozen'
            assert.same({ false, 'controlled' }, use(A, 'taille_descendante'))
            assert.equal(0, #befores)
            assert.equal(0, #timers)
        end)

        it('crochet vava_combat:using qui refuse : refused et sa raison, nettoyée', function()
            beforeAnswer = { false, 'Vous êtes au cachot.\n' }
            assert.same({ false, 'refused', 'Vous êtes au cachot.' }, use(A, 'taille_descendante', B))
            assert.same({ name = 'vava_combat:using', payload = { source = A, characterId = CHAR_A,
                technique = 'taille_descendante', item = 'epee_courte', target = B } }, befores[1])
            beforeAnswer = { false, { 'pas une chaîne' } }
            assert.same({ false, 'refused' }, use(A, 'taille_descendante'))
            assert.equal(0, #timers)
        end)

        it('module pas prêt : not_ready', function()
            VavaCombat.ready = false
            assert.same({ false, 'not_ready' }, use(A, 'taille_descendante'))
        end)
    end)

    describe('annulations', function()
        it('arme reposée (hook hold) avant l\'ouverture : aucun hit', function()
            use(A, 'taille_descendante', B)
            at(100)
            hands.onHold({ source = A, instanceId = 0, previous = 10 })
            held[A] = nil
            at(1000)
            assert.equal(0, #hits)
        end)

        it('arme échangée sans hook vu : la pile relue au relevé n\'est plus la même, aucun hit', function()
            use(A, 'taille_descendante', B)
            held[A] = pile(14, 'epee_courte')
            at(1000)
            assert.equal(0, #hits)
        end)

        it('A mis à terre (hook downed), ou personnage changé : aucun hit', function()
            use(A, 'taille_descendante', B)
            swings.onDowned(A)
            at(1000)
            assert.equal(0, #hits)
            use(A, 'taille_descendante', B)
            active[A] = 101
            at(2000)
            assert.equal(0, #hits)
        end)

        it('A déplacé de 4 m en 320 ms : aucun hit, une ligne de console ; deux fois en une minute : une seule', function()
            use(A, 'taille_descendante', B)
            positions[A] = { 0, 4, 0 }
            positions[B] = { 0, 6, 0 }
            at(1000)
            assert.equal(0, #hits)
            assert.equal(1, #logs.warn)
            assert.matches('bond invraisemblable', logs.warn[1])
            positions[A] = { 0, 0, 0 }
            use(A, 'taille_descendante', B)
            positions[A] = { 0, 4, 0 }
            at(2000)
            assert.equal(0, #hits)
            assert.equal(1, #logs.warn)
        end)

        it('un pas de 2 m pendant la préparation reste plausible : le coup porte', function()
            use(A, 'taille_descendante', B)
            positions[A] = { 0, 1, 0 }
            positions[B] = { 0, 3, 0 }
            at(320)
            assert.equal(1, #hits)
        end)

        it('départ du joueur pendant la préparation : aucun hit, rien en attente ne frappe', function()
            use(A, 'fendant', B)
            swings.forget(A)
            hands.forget(A)
            reactions.forget(A)
            at(2000)
            assert.equal(0, #hits)
        end)
    end)

    describe('enchaînement', function()
        it('Taille à 0, Estoc à 420 : relevés de la Taille à 320 et 480, de l\'Estoc à 640 et 760', function()
            local sampled = {}
            local realHeld = VavaCombat.bridge.Held
            VavaCombat.bridge.Held = function(src)
                sampled[#sampled + 1] = clock - T0
                return realHeld(src)
            end
            use(A, 'taille_descendante', B)
            at(420)
            assert.same({ true }, use(A, 'estoc_rapide', B))
            at(2000)
            assert.same({ 0, 320, 420, 480, 640, 760 }, sampled)
            assert.equal(2, #hits)
            assert.same({ 320, 640 }, { hits[1].at, hits[2].at })
            assert.equal(9.6, hits[2].packet.amount)
        end)

        it('quatre coups enchaînés en rythme, puis chain_limit jusqu\'à la fin de la récupération', function()
            use(A, 'taille_descendante', B)       -- 0 → frappe finie 480, fin 900
            at(420)
            assert.same({ true }, use(A, 'estoc_rapide', B))    -- 420 → frappe finie 760, fin 1140
            at(700)
            assert.same({ true }, use(A, 'revers', B))          -- 700 → frappe finie 1140, fin 1600
            at(1080)
            assert.same({ true }, use(A, 'taille_descendante', B)) -- 1080 → frappe finie 1560, fin 1980
            at(1560)
            assert.same({ false, 'chain_limit', 360 }, use(A, 'estoc_rapide', B))
            at(1920)
            assert.same({ true }, use(A, 'taille_descendante', B))
            at(5000)
            assert.equal(5, #hits)
        end)

        it('martèlement à 10 par seconde : jamais deux coups dans une même préparation', function()
            local accepted = 0
            for step = 0, 49 do
                at(step * 100)
                if swings.use(A, 'taille_descendante', B) == true then accepted = accepted + 1 end
            end
            at(10000)
            -- une Taille dure 900 ms (840 avec la gigue admise) : 6 coups en 5 s au plus
            assert.is_true(accepted <= 6, tostring(accepted))
            assert.equal(accepted, #hits)
        end)
    end)

    describe('issues et réactions', function()
        local function strikeWith(answer)
            hitAnswer = function() return answer end
            hits, sent = {}, {}
            use(A, 'taille_descendante', B)
            at(clock - T0 + 900)
        end

        it('esquive → dodge, coup bloqué → block, coup qui met à terre → down', function()
            strikeWith({ id = 1, amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive', downed = false })
            assert.same({ A, B, 'dodge' }, sent[1].args)
            strikeWith({ id = 2, amount = 0, applied = 0, blocked = 12, absorbed = 0, downed = false })
            assert.same({ A, B, 'block' }, sent[1].args)
            strikeWith({ id = 3, amount = 12, applied = 12, blocked = 0, absorbed = 0, downed = true })
            assert.same({ A, B, 'down' }, sent[1].args)
        end)

        it('combats coupés : aucun envoi, un seul avis à l\'attaquant pour trois coups en 10 s', function()
            for _ = 1, 3 do strikeWith({ id = 1, amount = 0, applied = 0, cancelled = 'pvp_off', downed = false }) end
            assert.equal(0, #sent)
            assert.equal(1, #notifies)
            assert.same({ target = A, text = cfg.messages.pvpOff, kind = 'info' }, notifies[1])
            at(clock - T0 + 10000)
            strikeWith({ id = 1, amount = 0, applied = 0, cancelled = 'pvp_off', downed = false })
            assert.equal(2, #notifies)
        end)

        it('lieu de paix, crochet de la chaîne : avis propres ; trop de coups : rien', function()
            strikeWith({ id = 1, amount = 0, applied = 0, cancelled = 'zone_protegee', stage = 'annulation' })
            strikeWith({ id = 1, amount = 0, applied = 0, cancelled = 'treve', stage = 'before' })
            assert.same({ cfg.messages.peace, cfg.messages.held }, { notifies[1].text, notifies[2].text })
            hitAnswer = nil
            VavaCombat.bridge.Hit = function() return nil, 'too_many_hits' end
            hits, sent = {}, {}
            use(A, 'taille_descendante', B)
            at(clock - T0 + 900)
            assert.equal(0, #sent)
            assert.equal(2, #notifies)
        end)

        it('Fendant : B chancelle, ne frappe plus 900 ms, son coup en préparation est coupé ; immunité ensuite', function()
            arm(B, 20, 'epee_courte')
            assert.same({ true }, use(A, 'fendant', B))      -- frappe à 650
            at(400)
            assert.same({ true }, use(B, 'taille_descendante', A)) -- frappe à 720
            at(650)
            assert.same({ A, B, 'stagger' }, sent[1].args)
            at(1000)
            assert.equal(1, #hits)                             -- le coup de B n'a pas porté
            assert.same({ false, 'staggered', 550 }, use(B, 'taille_descendante', A))
            at(1550)
            assert.same({ true }, use(B, 'taille_descendante', A))
            at(1999)
            -- second Fendant à 2 s : frappe à 2,65 s, B encore immunisé (jusqu'à 0,65 + 0,9 + 3 = 4,55 s)
            hits, sent = {}, {}
            at(2000)
            use(A, 'fendant', B)
            at(3000)
            assert.same({ A, B, 'hit' }, sent[1].args)
            -- à 4 s : frappe à 4,65 s, l'immunité est passée
            at(4000)
            use(A, 'fendant', B)
            at(5000)
            assert.same({ A, B, 'stagger' }, sent[2].args)
        end)

        it('l\'envoi part toujours dans l\'instance de l\'attaquant, autour de la cible', function()
            buckets[A], buckets[B] = 3, 3
            use(A, 'taille_descendante', B)
            at(320)
            assert.equal(3, sent[1].bucket)
            assert.same({ x = 0, y = 2, z = 0 }, sent[1].coords)
        end)
    end)

    describe('dégainer et rengainer', function()
        it('arme prise à t : refus drawing jusqu\'à t + 799, admis à t + 800', function()
            at(1000)
            hands.onHold({ source = A, instanceId = 10, item = 'epee_courte', previous = 0 })
            at(1799)
            assert.same({ false, 'drawing', 1 }, use(A, 'taille_descendante'))
            at(1800)
            assert.same({ true }, use(A, 'taille_descendante'))
        end)

        it('arme reposée : armed() dit « mains prises » 1 500 ms, puis plus rien', function()
            assert.equal('epee_courte', api.armed(A).item)
            at(2000)
            hands.onHold({ source = A, instanceId = 0, previous = 10 })
            held[A] = nil
            assert.same({ item = 'epee_courte', category = 'une_main', family = 'epee', sheathing = true,
                readyInMs = 1500 }, api.armed(A))
            at(3499)
            assert.equal(1, api.armed(A).readyInMs)
            at(3500)
            assert.same({ nil, 'no_weapon' }, { api.armed(A) })
        end)

        it('reposée puis Dague prise : armed() rend la Dague, sans rengainement', function()
            hands.onHold({ source = A, instanceId = 0, previous = 10 })
            local dague = arm(A, 15, 'dague')
            hands.onHold({ source = A, instanceId = dague.id, item = 'dague', previous = 0 })
            local armed = api.armed(A)
            assert.equal('dague', armed.item)
            assert.is_nil(armed.sheathing)
        end)

        it('arme déjà en main à l\'apparition (aucun hook) : apprise à l\'apparition, rengainement au dépôt', function()
            hands.onHold({ source = A, instanceId = 0, previous = 10 })
            assert.same({ nil, 'no_weapon' }, { (function() held[A] = nil return api.armed(A) end)() })
            held[A] = piles[A][1]
            hands.learn(A)
            hands.onHold({ source = A, instanceId = 0, previous = 10 })
            held[A] = nil
            assert.is_true(api.armed(A).sheathing)
        end)

        it('un outil pris après l\'arme : rengainement aussi ; pile partie (gone) : rengainement', function()
            assert.equal('epee_courte', api.armed(A).item)   -- arme apprise à la lecture de la main
            hands.onHold({ source = A, instanceId = 30, item = 'hache_fer', previous = 10 })
            held[A] = pile(30, 'hache_fer')
            assert.is_true(api.armed(A).sheathing)
            at(5000)
            hands.onHold({ source = A, instanceId = 10, item = 'epee_courte', previous = 30 })
            held[A] = piles[A][1]
            hands.onHold({ source = A, instanceId = 0, previous = 10, reason = 'gone' })
            held[A] = nil
            assert.is_true(api.armed(A).sheathing)
        end)

        it('mains vides sans arme connue : rien à rengainer', function()
            hands.forget(A)
            held[A] = nil
            hands.onHold({ source = A, instanceId = 0, previous = 0 })
            assert.same({ nil, 'no_weapon' }, { api.armed(A) })
        end)
    end)

    describe('exports des techniques', function()
        it('techniques() : copies par style puis libellé ; technique(id) : copie ou nil', function()
            local list = exported.techniques()
            local ids = {}
            for i, entry in ipairs(list) do ids[i] = entry.id end
            assert.same({ 'estoc_rapide', 'fendant', 'revers', 'taille_descendante' }, ids)
            local taille = exported.technique('taille_descendante')
            assert.equal('Taille descendante', taille.label)
            assert.same({ windup = 320, active = 160, recovery = 420 }, taille.phases)
            taille.phases.windup = 1
            assert.equal(320, cfg.techniques.taille_descendante.phases.windup)
            assert.is_nil(exported.technique('moulinet'))
            assert.is_nil(exported.technique(42))
        end)
    end)
end)
