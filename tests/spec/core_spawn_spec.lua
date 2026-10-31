local helper = require('tests.helper')

-- Apparition confirmée par le serveur (server/players/spawn.lua, core 0.14.0, T-139), au regard des sections
-- « core.characters » et « Hooks émis par le core » de docs/api.md : la déclaration du client ne suffit plus, le serveur
-- lit le ped et ne confirme qu'après l'avoir vu au point ordonné ; d'office après le délai de grâce sans déclaration.
-- Le temps de jeu (playtime.lua), les positions (positions.lua) et les joueurs proches (net.lua) sont les vrais
-- fichiers du core : ils ne croient que la confirmation. Natives, sync, zones et liste des personnages sont des
-- doublures ; les minuteries (SetTimeout) sont déclenchées à la main.
describe('vAvA.spawn', function()
    local spawn, playtime, positions, net, cfg, now, sent, printed, peds, coords, current, abandoned, refreshed
    local active, hookCalls, realPrint, dispatchFails, sessions, reads

    local SRC = 1
    local FAR = { x = 1200.0, y = 300.0, z = 40.0 }   -- ancien emplacement du ped (personnage précédent)

    before_each(function()
        helper.reset()
        now = 1000
        sent, printed, peds, coords, current, abandoned, refreshed, active, hookCalls = {}, {}, {}, {}, {}, {}, {}, {}, {}
        sessions, reads = {}, {}
        dispatchFails = false
        realPrint = _G.print
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        _G.GetGameTimer = function() return now end
        -- ordre impossible à envoyer : le joueur n'existe plus pour FXServer au moment de l'envoi
        _G.DoesPlayerExist = function(src) return src >= 1 and src <= 3 and not dispatchFails end
        _G.GetPlayerPed = function(src)
            reads[src] = (reads[src] or 0) + 1   -- lectures du ped par le serveur
            return peds[src] or 0
        end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function(ped) return coords[ped] end
        _G.GetEntityHeading = function() return 90.0 end
        _G.GetPlayerRoutingBucket = function() return 0 end
        _G.TriggerClientEvent = function(event, target, ...)
            sent[#sent + 1] = { event = event, target = target, args = { ... } }
        end
        _G.TriggerLatentClientEvent = function() error('aucun envoi latent attendu') end
        _G.msgpack = nil
        _G.TriggerClientEventInternal = nil
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'config/server.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
        })
        vAvA.sync = {
            isCurrent = function(character) return current[character.source] == character end,
            abandon = function(character, event, code) abandoned[#abandoned + 1] = { character, event, code } end,
        }
        vAvA.zones = { refreshPlayer = function(src) refreshed[#refreshed + 1] = src end }
        vAvA.characters = {
            forEachActive = function(fn) for i = 1, #active do fn(active[i]) end end,
        }
        -- sessions des joueurs : seul un personnage dont la session est active sur lui est confirmé
        vAvA.accounts = { get = function(src) return sessions[src] end }
        helper.loadAll({
            'server/players/playtime.lua',
            'server/players/positions.lua',
            'server/players/spawn.lua',
        })
        spawn, playtime, positions, net = vAvA.spawn, vAvA.playtime, vAvA.positions, vAvA.net
        cfg = vAvA.config.server.spawn.confirm
        assert.is_true(vAvA.hooks.subscribe('vava_test', 'after', 'core:character:spawned', function(payload)
            hookCalls[#hookCalls + 1] = payload
        end) ~= nil)
    end)

    after_each(function()
        _G.print = realPrint
    end)

    --- Personnage actif (chargé, courant) du joueur `src`, ped à l'ancien emplacement.
    local function newCharacter(src, id)
        local character = {
            id = id or 7, accountId = 3, source = src or SRC, sex = 'f', firstName = 'Aela', lastName = 'Vorn',
            data = {}, revision = 0, savedRevision = 0, spawned = false, playSeconds = 0,
        }
        current[character.source] = character
        active[#active + 1] = character
        sessions[character.source] = { source = character.source, accountId = 3, state = 'active', characterId = character.id }
        peds[character.source] = 100 + character.source
        coords[100 + character.source] = { x = FAR.x, y = FAR.y, z = FAR.z }
        return character
    end

    --- Numéro du dernier ordre d'apparition envoyé au joueur `src` (nil : aucun).
    local function lastOrder(src)
        for i = #sent, 1, -1 do
            if sent[i].target == src and sent[i].event == vAvA.EVENTS.SPAWN then return sent[i].args[1].seq end
        end
        return nil
    end

    --- Déclaration du client, avec le numéro du dernier ordre qu'il a reçu (ce que fait le client du core).
    local function claim(character)
        return spawn.claim(character, lastOrder(character.source))
    end

    --- Place le ped (ce que le serveur lira par OneSync) ; la position gardée 50 ms par core.net est oubliée.
    local function move(src, x, y, z)
        coords[100 + src] = { x = x, y = y, z = z }
        net.forgetPosition(src)
    end

    --- Fait passer le temps puis déclenche les minuteries en attente (une seule échéance de lecture à la fois).
    local function advance(ms)
        now = now + ms
        local due = helper.timers
        helper.timers = {}
        for i = 1, #due do due[i].fn() end
    end

    local function printedMatching(text)
        local count = 0
        for _, line in ipairs(printed) do
            if line:find(text, 1, true) then count = count + 1 end
        end
        return count
    end

    local function order(character, point)
        if point then return spawn.at(character, point) end
        spawn.forCharacter(character)
        return true
    end

    local POINT = { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 }

    describe('réglages', function()
        it('accepte la config livrée, au-delà du plus long chargement normal du client', function()
            assert.same({ true }, { spawn.validateConfig() })
            local client = vAvA.config.shared.spawn
            local longest = client.fadeMs * 4 + client.modelTimeoutMs + client.collisionTimeoutMs
            assert.is_true(cfg.graceMs > longest)
        end)

        it('refuse des réglages invalides', function()
            local saved = {
                checkMs = cfg.checkMs, radius = cfg.radius, graceMs = cfg.graceMs, lateCheckMs = cfg.lateCheckMs,
                maxPerCheck = cfg.maxPerCheck,
            }
            for _, case in ipairs({
                { checkMs = 0 }, { checkMs = 10 }, { checkMs = 500.5 }, { radius = 0 }, { radius = -1 },
                { radius = 0 / 0 }, { radius = math.huge }, { graceMs = 100 }, { graceMs = 'x' },
                -- bornes hautes (relecture sécurité S-5) et réglages des suites réseau (R-1, R-2)
                { checkMs = 5001 }, { radius = 50.01 }, { graceMs = 120001 }, { lateCheckMs = 100 },
                { lateCheckMs = 60001 }, { lateCheckMs = 'absent' }, { maxPerCheck = 0 }, { maxPerCheck = 1025 },
                { maxPerCheck = 2.5 }, { maxPerCheck = 'absent' },
                -- bornes basses (contre-relecture C-1) : rayon d'au moins 1 m, délai de grâce d'au moins 5 s et du plus
                -- long chargement du client (17 s avec config/shared.lua)
                { radius = 0.99 }, { radius = 0.01 }, { graceMs = 50 }, { graceMs = 4999 }, { graceMs = 16999 },
            }) do
                for key, value in pairs(case) do
                    if value == 'absent' then cfg[key] = nil else cfg[key] = value end
                end
                local ok, err = spawn.validateConfig()
                assert.is_false(ok)
                assert.is_string(err)
                for key, value in pairs(saved) do cfg[key] = value end
            end
        end)

        it('accepte les bornes des réglages (relecture sécurité S-5)', function()
            cfg.checkMs, cfg.radius, cfg.graceMs, cfg.lateCheckMs, cfg.maxPerCheck = 5000, 50, 120000, 60000, 1024
            assert.same({ true }, { spawn.validateConfig() })
            local client = vAvA.config.shared.spawn
            local longest = client.fadeMs * 4 + client.modelTimeoutMs + client.collisionTimeoutMs
            cfg.checkMs, cfg.radius, cfg.graceMs, cfg.lateCheckMs, cfg.maxPerCheck = 50, 1, longest, 50, 1
            assert.same({ true }, { spawn.validateConfig() })
            -- client au chargement plus court que 5 s : le délai de grâce garde 5 s au moins (contre-relecture C-1)
            client.fadeMs, client.modelTimeoutMs, client.collisionTimeoutMs = 100, 1000, 1000
            cfg.graceMs = 4999
            assert.is_false((spawn.validateConfig()))
            cfg.graceMs = 5000
            assert.same({ true }, { spawn.validateConfig() })
            -- config du client illisible : 5 s au moins
            client.modelTimeoutMs = 'x'
            assert.same({ true }, { spawn.validateConfig() })
            cfg.graceMs = 4999
            assert.is_false((spawn.validateConfig()))
        end)
    end)

    describe('règles pures', function()
        it('inPlace : écart horizontal seulement, bord compris, pas de ped refusé', function()
            assert.is_true(spawn.inPlace(POINT, { x = POINT.x, y = POINT.y, z = POINT.z - 80 }, 10))
            assert.is_true(spawn.inPlace(POINT, { x = POINT.x + 6, y = POINT.y + 8, z = POINT.z }, 10))
            assert.is_false(spawn.inPlace(POINT, { x = POINT.x + 6, y = POINT.y + 8.01, z = POINT.z }, 10))
            assert.is_false(spawn.inPlace(POINT, nil, 10))
        end)

        it('verdict : déclarée et vue → confirm ; vue sans déclaration → force après le délai ; jamais vue → warn une fois', function()
            local grace = 20000
            local watch = { orderedAt = 0, claimed = false, warned = false }
            assert.equal('wait', spawn.verdict(watch, 19999, grace))
            assert.equal('warn', spawn.verdict(watch, 20000, grace))
            watch.warned = true
            assert.equal('wait', spawn.verdict(watch, 60000, grace))
            watch.claimed = true
            assert.equal('wait', spawn.verdict(watch, 60000, grace))  -- déclarée, jamais vue : rien
            watch.seenAt = 500
            assert.equal('confirm', spawn.verdict(watch, 600, grace))
            watch.claimed = false
            assert.equal('wait', spawn.verdict(watch, 19999, grace))
            assert.equal('force', spawn.verdict(watch, 20000, grace))
        end)
    end)

    describe('ordre et déclaration', function()
        it('client honnête : ordre au seul joueur, ped au point, déclaration → confirmée aussitôt', function()
            local character = newCharacter()
            order(character)
            assert.equal(1, #sent)
            assert.equal(vAvA.EVENTS.SPAWN, sent[1].event)
            assert.equal(SRC, sent[1].target)
            assert.equal('mp_f_freemode_01', sent[1].args[1].model)
            assert.is_false(character.spawned)

            now = now + 1500
            move(SRC, POINT.x + 0.5, POINT.y, POINT.z - 1)
            assert.same({ true }, { claim(character) })
            assert.is_true(character.spawned)
            assert.equal(1, #hookCalls)
            assert.same({ source = SRC, accountId = 3, characterId = 7, forced = false }, hookCalls[1])
            assert.same({ SRC }, refreshed)
            assert.equal(0, spawn.pendingCount())
            assert.equal(0, printedMatching('[spawn]'))
            -- une seconde déclaration ne rejoue rien
            assert.same({ true }, { claim(character) })
            assert.equal(1, #hookCalls)
        end)

        it('client qui déclare avant d’avoir bougé : rien n’est confirmé, ni temps, ni position, ni proximité', function()
            local character = newCharacter()
            character.position = { x = POINT.x, y = POINT.y, z = POINT.z, heading = 0.0 }
            order(character)
            assert.same({ true }, { claim(character) })
            assert.is_false(character.spawned)
            assert.equal(0, #hookCalls)

            now = now + 60000
            assert.equal(0, playtime.current(character))
            assert.is_false(positions.sample(character))
            assert.same({ x = POINT.x, y = POINT.y, z = POINT.z, heading = 0.0 }, character.position)
            assert.same({}, net.playersNear(FAR, 50))
            -- le serveur le dit une fois, pas à chaque lecture
            advance(cfg.checkMs)
            advance(cfg.checkMs)
            assert.equal(1, printedMatching('jamais vu au point'))
            assert.equal(1, printedMatching('déclarée par son client'))
            assert.equal(0, #hookCalls)
        end)

        it('déclaré tôt puis arrivé au point : confirmé au passage suivant, sans être forcé', function()
            local character = newCharacter()
            order(character)
            claim(character)
            assert.is_false(character.spawned)
            move(SRC, POINT.x, POINT.y, POINT.z)
            advance(cfg.checkMs)
            assert.is_true(character.spawned)
            assert.equal(1, #hookCalls)
            assert.is_false(hookCalls[1].forced)
            assert.same({ SRC }, net.playersNear(POINT, 5))
        end)

        it('vu au point pendant l’écran noir, parti en courant avant la déclaration : confirmé', function()
            local character = newCharacter()
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            advance(cfg.checkMs)          -- ped figé au point, lu par le serveur
            assert.is_false(character.spawned)
            move(SRC, POINT.x + 40, POINT.y, POINT.z)
            claim(character)
            assert.is_true(character.spawned)
            assert.is_false(hookCalls[1].forced)
        end)

        it('déclaration sans ordre en attente : refusée sans effet', function()
            local character = newCharacter()
            assert.same({ false, 'not_ordered' }, { claim(character) })
            assert.is_false(character.spawned)
        end)

        it('temps de jeu compté seulement depuis la confirmation', function()
            local character = newCharacter()
            order(character)
            now = now + 30000
            move(SRC, POINT.x, POINT.y, POINT.z)
            claim(character)
            now = now + 12500
            assert.equal(12, playtime.current(character))
        end)

        it('position relevée seulement une fois confirmée, à l’endroit lu par le serveur', function()
            local character = newCharacter()
            order(character)
            assert.is_false(positions.sample(character))
            move(SRC, POINT.x, POINT.y, POINT.z)
            claim(character)
            assert.is_true(positions.sample(character))
            assert.equal(POINT.x, character.position.x)
            assert.equal(POINT.y, character.position.y)
        end)
    end)

    describe('confirmation d’office', function()
        it('client qui ne déclare rien, ped au point : confirmée après le délai de grâce, pas avant', function()
            local character = newCharacter()
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            local elapsed = 0
            while elapsed + cfg.checkMs < cfg.graceMs do
                advance(cfg.checkMs)
                elapsed = elapsed + cfg.checkMs
            end
            assert.is_false(character.spawned)
            advance(cfg.checkMs)
            assert.is_true(character.spawned)
            assert.same({ source = SRC, accountId = 3, characterId = 7, forced = true }, hookCalls[1])
            assert.equal(1, printedMatching('confirmée d\'office'))
            assert.equal(0, #helper.timers)   -- plus rien à lire : aucune échéance reposée
        end)

        it('client qui ne déclare rien et ne vient jamais : jamais confirmé, une seule ligne, confirmé s’il arrive', function()
            local character = newCharacter()
            order(character)
            for _ = 1, 2 * cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            assert.is_false(character.spawned)
            assert.equal(1, printedMatching('rien déclaré par son client'))
            assert.equal(0, playtime.current(character))
            assert.equal(1, #helper.timers)   -- une seule échéance à la fois
            move(SRC, POINT.x, POINT.y, POINT.z)
            -- après l'avertissement, le ped n'est plus relu que toutes les lateCheckMs (relecture réseau R-1)
            for _ = 1, cfg.lateCheckMs // cfg.checkMs do advance(cfg.checkMs) end
            assert.is_true(character.spawned)
            assert.is_true(hookCalls[1].forced)
        end)
    end)

    describe('ordres successifs et départs', function()
        it('un nouvel ordre remplace le point attendu', function()
            local character = newCharacter()
            order(character)
            local other = { x = 500.0, y = 500.0, z = 30.0 }
            assert.is_true(order(character, other))
            move(SRC, POINT.x, POINT.y, POINT.z)
            claim(character)
            assert.is_false(character.spawned)
            move(SRC, other.x, other.y, other.z)
            advance(cfg.checkMs)
            assert.is_true(character.spawned)
            assert.equal(0, spawn.pendingCount())
        end)

        it('téléportation d’un personnage apparu : plus apparu jusqu’à la nouvelle confirmation', function()
            local character = newCharacter()
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            claim(character)
            assert.is_true(character.spawned)
            assert.is_true(order(character, { x = 0.0, y = 0.0, z = 70.0 }))
            assert.is_false(character.spawned)
            assert.same({}, net.playersNear(POINT, 50))
            assert.same({ false, 'invalid_coords' }, { spawn.at(character, { x = 0 / 0, y = 0, z = 0 }) })
        end)

        it('déchargé ou parti : l’attente est oubliée, aucune échéance reposée', function()
            local character = newCharacter()
            order(character)
            spawn.forget(character)
            assert.equal(0, spawn.pendingCount())
            advance(cfg.checkMs)
            assert.equal(0, #helper.timers)

            local second = newCharacter(2, 8)
            order(second)
            current[2] = nil  -- son joueur est parti
            move(2, POINT.x, POINT.y, POINT.z)
            advance(cfg.checkMs)
            assert.is_false(second.spawned)
            assert.equal(0, spawn.pendingCount())
            assert.equal(0, #helper.timers)
        end)

        it('ordre impossible à envoyer : joueur abandonné, rien en attente', function()
            local character = newCharacter()
            dispatchFails = true
            local ok = order(character, POINT)
            assert.is_false(ok)
            assert.equal(1, #abandoned)
            assert.equal(0, spawn.pendingCount())
        end)

        it('un hook qui redonne un ordre pendant la confirmation : nouvel ordre attendu, zones non relues', function()
            local character = newCharacter()
            local again = { x = 900.0, y = 900.0, z = 30.0 }
            assert.is_true(vAvA.hooks.subscribe('vava_test', 'after', 'core:character:spawned', function()
                if #hookCalls == 1 then spawn.at(character, again) end
            end) ~= nil)
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            claim(character)
            assert.equal(1, #hookCalls)
            assert.is_false(character.spawned)
            assert.same({}, refreshed)
            assert.equal(1, spawn.pendingCount())
            move(SRC, again.x, again.y, again.z)
            assert.same({ true }, { claim(character) })   -- le nouvel ordre se déclare à son tour
            assert.is_true(character.spawned)
            assert.equal(2, #hookCalls)
            assert.same({ SRC }, refreshed)
        end)
    end)

    -- suites des relectures sécurité (S-1, S-2, S-4, S-6) et réseau (R-1, R-2) de T-139
    describe('suites des relectures', function()
        it('S-1 : personnage qui n’est plus chargé (déchargement en cours, autre personnage) : jamais confirmé', function()
            local character = newCharacter()
            order(character)
            claim(character)                         -- déclaré tôt, ped encore ailleurs
            sessions[SRC].state = 'unloading'        -- le déchargement a commencé et cède la main
            move(SRC, POINT.x, POINT.y, POINT.z)     -- le ped arrive au point pendant ce temps
            advance(cfg.checkMs)
            advance(cfg.graceMs)
            assert.is_false(character.spawned)
            assert.equal(0, #hookCalls)
            assert.is_nil(character.playMarker)
            assert.same({}, refreshed)
            assert.equal(0, spawn.pendingCount())
            assert.equal(0, #helper.timers)

            -- même chose, rien déclaré (confirmation d'office) et session passée à un autre personnage
            local second = newCharacter(2, 8)
            order(second)
            move(2, POINT.x, POINT.y, POINT.z)
            sessions[2].characterId = 9
            advance(cfg.graceMs)
            assert.is_false(second.spawned)
            assert.equal(0, #hookCalls)
            assert.equal(0, spawn.pendingCount())
        end)

        it('S-1 : déclaration reçue alors que la session n’est plus active : rien de confirmé', function()
            local character = newCharacter()
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            sessions[SRC] = nil                      -- joueur parti, personnage encore courant pour sync
            assert.same({ true }, { claim(character) })
            assert.is_false(character.spawned)
            assert.equal(0, #hookCalls)
            assert.equal(0, spawn.pendingCount())
        end)

        it('S-2 : déclaration d’un ordre précédent (arrivée en retard) : ne compte pas pour l’ordre qui attend', function()
            local character = newCharacter()
            order(character)
            local first = lastOrder(SRC)
            assert.is_true(math.type(first) == 'integer' and first >= 1)
            assert.is_true(order(character, { x = POINT.x + 3, y = POINT.y, z = POINT.z }))  -- presque au même point
            local second = lastOrder(SRC)
            assert.is_true(second ~= first)
            move(SRC, POINT.x, POINT.y, POINT.z)
            assert.same({ false, 'not_ordered' }, { spawn.claim(character, first) })
            assert.is_false(character.spawned)
            assert.same({ false, 'not_ordered' }, { spawn.claim(character, nil) })
            -- le ped est au point, mais seule la déclaration du bon ordre, ou le délai de grâce, confirme
            advance(cfg.checkMs)
            assert.is_false(character.spawned)
            assert.same({ true }, { spawn.claim(character, second) })
            assert.is_true(character.spawned)
            assert.is_false(hookCalls[1].forced)
        end)

        it('S-2 : chaque ordre a un numéro, repart à 1 après le plus grand', function()
            local character = newCharacter()
            local seen = {}
            for _ = 1, 5 do
                order(character, POINT)
                local seq = lastOrder(SRC)
                assert.is_nil(seen[seq])
                seen[seq] = true
                assert.is_true(seq >= 1 and seq <= spawn.MAX_ORDER)
            end
            -- remise à 1 vraiment exercée (contre-relecture C-3) : compteur posé juste avant le plus grand numéro
            assert.equal(0x7FFFFFFF, spawn.MAX_ORDER)
            assert.is_false(spawn.setLastOrderForTests(spawn.MAX_ORDER + 1))
            assert.is_false(spawn.setLastOrderForTests(-1))
            assert.is_true(spawn.setLastOrderForTests(spawn.MAX_ORDER - 1))
            order(character, POINT)
            assert.equal(spawn.MAX_ORDER, lastOrder(SRC))
            order(character, POINT)
            assert.equal(1, lastOrder(SRC))
            order(character, POINT)
            assert.equal(2, lastOrder(SRC))
            -- la déclaration de l'ordre MAX_ORDER, arrivée après la remise à 1, ne compte pas pour l'ordre qui attend
            move(SRC, POINT.x, POINT.y, POINT.z)
            assert.same({ false, 'not_ordered' }, { spawn.claim(character, spawn.MAX_ORDER) })
            assert.same({ true }, { spawn.claim(character, 2) })
            assert.is_true(character.spawned)
        end)

        it('S-4 : la ligne « jamais vu au point » nomme le compte et le personnage', function()
            local character = newCharacter()
            order(character)
            for _ = 1, cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            assert.equal(1, printedMatching('joueur 1 (compte #3, personnage #7) : ped jamais vu au point'))
            assert.is_false(character.spawned)
        end)

        it('C-2 : une erreur dans la confirmation elle-même est retentée au passage suivant, un seul hook', function()
            local character = newCharacter()
            local realBegin, failures = playtime.begin, 0
            playtime.begin = function(c)
                if failures == 0 then
                    failures = 1
                    error('temps de jeu indisponible')
                end
                return realBegin(c)
            end
            order(character)
            move(SRC, POINT.x, POINT.y, POINT.z)
            for _ = 1, cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            -- confirmation d'office en erreur : suivi gardé, une ligne d'erreur, aucun hook
            assert.equal(1, failures)
            assert.equal(1, printedMatching('en erreur (retentée)'))
            assert.equal(0, #hookCalls)
            assert.equal(1, spawn.pendingCount())
            assert.equal(1, #helper.timers)
            advance(cfg.checkMs)
            assert.is_true(character.spawned)
            assert.equal(1, #hookCalls)
            assert.is_true(hookCalls[1].forced)
            assert.equal(0, spawn.pendingCount())
            assert.is_not_nil(character.playMarker)
            advance(cfg.checkMs)
            assert.equal(1, #hookCalls)
            assert.equal(1, printedMatching('en erreur (retentée)'))
            assert.equal(0, #helper.timers)
        end)

        it('S-6 : une erreur dans un passage garde l’apparition et la retente, une seule ligne', function()
            local character = newCharacter()
            order(character)
            coords[101] = setmetatable({}, { __index = function() error('lecture impossible') end })
            net.forgetPosition(SRC)
            advance(cfg.checkMs)
            assert.equal(1, printedMatching('en erreur (retentée)'))
            assert.equal(1, spawn.pendingCount())
            assert.equal(1, #helper.timers)
            advance(cfg.checkMs)
            assert.equal(1, printedMatching('en erreur (retentée)'))
            move(SRC, POINT.x, POINT.y, POINT.z)
            advance(cfg.checkMs)
            assert.same({ true }, { claim(character) })
            assert.is_true(character.spawned)
            assert.equal(1, #hookCalls)
        end)

        it('R-1 : jamais vu au point, le ped n’est plus relu qu’à chaque lateCheckMs ; une déclaration le relit', function()
            local character = newCharacter()
            order(character)
            for _ = 1, cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            assert.equal(1, printedMatching('jamais vu au point'))
            reads[SRC] = 0
            for _ = 1, cfg.lateCheckMs // cfg.checkMs - 1 do advance(cfg.checkMs) end
            assert.equal(0, reads[SRC])
            advance(cfg.checkMs)
            assert.equal(1, reads[SRC])
            assert.equal(1, #helper.timers)
            -- arrivé au point entre deux lectures espacées : la déclaration le relit aussitôt
            move(SRC, POINT.x, POINT.y, POINT.z)
            advance(cfg.checkMs)
            assert.is_false(character.spawned)
            assert.same({ true }, { claim(character) })
            assert.is_true(character.spawned)
            assert.equal(1, printedMatching('jamais vu au point'))
        end)

        it('R-1 : sans déclaration, confirmé d’office à la lecture espacée suivante', function()
            local character = newCharacter()
            order(character)
            for _ = 1, cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            move(SRC, POINT.x, POINT.y, POINT.z)
            for _ = 1, cfg.lateCheckMs // cfg.checkMs - 1 do advance(cfg.checkMs) end
            assert.is_false(character.spawned)
            advance(cfg.checkMs)
            assert.is_true(character.spawned)
            assert.is_true(hookCalls[1].forced)
        end)

        it('R-2 : au plus maxPerCheck confirmations par passage, les suivantes au passage suivant', function()
            cfg.maxPerCheck = 2
            local list = { newCharacter(1, 7), newCharacter(2, 8), newCharacter(3, 9) }
            for i = 1, 3 do
                order(list[i])
                move(i, POINT.x, POINT.y, POINT.z)
            end
            for _ = 1, cfg.graceMs // cfg.checkMs do advance(cfg.checkMs) end
            assert.equal(2, #hookCalls)
            assert.equal(1, spawn.pendingCount())
            advance(cfg.checkMs)
            assert.equal(3, #hookCalls)
            for i = 1, 3 do assert.is_true(list[i].spawned) end
            assert.equal(0, #helper.timers)
        end)
    end)
end)

-- Le RPC de déclaration et l'API (server/players/characters.lua, server/players/api.lua) : le vrai fichier des
-- personnages, sur des doublures de la base, des sessions, de la sauvegarde et de la diffusion.
describe('vAvA.characters (apparition confirmée)', function()
    local characters, handlers, sessions, coords, refreshed, hookCalls, now, realPrint, lastOrder, rpcArgs

    local SRC = 1
    local POINT = { x = -269.4, y = -955.3, z = 31.2 }

    before_each(function()
        helper.reset()
        now = 1000
        handlers, sessions, coords, refreshed, hookCalls, lastOrder, rpcArgs = {}, {}, {}, {}, {}, nil, {}
        realPrint = _G.print
        _G.print = function() end
        _G.GetGameTimer = function() return now end
        _G.DoesPlayerExist = function(src) return src == SRC end
        _G.GetPlayerPed = function(src) return src == SRC and 101 or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function() return coords end
        _G.GetEntityHeading = function() return 0.0 end
        _G.GetPlayerRoutingBucket = function() return 0 end
        -- numéro du dernier ordre d'apparition reçu par le client (renvoyé avec sa déclaration)
        _G.TriggerClientEvent = function(event, _, payload)
            if event == vAvA.EVENTS.SPAWN then lastOrder = payload.seq end
        end
        _G.msgpack = nil
        _G.TriggerClientEventInternal = nil
        _G.json = { decode = function() return {} end, encode = function() return '{}' end }
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'config/server.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
        })
        local owners = {}
        vAvA.sync = {
            isCurrent = function(character) return owners[character.source] == character end,
            abandon = function() end,
            sendCharacter = function(character) owners[character.source] = character end,
            clearCharacter = function(character) owners[character.source] = nil end,
            fieldChanged = function() end,
        }
        vAvA.zones = {
            refreshPlayer = function(src) refreshed[#refreshed + 1] = src end,
            purgePlayer = function() end,
        }
        vAvA.database = {
            single = function()
                return { id = 7, first_name = 'Aela', last_name = 'Vorn', sex = 'f', play_seconds = 0, data = '{}' }
            end,
            update = function() return 1 end,
        }
        vAvA.rpc = {
            register = function(_, name, options, handler)
                assert.is_table(options.args)
                assert.is_table(options.rateLimit)
                handlers[name] = handler
                rpcArgs[name] = options.args
                return true
            end,
        }
        vAvA.accounts = {
            get = function(src) return sessions[src] end,
            isCurrent = function(session) return sessions[session.source] == session end,
        }
        vAvA.fields = {}
        vAvA.persistence = { takeRetry = function() return nil end, saveCharacter = function() end }
        helper.loadAll({
            'server/players/playtime.lua',
            'server/players/positions.lua',
            'server/players/spawn.lua',
            'server/players/characters.lua',
        })
        characters = vAvA.characters
        assert.same({ true }, { characters.registerRpc() })
        vAvA.hooks.subscribe('vava_test', 'after', 'core:character:spawned', function(payload)
            hookCalls[#hookCalls + 1] = payload
        end)
        sessions[SRC] = { source = SRC, accountId = 3, state = 'joined', characters = { [7] = { id = 7 } } }
        coords = { x = 1200.0, y = 300.0, z = 40.0 }
    end)

    after_each(function()
        _G.print = realPrint
        _G.json = nil
    end)

    it('déclaration sans ped au point : acceptée sans rien confirmer ; confirmée une fois le ped vu', function()
        local SPAWNED = vAvA.CHARACTER_RPC.SPAWNED
        assert.same({ false, 'no_character' }, { handlers[SPAWNED](SRC) })
        assert.same({ false, 'no_character' }, { characters.isSpawned(SRC) })
        assert.same({ true }, { handlers[vAvA.CHARACTER_RPC.SELECT](SRC, 7) })
        assert.same({ false }, { characters.isSpawned(SRC) })

        assert.same({ true }, { handlers[SPAWNED](SRC, lastOrder) })
        assert.same({ false }, { characters.isSpawned(SRC) })
        assert.equal(0, #hookCalls)

        coords = { x = POINT.x, y = POINT.y, z = POINT.z }
        vAvA.net.forgetPosition(SRC)
        assert.same({ true }, { handlers[SPAWNED](SRC, lastOrder) })
        assert.same({ true }, { characters.isSpawned(SRC) })
        assert.same({ source = SRC, accountId = 3, characterId = 7, forced = false }, hookCalls[1])
        assert.same({ SRC }, refreshed)
    end)

    it('déchargement : apparition en attente oubliée, plus apparu', function()
        assert.same({ true }, { handlers[vAvA.CHARACTER_RPC.SELECT](SRC, 7) })
        assert.equal(1, vAvA.spawn.pendingCount())
        assert.same({ true }, { characters.unload(SRC) })
        assert.equal(0, vAvA.spawn.pendingCount())
        assert.same({ false, 'no_character' }, { characters.isSpawned(SRC) })
    end)

    -- relecture sécurité S-1 : le hook unloading et la sauvegarde cèdent la main (ici, les passages de la confirmation
    -- tournent pendant qu'ils s'exécutent) ; le ped arrive au point pendant ce temps
    describe('déchargement pendant une apparition en attente (S-1)', function()
        local begins, character

        --- Fait passer le temps puis déclenche les minuteries en attente.
        local function advance(ms)
            now = now + ms
            local due = helper.timers
            helper.timers = {}
            for i = 1, #due do due[i].fn() end
        end

        local function pedAtPoint()
            coords = { x = POINT.x, y = POINT.y, z = POINT.z }
            vAvA.net.forgetPosition(SRC)
        end

        before_each(function()
            begins = 0
            local realBegin = vAvA.playtime.begin
            vAvA.playtime.begin = function(c)
                begins = begins + 1
                return realBegin(c)
            end
            assert.same({ true }, { handlers[vAvA.CHARACTER_RPC.SELECT](SRC, 7) })
            character = nil
            characters.forEachActive(function(c) character = c end)
            assert.is_table(character)
        end)

        it('déclaré tôt, ped au point pendant le hook unloading : jamais apparu, aucun hook, aucun temps de jeu', function()
            assert.same({ true }, { handlers[vAvA.CHARACTER_RPC.SPAWNED](SRC, lastOrder) })   -- ped encore ailleurs
            assert.equal(0, #hookCalls)
            vAvA.hooks.subscribe('vava_test', 'after', 'core:character:unloading', function()
                pedAtPoint()
                advance(vAvA.config.server.spawn.confirm.checkMs)
            end)
            assert.same({ true }, { characters.unload(SRC) })
            assert.equal(0, #hookCalls)
            assert.equal(0, begins)
            assert.is_false(character.spawned)
            assert.is_nil(character.playMarker)
            assert.same({}, refreshed)
            assert.equal(0, vAvA.spawn.pendingCount())
            assert.equal(0, #helper.timers)
        end)

        it('rien déclaré, ped au point pendant la sauvegarde au-delà du délai de grâce : pas de confirmation d’office', function()
            local confirm = vAvA.config.server.spawn.confirm
            vAvA.persistence.saveCharacter = function()
                pedAtPoint()
                advance(confirm.checkMs)
                advance(confirm.graceMs)
            end
            assert.same({ true }, { characters.unload(SRC) })
            assert.equal(0, #hookCalls)
            assert.equal(0, begins)
            assert.is_false(character.spawned)
            assert.equal(0, #helper.timers)
        end)

        it('déclaration pendant le déchargement : refusée (session plus active)', function()
            local answer
            vAvA.hooks.subscribe('vava_test', 'after', 'core:character:unloading', function()
                pedAtPoint()
                answer = { handlers[vAvA.CHARACTER_RPC.SPAWNED](SRC, lastOrder) }
            end)
            assert.same({ true }, { characters.unload(SRC) })
            assert.same({ false, 'no_character' }, answer)
            assert.equal(0, #hookCalls)
            assert.equal(0, begins)
        end)
    end)

    it('S-2 : la déclaration porte le numéro de l’ordre (entier borné) ; un autre numéro ne compte pas', function()
        local SPAWNED = vAvA.CHARACTER_RPC.SPAWNED
        assert.same({ { type = 'integer', min = 1, max = vAvA.spawn.MAX_ORDER } }, rpcArgs[SPAWNED])
        assert.same({ true }, { handlers[vAvA.CHARACTER_RPC.SELECT](SRC, 7) })
        coords = { x = POINT.x, y = POINT.y, z = POINT.z }
        vAvA.net.forgetPosition(SRC)
        assert.same({ false, 'not_ordered' }, { handlers[SPAWNED](SRC, lastOrder + 1) })
        assert.same({ false }, { characters.isSpawned(SRC) })
        assert.same({ true }, { handlers[SPAWNED](SRC, lastOrder) })
        assert.same({ true }, { characters.isSpawned(SRC) })
    end)

    it('config de la confirmation invalide : les RPC des personnages ne s’ouvrent pas', function()
        local confirm = vAvA.config.server.spawn.confirm
        local saved = confirm.radius
        confirm.radius = -1
        local ok, err = characters.registerRpc()
        confirm.radius = saved
        assert.is_false(ok)
        assert.truthy(err:find('spawn.confirm.radius', 1, true))
    end)
end)
