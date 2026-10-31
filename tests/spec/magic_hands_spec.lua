local helper = require('tests.helper')

-- Mains vides pour incanter (T-140, vava_magic 2.10.0), côté serveur : bridge/server.lua (HandsBusy, lu par les exports
-- `armed` et `shield` de vava_combat) et server/casting.lua (début et fin), avec des doublures : exports de vava_combat
-- réglables, état des ressources, horloge fixe, fiche, mana, monde et sorts simulés.
--   HandsBusy : `armed` si une arme de GTA est sortie (ped lu par le serveur) ou une arme tenue ; `shielded` si un
--     bouclier est au bras (`shield().ready`) ; rien pour un bouclier dans le dos, vava_combat absent, pas prêt ou en
--     erreur (une ligne de console par minute au plus ; `not_ready` signalé s'il dure une minute) ;
--   incantation : refusée au début, après les recharges (rien n'est réservé, aucune incantation en cours) ; brisée dès
--     qu'une arme passe en main (hook `vava_inventory:hold` after), et à la fin si l'arme a été prise pendant (mana
--     intacte, aucun temps de recharge) ; sans vava_combat, aucune restriction.
describe('vava_magic : mains vides pour incanter (serveur)', function()
    local Bridge, casting
    local now, combatState, weapon, weaponCode, shield, armedCalls, shieldCalls, warnings, spent
    local pedWeapon, peds, hooks, clientEvents

    local UNARMED_SIGNED = -1569615261   -- GetHashKey('WEAPON_UNARMED') tel que le rend Lua dans FiveM
    local PISTOL = 453432689             -- WEAPON_PISTOL

    local CASTER = 3
    local SPELL = 'lueur'

    local function loadMagic()
        helper.reset()
        VavaMagic = nil
        helper.loadAll({
            'modules/vava_magic/shared/constants.lua',
            'modules/vava_magic/config.lua',
            'modules/vava_magic/shared/geometry.lua',
        })
        now, combatState, weapon, weaponCode, shield = 1000, 'started', nil, 'no_weapon', nil
        armedCalls, shieldCalls, warnings, spent = 0, 0, {}, 0
        pedWeapon, peds, hooks, clientEvents = UNARMED_SIGNED, { [CASTER] = 101 }, {}, {}

        _G.GetGameTimer = function() return now end
        _G.TriggerClientEvent = function(event, target, ...)
            clientEvents[#clientEvents + 1] = { event = event, target = target, args = { ... } }
        end
        _G.GetPlayerPed = function(src) return peds[src] or 0 end
        _G.GetSelectedPedWeapon = function(ped)
            assert.equal(101, ped)
            return pedWeapon
        end
        _G.GetResourceState = function(name) return name == 'vava_combat' and combatState or 'missing' end
        local combat = {
            armed = function(src)
                armedCalls = armedCalls + 1
                assert.equal(CASTER, src)
                if type(weapon) == 'function' then return weapon() end
                if weapon then return weapon end
                return nil, weaponCode
            end,
            shield = function(src)
                shieldCalls = shieldCalls + 1
                assert.equal(CASTER, src)
                return shield
            end,
        }
        _G.exports = { vava_combat = setmetatable({}, { __index = function(_, fn)
            return function(_, ...) return combat[fn](...) end
        end }) }

        VavaMagic.resource = 'vava_magic'
        VavaMagic.ready = true
        VavaMagic.log = {
            warn = function(fmt, ...) warnings[#warnings + 1] = fmt:format(...) end,
            info = function() end,
            error = function() end,
        }
        VavaMagic.core = {
            hooks = {
                runBefore = function() return true end,
                runAfter = function() return true end,
                after = function(name, fn)
                    hooks[name] = fn
                    return 1
                end,
            },
        }
        helper.load('modules/vava_magic/bridge/server.lua')
        Bridge = VavaMagic.bridge
    end

    -- incantation sur le vrai bridge : vava_health et vava_admin absents (rien ne blesse, personne n'est à terre)
    local function loadCasting()
        local cfg = VavaMagic.config
        VavaMagic.world = {
            position = function() return { x = 0, y = 0, z = 0 } end,
            setState = function() end,
            inVehicle = function() return false end,
        }
        VavaMagic.spells = {
            get = function(name)
                if name ~= SPELL then return nil end
                return {
                    config = cfg.spells[SPELL],
                    begin = function() return true, {} end,
                    finish = function() return { success = true } end,
                }
            end,
        }
        VavaMagic.sheets = {
            get = function(src)
                if src ~= CASTER then return nil end
                return { isMage = true, characterId = 42, spells = { [SPELL] = { xp = 0 } } }
            end,
        }
        VavaMagic.mana = {
            current = function() return 100 end,
            spend = function(_, cost)
                spent = spent + cost
                return true
            end,
            give = function(_, amount) spent = spent - amount end,
        }
        VavaMagic.experience = { grant = function() return 0 end }
        VavaMagic.progression = { levelOf = function() return 1 end, cost = function() return 5 end }
        helper.load('modules/vava_magic/server/casting.lua')
        casting = VavaMagic.casting
        assert.is_true(casting.start())
    end

    after_each(function()
        _G.TriggerClientEvent, _G.GetResourceState, _G.exports = nil, nil, nil
        _G.GetPlayerPed, _G.GetSelectedPedWeapon = nil, nil
        VavaMagic = nil
    end)

    describe('bridge : HandsBusy', function()
        before_each(loadMagic)

        it('arme tenue : armed, sans consulter le bouclier', function()
            weapon = { item = 'epee_courte', category = 'une_main', family = 'epee' }
            assert.equal('armed', Bridge.HandsBusy(CASTER))
            assert.equal(1, armedCalls)
            assert.equal(0, shieldCalls)
        end)

        it('bouclier au bras (ready) : shielded ; dans le dos : rien', function()
            shield = { item = 'bouclier_rond', position = 'arm', ready = true }
            assert.equal('shielded', Bridge.HandsBusy(CASTER))
            shield = { item = 'bouclier_rond', position = 'back', ready = false }
            assert.is_nil(Bridge.HandsBusy(CASTER))
        end)

        it('mains vides, outil en main ou personnage absent pour vava_combat : rien', function()
            assert.is_nil(Bridge.HandsBusy(CASTER))
            weaponCode = 'no_character'
            assert.is_nil(Bridge.HandsBusy(CASTER))
        end)

        it('vava_combat pas encore prêt : aucune restriction', function()
            weaponCode = 'not_ready'
            assert.is_nil(Bridge.HandsBusy(CASTER))
        end)

        it('vava_combat absent ou arrêté : aucune restriction, aucun appel, aucune ligne de console', function()
            weapon = { item = 'epee_courte' }
            for _, state in ipairs({ 'missing', 'stopped', 'starting' }) do
                combatState = state
                assert.is_nil(Bridge.HandsBusy(CASTER))
            end
            assert.equal(0, armedCalls)
            assert.equal(0, #warnings)
        end)

        it('vava_combat en erreur : aucune restriction, une ligne de console par minute au plus', function()
            weapon = function() error('export en panne') end
            for _ = 1, 5 do assert.is_nil(Bridge.HandsBusy(CASTER)) end
            assert.equal(1, #warnings)
            assert.truthy(warnings[1]:find('vava_combat.armed', 1, true))
            now = now + 59999
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(1, #warnings)
            now = now + 1
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(2, #warnings)
        end)

        it('bouclier illisible (export en erreur) : aucune restriction', function()
            local combatShield = function() error('export en panne') end
            _G.exports.vava_combat = setmetatable({}, { __index = function(_, fn)
                if fn == 'shield' then return function() return combatShield() end end
                return function() return nil, 'no_weapon' end
            end })
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(1, #warnings)
        end)

        it('arme de GTA sortie (lue sur le ped) : armed, même sans vava_combat ; hash signé ou non', function()
            pedWeapon = PISTOL
            assert.equal('armed', Bridge.HandsBusy(CASTER))
            assert.equal(0, armedCalls)
            combatState = 'missing'
            assert.equal('armed', Bridge.HandsBusy(CASTER))
            pedWeapon = 0xA2719263
            assert.is_nil(Bridge.HandsBusy(CASTER))
            pedWeapon = UNARMED_SIGNED
            assert.is_nil(Bridge.HandsBusy(CASTER))
        end)

        it('ped absent ou arme illisible : pas d’arme de GTA, sans bruit', function()
            peds[CASTER] = nil
            assert.is_nil(Bridge.HandsBusy(CASTER))
            peds[CASTER] = 101
            pedWeapon = 0
            assert.is_nil(Bridge.HandsBusy(CASTER))
            pedWeapon = nil
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(0, #warnings)
        end)

        it('vava_combat pas prêt qui dure : une ligne de console après une minute, puis une par minute au plus', function()
            weaponCode = 'not_ready'
            assert.is_nil(Bridge.HandsBusy(CASTER))
            now = now + 59999
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(0, #warnings)
            now = now + 1
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(1, #warnings)
            assert.truthy(warnings[1]:find('pas prêt', 1, true))
            now = now + 30000
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(1, #warnings)
            now = now + 30000
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(2, #warnings)
            -- prêt de nouveau : le compte repart de zéro
            weaponCode = 'no_weapon'
            assert.is_nil(Bridge.HandsBusy(CASTER))
            weaponCode = 'not_ready'
            now = now + 120000
            assert.is_nil(Bridge.HandsBusy(CASTER))
            assert.equal(2, #warnings)
        end)

        it('OnHold s’abonne au hook vava_inventory:hold (after)', function()
            assert.is_true(Bridge.OnHold(function() end))
            assert.is_function(hooks['vava_inventory:hold'])
        end)
    end)

    describe('incantation', function()
        before_each(function()
            loadMagic()
            loadCasting()
        end)

        it('arme en main : début refusé (armed), rien n’est en cours ni réservé', function()
            weapon = { item = 'epee_courte' }
            local ok, code = casting.begin(CASTER, SPELL)
            assert.is_false(ok)
            assert.equal('armed', code)
            assert.is_nil(casting.current(CASTER))
            assert.equal(0, spent)
        end)

        it('bouclier au bras : début refusé (shielded) ; dans le dos : le sort part', function()
            shield = { item = 'bouclier_rond', ready = true }
            local ok, code = casting.begin(CASTER, SPELL)
            assert.is_false(ok)
            assert.equal('shielded', code)
            shield = { item = 'bouclier_rond', ready = false }
            local started, info = casting.begin(CASTER, SPELL)
            assert.is_true(started, tostring(info))
        end)

        it('mains vides : le sort part et aboutit', function()
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            now = now + info.ms
            local done, result = casting.finish(CASTER, SPELL, info.id)
            assert.is_true(done, tostring(result))
            assert.equal(5, spent)
        end)

        it('arme prise pendant l’incantation : brisée à la fin, mana intacte, aucune recharge', function()
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            now = now + info.ms
            weapon = { item = 'dague' }
            local done, code = casting.finish(CASTER, SPELL, info.id)
            assert.is_false(done)
            assert.equal('armed', code)
            assert.equal(0, spent)
            assert.is_nil(casting.current(CASTER))
            assert.equal(0, casting.cooldownLeft(42, SPELL))
            assert.equal(0, casting.globalLeft(42))
        end)

        it('bouclier passé au bras pendant l’incantation : brisée à la fin (shielded)', function()
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            now = now + info.ms
            shield = { item = 'bouclier_rond', ready = true }
            local done, code = casting.finish(CASTER, SPELL, info.id)
            assert.is_false(done)
            assert.equal('shielded', code)
            assert.equal(0, spent)
        end)

        it('sans vava_combat : aucune restriction, au début comme à la fin', function()
            combatState = 'missing'
            weapon = { item = 'epee_courte' }
            shield = { item = 'bouclier_rond', ready = true }
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            now = now + info.ms
            assert.is_true((casting.finish(CASTER, SPELL, info.id)))
            assert.equal(0, armedCalls)
            assert.equal(0, #warnings)
        end)

        it('vava_combat en erreur : le sort part, sans ligne de console à chaque lancer', function()
            weapon = function() error('export en panne') end
            for _ = 1, 3 do
                local ok, info = casting.begin(CASTER, SPELL)
                assert.is_true(ok, tostring(info))
                now = now + info.ms
                assert.is_true((casting.finish(CASTER, SPELL, info.id)))
                now = now + VavaMagic.config.casting.globalCooldownMs + VavaMagic.config.spells[SPELL].levels[1].cooldownMs
            end
            assert.equal(1, #warnings)
        end)

        local function abortsTo(code)
            local found = nil
            for _, e in ipairs(clientEvents) do
                if e.event == VavaMagic.EVENTS.CAST_ABORT then found = e end
            end
            assert.is_table(found)
            assert.equal(CASTER, found.target)
            assert.equal(code, found.args[2])
        end

        it('arme prise puis reposée avant la fin : brisée dès la prise, rien de dépensé', function()
            local hold = hooks['vava_inventory:hold']
            assert.is_function(hold)
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            weapon = { item = 'epee_courte' }
            hold({ source = CASTER, instanceId = 12, item = 'epee_courte', previous = 0 })
            assert.is_nil(casting.current(CASTER))
            abortsTo('armed')
            weapon = nil
            hold({ source = CASTER, instanceId = 0, previous = 12 })
            now = now + info.ms
            local done, code = casting.finish(CASTER, SPELL, info.id)
            assert.is_false(done)
            assert.equal('no_cast', code)
            assert.equal(0, spent)
            assert.equal(0, casting.cooldownLeft(42, SPELL))
        end)

        it('bouclier passé au bras pendant l’incantation (hook) : brisée (shielded)', function()
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            shield = { item = 'bouclier_rond', ready = true }
            hooks['vava_inventory:hold']({ source = CASTER, instanceId = 0, previous = 12 })
            assert.is_nil(casting.current(CASTER))
            abortsTo('shielded')
        end)

        it('outil pris pendant l’incantation, ou geste d’un joueur qui n’incante pas : rien ne change', function()
            local hold = hooks['vava_inventory:hold']
            hold({ source = 9, instanceId = 5, item = 'epee_courte', previous = 0 })
            assert.equal(0, armedCalls)
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            hold({ source = CASTER, instanceId = 7, item = 'hache_fer', previous = 0 })
            hold('bruit')
            assert.is_table(casting.current(CASTER))
            now = now + info.ms
            assert.is_true((casting.finish(CASTER, SPELL, info.id)))
        end)

        it('arme de GTA sortie : début refusé ; sortie pendant l’incantation : brisée à la fin', function()
            pedWeapon = PISTOL
            local ok, code = casting.begin(CASTER, SPELL)
            assert.is_false(ok)
            assert.equal('armed', code)
            pedWeapon = UNARMED_SIGNED
            local started, info = casting.begin(CASTER, SPELL)
            assert.is_true(started, tostring(info))
            now = now + info.ms
            pedWeapon = PISTOL
            local done, refusal = casting.finish(CASTER, SPELL, info.id)
            assert.is_false(done)
            assert.equal('armed', refusal)
            assert.equal(0, spent)
        end)

        it('en recharge : refusé pour la recharge, sans interroger vava_combat (R-4)', function()
            local ok, info = casting.begin(CASTER, SPELL)
            assert.is_true(ok, tostring(info))
            now = now + info.ms
            assert.is_true((casting.finish(CASTER, SPELL, info.id)))
            local calls = armedCalls
            weapon = { item = 'epee_courte' }
            local refused, code = casting.begin(CASTER, SPELL)
            assert.is_false(refused)
            assert.equal('global_cooldown', code)
            now = now + VavaMagic.config.casting.globalCooldownMs
            refused, code = casting.begin(CASTER, SPELL)
            assert.is_false(refused)
            assert.equal('cooldown', code)
            assert.equal(calls, armedCalls)
        end)
    end)
end)
