local helper = require('tests.helper')

-- Diffusion des champs de personnage (server/players/sync.lua), au regard de la section « core.characters » de
-- docs/api.md : rien n'est envoyé pour un personnage qui n'est plus celui du joueur (0.9.0), et garde des champs
-- publics : une valeur réécrite dans le statebag du joueur par son client est remplacée par celle du serveur.
-- Le statebag est une doublure : comme dans FiveM, le gestionnaire de changement est appelé AVANT que la nouvelle
-- valeur soit appliquée, pour une écriture du serveur comme pour une écriture du client.
describe('vAvA.sync', function()
    local sync, fields, EVENTS, sent, bags, serverSets, stateHandlers, registrations, existing, realPrint
    -- roundTrip : transformation d'une écriture du serveur vue au retour (arrondi réseau, ou valeur jamais égale)
    local roundTrip, printed, removed
    local HANDS = 'vava_test:hands'

    --- Statebag d'un joueur : lecture state[clé], écriture state:set(clé, valeur, répliqué).
    local function bagOf(src)
        local bag = bags[src]
        if bag then return bag end
        local values = {}
        local function apply(key, value)
            if stateHandlers[key] then stateHandlers[key]('player:' .. src, key, value, 0, true) end
            values[key] = value
        end
        local state = setmetatable({}, {
            __index = function(_, key)
                if key == 'set' then
                    return function(_, k, v, replicated)
                        serverSets[#serverSets + 1] = { src = src, key = k, value = v, replicated = replicated }
                        apply(k, roundTrip and roundTrip(v) or v)
                    end
                end
                return values[key]
            end,
        })
        bag = { state = state, values = values, clientWrite = apply }
        bags[src] = bag
        return bag
    end

    before_each(function()
        helper.reset()
        realPrint = _G.print
        printed, removed, roundTrip = {}, {}, nil
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        sent, bags, serverSets, stateHandlers, registrations = {}, {}, {}, {}, {}
        existing = { [1] = true, [2] = true }
        _G.GetGameTimer = function() return 0 end
        _G.TriggerClientEvent = function(event, src, ...)
            sent[#sent + 1] = { event = event, src = src, args = { ... } }
        end
        _G.DoesPlayerExist = function(src) return existing[src] == true end
        _G.Player = function(src) return { state = bagOf(src).state } end
        _G.AddStateBagChangeHandler = function(key, bag, fn)
            assert.is_string(key)                       -- jamais tous les statebags du serveur
            assert.is_nil(bag)
            registrations[key] = (registrations[key] or 0) + 1
            stateHandlers[key] = fn
            return 'cookie:' .. key   -- identifiant rendu par FiveM (un entier en jeu)
        end
        _G.RemoveStateBagChangeHandler = function(cookie) removed[#removed + 1] = cookie end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'config/server.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
            'server/players/fields.lua',
            'server/players/sync.lua',
        })
        sync, fields, EVENTS = vAvA.sync, vAvA.fields, vAvA.EVENTS
        assert.is_true(fields.define('vava_test', HANDS, {
            schema = { type = 'table', fields = {
                id = { type = 'integer' },
                offset = { type = 'table', fields = { x = { type = 'number' }, y = { type = 'number' } } },
            } },
            visibility = 'public',
        }))
        assert.is_true(fields.define('vava_test', 'vava_test:faim', {
            schema = { type = 'integer', min = 0, max = 100 }, default = 50, visibility = 'owner',
        }))
        assert.is_true(sync.start())
    end)

    after_each(function()
        _G.print = realPrint
    end)

    local function newCharacter(src, id)
        return { source = src, id = id, firstName = 'Aela', lastName = 'Vorn', sex = 'f', data = {}, revision = 0 }
    end

    --- Écriture validée d'un champ, comme characters.setField.
    local function setField(character, name, value)
        local ok, def = fields.set(character, name, value)
        assert.is_true(ok)
        if def then sync.fieldChanged(character, def) end
    end

    local function eventsNamed(event)
        local found = {}
        for i = 1, #sent do
            if sent[i].event == event then found[#found + 1] = sent[i] end
        end
        return found
    end

    --- Minuteries de la garde (la diffusion groupée des champs owner part, elle, au tick suivant : 0 ms).
    local function guardTimers()
        local count = 0
        for i = 1, #helper.timers do
            if helper.timers[i].ms > 0 then count = count + 1 end
        end
        return count
    end

    --- Déclenche la seule minuterie de garde en attente et rend son délai (les envois groupés partent avec).
    local function fireGuard()
        local timers = helper.timers
        helper.timers = {}
        local delay
        for i = 1, #timers do
            if timers[i].ms > 0 then
                assert.is_nil(delay, 'une seule minuterie de garde à la fois')
                delay = timers[i].ms
            end
            timers[i].fn()
        end
        return delay
    end

    local function linesMatching(pattern)
        local count = 0
        for i = 1, #printed do
            if printed[i]:find(pattern) then count = count + 1 end
        end
        return count
    end

    local function flushAll()
        local timers = helper.timers
        helper.timers = {}
        for i = 1, #timers do timers[i].fn() end
    end

    describe('personnage du joueur', function()
        it('n’envoie rien pour un personnage pas encore envoyé (hooks de chargement), puis tout à l’envoi complet', function()
            local character = newCharacter(1, 10)
            setField(character, 'vava_test:faim', 30)
            setField(character, HANDS, { id = 4, offset = { x = 0.1, y = 0 } })
            assert.equal(0, #sent)
            assert.equal(0, #serverSets)
            sync.sendCharacter(character)
            local loaded = eventsNamed(EVENTS.CHARACTER_LOADED)
            assert.equal(1, #loaded)
            assert.equal(30, loaded[1].args[1].fields['vava_test:faim'])
            assert.same({ id = 4, offset = { x = 0.1, y = 0 } }, bagOf(1).values[HANDS])
            assert.is_true(serverSets[1].replicated)
        end)

        it('diffuse un champ modifié au joueur du personnage envoyé', function()
            local character = newCharacter(1, 10)
            sync.sendCharacter(character)
            setField(character, 'vava_test:faim', 20)
            setField(character, HANDS, { id = 5, offset = { x = 0, y = 0 } })
            flushAll()
            local batches = eventsNamed(EVENTS.CHARACTER_FIELDS)
            assert.equal(1, #batches)
            assert.equal(1, batches[1].src)
            assert.equal(20, batches[1].args[1]['vava_test:faim'])
            assert.equal(5, bagOf(1).values[HANDS].id)
        end)

        it('vide les champs publics et prévient le joueur au déchargement, puis n’envoie plus rien', function()
            local character = newCharacter(1, 10)
            sync.sendCharacter(character)
            setField(character, HANDS, { id = 5, offset = { x = 0, y = 0 } })
            sync.clearCharacter(character)
            assert.is_nil(bagOf(1).values[HANDS])
            assert.equal(1, #eventsNamed(EVENTS.CHARACTER_UNLOADED))
            local before = #sent
            local setsBefore = #serverSets
            setField(character, 'vava_test:faim', 10)
            setField(character, HANDS, { id = 6, offset = { x = 0, y = 0 } })
            flushAll()
            assert.equal(before, #sent)
            assert.equal(setsBefore, #serverSets)
        end)

        it('joueur parti : ni champ, ni statebag, ni déchargement envoyé, même si son numéro est redonné', function()
            local character = newCharacter(1, 10)
            sync.sendCharacter(character)
            sync.purgePlayer(1)
            -- un nouveau venu reçoit le numéro 1 pendant que les modules sauvent l'ancien personnage
            local before, setsBefore = #sent, #serverSets
            setField(character, 'vava_test:faim', 10)
            setField(character, HANDS, { id = 6, offset = { x = 0, y = 0 } })
            sync.clearCharacter(character)
            flushAll()
            assert.equal(before, #sent)
            assert.equal(setsBefore, #serverSets)
        end)

        it('n’envoie pas un personnage déchargé à son successeur sur le même joueur', function()
            local first, second = newCharacter(1, 10), newCharacter(1, 11)
            sync.sendCharacter(first)
            sync.clearCharacter(first)
            sync.sendCharacter(second)
            local before = #sent
            setField(first, 'vava_test:faim', 1)
            sync.clearCharacter(first)
            flushAll()
            assert.equal(before, #sent)
        end)
    end)

    describe('garde des champs publics', function()
        local character

        before_each(function()
            character = newCharacter(1, 10)
            sync.sendCharacter(character)
            setField(character, HANDS, { id = 4, offset = { x = 0.1, y = 0 } })
            flushAll()
            serverSets = {}
        end)

        it('ne réagit pas aux écritures du serveur lui-même', function()
            setField(character, HANDS, { id = 7, offset = { x = 0, y = 0 } })
            assert.equal(0, guardTimers())
        end)

        it('remet la valeur du serveur quand le client réécrit son statebag', function()
            bagOf(1).clientWrite(HANDS, { id = 99, offset = { x = 0, y = 0 } })
            assert.equal(1, guardTimers())
            assert.equal(99, bagOf(1).values[HANDS].id)   -- la remise n'est pas immédiate
            flushAll()
            assert.same({ id = 4, offset = { x = 0.1, y = 0 } }, bagOf(1).values[HANDS])
            assert.equal(1, #serverSets)
            assert.is_true(serverSets[1].replicated)
            assert.equal(0, guardTimers())   -- la remise elle-même ne relance pas la garde
        end)

        it('regroupe les réécritures d’un même joueur en une seule remise', function()
            for i = 1, 20 do bagOf(1).clientWrite(HANDS, { id = i, offset = { x = 0, y = 0 } }) end
            bagOf(1).clientWrite(HANDS, nil)
            assert.equal(1, guardTimers())
            flushAll()
            assert.equal(1, #serverSets)
            assert.equal(4, bagOf(1).values[HANDS].id)
        end)

        it('accepte une copie identique (désérialisée) et ne remet rien si la valeur est revenue entre-temps', function()
            bagOf(1).clientWrite(HANDS, { id = 4, offset = { x = 0.1, y = 0.0 } })
            assert.equal(0, guardTimers())
            bagOf(1).clientWrite(HANDS, { id = 8, offset = { x = 0, y = 0 } })
            bagOf(1).clientWrite(HANDS, { id = 4, offset = { x = 0.1, y = 0 } })
            flushAll()
            assert.equal(0, #serverSets)
        end)

        it('remet un champ vide quand le client en écrit un sans personnage chargé', function()
            sync.clearCharacter(character)
            serverSets = {}
            bagOf(1).clientWrite(HANDS, { id = 1, offset = { x = 0, y = 0 } })
            flushAll()
            assert.equal(1, #serverSets)
            assert.is_nil(bagOf(1).values[HANDS])
        end)

        it('remet aussi un champ public jamais publié pour ce joueur', function()
            bagOf(2).clientWrite(HANDS, { id = 1, offset = { x = 0, y = 0 } })
            flushAll()
            assert.is_nil(bagOf(2).values[HANDS])
        end)

        it('laisse les autres clés, les autres statebags et les champs non publics', function()
            bagOf(1).clientWrite('vava_test:faim', 0)
            bagOf(1).clientWrite('autre:cle', true)
            stateHandlers[HANDS]('entity:42', HANDS, { id = 1 }, 0, true)
            stateHandlers[HANDS]('global', HANDS, { id = 1 }, 0, true)
            stateHandlers[HANDS]('player:abc', HANDS, { id = 1 }, 0, true)
            stateHandlers[HANDS](nil, HANDS, { id = 1 }, 0, true)
            assert.equal(0, guardTimers())
        end)

        it('ne remet rien pour un joueur parti avant l’échéance', function()
            bagOf(1).clientWrite(HANDS, { id = 99, offset = { x = 0, y = 0 } })
            existing[1] = nil
            sync.purgePlayer(1)
            flushAll()
            assert.equal(0, #serverSets)
        end)

        it('suit chaque champ public dès sa déclaration, une seule fois, et jamais les autres clés', function()
            assert.equal(1, registrations[HANDS])
            assert.is_nil(registrations['vava_test:faim'])
            -- déclaré après le démarrage, jamais publié : gardé quand même
            assert.is_true(fields.define('vava_test', 'vava_test:cape', {
                schema = { type = 'string', max = 16 }, visibility = 'public',
            }))
            assert.equal(1, registrations['vava_test:cape'])
            bagOf(2).clientWrite('vava_test:cape', 'pourpre royal')
            flushAll()
            assert.is_nil(bagOf(2).values['vava_test:cape'])
            -- module redémarré : le champ redéclaré garde son unique gestionnaire
            fields.purgeOwner('vava_test')
            assert.is_true(fields.define('vava_test', 'vava_test:cape', {
                schema = { type = 'string', max = 16 }, visibility = 'public',
            }))
            assert.equal(1, registrations['vava_test:cape'])
            -- champ retiré : plus gardé (le module arrêté ne publie plus rien)
            bagOf(1).clientWrite(HANDS, { id = 99 })
            assert.equal(0, guardTimers())
        end)

        it('juge différente une valeur forgée trop profonde, sans erreur', function()
            local deep = {}
            local node = deep
            for _ = 1, 200 do
                node.offset = {}
                node = node.offset
            end
            bagOf(1).clientWrite(HANDS, deep)
            flushAll()
            assert.equal(4, bagOf(1).values[HANDS].id)
        end)
    end)

    -- relecture de T-027 : une écriture du serveur qui ne revient pas égale ne doit pas boucler sans fin
    describe('boucle de remise', function()
        local character
        local cfg

        before_each(function()
            cfg = vAvA.config.server.sync
            character = newCharacter(1, 10)
            sync.sendCharacter(character)
            serverSets = {}
        end)

        it('nombres arrondis au retour (float32) : aucune remise', function()
            roundTrip = function(v)
                if type(v) ~= 'table' then return v end
                return { id = v.id, offset = { x = v.offset.x * (1 + 3e-8), y = v.offset.y * (1 - 3e-8) } }
            end
            setField(character, HANDS, { id = 4, offset = { x = 0.1, y = -0.02 } })
            assert.equal(0, guardTimers())
            assert.equal(1, #serverSets)
        end)

        it('valeur du serveur jamais revenue égale : remises espacées, bornées, une seule ligne', function()
            roundTrip = function(v)
                if type(v) ~= 'table' then return v end
                return { id = v.id + 1, offset = v.offset }
            end
            setField(character, HANDS, { id = 4, offset = { x = 0, y = 0 } })
            local delays = {}
            for i = 1, 12 do delays[i] = fireGuard() end
            local base, top = cfg.publicGuardDelayMs, cfg.publicGuardMaxDelayMs
            assert.same({ base, base, base, base * 2, base * 4, base * 8, base * 16, base * 32, top, top, top, top },
                delays)
            assert.equal(13, #serverSets)                       -- la publication, puis une remise par minuterie
            assert.equal(1, linesMatching('de suite sans nouvelle publication'))
            assert.equal(1, linesMatching('réécrit%(s%) par son client'))   -- 10 s de limite, horloge figée ici
            -- une nouvelle publication remet le compte à zéro : remise de nouveau rapide
            roundTrip = nil
            setField(character, HANDS, { id = 5, offset = { x = 0, y = 0 } })
            fireGuard()                                         -- la remise programmée trouve la bonne valeur
            bagOf(1).clientWrite(HANDS, { id = 9, offset = { x = 0, y = 0 } })
            assert.equal(base, fireGuard())
            assert.equal(5, bagOf(1).values[HANDS].id)
        end)

        it('un client qui insiste est toujours remis, de plus en plus tard, jamais laissé', function()
            setField(character, HANDS, { id = 4, offset = { x = 0, y = 0 } })
            for _ = 1, 10 do
                bagOf(1).clientWrite(HANDS, { id = 99, offset = { x = 0, y = 0 } })
                assert.is_true(fireGuard() <= cfg.publicGuardMaxDelayMs)
                assert.equal(4, bagOf(1).values[HANDS].id)
            end
        end)
    end)

    describe('schéma d’un champ public', function()
        local function define(name, def, visibility)
            return fields.define('vava_test', name, { schema = def, visibility = visibility or 'public' })
        end

        it('compilé comme une entrée réseau : any, function, table non stricte refusés (pas pour owner)', function()
            assert.is_false(define('vava_test:a', { type = 'any' }))
            assert.is_false(define('vava_test:b', { type = 'function' }))
            assert.is_false(define('vava_test:c', { type = 'table', fields = {}, strict = false }))
            assert.is_false(define('vava_test:d', { type = 'array', items = { type = 'any' } }))
            assert.is_true(define('vava_test:e', { type = 'any' }, 'owner'))
            assert.is_true(define('vava_test:f', { type = 'table', fields = {}, strict = false }, 'private'))
        end)

        it('chaînes et listes bornées par défaut, comme une entrée réseau', function()
            assert.is_true(define('vava_test:mot', { type = 'string' }))
            local character = newCharacter(1, 10)
            local ok = fields.set(character, 'vava_test:mot', string.rep('a', vAvA.config.server.schema.maxStringLength + 1))
            assert.is_false(ok)
        end)

        it('refuse un schéma plus profond que la comparaison de la garde', function()
            local def = { type = 'integer' }
            for _ = 1, vAvA.config.server.sync.publicCompareDepth do
                def = { type = 'table', fields = { n = def } }
            end
            assert.is_true(define('vava_test:juste', def))
            local ok, err = define('vava_test:trop', { type = 'array', max = 2, items = def })
            assert.is_false(ok)
            assert.matches('niveaux', err)
            assert.is_true(define('vava_test:prive', { type = 'array', items = def }, 'owner'))
        end)

        it('accepte le schéma réel de vava_inventory:hands', function()
            _G.VavaInventory = {
                items = {}, containers = {}, config = { hands = {} }, MAX_ID = 0x7FFFFFFF,
                HANDS_FIELD = 'vava_inventory:hands', HELD_MODELS = 'vava_inventory:heldModels',
                REGISTRY = 'vava_inventory:items',
            }
            _G.GlobalState = {}
            helper.load('modules/vava_inventory/server/hands.lua')
            local ok, err = fields.define('vava_inventory', 'vava_inventory:hands', {
                schema = VavaInventory.hands.SCHEMA, visibility = 'public',
            })
            _G.VavaInventory, _G.GlobalState = nil, nil
            assert.is_true(ok, err)
        end)
    end)

    it('stop retire les gestionnaires de changement et oublie les remises programmées', function()
        local character = newCharacter(1, 10)
        sync.sendCharacter(character)
        bagOf(1).clientWrite(HANDS, { id = 99, offset = { x = 0, y = 0 } })
        sync.stop()
        assert.same({ 'cookie:' .. HANDS }, removed)
        serverSets = {}
        flushAll()
        assert.equal(0, #serverSets)
        -- plus aucun suivi : un champ déclaré ensuite n'est pas branché
        assert.is_true(fields.define('vava_test', 'vava_test:cape', { schema = { type = 'string', max = 8 }, visibility = 'public' }))
        assert.is_nil(registrations['vava_test:cape'])
    end)

    -- 0.10.0 : envois par core.net, toujours fiables (l'ordre chargement → champs → apparition compte)
    describe('envois par core.net', function()
        it('un chargement de 12 Ko part en fiable, jamais en latent ; alerte une fois par minute au plus', function()
            _G.TriggerLatentClientEvent = function() error('jamais en latent') end
            assert.is_true(fields.define('vava_test', 'vava_test:carnet', {
                schema = { type = 'string', max = 20000 }, visibility = 'owner',
            }))
            local character = newCharacter(1, 10)
            setField(character, 'vava_test:carnet', string.rep('x', 12288))
            sync.sendCharacter(character)
            sync.sendCharacter(character)
            local loaded = eventsNamed(EVENTS.CHARACTER_LOADED)
            assert.equal(2, #loaded)
            assert.equal(12288, #loaded[1].args[1].fields['vava_test:carnet'])
            assert.equal(1, linesMatching(EVENTS.CHARACTER_LOADED .. ' : %d+ octets envoyés en fiable'))
            local stats = vAvA.net.stats({ resource = vAvA.resourceName })
            assert.equal(EVENTS.CHARACTER_LOADED, stats.events[1].label)
            assert.equal(2, stats.events[1].messages)
            assert.equal(0, stats.total.latent)
        end)

        -- relecture sécurité de T-013 : un envoi indispensable impossible ne laisse pas le joueur bloqué
        describe('envoi indispensable impossible', function()
            local dropped

            before_each(function()
                dropped = {}
                _G.DropPlayer = function(target, reason) dropped[#dropped + 1] = { target = target, reason = reason } end
                -- sync.lua garde DropPlayer en local : rechargé avec la doublure
                helper.load('server/players/sync.lua')
                sync = vAvA.sync
                assert.is_true(fields.define('vava_test', 'vava_test:carnet', {
                    schema = { type = 'string', max = 300000 }, visibility = 'owner',
                }))
            end)

            it('personnage trop gros : erreur en console (compte, cause) et déconnexion avec un message clair', function()
                local character = newCharacter(1, 10)
                character.accountId = 42
                setField(character, 'vava_test:carnet', string.rep('x', vAvA.config.server.net.maxBytes))
                sync.sendCharacter(character)
                assert.equal(0, #eventsNamed(EVENTS.CHARACTER_LOADED))
                assert.equal(1, #dropped)
                assert.equal('1', dropped[1].target)
                assert.equal(vAvA.config.server.players.messages.sendFailed, dropped[1].reason)
                assert.equal(1, linesMatching('compte #42, personnage #10 : vAvA:character:loaded impossible à envoyer %(too_large%)'))
                assert.is_nil(bagOf(1).values[HANDS])   -- rien n'est publié
            end)

            it('joueur déjà parti : ni erreur ni déconnexion', function()
                existing[1] = nil
                sync.sendCharacter(newCharacter(1, 10))
                assert.equal(0, #dropped)
            end)

            it('ordre d’apparition impossible : même traitement, spawn.at rend false et le code', function()
                vAvA.playtime = { pause = function() end }
                helper.load('server/players/spawn.lua')
                local character = newCharacter(2, 11)
                character.accountId = 7
                vAvA.config.server.spawn.models.f = string.rep('x', vAvA.config.server.net.maxBytes)
                vAvA.spawn.forCharacter(character)
                assert.equal(1, #dropped)
                assert.equal('2', dropped[1].target)
                assert.equal(1, linesMatching('compte #7, personnage #11 : vAvA:character:spawn impossible à envoyer'))
                assert.same({ true }, { vAvA.spawn.at(character, { x = 1.0, y = 2.0, z = 3.0 }) })
                assert.equal(1, #dropped)
            end)
        end)

        it('isCurrent : vrai pour le personnage envoyé, faux après son déchargement ou le départ du joueur', function()
            local character = newCharacter(1, 10)
            assert.is_false(sync.isCurrent(character))
            sync.sendCharacter(character)
            assert.is_true(sync.isCurrent(character))
            sync.clearCharacter(character)
            assert.is_false(sync.isCurrent(character))
            local other = newCharacter(2, 11)
            sync.sendCharacter(other)
            sync.purgePlayer(2)
            assert.is_false(sync.isCurrent(other))
        end)
    end)

    it('start renvoie false sans suivi des statebags côté serveur', function()
        _G.AddStateBagChangeHandler = nil
        assert.is_false(sync.start())
    end)
end)
