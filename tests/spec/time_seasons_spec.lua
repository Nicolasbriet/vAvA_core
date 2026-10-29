local helper = require('tests.helper')

-- Effets des saisons de vava_time sur la croissance de vava_farming (shared/growth.lua).
describe('vava_farming croissance selon la saison', function()
    local growth, cfg

    before_each(function()
        helper.reset()
        VavaFarming = nil
        helper.loadAll({
            'modules/vava_farming/shared/constants.lua',
            'modules/vava_farming/config.lua',
            'modules/vava_farming/shared/growth.lua',
        })
        growth = VavaFarming.growth
        cfg = VavaFarming.config
    end)

    -- culture d'essai : une heure de pousse, la terre perd 10 points d'humidité par heure
    local CROP = { id = 'essai', growMinutes = 60, waterPerHour = 10, stages = { 'a', 'b' } }

    local function planted()
        return {
            crop = 'essai', seedTier = 1, plantedAt = 0, growth = 0, moisture = 100, fertility = 80, drySince = nil,
            dryHours = 0, waterings = 0, wilted = false, dead = false, updatedAt = 0,
        }
    end

    --- Avance de `seconds` par pas de `step` secondes (la boucle du serveur relit toutes les 10 s).
    local function run(slot, seconds, step, season)
        for now = step, seconds, step do growth.advance(slot, CROP, now, season) end
        return slot
    end

    it('pousse comme avant sans saison (vava_time absent)', function()
        local slot = run(planted(), 600, 10, nil)
        assert.equal(600, slot.growth)
        assert.equal(math.type(slot.growth), 'integer')
        assert.near(100 - 10 * 600 / 3600, slot.moisture, 1e-9)
    end)

    it('ralentit l\'hiver sans rien perdre aux arrondis', function()
        local slot = run(planted(), 3600, 10, { growth = 0.25, drying = 0.5 })
        assert.near(900, slot.growth, 1e-6)
        assert.near(95, slot.moisture, 1e-9)
        assert.is_false(slot.wilted)
    end)

    it('fait sécher la terre plus vite l\'été', function()
        local slot = run(planted(), 3600, 10, { growth = 1.0, drying = 1.5 })
        assert.near(85, slot.moisture, 1e-9)
        assert.near(3600, slot.growth, 1e-6)
    end)

    it('arrête la pousse à 0 et garde la terre humide si elle ne sèche plus', function()
        local slot = run(planted(), 3600, 10, { growth = 0, drying = 0 })
        assert.equal(0, slot.growth)
        assert.equal(100, slot.moisture)
        assert.equal(0, slot.dryHours)
    end)

    it('ne pousse plus une fois la terre sous le seuil, saison ou non', function()
        local slot = planted()
        slot.moisture = cfg.growth.moistureThreshold + 1
        -- 1 point d'humidité à perdre à 10/h × 2 (été très sec) : 180 s de pousse, puis plus rien
        run(slot, 600, 10, { growth = 1, drying = 2 })
        assert.near(180, slot.growth, 1e-6)
    end)

    it('donne les réglages de saison attendus dans la config', function()
        for _, season in ipairs({ 'printemps', 'ete', 'automne', 'hiver' }) do
            assert.is_number(cfg.seasons[season].growth)
            assert.is_number(cfg.seasons[season].drying)
        end
        assert.is_true(cfg.seasons.hiver.growth < cfg.seasons.printemps.growth)
        assert.is_true(cfg.seasons.ete.drying > cfg.seasons.hiver.drying)
    end)
end)

-- Effets des saisons sur la récolte de vava_gathering (server/nodes.lua, server/quality.lua) : facteur fourni par le
-- bridge, doublé ici.
describe('vava_gathering repousse et rendement selon la saison', function()
    local nodes, quality, factor

    before_each(function()
        helper.reset()
        VavaGathering = nil
        GlobalState = {}
        factor = 1
        helper.loadAll({ 'modules/vava_gathering/shared/constants.lua', 'modules/vava_gathering/config.lua' })
        VavaGathering.bridge = { SeasonFactor = function() return factor end }
        VavaGathering.catalog = {}
        helper.loadAll({ 'modules/vava_gathering/server/nodes.lua', 'modules/vava_gathering/server/quality.lua' })
        nodes, quality = VavaGathering.nodes, VavaGathering.quality
    end)

    after_each(function()
        GlobalState = nil
    end)

    -- nœud de 4 charges, une rendue toutes les 10 min
    local DEF = { id = 'essai', charges = 4, regenMs = 600000, resource = { skill = 'herboristerie' } }

    it('rend les charges comme avant sans saison', function()
        local state = { charges = 0, updatedAt = 1000 }
        nodes.refresh(DEF, state, 1000 + 1500)
        assert.same({ 2, 1000 + 1200 }, { state.charges, state.updatedAt })
        nodes.refresh(DEF, state, 1000 + 3000)
        assert.same({ 4, 1000 + 3000 }, { state.charges, state.updatedAt })
    end)

    it('ralentit la repousse en hiver et garde le reste du délai', function()
        factor = 0.25
        local state = { charges = 0, updatedAt = 1000 }
        nodes.refresh(DEF, state, 1000 + 1500)
        assert.equal(0, state.charges)
        nodes.refresh(DEF, state, 1000 + 2500)
        assert.same({ 1, 1000 + 2400 }, { state.charges, state.updatedAt })
    end)

    it('n\'accumule rien quand rien ne repousse, puis repart de zéro', function()
        factor = 0
        local state = { charges = 1, updatedAt = 1000 }
        nodes.refresh(DEF, state, 1000 + 86400)
        assert.same({ 1, 1000 + 86400 }, { state.charges, state.updatedAt })
        factor = 1
        nodes.refresh(DEF, state, 1000 + 86400 + 599)
        assert.equal(1, state.charges)
        nodes.refresh(DEF, state, 1000 + 86400 + 600)
        assert.equal(2, state.charges)
    end)

    it('multiplie le rendement, au moins une unité', function()
        local resource = { yield = { 2, 2 } }
        local effects = { yield = 1.0 }
        assert.equal(2, quality.yield(resource, nil, effects))
        assert.equal(1, quality.yield(resource, nil, effects, 0.5))
        assert.equal(3, quality.yield(resource, nil, effects, 1.25))
        assert.equal(1, quality.yield(resource, nil, { yield = 0.2 }, 0.5))
    end)

    it('règle la récolte par saison sans toucher au minage', function()
        local seasons = VavaGathering.config.seasons
        for _, kind in ipairs({ 'regen', 'yield' }) do
            for _, bySkill in pairs(seasons[kind]) do assert.is_nil(bySkill.minage) end
        end
        assert.is_true(seasons.regen.hiver.herboristerie < 1)
    end)
end)
