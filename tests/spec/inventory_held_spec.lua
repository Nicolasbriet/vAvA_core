local helper = require('tests.helper')

-- Objet tenu en main (T-045, vava_inventory 1.7.0) : la main est publiée sur le statebag du ped du porteur, réduite à
-- { id, item } ; chaque client retrouve l'accessoire dans la liste des objets tenables (GlobalState). Règles pures de
-- shared/held.lua, puis publication et garde du serveur (server/pedstate.lua) sur des doublures : comme dans FiveM,
-- le gestionnaire de changement d'un statebag est appelé AVANT que la nouvelle valeur soit appliquée.
describe('vava_inventory objet en main', function()
    local held, cfg
    local DECLARED = {
        hache_fer = { model = 'prop_tool_fireaxe', bone = 57005, offset = { 0.1, 0.02, 0.0 }, rotation = { 0.0, 0.0, 0.0 } },
    }

    local function loadShared()
        helper.reset()
        VavaInventory = nil
        helper.loadAll({
            'modules/vava_inventory/shared/constants.lua',
            'modules/vava_inventory/config.lua',
            'modules/vava_inventory/shared/held.lua',
        })
        held, cfg = VavaInventory.held, VavaInventory.config.hands
    end

    describe('règles pures', function()
        before_each(loadShared)

        it('publie { id, item } et rien d\'autre', function()
            assert.same({ id = 42, item = 'hache_fer' }, held.value(42, 'hache_fer'))
            assert.is_true(held.valid(held.value(42, 'hache_fer')))
            assert.is_true(held.valid(nil))
        end)

        it('refuse une valeur mal formée', function()
            assert.is_false(held.valid({ id = 42 }))
            assert.is_false(held.valid({ item = 'hache_fer' }))
            assert.is_false(held.valid({ id = 42, item = 'hache_fer', model = 'prop_tool_fireaxe' }))
            assert.is_false(held.valid({ id = 0, item = 'hache_fer' }))
            assert.is_false(held.valid({ id = 1.5, item = 'hache_fer' }))
            assert.is_false(held.valid({ id = 0 / 0, item = 'hache_fer' }))
            assert.is_false(held.valid({ id = math.huge, item = 'hache_fer' }))
            assert.is_false(held.valid({ id = VavaInventory.MAX_ID + 1, item = 'hache_fer' }))
            assert.is_false(held.valid({ id = '42', item = 'hache_fer' }))
            assert.is_false(held.valid({ id = 42, item = '' }))
            assert.is_false(held.valid({ id = 42, item = string.rep('a', 65) }))
            assert.is_false(held.valid({ id = 42, item = 7 }))
            assert.is_false(held.valid('hache_fer'))
            assert.is_false(held.valid({ 42, 'hache_fer' }))
        end)

        it('admet un identifiant relu en flottant entier (aller-retour réseau)', function()
            assert.is_true(held.valid({ id = 42.0, item = 'hache_fer' }))
            assert.is_true(held.same({ id = 42.0, item = 'hache_fer' }, { id = 42, item = 'hache_fer' }))
        end)

        it('compare deux mains : même pile et même objet seulement', function()
            assert.is_true(held.same(nil, nil))
            assert.is_true(held.same({ id = 42, item = 'hache_fer' }, { id = 42, item = 'hache_fer' }))
            assert.is_false(held.same({ id = 42, item = 'hache_fer' }, nil))
            assert.is_false(held.same(nil, { id = 42, item = 'hache_fer' }))
            assert.is_false(held.same({ id = 42, item = 'hache_fer' }, { id = 43, item = 'hache_fer' }))
            assert.is_false(held.same({ id = 42, item = 'hache_fer' }, { id = 42, item = 'pioche_fer' }))
        end)

        it('une valeur mal formée n\'est égale à rien, pas même à elle-même', function()
            local forged = { id = 42, item = 'hache_fer', model = 'prop_tool_fireaxe' }
            assert.is_false(held.same(forged, forged))
            assert.is_false(held.same(forged, { id = 42, item = 'hache_fer' }))
            assert.is_false(held.same(false, nil))
            assert.is_false(held.same({}, {}))
        end)

        it('reconnaît l\'accessoire depuis { id, item } et la liste publiée', function()
            local prop = held.prop({ id = 42, item = 'hache_fer' }, DECLARED)
            assert.same({ id = 42, model = 'prop_tool_fireaxe', bone = 57005, offset = { 0.1, 0.02, 0.0 },
                rotation = { 0.0, 0.0, 0.0 } }, prop)
            assert.equal('integer', math.type(held.prop({ id = 42.0, item = 'hache_fer' }, DECLARED).id))
        end)

        it('ne montre rien pour un objet non déclaré tenable, une liste absente ou une valeur forgée', function()
            assert.is_nil(held.prop(nil, DECLARED))
            assert.is_nil(held.prop({ id = 42, item = 'carotte' }, DECLARED))
            assert.is_nil(held.prop({ id = 42, item = 'hache_fer' }, nil))
            assert.is_nil(held.prop({ id = 42, item = 'hache_fer' }, {}))
            -- placement glissé dans la valeur : refusé, jamais lu
            assert.is_nil(held.prop({ id = 42, item = 'hache_fer', model = 'prop_bomb' }, DECLARED))
            -- déclaration incomplète (liste publiée abîmée) : rien
            assert.is_nil(held.prop({ id = 42, item = 'hache_fer' }, { hache_fer = { model = 'prop_tool_fireaxe' } }))
        end)

        it('lit le numéro réseau d\'un statebag d\'entité, et de rien d\'autre', function()
            assert.equal(12, held.netIdOf('entity:12'))
            assert.is_nil(held.netIdOf('player:12'))
            assert.is_nil(held.netIdOf('global'))
            assert.is_nil(held.netIdOf('entity:0'))
            assert.is_nil(held.netIdOf('entity:-3'))
            assert.is_nil(held.netIdOf('entity:12a'))
            assert.is_nil(held.netIdOf('entity:1234567890'))
            assert.is_nil(held.netIdOf(12))
        end)

        it('espace les remises au-delà du plafond, jusqu\'au délai maximal', function()
            local delays = {}
            for streak = 0, 10 do delays[#delays + 1] = held.guardDelay(streak, cfg) end
            assert.same({ 250, 250, 250, 500, 1000, 2000, 4000, 8000, 10000, 10000, 10000 }, delays)
            assert.equal(10000, held.guardDelay(1000, cfg))
        end)
    end)

    describe('publication sur le ped et garde (server/pedstate.lua)', function()
        local pedState, entities, peds, players, handler, threads, warnings, sets
        -- horloge du serveur (GetGameTimer, lue par pedstate.lua à travers une variable locale posée au chargement)
        local clock

        --- Entité doublure : numéro réseau, statebag, propriétaire.
        local function newEntity(handle, netId, owner)
            local values = {}
            local entity = { handle = handle, netId = netId, owner = owner, values = values }
            entity.state = setmetatable({}, {
                __index = function(_, key)
                    if key == 'set' then
                        return function(_, k, v, replicated)
                            sets[#sets + 1] = { netId = netId, key = k, value = v, replicated = replicated }
                            if handler then handler('entity:' .. netId, k, v, 0, true) end
                            values[k] = v
                        end
                    end
                    return values[key]
                end,
            })
            entities[handle] = entity
            return entity
        end

        --- Écriture faite par le client propriétaire (même chemin côté serveur : gestionnaire, puis valeur appliquée).
        local function clientWrite(entity, value)
            handler('entity:' .. entity.netId, VavaInventory.HELD_STATE, value, 0, true)
            entity.values[VavaInventory.HELD_STATE] = value
        end

        local function bagValue(entity)
            return entity.values[VavaInventory.HELD_STATE]
        end

        --- Fait avancer d'un tour chaque boucle en cours (Wait rend la main).
        local function tick()
            for i = #threads, 1, -1 do
                local co = threads[i]
                if coroutine.status(co) == 'dead' then
                    table.remove(threads, i)
                else
                    assert(coroutine.resume(co))
                    if coroutine.status(co) == 'dead' then table.remove(threads, i) end
                end
            end
        end

        local function fireTimers()
            local timers = helper.timers
            helper.timers = {}
            for _, timer in ipairs(timers) do timer.fn() end
            return timers
        end

        local HACHE = { id = 42, item = 'hache_fer' }
        local STUBBED = { 'Entity', 'GetPlayerPed', 'DoesEntityExist', 'DoesPlayerExist', 'NetworkGetNetworkIdFromEntity',
            'NetworkGetEntityFromNetworkId', 'NetworkGetEntityOwner', 'AddStateBagChangeHandler' }

        after_each(function()
            for _, name in ipairs(STUBBED) do _G[name] = nil end
            VavaInventory = nil
        end)

        before_each(function()
            loadShared()
            entities, peds, players, threads, warnings, sets = {}, {}, { [1] = true, [2] = true }, {}, {}, {}
            handler = nil
            _G.Entity = function(h) return { state = entities[h].state } end
            _G.GetPlayerPed = function(src) return peds[src] or 0 end
            _G.DoesEntityExist = function(h) return entities[h] ~= nil end
            _G.DoesPlayerExist = function(src) return players[src] == true end
            _G.NetworkGetNetworkIdFromEntity = function(h) return entities[h].netId end
            _G.NetworkGetEntityFromNetworkId = function(netId)
                for h, e in pairs(entities) do if e.netId == netId then return h end end
                return 0
            end
            _G.NetworkGetEntityOwner = function(h) return entities[h] and entities[h].owner or -1 end
            clock = 0
            _G.GetGameTimer = function() return clock end
            _G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
            _G.Wait = function() coroutine.yield() end
            _G.AddStateBagChangeHandler = function(key, bag, fn)
                assert.equal(VavaInventory.HELD_STATE, key)   -- filtré sur la clé : jamais tous les statebags
                assert.is_nil(bag)
                handler = fn
                return 1
            end
            VavaInventory.log = { warn = function(fmt, ...) warnings[#warnings + 1] = fmt:format(...) end }
            helper.load('modules/vava_inventory/server/pedstate.lua')
            pedState = VavaInventory.pedState
            assert.is_true(pedState.start())
        end)

        it('écrit { id, item } sur le ped du joueur, répliqué, une seule fois', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            assert.same(HACHE, bagValue(ped))
            assert.equal(1, #sets)
            assert.is_true(sets[1].replicated)
            pedState.set(1, { id = 42, item = 'hache_fer' })
            assert.equal(1, #sets)   -- même main : rien ne repart
            -- l'écriture du serveur ne déclenche pas la garde
            assert.equal(0, #helper.timers)
        end)

        it('vide le ped quand les mains se vident, sans rien écrire s\'il est déjà vide', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(2, nil)
            assert.equal(0, #sets)
            pedState.set(1, HACHE)
            pedState.set(1, nil)
            assert.is_nil(bagValue(ped))
            assert.equal(2, #sets)
            pedState.set(1, nil)
            assert.equal(2, #sets)
        end)

        it('réécrit la main sur le nouveau ped (réapparition, modèle changé) au contrôle suivant', function()
            local first = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            assert.equal(1, #threads)
            tick()
            assert.equal(1, #sets)   -- même ped : rien
            -- nouveau ped, l'ancien supprimé avec son statebag
            entities[100] = nil
            local second = newEntity(101, 8, 1)
            peds[1] = 101
            tick()
            assert.same(HACHE, bagValue(second))
            -- l'ancien ped, supprimé, n'est pas touché ; une seule écriture de plus, sur le nouveau
            assert.equal(2, #sets)
            -- l'ancien numéro réseau n'est plus suivi : une main qui y serait écrite serait remise à rien
            entities[100] = first
            clientWrite(first, HACHE)
            fireTimers()
            assert.is_nil(bagValue(first))
        end)

        it('vide l\'ancien ped s\'il existe encore et attend un ped absent', function()
            local first = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            tick()   -- la boucle démarre : premier contrôle au tour suivant
            peds[1] = nil
            tick()
            assert.is_nil(bagValue(first))   -- ped gardé par le jeu sans le joueur : vidé
            local second = newEntity(101, 8, 1)
            peds[1] = 101
            tick()
            assert.same(HACHE, bagValue(second))
        end)

        it('ne touche pas à une entité qui a repris l\'ancien numéro réseau', function()
            newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            -- l'ancien ped disparaît ; une autre entité reprend son handle avec un autre numéro réseau
            entities[100] = nil
            local other = newEntity(100, 9, 2)
            other.values[VavaInventory.HELD_STATE] = { id = 5, item = 'pioche_fer' }
            local second = newEntity(101, 8, 1)
            peds[1] = 101
            tick()
            tick()
            assert.same({ id = 5, item = 'pioche_fer' }, bagValue(other))
            assert.same(HACHE, bagValue(second))
        end)

        it('suit un nouveau ped qui garde le même handle sous un autre numéro réseau', function()
            newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            tick()
            local renewed = newEntity(100, 9, 1)   -- même handle, nouvelle entité, statebag vide
            tick()
            assert.same(HACHE, bagValue(renewed))
            -- l'ancien numéro n'est plus attendu, le nouveau l'est
            clientWrite(renewed, nil)
            fireTimers()
            assert.same(HACHE, bagValue(renewed))
        end)

        it('rend sa main à un statebag qui l\'a perdue, au contrôle suivant, sans rien envoyer sinon', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            tick()
            tick()
            assert.equal(1, #sets)   -- ped inchangé et porteur de sa main : aucun envoi
            ped.values[VavaInventory.HELD_STATE] = nil
            tick()
            assert.same(HACHE, bagValue(ped))
            assert.equal(2, #sets)
        end)

        it('la boucle s\'arrête quand plus personne ne tient rien, et oublie un joueur parti', function()
            newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            pedState.set(1, nil)
            tick()
            assert.equal(0, #threads)
            pedState.set(1, HACHE)
            players[1] = nil
            tick()
            tick()
            assert.equal(0, #threads)
        end)

        it('remet la valeur du serveur quand le client réécrit sa main, après le délai', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            local before = #sets
            clientWrite(ped, { id = 999999, item = 'pioche_fer' })
            assert.equal(1, #helper.timers)
            assert.equal(cfg.guardDelayMs, helper.timers[1].ms)
            fireTimers()
            assert.same(HACHE, bagValue(ped))
            assert.equal(before + 1, #sets)
            assert.equal(1, #warnings)
            assert.matches('joueur 1', warnings[1])
        end)

        it('remet aussi une main vidée par le client, ou forgée avec un placement', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            clientWrite(ped, nil)
            fireTimers()
            assert.same(HACHE, bagValue(ped))
            clientWrite(ped, { id = 42, item = 'hache_fer', model = 'prop_bomb' })
            fireTimers()
            assert.same(HACHE, bagValue(ped))
        end)

        it('regroupe une rafale de réécritures en une seule remise', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            for i = 1, 30 do clientWrite(ped, { id = i, item = 'pioche_fer' }) end
            assert.equal(1, #helper.timers)
            local before = #sets
            fireTimers()
            assert.equal(before + 1, #sets)
            assert.same(HACHE, bagValue(ped))
        end)

        it('ne remet rien si la valeur est revenue avant l\'échéance', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            clientWrite(ped, { id = 1, item = 'pioche_fer' })
            clientWrite(ped, { id = 42, item = 'hache_fer' })
            local before = #sets
            fireTimers()
            assert.equal(before, #sets)
            assert.equal(0, #warnings)
        end)

        it('efface une main écrite par un client sur une entité que le serveur ne suit pas', function()
            local cart = newEntity(300, 30, 2)
            clientWrite(cart, HACHE)
            fireTimers()
            assert.is_nil(bagValue(cart))
            assert.matches('joueur 2', warnings[1])
            -- une main vidée par le client sur une entité non suivie : rien à remettre
            clientWrite(cart, nil)
            assert.equal(0, #helper.timers)
        end)

        it('ne fait rien si l\'entité a disparu avant l\'échéance', function()
            local cart = newEntity(300, 30, 2)
            clientWrite(cart, HACHE)
            entities[300] = nil
            local before = #sets
            fireTimers()
            assert.equal(before, #sets)
        end)

        it('ignore les statebags de joueur et le GlobalState', function()
            handler('player:1', VavaInventory.HELD_STATE, HACHE, 0, true)
            handler('global', VavaInventory.HELD_STATE, HACHE, 0, true)
            assert.equal(0, #helper.timers)
        end)

        it('espace les remises d\'un client qui insiste, sans jamais les abandonner, et repart de zéro à la publication', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            local delays = {}
            for _ = 1, 6 do
                clientWrite(ped, { id = 1, item = 'pioche_fer' })
                delays[#delays + 1] = helper.timers[1].ms
                fireTimers()
                assert.same(HACHE, bagValue(ped))
            end
            assert.same({ 250, 250, 250, 500, 1000, 2000 }, delays)
            -- une ligne par remise jusqu'au plafond (limitées par joueur), puis une seule ligne « de suite »
            local streakLines = 0
            for _, line in ipairs(warnings) do
                if line:find('de suite', 1, true) then streakLines = streakLines + 1 end
            end
            assert.equal(1, streakLines)
            pedState.set(1, { id = 43, item = 'hache_fer' })
            clientWrite(ped, { id = 1, item = 'pioche_fer' })
            assert.equal(250, helper.timers[1].ms)
        end)

        it('limite les avertissements en console à un par joueur et par intervalle', function()
            local ped = newEntity(100, 7, 1)
            peds[1] = 100
            pedState.set(1, HACHE)
            for _ = 1, 3 do
                pedState.set(1, HACHE)   -- republication : compte des remises remis à zéro
                clientWrite(ped, { id = 1, item = 'pioche_fer' })
                fireTimers()
            end
            assert.equal(1, #warnings)
            clock = cfg.guardWarnMs
            clientWrite(ped, { id = 1, item = 'pioche_fer' })
            fireTimers()
            assert.equal(2, #warnings)
        end)
    end)
end)
