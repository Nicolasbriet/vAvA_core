local helper = require('tests.helper')

-- Temps vu du client (T-142, lot 3 de T-132 ; relecture réseau R-2) : shared/calendar.lua et shared/weather.lua, servis
-- aux joueurs, lisent la config (calendrier, textes, ciels) ; le client s'en sert pour /date, l'outil du Conseil et
-- l'horloge du jeu (client/main.lua, client/tool.lua, client/world.lua). Sur la SEULE vue client (constantes et
-- config_client.lua, comme chez un joueur ; config.lua n'est pas lu), ils rendent ce que rend la config complète du
-- serveur.

local DIR = 'modules/vava_time'

local function load(view)
    helper.reset()
    VavaTime = nil
    if view == 'client' then
        helper.loadClientView(DIR, 'VavaTime')
        helper.loadAll({ DIR .. '/shared/calendar.lua', DIR .. '/shared/weather.lua' })
    else
        helper.loadAll({ DIR .. '/shared/constants.lua', DIR .. '/config.lua', DIR .. '/shared/calendar.lua',
            DIR .. '/shared/weather.lua', DIR .. '/shared/cycle.lua' })
    end
    return { calendar = VavaTime.calendar, rules = VavaTime.weatherRules, cfg = VavaTime.config }
end

-- instants UTC répartis sur plus d'une année du royaume (une saison : 14 jours), heure d'été comprise
local INSTANTS = {}
for i = 0, 40 do INSTANTS[#INSTANTS + 1] = 1793000000 + i * 3 * 86400 + i * 3607 end

describe('vava_time vu du client (config_client.lua seul)', function()
    local full, client

    before_each(function()
        full = load('full')
        client = load('client')
    end)

    after_each(function() VavaTime = nil end)

    it('la vue client ne contient pas les réglages du seul serveur', function()
        assert.is_true(client.cfg.clientFile)
        assert.is_nil(client.cfg.frost)
        assert.is_nil(client.cfg.council)
        assert.is_nil(client.cfg.clock.maxShiftMinutes)
        assert.is_number(client.cfg.clock.msPerGameMinute)
    end)

    it('même date et même ligne de /date, heure figée ou non, nuit de gel annoncée ou non', function()
        for _, utc in ipairs(INSTANTS) do
            local date = client.calendar.date(utc)
            assert.same(full.calendar.date(utc), date)
            local seconds = client.calendar.clock(utc, { shift = 0 })
            for _, frozen in ipairs({ false, true }) do
                for _, frost in ipairs({ false, true }) do
                    local d = { season = date.season, day = date.day, year = date.year, frost = frost }
                    local text = client.calendar.describe(seconds, frozen, d, 'il pleut')
                    assert.is_string(text)
                    assert.equal(full.calendar.describe(seconds, frozen, d, 'il pleut'), text)
                end
            end
        end
    end)

    it('chaque ciel se lit de même (définition, transition)', function()
        local ids = full.rules.ids()
        assert.same(ids, client.rules.ids())
        for _, id in ipairs(ids) do
            local def = client.rules.get(id)
            assert.is_table(def, id)
            assert.same(full.rules.get(id), def)
            assert.is_string(def.phrase, id)
        end
        assert.equal(full.rules.progress(1000, 90, 46000), client.rules.progress(1000, 90, 46000))
    end)

    -- T-146 (relecture réseau R-1 de T-142) : le cours des ciels et son tirage sont au seul serveur
    it('le cours des ciels n\'est pas servi : ni ses réglages, ni son tirage', function()
        for _, key in ipairs({ 'next', 'seasons', 'snow', 'durationMinutes', 'durations', 'fadeSeconds' }) do
            assert.is_nil(client.cfg.weather[key], 'weather.' .. key)
            assert.is_not_nil(full.cfg.weather[key], 'weather.' .. key)
        end
        for _, name in ipairs({ 'weight', 'allowed', 'candidates', 'pick', 'duration', 'missingCourse' }) do
            assert.is_nil(client.rules[name], name)
            assert.is_function(full.rules[name], name)
        end
        assert.same(full.cfg.weather.types, client.cfg.weather.types)
    end)

    -- Ce que fait client/world.lua d'un ciel publié (vava_time:weather) : ciel visé, ciel d'avant, avancement du
    -- fondu ; client/main.lua (/date) et client/tool.lua (ciel tapé après /ciel imposer) lisent la même définition.
    it('le ciel publié s\'applique sur la vue client, en fondu', function()
        local published = { id = 'pluie', from = 'clair', at = 1000, fade = 90 }
        local target, from = client.rules.get(published.id), client.rules.get(published.from)
        assert.equal('RAIN', target.gta)
        assert.equal('CLEAR', from.gta)
        assert.equal('il pleut', target.phrase)
        assert.equal(0, client.rules.progress(published.at, published.fade, 1000))
        assert.equal(0.5, client.rules.progress(published.at, published.fade, 1045))
        assert.equal(1, client.rules.progress(published.at, published.fade, 2000))
        assert.equal(1, client.rules.progress(published.at, 0, 1000))
        assert.is_true(client.rules.get('neige_au_sol').tracks)
        assert.is_nil(client.rules.get('grele'))
        assert.is_nil(client.rules.get(nil))
    end)
end)
