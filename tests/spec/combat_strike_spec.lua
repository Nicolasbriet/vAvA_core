local helper = require('tests.helper')

-- Armes côté serveur (modules/vava_combat/server/catalog.lua, wear.lua, strike.lua, pedstate.lua, shields.lua, api.lua,
-- commands.lua, T-111) avec des doublures : bridge (personnages, positions, à terre, main tenue, piles de la besace,
-- besace, patchMetadata qui applique le patch, registres, hit qui note le paquet et rend un résultat réglable,
-- notifications qui notent cible et texte, hooks qui notent et peuvent refuser, champ du bouclier, droits, journal,
-- chat, horloge), statebags d'entités en mémoire avec leur gestionnaire de changement, SetTimeout déclenché à la main,
-- boucles en coroutines jamais lancées seules, math.random fixé, GetInvokingResource réglable. Règles documentées :
-- README du module et docs/plan/specs/T-111.md § 7 et § 11.1.

local A, B, C = 1, 2, 3
local CHAR_A, CHAR_B = 100, 200
local BAG_A, BAG_B = 1000, 2000

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

describe('vava_combat server', function()
    local cfg, catalog, strike, wear, shields, pedState, api, commands, HOOKS, SHIELD_STATE
    local active, positions, downed, held, piles, itemsDown, containers, patches, patchAnswer
    local itemDefs, itemsAdded, recipes, recipesAdded, skillRecipes, versions
    local hits, hitAnswer, notifies, befores, beforeAnswer, afters, fields, fieldSets
    local allowed, adminLogs, chats, chatLines, logs, exported, invoking, buckets
    local entities, peds, players, threads, sets, handler, clock, roll
    local realRandom = math.random
    local STUBBED = { 'Entity', 'GetPlayerPed', 'DoesEntityExist', 'DoesPlayerExist', 'NetworkGetNetworkIdFromEntity',
        'NetworkGetEntityFromNetworkId', 'NetworkGetEntityOwner', 'AddStateBagChangeHandler', 'GetPlayers',
        'GetInvokingResource', 'exports' }

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

    --- Écriture faite par le client propriétaire (gestionnaire, puis valeur appliquée).
    local function clientWrite(entity, value)
        handler('entity:' .. entity.netId, SHIELD_STATE, value, 0, true)
        entity.values[SHIELD_STATE] = value
    end

    local function bag(entity) return entity.values[SHIELD_STATE] end

    local function fireTimers()
        local timers = helper.timers
        helper.timers = {}
        for _, timer in ipairs(timers) do timer.fn() end
        return timers
    end

    local function pile(id, item, metadata)
        return { id = id, item = item, x = 1, y = 1, rotated = false, quantity = 1, metadata = metadata or {} }
    end

    --- Met une pile dans la besace et, au besoin, en main.
    local function give(src, entry, inHand)
        piles[src][#piles[src] + 1] = entry
        if inHand then held[src] = entry end
        return entry
    end

    local function hookAfters(name)
        local out = {}
        for _, entry in ipairs(afters) do
            if entry.name == name then out[#out + 1] = entry.payload end
        end
        return out
    end

    before_each(function()
        helper.reset()
        VavaCombat = nil
        active, positions, downed = { [A] = CHAR_A, [B] = CHAR_B }, { [A] = { 0, 0, 0 }, [B] = { 2, 0, 0 } }, {}
        held, piles, itemsDown, containers = {}, { [A] = {}, [B] = {} }, {}, { [A] = BAG_A, [B] = BAG_B }
        patches, patchAnswer = {}, nil
        itemDefs = {
            epee_courte = { label = 'Épée courte', stack = 1, held = { model = 'w_me_machette_lr' } },
            hache_fer = { label = 'Hache de bûcheron', stack = 1, held = { model = 'prop_tool_fireaxe' } },
        }
        itemsAdded, recipes, recipesAdded, skillRecipes = {}, { epee_courte = { durability = 150 } }, {}, {}
        versions = { vava_crafting = '1.5.0', vava_skills = '1.1.3' }
        hits, hitAnswer, notifies, befores, beforeAnswer, afters, fields, fieldSets = {}, nil, {}, {}, nil, {}, {}, {}
        allowed, adminLogs, chats, chatLines, logs, exported, invoking = {}, {}, {}, {}, { warn = {}, info = {} }, {}, 'vava_example_combat'
        buckets = {}
        entities, peds, players, threads, sets, handler, clock, roll = {}, {}, { [A] = true, [B] = true }, {}, {}, nil, 100000, 0.1

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
        _G.GetPlayers = function()
            local list = {}
            for src in pairs(players) do list[#list + 1] = tostring(src) end
            table.sort(list)
            return list
        end
        _G.GetGameTimer = function() return clock end
        _G.CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
        _G.Wait = function() coroutine.yield() end
        _G.AddStateBagChangeHandler = function(key, bagName, fn)
            assert.equal(VavaCombat.SHIELD_STATE, key)   -- filtré sur la clé : jamais tous les statebags
            assert.is_nil(bagName)
            handler = fn
            return 1
        end
        _G.GetInvokingResource = function() return invoking end
        _G.exports = setmetatable({}, { __call = function(_, name, fn) exported[name] = fn end })
        math.random = function() return roll end

        helper.loadAll({
            'modules/vava_combat/shared/constants.lua',
            'modules/vava_combat/config.lua',
            'modules/vava_combat/shared/shield.lua',
            'modules/vava_combat/shared/weapons.lua',
        })
        cfg, HOOKS, SHIELD_STATE = VavaCombat.config, VavaCombat.HOOKS, VavaCombat.SHIELD_STATE
        VavaCombat.resource = 'vava_combat'
        VavaCombat.log = {
            warn = function(fmt, ...) logs.warn[#logs.warn + 1] = fmt:format(...) end,
            info = function(fmt, ...) logs.info[#logs.info + 1] = fmt:format(...) end,
        }
        VavaCombat.bridge = {
            CONSOLE = 0, INVENTORY = 'vava_inventory', HEALTH = 'vava_health', CRAFTING = 'vava_crafting',
            SKILLS = 'vava_skills',
            ActiveCharacterId = function(src) return active[src] end,
            ActivePlayers = function()
                local out = {}
                for src in pairs(active) do out[#out + 1] = src end
                table.sort(out)
                return out
            end,
            Position = function(src)
                local p = positions[src]
                if not p then return nil end
                return p[1], p[2], p[3]
            end,
            IsDowned = function(src) return downed[src] == true end,
            SameBucket = function(a, b) return (buckets[a] or 0) == (buckets[b] or 0) end,
            Held = function(src) return held[src] end,
            Items = function(src, item)
                if itemsDown[src] then return nil end
                local out = {}
                for _, entry in ipairs(piles[src] or {}) do
                    if entry.item == item then out[#out + 1] = entry end
                end
                return out
            end,
            ContainerOf = function(src) return containers[src] end,
            PatchMetadata = function(src, id, patch)
                patches[#patches + 1] = { source = src, id = id, patch = copy(patch) }
                if patchAnswer then return table.unpack(patchAnswer) end
                for _, entry in ipairs(piles[src] or {}) do
                    if entry.id == id then
                        for key, value in pairs(patch) do entry.metadata[key] = value end
                    end
                end
                return true
            end,
            ItemsReady = function() return true end,
            HasItem = function(name) return itemDefs[name] ~= nil end,
            ItemDefinition = function(name) return copy(itemDefs[name]) end,
            AddItem = function(name, def)
                itemsAdded[name] = def
                itemDefs[name] = def
                return true
            end,
            ModuleVersion = function(name) return versions[name] end,
            RecipesReady = function() return true end,
            Recipe = function(id) return copy(recipes[id]) end,
            AddRecipe = function(id, data)
                if recipes[id] then return false, 'taken' end
                recipes[id], recipesAdded[id] = data, data
                return true
            end,
            SkillRecipesReady = function() return true end,
            AddSkillRecipe = function(id, data)
                skillRecipes[id] = data
                return true
            end,
            HasSkillRecipe = function(id) return skillRecipes[id] ~= nil end,
            Hit = function(target, packet)
                hits[#hits + 1] = { target = target, packet = copy(packet) }
                if hitAnswer then return hitAnswer(packet) end
                return { id = #hits, amount = packet.amount, applied = packet.amount, blocked = 0, absorbed = 0,
                    resisted = 0, added = 0, downed = false, health = 0.5 }
            end,
            HealthKinds = function() return { 'tranchant', 'contondant', 'percant', 'feu' } end,
            DefineShieldField = function() return true end,
            ShieldField = function(characterId) return fields[characterId] end,
            SetShieldField = function(characterId, value)
                fieldSets[#fieldSets + 1] = { characterId = characterId, value = value }
                fields[characterId] = value
            end,
            RunBefore = function(name, payload)
                befores[#befores + 1] = { name = name, payload = copy(payload) }
                if beforeAnswer then return table.unpack(beforeAnswer) end
                return true
            end,
            RunAfter = function(name, payload) afters[#afters + 1] = { name = name, payload = copy(payload) } end,
            Notify = function(target, text, kind)
                -- jamais à tous, jamais une liste, jamais un joueur sans personnage
                assert.equal('integer', math.type(target))
                assert.is_true(target > 0)
                assert.is_not_nil(active[target])
                notifies[#notifies + 1] = { target = target, text = text, kind = kind }
            end,
            IsAllowed = function(src) return src == 0 or allowed[src] == true end,
            AdminLog = function(src, label, details) adminLogs[#adminLogs + 1] = { source = src, label = label, details = copy(details) } end,
            Chat = function(src, text) chats[#chats + 1] = { source = src, text = text } end,
            ChatLines = function(src, lines) chatLines[#chatLines + 1] = { source = src, lines = copy(lines) } end,
            Timer = function() return clock end,
        }
        helper.loadAll({
            'modules/vava_combat/server/catalog.lua',
            'modules/vava_combat/server/pedstate.lua',
            'modules/vava_combat/server/wear.lua',
            'modules/vava_combat/server/shields.lua',
            'modules/vava_combat/server/strike.lua',
            'modules/vava_combat/server/api.lua',
            'modules/vava_combat/server/commands.lua',
        })
        catalog, wear, shields = VavaCombat.catalog, VavaCombat.wear, VavaCombat.shields
        strike, pedState, api, commands = VavaCombat.strike, VavaCombat.pedState, VavaCombat.api, VavaCombat.commands
        local ok, items, recipeCount = catalog.setup()
        assert.is_true(ok, items)
        assert.equal(6, items)
        assert.equal(6, recipeCount)
        assert.is_true(pedState.start())
        VavaCombat.ready = true
        newEntity(101, 11, A)
        newEntity(102, 12, B)
        peds[A], peds[B] = 101, 102
    end)

    after_each(function()
        for _, name in ipairs(STUBBED) do _G[name] = nil end
        math.random = realRandom
        VavaCombat = nil
    end)

    describe('catalogue', function()
        it('déclare six objets, l\'Épée courte adoptée sans être redéclarée, le bouclier sans held et utilisable', function()
            local names = {}
            for name in pairs(itemsAdded) do names[#names + 1] = name end
            table.sort(names)
            assert.same({ 'baton_ferre', 'bouclier_rond', 'dague', 'epee_longue', 'hache_d_armes', 'masse_d_armes' }, names)
            assert.equal('nui://vava_combat/web/items/dague.svg', itemsAdded.dague.image)
            assert.is_nil(itemsAdded.bouclier_rond.held)
            assert.equal('function', type(itemsAdded.bouclier_rond.onUse))
            assert.is_true(catalog.holdable('epee_courte'))
            assert.is_false(catalog.holdable('bouclier_rond'))
            assert.equal('Épée courte', catalog.weapon('epee_courte').label)
        end)

        it('déclare six recettes signées, solidité tirée de la fiche, et leurs recettes de compétence', function()
            for id, data in pairs(recipesAdded) do
                assert.is_true(data.signed)
                assert.equal(cfg.weapons[id].durability, data.durability)
                assert.equal(cfg.recipes[id].skill, skillRecipes[id].skill)
            end
            assert.is_nil(recipesAdded.epee_courte)
            assert.is_true(skillRecipes.epee_longue.transmission)
            assert.is_false(skillRecipes.dague.transmission)
            assert.equal(0, #logs.warn)
        end)

        it('liste les armes par catégorie puis par libellé', function()
            local order = {}
            for i, def in ipairs(catalog.list()) do order[i] = def.item end
            assert.same({ 'epee_courte', 'hache_d_armes', 'masse_d_armes', 'epee_longue', 'dague', 'baton_ferre', 'bouclier_rond' }, order)
            local list = exported.weapons()
            assert.equal(7, #list)
            assert.is_true(list[1].provisional)
            assert.same(catalog.view('dague'), exported.weapon('dague'))
            assert.is_nil(exported.weapon('pain'))
        end)

        it('sans artisanat assez récent : aucune recette, une ligne de console', function()
            recipesAdded = {}
            versions.vava_crafting = '1.4.0'
            assert.equal(0, catalog.onCraftingReady())
            assert.same({}, recipesAdded)
            assert.equal(1, #logs.warn)
            assert.matches('vava_crafting', logs.warn[1])
        end)
    end)

    describe('strike', function()
        it('frappe avec l\'arme tenue : un hit au paquet fermé, puis l\'usure', function()
            give(A, pile(10, 'epee_courte', { quality = 64, durability = 150, max_durability = 150 }), true)
            local result = strike.run(A, B)
            assert.equal(1, #hits)
            assert.equal(B, hits[1].target)
            assert.same({ amount = 12.5, kind = 'tranchant', source = A, weapon = 'epee_courte', tags = { melee = true } },
                hits[1].packet)
            assert.same({ { source = A, id = 10, patch = { durability = 149 } } }, patches)
            assert.same({ item = 'epee_courte', durability = 149, maxDurability = 150, worn = true, dull = false }, result.weapon)
            assert.equal(12.5, result.applied)
        end)

        it('une pièce de qualité épargne parfois l\'usure', function()
            give(A, pile(10, 'epee_courte', { quality = 64, durability = 150, max_durability = 150 }), true)
            roll = 0.95
            local result = strike.run(A, B)
            assert.equal(1, #hits)
            assert.same({}, patches)
            assert.same({ item = 'epee_courte', durability = 150, maxDurability = 150, worn = false, dull = false }, result.weapon)
        end)

        it('refuse sans arme réellement tenue : rien en main, un outil, un objet adopté inconnu', function()
            assert.same({ nil, 'no_weapon' }, { strike.run(A, B) })
            give(A, pile(11, 'hache_fer', { quality = 50 }), true)
            assert.same({ nil, 'no_weapon' }, { strike.run(A, B) })
            give(A, pile(12, 'bouclier_rond'), true)
            assert.same({ nil, 'no_weapon' }, { strike.run(A, B) })
            give(A, pile(10, 'epee_courte'), true)
            itemDefs.epee_courte, recipes = nil, {}
            catalog.onCraftingReady()
            assert.same({ nil, 'no_weapon' }, { strike.run(A, B) })
            assert.equal(1, #logs.warn)
            assert.matches("arme adoptée 'epee_courte'", logs.warn[1])
            assert.equal(0, #hits)
        end)

        it('refuse de trop loin, attaquant à terre, soi-même, cible sans personnage, options piégées', function()
            give(A, pile(10, 'epee_courte'), true)
            positions[B] = { 6.1, 0, 0 }
            assert.same({ nil, 'too_far' }, { strike.run(A, B) })
            positions[B] = nil
            assert.same({ nil, 'too_far' }, { strike.run(A, B) })
            positions[B] = { 2, 0, 0 }
            downed[A] = true
            assert.same({ nil, 'downed' }, { strike.run(A, B) })
            downed[A] = nil
            assert.same({ nil, 'invalid_target' }, { strike.run(A, A) })
            assert.same({ nil, 'invalid_target' }, { strike.run(A, -1) })
            assert.same({ nil, 'no_character' }, { strike.run(A, C) })
            assert.same({ nil, 'invalid_options' }, { strike.run(A, B, { damage = 10 }) })
            assert.same({ nil, 'invalid_options' }, { strike.run(A, B, { tags = { melee = true } }) })
            VavaCombat.ready = false
            assert.same({ nil, 'not_ready' }, { strike.run(A, B) })
            assert.equal(0, #hits)
        end)

        it('passe la technique, le multiplicateur, les étiquettes et la partie', function()
            give(A, pile(10, 'epee_courte', { quality = 50 }), true)
            strike.run(A, B, { technique = 'vava_combat:taille_descendante', damage = 1.5, tags = { parryable = true }, part = 'torse' })
            assert.same({ amount = 18.0, kind = 'tranchant', source = A, weapon = 'epee_courte',
                technique = 'vava_combat:taille_descendante', part = 'torse', tags = { melee = true, parryable = true } },
                hits[1].packet)
        end)

        it('l\'export n\'admet que les ressources de strike.callers (console une fois par minute)', function()
            give(A, pile(10, 'epee_courte'), true)
            invoking = 'vava_autre'
            for _ = 1, 10 do assert.same({ nil, 'not_allowed' }, { exported.strike(A, B) }) end
            assert.equal(1, #logs.warn)
            assert.matches('vava_autre', logs.warn[1])
            clock = clock + 60000
            exported.strike(A, B)
            assert.equal(2, #logs.warn)
            assert.equal(0, #hits)
            invoking = 'vava_example_combat'
            assert.is_table(exported.strike(A, B))
            assert.equal(1, #hits)
        end)

        it('rend le refus de hit tel quel, sans usure ; esquive sans usure ; parade avec usure', function()
            give(A, pile(10, 'epee_courte', { quality = 50 }), true)
            hitAnswer = function() return nil, 'too_many_hits' end
            assert.same({ nil, 'too_many_hits' }, { strike.run(A, B) })
            hitAnswer = function() return { amount = 0, applied = 0, cancelled = 'esquive', stage = 'esquive', health = 1 } end
            local result = strike.run(A, B)
            assert.equal('esquive', result.cancelled)
            assert.is_false(result.weapon.worn)
            assert.same({}, patches)
            hitAnswer = function() return { amount = 0, applied = 0, cancelled = 'parade', stage = 'parade', health = 1 } end
            strike.run(A, B)
            assert.same({ { source = A, id = 10, patch = { durability = 149, max_durability = 150 } } }, patches)
        end)

        it('prévient le seul porteur aux seuils ; émoussée : hook, puis coups à moitié sans usure', function()
            local sword = give(A, pile(10, 'epee_courte', { quality = 64, durability = 38, max_durability = 150 }), true)
            strike.run(A, B)
            assert.equal(37, sword.metadata.durability)
            assert.equal(1, #notifies)
            assert.equal(A, notifies[1].target)
            assert.equal('Épée courte : solidité 37 / 150, l\'arme s\'émousse.', notifies[1].text)
            strike.run(A, B)
            assert.equal(1, #notifies)
            sword.metadata.durability = 1
            strike.run(A, B)
            assert.equal(0, sword.metadata.durability)
            assert.equal(2, #notifies)
            assert.matches('émoussée', notifies[2].text)
            assert.equal('warning', notifies[2].kind)
            assert.same({ { source = A, characterId = CHAR_A, instanceId = 10, item = 'epee_courte' } }, hookAfters(HOOKS.DULLED))
            local before = #patches
            local result = strike.run(A, B)
            assert.equal(6.3, hits[#hits].packet.amount)
            assert.equal(before, #patches)
            assert.is_true(result.weapon.dull)
            assert.equal(0, result.weapon.durability)
        end)

        it('pile sans métadonnées : solidité et maximale écrites', function()
            give(A, pile(10, 'epee_courte'), true)
            strike.run(A, B)
            assert.same({ { source = A, id = 10, patch = { durability = 149, max_durability = 150 } } }, patches)
        end)

        it('refuse une cible dans une autre instance (routing bucket), quelle que soit la distance', function()
            give(A, pile(10, 'epee_courte'), true)
            buckets[B] = 7
            assert.same({ nil, 'too_far' }, { strike.run(A, B) })
            assert.equal(0, #hits)
            buckets[A] = 7
            assert.is_table(strike.run(A, B))
        end)

        it('use la pile relue après le coup, pas celle lue avant (usée entre-temps par un autre coup)', function()
            local sword = give(A, pile(10, 'epee_courte', { quality = 50, durability = 150, max_durability = 150 }), true)
            hitAnswer = function(packet)
                -- un abonné de la chaîne a cédé la main : un autre coup a porté la solidité à 100
                sword.metadata.durability = 100
                return { amount = packet.amount, applied = packet.amount, health = 0.5 }
            end
            local result = strike.run(A, B)
            assert.same({ { source = A, id = 10, patch = { durability = 99 } } }, patches)
            assert.equal(99, result.weapon.durability)
        end)

        it('pile partie de la besace pendant le coup, ou inventaire muet : aucune usure', function()
            give(A, pile(10, 'epee_courte', { quality = 50 }), true)
            hitAnswer = function(packet)
                piles[A] = {}
                return { amount = packet.amount, applied = packet.amount, health = 0.5 }
            end
            local result = strike.run(A, B)
            assert.same({}, patches)
            assert.is_false(result.weapon.worn)
            give(A, pile(10, 'epee_courte', { quality = 50 }), true)
            hitAnswer = function(packet)
                itemsDown[A] = true
                return { amount = packet.amount, applied = packet.amount, health = 0.5 }
            end
            strike.run(A, B)
            assert.same({}, patches)
        end)

        it('écriture refusée : console, rien de prévenu, solidité inchangée dans le résultat', function()
            give(A, pile(10, 'epee_courte', { durability = 1, max_durability = 150 }), true)
            patchAnswer = { false, 'durability_locked' }
            local result = strike.run(A, B)
            assert.equal(1, result.weapon.durability)
            assert.is_false(result.weapon.worn)
            assert.equal(0, #notifies)
            assert.equal(0, #hookAfters(HOOKS.DULLED))
            assert.matches('durability_locked', logs.warn[1])
        end)
    end)

    describe('armed', function()
        it('rend l\'arme tenue et son coup à × 1,0, ou no_weapon', function()
            assert.same({ nil, 'no_weapon' }, { api.armed(A) })
            assert.same({ nil, 'no_character' }, { api.armed(C) })
            give(A, pile(10, 'epee_courte', { quality = 64, durability = 140, max_durability = 145 }), true)
            local view = api.armed(A)
            assert.equal(12.5, view.amount)
            assert.near(1.042, view.factor, 1e-9)
            assert.same({ 10, 'une_main', 'epee', 140, 145, false, 64 },
                { view.instanceId, view.category, view.family, view.durability, view.maxDurability, view.dull, view.quality })
        end)
    end)

    describe('bouclier', function()
        local function use(id, item) return shields.onUse(A, { id = id, item = item or 'bouclier_rond' }) end

        it('« utiliser » l\'accroche puis le décroche, sans jamais le consommer', function()
            give(A, pile(20, 'bouclier_rond'))
            assert.same({ false, 'Bouclier rond accroché, prêt à servir.' }, { use(20) })
            assert.same({ id = 20, item = 'bouclier_rond' }, bag(entities[101]))
            assert.is_true(sets[#sets].replicated)
            assert.equal(20, fields[CHAR_A])
            assert.same({ { source = A, characterId = CHAR_A, instanceId = 20, item = 'bouclier_rond', hang = true, reason = 'use' } },
                hookAfters(HOOKS.SHIELD_HANG))
            clock = clock + 500
            assert.same({ false, 'Un instant…' }, { use(20) })
            clock = clock + 500
            assert.same({ false, 'Bouclier rond décroché.' }, { use(20) })
            assert.is_nil(bag(entities[101]))
            assert.is_nil(fields[CHAR_A])
            assert.is_false(hookAfters(HOOKS.SHIELD_HANG)[2].hang)
        end)

        it('un second bouclier remplace le premier', function()
            give(A, pile(20, 'bouclier_rond'))
            give(A, pile(21, 'bouclier_rond'))
            use(20)
            clock = clock + 1000
            use(21)
            assert.same({ id = 21, item = 'bouclier_rond' }, bag(entities[101]))
            assert.equal(21, fields[CHAR_A])
            local events = hookAfters(HOOKS.SHIELD_HANG)
            assert.equal(3, #events)
            assert.same({ 20, false }, { events[2].instanceId, events[2].hang })
            assert.same({ 21, true }, { events[3].instanceId, events[3].hang })
        end)

        it('refusé à terre, et par un hook before (sa raison est montrée) ; rien n\'est publié', function()
            give(A, pile(20, 'bouclier_rond'))
            downed[A] = true
            assert.same({ false, cfg.messages.shieldDowned }, { use(20) })
            downed[A] = nil
            beforeAnswer = { false, 'Pas d\'armes au cachot.' }
            assert.same({ false, 'Pas d\'armes au cachot.' }, { use(20) })
            assert.same({ source = A, characterId = CHAR_A, instanceId = 20, item = 'bouclier_rond' }, befores[1].payload)
            assert.is_nil(bag(entities[101]))
            assert.same({}, fieldSets)
            assert.equal(0, #hookAfters(HOOKS.SHIELD_HANG))
            -- un objet qui n'est pas un bouclier n'est jamais accroché
            clock = clock + 1000
            beforeAnswer = nil
            assert.same({ false }, { use(30, 'dague') })
        end)

        it('décroché aussitôt quand la pile est jetée ou quitte la besace', function()
            give(A, pile(20, 'bouclier_rond'))
            use(20)
            shields.onMove({ source = A, instanceId = 20, item = 'bouclier_rond', from = BAG_A, to = BAG_A })
            assert.is_not_nil(bag(entities[101]))
            shields.onDrop({ source = A, instanceId = 20, item = 'bouclier_rond', from = BAG_A, to = 9000 })
            assert.is_nil(bag(entities[101]))
            assert.is_nil(fields[CHAR_A])
            assert.equal('gone', hookAfters(HOOKS.SHIELD_HANG)[2].reason)
            clock = clock + 1000
            use(20)
            -- fouille : la pile passe dans la besace d'un autre, déplacée par lui
            shields.onMove({ source = B, instanceId = 20, item = 'bouclier_rond', from = BAG_A, to = BAG_B })
            assert.is_nil(bag(entities[101]))
        end)

        it('retrait par un module : possession relue, décroché si la pile n\'y est plus', function()
            give(A, pile(20, 'bouclier_rond'))
            use(20)
            shields.onRemove({ container = BAG_A, removals = { { item = 'bouclier_rond', quantity = 1 } }, owner = 'x' })
            assert.is_not_nil(bag(entities[101]))
            shields.onRemove({ container = BAG_B, removals = { { instanceId = 20 } }, owner = 'x' })
            assert.is_not_nil(bag(entities[101]))
            piles[A] = {}
            shields.onRemove({ container = BAG_A, removals = { { instanceId = 20 } }, owner = 'x' })
            assert.is_nil(bag(entities[101]))
        end)

        it('relevé lent : décroché après deux relevés manquants ; inventaire muet : relevé sauté', function()
            give(A, pile(20, 'bouclier_rond'))
            use(20)
            itemsDown[A] = true
            shields.verify()
            shields.verify()
            shields.verify()
            assert.is_not_nil(bag(entities[101]))
            itemsDown[A] = nil
            piles[A] = {}
            shields.verify()
            assert.is_not_nil(bag(entities[101]))
            shields.verify()
            assert.is_nil(bag(entities[101]))
            assert.is_nil(fields[CHAR_A])
        end)

        it('repris à l\'apparition si la pile est toujours là ; sinon le champ est effacé', function()
            give(A, pile(20, 'bouclier_rond'))
            fields[CHAR_A] = 20
            shields.restore(A)
            assert.same({ id = 20, item = 'bouclier_rond' }, bag(entities[101]))
            assert.equal('restored', hookAfters(HOOKS.SHIELD_HANG)[1].reason)
            assert.equal(0, #befores)
            -- déchargement : statebag vidé, champ gardé
            shields.release(A)
            assert.is_nil(bag(entities[101]))
            assert.equal(20, fields[CHAR_A])
            piles[A] = {}
            shields.restore(A)
            assert.is_nil(bag(entities[101]))
            assert.is_nil(fields[CHAR_A])
            -- inventaire muet : le champ est gardé
            fields[CHAR_A] = 20
            itemsDown[A] = true
            shields.restore(A)
            assert.equal(20, fields[CHAR_A])
        end)

        it('shield(src) : rien sans la pile ; pile partie de la besace : décroché aussitôt', function()
            give(A, pile(20, 'bouclier_rond', { durability = 120, max_durability = 150 }))
            use(20)
            itemsDown[A] = true
            assert.is_nil(exported.shield(A))
            -- inventaire muet : rien n'est affirmé, mais rien n'est décroché non plus
            assert.is_not_nil(bag(entities[101]))
            itemsDown[A] = nil
            piles[A] = {}
            assert.is_nil(exported.shield(A))
            assert.is_nil(bag(entities[101]))
            assert.is_nil(fields[CHAR_A])
            assert.equal('gone', hookAfters(HOOKS.SHIELD_HANG)[2].reason)
        end)

        it('une même pile accrochée par un autre porteur décroche le premier', function()
            local buckler = give(A, pile(20, 'bouclier_rond'))
            use(20)
            piles[B][1] = buckler
            shields.onUse(B, { id = 20, item = 'bouclier_rond' })
            assert.is_nil(bag(entities[101]))
            assert.same({ id = 20, item = 'bouclier_rond' }, bag(entities[102]))
            assert.is_nil(shields.hungOf(A))
            assert.is_nil(fields[CHAR_A])
        end)

        it('shield(src) : solidité de la pile et position d\'après la main', function()
            give(A, pile(20, 'bouclier_rond', { durability = 120, max_durability = 150 }))
            use(20)
            local view = exported.shield(A)
            assert.same({ 20, 'back', false, 120, 0.7 }, { view.instanceId, view.position, view.ready, view.durability, view.block })
            give(A, pile(10, 'epee_courte'), true)
            assert.is_true(exported.shield(A).ready)
            assert.is_nil(exported.shield(B))
        end)
    end)

    describe('garde du statebag', function()
        it('remet la valeur du serveur réécrite par le client, de plus en plus tard', function()
            give(A, pile(20, 'bouclier_rond'))
            shields.onUse(A, { id = 20, item = 'bouclier_rond' })
            local ped = entities[101]
            local logged = #logs.warn
            clientWrite(ped, nil)
            assert.equal(cfg.shield.guardDelayMs, helper.timers[1].ms)
            fireTimers()
            assert.same({ id = 20, item = 'bouclier_rond' }, bag(ped))
            assert.equal(logged + 1, #logs.warn)
            assert.matches('joueur 1', logs.warn[#logs.warn])
            for _ = 1, 2 do
                clientWrite(ped, { id = 99, item = 'bouclier_rond' })
                fireTimers()
            end
            -- quatrième remise sans nouvelle publication : délai doublé
            clientWrite(ped, nil)
            assert.equal(500, helper.timers[1].ms)
            fireTimers()
            assert.same({ id = 20, item = 'bouclier_rond' }, bag(ped))
        end)

        it('efface une valeur écrite sur une entité non suivie', function()
            local other = newEntity(300, 30, C)
            clientWrite(other, { id = 5, item = 'bouclier_rond' })
            fireTimers()
            assert.is_nil(bag(other))
        end)
    end)

    describe('/armes', function()
        it('refuse sans droit ; usage pour des points hors bornes', function()
            give(B, pile(40, 'epee_courte', { durability = 149, max_durability = 150 }), true)
            commands.handle(A, { 'user', tostring(B), '20' })
            assert.equal(cfg.messages.adminDenied, chats[1].text)
            assert.same({}, patches)
            allowed[A] = true
            commands.handle(A, { 'user', tostring(B), '0' })
            commands.handle(A, { 'user', tostring(B), '1001' })
            assert.matches('^Usage', chats[2].text)
            assert.matches('^Usage', chats[3].text)
            assert.same({}, patches)
            assert.same({}, adminLogs)
        end)

        it('baisse la solidité de l\'arme en main, journalisé', function()
            allowed[A] = true
            local sword = give(B, pile(40, 'epee_courte', { durability = 149, max_durability = 150 }), true)
            commands.handle(A, { 'user', tostring(B), '20' })
            assert.equal(129, sword.metadata.durability)
            assert.same({ { source = A, label = cfg.journal.wear, details = { cible = B, objet = 'epee_courte', avant = 149, apres = 129 } } },
                adminLogs)
            commands.handle(A, { 'user', tostring(B), '1000' })
            assert.equal(0, sword.metadata.durability)
            assert.equal(B, notifies[#notifies].target)
            assert.matches('émoussée', notifies[#notifies].text)
        end)

        it('écriture refusée : message à part, rien au journal', function()
            allowed[A] = true
            local sword = give(B, pile(40, 'epee_courte', { durability = 149, max_durability = 150 }), true)
            patchAnswer = { false, 'durability_locked' }
            commands.handle(A, { 'user', tostring(B), '20' })
            assert.equal(149, sword.metadata.durability)
            assert.equal(cfg.messages.adminFailed:format('Épée courte'), chats[#chats].text)
            assert.same({}, adminLogs)
        end)

        it('liste les armes et inspecte celle d\'un joueur (journal)', function()
            allowed[A] = true
            commands.handle(A, { 'liste' })
            -- en-tête et sept lignes, remis d'un bloc (regroupés en messages par le bridge)
            assert.equal(0, #chats)
            assert.equal(1, #chatLines)
            assert.equal(8, #chatLines[1].lines)
            assert.matches('modèle provisoire', chatLines[1].lines[2])
            give(B, pile(40, 'epee_courte', { quality = 64, tier = 3, durability = 149, max_durability = 150 }), true)
            commands.handle(A, { 'voir', tostring(B) })
            assert.matches('coup 12 → 12,5', chats[#chats].text)
            assert.same({ source = A, label = cfg.journal.inspect, details = { cible = B, objet = 'epee_courte' } }, adminLogs[1])
            commands.handle(A, { 'voir', '42' })
            assert.equal(cfg.messages.adminNoPlayer, chats[#chats].text)
        end)
    end)
end)
