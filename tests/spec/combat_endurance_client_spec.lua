local helper = require('tests.helper')

-- Endurance côté joueur (modules/vava_combat/client/endurance.lua, avec bridge/client.lua, attack.lua, defense.lua,
-- mode.lua et main.lua réels, T-114) sur la SEULE vue client (constantes et config_client.lua), un faux core (hooks
-- locaux, rpc.call réglable) et un faux vava_hud qui note defineGauge, setGauge, removeGauge. Minuteries (SetTimeout) et
-- threads gardés, lancés par l'essai. Vérifie l'état lu dans la réponse de use et l'évènement vava_combat:stamina, la
-- jauge du HUD et sa visibilité, et qu'aucune demande ne part que la jauge vue d'ici ne paie pas. Règles documentées :
-- docs/plan/specs/T-114.md § 8 et § 11.1.

local HANDS = 'vava_inventory:hands'
local ID = 'vava_combat:endurance'

describe('vava_combat client : endurance', function()
    local cfg, gaugeView, mode
    local clock, hooks, rpcCalls, rpcAnswer, threads, commands, feed, hud, timeouts, net, events, threadCount
    local STUBBED = { 'GetResourceState', 'BeginTextCommandThefeedPost', 'AddTextComponentSubstringPlayerName',
        'EndTextCommandThefeedPostTicker', 'PlayerPedId', 'DoesEntityExist', 'RequestAnimDict', 'HasAnimDictLoaded',
        'RemoveAnimDict', 'DoesAnimDictExist', 'TaskPlayAnim', 'StopAnimTask', 'RegisterCommand', 'RegisterKeyMapping',
        'IsEntityDead', 'IsPedInAnyVehicle', 'IsPedRagdoll', 'IsPedFalling', 'IsPedCuffed', 'IsNuiFocused',
        'IsPauseMenuActive', 'DisableControlAction', 'PlayerId', 'GetActivePlayers', 'GetPlayerPed', 'GetPlayerServerId',
        'GetEntityCoords', 'GetEntityHeading', 'SetEntityHeading', 'GetGameplayCamRot', 'GetGameplayCamCoord',
        'HasEntityClearLosToEntity', 'DrawMarker', 'exports', 'GetControlNormal', 'RegisterNetEvent', 'AddEventHandler',
        'Entity' }

    local function fire(name, payload)
        for _, fn in ipairs(hooks[name] or {}) do fn(payload) end
    end

    local function runThreads()
        local list = threads
        threads = {}
        for _, co in ipairs(list) do assert(coroutine.resume(co)) end
        return list
    end

    local function press(name)
        local key = cfg.keys[name]
        if key.hold then
            commands['+' .. key.command]()
            commands['-' .. key.command]()
        else
            commands[key.command]()
        end
    end

    local function uses()
        local out = {}
        for _, call in ipairs(rpcCalls) do
            if call.name == 'vava_combat:use' then out[#out + 1] = call.args[1] end
        end
        return out
    end

    local function hudCalls(fn)
        local out = {}
        for _, call in ipairs(hud) do
            if call.fn == fn then out[#out + 1] = call end
        end
        return out
    end

    local function lastSet()
        local list = hudCalls('setGauge')
        return list[#list]
    end

    --- Minuteries arrivées à échéance à `now` (dans l'ordre), retirées puis lancées.
    local function fireTimeouts(now)
        table.sort(timeouts, function(a, b) return a.due < b.due end)
        while timeouts[1] and timeouts[1].due <= now do
            local timer = table.remove(timeouts, 1)
            clock = math.max(clock, timer.due)
            timer.fn()
        end
        clock = now
    end

    local function load()
        helper.loadClientView('modules/vava_combat', 'VavaCombat')
        cfg = VavaCombat.config
        VavaCombat.resource = 'vava_combat'
        VavaCombat.log = { warn = function() end, info = function() end }
        VavaCombat.core = {
            log = VavaCombat.log,
            hooks = {
                after = function(name, fn)
                    hooks[name] = hooks[name] or {}
                    hooks[name][#hooks[name] + 1] = fn
                    return #hooks[name]
                end,
            },
            characters = { current = function() return nil end },
            rpc = {
                call = function(name, ...)
                    rpcCalls[#rpcCalls + 1] = { name = name, args = { ... } }
                    return table.unpack(rpcAnswer)
                end,
            },
        }
        helper.loadAll({
            'modules/vava_combat/shared/heading.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/endurance.lua',
            'modules/vava_combat/bridge/client.lua',
            'modules/vava_combat/client/endurance.lua',
            'modules/vava_combat/client/hands.lua',
            'modules/vava_combat/client/keys.lua',
            'modules/vava_combat/client/targeting.lua',
            'modules/vava_combat/client/attack.lua',
            'modules/vava_combat/client/defense.lua',
            'modules/vava_combat/client/mode.lua',
        })
        VavaCombat.natives = { start = function() end }
        VavaCombat.shields = { start = function() end }
        VavaCombat.dummyProps = { start = function() end }
        helper.load('modules/vava_combat/client/main.lua')
        gaugeView, mode = VavaCombat.gaugeView, VavaCombat.mode
    end

    --- Personnage chargé l'épée en main (en garde d'emblée).
    local function armed()
        load()
        fire('core:character:loaded', { id = 4, fields = { [HANDS] = { item = 'epee_courte' } } })
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, hooks, rpcCalls, rpcAnswer, threads, commands, feed = 1000, {}, {}, { true, true }, {}, {}, {}
        hud, timeouts, net, events, threadCount = {}, {}, {}, {}, 0
        _G.GetGameTimer = function() return clock end
        _G.CreateThread = function(fn)
            threadCount = threadCount + 1
            threads[#threads + 1] = coroutine.create(fn)
        end
        _G.Wait = function() coroutine.yield() end
        _G.SetTimeout = function(ms, fn) timeouts[#timeouts + 1] = { due = clock + ms, fn = fn } end
        _G.GetResourceState = function(name) return name == 'vava_hud' and 'started' or 'missing' end
        _G.BeginTextCommandThefeedPost = function() end
        _G.AddTextComponentSubstringPlayerName = function(text) feed[#feed + 1] = text end
        _G.EndTextCommandThefeedPostTicker = function() end
        _G.PlayerPedId = function() return 7 end
        _G.DoesEntityExist = function() return true end
        _G.RequestAnimDict = function() end
        _G.HasAnimDictLoaded = function() return true end
        _G.RemoveAnimDict = function() end
        _G.DoesAnimDictExist = function() return true end
        _G.TaskPlayAnim = function() end
        _G.StopAnimTask = function() end
        _G.RegisterCommand = function(name, fn) commands[name] = fn end
        _G.RegisterKeyMapping = function() end
        for _, name in ipairs({ 'IsEntityDead', 'IsPedInAnyVehicle', 'IsPedRagdoll', 'IsPedFalling', 'IsPedCuffed',
            'IsNuiFocused', 'IsPauseMenuActive', 'HasEntityClearLosToEntity' }) do
            _G[name] = function() return false end
        end
        _G.DisableControlAction = function() end
        _G.DrawMarker = function() end
        _G.PlayerId = function() return 0 end
        _G.GetActivePlayers = function() return { 0 } end
        _G.GetPlayerPed = function() return 7 end
        _G.GetPlayerServerId = function() return 1 end
        _G.GetEntityCoords = function() return { x = 0, y = 0, z = 0 } end
        _G.GetEntityHeading = function() return 0 end
        _G.SetEntityHeading = function() end
        _G.GetGameplayCamRot = function() return { x = 0, y = 0, z = 0 } end
        _G.GetGameplayCamCoord = function() return { x = 0, y = -3, z = 1 } end
        _G.GetControlNormal = function() return 0 end
        _G.RegisterNetEvent = function(name, fn) net[name] = fn end
        _G.AddEventHandler = function(name, fn) events[name] = fn end
        _G.Entity = function() return { state = {} } end
        local fake = {}
        for _, fn in ipairs({ 'defineGauge', 'setGauge', 'removeGauge', 'notify' }) do
            fake[fn] = function(_, ...)
                hud[#hud + 1] = { fn = fn, args = table.pack(...) }
                return fn ~= 'notify'
            end
        end
        _G.exports = setmetatable({ vava_hud = fake }, { __call = function() end })
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        VavaCombat = nil
    end)

    describe('état reçu', function()
        it('réponse acceptée : médaillon déclaré une fois, puis 0,88 qui remonte à 0,2 / s après 1 s ; plein : 1', function()
            armed()
            rpcAnswer = { true, true, 880, 1000, 200 }
            press('legere')
            runThreads()
            assert.same({ 'taille_descendante' }, uses())
            local defines = hudCalls('defineGauge')
            assert.equal(1, #defines)
            assert.same({ n = 2, ID, { label = 'Endurance', icon = 'nui://vava_combat/web/icons/endurance.svg', order = 60,
                low = 0.25, critical = 0.10 } }, defines[1].args)
            assert.same({ n = 3, ID, 0.88, { perSecond = 0.2, delayMs = 1000 } }, lastSet().args)
            -- l'évènement du serveur (coup bloqué, mise à terre) : même lecture
            net['vava_combat:stamina'](1000, 0, 200)
            assert.equal(ID, lastSet().args[1])
            assert.equal(1, lastSet().args[2])
            assert.is_nil(lastSet().args[3])
            assert.equal(1, #hudCalls('defineGauge'))
        end)

        it('évènement invalide (1 001, chaîne, nil, flottant) : ignoré, rien au HUD', function()
            armed()
            gaugeView.setAwake(true)                           -- médaillon montré : un état pris serait poussé
            local before = #hud
            for _, bad in ipairs({ { 1001, 0, 200 }, { '500', 0, 200 }, { nil, 0, 200 }, { 500.5, 0, 200 },
                { 500, 10001, 200 }, { 500, 0, 1001 } }) do
                net['vava_combat:stamina'](table.unpack(bad, 1, 3))
            end
            assert.equal(before, #hud)
            assert.equal(1000, gaugeView.level(clock))
        end)

        it('reprise passée : valeur projetée, remontée immédiate ; pente nulle : aucune remontée', function()
            armed()
            gaugeView.apply(500, 1000, 200)
            clock = clock + 1500
            gaugeView.setAwake(true)
            hud = {}
            fire('core:character:unloaded', {})
            assert.equal(1, #hudCalls('removeGauge'))
            gaugeView.apply(500, 0, 0)
            assert.same({ n = 3, ID, 0.5, nil }, lastSet().args)
        end)
    end)

    describe('demandes', function()
        it('jauge à 10 : la Taille (12, marge 2) part ; à 9,9 : aucune, le texte une fois en 3 s même martelé', function()
            armed()
            gaugeView.apply(100, 1000, 200)
            rpcAnswer = { true, false, 'busy', 10 }
            press('legere')
            runThreads()
            assert.same({ 'taille_descendante' }, uses())
            clock = clock + 2000
            gaugeView.apply(99, 10000, 200)                  -- recharge dans 10 s : rien ne remonte
            feed = {}
            for _ = 1, 20 do
                press('legere')
                runThreads()
                clock = clock + 100
            end
            assert.same({ 'taille_descendante' }, uses())
            assert.same({ cfg.refusals.exhausted }, feed)
            clock = clock + 1000
            press('legere')
            assert.same({ cfg.refusals.exhausted, cfg.refusals.exhausted }, feed)
        end)

        it('R maintenue à 20 : la parade part (6), la garde non (14 + 2 < 25), texte une fois', function()
            armed()
            gaugeView.apply(200, 1000, 200)
            rpcAnswer = { true, true, 140, 1000, 200 }
            commands['+' .. cfg.keys.garde.command]()
            runThreads()
            local stance = VavaCombat.stance
            for i = 1, 30 do stance.tick(clock + 200 + i * 10) end
            clock = clock + 500
            runThreads()
            assert.same({ 'parade_epee' }, uses())
            assert.is_false(stance.guarding())
            assert.same({ cfg.refusals.exhausted }, feed)
        end)

        it('R maintenue à 3,9 : ni parade ni garde, texte une fois ; à 4 (6 − marge 2) la parade part', function()
            armed()
            gaugeView.apply(39, 1000, 200)
            commands['+' .. cfg.keys.garde.command]()
            runThreads()
            for i = 1, 30 do VavaCombat.stance.tick(clock + i * 10) end
            runThreads()
            assert.same({}, uses())
            assert.same({ cfg.refusals.exhausted }, feed)
            commands['-' .. cfg.keys.garde.command]()
            clock = clock + 100
            gaugeView.apply(40, 1000, 200)
            rpcAnswer = { true, false, 'exhausted', 100, 40, 900, 200 }
            commands['+' .. cfg.keys.garde.command]()
            runThreads()
            assert.same({ 'parade_epee' }, uses())
        end)

        it('refus exhausted (800) d\'un Fendant : clic droit retenu 800 ms ici, clic gauche aussitôt possible', function()
            armed()
            rpcAnswer = { true, false, 'exhausted', 800, 200, 650, 200 }
            press('lourde')
            runThreads()
            assert.same({ 'fendant' }, uses())
            assert.equal(0.2, lastSet().args[2])
            feed = {}
            clock = clock + 100
            press('lourde')
            runThreads()
            assert.same({ 'fendant' }, uses())
            rpcAnswer = { true, true, 80, 1000, 200 }
            press('legere')
            runThreads()
            assert.same({ 'fendant', 'taille_descendante' }, uses())
            -- après la Taille (900 ms) et l'attente, le clic droit repart si la jauge le paie
            clock = clock + 1000
            gaugeView.apply(1000, 0, 200)
            press('lourde')
            runThreads()
            assert.same({ 'fendant', 'taille_descendante', 'fendant' }, uses())
        end)
    end)

    describe('visibilité', function()
        it('mode éveillé, jauge pleine : montré ; endormi : retiré lingerMs après, une seule fois', function()
            armed()
            press('legere')
            assert.equal(1, #hudCalls('defineGauge'))
            assert.same({ n = 2, ID, 1 }, lastSet().args)
            local loop = runThreads()
            mode.sleep()
            for _, co in ipairs(loop) do
                if coroutine.status(co) == 'suspended' then assert(coroutine.resume(co)) end
            end
            runThreads()
            fireTimeouts(clock + cfg.gauge.lingerMs - 1)
            assert.equal(0, #hudCalls('removeGauge'))
            fireTimeouts(clock + 1)
            assert.equal(1, #hudCalls('removeGauge'))
            fireTimeouts(clock + 60000)
            assert.equal(1, #hudCalls('removeGauge'))
        end)

        it('endormi à moitié vide : retiré à fullAt + lingerMs ; un état reçu entre-temps périme l\'ancienne minuterie',
            function()
            armed()
            local start = clock
            gaugeView.apply(500, 1000, 200)                    -- pleine à start + 3 500
            assert.equal(1, #hudCalls('defineGauge'))
            fireTimeouts(start + 1000)
            gaugeView.apply(400, 1000, 200)                    -- pleine à start + 1 000 + 4 000
            fireTimeouts(start + 3500 + cfg.gauge.lingerMs)
            assert.equal(0, #hudCalls('removeGauge'))
            fireTimeouts(start + 5000 + cfg.gauge.lingerMs - 1)
            assert.equal(0, #hudCalls('removeGauge'))
            fireTimeouts(start + 5000 + cfg.gauge.lingerMs)
            assert.equal(1, #hudCalls('removeGauge'))
            fireTimeouts(start + 120000)
            assert.equal(1, #hudCalls('removeGauge'))
        end)

        it('réveillé avant l\'échéance : jamais retiré ; endormi plein sans médaillon : rien', function()
            armed()
            gaugeView.apply(500, 1000, 200)
            gaugeView.setAwake(true)
            fireTimeouts(clock + 60000)
            assert.equal(0, #hudCalls('removeGauge'))
            gaugeView.setAwake(false)
            fireTimeouts(clock + cfg.gauge.lingerMs)
            assert.equal(1, #hudCalls('removeGauge'))
            gaugeView.apply(1000, 0, 200)
            assert.equal(1, #hudCalls('defineGauge'))
        end)

        it('vava_hud redémarré : redéclaré, état projeté reposé ; personnage déchargé : retiré', function()
            armed()
            gaugeView.apply(500, 1000, 200)
            clock = clock + 2000                                -- 500 + 1 s de recharge = 700
            events.onClientResourceStart('vava_inventory')
            assert.equal(1, #hudCalls('defineGauge'))
            events.onClientResourceStart('vava_hud')
            assert.equal(2, #hudCalls('defineGauge'))
            assert.same({ n = 3, ID, 0.7, { perSecond = 0.2, delayMs = 0 } }, lastSet().args)
            fire('core:character:unloaded', {})
            assert.equal(1, #hudCalls('removeGauge'))
            assert.equal(1000, gaugeView.level(clock))
            -- plein et endormi : rien à redéclarer
            events.onClientResourceStart('vava_hud')
            assert.equal(2, #hudCalls('defineGauge'))
        end)

        it('sans vava_hud : rien appelé, aucune erreur ; la jauge garde sa prédiction', function()
            _G.GetResourceState = function() return 'missing' end
            armed()
            assert.has_no.errors(function() gaugeView.apply(300, 1000, 200) end)
            assert.equal(0, #hud)
            assert.is_false(gaugeView.allows(40, clock))
            assert.is_true(gaugeView.allows(30, clock))
        end)
    end)

    it('aucune boucle : client/endurance.lua ne crée ni thread ni attente', function()
        armed()
        local before = threadCount
        _G.Wait = function() error('Wait appelé') end
        gaugeView.apply(300, 1000, 200)
        gaugeView.setAwake(true)
        gaugeView.setAwake(false)
        net['vava_combat:stamina'](0, 1000, 200)
        events.onClientResourceStart('vava_hud')
        fire('core:character:unloaded', {})
        assert.equal(before, threadCount)
    end)
end)
