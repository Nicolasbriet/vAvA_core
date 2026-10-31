local helper = require('tests.helper')

-- Palier de l'outre (T-135) sur l'inventaire réel : une outre de la tannerie porte son palier (`{ tier }`, produit
-- simple de vava_crafting : server/signature.lua, signature.simple) ; remplie à un point d'eau, l'outre d'eau garde ce
-- palier ; bue, elle rend une outre vide du même palier, même quand c'était la dernière unité de sa pile (palier relevé
-- par l'abonné before de `vava_inventory:use`). Empilement tenu par l'inventaire : deux outres du même palier font une
-- pile, deux paliers différents deux piles, une outre sans palier une autre encore.
-- Montage réel : registres et hooks du core (server/core/registry.lua, shared/core/hooks.lua) ; vava_inventory
-- (shared/grid.lua, server/items.lua, server/containers.lua, server/operations.lua, server/api.lua) avec des doublures
-- de la base, des spectateurs et des mains ; vava_provisions entier côté serveur (bridge, main.lua, setup) sur ses
-- exports. Règles : README de vava_provisions (Règles, Données) et docs/tests/eau.md § 4.

local SRC, CHARACTER = 5, 100
local PROVISIONS, INVENTORY, CRAFTING = 'vava_provisions', 'vava_inventory', 'vava_crafting'
local ANY = { schema = { type = 'any' } }

