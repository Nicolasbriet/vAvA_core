local helper = require('tests.helper')

-- Magie vue du client (T-143, lot 4 de T-132 ; relecture réseau R-2 de T-132) : les fichiers partagés dont le client se
-- sert (shared/progression.lua, shared/geometry.lua) lisent la config au chargement (seuils, coûts, zones de paix) et
-- reçoivent la config d'un sort (progression.cost, client/state.lua et client/grimoire.lua). Ils sont essayés sur la
-- SEULE vue client (constantes et config_client.lua, comme chez un joueur ; config.lua n'est pas lu) : mêmes résultats
-- que sur la config complète du serveur, pour chaque sort, chaque niveau et chaque XP de seuil.

local SHARED = { 'modules/vava_magic/shared/progression.lua', 'modules/vava_magic/shared/geometry.lua' }

--- Résultats des fonctions partagées sur la config chargée : un relevé comparable d'une vue à l'autre.
local function survey(magic)
    local progression, geometry, cfg = magic.progression, magic.geometry, magic.config
    local out = { maxLevel = progression.MAX_LEVEL, maxXp = progression.MAX_XP, levels = {}, thresholds = {}, costs = {},
        sigils = {}, zones = {} }
    for xp = 0, progression.MAX_XP + 10, 5 do out.levels[xp] = progression.levelOf(xp) end
    for level = 1, progression.MAX_LEVEL do out.thresholds[level] = progression.threshold(level) end
    for name, spell in pairs(cfg.spells) do
        out.costs[name] = {}
        for level = 1, #spell.levels do
            out.costs[name][level] = { progression.cost(spell, level), progression.cost(spell, level, 0.5) }
        end
    end
    out.sigils.nonMage = progression.sigilLimit(false, nil)
    out.sigils.noSpell = progression.sigilLimit(true, nil)
    for _, xp in ipairs({ 0, 99, 100, 300, 700, 1500, 99999 }) do out.sigils[xp] = progression.sigilLimit(true, xp) end
    for i, point in ipairs({ { x = 0, y = 0, z = 0 }, { x = 30, y = 0, z = 0 }, { x = -500, y = 1200, z = 40 } }) do
        out.zones[i] = geometry.protectedZone(point) or false
    end
    return out
end

describe('vava_magic vu du client (config_client.lua seul)', function()
    local full, client, view

    before_each(function()
        helper.reset()
        helper.loadAll({ 'modules/vava_magic/shared/constants.lua', 'modules/vava_magic/config.lua' })
        helper.loadAll(SHARED)
        full = survey(VavaMagic)
        helper.reset()
        helper.loadClientView('modules/vava_magic', 'VavaMagic')
        helper.loadAll(SHARED)
        view = VavaMagic.config
        client = survey(VavaMagic)
    end)

    after_each(function()
        VavaMagic = nil
    end)

    it('la vue client est bien sans config.lua', function()
        assert.is_true(view.clientFile)
        assert.is_nil(view.items)
        assert.is_nil(view.rateLimits)
        assert.is_nil(view.protections)
        assert.is_nil(view.registers)
        assert.is_nil(view.texts.logs)
        assert.is_nil(view.texts.chat.adminUsage)
        assert.is_nil(view.texts.notify.levelUp)
        assert.is_nil(view.states.durations)
        assert.is_nil(view.combat.pvp)
        assert.is_nil(view.sigils.alphabet)
        assert.is_nil(view.sigils.scramble.cooldownMs)
        assert.is_nil(view.progression.failureShare)
        -- droits et commandes du Conseil, réponses du Conseil (relecture sécurité S-4 de T-143)
        assert.is_nil(view.admin)
        assert.is_nil(view.commands.adminActions)
        assert.is_nil(view.commands.protectWords)
        assert.is_nil(view.texts.chat.adminErrors)
    end)

    it('niveaux, seuils, coûts de chaque sort et sigils mémorisables : comme sur la config complète', function()
        assert.equal(5, client.maxLevel)
        assert.equal(1500, client.maxXp)
        assert.same(full, client)
        -- chaque sort a un coût à chaque niveau (rien de nil, rien de NaN)
        for name, levels in pairs(client.costs) do
            for level, costs in ipairs(levels) do
                assert.is_true(math.type(costs[1]) == 'integer' and costs[1] >= 0, name .. ' niveau ' .. level)
            end
        end
    end)

    it('zones de paix : la même liste que le serveur', function()
        assert.same({}, view.combat.protectedZones)
        assert.same(full.zones, client.zones)
    end)
end)
