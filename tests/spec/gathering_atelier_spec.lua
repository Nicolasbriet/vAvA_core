local helper = require('tests.helper')

-- Atelier « Récolte » côté serveur (modules/vava_gathering/server/atelier.lua, trials.lua, map.lua, harvest.lua ;
-- 1.8.0, T-102), avec le vrai catalogue, les vraies règles (shared/editing.lua) et des doublures du core, de la base et
-- des envois. Règles documentées : spec T-102 § 5.5, § 6, § 7.4, README du module (« Atelier de la récolte ») :
--   l'atelier se déclare si l'Atelier tourne, et de nouveau à son hook `editorsReady` ; `read` rend data, lieu et
--   parent (aller-retour exact avec `apply`) ou la graine (`original`) ; `apply` et `remove` changent le catalogue à
--   chaud, tout ou rien, reprennent vitalité et charges, oublient les récoltes en cours sur un point changé, NOTENT la
--   zone et ne diffusent qu'au dernier appel d'un lot ; l'essai est montré au seul auteur (entier, puis différences),
--   cache les points dont le retrait est préparé ; la récolte d'un point d'essai est à BLANC (rien n'est donné : ni
--   objet, ni XP, ni usure, ni vitalité, ni charge réelle, ni hook) et réservée à son auteur ; la liste de la carte
--   n'est rendue qu'au client dont la version diffère.

