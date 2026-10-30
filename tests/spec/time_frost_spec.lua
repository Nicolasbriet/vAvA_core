local helper = require('tests.helper')

local function fixed(value)
    return function() return value end
end

describe('vava_time nuits de gel', function()
    local rules, cfg

    before_each(function()
        helper.reset()
        VavaTime = nil
        helper.loadAll({
            'modules/vava_time/shared/constants.lua',
            'modules/vava_time/config.lua',
            'modules/vava_time/shared/frost.lua',
        })
        rules = VavaTime.frostRules
        cfg = VavaTime.config.frost
    end)

    it('ne gèle qu\'en hiver, selon la probabilité de la config', function()
        assert.is_true(rules.chance('hiver') > 0)
        for _, season in ipairs({ 'printemps', 'ete', 'automne' }) do
            assert.equal(0, rules.chance(season))
            assert.is_false(rules.night(season, 1, false, fixed(0)).frosty)
        end
        assert.is_true(rules.night('hiver', 1, false, fixed(0)).frosty)
        assert.is_false(rules.night('hiver', 1, false, fixed(0.999)).frosty)
        assert.equal(0, rules.chance(nil))
    end)

    it('borne et ignore un réglage invalide', function()
        assert.equal(1, rules.chance('hiver', { seasons = { hiver = 3 } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = 0 / 0 } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = 'souvent' } }))
        assert.equal(0, rules.chance('hiver', { seasons = { hiver = -1 } }))
    end)

    it('avertit au soir puis fait tomber le gel à la tombée de la nuit, une seule fois chacun', function()
        local night = rules.night('hiver', 0, false, fixed(0))
        assert.same({ false, false }, { rules.due(night, cfg.warnHour - 0.01) })
        assert.same({ true, false }, { rules.due(night, cfg.warnHour) })
        assert.same({ false, false }, { rules.due(night, cfg.warnHour + 1) })
        assert.same({ false, true }, { rules.due(night, cfg.hour) })
        assert.same({ false, false }, { rules.due(night, 23.9) })
    end)

    it('rend les deux moments ensemble quand l\'heure saute au-delà du gel', function()
        local night = rules.night('hiver', 10, false, fixed(0))
        assert.same({ true, true }, { rules.due(night, cfg.hour + 0.5) })
    end)

    it('ne rejoue rien de ce qui était passé au démarrage', function()
        local late = rules.night('hiver', cfg.hour + 1, true, fixed(0))
        assert.same({ false, false }, { rules.due(late, cfg.hour + 1) })
        local evening = rules.night('hiver', cfg.warnHour + 1, true, fixed(0))
        assert.same({ false, true }, { rules.due(evening, cfg.hour) })
    end)

    it('ne fait rien une nuit sans gel', function()
        local night = rules.night('hiver', 0, false, fixed(0.999))
        assert.same({ false, false }, { rules.due(night, 23) })
    end)

    it('annonce la nuit de gel dès son tirage, avertissement passé compris, jusqu\'à ce que le gel tombe', function()
        local night = rules.night('hiver', 0, false, fixed(0))
        assert.is_true(rules.announced(night))
        rules.due(night, cfg.warnHour)
        assert.is_true(rules.announced(night))
        rules.due(night, cfg.hour)
        assert.is_false(rules.announced(night))
    end)

    it('annonce aussi la nuit de gel au joueur arrivé après le soir, pas une nuit sans gel', function()
        -- démarrage entre le soir et le gel : l'avertissement ne se rejoue pas, mais la nuit reste annoncée
        local evening = rules.night('hiver', cfg.warnHour + 1, true, fixed(0))
        rules.due(evening, cfg.warnHour + 1)
        assert.is_true(rules.announced(evening))
        -- démarrage après le gel : rien à annoncer
        local late = rules.night('hiver', cfg.hour + 1, true, fixed(0))
        assert.is_false(rules.announced(late))
        assert.is_false(rules.announced(rules.night('hiver', 0, false, fixed(0.999))))
        assert.is_false(rules.announced(rules.night('ete', 0, false, fixed(0))))
        assert.is_false(rules.announced(nil))
    end)

    it('garde les réglages décidés : hiver seulement, 0,4, soir à 17 h, gel à 21 h', function()
        assert.equal(0.4, rules.chance('hiver'))
        assert.equal(17, cfg.warnHour)
        assert.equal(21, cfg.hour)
    end)
end)

