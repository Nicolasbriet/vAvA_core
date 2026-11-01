local helper = require('tests.helper')

-- Mannequins chez le joueur (modules/vava_combat/client/dummies.lua, T-156 spec § 8 et § 11.1), vue client seule
-- (constants + config_client + shared/dummies.lua), faux core, natives simulées et un petit ordonnanceur : chaque
-- CreateThread est une coroutine, Wait(ms) la rend la main jusqu'à l'heure dite (Wait(0) : une image de 16 ms).
-- Props LOCAUX créés à 60 m, retirés au-delà de 70 m, boucle à 0,5 s près d'une cour et 2 s loin, seulement personnage
-- apparu ; modèle de repli ; tout retiré au déchargement et à l'arrêt ; vava_combat:dummy relu (chiffre chez
-- l'attaquant seul, balancement chez tous) ; le balancement s'arrête de lui-même et remet le prop droit.
describe('vava_combat mannequins (client)', function()
    local props, cfg, dummy1
    local clock, threads, waits, player, attackerAt
    local created, deleted, entities, rotations, frozen, hitTexts, sounds, particles, warns, hooks, netEvents, stops
    local validModels, nextEntity, loads, modelLoads
    local ME, OTHER = 5, 7
    local FRAME_MS = 16

    --- Fait tourner les fils jusqu'à `ms` (horloge absolue), dans l'ordre de leurs réveils.
    local function run(ms)
        while true do
            local best
            for _, t in ipairs(threads) do
                if t.wakeAt <= ms and (not best or t.wakeAt < best.wakeAt) then best = t end
            end
            if not best then break end
            if best.wakeAt > clock then clock = best.wakeAt end
            local ok, wait = coroutine.resume(best.co)
            assert(ok, wait)
            if coroutine.status(best.co) == 'dead' then
                for i, t in ipairs(threads) do
                    if t == best then table.remove(threads, i) break end
                end
            else
                best.wakeAt = clock + (wait == 0 and FRAME_MS or wait)
            end
        end
        if ms > clock then clock = ms end
    end

    --- Joueur à `meters` au sud du mannequin 1.
    local function standAt(meters)
        player = { x = dummy1.x, y = dummy1.y - meters, z = dummy1.z }
    end

    local function count(map)
        local n = 0
        for _ in pairs(map) do n = n + 1 end
        return n
    end

    before_each(function()
        helper.reset()
        helper.loadClientView('modules/vava_combat', 'VavaCombat')
        helper.load('modules/vava_combat/shared/dummies.lua')
        cfg = VavaCombat.config
        cfg.effects.sounds = { hit = { name = 'HIT', set = 'SET' } }
        dummy1 = cfg.dummies.list[1]
        clock, threads, waits = 0, {}, {}
        created, deleted, entities, rotations, frozen = {}, {}, {}, {}, {}
        hitTexts, sounds, particles, warns, hooks, netEvents, stops = {}, {}, {}, {}, {}, {}, {}
        validModels = { [cfg.dummies.model] = true, [cfg.dummies.fallbackModel] = true }
        nextEntity, attackerAt, loads, modelLoads = 100, nil, true, 0
        standAt(100)

        VavaCombat.resource = 'vava_combat'
        VavaCombat.core = {
            log = { warn = function(fmt, ...) warns[#warns + 1] = fmt:format(...) end, error = function() end },
            hooks = { after = function(name, fn) hooks[name] = fn return 1 end },
            characters = { current = function() return nil end, awaitingSelection = function() return true end },
        }
        VavaCombat.bridge = {
            HitText = function(side, anchor, issue, tenths)
                hitTexts[#hitTexts + 1] = { side = side, anchor = anchor, issue = issue, tenths = tenths }
            end,
        }
        _G.CreateThread = function(fn)
            threads[#threads + 1] = { co = coroutine.create(fn), wakeAt = clock }
        end
        _G.Wait = function(ms)
            waits[#waits + 1] = ms
            coroutine.yield(ms)
        end
        _G.GetGameTimer = function() return clock end
        _G.AddEventHandler = function(name, fn) stops[name] = fn end
        _G.RegisterNetEvent = function(name, fn) netEvents[name] = fn end
        _G.PlayerPedId = function() return 1 end
        _G.PlayerId = function() return 0 end
        _G.GetPlayerServerId = function() return ME end
        _G.GetPlayerFromServerId = function(src) return (src == OTHER and attackerAt) and 3 or -1 end
        _G.GetPlayerPed = function(client) return client == 3 and 33 or 0 end
        _G.GetEntityCoords = function(entity)
            if entity == 1 then return player end
            if entity == 33 then return attackerAt end
            return { x = 0, y = 0, z = 0 }
        end
        _G.DoesEntityExist = function(entity) return entity == 33 or entities[entity] ~= nil end
        _G.DeleteObject = function(entity)
            deleted[#deleted + 1] = entity
            entities[entity] = nil
        end
        _G.GetHashKey = function(name) return 'h:' .. name end
        _G.IsModelValid = function(hash) return validModels[hash:sub(3)] == true end
        _G.RequestModel = function() modelLoads = modelLoads + 1 end
        _G.HasModelLoaded = function() return loads end
        _G.SetModelAsNoLongerNeeded = function() end
        _G.CreateObjectNoOffset = function(hash, x, y, z, networked, missionEntity, door)
            nextEntity = nextEntity + 1
            entities[nextEntity] = true
            created[#created + 1] = { entity = nextEntity, hash = hash, x = x, y = y, z = z,
                flags = { networked, missionEntity, door } }
            return nextEntity
        end
        _G.SetEntityHeading = function() end
        _G.FreezeEntityPosition = function(entity, flag) frozen[entity] = flag end
        _G.SetEntityRotation = function(entity, pitch, roll, yaw)
            rotations[#rotations + 1] = { entity = entity, pitch = pitch, roll = roll, yaw = yaw }
        end
        _G.HasNamedPtfxAssetLoaded = function() return true end
        _G.RequestNamedPtfxAsset = function() end
        _G.UseParticleFxAsset = function() end
        _G.StartParticleFxNonLoopedAtCoord = function(name, x, y, z)
            particles[#particles + 1] = { name = name, x = x, y = y, z = z }
        end
        _G.PlaySoundFrontend = function(_, name, set) sounds[#sounds + 1] = { name, set } end

        helper.load('modules/vava_combat/client/dummies.lua')
        props = VavaCombat.dummyProps
        props.start()
    end)

    after_each(function()
        for _, name in ipairs({ 'AddEventHandler', 'RegisterNetEvent', 'PlayerPedId', 'PlayerId', 'GetPlayerServerId',
            'GetPlayerFromServerId', 'GetPlayerPed', 'GetEntityCoords', 'DoesEntityExist', 'DeleteObject', 'GetHashKey',
            'IsModelValid', 'RequestModel', 'HasModelLoaded', 'SetModelAsNoLongerNeeded', 'CreateObjectNoOffset',
            'SetEntityHeading', 'FreezeEntityPosition', 'SetEntityRotation', 'HasNamedPtfxAssetLoaded',
            'RequestNamedPtfxAsset', 'UseParticleFxAsset', 'StartParticleFxNonLoopedAtCoord', 'PlaySoundFrontend' }) do
            _G[name] = nil
        end
        VavaCombat = nil
    end)

    local function spawned()
        hooks['core:character:spawning']()
        run(clock)
    end

    describe('props locaux streamés', function()
        it('aucune boucle avant l\'apparition du personnage', function()
            run(10000)
            assert.equal(0, #threads)
            assert.equal(0, #waits)
        end)

        it('à 100 m : aucun prop, passage suivant dans 2 s', function()
            spawned()
            assert.equal(0, #created)
            assert.same({ 2000 }, waits)
        end)

        it('créé à 59 m (local, figé), gardé à 65 m, retiré à 71 m, recréé à 59 m ; 0,5 s près d\'une cour', function()
            spawned()
            standAt(59)
            run(2000)
            assert.equal(1, #created)
            assert.equal('h:' .. cfg.dummies.model, created[1].hash)
            assert.same({ false, false, false }, created[1].flags)
            assert.same({ dummy1.x, dummy1.y, dummy1.z }, { created[1].x, created[1].y, created[1].z })
            assert.is_true(frozen[created[1].entity])
            assert.equal(500, waits[#waits])
            standAt(65)
            run(2500)
            assert.equal(0, #deleted)
            standAt(71)
            run(3000)
            assert.same({ created[1].entity }, deleted)
            assert.equal(500, waits[#waits])   -- 71 m : encore à moins de 90 m
            standAt(59)
            run(3500)
            assert.equal(2, #created)
            assert.equal(1, count(entities))
        end)

        it('modèle inconnu : repli ; les deux inconnus : aucun prop, une ligne par modèle, pas à chaque passage', function()
            validModels[cfg.dummies.model] = nil
            spawned()
            standAt(10)
            run(2000)
            assert.equal(3, #created)
            assert.equal('h:' .. cfg.dummies.fallbackModel, created[1].hash)
            assert.equal(1, #warns)
            -- les deux inconnus
            hooks['core:character:unloaded']()
            run(2500)
            validModels = {}
            created, warns = {}, {}
            spawned()
            run(5000)
            assert.equal(0, #created)
            assert.equal(1, #warns)           -- le repli seulement : le premier modèle est déjà signalé
            run(8000)
            assert.equal(1, #warns)
        end)

        it('R-3 : modèle connu qui ne se charge pas : aucun prop, une ligne, pas de nouvel essai avant la sortie de portée', function()
            loads = false
            spawned()
            standAt(10)
            run(2000)
            run(9000)                         -- attente bornée (5 s) épuisée
            assert.equal(0, #created)
            assert.equal(3, modelLoads)       -- un essai par mannequin
            local lines = 0
            for _, line in ipairs(warns) do
                if line:find('non chargé', 1, true) then lines = lines + 1 end
            end
            assert.equal(1, lines)            -- une ligne par modèle
            run(20000)
            assert.equal(3, modelLoads)       -- aucun nouvel essai tant qu'on reste à portée
            -- sorti de portée puis revenu : nouvel essai, sans nouvelle ligne
            standAt(100)
            run(23000)
            loads = true
            standAt(10)
            run(26000)
            assert.equal(6, modelLoads)
            assert.equal(3, #created)
            assert.equal(1, #warns)
        end)

        it('R-1 : liste illisible (contrôlée au seul serveur) : une ligne, aucune boucle, aucune erreur', function()
            cfg.dummies.list = { 'paleto' }
            warns, threads, waits = {}, {}, {}
            helper.load('modules/vava_combat/client/dummies.lua')
            props = VavaCombat.dummyProps
            props.start()
            assert.equal(1, #warns)
            assert.matches('mannequins non montrés', warns[1])
            spawned()
            run(5000)
            assert.equal(0, #waits)
            assert.equal(0, #created)
            assert.has_no.errors(function() props.receive(1, ME, 'hit', 120) end)
            assert.equal(0, #hitTexts)
        end)

        it('déchargement : tout retiré, boucle arrêtée ; arrêt de la ressource : tout retiré', function()
            spawned()
            standAt(10)
            run(2000)
            assert.equal(3, count(entities))
            hooks['core:character:unloaded']()
            assert.equal(0, count(entities))
            run(5000)
            assert.equal(0, #threads)
            -- de nouveau en jeu, puis la ressource s'arrête
            spawned()
            run(6000)
            assert.equal(3, count(entities))
            stops.onResourceStop('autre_ressource')
            assert.equal(3, count(entities))
            stops.onResourceStop('vava_combat')
            assert.equal(0, count(entities))
            run(9000)
            assert.equal(0, #threads)
        end)

        it('retour à la sélection : tout retiré', function()
            spawned()
            standAt(10)
            run(2000)
            hooks['core:character:selection']()
            assert.equal(0, count(entities))
        end)
    end)

    describe('vava_combat:dummy', function()
        before_each(function()
            standAt(10)
            spawned()
            run(1000)
            assert.equal(3, count(entities))
            assert.equal(props.receive, netEvents['vava_combat:dummy'])
            waits = {}
        end)

        it('chez l\'attaquant : chiffre au-dessus du mannequin, son, balancement, éclats', function()
            props.receive(1, ME, 'hit', 120)
            assert.equal(1, #hitTexts)
            assert.same({ side = 'dealt', anchor = { x = dummy1.x, y = dummy1.y,
                z = dummy1.z + cfg.dummies.anchorHeight }, issue = 'hit', tenths = 120 }, hitTexts[1])
            assert.same({ { 'HIT', 'SET' } }, sounds)
            assert.equal(1, #particles)
            assert.equal(dummy1.z + cfg.dummies.centerHeight, particles[1].z)
            run(clock + 100)
            assert.is_true(#rotations > 0)
        end)

        it('chez un témoin : balancement seul, aucun chiffre ni son', function()
            attackerAt = { x = dummy1.x - 1.5, y = dummy1.y, z = dummy1.z }
            props.receive(1, OTHER)
            -- même avec une issue (que le serveur n'envoie qu'à l'attaquant) : jamais de chiffre chez un témoin
            props.receive(1, OTHER, 'hit', 120)
            assert.equal(0, #hitTexts)
            assert.equal(0, #sounds)
            run(clock + 200)
            assert.is_true(#rotations > 0)
        end)

        it('le balancement s\'arrête de lui-même après 900 ms et remet le prop droit', function()
            local start = clock
            props.receive(1, OTHER)
            run(start + 400)
            local moving = #rotations
            assert.is_true(moving > 10)
            run(start + 2000)
            local last = rotations[#rotations]
            assert.same({ pitch = 0.0, roll = 0.0, yaw = dummy1.heading }, { pitch = last.pitch, roll = last.roll,
                yaw = last.yaw })
            local frames = #rotations
            -- plus aucune attente d'une image : la boucle du balancement est finie
            local zeros = 0
            for _, w in ipairs(waits) do if w == 0 then zeros = zeros + 1 end end
            assert.is_true(zeros >= 50 and zeros <= 60, tostring(zeros))   -- ≈ 900 ms d’images de 16 ms
            waits = {}
            run(start + 4000)
            assert.equal(frames, #rotations)
            for _, w in ipairs(waits) do assert.is_true(w > 0) end
            -- un nouveau coup repart de zéro
            props.receive(1, OTHER)
            run(clock + 100)
            assert.is_true(#rotations > frames)
        end)

        it('valeurs hors bornes : message ignoré ; montant illisible : aucun chiffre ; false : le mot seul', function()
            for _, args in ipairs({
                { 0, ME, 'hit', 120 }, { 4, ME, 'hit', 120 }, { 1.5, ME, 'hit', 120 }, { 1, 'a', 'hit', 120 },
                { 1, 0, 'hit', 120 }, { 1, 70000, 'hit', 120 }, { 1, ME, 'boom', 120 }, { 1, ME, 12, 120 },
            }) do
                props.receive(table.unpack(args))
            end
            assert.equal(0, #hitTexts)
            assert.equal(0, #particles)
            props.receive(1, ME, 'hit', 7.5)
            props.receive(1, ME, 'hit', 2001)
            assert.equal(0, #hitTexts)
            assert.equal(2, #particles)
            props.receive(1, ME, 'block', false)
            assert.equal(1, #hitTexts)
            assert.equal('block', hitTexts[1].issue)
            assert.is_nil(hitTexts[1].tenths)
            -- chiffres coupés par le serveur (issue sans 4e valeur) : aucun chiffre
            props.receive(1, ME, 'hit')
            assert.equal(1, #hitTexts)
        end)

        it('mannequin sans prop (hors de portée) : rien ne bouge, aucune erreur', function()
            standAt(100)
            run(clock + 3000)
            assert.equal(0, count(entities))
            rotations = {}
            props.receive(1, OTHER)
            run(clock + 1000)
            assert.equal(0, #rotations)
        end)
    end)
end)