local function newLogs()
    local logs = { error = {}, warn = {}, info = {}, debug = {} }
    local log = {}
    for level in pairs(logs) do
        log[level] = function(fmt, ...) logs[level][#logs[level] + 1] = fmt:format(...) end
    end
    return logs, log
end

describe('vava_provisions : palier de l\'outre sur l\'inventaire réel', function()
    local registry, hooks, besace, operations, simple, inventoryExports, rpcs, setup, peds, sent, queue, roll, logs
    local realRandom, realPrint = math.random, nil

    --- API du core telle que la voit une ressource : registres et hooks au nom du propriétaire.
    local function coreFor(owner, log)
        return {
            log = log,
            registry = {
                define = function(name, options) return registry.define(owner, name, options) end,
                add = function(name, key, data) return registry.add(owner, name, key, data) end,
                get = function(name, key) return registry.get(name, key) end,
                has = function(name, key) return registry.has(name, key) end,
                exists = function(name) return registry.exists(name) end,
            },
            hooks = {
                before = function(name, fn, priority) return hooks.subscribe(owner, 'before', name, fn, priority) end,
                after = function(name, fn, priority) return hooks.subscribe(owner, 'after', name, fn, priority) end,
                runBefore = function(name, payload) return hooks.runBefore(name, payload) end,
                runAfter = function(name, payload) return hooks.runAfter(name, payload) end,
            },
            players = { get = function(src) return src == SRC and { state = 'active' } or nil end },
            characters = { getActive = function(src) return src == SRC and { id = CHARACTER } or nil end },
            zones = { define = function() return true, 1 end },
            net = {
                send = function(target, event, ...)
                    sent[#sent + 1] = { target = target, event = event, args = table.pack(...) }
                    return true
                end,
            },
            rpc = {
                register = function(name, options, handler)
                    rpcs[name] = { options = options, handler = handler }
                    return true
                end,
            },
            modules = { register = function(def) setup = def.setup return true end },
        }
    end

    --- Démarre l'inventaire : registre des objets, une besace de 10 × 6 (30 kg) liée au joueur.
    local function startInventory()
        VavaInventory = nil
        helper.loadAll({
            'modules/vava_inventory/shared/constants.lua',
            'modules/vava_inventory/config_client.lua',
            'modules/vava_inventory/config.lua',
            'modules/vava_inventory/shared/grid.lua',
        })
        local _, log = newLogs()
        VavaInventory.core, VavaInventory.log, VavaInventory.resource = coreFor(INVENTORY, log), log, INVENTORY
        helper.load('modules/vava_inventory/server/items.lua')
        assert.is_true(VavaInventory.items.define())
        -- base, spectateurs, mains, sacs, positions : hors de l'essai
        VavaInventory.persistence = { touch = function() end, forget = function() end }
        VavaInventory.viewers = { publish = function() end, isViewing = function() return false end, removePlayer = function() end }
        VavaInventory.hands = {
            sync = function() return nil end, bind = function() end, unbind = function() end, heldId = function() return nil end,
            restore = function() end,
        }
        VavaInventory.drops, VavaInventory.positions = {}, {}
        helper.loadAll({ 'modules/vava_inventory/server/containers.lua', 'modules/vava_inventory/server/operations.lua' })
        inventoryExports = {}
        _G.exports = setmetatable({}, {
            __call = function(_, name, fn) inventoryExports[name] = fn end,
            __index = function(_, resource)
                if resource ~= INVENTORY then return nil end
                -- appel d'export FiveM : exports.ressource:fonction(…)
                return setmetatable({}, { __index = function(_, fn)
                    local target = inventoryExports[fn]
                    return target and function(_, ...) return target(...) end
                end })
            end,
        })
        helper.load('modules/vava_inventory/server/api.lua')
        operations = VavaInventory.operations
        besace = VavaInventory.containers.createTransient({ kind = 'player', width = 10, height = 6, maxWeight = 30000 })
        operations.bind(SRC, CHARACTER, besace.id)
        VavaInventory.ready = true
    end

    --- Démarre les vivres (setup réel) : objets déclarés à l'inventaire, points, RPC, hooks.
    local function startProvisions()
        VavaProvisions = nil
        helper.loadAll({
            'modules/vava_provisions/shared/constants.lua',
            'modules/vava_provisions/config_client.lua',
            'modules/vava_provisions/config.lua',
            'modules/vava_provisions/shared/texts.lua',
            'modules/vava_provisions/shared/rules.lua',
            'modules/vava_provisions/shared/pointzone.lua',
        })
        local log
        logs, log = newLogs()
        VavaProvisions.core, VavaProvisions.log, VavaProvisions.resource, VavaProvisions.ready = coreFor(PROVISIONS, log), log, PROVISIONS, false
        helper.loadAll({
            'modules/vava_provisions/bridge/server.lua',
            'modules/vava_provisions/server/items.lua',
            'modules/vava_provisions/server/points.lua',
            'modules/vava_provisions/server/draw.lua',
            'modules/vava_provisions/server/containers.lua',
            'modules/vava_provisions/server/admin.lua',
            'modules/vava_provisions/server/commands.lua',
            'modules/vava_provisions/server/api.lua',
            'modules/vava_provisions/server/main.lua',
        })
        assert.same({ true }, { setup() })
    end

    --- Métadonnées d'une outre de la tannerie au palier donné, telles que vava_crafting les pose.
    local function loadCrafting()
        VavaCrafting = nil
        helper.loadAll({ 'modules/vava_crafting/shared/constants.lua', 'modules/vava_crafting/config.lua' })
        VavaCrafting.bridge, VavaCrafting.journal, VavaCrafting.catalog = {}, { write = function() end }, {}
        helper.load('modules/vava_crafting/server/signature.lua')
        simple = VavaCrafting.signature.simple
    end

    --- Piles d'un objet dans la besace, les plus anciennes d'abord : { { quantité, palier } }.
    local function stacks(item)
        local list = {}
        for _, pile in ipairs(inventoryExports.getItems(SRC, { item = item })) do
            list[#list + 1] = { pile.quantity, pile.metadata.tier }
        end
        return list
    end

    --- Pile d'un objet au palier donné (nil : sans palier).
    local function pileOf(item, tier)
        for _, pile in ipairs(inventoryExports.getItems(SRC, { item = item })) do
            if pile.metadata.tier == tier then return pile end
        end
        return nil
    end

    --- Une tanneuse fait des outres : ajout de l'artisanat (produit simple au palier de la pièce).
    local function tan(quantity, tier)
        assert.is_true(inventoryExports.exchange(SRC, {}, { { item = 'outre', quantity = quantity, metadata = simple(tier) } }))
    end

    --- Le joueur boit une unité de la pile, puis les threads lancés pendant l'utilisation tournent (comme au tick suivant).
    local function drink(pile)
        assert.is_true(operations.use(SRC, pile.id))
        local pending = queue
        queue = {}
        for _, fn in ipairs(pending) do fn() end
    end

    before_each(function()
        helper.reset()
        realPrint = _G.print
        _G.print = function() end
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/table.lua',
            'shared/lib/string.lua',
            'shared/lib/schema.lua',
            'shared/core/logger.lua',
            'shared/core/hooks.lua',
            'server/core/registry.lua',
        })
        registry, hooks = vAvA.registry, vAvA.hooks
        assert.is_true(registry.define('core', 'core:commands', ANY))
        rpcs, peds, sent, queue, roll = {}, {}, {}, {}, 0.5
        _G.json = { decode = function() return {} end, encode = function() return '{}' end }
        _G.GetInvokingResource = function() return PROVISIONS end
        _G.TriggerClientEvent = function() error('TriggerClientEvent ne doit pas servir') end
        _G.GetResourceState = function(name) return name == INVENTORY and 'started' or 'missing' end
        _G.GetPlayerPed = function(src) return peds[src] and src or 0 end
        _G.DoesEntityExist = function(ped) return ped ~= 0 end
        _G.GetEntityCoords = function(ped)
            local p = peds[ped]
            return { x = p[1], y = p[2], z = p[3] }
        end
        _G.IsPlayerAceAllowed = function() return false end
        _G.RegisterCommand = function() end
        -- tirage fixé avant le chargement (containers.lua garde math.random en local) ; threads tenus jusqu'à la fin
        -- de l'utilisation, comme en jeu
        math.random = function() return roll end
        _G.CreateThread = function(fn) queue[#queue + 1] = fn end

        startInventory()
        loadCrafting()
        startProvisions()
        local fontaine = VavaProvisions.config.points[1]
        peds[SRC] = { fontaine.x, fontaine.y, fontaine.z }
    end)

    after_each(function()
        math.random = realRandom
        _G.print = realPrint
        VavaProvisions, VavaInventory, VavaCrafting = nil, nil, nil
    end)

    it('deux outres vides de même palier s\'empilent, deux paliers différents non', function()
        tan(2, 3)
        tan(2, 3)
        tan(1, 2)
        assert.same({ { 4, 3 }, { 1, 2 } }, stacks('outre'))
        -- une outre sans palier (dotation) : une pile de plus
        assert.is_true(inventoryExports.add(SRC, 'outre', 1))
        assert.same({ { 4, 3 }, { 1, 2 }, { 1, nil } }, stacks('outre'))
        -- le joueur ne peut pas fusionner deux paliers différents
        assert.same({ false, 'not_stackable' }, { operations.merge(SRC, pileOf('outre', 2).id, pileOf('outre', 3).id, 1) })
    end)

    it('remplit en gardant le palier de chaque outre, puis rend l\'outre vide au même palier, qui s\'empile avec les neuves', function()
        tan(2, 3)                                         -- deux outres Soignées
        assert.is_true(inventoryExports.add(SRC, 'outre', 1))   -- une outre de la dotation, sans palier
        tan(1, 1)                                         -- une outre Grossière
        assert.same({ true, { action = 'fill', count = 4 } }, { rpcs['vava_provisions:draw'].handler(SRC, 'fontaine_bourg') })
        assert.same({}, stacks('outre'))
        assert.same({ { 2, 3 }, { 1, nil }, { 1, 1 } }, stacks('eau'))

        -- une Outre d'eau Soignée bue : une outre vide Soignée, qui s'empile avec une outre Soignée neuve
        drink(pileOf('eau', 3))
        assert.same({ { 1, 3 } }, stacks('outre'))
        tan(1, 3)
        assert.same({ { 2, 3 } }, stacks('outre'))

        -- la dernière unité de la pile : la pile disparaît, le palier est gardé quand même
        drink(pileOf('eau', 3))
        assert.is_nil(pileOf('eau', 3))
        assert.same({ { 3, 3 } }, stacks('outre'))

        -- sans palier et Grossière : chacune sa pile, jamais avec les Soignées
        drink(pileOf('eau', nil))
        drink(pileOf('eau', 1))
        assert.same({}, stacks('eau'))
        assert.same({ { 3, 3 }, { 1, nil }, { 1, 1 } }, stacks('outre'))
        assert.same({}, sent)
        assert.same({}, logs.error)
    end)

    it('même tirage : l\'outre Soignée tient, l\'outre sans palier se fend (avis au seul buveur)', function()
        tan(1, 3)
        assert.is_true(inventoryExports.add(SRC, 'outre', 1))
        assert.same({ true, { action = 'fill', count = 2 } }, { rpcs['vava_provisions:draw'].handler(SRC, 'fontaine_bourg') })
        roll = 0.06
        drink(pileOf('eau', 3))
        drink(pileOf('eau', nil))
        assert.same({ { 1, 3 } }, stacks('outre'))
        assert.equal(1, #sent)
        assert.same({ SRC, 'vava_provisions:notice', 'torn' }, { sent[1].target, sent[1].event, sent[1].args[1] })
    end)

    it('une gorgée refusée par un autre abonné ne rend rien, et la suivante rend la bonne outre', function()
        tan(1, 4)
        assert.same({ true, { action = 'fill', count = 1 } }, { rpcs['vava_provisions:draw'].handler(SRC, 'fontaine_bourg') })
        local refuse = true
        -- vava_needs refuse avant (priorité par défaut, avant l'abonné des vivres) : « Vous n'avez plus soif. »
        hooks.subscribe('vava_needs', 'before', 'vava_inventory:use', function()
            if refuse then return false, 'Vous n\'avez plus soif.' end
        end)
        local pile = pileOf('eau', 4)
        assert.same({ false, 'Vous n\'avez plus soif.', true }, { operations.use(SRC, pile.id) })
        assert.same({}, stacks('outre'))
        refuse = false
        drink(pile)
        assert.same({ { 1, 4 } }, stacks('outre'))
    end)
end)
