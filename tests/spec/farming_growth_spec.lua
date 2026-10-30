local helper = require('tests.helper')

-- Croissance, fertilité et qualité (modules/vava_farming/shared/growth.lua), grille des parcelles
-- (modules/vava_farming/shared/geometry.lua). Valeurs documentées : README du module, tableau « Règles » :
--   croissance : pousse si humidité > 20 ; à sec : pause, flétrie après 6 h, morte après 18 h ; arroser une flétrie la
--   fait repartir ;
--   fertilité : 80 au départ ; − coût de la culture par récolte ; même famille − 10, famille différente + 10 ;
--   compost + 25 ; jachère + 10 par jour vide ;
--   qualité : graine × 0,35 + compétence × 0,35 + régularité × 0,15 + fertilité × 0,15 ± 5 → paliers 20 / 40 / 60 / 85 ;
--   régularité : 100 − 100 × heures de sécheresse ÷ durée de croissance ;
--   cultures de départ : blé 90 min, carotte 30, chou 45, lin 60.

local HOUR, DAY = 3600, 86400

describe('vava_farming growth', function()
    local growth, cfg, STATES

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_farming/shared/constants.lua',
            'modules/vava_farming/config.lua',
            'modules/vava_farming/shared/geometry.lua',
            'modules/vava_farming/shared/growth.lua',
        })
        growth = VavaFarming.growth
        cfg = VavaFarming.config
        STATES = VavaFarming.STATES
    end)

    --- Emplacement planté à l'instant 0 (mêmes champs que slots.plant côté serveur), humidité au choix.
    local function slotOf(cropId, moisture)
        return {
            crop = cropId, seedTier = 1, plantedAt = 0, growth = 0, moisture = moisture, fertility = 80,
            drySince = nil, dryHours = 0, waterings = 0, wilted = false, dead = false, lastFamily = nil, updatedAt = 0,
        }
    end

    --- Culture d'essai à croissance longue (10 h), pour voir la pause et la reprise.
    local function longCrop()
        return { id = 'essai', family = 'essai', growMinutes = 600, waterPerHour = 20, fertilityCost = 0, stages = { 'a', 'b' } }
    end

    local function copy(t)
        local out = {}
        for k, v in pairs(t) do out[k] = v end
        return out
    end

    describe('réglages documentés', function()
        it('reprend les règles du README', function()
            assert.equal(20, cfg.growth.moistureThreshold)
            assert.equal(6, cfg.growth.wiltAfterHours)
            assert.equal(18, cfg.growth.dieAfterHours)
            assert.equal(80, cfg.fertility.initial)
            assert.equal(25, cfg.fertility.compostBonus)
            assert.equal(10, cfg.fertility.fallowPerDay)
            assert.equal(10, cfg.fertility.rotationBonus)
            assert.equal(10, cfg.fertility.sameFamilyPenalty)
            assert.same({ seed = 0.35, skill = 0.35, watering = 0.15, fertility = 0.15 }, cfg.quality.weights)
            assert.equal(5, cfg.quality.jitter)
            assert.same({ 20, 40, 60, 85 }, cfg.quality.tiers)
        end)

        it('donne aux cultures de départ les durées du README : blé 90 min, carotte 30, chou 45, lin 60', function()
            assert.equal(90, cfg.crops.ble.growMinutes)
            assert.equal(30, cfg.crops.carotte.growMinutes)
            assert.equal(45, cfg.crops.chou.growMinutes)
            assert.equal(60, cfg.crops.lin.growMinutes)
        end)
    end)

    describe('croissance', function()
        it('pousse tant que la terre est humide et boit waterPerHour points d’humidité par heure', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 100)
            growth.advance(slot, crop, HOUR)
            assert.equal(HOUR, slot.growth)
            assert.is_near(80, slot.moisture, 1e-9)
            assert.equal(HOUR, slot.updatedAt)
            assert.equal(0, slot.dryHours)
            assert.is_nil(slot.drySince)
        end)

        it('mûrit après growMinutes de terre humide (blé : 90 min)', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 100)
            growth.advance(slot, crop, 89 * 60)
            assert.equal(STATES.GROWING, growth.state(slot, crop))
            growth.advance(slot, crop, 90 * 60)
            assert.equal(90 * 60, slot.growth)
            assert.equal(1, growth.progress(slot, crop))
            assert.equal(STATES.RIPE, growth.state(slot, crop))
        end)

        it('plafonne la croissance à la durée de la culture', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 100)
            growth.advance(slot, crop, 3 * HOUR)
            assert.equal(90 * 60, slot.growth)
        end)

        it('ne pousse pas quand l’humidité vaut exactement le seuil (20) : il faut la dépasser', function()
            local slot = slotOf('essai', 20)
            growth.advance(slot, longCrop(), HOUR)
            assert.equal(0, slot.growth)
            assert.equal(0, slot.moisture)
            assert.is_near(1, slot.dryHours, 1e-9)
        end)

        it('marque une pause à sec : la croissance s’arrête sous le seuil et la sécheresse se compte', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)             -- 40 points au-dessus du seuil : 2 h de terre humide
            growth.advance(slot, crop, 2 * HOUR)
            assert.equal(2 * HOUR, slot.growth)
            assert.is_near(20, slot.moisture, 1e-9)
            growth.advance(slot, crop, 5 * HOUR)
            assert.equal(2 * HOUR, slot.growth)
            assert.equal(0, slot.moisture)
            assert.is_near(3, slot.dryHours, 1e-9)
            assert.equal(STATES.GROWING, growth.state(slot, crop))
        end)

        it('sépare la part humide et la part sèche d’un long intervalle calculé en une fois', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)
            growth.advance(slot, crop, 3 * HOUR)
            assert.equal(2 * HOUR, slot.growth)
            assert.is_near(1, slot.dryHours, 1e-9)
            assert.equal(2 * HOUR, slot.drySince)
        end)

        it('flétrit après 6 h de sécheresse continue', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)             -- sèche à partir de 2 h
            growth.advance(slot, crop, 8 * HOUR - 1)
            assert.is_false(slot.wilted)
            assert.equal(STATES.GROWING, growth.state(slot, crop))
            growth.advance(slot, crop, 8 * HOUR)
            assert.is_true(slot.wilted)
            assert.is_false(slot.dead)
            assert.equal(STATES.WILTED, growth.state(slot, crop))
        end)

        it('meurt après 18 h de sécheresse continue', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)             -- sèche à partir de 2 h
            growth.advance(slot, crop, 20 * HOUR - 1)
            assert.is_false(slot.dead)
            assert.equal(STATES.WILTED, growth.state(slot, crop))
            growth.advance(slot, crop, 20 * HOUR)
            assert.is_true(slot.dead)
            assert.equal(STATES.DEAD, growth.state(slot, crop))
        end)

        it('flétrit et meurt aux mêmes heures, calculé en une fois ou heure par heure', function()
            local crop = longCrop()
            local once, hourly = slotOf('essai', 60), slotOf('essai', 60)
            growth.advance(once, crop, 9 * HOUR)
            for hour = 1, 9 do growth.advance(hourly, crop, hour * HOUR) end
            assert.is_true(once.wilted)
            assert.is_true(hourly.wilted)
            assert.equal(once.drySince, hourly.drySince)
            assert.is_near(once.growth, hourly.growth, 1)
            assert.is_near(7, once.dryHours, 1e-9)
            assert.is_near(once.dryHours, hourly.dryHours, 1e-9)
            growth.advance(once, crop, 25 * HOUR)
            for hour = 10, 25 do growth.advance(hourly, crop, hour * HOUR) end
            assert.is_true(once.dead)
            assert.is_true(hourly.dead)
            assert.equal(once.growth, hourly.growth)
        end)

        it('arrête de compter les heures sèches à la mort, calculé en une fois ou heure par heure', function()
            local crop = longCrop()
            local once, hourly = slotOf('essai', 60), slotOf('essai', 60)   -- sèches dès 2 h, mortes à 20 h
            growth.advance(once, crop, 25 * HOUR)
            for hour = 1, 25 do growth.advance(hourly, crop, hour * HOUR) end
            assert.is_true(once.dead)
            assert.is_true(hourly.dead)
            assert.is_near(18, once.dryHours, 1e-9)
            assert.is_near(once.dryHours, hourly.dryHours, 1e-9)
            -- morte, elle ne compte plus rien
            growth.advance(once, crop, 40 * HOUR)
            assert.is_near(18, once.dryHours, 1e-9)
        end)

        it('une plante flétrie ne pousse plus', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)
            growth.advance(slot, crop, 8 * HOUR)
            assert.is_true(slot.wilted)
            local grown = slot.growth
            growth.advance(slot, crop, 10 * HOUR)
            assert.equal(grown, slot.growth)
        end)

        it('arroser remet l’humidité à 100 et fait repartir une plante flétrie', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)
            growth.advance(slot, crop, 9 * HOUR)
            assert.is_true(slot.wilted)
            local grown = slot.growth
            growth.water(slot)
            assert.equal(100, slot.moisture)
            assert.is_false(slot.wilted)
            assert.is_nil(slot.drySince)
            assert.equal(1, slot.waterings)
            assert.equal(STATES.GROWING, growth.state(slot, crop))
            growth.advance(slot, crop, 10 * HOUR)
            assert.equal(grown + HOUR, slot.growth)
        end)

        it('arroser ne ressuscite pas une plante morte, que le temps ne touche plus', function()
            local crop = longCrop()
            local slot = slotOf('essai', 60)
            growth.advance(slot, crop, 20 * HOUR)
            assert.is_true(slot.dead)
            growth.water(slot)
            assert.equal(STATES.DEAD, growth.state(slot, crop))
            local before = copy(slot)
            growth.advance(slot, crop, 30 * HOUR)
            assert.equal(30 * HOUR, slot.updatedAt)
            before.updatedAt = 30 * HOUR
            assert.same(before, slot)
        end)

        it('ne change rien quand le temps n’a pas avancé ou a reculé', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 60)
            slot.updatedAt = 1000
            local before = copy(slot)
            growth.advance(slot, crop, 1000)
            assert.same(before, slot)
            growth.advance(slot, crop, 500)
            assert.same(before, slot)
        end)
    end)

    describe('jachère', function()
        it('rend 10 points de fertilité par jour vide', function()
            local slot = slotOf(nil, 0)
            slot.fertility = 50
            growth.advance(slot, nil, DAY)
            assert.is_near(60, slot.fertility, 1e-9)
            growth.advance(slot, nil, DAY + DAY / 2)
            assert.is_near(65, slot.fertility, 1e-9)
            assert.equal(DAY + DAY / 2, slot.updatedAt)
        end)

        it('ne dépasse pas 100', function()
            local slot = slotOf(nil, 0)
            slot.fertility = 95
            growth.advance(slot, nil, 3 * DAY)
            assert.equal(100, slot.fertility)
        end)

        it('ne rend rien à un emplacement planté', function()
            local slot = slotOf('ble', 100)
            growth.advance(slot, cfg.crops.ble, DAY)
            assert.equal(80, slot.fertility)
        end)
    end)

    describe('avancement, stade et état', function()
        it('rend l’avancement de 0 à 1, sans le dépasser', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 60)
            assert.equal(0, growth.progress(slot, crop))
            slot.growth = 45 * 60
            assert.equal(0.5, growth.progress(slot, crop))
            slot.growth = 10 * HOUR
            assert.equal(1, growth.progress(slot, crop))
        end)

        it('compte une culture sans durée comme mûre', function()
            local slot = slotOf('essai', 60)
            assert.equal(1, growth.progress(slot, { growMinutes = 0, stages = {} }))
        end)

        it('donne un stade de 1 à #stages : le premier au semis, le dernier réservé à la plante mûre', function()
            local crop = cfg.crops.ble               -- trois stades : semis, pousse, mûr
            local slot = slotOf('ble', 60)
            slot.growth = 0
            assert.equal(1, growth.stage(slot, crop))
            slot.growth = 44 * 60
            assert.equal(1, growth.stage(slot, crop))
            slot.growth = 45 * 60
            assert.equal(2, growth.stage(slot, crop))
            slot.growth = 89 * 60
            assert.equal(2, growth.stage(slot, crop))   -- le dernier modèle attend la maturité
            slot.growth = 90 * 60
            assert.equal(3, growth.stage(slot, crop))
            local carrot = cfg.crops.carotte         -- deux stades : semis, puis mûr
            slot.growth = 0
            assert.equal(1, growth.stage(slot, carrot))
            slot.growth = 29 * 60
            assert.equal(1, growth.stage(slot, carrot))
            slot.growth = 30 * 60
            assert.equal(2, growth.stage(slot, carrot))
        end)

        it('affiche toujours l’unique modèle d’une culture à un seul stade', function()
            local slot = slotOf('essai', 60)
            local crop = { growMinutes = 10, stages = { 'seul' } }
            assert.equal(1, growth.stage(slot, crop))
            slot.growth = 10 * 60
            assert.equal(1, growth.stage(slot, crop))
        end)

        it('ne fait jamais reculer le stade quand la plante pousse', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 60)
            local previous = 1
            for minute = 0, 90 do
                slot.growth = minute * 60
                local stage = growth.stage(slot, crop)
                assert.is_true(stage >= previous and stage <= #crop.stages, 'minute ' .. minute)
                previous = stage
            end
        end)

        it('donne le stade 0 à une culture sans stade', function()
            local slot = slotOf('essai', 60)
            assert.equal(0, growth.stage(slot, { growMinutes = 10, stages = {} }))
        end)

        it('fait primer morte sur flétrie, flétrie sur mûre', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 60)
            slot.growth = 90 * 60
            assert.equal(STATES.RIPE, growth.state(slot, crop))
            slot.wilted = true
            assert.equal(STATES.WILTED, growth.state(slot, crop))
            slot.dead = true
            assert.equal(STATES.DEAD, growth.state(slot, crop))
        end)
    end)

    describe('régularité d’arrosage', function()
        it('suit 100 − 100 × heures de sécheresse ÷ durée de croissance (blé : 1,5 h)', function()
            local crop = cfg.crops.ble
            local slot = slotOf('ble', 60)
            assert.equal(100, growth.regularity(slot, crop))
            slot.dryHours = 0.75
            assert.is_near(50, growth.regularity(slot, crop), 1e-9)
            slot.dryHours = 0.3
            assert.is_near(80, growth.regularity(slot, crop), 1e-9)
        end)

        it('ne descend pas sous 0', function()
            local slot = slotOf('ble', 60)
            slot.dryHours = 3
            assert.equal(0, growth.regularity(slot, cfg.crops.ble))
        end)

        it('vaut 100 pour une culture sans durée', function()
            local slot = slotOf('essai', 60)
            slot.dryHours = 5
            assert.equal(100, growth.regularity(slot, { growMinutes = 0 }))
        end)
    end)

    describe('qualité de la récolte', function()
        it('suit la formule documentée : graine × 0,35 + compétence × 0,35 + régularité × 0,15 + fertilité × 0,15', function()
            -- graine de palier 3 (50) : 17,5 + 17,5 + 15 + 12 = 62
            assert.equal(62, growth.quality(3, 50, 100, 80, 0))
            -- tout au mieux : 92 × 0,35 + 35 + 15 + 15 = 97,2
            assert.equal(97, growth.quality(5, 100, 100, 100, 0))
        end)

        it('donne aux paliers de graine la qualité 10, 30, 50, 72, 92', function()
            assert.same({ 10, 30, 50, 72, 92 }, cfg.quality.materialQuality)
            -- seule la graine change : l'écart entre deux paliers vaut 0,35 × l'écart de qualité
            assert.equal(7, growth.quality(2, 0, 0, 0, 0) - growth.quality(1, 0, 0, 0, 0))   -- 10,5 − 3,5
        end)

        it('ajoute l’aléa et borne la qualité entre 0 et 100', function()
            assert.equal(100, growth.quality(5, 100, 100, 100, 5))
            assert.equal(92, growth.quality(5, 100, 100, 100, -5))
            assert.equal(0, growth.quality(1, 0, 0, 0, -5))
        end)

        it('ramène un palier de graine hors bornes dans 1 à 5', function()
            assert.equal(growth.quality(1, 40, 50, 50, 0), growth.quality(0, 40, 50, 50, 0))
            assert.equal(growth.quality(5, 40, 50, 50, 0), growth.quality(9, 40, 50, 50, 0))
        end)

        it('rend un entier', function()
            assert.equal('integer', math.type(growth.quality(3, 50, 100, 80, 0)))
        end)

        it('place les paliers à 20 / 40 / 60 / 85', function()
            assert.equal(1, growth.tierOf(19))
            assert.equal(2, growth.tierOf(20))
            assert.equal(2, growth.tierOf(39))
            assert.equal(3, growth.tierOf(40))
            assert.equal(4, growth.tierOf(60))
            assert.equal(4, growth.tierOf(84))
            assert.equal(5, growth.tierOf(85))
            assert.equal(5, growth.tierOf(100))
        end)
    end)

    describe('fertilité après récolte', function()
        it('première récolte : seulement le coût de la culture (blé : 80 → 65)', function()
            assert.equal(65, growth.fertilityAfterHarvest(80, cfg.crops.ble, nil))
        end)

        it('même famille : coût − 10 (blé après blé : 65 → 40)', function()
            assert.equal(40, growth.fertilityAfterHarvest(65, cfg.crops.ble, 'cereale'))
        end)

        it('famille différente : coût + 10 (carotte après blé : 40 → 40)', function()
            assert.equal(40, growth.fertilityAfterHarvest(40, cfg.crops.carotte, 'cereale'))
            assert.equal(78, growth.fertilityAfterHarvest(80, cfg.crops.chou, 'racine'))       -- 80 − 12 + 10
        end)

        it('reste entre 0 et 100', function()
            assert.equal(0, growth.fertilityAfterHarvest(5, cfg.crops.ble, 'cereale'))
            assert.equal(100, growth.fertilityAfterHarvest(98, longCrop(), 'autre'))            -- 98 − 0 + 10
        end)
    end)