describe('vava_gathering atelier côté serveur', function()
    local cfg, catalog, atelier, trials, map
    local hooks, declared, sent, touched, flushes, ensured, forgotten, staleNodes, warnings
    local atelierRunning

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
            'modules/vava_gathering/shared/zonebuild.lua',
            'modules/vava_gathering/shared/editing.lua',
        })
        cfg = VavaGathering.config
        hooks, declared, sent, touched, flushes, warnings = {}, {}, {}, {}, 0, {}
        ensured = { zones = {}, nodes = {} }
        forgotten = { zones = {}, nodes = {} }
        staleNodes = {}
        atelierRunning = true
        VavaGathering.resource = 'vava_gathering'
        VavaGathering.log = { warn = function(fmt, ...) warnings[#warnings + 1] = fmt:format(...) end,
            error = function(fmt, ...) warnings[#warnings + 1] = fmt:format(...) end }
        VavaGathering.core = {
            registry = { define = function() return true end, add = function() return true end, all = function() return {} end },
            hooks = { after = function(name, fn)
                hooks[name] = fn
                return #hooks + 1
            end },
        }
        VavaGathering.bridge = {
            DeclareItem = function() end, ItemExists = function() return true end,
            AtelierExists = function() return atelierRunning end,
            AtelierHas = function(key) return declared[key] ~= nil end,
            AtelierDeclare = function(key, def)
                declared[key] = def
                return true
            end,
            SendPacked = function(target, event, payload)
                sent[#sent + 1] = { target = target, event = event, payload = payload }
                return true
            end,
            GetCharacterId = function(src)
                if src == 99 then return nil end
                return 100 + src
            end,
        }
        helper.load('modules/vava_gathering/server/catalog.lua')
        catalog = VavaGathering.catalog
        assert.is_true(catalog.define())
        VavaGathering.zones = {
            ensure = function(def) ensured.zones[#ensured.zones + 1] = def.id end,
            forget = function(id) forgotten.zones[#forgotten.zones + 1] = id end,
        }
        VavaGathering.nodes = {
            ensure = function(def) ensured.nodes[#ensured.nodes + 1] = def.id end,
            forget = function(id) forgotten.nodes[#forgotten.nodes + 1] = id end,
        }
        local pending = {}
        VavaGathering.share = {
            touch = function(id)
                touched[#touched + 1] = id
                pending[id] = true
            end,
            pending = function()
                local ids = {}
                for id in pairs(pending) do ids[#ids + 1] = id end
                table.sort(ids)
                return ids
            end,
            flush = function()
                flushes = flushes + 1
                pending = {}
            end,
        }
        VavaGathering.harvest = { forgetNode = function(id) staleNodes[#staleNodes + 1] = id end }
        helper.load('modules/vava_gathering/server/trials.lua')
        trials = VavaGathering.trials
        helper.load('modules/vava_gathering/server/map.lua')
        map = VavaGathering.map
        helper.load('modules/vava_gathering/server/atelier.lua')
        atelier = VavaGathering.atelier
        assert.is_true(atelier.start())
    end)

    local function fn(name)
        return declared['vava_gathering:zones'][name]
    end

    local function zoneDef(extra)
        local def = { id = 'bois', version = 1, nom = 'Bois des Essais', genre = 'foret', fatigue = 2.5, repos = 4,
            cicatrice = 172800, place = { x = 2000.0, y = 2000.0, z = 30.0, r = 60.0 } }
        for key, value in pairs(extra or {}) do def[key] = value end
        return def
    end

    local function nodeDef(id, x, extra)
        local def = { id = id, version = 1, nom = 'Chêne', ressource = 'chene', charges = 3, repousse = 600,
            parent = 'bois', place = { x = x, y = 2000.0, z = 30.0, h = 90.0 } }
        for key, value in pairs(extra or {}) do def[key] = value end
        return def
    end

    describe('déclaration', function()
        it('se déclare avec toutes ses fonctions quand l’Atelier tourne, une seule fois', function()
            local def = declared['vava_gathering:zones']
            assert.is_not_nil(def)
            for _, name in ipairs({ 'index', 'read', 'validate', 'validateLot', 'placeCheck', 'apply', 'remove',
                'trial', 'endTrial', 'options', 'compare' }) do
                assert.equal('function', type(def[name]), name)
            end
            assert.equal('Récolte', def.label)
            declared['vava_gathering:zones'].marker = true
            atelier.declare()
            assert.is_true(declared['vava_gathering:zones'].marker)
        end)

        it('sans l’Atelier : avertit et tourne sur sa graine ; se déclare quand il démarre (hook)', function()
            declared, warnings = {}, {}
            atelierRunning = false
            assert.is_true(atelier.start())
            assert.is_nil(declared['vava_gathering:zones'])
            assert.equal(1, #warnings)
            atelierRunning = true
            hooks['vava_atelier:editorsReady']()
            assert.is_not_nil(declared['vava_gathering:zones'])
        end)
    end)

    describe('lecture', function()
        it('index : zones dans l’ordre de la graine, points triés', function()
            local zones = fn('index')('zone')
            assert.same({ id = 'foret_brume', title = 'Forêt de Brume' }, zones[1])
            assert.equal(4, #zones)
            local points = fn('index')('node')
            assert.equal(12, #points)
            assert.equal('foret_brume_chene_1', points[1].id)
        end)

        it('read : data, lieu et parent d’un point ; data et lieu d’une zone', function()
            local zone = fn('read')('zone', 'foret_brume')
            assert.same({ nom = 'Forêt de Brume', genre = 'foret', fatigue = 2.0, repos = 4.0, cicatrice = 172800,
                place = { x = -320.0, y = -880.0, z = 31.0, r = 120.0 } }, zone)
            local node = fn('read')('node', 'foret_brume_chene_2')
            assert.same({ nom = 'Chêne 2', ressource = 'chene', charges = 3, repousse = 600,
                place = { x = -330.0, y = -870.0, z = 31.0, h = 40.0 }, parent = 'foret_brume' }, node)
            assert.is_nil(fn('read')('node', 'inconnu'))
            assert.is_nil(fn('read')('autre', 'foret_brume'))
        end)

        it('original : la graine telle que la config la donne, même après un changement', function()
            assert.is_true(fn('apply')('zone', zoneDef({ id = 'foret_brume', place = { x = -320.0, y = -880.0, z = 31.0,
                r = 100.0 } }), { reason = 'publish', last = true }))
            assert.equal(100.0, fn('read')('zone', 'foret_brume').place.r)
            assert.equal(120.0, fn('read')('zone', 'foret_brume', { original = true }).place.r)
            assert.equal(4, #fn('index')('zone', { original = true }))
        end)
    end)

    describe('apply et remove', function()
        it('zone nouvelle : catalogue changé, état repris, zone notée ; diffusion au seul dernier appel du lot', function()
            assert.is_true(fn('apply')('zone', zoneDef(), { reason = 'publish', last = false }))
            assert.is_not_nil(catalog.zone('bois'))
            assert.same({ 'bois' }, ensured.zones)
            assert.same({ 'bois' }, touched)
            assert.equal(0, flushes)
            assert.is_true(fn('apply')('node', nodeDef('bois_chene_1', 2003.0), { reason = 'publish', last = true }))
            assert.equal(1, flushes)
            assert.equal('bois', catalog.node('bois_chene_1').zone.id)
            assert.same({ 'bois_chene_1' }, ensured.nodes)
            assert.same({ 'bois_chene_1' }, staleNodes)
        end)

        it('aller-retour : après apply, read rend la même data, le même lieu, le même parent', function()
            local zone, node = zoneDef(), nodeDef('bois_chene_1', 2003.0)
            fn('apply')('zone', zone, { reason = 'publish', last = false })
            fn('apply')('node', node, { reason = 'publish', last = true })
            local readZone = fn('read')('zone', 'bois')
            assert.same(zone.place, readZone.place)
            for _, key in ipairs({ 'nom', 'genre', 'fatigue', 'repos', 'cicatrice' }) do
                assert.equal(zone[key], readZone[key], key)
            end
            local readNode = fn('read')('node', 'bois_chene_1')
            assert.same(node.place, readNode.place)
            assert.equal('bois', readNode.parent)
            for _, key in ipairs({ 'nom', 'ressource', 'charges', 'repousse' }) do
                assert.equal(node[key], readNode[key], key)
            end
        end)

        it('tout ou rien : un type de lieu inconnu ou une zone sans lieu ne change rien', function()
            local ok, why = fn('apply')('zone', zoneDef({ genre = 'volcan' }), { reason = 'publish', last = true })
            assert.is_false(ok)
            assert.equal(cfg.editor.texts.kind, why)
            ok, why = fn('apply')('zone', zoneDef({ place = false }), { reason = 'publish', last = true })
            assert.is_false(ok)
            assert.equal(cfg.editor.texts.noPlaceZone, why)
            assert.is_nil(catalog.zone('bois'))
            assert.same({}, touched)
        end)

        it('tout ou rien : un point d’une zone inconnue ou d’une ressource inconnue ne change rien', function()
            assert.is_false(fn('apply')('node', nodeDef('x_1', 0.0, { parent = 'zone_inconnue' }), { last = true }))
            assert.is_false(fn('apply')('node', nodeDef('x_2', -320.0, { parent = 'foret_brume', ressource = 'mithril' }),
                { last = true }))
            assert.is_nil(catalog.node('x_1'))
            assert.is_nil(catalog.node('x_2'))
            assert.same({}, ensured.nodes)
        end)

        -- relecture sécurité S-5, contre-relecture C-1 (b) : une zone déplacée loin avec tous ses points est publiée
        it('zone déplacée loin avec ses trois points dans le même lot : appliquée, puis diffusée (S-5, C-1 b)', function()
            local far = { x = 3000.0, y = 3000.0, z = 31.0, r = 120.0 }
            assert.is_true(fn('apply')('zone', zoneDef({ id = 'foret_brume', nom = 'Forêt de Brume', place = far }),
                { reason = 'publish', last = false }))
            local ids = { 'foret_brume_chene_1', 'foret_brume_chene_2', 'foret_brume_pin_1' }
            for i, id in ipairs(ids) do
                local ok, err = fn('apply')('node', nodeDef(id, 3000.0 + 3 * i, { parent = 'foret_brume',
                    place = { x = 3000.0 + 3 * i, y = 3000.0, z = 31.0, h = 0.0 } }),
                    { reason = 'publish', last = i == #ids })
                assert.is_true(ok, tostring(err))
            end
            assert.equal(1, flushes)
            assert.is_true((catalog.bounds('foret_brume')))
        end)

        -- contre-relecture C-1 (défense) : au dernier appel du lot, une zone hors des bornes du core fait annuler le lot
        it('zone déplacée seule loin de ses points : refusée au dernier appel, rien ne part (C-1)', function()
            local ok, err = fn('apply')('zone', zoneDef({ id = 'foret_brume', nom = 'Forêt de Brume',
                place = { x = -320.0, y = 650.0, z = 31.0, r = 120.0 } }), { reason = 'publish', last = true })
            assert.is_false(ok)
            assert.truthy(err:find('Forêt de Brume', 1, true))
            assert.truthy(err:find('500 m au plus', 1, true))
            assert.equal(0, flushes)
        end)

        it('un point posé n’est contrôlé que pour lui : à plus de 500 m de sa zone ou 121e, refusé (C-1)', function()
            local ok, err = catalog.putNode({ id = 'foret_brume_loin', zone = 'foret_brume', resource = 'chene',
                x = -320.0 + 501.0, y = -880.0, z = 31.0, charges = 1 })
            assert.is_false(ok)
            assert.truthy(err:find('500 m au plus', 1, true))
            assert.is_true(catalog.putNode({ id = 'foret_brume_pres', zone = 'foret_brume', resource = 'chene',
                x = -320.0 + 499.0, y = -880.0, z = 31.0, charges = 1 }))
        end)

        it('point qui change de zone : les deux zones sont notées', function()
            fn('apply')('node', nodeDef('foret_brume_chene_1', -175.0, { parent = 'mine_du_val',
                place = { x = -175.0, y = -1005.0, z = 29.0, h = 0.0 } }), { reason = 'publish', last = true })
            assert.same({ 'mine_du_val', 'foret_brume' }, touched)
            local found = false
            for _, node in ipairs(catalog.nodesOf('mine_du_val')) do
                if node.id == 'foret_brume_chene_1' then found = true end
            end
            assert.is_true(found)
            for _, node in ipairs(catalog.nodesOf('foret_brume')) do assert.are_not.equal('foret_brume_chene_1', node.id) end
        end)

        it('zone retirée : ses points oubliés (vitalité et charges gardées en base), récoltes en cours oubliées', function()
            assert.is_true(fn('remove')('zone', 'foret_brume', { reason = 'remove', last = true }))
            assert.is_nil(catalog.zone('foret_brume'))
            assert.is_nil(catalog.node('foret_brume_chene_1'))
            assert.same({ 'foret_brume' }, forgotten.zones)
            assert.equal(3, #forgotten.nodes)
            assert.equal(3, #staleNodes)
            assert.same({ 'foret_brume' }, touched)
            assert.equal(1, flushes)
        end)

        it('point retiré : sa zone notée, la diffusion attend le dernier appel', function()
            assert.is_true(fn('remove')('node', 'foret_brume_pin_1', { reason = 'remove', last = false }))
            assert.is_nil(catalog.node('foret_brume_pin_1'))
            assert.same({ 'foret_brume' }, touched)
            assert.same({ 'foret_brume_pin_1' }, forgotten.nodes)
            assert.equal(0, flushes)
        end)
    end)

    describe('règles passées à l’Atelier', function()
        it('validate et placeCheck jugent sur le catalogue courant', function()
            local ok = fn('validate')('zone', { nom = 'Forêt de Brume', genre = 'foret', fatigue = 2, repos = 4,
                cicatrice = 3600 }, { action = 'save' })
            assert.is_false(ok)
            assert.is_true(fn('placeCheck')('zone', { x = 2000.0, y = 2000.0, z = 0.0, r = 60.0 }, { id = '' }))
            assert.is_false(fn('placeCheck')('zone', { x = -320.0, y = -880.0, z = 0.0, r = 60.0 }, { id = '' }))
        end)

        it('options : les ressources ; compare : une autre zone du même type', function()
            assert.equal(11, #fn('options')('ressources'))
            assert.same({}, fn('options')('autre'))
            assert.equal('Pour comparer', fn('compare')('zone', { nom = 'Bois', genre = 'mine' }).title)
            assert.is_nil(fn('compare')('node', {}))
        end)
    end)

    describe('essai à blanc', function()
        local SOURCE, ACCOUNT = 4, 7

        local function last()
            return sent[#sent]
        end

        it('zone nouvelle : montrée entière au seul auteur, avec ses points et leurs charges', function()
            assert.is_true(fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start',
                children = { { kind = 'node', def = nodeDef('bois_chene_1', 2003.0) },
                    { kind = 'node', def = nodeDef('bois_chene_2', 2006.0) } } }))
            assert.equal(1, #sent)
            assert.equal(SOURCE, last().target)
            assert.equal(VavaGathering.EVENTS.TRIAL, last().event)
            local payload = last().payload
            assert.equal('full', payload.mode)
            assert.equal('bois', payload.zone)
            assert.equal('Bois des Essais', payload.def[1])
            assert.same({ 'chene', 200300, 200000, 3000, 900, 3 }, payload.nodes.bois_chene_1)
            -- rien dans le catalogue ni dans l'état des zones du core
            assert.is_nil(catalog.zone('bois'))
            assert.same({}, touched)
        end)

        it('zone publiée : ses points publiés, moins ceux dont le retrait est préparé, plus ceux de l’essai', function()
            local data, place = VavaGathering.editing.zoneData(catalog.zone('foret_brume'))
            data.id, data.place = 'foret_brume', place
            fn('trial')('zone', data, { source = SOURCE, accountId = ACCOUNT, reason = 'start',
                children = { { kind = 'node', def = nodeDef('foret_brume_neuf', -300.0, { parent = 'foret_brume',
                    place = { x = -300.0, y = -880.0, z = 31.0, h = 0.0 } }) } },
                removed = { { kind = 'node', id = 'foret_brume_pin_1' } } })
            local shown = last().payload.nodes
            assert.is_not_nil(shown.foret_brume_chene_1)
            assert.is_not_nil(shown.foret_brume_neuf)
            assert.is_nil(shown.foret_brume_pin_1)
        end)

        it('relance après une sauvegarde : une différence, jamais l’essai entier', function()
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start', children = {} })
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'save',
                children = { { kind = 'node', def = nodeDef('bois_chene_3', 2009.0) } } })
            assert.equal(2, #sent)
            assert.equal('patch', last().payload.mode)
            assert.is_not_nil(last().payload.nodes.bois_chene_3)
            assert.equal('Bois des Essais', last().payload.def[1])
        end)

        it('point d’une zone qui n’est pas publiée : refusé', function()
            local ok, why = fn('trial')('node', nodeDef('bois_chene_1', 2003.0), { source = SOURCE, accountId = ACCOUNT,
                reason = 'start', children = {} })
            assert.is_false(ok)
            assert.equal(cfg.editor.texts.noZone, why)
            assert.equal(0, #sent)
        end)

        it('fin d’essai : l’auteur seul rend l’affichage publié', function()
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start', children = {} })
            fn('endTrial')('zone', 'bois', { accountId = ACCOUNT, reason = 'stop' })
            assert.equal(SOURCE, last().target)
            assert.equal(VavaGathering.EVENTS.TRIAL_END, last().event)
            assert.equal('bois', last().payload)
            assert.is_nil(trials.node(SOURCE, 'bois_chene_1'))
        end)

        it('un point d’essai n’existe que pour son auteur ; ses charges d’essai se prennent une à une', function()
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start',
                children = { { kind = 'node', def = nodeDef('bois_chene_1', 2003.0, { charges = 2 }) } } })
            assert.is_not_nil(trials.node(SOURCE, 'bois_chene_1'))
            assert.is_nil(trials.node(5, 'bois_chene_1'))
            assert.is_true(trials.take(SOURCE, 'bois_chene_1'))
            assert.same({ zone = 'bois', mode = 'patch', nodes = { bois_chene_1 = 1 } }, last().payload)
            assert.is_true(trials.take(SOURCE, 'bois_chene_1'))
            assert.is_false(trials.take(SOURCE, 'bois_chene_1'))
            assert.is_false(trials.take(5, 'bois_chene_1'))
        end)

        it('l’Atelier arrêté ou redémarré : tous les essais prennent fin chez leurs auteurs (sécurité S-4)', function()
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start', children = {
                { kind = 'node', def = nodeDef('bois_chene_1', 2003.0) } } })
            fn('trial')('zone', zoneDef({ id = 'autre' }), { source = 5, accountId = 8, reason = 'start', children = {} })
            local count = #sent
            -- un autre registre, ou un autre atelier retiré : rien
            hooks['core:registry:dropped']({ registry = 'vava_gathering:tools' })
            hooks['core:registry:removed']({ registry = 'vava_atelier:editors', key = 'autre:atelier' })
            assert.equal(count, #sent)
            hooks['core:registry:dropped']({ registry = 'vava_atelier:editors', owner = 'vava_atelier' })
            assert.equal(count + 2, #sent)
            assert.equal(VavaGathering.EVENTS.TRIAL_END, sent[#sent].event)
            assert.is_nil(trials.node(SOURCE, 'bois_chene_1'))
            -- l'atelier retiré du registre (Atelier redémarré) : même chose, sans rien renvoyer deux fois
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start', children = {} })
            count = #sent
            hooks['core:registry:removed']({ registry = 'vava_atelier:editors', key = 'vava_gathering:zones' })
            assert.equal(count + 1, #sent)
            hooks['core:registry:removed']({ registry = 'vava_atelier:editors', key = 'vava_gathering:zones' })
            assert.equal(count + 1, #sent)
        end)

        it('auteur parti : plus rien ne lui est envoyé, son point d’essai n’est plus à personne', function()
            fn('trial')('zone', zoneDef(), { source = SOURCE, accountId = ACCOUNT, reason = 'start',
                children = { { kind = 'node', def = nodeDef('bois_chene_1', 2003.0) } } })
            local count = #sent
            trials.forget(SOURCE)
            assert.is_nil(trials.node(SOURCE, 'bois_chene_1'))
            fn('endTrial')('zone', 'bois', { accountId = ACCOUNT, reason = 'session' })
            assert.equal(count, #sent)
        end)
    end)

    describe('liste de la carte', function()
        it('rend la liste au client dont la version diffère, la version seule sinon', function()
            map.refresh()
            local ok, answer = map.rpc(1, '')
            assert.is_true(ok)
            assert.equal(4, #answer.zones)
            assert.equal(map.version(), answer.version)
            ok, answer = map.rpc(1, map.version())
            assert.is_true(ok)
            assert.same({ version = map.version() }, answer)
        end)

        it('refuse un joueur sans personnage chargé', function()
            assert.same({ false, 'no_character' }, { map.rpc(99, '') })
        end)

        it('change de version quand une zone est publiée', function()
            map.refresh()
            local before = map.version()
            fn('apply')('zone', zoneDef(), { reason = 'publish', last = true })
            map.refresh()
            assert.are_not.equal(before, map.version())
            local _, answer = map.rpc(1, before)
            assert.equal(5, #answer.zones)
        end)
    end)
end)

describe('vava_gathering récolte d’un point d’essai (à blanc)', function()
    local harvest, trials, calls, notes, now
    local AUTHOR, OTHER, ACCOUNT = 4, 5, 7

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
            'modules/vava_gathering/shared/zonebuild.lua',
            'modules/vava_gathering/shared/geometry.lua',
        })
        now = 100000
        _G.GetGameTimer = function() return now end
        calls, notes = {}, {}
        local function forbidden(name)
            return function() calls[#calls + 1] = name return true end
        end
        local axe = { id = 31, item = 'hache_fer', metadata = { durability = 50, max_durability = 100 } }
        VavaGathering.log = { warn = function() end }
        VavaGathering.core = { hooks = { runBefore = forbidden('runBefore'), runAfter = forbidden('runAfter') } }
        VavaGathering.bridge = {
            GetCharacterId = function() return 1 end,
            IsDowned = function() return false end,
            Position = function() return 2003.0, 2001.0, 30.0 end,
            Held = function() return axe end,
            GetLevel = function() return 10 end,
            SeasonFactor = function() return 1 end,
            Notify = function(_, text) notes[#notes + 1] = text end,
            CanCarry = forbidden('CanCarry'), Add = forbidden('Add'), AddXp = forbidden('AddXp'),
            PatchMetadata = forbidden('PatchMetadata'),
            SendPacked = function(target, event, payload)
                calls[#calls + 1] = 'send:' .. tostring(target)
                return true
            end,
        }
        local resources = {
            chene = { id = 'chene', label = 'Chêne', item = 'bois_chene', skill = 'bucheronnage', tool = 'hache',
                difficulty = 15, xp = 12, yield = { 2, 4 }, durationMs = 5000, anim = 'chop', fishing = false },
        }
        VavaGathering.catalog = {
            node = function() return nil end,
            zone = function() return nil end,
            tool = function(item) return item == 'hache_fer' and { item = item, kind = 'hache', power = 1.0,
                yieldBonus = 0, qualityBonus = 0, wear = 2 } or nil end,
            itemLabel = function() return 'Bûche de chêne' end,
            resource = function(id) return resources[id] end,
        }
        VavaGathering.zones = {
            state = function() return nil end,
            consume = forbidden('zones.consume'),
        }
        VavaGathering.nodes = { charges = forbidden('nodes.charges'), consume = forbidden('nodes.consume'),
            flush = forbidden('nodes.flush'), restore = forbidden('nodes.restore') }
        helper.load('modules/vava_gathering/server/quality.lua')
        helper.load('modules/vava_gathering/server/trials.lua')
        trials = VavaGathering.trials
        helper.load('modules/vava_gathering/server/harvest.lua')
        harvest = VavaGathering.harvest
        local zone = { id = 'bois', label = 'Bois des Essais', kind = 'foret', x = 2000.0, y = 2000.0, z = 30.0, radius = 60.0 }
        trials.start(AUTHOR, ACCOUNT, zone, { { id = 'bois_chene_1', label = 'Chêne 1', resource = resources.chene,
            x = 2003.0, y = 2000.0, z = 30.0, heading = 0.0, charges = 3, regenMs = 600000 } })
        calls = {}
    end)

    local function harvestOnce(src)
        local ok, started = harvest.begin(src, 'bois_chene_1')
        if not ok then return ok, started end
        now = now + started.durationMs
        return harvest.finish(src, started.token)
    end

    it('l’auteur récolte : quantité et palier dits, rien n’est donné, une charge d’essai prise', function()
        local ok, started = harvest.begin(AUTHOR, 'bois_chene_1')
        assert.is_true(ok)
        assert.is_true(started.trial)
        assert.is_true(started.durationMs > 0)
        now = now + started.durationMs
        local done, result = harvest.finish(AUTHOR, started.token)
        assert.is_true(done)
        assert.is_true(result.trial)
        assert.is_true(result.quantity >= 2)
        -- ni objet, ni XP, ni usure, ni vitalité, ni charge réelle, ni hook : seulement la charge d'essai, chez l'auteur
        assert.same({ 'send:' .. AUTHOR }, calls)
        assert.truthy(notes[#notes]:find('^%[Essai%] Chêne : %d × Bûche de chêne'))
        assert.truthy(notes[#notes]:find('Rien n\'est donné pendant un essai.', 1, true))
        assert.equal(2, trials.node(AUTHOR, 'bois_chene_1').c)
    end)

    it('un autre joueur ne trouve pas le point d’essai', function()
        assert.same({ false, 'unknown_node' }, { harvest.begin(OTHER, 'bois_chene_1') })
    end)

    it('mêmes contrôles qu’une vraie récolte : distance, outil, délai, charges', function()
        VavaGathering.bridge.Position = function() return 2010.0, 2000.0, 30.0 end
        assert.same({ false, 'too_far' }, { harvest.begin(AUTHOR, 'bois_chene_1') })
        VavaGathering.bridge.Position = function() return 2003.0, 2001.0, 30.0 end
        local held = VavaGathering.bridge.Held
        VavaGathering.bridge.Held = function() return nil end
        assert.same({ false, 'no_tool' }, { harvest.begin(AUTHOR, 'bois_chene_1') })
        VavaGathering.bridge.Held = held
        for _ = 1, 3 do
            assert.is_true((harvestOnce(AUTHOR)))
            now = now + 2000
        end
        assert.same({ false, 'no_charges' }, { harvest.begin(AUTHOR, 'bois_chene_1') })
        assert.equal(VavaGathering.config.messages.noCharges, notes[#notes])
    end)

    it('ne touche jamais la vitalité réelle : calcul sur une copie, au rythme de la zone publiée (sécurité S-1)', function()
        local real = { vitality = 50.0, updatedAt = os.time() - 3600, scarredUntil = nil }
        local refreshed
        VavaGathering.zones.state = function() return real end
        VavaGathering.zones.refresh = function(def, state)
            refreshed = def
            state.vitality = state.vitality + def.regenPerHour
            state.updatedAt = os.time()
        end
        VavaGathering.zones.effects = function() return VavaGathering.config.bands.effects.normal end
        VavaGathering.zones.isWater = function() return false end
        VavaGathering.catalog.zone = function() return { id = 'bois', regenPerHour = 4.0 } end
        assert.is_true((harvestOnce(AUTHOR)))
        assert.equal(4.0, refreshed.regenPerHour)
        assert.same({ vitality = 50.0, scarredUntil = nil }, { vitality = real.vitality, scarredUntil = real.scarredUntil })
    end)

    it('essai raté dans une zone d’eau : le texte de l’eau (lore L-6)', function()
        local failing = { yield = 0.2, tierMalus = 2, failure = 1.0 }
        VavaGathering.zones.state = function() return { vitality = 10.0, updatedAt = os.time() } end
        VavaGathering.zones.refresh = function() end
        VavaGathering.zones.effects = function() return failing end
        VavaGathering.catalog.zone = function() return { id = 'bois', regenPerHour = 4.0 } end
        VavaGathering.zones.isWater = function() return true end
        assert.same({ false, 'failed' }, { harvestOnce(AUTHOR) })
        assert.equal(VavaGathering.config.messages.trialFailedWater, notes[#notes])
        VavaGathering.zones.isWater = function() return false end
        now = now + 2000
        assert.same({ false, 'failed' }, { harvestOnce(AUTHOR) })
        assert.equal(VavaGathering.config.messages.trialFailed, notes[#notes])
    end)

    it('trop tôt : refusé, rien de pris', function()
        local _, started = harvest.begin(AUTHOR, 'bois_chene_1')
        assert.same({ false, 'too_soon' }, { harvest.finish(AUTHOR, started.token) })
        assert.equal(3, trials.node(AUTHOR, 'bois_chene_1').c)
    end)

    it('essai fini pendant le geste : rien n’est pris, le point est inconnu', function()
        local _, started = harvest.begin(AUTHOR, 'bois_chene_1')
        trials.stop(ACCOUNT)
        now = now + started.durationMs
        assert.same({ false, 'unknown_node' }, { harvest.finish(AUTHOR, started.token) })
    end)
end)

-- Charges d'un point posé ou retiré par l'Atelier (server/nodes.lua › ensure, forget ; 1.8.0) : les lignes de la base
-- sont gardées au chargement, nœuds encore inconnus compris ; un point qui arrive reprend la sienne, ses charges
-- ramenées à son nouveau maximum, posées comme publiées (l'état entier de sa zone les portera) ; un point retiré n'est
-- plus publié mais garde sa ligne (un retour en arrière le retrouve tel qu'il était).
describe('vava_gathering charges d’un point de l’Atelier', function()
    local nodes, known, rows

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/zonestate.lua',
            'modules/vava_gathering/shared/zonebuild.lua',
        })
        known = {}
        rows = { { node = 'bois_chene_1', charges = 5, updated_at = os.time() } }
        VavaGathering.bridge = {
            SeasonFactor = function() return 1 end,
            Integer = function(value, default) return math.tointeger(value) or default end,
            db = { query = function() return rows end },
        }
        VavaGathering.catalog = { nodes = function() return known end, node = function(id) return known[id] end }
        VavaGathering.share = { set = function() return false end }
        helper.load('modules/vava_gathering/server/nodes.lua')
        nodes = VavaGathering.nodes
        assert.is_true(nodes.load())
    end)

    local function def(id, charges)
        return { id = id, zone = { id = 'bois' }, charges = charges, regenMs = 600000, resource = { skill = 'bucheronnage' } }
    end

    it('un point qui revient reprend sa ligne, charges ramenées à son nouveau maximum', function()
        local point = def('bois_chene_1', 3)
        known.bois_chene_1 = point
        local state = nodes.ensure(point)
        assert.equal(3, state.charges)
        assert.equal(3, nodes.published('bois_chene_1'))
        assert.equal(3, nodes.charges(point))
    end)

    it('un point nouveau part plein ; retiré, il n’est plus publié mais garde son état', function()
        local point = def('bois_chene_9', 4)
        known.bois_chene_9 = point
        nodes.ensure(point)
        assert.equal(4, nodes.published('bois_chene_9'))
        assert.is_true(nodes.consume(point))
        nodes.forget('bois_chene_9')
        known.bois_chene_9 = nil
        assert.is_nil(nodes.published('bois_chene_9'))
        -- revient : sa charge prise est toujours là
        known.bois_chene_9 = point
        nodes.ensure(point)
        assert.equal(3, nodes.published('bois_chene_9'))
    end)

    it('écrit l’état d’un point retiré avec sa zone gardée', function()
        local point = def('bois_chene_9', 4)
        known.bois_chene_9 = point
        nodes.ensure(point)
        nodes.forget('bois_chene_9')
        known.bois_chene_9 = nil
        local queries = {}
        nodes.collect(queries)
        local found = false
        for _, q in ipairs(queries) do
            if q.values[1] == 'bois_chene_9' then
                found = true
                assert.equal('bois', q.values[2])
            end
        end
        assert.is_true(found)
    end)
end)
