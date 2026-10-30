local helper = require('tests.helper')

-- Diffusion des champs de personnage (server/players/sync.lua), au regard de la section « core.characters » de
-- docs/api.md : rien n'est envoyé pour un personnage qui n'est plus celui du joueur (0.9.0), et garde des champs
-- publics : une valeur réécrite dans le statebag du joueur par son client est remplacée par celle du serveur.
-- Le statebag est une doublure : comme dans FiveM, le gestionnaire de changement est appelé AVANT que la nouvelle
-- valeur soit appliquée, pour une écriture du serveur comme pour une écriture du client.
describe('vAvA.sync', function()
    local sync, fields, EVENTS, sent, bags, serverSets, stateHandlers, registrations, existing, realPrint
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
                        apply(k, v)
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
        _G.print = function() end
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
            return 1
        end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'config/server.lua',
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
            if helper.timers[i].ms == vAvA.config.server.sync.publicGuardDelayMs then count = count + 1 end
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

    it('start renvoie false sans suivi des statebags côté serveur', function()
        _G.AddStateBagChangeHandler = nil
        assert.is_false(sync.start())
    end)
end)
