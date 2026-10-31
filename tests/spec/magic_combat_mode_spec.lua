local helper = require('tests.helper')

-- La magie et le mode combat (T-149, vava_magic 2.12.0 ; décisions du porteur du projet, spec T-112 § 13-1 à 13-3).
--   Règles pures (shared/hands.lua) : arme du royaume en main, la magie se tait aux touches et ne verrouille personne ;
--     pendant le rengainement, un mot propre (`sheathing`) au lieu de « rangez votre arme » ; arme de GTA : le rappel
--     d'avant ; roue et /lancer : toujours dit.
--   Côté joueur, sur la SEULE vue client (constantes, config_client.lua) : bridge/client.lua (CombatHands, un appel
--     isolé à `vava_combat:armed()`), client/messages.lua (le rengainement en simple avis), client/controls.lua (clic
--     droit, clic gauche, /lancer, roue), client/targeting.lua (verrou refusé, verrou posé qui tombe) ; natives et
--     modules voisins doublés, threads gardés et lancés par le test.
--   Côté serveur : server/states.lua (`states.hardControl`), l'export `hardControl` (server/api.lua) et sa lecture par
--     le bridge de vava_combat (`MagicHardControl`, refus `controlled` : tests/spec/combat_use_spec.lua).

local UNARMED = -1569615261   -- GetHashKey('WEAPON_UNARMED') tel que le rend Lua dans FiveM
local PISTOL = 453432689      -- WEAPON_PISTOL

