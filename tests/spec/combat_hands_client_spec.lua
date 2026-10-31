local helper = require('tests.helper')

-- Côté joueur (modules/vava_combat/bridge/client.lua, client/hands.lua, keys.lua, targeting.lua, attack.lua, mode.lua
-- réels, T-112), sur la SEULE vue client (constantes et config_client.lua) et un faux core : hooks locaux, compteur
-- d'appels à characters.current, rpc.call réglable ; natives doublées, threads gardés et lancés par le test (jamais
-- seuls). Vérifie le cache de la main (rapport T-140, R-1 : aucune lecture du personnage par appel), dégainer et
-- rengainer, le mode combat qui ne s'éveille que par une touche et pour une arme qui a des techniques, et le coup prédit
-- puis coupé au refus du serveur. Règles documentées : docs/plan/specs/T-112.md § 8 et § 11.1.

local HANDS = 'vava_inventory:hands'

describe('vava_combat client : main, dégainer, mode combat', function()
    local cfg, bridge, hands, mode, attack
    local clock, hooks, currentCalls, currentCharacter, rpcCalls, rpcAnswer, threads, commands, played, stopped
    local feed, dictsLoaded
    local STUBBED = { 'GetResourceState', 'BeginTextCommandThefeedPost', 'AddTextComponentSubstringPlayerName',
        'EndTextCommandThefeedPostTicker', 'PlayerPedId', 'DoesEntityExist', 'RequestAnimDict', 'HasAnimDictLoaded',
        'RemoveAnimDict', 'DoesAnimDictExist', 'TaskPlayAnim', 'StopAnimTask', 'RegisterCommand', 'RegisterKeyMapping',
        'IsEntityDead', 'IsPedInAnyVehicle', 'IsPedRagdoll', 'IsPedFalling', 'IsPedCuffed', 'IsNuiFocused',
        'IsPauseMenuActive', 'DisableControlAction', 'PlayerId', 'GetActivePlayers', 'GetPlayerPed', 'GetPlayerServerId',
        'GetEntityCoords', 'GetEntityHeading', 'SetEntityHeading', 'GetGameplayCamRot', 'GetGameplayCamCoord',
        'HasEntityClearLosToEntity', 'DrawMarker', 'exports' }

    local function fire(name, payload)
        for _, fn in ipairs(hooks[name] or {}) do fn(payload) end
    end

    local function character(item)
        return { id = 4, firstName = 'Aldric', lastName = 'Morn', fields = { [HANDS] = item and { item = item } or nil } }
    end

    --- Lance les threads gardés (une fois chacun, jusqu'à leur première attente).
    local function runThreads()
        local list = threads
        threads = {}
        for _, co in ipairs(list) do assert(coroutine.resume(co)) end
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

    local function load(activeCharacter)
        currentCharacter = activeCharacter
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
            characters = {
                current = function()
                    currentCalls = currentCalls + 1
                    return currentCharacter
                end,
            },
            rpc = {
                call = function(name, ...)
                    rpcCalls[#rpcCalls + 1] = { name = name, args = { ... } }
                    return table.unpack(rpcAnswer)
                end,
            },
        }
        helper.loadAll({
            'modules/vava_combat/shared/geometry.lua',
            'modules/vava_combat/shared/techniques.lua',
            'modules/vava_combat/bridge/client.lua',
            'modules/vava_combat/client/hands.lua',
            'modules/vava_combat/client/keys.lua',
            'modules/vava_combat/client/targeting.lua',
            'modules/vava_combat/client/attack.lua',
            'modules/vava_combat/client/mode.lua',
        })
        bridge, hands, mode, attack = VavaCombat.bridge, VavaCombat.hands, VavaCombat.mode, VavaCombat.attack
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        clock, hooks, currentCalls, rpcCalls, rpcAnswer, threads, commands = 1000, {}, 0, {}, { true, true }, {}, {}
        played, stopped, feed, dictsLoaded = {}, {}, {}, true
        _G.GetGameTimer = function() return clock end
        _G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
        _G.Wait = function() coroutine.yield() end
        _G.GetResourceState = function() return 'missing' end
        _G.BeginTextCommandThefeedPost = function() end
        _G.AddTextComponentSubstringPlayerName = function(text) feed[#feed + 1] = text end
        _G.EndTextCommandThefeedPostTicker = function() end
        _G.PlayerPedId = function() return 7 end
        _G.DoesEntityExist = function() return true end
        _G.RequestAnimDict = function() end
        _G.HasAnimDictLoaded = function() return dictsLoaded end
        _G.RemoveAnimDict = function() end
        _G.DoesAnimDictExist = function() return true end
        _G.TaskPlayAnim = function(_, dict, clip, _, _, duration) played[#played + 1] = { dict = dict, clip = clip, ms = duration } end
        _G.StopAnimTask = function(_, dict, clip) stopped[#stopped + 1] = { dict = dict, clip = clip } end
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
        _G.exports = setmetatable({}, { __call = function() end })
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        VavaCombat = nil
    end)

    describe('cache de la main', function()
        it('chargé : la main est lue une fois, puis jamais plus (1 000 appels, aucun characters.current)', function()
            load(nil)
            assert.equal(1, currentCalls)       -- une lecture au chargement du fichier (aucun personnage)
            currentCalls = 0
            fire('core:character:loaded', character('epee_courte'))
            for _ = 1, 1000 do assert.equal('epee_courte', bridge.HandItem()) end
            for _ = 1, 1000 do assert.equal('epee_courte', hands.armed().item) end
            assert.equal(0, currentCalls)
            -- personnage chargé avec la main restaurée : en garde d'emblée, aucun geste
            assert.is_true(hands.ready(clock))
            assert.equal(0, #played)
        end)

        it('un autre champ ne change rien ; la main à nil : rengainement 1 500 ms', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            fire('core:character:fieldChanged', { field = 'vava_needs:state', value = { item = 'pain' } })
            assert.equal('epee_courte', bridge.HandItem())
            clock = 5000
            fire('core:character:fieldChanged', { field = HANDS, value = nil })
            assert.is_nil(bridge.HandItem())
            assert.same({ item = 'epee_courte', category = 'une_main', family = 'epee', sheathing = true }, hands.armed())
            assert.same({ dict = cfg.draw.sheatheGesture.dict, clip = cfg.draw.sheatheGesture.clip, ms = 1500 },
                played[#played])
            clock = 6499
            assert.is_true(hands.armed().sheathing)
            clock = 6500
            assert.is_nil(hands.armed())
        end)

        it('déchargé : plus rien en main, aucun rengainement', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            fire('core:character:unloaded', { id = 4 })
            assert.is_nil(bridge.HandItem())
            assert.is_nil(hands.armed())
        end)

        it('module redémarré, personnage déjà en jeu l\'arme en main : une seule lecture, en garde d\'emblée', function()
            load(character('epee_courte'))
            assert.equal(1, currentCalls)
            assert.equal('epee_courte', bridge.HandItem())
            assert.equal('epee_courte', hands.armed().item)
            assert.is_true(hands.ready(clock))
        end)

        it('un outil ou un bouclier n\'est pas une arme ; un outil après l\'arme : rengainement', function()
            load(nil)
            fire('core:character:loaded', character('hache_fer'))
            assert.is_nil(hands.armed())
            fire('core:character:fieldChanged', { field = HANDS, value = { item = 'epee_courte' } })
            fire('core:character:fieldChanged', { field = HANDS, value = { item = 'hache_fer' } })
            assert.is_true(hands.armed().sheathing)
        end)
    end)

    describe('dégainer', function()
        it('arme prise : geste de dégainer, pas en garde avant 800 ms', function()
            load(nil)
            fire('core:character:loaded', character(nil))
            fire('core:character:fieldChanged', { field = HANDS, value = { item = 'epee_courte' } })
            assert.same({ dict = cfg.draw.drawGesture.dict, clip = cfg.draw.drawGesture.clip, ms = 800 }, played[1])
            assert.is_false(hands.ready(clock + 799))
            assert.is_true(hands.ready(clock + 800))
        end)
    end)

    describe('mode combat', function()
        it('arme sans technique (Épée longue) : armed() la rend, le mode ne s\'éveille pas, refus dit une fois', function()
            load(nil)
            fire('core:character:loaded', character('epee_longue'))
            assert.same({ item = 'epee_longue', category = 'deux_mains', family = 'epee' }, hands.armed())
            press('legere')
            press('legere')
            press('cible')
            assert.is_false(mode.isActive())
            assert.equal(0, #threads)
            assert.same({ cfg.refusals.no_style }, feed)
            assert.equal(0, #rpcCalls)
        end)

        it('arme en main sans rien presser : aucune boucle ; une touche l\'éveille, le geste part aussitôt', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            -- seul le chargement des gestes du style, borné et terminé aussitôt
            runThreads()
            assert.equal(0, #threads)
            assert.is_false(mode.isActive())
            played = {}
            press('legere')
            assert.is_true(mode.isActive())
            local taille = cfg.techniques.taille_descendante
            assert.same({ dict = taille.gesture.dict, clip = taille.gesture.clip, ms = 900 }, played[1])
            -- deux threads : la boucle du mode, la demande au serveur
            assert.equal(2, #threads)
            runThreads()
            assert.same({ { name = 'vava_combat:use', args = { 'taille_descendante', 0 } } }, rpcCalls)
            assert.equal(0, #stopped)
        end)

        it('pendant la préparation, une seconde touche n\'envoie rien ; pendant la récupération, l\'Estoc part', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            press('legere')
            runThreads()
            clock = clock + 200
            press('legere')
            assert.equal(0, #threads)
            clock = clock + 300   -- 500 ms après le départ : récupération de la Taille
            press('legere')
            runThreads()
            assert.equal('estoc_rapide', rpcCalls[2].args[1])
        end)

        it('refus du serveur : geste coupé ; texte selon le code (rien pour busy)', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            rpcAnswer = { true, false, 'busy', 300 }
            press('legere')
            runThreads()
            assert.equal(1, #stopped)
            assert.same({}, feed)
            clock = clock + 2000
            rpcAnswer = { true, false, 'controlled' }
            press('legere')
            runThreads()
            assert.equal(2, #stopped)
            assert.same({ cfg.refusals.controlled }, feed)
            clock = clock + 2000
            rpcAnswer = { true, false, 'refused', 'Vous êtes au cachot.' }
            press('legere')
            runThreads()
            assert.same({ cfg.refusals.controlled, 'Vous êtes au cachot.' }, feed)
        end)

        it('arme tout juste prise : aucune demande avant 800 ms, refus dit sans réseau', function()
            load(nil)
            fire('core:character:loaded', character(nil))
            fire('core:character:fieldChanged', { field = HANDS, value = { item = 'epee_courte' } })
            runThreads()
            press('legere')
            runThreads()
            assert.equal(0, #rpcCalls)
            assert.same({ cfg.refusals.drawing }, feed)
            clock = clock + 800
            press('legere')
            runThreads()
            assert.equal(1, #rpcCalls)
        end)

        it('la main change : le mode s\'endort (rengainer)', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            press('legere')
            assert.is_true(mode.isActive())
            fire('core:character:fieldChanged', { field = HANDS, value = nil })
            assert.is_false(mode.isActive())
            press('legere')
            assert.is_false(mode.isActive())
        end)

        it('interface au focus : le mode ne devient pas actif, aucun coup', function()
            load(nil)
            fire('core:character:loaded', character('epee_courte'))
            _G.IsNuiFocused = function() return true end
            -- les natives sont lues au chargement : on recharge le mode avec la nouvelle doublure
            helper.load('modules/vava_combat/client/mode.lua')
            mode = VavaCombat.mode
            commands[cfg.keys.legere.command]()
            assert.is_false(mode.isActive())
            assert.equal(0, #rpcCalls)
        end)

        it('les contrôles coupés n\'incluent jamais Échap ni P (vava_pause)', function()
            load(nil)
            for _, control in ipairs(cfg.mode.blocked) do
                assert.is_true(control ~= 199 and control ~= 200 and control ~= 177 and control ~= 202, tostring(control))
            end
        end)
    end)
end)
