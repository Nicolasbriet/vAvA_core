local helper = require('tests.helper')

-- Apparition confirmée par le serveur (server/players/spawn.lua, core 0.14.0, T-139), au regard des sections
-- « core.characters » et « Hooks émis par le core » de docs/api.md : la déclaration du client ne suffit plus, le serveur
-- lit le ped et ne confirme qu'après l'avoir vu au point ordonné ; d'office après le délai de grâce sans déclaration.
-- Le temps de jeu (playtime.lua), les positions (positions.lua) et les joueurs proches (net.lua) sont les vrais
-- fichiers du core : ils ne croient que la confirmation. Natives, sync, zones et liste des personnages sont des
-- doublures ; les minuteries (SetTimeout) sont déclenchées à la main.
describe('vAvA.spawn', function()
    local spawn, playtime, positions, net, cfg, now, sent, printed, peds, coords, current, abandoned, refreshed
    local active, hookCalls, realPrint, dispatchFails

    local SRC = 1
    local FAR = { x = 1200.0, y = 300.0, z = 40.0 }   -- ancien emplacement du ped (personnage précédent)

    before_each(function()
        helper.reset()
        now = 1000
        sent, printed, peds, coords, current, abandoned, refreshed, active, hookCalls = {}, {}, {}, {}, {}, {}, {}, {}, {}
        dispatchFails = false
        realPrint = _G.print
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        _G.GetGameTimer = function() return now end
        -- ordre impossible à envoyer : le joueur n'existe plus pour FXServer au moment de l'envoi
        _G.DoesPlayerExist = function(src) return (src == 1 or src == 2) and not dispatchFails end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
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
        peds[character.source] = 100 + character.source
        coords[100 + character.source] = { x = FAR.x, y = FAR.y, z = FAR.z }
        return character
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
            local saved = { checkMs = cfg.checkMs, radius = cfg.radius, graceMs = cfg.graceMs }
            for _, case in ipairs({
                { checkMs = 0 }, { checkMs = 10 }, { checkMs = 500.5 }, { radius = 0 }, { radius = -1 },
                { radius = 0 / 0 }, { radius = math.huge }, { graceMs = 100 }, { graceMs = 'x' },
            }) do
                for key, value in pairs(case) do cfg[key] = value end
                local ok, err = spawn.validateConfig()
                assert.is_false(ok)
                assert.is_string(err)
                for key, value in pairs(saved) do cfg[key] = value end
            end
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
            assert.same({ true }, { spawn.claim(character) })
            assert.is_true(character.spawned)
            assert.equal(1, #hookCalls)
            assert.same({ source = SRC, accountId = 3, characterId = 7, forced = false }, hookCalls[1])
            assert.same({ SRC }, refreshed)
            assert.equal(0, spawn.pendingCount())
            assert.equal(0, printedMatching('[spawn]'))
            -- une seconde déclaration ne rejoue rien
            assert.same({ true }, { spawn.claim(character) })
            assert.equal(1, #hookCalls)
        end)

        it('client qui déclare avant d’avoir bougé : rien n’est confirmé, ni temps, ni position, ni proximité', function()
            local character = newCharacter()
            character.position = { x = POINT.x, y = POINT.y, z = POINT.z, heading = 0.0 }
            order(character)
            assert.same({ true }, { spawn.claim(character) })
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
            spawn.claim(character)
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
            spawn.claim(character)
            assert.is_true(character.spawned)
            assert.is_false(hookCalls[1].forced)
        end)

        it('déclaration sans ordre en attente : refusée sans effet', function()
            local character = newCharacter()
            assert.same({ false, 'not_ordered' }, { spawn.claim(character) })
            assert.is_false(character.spawned)
        end)

        it('temps de jeu compté seulement depuis la confirmation', function()
            local character = newCharacter()
            order(character)
            now = now + 30000
            move(SRC, POINT.x, POINT.y, POINT.z)
            spawn.claim(character)
            now = now + 12500
            assert.equal(12, playtime.current(character))
        end)

        it('position relevée seulement une fois confirmée, à l’endroit lu par le serveur', function()
            local character = newCharacter()
            order(character)
            assert.is_false(positions.sample(character))
            move(SRC, POINT.x, POINT.y, POINT.z)
            spawn.claim(character)
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
            advance(cfg.checkMs)
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
            spawn.claim(character)
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
            spawn.claim(character)
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
            spawn.claim(character)
            assert.equal(1, #hookCalls)
            assert.is_false(character.spawned)
            assert.same({}, refreshed)
            assert.equal(1, spawn.pendingCount())
            move(SRC, again.x, again.y, again.z)
            assert.same({ true }, { spawn.claim(character) })   -- le nouvel ordre se déclare à son tour
            assert.is_true(character.spawned)
            assert.equal(2, #hookCalls)
            assert.same({ SRC }, refreshed)
        end)
    end)
end)

-- Le RPC de déclaration et l'API (server/players/characters.lua, server/players/api.lua) : le vrai fichier des
-- personnages, sur des doublures de la base, des sessions, de la sauvegarde et de la diffusion.
describe('vAvA.characters (apparition confirmée)', function()
    local characters, handlers, sessions, coords, refreshed, hookCalls, now, realPrint

    local SRC = 1
    local POINT = { x = -269.4, y = -955.3, z = 31.2 }

    before_each(function()
        helper.reset()
        now = 1000
        handlers, sessions, coords, refreshed, hookCalls = {}, {}, {}, {}, {}
        realPrint = _G.print
        _G.print = function() end
        _G.GetGameTimer = function() return now end
        _G.DoesPlayerExist = function(src) return src == SRC end
        _G.GetPlayerPed = function(src) return src == SRC and 101 or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function() return coords end
        _G.GetEntityHeading = function() return 0.0 end
        _G.GetPlayerRoutingBucket = function() return 0 end
        _G.TriggerClientEvent = function() end
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

        assert.same({ true }, { handlers[SPAWNED](SRC) })
        assert.same({ false }, { characters.isSpawned(SRC) })
        assert.equal(0, #hookCalls)

        coords = { x = POINT.x, y = POINT.y, z = POINT.z }
        vAvA.net.forgetPosition(SRC)
        assert.same({ true }, { handlers[SPAWNED](SRC) })
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
