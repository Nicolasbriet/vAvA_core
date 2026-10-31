local helper = require('tests.helper')

-- RPC `place` et `children` de l'outil de placement (modules/vava_atelier/server/placement.lua, 1.3.0, T-102), avec la
-- vraie déclaration de l'atelier « Récolte » (vava_gathering/shared/editing.lua), les vraies règles (shared/place.lua,
-- shared/placerules.lua, shared/lifecycle.lua, shared/slug.lua, shared/formvalues.lua) et des doublures de la base, des
-- têtes, de l'écriture (server/lifecycle.lua › cycle.place) et du jeu. Règles documentées : spec T-102 § 6.1 et § 7.1,
-- README du module (« Outil de placement ») :
--   le serveur ne croit aucun lieu du client : type placé (jamais une porte), instance du royaume, personnage présent
--   et position lue par lui, forme du lieu, portée (60 m), fiche (nouvelle : parent vivant, titre donné tout seul,
--   plafonds ; existante : vivante, sans valeurs), règles déclarées avec le parent et les frères lus en base,
--   `placeCheck` du module ; refus de lieu `{ done = false, errors = { { field = 'place', text } } }`, refus de
--   structure `false, code` ; `children` rend le lieu de la fiche, de son parent et de ses enfants ou frères.

describe('vava_atelier placement côté serveur', function()
    local placement, editor, ctx, heads, rowsOf, json, written, checked, position, bucket, liveCount, allowed

    local ACCOUNT, OTHER = 7, 9
    -- Bois des Essais : centre (100, 100), rayon 60 ; le Sénéchal se tient au centre
    local ZONE_PLACE = { x = 100.0, y = 100.0, z = 30.0, r = 60.0 }

    --- Ligne de la base (CHILDREN_SQL) : lieu et data en JSON (doublure : clé de la table `json`).
    local function dbRow(kind, id, status, place, data, holder, extra)
        local key = '#' .. kind .. '/' .. id .. '/' .. status
        json[key .. '/p'], json[key .. '/d'] = place, data
        local row = { kind = kind, def_id = id, status = status, removal = 0, title = data and data.nom or id,
            parent = 'bois', place = key .. '/p', data = key .. '/d', author_account_id = holder, rev = 1 }
        for k, v in pairs(extra or {}) do row[k] = v end
        return row
    end

    local function chene(i, x, y, status, holder)
        return dbRow('node', 'chene_' .. i, status or 'published', { x = x, y = y, z = 30.0, h = 0.0 },
            { nom = 'Chêne ' .. i, ressource = 'chene', charges = 3, repousse = 600 }, holder)
    end

    before_each(function()
        helper.reset()
        VavaAtelier, VavaGathering = nil, nil
        helper.loadAll({
            'modules/vava_gathering/shared/constants.lua',
            'modules/vava_gathering/config.lua',
            'modules/vava_gathering/shared/editing.lua',
            'modules/vava_atelier/shared/constants.lua',
            'modules/vava_atelier/config.lua',
            'modules/vava_atelier/shared/placerules.lua',
            'modules/vava_atelier/shared/bounds.lua',
            'modules/vava_atelier/shared/text.lua',
            'modules/vava_atelier/shared/formvalues.lua',
            'modules/vava_atelier/shared/place.lua',
            'modules/vava_atelier/shared/slug.lua',
            'modules/vava_atelier/shared/lifecycle.lua',
        })
        local fv = VavaAtelier.formvalues
        local declaration = VavaGathering.editing.declaration(VavaGathering.config)
        local kinds = {}
        for _, def in ipairs(declaration.kinds) do
            local fields = {}
            for _, field in ipairs(def.form.fields) do fields[field.id] = field end
            kinds[def.id] = { def = def, fields = fields }
        end
        editor = { id = 'vava_gathering:zones', kinds = kinds, children = { zone = { 'node' } }, format = 1 }
        ctx = { source = 3, accountId = ACCOUNT, editor = editor, kind = kinds.node }
        heads, rowsOf, json, written, checked = {}, {}, {}, {}, {}
        position, bucket, liveCount, allowed = { x = 100.0, y = 100.0, z = 30.0 }, 0, 0, true
        heads['zone|bois'] = { kind = 'zone', id = 'bois', title = 'Bois des Essais',
            published = { row = 1, version = 1, parent = nil } }
        rowsOf[1] = { data = { nom = 'Bois des Essais', genre = 'foret', fatigue = 2, repos = 4, cicatrice = 172800 },
            place = ZONE_PLACE }
        local options = VavaGathering.editing.resourceOptions(VavaGathering.config.resources)
        local byValue = {}
        for _, option in ipairs(options) do byValue[option.value] = option end

        VavaAtelier.core = {}
        VavaAtelier.bridge = {
            Bucket = function() return bucket end,
            Position = function() return position end,
            JsonDecode = function(text) return json[text] end,
        }
        VavaAtelier.entries = { source = function() return options, byValue end }
        VavaAtelier.check = {
            values = function(kind, packet)
                local data, errors = fv.toData(kind.def.form, packet)
                if not data then return nil, errors end
                return data
            end,
            world = function() return {} end,
            bounded = function(errors) return errors end,
        }
        VavaAtelier.store = {
            children = function(_, parentId)
                local out = {}
                for _, row in ipairs(rowsOf.children or {}) do
                    if row.parent == parentId then out[#out + 1] = row end
                end
                return out
            end,
        }
        VavaAtelier.index = {
            get = function(_, kindId, id) return heads[kindId .. '|' .. id] end,
            alive = function(head) return head ~= nil and (head.published ~= nil or head.draft ~= nil) end,
            liveCount = function() return liveCount end,
            taken = function(_, kindId, id) return heads[kindId .. '|' .. id] ~= nil end,
            toInt = function(value) return math.tointeger(value) end,
        }
        VavaAtelier.calls = {
            titleOf = function(kind, data, fallback) return data[kind.def.form.titleField] or fallback end,
            placeCheck = function(_, kindId, where, info)
                checked[#checked + 1] = { kind = kindId, place = where, ctx = info }
                if allowed == true then return true end
                return false, allowed
            end,
        }
        VavaAtelier.cycle = {
            available = function() return true end,
            rowEntry = function(_, _, rowId)
                local row = rowsOf[rowId]
                if not row then return nil, 'unknown_entry' end
                return row, { data = row.data, place = row.place, parent = row.parent }
            end,
            place = function(_, req)
                written[#written + 1] = req
                local head = req.head or { kind = req.kind.def.id, id = req.id, title = req.title }
                head.draft = { row = 50, rev = (req.head and req.head.draft and req.head.draft.rev or 0) + 1,
                    status = 'draft', holder = ACCOUNT }
                local data = req.data
                if not data and req.head then data = rowsOf[req.head.published.row].data end
                return true, { head = head, data = data, parentId = req.parentId }
            end,
            stateOf = function() return { label = 'Brouillon', tone = 'draft' } end,
            footerOf = function() return {} end,
        }
        helper.load('modules/vava_atelier/server/placement.lua')
        placement = VavaAtelier.placement
    end)

    after_each(function()
        VavaAtelier, VavaGathering = nil, nil
    end)

    local function template(resource)
        return { s = { ressource = resource or 'chene' }, n = { charges = 3, repousse = 600 } }
    end

    local function poseNode(x, y, extra)
        local where = { x = x, y = y, z = 30.0, h = 15.0 }
        for k, v in pairs(extra or {}) do where[k] = v end
        return placement.place(ctx, '', 0, where, 'bois', template())
    end

    local function placeRefusal(ok, answer)
        assert.is_true(ok)
        assert.is_false(answer.done)
        assert.equal('place', answer.errors[1].field)
        return answer.errors[1].text
    end

    describe('refus de structure', function()
        it('refuse une porte et un type sans lieu (not_placeable)', function()
            editor.kinds.node.def.placement = 'door'
            assert.same({ false, 'not_placeable' }, { poseNode(110.0, 100.0) })
            editor.kinds.node.def.placement = nil
            assert.same({ false, 'not_placeable' }, { poseNode(110.0, 100.0) })
        end)

        it('refuse hors de l’instance du royaume et sans personnage présent', function()
            bucket = 3
            assert.same({ false, 'instance' }, { poseNode(110.0, 100.0) })
            bucket, position = 0, nil
            assert.same({ false, 'not_ready' }, { poseNode(110.0, 100.0) })
            assert.same({}, written)
        end)

        it('enfant nouveau : parent absent, inconnu, ou brouillon jamais publié d’un autre membre', function()
            assert.same({ false, 'parent_missing' }, { placement.place(ctx, '', 0, { x = 110.0, y = 100.0, z = 30.0, h = 0.0 },
                '', template()) })
            assert.same({ false, 'parent_missing' }, { placement.place(ctx, '', 0, { x = 110.0, y = 100.0, z = 30.0, h = 0.0 },
                'inconnu', template()) })
            heads['zone|bois'] = { kind = 'zone', id = 'bois', title = 'Bois', draft = { row = 1, rev = 1, holder = OTHER,
                status = 'draft' } }
            assert.same({ false, 'parent_missing' }, { poseNode(110.0, 100.0) })
        end)

        it('enfant nouveau d’une zone publiée dont un autre membre tient le brouillon : jugé à l’écriture', function()
            heads['zone|bois'].draft = { row = 2, rev = 1, holder = OTHER, status = 'draft' }
            rowsOf[2] = rowsOf[1]
            -- la tête du parent part à l'écriture, où lc.placePlan rend draft_taken (atelier_lifecycle_spec)
            local ok = poseNode(110.0, 100.0)
            assert.is_true(ok)
            assert.equal(1, #written)
            assert.equal(heads['zone|bois'], written[1].parentHead)
        end)

        it('fiche existante : des valeurs ou un autre parent sont une demande mal formée', function()
            heads['node|chene_1'] = { kind = 'node', id = 'chene_1', title = 'Chêne 1',
                published = { row = 10, version = 1, parent = 'bois' } }
            rowsOf[10] = { data = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
                place = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
            assert.same({ false, 'bad_request' }, { placement.place(ctx, 'chene_1', 0, { x = 112.0, y = 100.0, z = 30.0, h = 0.0 },
                '', template()) })
            assert.same({ false, 'bad_request' }, { placement.place(ctx, 'chene_1', 0, { x = 112.0, y = 100.0, z = 30.0, h = 0.0 },
                'autre_zone', {}) })
            assert.same({ false, 'unknown_entry' }, { placement.place(ctx, 'chene_9', 0, { x = 112.0, y = 100.0, z = 30.0,
                h = 0.0 }, '', {}) })
        end)

        it('zone sans parent : un parent nommé est une demande mal formée', function()
            ctx.kind = editor.kinds.zone
            assert.same({ false, 'bad_request' }, { placement.place(ctx, '', 0, { x = 100.0, y = 100.0, z = 30.0, r = 60.0 },
                'bois', { s = { nom = 'Bois Neuf' } }) })
        end)

        it('plafond de fiches vivantes du type : full', function()
            liveCount = VavaAtelier.config.definitions.perKind
            assert.same({ false, 'full' }, { poseNode(110.0, 100.0) })
        end)
    end)

    describe('refus de lieu (jamais cru du client)', function()
        it('lieu mal formé : clé d’une autre forme, nombre non fini', function()
            assert.truthy(placeRefusal(poseNode(110.0, 100.0, { r = 5.0 })):find('r', 1, true))
            assert.truthy(placeRefusal(poseNode(0 / 0, 100.0)))
            assert.same({}, written)
        end)

        it('portée : 59,9 m accepté, 60,1 m refusé, position lue par le serveur', function()
            position = { x = 100.0, y = 40.1, z = 30.0 }
            assert.equal('Trop loin de vous : approchez-vous (60 m).', placeRefusal(poseNode(100.0, 100.2)))
            position = { x = 100.0, y = 40.3, z = 30.0 }
            local ok, answer = poseNode(100.0, 100.2)
            assert.is_true(ok)
            assert.is_true(answer.done)
        end)

        it('hors de la zone (rayon + 5 m)', function()
            position = { x = 160.0, y = 100.0, z = 30.0 }
            assert.equal('Hors de Bois des Essais.', placeRefusal(poseNode(165.1, 100.0)))
            assert.is_true(select(2, poseNode(164.9, 100.0)).done)
        end)

        it('trop près d’un frère vivant (2 m), sauf d’un frère d’une autre zone ou retiré', function()
            rowsOf.children = { chene(1, 110.0, 100.0) }
            assert.equal('Trop près de « Chêne 1 » (1,5 m).', placeRefusal(poseNode(111.5, 100.0)))
            rowsOf.children[1].parent = 'autre'
            assert.is_true(select(2, poseNode(111.5, 100.0)).done)
            rowsOf.children = { chene(1, 110.0, 100.0, 'draft', ACCOUNT) }
            rowsOf.children[1].removal = 1
            assert.is_true(select(2, poseNode(111.5, 100.0)).done)
        end)

        it('refus du module (placeCheck) : son texte, borné', function()
            allowed = string.rep('x', 400)
            local text = placeRefusal(poseNode(110.0, 100.0))
            assert.is_true(#text <= 160)
        end)
    end)

    describe('pose réussie', function()
        it('enfant nouveau : valeurs du modèle, titre donné tout seul, ligne et parent rendus', function()
            rowsOf.children = { chene(1, 110.0, 100.0), chene(2, 120.0, 100.0) }
            local ok, answer = poseNode(130.0, 100.0)
            assert.is_true(ok)
            assert.is_true(answer.done)
            local req = written[1]
            assert.equal('Chêne 3', req.title)
            assert.same({ nom = 'Chêne 3', ressource = 'chene', charges = 3, repousse = 600 }, req.data)
            assert.equal('bois', req.parentId)
            assert.same({ x = 130.0, y = 100.0, z = 30.0, h = 15.0 }, req.where)
            assert.equal('Chêne 3', answer.row.title)
            assert.equal('new', answer.row.tone)
            assert.equal('3 récoltes', answer.row.hint)
            assert.same({ model = 'prop_tree_oak_01', label = 'chêne de GTA', provisional = true }, answer.row.look)
            assert.equal('bois', answer.parent.id)
            -- placeCheck voit l'enfant tel qu'il serait : nouveau, ses frères comptés avec lui
            assert.equal('', checked[1].ctx.id)
            assert.equal(3, checked[1].ctx.siblings)
            assert.equal('chene', checked[1].ctx.data.ressource)
        end)

        it('arrondit le lieu (centimètre, cap dans [0, 360))', function()
            local ok, answer = poseNode(110.123456, 100.0, { h = -15.04 })
            assert.is_true(ok)
            assert.same({ x = 110.12, y = 100.0, z = 30.0, h = 345.0 }, answer.place)
        end)

        it('fiche publiée déplacée : aucune valeur, le serveur relit la fiche', function()
            heads['node|chene_1'] = { kind = 'node', id = 'chene_1', title = 'Chêne 1',
                published = { row = 10, version = 1, parent = 'bois' } }
            rowsOf[10] = { data = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
                place = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
            rowsOf.children = { chene(1, 110.0, 100.0) }
            local ok, answer = placement.place(ctx, 'chene_1', 0, { x = 110.5, y = 100.0, z = 30.0, h = 0.0 }, '', {})
            assert.is_true(ok)
            assert.is_true(answer.done)
            -- la fiche elle-même n'est jamais son propre frère (0,5 m de son ancien lieu)
            assert.equal(heads['node|chene_1'], written[1].head)
            assert.equal('chene_1', checked[1].ctx.id)
            assert.equal(1, checked[1].ctx.siblings)
        end)

        it('zone : rayon hors des bornes du type refusé, dans les bornes accepté', function()
            ctx.kind = editor.kinds.zone
            heads['zone|bois'].draft = { row = 1, rev = 1, holder = ACCOUNT, status = 'draft' }
            assert.equal('Rayon de 10 à 300 m.', placeRefusal(placement.place(ctx, 'bois', 1,
                { x = 100.0, y = 100.0, z = 30.0, r = 9.0 }, '', {})))
            local ok, answer = placement.place(ctx, 'bois', 1, { x = 100.0, y = 100.0, z = 30.0, r = 80.0 }, '', {})
            assert.is_true(ok)
            assert.equal(80.0, answer.place.r)
            assert.equal('zone', checked[#checked].kind)
        end)
    end)

    describe('children', function()
        it('zone : son lieu et ses points (publiés, brouillons du membre, brouillons d’un autre), triés par titre', function()
            ctx.kind = editor.kinds.zone
            rowsOf.children = { chene(2, 120.0, 100.0), chene(1, 110.0, 100.0), chene(3, 130.0, 100.0, 'draft', ACCOUNT),
                chene(4, 140.0, 100.0, 'draft', OTHER) }
            local ok, answer = placement.children(ctx, 'bois')
            assert.is_true(ok)
            assert.same(ZONE_PLACE, answer.self.place)
            local titles, tones = {}, {}
            for i, row in ipairs(answer.rows) do titles[i], tones[i] = row.title, row.tone end
            assert.same({ 'Chêne 1', 'Chêne 2', 'Chêne 3', 'Chêne 4' }, titles)
            assert.same({ 'live', 'live', 'new', 'other' }, tones)
            -- un point publié a déjà son modèle en jeu : pas de fantôme
            assert.is_nil(answer.rows[1].look)
            assert.is_not_nil(answer.rows[3].look)
        end)

        it('point : son lieu, sa zone et ses frères', function()
            heads['node|chene_1'] = { kind = 'node', id = 'chene_1', title = 'Chêne 1',
                published = { row = 10, version = 1, parent = 'bois' } }
            rowsOf[10] = { data = { nom = 'Chêne 1', ressource = 'chene', charges = 3, repousse = 600 },
                place = { x = 110.0, y = 100.0, z = 30.0, h = 0.0 }, parent = 'bois' }
            rowsOf.children = { chene(1, 110.0, 100.0), chene(2, 120.0, 100.0) }
            local ok, answer = placement.children(ctx, 'chene_1')
            assert.is_true(ok)
            assert.same({ kind = 'zone', id = 'bois', title = 'Bois des Essais', place = ZONE_PLACE }, answer.parent)
            assert.equal(2, #answer.rows)
        end)

        it('ignore une ligne au lieu illisible et une fiche inconnue', function()
            ctx.kind = editor.kinds.zone
            rowsOf.children = { chene(1, 110.0, 100.0) }
            json[rowsOf.children[1].place] = { x = 'loin' }
            local _, answer = placement.children(ctx, 'bois')
            assert.same({}, answer.rows)
            assert.same({ false, 'unknown_entry' }, { placement.children(ctx, 'inconnue') })
        end)
    end)
end)