end)

describe('vava_farming geometry', function()
    local geometry, cfg

    before_each(function()
        helper.reset()
        helper.loadAll({
            'modules/vava_farming/shared/constants.lua',
            'modules/vava_farming/config.lua',
            'modules/vava_farming/shared/geometry.lua',
        })
        geometry = VavaFarming.geometry
        cfg = VavaFarming.config
    end)

    local function parcel(heading, rows, cols)
        return { x = 100.0, y = 200.0, z = 30.0, heading = heading, rows = rows or 3, cols = cols or 4, spacing = 1.6 }
    end

    local function near(expectedX, expectedY, x, y)
        assert.is_near(expectedX, x, 1e-9)
        assert.is_near(expectedY, y, 1e-9)
    end

    it('compte lignes × colonnes emplacements (champ communal 12, jardin privé 6)', function()
        assert.equal(12, geometry.slotCount(cfg.parcels[1]))
        assert.equal(6, geometry.slotCount(cfg.parcels[2]))
    end)

    it('chaque parcelle de la config tient dans la borne du protocole (MAX_SLOTS)', function()
        for _, entry in ipairs(cfg.parcels) do
            assert.is_true(geometry.slotCount(entry) <= VavaFarming.MAX_SLOTS, entry.id)
        end
    end)

    it('range les emplacements ligne par ligne, grille centrée sur la parcelle (cap 0)', function()
        local p = parcel(0)
        local x, y, z = geometry.slotPosition(p, 1)
        near(100 - 2.4, 200 - 1.6, x, y)
        assert.equal(30.0, z)
        x, y = geometry.slotPosition(p, 2)
        near(100 - 0.8, 200 - 1.6, x, y)
        x, y = geometry.slotPosition(p, 4)
        near(100 + 2.4, 200 - 1.6, x, y)
        x, y = geometry.slotPosition(p, 5)
        near(100 - 2.4, 200, x, y)
        x, y = geometry.slotPosition(p, 12)
        near(100 + 2.4, 200 + 1.6, x, y)
    end)

    it('garde le centre de la grille au centre de la parcelle, quel que soit le cap', function()
        for _, heading in ipairs({ 0, 30, 90, 217.5 }) do
            local p = parcel(heading)
            local sumX, sumY = 0, 0
            for index = 1, geometry.slotCount(p) do
                local x, y = geometry.slotPosition(p, index)
                sumX, sumY = sumX + x, sumY + y
            end
            near(p.x, p.y, sumX / 12, sumY / 12)
        end
    end)

    it('garde l’espacement entre voisins après rotation', function()
        local p = parcel(30)
        local x1, y1, z1 = geometry.slotPosition(p, 1)
        local x2, y2, z2 = geometry.slotPosition(p, 2)
        local x5, y5, z5 = geometry.slotPosition(p, 5)
        assert.is_near(1.6, geometry.distance(x1, y1, z1, x2, y2, z2), 1e-9)
        assert.is_near(1.6, geometry.distance(x1, y1, z1, x5, y5, z5), 1e-9)
    end)

    it('tourne la grille de son cap : à 90°, une ligne s’aligne sur l’axe y ; à 180°, la grille se retourne', function()
        local row = parcel(90, 1, 2)
        local x, y = geometry.slotPosition(row, 1)
        near(100, 200 - 0.8, x, y)
        x, y = geometry.slotPosition(row, 2)
        near(100, 200 + 0.8, x, y)
        local flipped = parcel(180)
        x, y = geometry.slotPosition(flipped, 1)
        near(100 + 2.4, 200 + 1.6, x, y)
    end)

    it('prend un cap absent pour 0', function()
        local p = parcel(nil)
        local x, y = geometry.slotPosition(p, 1)
        near(100 - 2.4, 200 - 1.6, x, y)
    end)

    it('mesure une distance en 3D', function()
        assert.equal(5, geometry.distance(0, 0, 0, 3, 4, 0))
        assert.equal(3, geometry.distance(1, 1, 1, 2, 3, 3))
        assert.equal(0, geometry.distance(7, 8, 9, 7, 8, 9))
    end)

    it('compte un point posé sur le bord comme à portée, pas un point au-delà', function()
        assert.is_true(geometry.within(3, 4, 0, 0, 0, 0, 5))
        assert.is_false(geometry.within(3, 4.01, 0, 0, 0, 0, 5))
        assert.is_true(geometry.within(0, 0, 0, 0, 0, 0, 0))
        assert.is_false(geometry.within(0, 0, 3, 0, 0, 0, 2.5))     -- la hauteur compte
    end)
end)