-- Le gel dans l'agriculture (modules/vava_farming/shared/growth.lua) : plante qu'il tue, objet qui couvre.
describe('vava_farming gel des cultures', function()
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

    local FRAGILE = { id = 'ble', frostHardy = false }
    local HARDY = { id = 'chou', frostHardy = true }

    local function slotOf(crop, fields)
        local slot = { crop = crop and crop.id or nil, dead = false, covered = false }
        for key, value in pairs(fields or {}) do slot[key] = value end
        return slot
    end

    it('tue une plante vivante ni couverte ni résistante, flétrie ou mûre comprise', function()
        assert.is_true(growth.frostKills(slotOf(FRAGILE), FRAGILE))
        assert.is_true(growth.frostKills(slotOf(FRAGILE, { wilted = true }), FRAGILE))
        assert.is_true(growth.frostKills(slotOf(FRAGILE, { growth = 5400 }), FRAGILE))
    end)

    it('épargne la plante couverte, la culture qui résiste au froid, la plante déjà morte et la terre vide', function()
        assert.is_false(growth.frostKills(slotOf(FRAGILE, { covered = true }), FRAGILE))
        assert.is_false(growth.frostKills(slotOf(HARDY), HARDY))
        assert.is_false(growth.frostKills(slotOf(FRAGILE, { dead = true }), FRAGILE))
        assert.is_false(growth.frostKills(slotOf(nil), nil))
        -- culture retirée de la config : rien à tuer
        assert.is_false(growth.frostKills(slotOf(FRAGILE), nil))
    end)

    it('fait du chou la seule culture qui résiste au froid dans la config', function()
        assert.is_true(cfg.crops.chou.frostHardy)
        for id, crop in pairs(cfg.crops) do
            if id ~= 'chou' then assert.is_not_true(crop.frostHardy) end
        end
    end)

    it('couvre avec le premier objet de la liste que le cultivateur a en quantité suffisante', function()
        local options = { { item = 'paille', quantity = 2 }, { item = 'compost', quantity = 1 } }
        local besace = { paille = 1, compost = 3 }
        local function countOf(item) return besace[item] or 0 end
        assert.equal('compost', growth.coverOption(options, countOf).item)
        besace.paille = 2
        assert.equal('paille', growth.coverOption(options, countOf).item)
        besace.paille, besace.compost = 0, 0
        assert.is_nil(growth.coverOption(options, countOf))
        assert.is_nil(growth.coverOption({}, countOf))
    end)

    it('couvre d\'abord avec deux déchets végétaux, le compost en secours (décision du 30 octobre 2026)', function()
        local cover = cfg.frost.cover
        assert.equal(2, #cover)
        assert.same({ item = cfg.compost.waste.item, quantity = 2 }, cover[1])
        assert.equal('dechets_vegetaux', cover[1].item)
        assert.same({ item = cfg.compost.item, quantity = 1 }, cover[2])
        assert.is_table(cfg.items[cover[1].item])
        assert.is_table(cfg.items[cover[2].item])
    end)

    it('choisit l\'objet qui couvre dans l\'ordre de la config : déchets, compost, ou rien', function()
        local besace = {}
        local function countOf(item) return besace[item] or 0 end
        local cover = cfg.frost.cover
        besace = { dechets_vegetaux = 5, compost = 3 }
        assert.same({ item = 'dechets_vegetaux', quantity = 2 }, growth.coverOption(cover, countOf))
        besace = { dechets_vegetaux = 2, compost = 0 }
        assert.same({ item = 'dechets_vegetaux', quantity = 2 }, growth.coverOption(cover, countOf))
        -- un seul déchet ne suffit pas : le compost prend le relais
        besace = { dechets_vegetaux = 1, compost = 1 }
        assert.same({ item = 'compost', quantity = 1 }, growth.coverOption(cover, countOf))
        besace = { compost = 4 }
        assert.same({ item = 'compost', quantity = 1 }, growth.coverOption(cover, countOf))
        besace = { dechets_vegetaux = 1 }
        assert.is_nil(growth.coverOption(cover, countOf))
        besace = {}
        assert.is_nil(growth.coverOption(cover, countOf))
    end)

    it('ne couvre qu\'en automne et en hiver', function()
        local allowed = cfg.frost.coverSeasons
        assert.same({ 'automne', 'hiver' }, allowed)
        assert.is_true(growth.coverSeason('automne', allowed))
        assert.is_true(growth.coverSeason('hiver', allowed))
        assert.is_false(growth.coverSeason('printemps', allowed))
        assert.is_false(growth.coverSeason('ete', allowed))
    end)

    it('ne couvre pas sans saison connue ni avec une liste invalide', function()
        local allowed = cfg.frost.coverSeasons
        -- vava_time absent (aucun gel) ou en démarrage (saison en attente)
        assert.is_false(growth.coverSeason(nil, allowed))
        assert.is_false(growth.coverSeason(false, allowed))
        assert.is_false(growth.coverSeason('hiver', nil))
        assert.is_false(growth.coverSeason('hiver', {}))
        assert.is_false(growth.coverSeason('inconnue', allowed))
    end)
end)