describe('vava_magic et le mode combat (T-149)', function()
    after_each(function()
        _G.GetResourceState, _G.exports, _G.TriggerClientEvent, _G.TriggerEvent = nil, nil, nil, nil
        VavaMagic, VavaCombat = nil, nil
    end)

    describe('règles pures des mains (shared/hands.lua, vue client)', function()
        local hands

        before_each(function()
            helper.reset()
            helper.loadClientView('modules/vava_magic', 'VavaMagic')
            helper.load('modules/vava_magic/shared/hands.lua')
            hands = VavaMagic.hands
        end)

        it('code : sheathing pendant le rengainement, sinon armed', function()
            assert.equal('sheathing', hands.code(hands.SHEATHING))
            assert.equal('armed', hands.code(hands.WEAPON))
            assert.equal('armed', hands.code(hands.NATIVE))
        end)

        it('mains libres : rien à dire, verrou permis', function()
            assert.is_nil(hands.notice(nil, true, false, nil, 0, 5000))
            assert.is_nil(hands.notice(nil, false, false, nil, 0, 5000))
            assert.is_true(hands.canLock(nil))
        end)

        it('arme du royaume en main (mode combat) : aucun rappel aux touches, aucun verrou', function()
            assert.is_nil(hands.notice(hands.WEAPON, false, false, nil, 0, 5000))
            assert.is_false(hands.canLock(hands.WEAPON))
        end)

        it('roue et /lancer : toujours dit, même déjà dit ou à l’instant', function()
            assert.equal('armed', hands.notice(hands.WEAPON, true, true, 0, 1, 5000))
            assert.equal('sheathing', hands.notice(hands.SHEATHING, true, true, 0, 1, 5000))
            assert.equal('armed', hands.notice(hands.NATIVE, true, true, 0, 1, 5000))
        end)

        it('rengainement : un mot propre aux touches, une fois par arme, jamais deux fois en moins de minMs', function()
            assert.equal('sheathing', hands.notice(hands.SHEATHING, false, false, nil, 0, 5000))
            assert.is_nil(hands.notice(hands.SHEATHING, false, true, nil, 0, 5000))
            assert.is_nil(hands.notice(hands.SHEATHING, false, false, 1000, 5999, 5000))
            assert.equal('sheathing', hands.notice(hands.SHEATHING, false, false, 1000, 6000, 5000))
            assert.is_false(hands.canLock(hands.SHEATHING))
        end)

        it('arme de GTA : le rappel d’avant (une fois par arme, pas deux fois en moins de minMs), verrou permis', function()
            assert.equal('armed', hands.notice(hands.NATIVE, false, false, nil, 0, 5000))
            assert.is_nil(hands.notice(hands.NATIVE, false, true, nil, 0, 5000))
            assert.is_nil(hands.notice(hands.NATIVE, false, false, 0, 4999, 5000))
            assert.is_true(hands.canLock(hands.NATIVE))
        end)

        it('texte du rengainement dans la config du joueur', function()
            local text = VavaMagic.config.texts.errors.sheathing
            assert.is_string(text)
            assert.truthy(text:find('rengainez', 1, true))
        end)
    end)

    describe('côté joueur', function()
        local cfg, bridge, controls, targeting
        local combatState, combatArmed, armedCalls, notes, commands, threads, pedWeapon, woken, castCalls
        local players, locked, clock, nuiHandlers

        local function stubs()
            combatState, combatArmed, armedCalls, notes, commands, threads = 'started', nil, 0, {}, {}, {}
            pedWeapon, woken, castCalls, players, clock = UNARMED, 0, 0, {}, 1000
            _G.GetGameTimer = function() return clock end
            _G.GetResourceState = function(name)
                if name == 'vava_combat' then return combatState end
                if name == 'vava_hud' then return 'started' end
                return 'missing'
            end
            _G.exports = {
                vava_combat = setmetatable({}, { __index = function(_, fn)
                    return function()
                        assert.equal('armed', fn)
                        armedCalls = armedCalls + 1
                        if type(combatArmed) == 'function' then return combatArmed() end
                        return combatArmed
                    end
                end }),
                vava_hud = setmetatable({}, { __index = function()
                    return function(_, message, kind)
                        notes[#notes + 1] = { message = message, kind = kind }
                        return true
                    end
                end }),
            }
            _G.TriggerEvent = function() end
            _G.CreateThread = function(fn)
                woken = woken + 1
                threads[#threads + 1] = coroutine.create(fn)
            end
            _G.Wait = function() coroutine.yield() end
            _G.GetHashKey = function(name)
                assert.equal('WEAPON_UNARMED', name)
                return UNARMED
            end
            _G.PlayerPedId = function() return 1 end
            _G.PlayerId = function() return 0 end
            _G.GetSelectedPedWeapon = function() return pedWeapon end
            _G.RegisterNetEvent = function() end
            _G.GetActivePlayers = function()
                local list = { 0 }
                for _, p in ipairs(players) do list[#list + 1] = p.player end
                return list
            end
            _G.GetPlayerPed = function(player)
                if player == 0 then return 1 end
                for _, p in ipairs(players) do if p.player == player then return p.ped end end
                return 0
            end
            _G.GetPlayerServerId = function(player) return player + 100 end
            _G.GetEntityCoords = function(ped)
                if ped == 1 then return { x = 0.0, y = 0.0, z = 0.0 } end
                return { x = 5.0, y = 0.0, z = 0.0 }
            end
            _G.GetGameplayCamCoord = function() return { x = -1.0, y = 0.0, z = 0.0 } end
            _G.IsEntityDead = function() return false end
            _G.DoesEntityExist = function() return true end
            _G.HasEntityClearLosToEntity = function() return true end
            _G.DrawMarker = function() end
        end

        local function load()
            helper.reset()
            stubs()
            helper.loadClientView('modules/vava_magic', 'VavaMagic')
            cfg = VavaMagic.config
            VavaMagic.resource = 'vava_magic'
            VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
            VavaMagic.core = { hooks = { after = function() return 1 end }, rpc = { emit = function() end } }
            helper.loadAll({
                'modules/vava_magic/shared/geometry.lua',
                'modules/vava_magic/shared/hands.lua',
                'modules/vava_magic/bridge/client.lua',
                'modules/vava_magic/client/messages.lua',
            })
            bridge = VavaMagic.bridge
            local selected = 'boule_de_feu'
            VavaMagic.state = {
                isMage = function() return true end,
                selected = function() return selected end,
                setSelected = function(name)
                    selected = name
                    return true
                end,
                level = function(name) return cfg.spells[name] and 1 or nil end,
                spellConfig = function(name) return cfg.spells[name] end,
                knownSpells = function() return { 'boule_de_feu' } end,
                onChange = function() end,
            }
            nuiHandlers = {}
            VavaMagic.nui = {
                send = function() end,
                modal = function() return false end,
                on = function(name, fn) nuiHandlers[name] = fn end,
            }
            VavaMagic.hud = { setAwake = function() end }
            VavaMagic.aim = { direction = function() return { x = 1.0, y = 0.0, z = 0.0 } end }
            VavaMagic.casting = { isCasting = function() return false end, start = function() castCalls = castCalls + 1 end }
            VavaMagic.keys = {
                bind = function(name, handler) commands[name] = handler end,
                bindHold = function(name, down, up) commands['+' .. name], commands['-' .. name] = down, up end,
                command = function(name, _, handler) commands['/' .. name] = handler end,
            }
            helper.loadAll({
                'modules/vava_magic/client/targeting.lua',
                'modules/vava_magic/client/controls.lua',
                'modules/vava_magic/client/wheel.lua',
            })
            controls, targeting = VavaMagic.controls, VavaMagic.targeting
            -- un sort de feu : clic gauche d'un sort sans visée
            controls.register('boule_de_feu', { cast = function() castCalls = castCalls + 1 end })
        end

        local function texts()
            local list = {}
            for _, note in ipairs(notes) do list[#list + 1] = note.message end
            return list
        end

        local SWORD = { item = 'epee_courte', category = 'une_main', family = 'epee' }
        local SHEATHING = { item = 'epee_courte', category = 'une_main', family = 'epee', sheathing = true }

        before_each(load)
        after_each(function()
            for _, name in ipairs({ 'GetHashKey', 'PlayerPedId', 'PlayerId', 'GetSelectedPedWeapon', 'RegisterNetEvent',
                'GetActivePlayers', 'GetPlayerPed', 'GetPlayerServerId', 'GetEntityCoords', 'GetGameplayCamCoord',
                'IsEntityDead', 'DoesEntityExist', 'HasEntityClearLosToEntity', 'DrawMarker' }) do
                _G[name] = nil
            end
            -- CreateThread, Wait et GetGameTimer : doublures du helper rendues
            helper.reset()
        end)

        describe('bridge : CombatHands', function()
            it('arme en main : weapon ; qu’on rengaine : sheathing ; rien : nil ; un appel à l’export chaque fois', function()
                combatArmed = SWORD
                assert.equal('weapon', bridge.CombatHands())
                assert.is_true(bridge.IsArmed())
                combatArmed = SHEATHING
                assert.equal('sheathing', bridge.CombatHands())
                combatArmed = nil
                assert.is_nil(bridge.CombatHands())
                assert.is_false(bridge.IsArmed())
                assert.equal(5, armedCalls)
            end)

            it('vava_combat absent : nil sans appel ; en erreur : nil, sans bruit', function()
                combatArmed = SWORD
                combatState = 'missing'
                assert.is_nil(bridge.CombatHands())
                assert.equal(0, armedCalls)
                combatState = 'started'
                combatArmed = function() error('export en panne') end
                assert.is_nil(bridge.CombatHands())
                assert.equal(0, #notes)
            end)
        end)

        describe('touches de la magie', function()
            it('arme du royaume en main : ni rappel au clic droit, ni au clic gauche ; le mode ne s’éveille pas', function()
                combatArmed = SWORD
                commands['+viser']()
                commands['-viser']()
                commands.lancer()
                commands['+viser']()
                assert.same({}, texts())
                assert.equal(0, woken)
                assert.equal(0, castCalls)
            end)

            it('arme du royaume en main : /lancer et la roue le disent (rangez votre arme)', function()
                combatArmed = SWORD
                commands['/' .. cfg.commands.lancer]({})
                assert.same({ cfg.texts.errors.armed }, texts())
                assert.equal('warning', notes[1].kind)
                assert.is_true(controls.armed())
                controls.noticeArmed(true)
                assert.equal(2, #notes)
                assert.equal(0, castCalls)
            end)

            it('rengainement : un mot propre (simple avis) au clic droit, une fois par arme', function()
                combatArmed = SHEATHING
                commands['+viser']()
                assert.same({ cfg.texts.errors.sheathing }, texts())
                assert.equal('info', notes[1].kind)
                commands['+viser']()
                commands.lancer()
                assert.equal(1, #notes)
                assert.equal(0, woken)
            end)

            it('rengainement : le clic gauche le dit aussi, mode magie endormi', function()
                combatArmed = SHEATHING
                commands.lancer()
                assert.same({ cfg.texts.errors.sheathing }, texts())
                assert.equal(0, castCalls)
            end)

            it('rengainement : /lancer dit « vous rengainez », jamais « rangez votre arme »', function()
                combatArmed = SHEATHING
                commands['/' .. cfg.commands.lancer]({})
                assert.same({ cfg.texts.errors.sheathing }, texts())
            end)

            it('arme de GTA : le rappel « rangez votre arme » d’avant, une fois', function()
                pedWeapon = PISTOL
                commands['+viser']()
                commands['+viser']()
                assert.same({ cfg.texts.errors.armed }, texts())
                assert.equal(0, armedCalls)
                assert.equal(0, woken)
            end)

            it('mains libres : le clic droit éveille le mode, sans un mot', function()
                commands['+viser']()
                assert.equal(1, woken)
                assert.same({}, texts())
            end)
        end)

        describe('roue (client/wheel.lua)', function()
            it('sort choisi l’épée en main : « rangez votre arme », un seul appel à vava_combat (R-3)', function()
                combatArmed = SWORD
                nuiHandlers['wheel:choose']({ spell = 'lueur' })
                assert.same({ cfg.texts.errors.armed }, texts())
                assert.equal(1, armedCalls)
                assert.equal('lueur', VavaMagic.state.selected())
            end)

            it('pendant le rengainement : « vous rengainez » ; mains libres : rien', function()
                combatArmed = SHEATHING
                nuiHandlers['wheel:choose']({ spell = 'lueur' })
                assert.same({ cfg.texts.errors.sheathing }, texts())
                combatArmed = nil
                nuiHandlers['wheel:choose']({ spell = 'boule_de_feu' })
                assert.equal(1, #notes)
            end)
        end)

        describe('verrou de la magie (même bouton que le combat)', function()
            local function click()
                commands['+cible']()
                commands['-cible']()
            end

            it('arme du royaume en main ou qu’on rengaine : aucun verrou, aucun message', function()
                players = { { player = 2, ped = 22 } }
                combatArmed = SWORD
                click()
                assert.is_nil(targeting.current())
                combatArmed = SHEATHING
                click()
                assert.is_nil(targeting.current())
                assert.same({}, texts())
                assert.equal(0, #threads)
            end)

            it('mains libres : le verrou se pose (anneau de la magie)', function()
                players = { { player = 2, ped = 22 } }
                click()
                assert.equal(102, targeting.current())
                assert.equal(1, #threads)
            end)

            it('arme prise en main, verrou posé : il tombe à la vérification suivante', function()
                players = { { player = 2, ped = 22 } }
                click()
                locked = targeting.current()
                assert.equal(102, locked)
                local loop = threads[1]
                assert(coroutine.resume(loop))
                assert.equal(102, targeting.current())
                combatArmed = SWORD
                -- entre deux vérifications, rien n'est relu (une image)
                local before = armedCalls
                clock = clock + 16
                assert(coroutine.resume(loop))
                assert.equal(before, armedCalls)
                assert.equal(102, targeting.current())
                -- vérification suivante : la main en fait partie, le verrou tombe et la boucle s'arrête
                clock = clock + cfg.targeting.checkMs
                assert(coroutine.resume(loop))
                assert.equal('dead', coroutine.status(loop))
                assert.is_nil(targeting.current())
                assert.is_true(armedCalls > before)
            end)

            it('sort sans verrou : l’export de vava_combat n’est même pas lu', function()
                VavaMagic.state.setSelected('lueur')
                combatArmed = SWORD
                click()
                assert.equal(0, armedCalls)
            end)
        end)
    end)

    describe('serveur : contrôles durs (states.hardControl, export hardControl)', function()
        local states, registered, now, hardMagic, blockers, displayOrder

        local function loadStates()
            helper.reset()
            VavaMagic = nil
            helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
            if displayOrder then VavaMagic.config.states.order = displayOrder end
            now, registered, blockers = 1000, {}, {}
            _G.GetGameTimer = function() return now end
            _G.TriggerClientEvent = function() end
            _G.exports = setmetatable({}, { __call = function(_, name, fn) registered[name] = fn end })
            VavaMagic.resource = 'vava_magic'
            VavaMagic.log = { warn = function() end, info = function() end, error = function() end }
            VavaMagic.core = { hooks = { runBefore = function() return true end } }
            VavaMagic.bridge = { GetCharacterId = function(src) return src == 3 and 42 or nil end }
            VavaMagic.world = { freeze = function() end, setState = function() end }
            VavaMagic.combat = {}
            VavaMagic.casting = {
                current = function() return nil end,
                addBlocker = function(fn) blockers[#blockers + 1] = fn end,
            }
            VavaMagic.bridge.OnCouncilAction = function() return true end
            VavaMagic.sheets, VavaMagic.mana = {}, {}
            helper.loadAll({ 'modules/vava_magic/server/states.lua', 'modules/vava_magic/server/api.lua' })
            states = VavaMagic.states
            hardMagic = registered.hardControl
        end

        before_each(function()
            displayOrder = nil
            loadStates()
        end)

        it('ordre d’affichage incomplet (S-2) : gelé, renversé, chancelant restent des contrôles et empêchent d’incanter', function()
            displayOrder = { 'burn', 'wet', 'slow' }
            loadStates()
            states.start()
            assert.equal(1, #blockers)
            for _, case in ipairs({ { 'frozen', 'frozen' }, { 'knockdown', 'knocked' }, { 'stagger', 'staggered' } }) do
                assert.is_true(states.apply(3, case[1], { durationMs = 1500 }))
                assert.equal(case[1], states.hardControl(3))
                assert.equal(case[2], blockers[1](3))
                states.remove(3, case[1])
                assert.is_nil(blockers[1](3))
                now = now + 100000
            end
        end)

        it('aucun état, ou un état sans contrôle dur (mouillé, ralenti, brûlure) : nil', function()
            assert.is_nil(states.hardControl(3))
            assert.is_true(states.apply(3, 'wet'))
            assert.is_true(states.apply(3, 'slow', { strength = 0.5 }))
            assert.is_true(states.apply(3, 'burn', { damage = 0 }))
            assert.is_nil(states.hardControl(3))
        end)

        it('gelé, renversé, chancelant : le nom de l’état, tant qu’il dure', function()
            for _, name in ipairs({ 'frozen', 'knockdown', 'stagger' }) do
                assert.is_true(states.apply(3, name, { durationMs = 1500 }))
                assert.equal(name, states.hardControl(3))
                assert.is_true(states.remove(3, name))
                assert.is_nil(states.hardControl(3))
                -- l'immunité qui suit n'est pas un contrôle
                now = now + 100000
            end
        end)

        it('échu avant que sa minuterie ne tombe : déjà plus un contrôle', function()
            assert.is_true(states.apply(3, 'frozen', { durationMs = 2000 }))
            now = now + 1999
            assert.equal('frozen', states.hardControl(3))
            now = now + 1
            assert.is_nil(states.hardControl(3))
        end)

        it('export hardControl : même réponse ; source invalide : nil', function()
            assert.is_function(hardMagic)
            assert.is_nil(hardMagic(3))
            states.apply(3, 'knockdown')
            assert.equal('knockdown', hardMagic(3))
            assert.is_nil(hardMagic('3'))
            assert.is_nil(hardMagic(3.5))
            -- 3.0 serait la même clé de table que 3 : refusé comme tout nombre non entier
            assert.is_nil(hardMagic(3.0))
            assert.is_nil(hardMagic(9))
        end)

        it('lu par le bridge de vava_combat (MagicHardControl) : refus de frapper tant qu’il dure', function()
            local magicState = 'started'
            _G.GetResourceState = function(name) return name == 'vava_magic' and magicState or 'missing' end
            _G.exports = { vava_magic = { hardControl = function(_, src) return hardMagic(src) end } }
            VavaCombat = {
                core = {}, config = {}, EVENTS = {}, SHIELD_FIELD = 'vava_combat:shield',
                log = { warn = function() end, info = function() end },
            }
            helper.load('modules/vava_combat/bridge/server.lua')
            local combatBridge = VavaCombat.bridge
            assert.is_nil(combatBridge.MagicHardControl(3))
            states.apply(3, 'frozen')
            assert.equal('frozen', combatBridge.MagicHardControl(3))
            magicState = 'stopped'
            assert.is_nil(combatBridge.MagicHardControl(3))
        end)
    end)
end)
