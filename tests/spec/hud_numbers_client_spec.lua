local helper = require('tests.helper')

-- Chiffres des coups côté joueur (vava_hud 1.7.0, T-155 § 8.1 et § 11.1) : client/numbers.lua et client/pause.lua réels,
-- sur la config du client, avec un faux core (hooks locaux), une fausse bannière (export setting), des messages à la
-- page notés, et des natives simulées : peds placés à la main, projection à l'écran réglable, threads gardés et
-- avancés par le test (jamais seuls). Vérifie l'export hitText (codes de refus, message `number`), le suivi (un
-- `numbersMove` seulement si un chiffre a bougé ou s'est caché, jamais d'attente de 0 ms, arrêt de la boucle), les
-- plafonds et l'effacement.
describe('vava_hud client : chiffres des coups', function()
    local numbers, cfg
    local clock, messages, hooks, threads, waits, warns, positions, offscreen, pauseSettings, pauseState
    local ME, TARGET, FAR = 1, 2, 3
    local PED_ME, PED_TARGET, PED_FAR = 100, 200, 300
    local STUBBED = { 'PlayerId', 'PlayerPedId', 'GetPlayerServerId', 'GetPlayerFromServerId', 'GetPlayerPed',
        'DoesEntityExist', 'GetPedBoneCoords', 'GetFinalRenderedCamCoord', 'GetScreenCoordFromWorldCoord',
        'GetResourceState', 'AddEventHandler', 'exports' }

    local function load(tune)
        helper.reset()
        VavaHud = nil
        helper.load('modules/vava_hud/config_client.lua')
        if tune then tune(VavaHud.config.numbers) end
        helper.load('modules/vava_hud/shared/numbers.lua')
        cfg = VavaHud.config.numbers
        local log = { warn = function(fmt, ...) warns[#warns + 1] = fmt:format(...) end, info = function() end }
        VavaHud.resource = 'vava_hud'
        VavaHud.core = {
            log = log,
            hooks = {
                after = function(name, fn)
                    hooks[name] = fn
                    return 1
                end,
            },
        }
        VavaHud.nui = { send = function(action, payload) messages[#messages + 1] = { action = action, payload = payload } end }
        _G.GetGameTimer = function() return clock end
        _G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
        _G.Wait = function(ms)
            waits[#waits + 1] = ms
            coroutine.yield()
        end
        helper.loadAll({ 'modules/vava_hud/client/pause.lua', 'modules/vava_hud/client/numbers.lua' })
        numbers = VavaHud.numbers
        numbers.setVisible(true)
        messages = {}
    end

    --- Avance l'horloge de `ms` et laisse tourner chaque thread jusqu'à sa prochaine attente.
    local function step(ms)
        clock = clock + ms
        local list = threads
        threads = {}
        for _, co in ipairs(list) do
            if coroutine.status(co) == 'suspended' then
                assert(coroutine.resume(co))
                if coroutine.status(co) == 'suspended' then threads[#threads + 1] = co end
            end
        end
    end

    local function sent(action)
        local out = {}
        for _, m in ipairs(messages) do
            if m.action == action then out[#out + 1] = m.payload end
        end
        return out
    end

    before_each(function()
        clock, messages, hooks, threads, waits, warns = 50000, {}, {}, {}, {}, {}
        positions = { [PED_ME] = { 0, 2, 0 }, [PED_TARGET] = { 10, 5, 0 }, [PED_FAR] = { 0, 61, 0 } }
        offscreen = false
        pauseSettings, pauseState = { ['combat.numbers'] = 'tous' }, 'started'
        _G.PlayerId = function() return 0 end
        _G.PlayerPedId = function() return PED_ME end
        _G.GetPlayerServerId = function() return ME end
        _G.GetPlayerFromServerId = function(id)
            if id == ME then return 0 end
            if id == TARGET then return 5 end
            if id == FAR then return 6 end
            return -1
        end
        _G.GetPlayerPed = function(index) return ({ [0] = PED_ME, [5] = PED_TARGET, [6] = PED_FAR })[index] or 0 end
        _G.DoesEntityExist = function(ped) return positions[ped] ~= nil end
        _G.GetPedBoneCoords = function(ped)
            local p = positions[ped] or { 0, 0, 0 }
            return { x = p[1], y = p[2], z = p[3] }
        end
        _G.GetFinalRenderedCamCoord = function() return { x = 0, y = 0, z = 0 } end
        -- écran : x de 0,5 ± 1 % par mètre de côté, y de 0,4 ± 1 % par mètre de profondeur
        _G.GetScreenCoordFromWorldCoord = function(x, y)
            if offscreen then return false, 0, 0 end
            return true, 0.5 + x * 0.01, 0.4 + y * 0.01
        end
        _G.GetResourceState = function(name) return name == 'vava_pause' and pauseState or 'missing' end
        _G.AddEventHandler = function() end
        _G.exports = { vava_pause = { setting = function(_, key) return pauseSettings[key] end } }
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        VavaHud = nil
    end)

    it('hitText valide : un message `number`, la boucle de suivi lancée', function()
        load()
        assert.same({ true }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        local list = sent('number')
        assert.equal(1, #list)
        local n = list[1]
        assert.same({ 1, 'dealt', '12' }, { n.id, n.cls, n.text })
        assert.near(0.6, n.x, 1e-9)
        assert.near(0.45, n.y, 1e-9)
        assert.is_number(n.dx)
        assert.equal(0, n.dy)
        assert.is_nil(n.sub)
        assert.equal(1, #threads)
        -- un mot dessous, un chiffre reçu au-dessus de soi
        numbers.hit('taken', ME, 'block', 72)
        assert.same({ '7', 'Bloqué', 'taken' }, { sent('number')[2].text, sent('number')[2].sub, sent('number')[2].cls })
        assert.equal(1, #threads)
    end)

    it('arguments refusés : le code, rien envoyé', function()
        load()
        assert.same({ false, 'invalid_side' }, { numbers.hit('vu', TARGET, 'hit', 1) })
        assert.same({ false, 'invalid_anchor' }, { numbers.hit('dealt', 0, 'hit', 1) })
        assert.same({ false, 'invalid_issue' }, { numbers.hit('dealt', TARGET, 'soin', 1) })
        assert.same({ false, 'invalid_amount' }, { numbers.hit('dealt', TARGET, 'hit', 7.5) })
        -- joueur inconnu de ce client : ancre invalide pour un chiffre donné
        assert.same({ false, 'invalid_anchor' }, { numbers.hit('dealt', 77, 'hit', 1) })
        assert.equal(0, #messages)
        assert.equal(0, #threads)
    end)

    it('HUD masqué : hidden, rien envoyé', function()
        load()
        numbers.setVisible(false)
        assert.same({ false, 'hidden' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        assert.equal(0, #sent('number'))
    end)

    it('réglage du joueur : infliges → les reçus refusés ; aucun → tout refusé ; bannière absente → défaut', function()
        pauseSettings['combat.numbers'] = 'infliges'
        load()
        assert.same({ false, 'off' }, { numbers.hit('taken', ME, 'hit', 120) })
        assert.same({ true }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        pauseSettings['combat.numbers'] = 'aucun'
        hooks['vava_pause:settingChanged']({ key = 'combat.numbers', value = 'aucun' })
        assert.same({ false, 'off' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        pauseState = 'stopped'
        hooks['vava_pause:settingChanged']({ key = 'combat.numbers', value = 'aucun' })
        assert.same({ true }, { numbers.hit('taken', ME, 'hit', 120) })
        assert.equal(2, #sent('number'))
    end)

    it('config.numbers.enabled = false, ou config hors bornes : off (une ligne de console)', function()
        load(function(n) n.enabled = false end)
        assert.same({ false, 'off' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        assert.equal(0, #warns)
        load(function(n) n.followMs = 0 end)
        assert.same({ false, 'off' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        assert.equal(1, #warns)
        assert.matches('followMs', warns[1])
    end)

    it('ancre hors de l\'écran : donné → offscreen ; reçu → position de repli', function()
        load()
        offscreen = true
        assert.same({ false, 'offscreen' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
        assert.same({ true }, { numbers.hit('taken', ME, 'hit', 120) })
        local n = sent('number')[1]
        assert.same({ cfg.takenFallback.x, cfg.takenFallback.y }, { n.x, n.y })
    end)

    it('cible à 61 m de la caméra : far', function()
        load()
        assert.same({ false, 'far' }, { numbers.hit('dealt', FAR, 'hit', 120) })
        assert.equal(0, #messages)
    end)

    it('point fixe (mannequin) : montré, suivi sans ped', function()
        load()
        assert.same({ true }, { numbers.hit('dealt', { x = 10, y = 5, z = 1 }, 'stagger', 216) })
        local n = sent('number')[1]
        assert.same({ '22', 'Chancelle', 'dealt big' }, { n.text, n.sub, n.cls })
        assert.near(0.6, n.x, 1e-9)
    end)

    it('16 par seconde au plus ; 10 à l\'écran au plus, le plus ancien oublié', function()
        load()
        for i = 1, 16 do assert.same({ true }, { numbers.hit('dealt', TARGET, 'hit', i) }) end
        assert.same({ false, 'too_many' }, { numbers.hit('dealt', TARGET, 'hit', 1) })
        step(0)                                   -- la boucle part et attend
        -- tous bougent : seuls les 10 derniers sont suivis
        positions[PED_TARGET] = { 20, 5, 0 }
        step(cfg.followMs)
        local moves = sent('numbersMove')
        assert.equal(1, #moves)
        assert.equal(10, #moves[1].list)
        assert.equal(7, moves[1].list[1].id)
        assert.equal(16, moves[1].list[10].id)
        clock = clock + 1000
        assert.same({ true }, { numbers.hit('dealt', TARGET, 'hit', 1) })
    end)

    it('suivi : un numbersMove seulement au-delà de followEpsilon ou caché ; jamais d\'attente de 0 ms ; arrêt', function()
        load()
        numbers.hit('dealt', TARGET, 'hit', 120)
        step(0)                                   -- la boucle part et attend
        step(cfg.followMs)                        -- rien n'a bougé
        assert.equal(0, #sent('numbersMove'))
        positions[PED_TARGET] = { 10.3, 5, 0 }    -- 0,003 de l'écran : sous le seuil
        step(cfg.followMs)
        assert.equal(0, #sent('numbersMove'))
        positions[PED_TARGET] = { 11, 5, 0 }      -- 0,01
        step(cfg.followMs)
        local moves = sent('numbersMove')
        assert.equal(1, #moves)
        assert.same({ { id = 1, x = 0.61, y = 0.45 } }, moves[1].list)
        offscreen = true                          -- caché une fois, pas deux
        step(cfg.followMs)
        step(cfg.followMs)
        moves = sent('numbersMove')
        assert.equal(2, #moves)
        assert.same({ { id = 1, hidden = true } }, moves[2].list)
        offscreen = false
        step(cfg.followMs)
        assert.same({ { id = 1, x = 0.61, y = 0.45 } }, sent('numbersMove')[3].list)
        -- au-delà de durationMs : plus rien à suivre, la boucle s'arrête d'elle-même
        step(cfg.durationMs)
        assert.equal(0, #threads)
        for _, ms in ipairs(waits) do assert.equal(cfg.followMs, ms) end
        -- un nouveau chiffre relance une seule boucle
        numbers.hit('dealt', TARGET, 'hit', 120)
        assert.equal(1, #threads)
    end)

    -- relecture réseau R-5 : une lecture de la tête à la création, une par ped et par passage ; positions à 1e-4
    it('une lecture de la tête par chiffre créé, puis une par ped et par passage ; positions arrondies', function()
        local reads = 0
        local real = _G.GetPedBoneCoords
        _G.GetPedBoneCoords = function(...)
            reads = reads + 1
            return real(...)
        end
        load()
        for _ = 1, 3 do numbers.hit('dealt', TARGET, 'hit', 120) end
        assert.equal(3, reads)
        step(0)
        positions[PED_TARGET] = { 11.123456, 5, 0 }
        step(cfg.followMs)
        assert.equal(4, reads)
        local move = sent('numbersMove')[1].list[1]
        assert.equal(0.6112, move.x)       -- 0,61123456
        assert.equal(3, #sent('numbersMove')[1].list)
    end)

    it('cascade : deux coups rapprochés sur la même cible ne se recouvrent pas', function()
        load()
        numbers.hit('dealt', TARGET, 'hit', 120)
        clock = clock + 100
        numbers.hit('dealt', TARGET, 'hit', 80)
        local a, b = sent('number')[1], sent('number')[2]
        assert.equal(0, a.dy)
        assert.near(-cfg.stackStepVh, b.dy, 1e-9)
    end)

    it('clear : numbersClear une fois, la boucle s\'arrête ; HUD masqué efface', function()
        load()
        numbers.hit('dealt', TARGET, 'hit', 120)
        numbers.clear()
        numbers.clear()
        assert.equal(1, #sent('numbersClear'))
        step(cfg.followMs)
        assert.equal(0, #threads)
        numbers.hit('dealt', TARGET, 'hit', 120)
        numbers.setVisible(false)
        assert.equal(2, #sent('numbersClear'))
        assert.same({ false, 'hidden' }, { numbers.hit('dealt', TARGET, 'hit', 120) })
    end)

    it('rythme pour la page (init.numbers)', function()
        load()
        assert.same({ durationMs = cfg.durationMs, riseVh = cfg.riseVh, followMs = cfg.followMs, maxAlive = cfg.maxAlive,
            maxPerSecond = cfg.maxPerSecond }, numbers.settings())
    end)
end)
