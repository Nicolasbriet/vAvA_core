local helper = require('tests.helper')

-- Atelier « Récolte » (modules/vava_gathering/shared/editing.lua, 1.8.0, T-102). Règles documentées : spec T-102 § 5.5,
-- § 7.4 et § 11.1, README du module (« Atelier de la récolte ») :
--   déclaration acceptée par le validateur de vava_atelier ; conversions graine ⇄ data ⇄ définition exactes ; valeurs de
--   la graine sur les pas des formulaires ; validate d'une zone (nom unique sans accents ni casse, type connu, lieu exigé
--   à l'essai et à la publication, rayon de 10 à 300 m, chevauchement de 10 m au plus avec une autre zone publiée hors
--   celles retirées par le lot) et d'un point (ressource connue, poisson ⇔ eau, lieu exigé, dedans sa zone + 5 m si la
--   zone n'est pas dans le lot) ; validateLot (120 points au plus, chacun dans le cercle neuf, 2 m entre deux points,
--   retraits non comptés, cercle englobant de 500 m) ; placeCheck (chevauchement, nombre de zones, nombre de points) ;
--   liste de la carte au mètre et empreinte stable quel que soit l'ordre.

local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for key, item in pairs(value) do out[key] = copy(item) end
    return out
end

describe('vava_gathering atelier « Récolte »', function()
    local editing, cfg

    before_each(function()
        helper.reset()
        VavaGathering = nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/editing.lua',
        })
        editing = VavaGathering.editing
        cfg = VavaGathering.config
    end)

    --- Ce que voient les règles : zones et nœuds de la graine (identifiants de ressource), ressources fusionnées.
    local function viewOf(zones, nodes)
        zones = zones or copy(cfg.zones)
        nodes = nodes or copy(cfg.nodes)
        local byId = {}
        for _, zone in ipairs(zones) do byId[zone.id] = zone end
        local resources = {}
        for id, resource in pairs(cfg.resources) do
            resources[id] = { label = resource.label, fishing = cfg.resourceStats[id].fishing == true }
        end
        local kinds = {}
        for _, option in ipairs(cfg.editor.zoneKinds) do kinds[option.value] = true end
        return {
            zones = zones, zone = function(id) return byId[id] end,
            nodesOf = function(zoneId)
                local list = {}
                for _, node in ipairs(nodes) do
                    if node.zone == zoneId then list[#list + 1] = node end
                end
                return list
            end,
            resources = resources, water = cfg.waterKinds, kinds = kinds, settings = cfg.editor,
        }
    end

    local function texts(errors)
        local out = {}
        for i, item in ipairs(errors or {}) do out[i] = item.text end
        return out
    end

    describe('déclaration', function()
        local fs

        before_each(function()
            VavaAtelier = nil
            helper.loadAll({
                'modules/vava_atelier/shared/constants.lua',
                'modules/vava_atelier/shared/bounds.lua',
                'modules/vava_atelier/config.lua',
                'modules/vava_atelier/shared/text.lua',
                'modules/vava_atelier/shared/formvalues.lua',
                'modules/vava_atelier/shared/formschema.lua',
            })
            fs = VavaAtelier.formschema
        end)

        after_each(function()
            VavaAtelier = nil
        end)

        local function declared()
            local def = editing.declaration(cfg)
            local function noop() end
            for _, name in ipairs({ 'index', 'read', 'validate', 'validateLot', 'placeCheck', 'apply', 'remove', 'trial',
                'endTrial', 'options', 'compare' }) do
                def[name] = noop
            end
            return def
        end

        it('est acceptée par le validateur du registre vava_atelier:editors', function()
            local ctx = { families = { monde = true }, rights = { metiers = true }, icons = { recolte = true },
                place = VavaAtelier.config.place }
            assert.same({ true }, { fs.checkEditor(declared(), ctx) })
        end)

        it('bornes de l’abondance (risque lore R-1) : repos 12 % par heure au plus, repousse en 5 min au moins', function()
            local zoneFields, nodeFields = {}, {}
            local def = editing.declaration(cfg)
            for _, field in ipairs(def.kinds[1].form.fields) do zoneFields[field.id] = field end
            for _, field in ipairs(def.kinds[2].form.fields) do nodeFields[field.id] = field end
            assert.equal(12, zoneFields.repos.max)
            assert.equal(300, nodeFields.repousse.min)
            assert.equal('%', zoneFields.fatigue.unit)
            assert.equal('% / h', zoneFields.repos.unit)
            -- la graine reste dans les bornes
            for _, zone in ipairs(cfg.zones) do assert.is_true(zone.regenPerHour <= 12, zone.id) end
            for _, node in ipairs(cfg.nodes) do assert.is_true(node.regenMs >= 300000, node.id) end
        end)

        it('indice accordé et titre du bandeau (lore L-1, suggestion S-3)', function()
            local def = editing.declaration(cfg)
            assert.same({ one = '%s récolte', many = '%s récoltes' }, def.kinds[2].hintFormat)
            assert.equal('Atelier de la récolte', def.texts.banner)
        end)

        it('fixe les choix de la spec : cercle et point orienté enfant, droit metiers, essai joué', function()
            local def = editing.declaration(cfg)
            assert.equal('metiers', def.right)
            assert.is_true(def.trialPlay)
            assert.equal('Tester la récolte', def.texts.trial)
            assert.equal('Publier la zone', def.texts.publish)
            local zone, node = def.kinds[1], def.kinds[2]
            assert.equal('circle', zone.placement)
            assert.same({ min = 10.0, max = 300.0, default = 60.0 }, zone.rules.radius)
            assert.equal('oriented', node.placement)
            assert.equal('zone', node.parent)
            assert.is_false(node.creatable)
            assert.same({ inside = { slack = 5.0 }, spacing = 2.0 }, node.rules)
            assert.same({ 'ressource', 'charges', 'repousse' }, node.template)
            assert.equal('ressource', node.autoTitle)
        end)

        it('donne un fantôme par ressource : son modèle et son apparence (provisoire)', function()
            local models = editing.declaration(cfg).kinds[2].ghost.models
            local count = 0
            for id, look in pairs(models) do
                count = count + 1
                assert.equal(cfg.resources[id].prop.model, look.model, id)
                assert.equal(cfg.looks[id].label, look.label, id)
                assert.is_true(look.provisional, id)
            end
            assert.equal(11, count)
        end)

        it('ne parle jamais de « nœud », de « module », de « config » ni de « base » au Conseil', function()
            local function walk(value)
                if type(value) == 'string' then
                    local lower = value:lower()
                    for _, word in ipairs({ 'nœud', 'noeud', 'module', 'config', ' base' }) do
                        assert.is_nil(lower:find(word, 1, true), value)
                    end
                elseif type(value) == 'table' then
                    for key, item in pairs(value) do
                        if key ~= 'id' and key ~= 'parent' and key ~= 'model' then walk(item) end
                    end
                end
            end
            walk(editing.declaration(cfg))
            for key, value in pairs(cfg.editor.texts) do
                if key ~= 'noZone' then walk(value) end
            end
        end)
    end)

    describe('conversions', function()
        it('graine → data et lieu → définition → data : identiques (4 zones)', function()
            assert.equal(4, #cfg.zones)
            for _, zone in ipairs(cfg.zones) do
                local data, place = editing.zoneData(zone)
                local def = copy(data)
                def.id, def.place = zone.id, place
                local back = editing.zoneOf(def)
                for _, key in ipairs({ 'id', 'label', 'kind', 'x', 'y', 'z', 'radius', 'cost', 'regenPerHour', 'scarHours' }) do
                    assert.equal(zone[key], back[key], zone.id .. '.' .. key)
                end
                local again, againPlace = editing.zoneData(back)
                assert.same(data, again)
                assert.same(place, againPlace)
            end
        end)

        it('graine → data, lieu et parent → définition → data : identiques (12 nœuds)', function()
            assert.equal(12, #cfg.nodes)
            for _, node in ipairs(cfg.nodes) do
                local data, place, parent = editing.nodeData(node)
                assert.equal(node.zone, parent)
                local def = copy(data)
                def.id, def.place, def.parent = node.id, place, parent
                local back = editing.nodeOf(def)
                for _, key in ipairs({ 'id', 'label', 'zone', 'resource', 'x', 'y', 'z', 'heading', 'charges', 'regenMs' }) do
                    assert.equal(node[key], back[key], node.id .. '.' .. key)
                end
                assert.equal('integer', math.type(back.charges))
                assert.equal('integer', math.type(back.regenMs))
                local again, againPlace, againParent = editing.nodeData(back)
                assert.same(data, again)
                assert.same(place, againPlace)
                assert.equal(parent, againParent)
            end
        end)

        it('lit un nœud du catalogue (zone et ressource résolues en définitions)', function()
            local data, _, parent = editing.nodeData({ id = 'n', label = 'Pin 1', zone = { id = 'foret_brume' },
                resource = { id = 'pin' }, x = 0.0, y = 0.0, z = 0.0, charges = 2, regenMs = 60000 })
            assert.same({ nom = 'Pin 1', ressource = 'pin', charges = 2, repousse = 60 }, data)
            assert.equal('foret_brume', parent)
        end)

        it('refuse une définition sans lieu, sans parent ou à valeurs fausses', function()
            assert.same({ nil, 'no_place' }, { editing.zoneOf({ id = 'z', nom = 'Z', genre = 'foret', fatigue = 1,
                repos = 1, cicatrice = 3600 }) })
            assert.same({ nil, 'no_place' }, { editing.zoneOf({ id = 'z', nom = 'Z', genre = 'foret', fatigue = 1,
                repos = 1, cicatrice = 3600, place = { x = 0.0, y = 0.0, z = 0.0, r = 0 / 0 } }) })
            assert.same({ nil, 'bad_data' }, { editing.zoneOf({ id = 'z', nom = 'Z', genre = 'foret', fatigue = 'x',
                repos = 1, cicatrice = 3600, place = { x = 0.0, y = 0.0, z = 0.0, r = 10.0 } }) })
            local node = { id = 'n', nom = 'N', ressource = 'chene', charges = 3, repousse = 600, parent = 'z',
                place = { x = 0.0, y = 0.0, z = 0.0, h = 0.0 } }
            assert.is_not_nil(editing.nodeOf(node))
            local noParent = copy(node)
            noParent.parent = nil
            assert.same({ nil, 'no_zone' }, { editing.nodeOf(noParent) })
            local noPlace = copy(node)
            noPlace.place = nil
            assert.same({ nil, 'no_place' }, { editing.nodeOf(noPlace) })
            local bad = copy(node)
            bad.charges = 0
            assert.same({ nil, 'bad_data' }, { editing.nodeOf(bad) })
        end)

        describe('valeurs de la graine sur les pas des formulaires', function()
            local fv

            before_each(function()
                VavaAtelier = nil
                helper.loadAll({
                    'modules/vava_atelier/shared/constants.lua',
                    'modules/vava_atelier/shared/bounds.lua',
                    'modules/vava_atelier/shared/text.lua',
                    'modules/vava_atelier/shared/formvalues.lua',
                })
                fv = VavaAtelier.formvalues
            end)

            after_each(function()
                VavaAtelier = nil
            end)

            it('chaque zone et chaque nœud passent par l’Atelier sans être changés', function()
                local def = editing.declaration(cfg)
                local zoneForm, nodeForm = def.kinds[1].form, def.kinds[2].form
                for _, zone in ipairs(cfg.zones) do
                    local data = editing.zoneData(zone)
                    local normalized, errors = fv.toData(zoneForm, fv.toPacket(zoneForm, data))
                    assert.is_nil(errors, zone.id)
                    assert.same(data, normalized)
                end
                for _, node in ipairs(cfg.nodes) do
                    local data = editing.nodeData(node)
                    local normalized, errors = fv.toData(nodeForm, fv.toPacket(nodeForm, data))
                    assert.is_nil(errors, node.id)
                    assert.same(data, normalized)
                end
            end)
        end)
    end)

    describe('validate d’une zone', function()
        local function zoneData(name)
            return { nom = name or 'Bois des Essais', genre = 'foret', fatigue = 2, repos = 4, cicatrice = 172800 }
        end
        -- loin de toutes les zones de la graine
        local FAR = { x = 2000.0, y = 2000.0, z = 30.0, r = 60.0 }

        it('accepte une zone nouvelle bien placée', function()
            assert.is_true(editing.validateZone(zoneData(), { action = 'publish', place = FAR }, viewOf()))
        end)

        it('refuse un nom déjà pris, sans accents ni casse ni espaces en trop', function()
            local ok, errors = editing.validateZone(zoneData('  foret DE   brume '), { action = 'save', place = FAR }, viewOf())
            assert.is_false(ok)
            assert.same({ field = 'nom', text = cfg.editor.texts.name }, errors[1])
            -- la zone elle-même garde son nom
            assert.is_true(editing.validateZone(zoneData('Forêt de Brume'), { action = 'publish', id = 'foret_brume',
                place = { x = -320.0, y = -880.0, z = 31.0, r = 120.0 } }, viewOf()))
        end)

        it('ramène les accents et la casse d’un nom à leur base', function()
            assert.equal('foret de brume', editing.nameKey('Forêt  de Brume'))
            assert.equal('oeuvre a l\'ete', editing.nameKey('Œuvre À l\'Été'))
            assert.equal('', editing.nameKey(nil))
        end)

        it('refuse un type de lieu inconnu', function()
            local data = zoneData()
            data.genre = 'volcan'
            local _, errors = editing.validateZone(data, { action = 'save', place = FAR }, viewOf())
            assert.same({ field = 'genre', text = cfg.editor.texts.kind }, errors[1])
        end)

        it('exige un lieu à l’essai et à la publication, pas à l’enregistrement', function()
            assert.is_true(editing.validateZone(zoneData(), { action = 'save' }, viewOf()))
            for _, action in ipairs({ 'trial', 'publish' }) do
                local ok, errors = editing.validateZone(zoneData(), { action = action }, viewOf())
                assert.is_false(ok)
                assert.same({ cfg.editor.texts.noPlaceZone }, texts(errors))
            end
        end)

        it('refuse un rayon de 9,9 m et de 300,1 m, accepte 10 et 300', function()
            for _, r in ipairs({ 9.9, 300.1 }) do
                local ok, errors = editing.validateZone(zoneData(), { action = 'publish',
                    place = { x = 2000.0, y = 2000.0, z = 0.0, r = r } }, viewOf())
                assert.is_false(ok, tostring(r))
                assert.same({ 'Le rayon doit aller de 10 à 300 m.' }, texts(errors))
            end
            for _, r in ipairs({ 10.0, 300.0 }) do
                assert.is_true(editing.validateZone(zoneData(), { action = 'publish',
                    place = { x = 2000.0, y = 2000.0, z = 0.0, r = r } }, viewOf()), tostring(r))
            end
        end)

        it('accepte 10 m de chevauchement avec une zone publiée et en refuse 10,1', function()
            -- Rivière Claire : centre (-120, -880), rayon 60 ; un cercle de 50 m à 100 m de son centre la chevauche de 10 m
            local at = { x = -120.0, y = -780.0, z = 29.0, r = 50.0 }
            assert.is_true(editing.validateZone(zoneData(), { action = 'publish', place = at }, viewOf()))
            local ok, errors = editing.validateZone(zoneData(), { action = 'publish',
                place = { x = -120.0, y = -780.0, z = 29.0, r = 50.1 } }, viewOf())
            assert.is_false(ok)
            assert.same({ 'Cette zone empiète sur « Rivière Claire » de 11 m.' }, texts(errors))
        end)

        it('ignore une zone retirée par le même lot', function()
            local at = { x = -120.0, y = -800.0, z = 29.0, r = 50.0 }
            assert.is_false(editing.validateZone(zoneData(), { action = 'publish', place = at }, viewOf()))
            assert.is_true(editing.validateZone(zoneData(), { action = 'publish', place = at,
                bundle = { { kind = 'zone', id = 'riviere_claire', removal = true } } }, viewOf()))
            -- un retrait ne juge rien
            assert.is_true(editing.validateZone({}, { action = 'remove' }, viewOf()))
        end)

        -- contre-relecture C-1 (a) : une zone publiée déplacée seule (lot d'une fiche : validateLot n'est pas appelé)
        it('zone publiée déplacée seule loin de ses points : refusée par validate (C-1 a)', function()
            local data = editing.zoneData(cfg.zones[1])
            local far = { x = -320.0, y = 650.0, z = 31.0, r = 120.0 }
            local ok, errors = editing.validateZone(data, { action = 'publish', id = 'foret_brume', place = far,
                bundle = { { kind = 'zone', id = 'foret_brume', removal = false } } }, viewOf())
            assert.is_false(ok)
            assert.equal('Ce point est hors de « Forêt de Brume ».', errors[1].text)
            -- ses points dans le même lot : validateLot jugera le cercle neuf avec eux
            assert.is_true(editing.validateZone(data, { action = 'publish', id = 'foret_brume', place = far,
                bundle = { { kind = 'zone', id = 'foret_brume', removal = false },
                    { kind = 'node', id = 'foret_brume_chene_1', parent = 'foret_brume', removal = false } } }, viewOf()))
            -- déplacée de 5 m (vers l'ouest, loin de la mine) : ses points restent dedans
            assert.is_true(editing.validateZone(data, { action = 'publish', id = 'foret_brume',
                place = { x = -325.0, y = -880.0, z = 31.0, r = 120.0 },
                bundle = { { kind = 'zone', id = 'foret_brume', removal = false } } }, viewOf()))
        end)

        it('zone déplacée loin avec tous ses points : le lot passe validateLot (C-1 b)', function()
            local lot = { { kind = 'zone', id = 'foret_brume', removal = false,
                data = editing.zoneData(cfg.zones[1]), place = { x = 3000.0, y = 3000.0, z = 31.0, r = 120.0 } } }
            for i, id in ipairs({ 'foret_brume_chene_1', 'foret_brume_chene_2', 'foret_brume_pin_1' }) do
                lot[#lot + 1] = { kind = 'node', id = id, parent = 'foret_brume', removal = false,
                    place = { x = 3000.0 + 3 * i, y = 3000.0, z = 31.0, h = 0.0 },
                    data = { nom = id, ressource = 'chene', charges = 3, repousse = 600 } }
            end
            assert.is_true(editing.validateLot(lot, viewOf()))
        end)

        -- contre-relecture C-5 : le nom part dans l'état et la carte, borné en octets
        it('nom de plus de 80 octets refusé (lettres accentuées comprises), 80 accepté (C-5)', function()
            local data = editing.zoneData(cfg.zones[1])
            data.nom = string.rep('é', 41)
            local ok, errors = editing.validateZone(data, { action = 'save', id = 'foret_brume' }, viewOf())
            assert.is_false(ok)
            assert.same({ field = 'nom', text = cfg.editor.texts.nameLong }, errors[1])
            data.nom = string.rep('é', 40)
            assert.is_true(editing.validateZone(data, { action = 'save', id = 'foret_brume' }, viewOf()))
        end)

        it('la graine respecte ses propres règles (rayons, chevauchements de 10 m au plus)', function()
            local view = viewOf()
            for _, zone in ipairs(cfg.zones) do
                local data, place = editing.zoneData(zone)
                local ok, errors = editing.validateZone(data, { action = 'publish', id = zone.id, place = place }, view)
                assert.is_true(ok, zone.id .. ' : ' .. table.concat(texts(errors), ' ; '))
            end
        end)
    end)

    describe('validate d’un point', function()
        local function nodeData(resource)
            return { nom = 'Chêne 4', ressource = resource or 'chene', charges = 3, repousse = 600 }
        end
        local INSIDE = { x = -300.0, y = -880.0, z = 31.0, h = 0.0 }

        it('accepte un chêne dans la Forêt de Brume', function()
            assert.is_true(editing.validateNode(nodeData(), { action = 'publish', parent = 'foret_brume', place = INSIDE },
                viewOf()))
        end)

        it('refuse une ressource inconnue', function()
            local ok, errors = editing.validateNode(nodeData('mithril'), { action = 'save', parent = 'foret_brume',
                place = INSIDE }, viewOf())
            assert.is_false(ok)
            assert.same({ field = 'ressource', text = cfg.editor.texts.resource }, errors[1])
        end)

        it('refuse un poisson hors de l’eau et un chêne dans l’eau', function()
            local _, errors = editing.validateNode(nodeData('truite'), { action = 'publish', parent = 'foret_brume',
                place = INSIDE }, viewOf())
            assert.same({ cfg.editor.texts.waterOnly }, texts(errors))
            _, errors = editing.validateNode(nodeData('chene'), { action = 'publish', parent = 'riviere_claire',
                place = { x = -120.0, y = -880.0, z = 29.0, h = 0.0 } }, viewOf())
            assert.same({ cfg.editor.texts.fishOnly }, texts(errors))
            assert.is_true(editing.validateNode(nodeData('brochet'), { action = 'publish', parent = 'riviere_claire',
                place = { x = -120.0, y = -880.0, z = 29.0, h = 0.0 } }, viewOf()))
        end)

        it('refuse un point hors de sa zone (rayon + 5 m), accepte au bord', function()
            -- Forêt de Brume : centre (-320, -880), rayon 120
            assert.is_true(editing.validateNode(nodeData(), { action = 'publish', parent = 'foret_brume',
                place = { x = -195.0, y = -880.0, z = 31.0, h = 0.0 } }, viewOf()))
            local ok, errors = editing.validateNode(nodeData(), { action = 'publish', parent = 'foret_brume',
                place = { x = -194.9, y = -880.0, z = 31.0, h = 0.0 } }, viewOf())
            assert.is_false(ok)
            assert.same({ 'Ce point est hors de « Forêt de Brume ».' }, texts(errors))
        end)

        it('ne juge pas sa zone si elle est dans le lot (validateLot jugera avec le cercle neuf)', function()
            assert.is_true(editing.validateNode(nodeData(), { action = 'publish', parent = 'foret_brume',
                place = { x = 500.0, y = 500.0, z = 31.0, h = 0.0 },
                bundle = { { kind = 'zone', id = 'foret_brume', removal = false } } }, viewOf()))
        end)

        it('exige un lieu et une zone publiée à l’essai et à la publication', function()
            local _, errors = editing.validateNode(nodeData(), { action = 'trial', parent = 'foret_brume' }, viewOf())
            assert.same({ cfg.editor.texts.noPlaceNode }, texts(errors))
            _, errors = editing.validateNode(nodeData(), { action = 'publish', parent = 'zone_neuve', place = INSIDE }, viewOf())
            assert.same({ cfg.editor.texts.noZone }, texts(errors))
            assert.is_true(editing.validateNode(nodeData(), { action = 'save', parent = 'zone_neuve' }, viewOf()))
        end)
    end)

    describe('validateLot', function()
        local function zoneItem(place, removal)
            return { kind = 'zone', id = 'bois', removal = removal == true, place = place,
                data = { nom = 'Bois des Essais', genre = 'foret', fatigue = 2, repos = 4, cicatrice = 172800 } }
        end
        local function nodeItem(id, x, y, extra)
            local item = { kind = 'node', id = id, parent = 'bois', removal = false,
                place = { x = x, y = y, z = 30.0, h = 0.0 },
                data = { nom = id, ressource = 'chene', charges = 3, repousse = 600 } }
            for key, value in pairs(extra or {}) do item[key] = value end
            return item
        end
        local CENTER = { x = 2000.0, y = 2000.0, z = 30.0, r = 60.0 }

        it('accepte une zone nouvelle et cinq points espacés', function()
            local lot = { zoneItem(CENTER) }
            for i = 1, 5 do lot[#lot + 1] = nodeItem('chene_' .. i, 2000.0 + 3 * i, 2000.0) end
            assert.is_true(editing.validateLot(lot, viewOf()))
        end)

        it('refuse 121 points dans une zone, accepte 120', function()
            local lot = { zoneItem({ x = 2000.0, y = 2000.0, z = 30.0, r = 100.0 }) }
            for i = 1, 120 do
                lot[#lot + 1] = nodeItem(string.format('p%03d', i), 1950.0 + (i % 12) * 5, 1950.0 + (i // 12) * 5)
            end
            assert.is_true(editing.validateLot(lot, viewOf()))
            lot[#lot + 1] = nodeItem('p121', 2040.0, 2040.0)
            local ok, errors = editing.validateLot(lot, viewOf())
            assert.is_false(ok)
            assert.same({ 'Cette zone aurait 121 points : 120 au plus.' }, texts(errors))
        end)

        it('refuse deux points à 1,9 m, accepte 2 m', function()
            assert.is_true(editing.validateLot({ zoneItem(CENTER), nodeItem('a', 2000.0, 2000.0), nodeItem('b', 2002.0, 2000.0) },
                viewOf()))
            local ok, errors = editing.validateLot({ zoneItem(CENTER), nodeItem('a', 2000.0, 2000.0),
                nodeItem('b', 2001.9, 2000.0) }, viewOf())
            assert.is_false(ok)
            assert.same({ '« a » et « b » sont trop près l\'un de l\'autre (1,9 m).' }, texts(errors))
        end)

        it('refuse un point hors du cercle neuf de la zone (redessinée plus petite)', function()
            local ok, errors = editing.validateLot({ zoneItem({ x = 2000.0, y = 2000.0, z = 30.0, r = 20.0 }),
                nodeItem('a', 2030.0, 2000.0) }, viewOf())
            assert.is_false(ok)
            assert.same({ 'Ce point est hors de « Bois des Essais ».' }, texts(errors))
        end)

        it('compte les points publiés de la zone, sans ceux que le lot retire', function()
            -- Forêt de Brume redessinée petite autour de chêne 2 : chêne 1 et pin 1 en sortent, sauf s'ils sont retirés
            local zone = { kind = 'zone', id = 'foret_brume', removal = false,
                place = { x = -330.0, y = -870.0, z = 31.0, r = 10.0 },
                data = { nom = 'Forêt de Brume', genre = 'foret', fatigue = 2, repos = 4, cicatrice = 172800 } }
            local ok, errors = editing.validateLot({ zone }, viewOf())
            assert.is_false(ok)
            assert.equal(2, #errors)
            local removal = { kind = 'node', parent = 'foret_brume', removal = true, data = {} }
            local one, two = copy(removal), copy(removal)
            one.id, two.id = 'foret_brume_chene_1', 'foret_brume_pin_1'
            assert.is_true(editing.validateLot({ zone, one, two }, viewOf()))
        end)

        it('juge les points ajoutés à une zone publiée qui n’est pas dans le lot', function()
            local ok, errors = editing.validateLot({ { kind = 'node', id = 'n', parent = 'foret_brume', removal = false,
                place = { x = -330.5, y = -870.0, z = 31.0, h = 0.0 },
                data = { nom = 'Chêne 9', ressource = 'chene', charges = 3, repousse = 600 } } }, viewOf())
            assert.is_false(ok)
            assert.same({ '« Chêne 2 » et « Chêne 9 » sont trop près l\'un de l\'autre (0,5 m).' }, texts(errors))
        end)

        it('refuse un poisson dans une zone de forêt', function()
            local ok, errors = editing.validateLot({ zoneItem(CENTER),
                nodeItem('t', 2000.0, 2000.0, { data = { nom = 't', ressource = 'truite', charges = 3, repousse = 600 } }) },
                viewOf())
            assert.is_false(ok)
            assert.same({ cfg.editor.texts.waterOnly }, texts(errors))
        end)

        it('ignore une zone retirée par le lot', function()
            assert.is_true(editing.validateLot({ zoneItem(CENTER, true), nodeItem('a', 9000.0, 9000.0, { removal = true }) },
                viewOf()))
        end)

        it('garde 8 erreurs au plus', function()
            local lot = { zoneItem({ x = 2000.0, y = 2000.0, z = 30.0, r = 10.0 }) }
            for i = 1, 20 do lot[#lot + 1] = nodeItem('n' .. i, 2100.0 + i * 3, 2000.0) end
            local _, errors = editing.validateLot(lot, viewOf())
            assert.equal(8, #errors)
        end)
    end)

    describe('placeCheck', function()
        it('zone : refuse un chevauchement de plus de 10 m, ignore la zone elle-même', function()
            local ok, why = editing.placeCheck('zone', { x = -120.0, y = -800.0, z = 29.0, r = 50.0 }, { id = '' }, viewOf())
            assert.is_false(ok)
            assert.equal('Cette zone empiète sur « Rivière Claire » de 30 m.', why)
            assert.is_true(editing.placeCheck('zone', { x = -120.0, y = -880.0, z = 29.0, r = 60.0 },
                { id = 'riviere_claire' }, viewOf()))
        end)

        it('zone nouvelle : refusée quand le royaume a déjà son plafond de zones', function()
            local zones = {}
            for i = 1, cfg.editor.maxZones do
                zones[i] = { id = 'z' .. i, label = 'Z' .. i, kind = 'foret', x = i * 1000.0, y = -40000.0, z = 0.0, radius = 10.0 }
            end
            local ok, why = editing.placeCheck('zone', { x = 0.0, y = 0.0, z = 0.0, r = 10.0 }, { id = '' }, viewOf(zones))
            assert.is_false(ok)
            assert.equal('Le royaume compte déjà 256 zones de récolte, le plus permis : retirez-en une d\'abord.', why)
            assert.is_true(editing.placeCheck('zone', { x = 0.0, y = 0.0, z = 0.0, r = 10.0 }, { id = 'z1' }, viewOf(zones)))
        end)

        it('point : refusé dès le clic s’il n’est pas un poisson dans une zone d’eau, ou un poisson hors de l’eau (risque lore R-3)', function()
            local ok, why = editing.placeCheck('node', { x = -120.0, y = -880.0, z = 29.0, h = 0.0 },
                { id = '', siblings = 3, parent = 'riviere_claire', data = { ressource = 'chene' } }, viewOf())
            assert.is_false(ok)
            assert.equal('Une zone d\'eau ne porte que des bancs de poissons.', why)
            ok, why = editing.placeCheck('node', { x = -320.0, y = -880.0, z = 31.0, h = 0.0 },
                { id = '', siblings = 4, parent = 'foret_brume', data = { ressource = 'truite' } }, viewOf())
            assert.is_false(ok)
            assert.equal(cfg.editor.texts.waterOnly, why)
            assert.is_true(editing.placeCheck('node', { x = -120.0, y = -880.0, z = 29.0, h = 0.0 },
                { id = '', siblings = 3, parent = 'riviere_claire', data = { ressource = 'truite' } }, viewOf()))
            -- zone nouvelle (pas encore publiée) : jugée à l'essai et à la publication
            assert.is_true(editing.placeCheck('node', { x = 0.0, y = 0.0, z = 0.0, h = 0.0 },
                { id = '', siblings = 1, parent = 'zone_neuve', data = { ressource = 'chene' } }, viewOf()))
            -- contre-relecture C-4 : le genre jugé est celui du brouillon de la zone tenu par le membre
            ok, why = editing.placeCheck('node', { x = 0.0, y = 0.0, z = 0.0, h = 0.0 },
                { id = '', siblings = 1, parent = 'zone_neuve', data = { ressource = 'chene' }, parentData = { genre = 'eau' } },
                viewOf())
            assert.is_false(ok)
            assert.equal(cfg.editor.texts.fishOnly, why)
            assert.is_true(editing.placeCheck('node', { x = -120.0, y = -880.0, z = 29.0, h = 0.0 },
                { id = '', siblings = 3, parent = 'riviere_claire', data = { ressource = 'chene' },
                    parentData = { genre = 'foret' } }, viewOf()))
        end)

        it('point : refusé au-delà de 120 points dans sa zone après la pose', function()
            assert.is_true(editing.placeCheck('node', { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }, { id = '', siblings = 120 }, viewOf()))
            local ok, why = editing.placeCheck('node', { x = 0.0, y = 0.0, z = 0.0, h = 0.0 }, { id = '', siblings = 121 }, viewOf())
            assert.is_false(ok)
            assert.equal('Cette zone aurait 121 points : 120 au plus.', why)
        end)
    end)

    describe('aides du volet', function()
        it('« Pour comparer » : une autre zone du même type de lieu', function()
            local compare = editing.compare({ nom = 'Bois des Essais', genre = 'foret' }, viewOf())
            assert.same({ title = 'Pour comparer', text = 'Forêt de Brume : fatigue 2 % par récolte, repos 4 % par heure' },
                compare)
            assert.is_nil(editing.compare({ nom = 'Forêt de Brume', genre = 'foret' }, viewOf()))
            assert.same({ title = 'Pour comparer', text = 'Mine du Val : fatigue 2,5 % par récolte, repos 3 % par heure' },
                editing.compare({ nom = 'Mine Neuve', genre = 'mine' }, viewOf()))
        end)

        it('choix « Ressource » : toutes les ressources, triées par libellé', function()
            local options = editing.resourceOptions(cfg.resources)
            assert.equal(11, #options)
            assert.same({ value = 'piste_cerf', label = 'Piste de cerf' }, options[8])
            for i = 2, #options do assert.is_true(options[i - 1].label <= options[i].label) end
        end)
    end)

    describe('liste de la carte', function()
        it('arrondit au mètre, trie par identifiant, rayon d’au moins 1 m', function()
            local list = editing.mapList({
                { id = 'b', label = 'B', kind = 'mine', x = 10.4, y = -10.6, radius = 0.2 },
                { id = 'a', label = 'A', kind = 'foret', x = 0.5, y = 0.0, radius = 120.0 },
            })
            assert.same({
                { i = 'a', l = 'A', k = 'foret', x = 1, y = 0, r = 120 },
                { i = 'b', l = 'B', k = 'mine', x = 10, y = -11, r = 1 },
            }, list)
        end)

        it('a une empreinte stable quel que soit l’ordre, qui change avec une zone', function()
            local zones = copy(cfg.zones)
            local version = editing.mapVersion(editing.mapList(zones))
            assert.truthy(version:find('^%x+$'))
            assert.equal(16, #version)
            local reversed = {}
            for i = #zones, 1, -1 do reversed[#reversed + 1] = zones[i] end
            assert.equal(version, editing.mapVersion(editing.mapList(reversed)))
            zones[1].label = 'Forêt de Brume Neuve'
            assert.are_not.equal(version, editing.mapVersion(editing.mapList(zones)))
            -- un déplacement de moins d'un demi-mètre ne change pas la liste de la carte
            local moved = copy(cfg.zones)
            moved[2].x = moved[2].x + 0.3
            assert.equal(version, editing.mapVersion(editing.mapList(moved)))
        end)

        it('pèse ≈ 60 octets par zone (4 zones : sous 0,3 Ko)', function()
            local list = editing.mapList(cfg.zones)
            local bytes = 0
            for _, zone in ipairs(list) do bytes = bytes + #zone.i + #zone.l + #zone.k + 12 end
            assert.is_true(bytes < 300, tostring(bytes))
        end)
    end)
end)
