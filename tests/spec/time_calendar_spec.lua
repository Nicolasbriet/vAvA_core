local helper = require('tests.helper')

-- Instants de référence (secondes UTC), vérifiés par os.date('!…') dans le premier test.
local UTC_2026_01_01 = 1767225600          -- jeudi 1er janvier 2026, 00:00 UTC
local UTC_SUMMER_2026 = 1774746000         -- dimanche 29 mars 2026, 01:00 UTC : passage à l'heure d'été
local UTC_WINTER_2026 = 1792890000         -- dimanche 25 octobre 2026, 01:00 UTC : retour à l'heure d'hiver
local UTC_2026_10_29_14H = 1793282400      -- jeudi 29 octobre 2026, 14:00 UTC (15:00 à Paris)
local UTC_2026_07_14_10H = 1784023200      -- mardi 14 juillet 2026, 10:00 UTC (12:00 à Paris)
local HOUR, DAY = 3600, 86400

describe('vava_time calendrier', function()
    local calendar, cfg

    before_each(function()
        helper.reset()
        VavaTime = nil
        helper.loadAll({
            'modules/vava_time/shared/constants.lua',
            'modules/vava_time/config.lua',
            'modules/vava_time/shared/calendar.lua',
        })
        calendar = VavaTime.calendar
        cfg = VavaTime.config
    end)

    describe('dates civiles', function()
        it('concorde avec os.date en UTC', function()
            for _, utc in ipairs({ 0, UTC_2026_01_01, UTC_SUMMER_2026, UTC_WINTER_2026, UTC_2026_10_29_14H, 951782400, 4107542400 }) do
                local expected = os.date('!*t', utc)
                local y, m, d = calendar.civilFromDays(utc // DAY)
                assert.same({ expected.year, expected.month, expected.day }, { y, m, d })
                assert.equal(utc // DAY, calendar.daysFromCivil(y, m, d))
            end
        end)

        it('fait l\'aller-retour sur quatre siècles, années bissextiles comprises', function()
            for days = -146097, 146097, 37 do
                local y, m, d = calendar.civilFromDays(days)
                assert.equal(days, calendar.daysFromCivil(y, m, d))
            end
            assert.equal(calendar.daysFromCivil(2028, 3, 1) - 1, calendar.daysFromCivil(2028, 2, 29))
            assert.equal(calendar.daysFromCivil(2100, 3, 1) - 1, calendar.daysFromCivil(2100, 2, 28))
        end)

        it('trouve le dernier dimanche du mois', function()
            assert.equal(29, calendar.lastSunday(2026, 3))
            assert.equal(25, calendar.lastSunday(2026, 10))
            assert.equal(31, calendar.lastSunday(2024, 3))
            assert.equal(28, calendar.lastSunday(2027, 3))
            assert.equal(31, calendar.lastSunday(2027, 10))
            assert.equal(0, calendar.weekday(calendar.daysFromCivil(2026, 3, 29)))
        end)
    end)

    describe('heure de Paris', function()
        it('passe à l\'heure d\'été le dernier dimanche de mars à 01:00 UTC', function()
            assert.equal(HOUR, calendar.parisOffset(UTC_SUMMER_2026 - 1))
            assert.equal(2 * HOUR, calendar.parisOffset(UTC_SUMMER_2026))
            -- 01:59:59 à Paris, puis 03:00:00 : l'heure de 02:00 n'existe pas
            assert.equal(1 * HOUR + 59 * 60 + 59, calendar.realSeconds(UTC_SUMMER_2026 - 1))
            assert.equal(3 * HOUR, calendar.realSeconds(UTC_SUMMER_2026))
        end)

        it('revient à l\'heure d\'hiver le dernier dimanche d\'octobre à 01:00 UTC', function()
            assert.equal(2 * HOUR, calendar.parisOffset(UTC_WINTER_2026 - 1))
            assert.equal(HOUR, calendar.parisOffset(UTC_WINTER_2026))
            -- 02:59:59 à Paris, puis 02:00:00 de nouveau
            assert.equal(2 * HOUR + 59 * 60 + 59, calendar.realSeconds(UTC_WINTER_2026 - 1))
            assert.equal(2 * HOUR, calendar.realSeconds(UTC_WINTER_2026))
        end)

        it('suit les années où le dernier dimanche est le 31', function()
            local summer2024 = calendar.daysFromCivil(2024, 3, 31) * DAY + HOUR
            local winter2027 = calendar.daysFromCivil(2027, 10, 31) * DAY + HOUR
            assert.equal(HOUR, calendar.parisOffset(summer2024 - 1))
            assert.equal(2 * HOUR, calendar.parisOffset(summer2024))
            assert.equal(2 * HOUR, calendar.parisOffset(winter2027 - 1))
            assert.equal(HOUR, calendar.parisOffset(winter2027))
        end)

        it('donne l\'heure d\'hiver en janvier et décembre, d\'été en juillet', function()
            assert.equal(HOUR, calendar.parisOffset(UTC_2026_01_01))
            assert.equal(HOUR, calendar.parisOffset(calendar.daysFromCivil(2026, 12, 31) * DAY + 23 * HOUR))
            assert.equal(2 * HOUR, calendar.parisOffset(UTC_2026_07_14_10H))
            assert.equal(12 * HOUR, calendar.realSeconds(UTC_2026_07_14_10H))
            assert.equal(15 * HOUR, calendar.realSeconds(UTC_2026_10_29_14H))
        end)

        it('accepte un instant décimal (horloge estimée du client)', function()
            assert.equal(2 * HOUR, calendar.parisOffset(UTC_SUMMER_2026 + 0.5))
            assert.near(3 * HOUR + 0.5, calendar.realSeconds(UTC_SUMMER_2026 + 0.5), 1e-9)
        end)
    end)

    describe('heure du royaume', function()
        it('suit l\'heure de Paris sans décalage', function()
            assert.equal(15 * HOUR, calendar.clock(UTC_2026_10_29_14H, { shift = 0, frozen = false }))
            assert.equal(15 * HOUR, calendar.clock(UTC_2026_10_29_14H, nil))
        end)

        it('applique un décalage et repasse minuit', function()
            assert.equal(18 * HOUR, calendar.clock(UTC_2026_10_29_14H, { shift = 3 * HOUR }))
            assert.equal(2 * HOUR, calendar.clock(UTC_2026_10_29_14H + 8 * HOUR, { shift = 3 * HOUR }))
            assert.equal(10 * HOUR, calendar.clock(UTC_2026_10_29_14H, { shift = -5 * HOUR }))
        end)

        it('reste figée quel que soit l\'instant', function()
            local state = { shift = 3 * HOUR, frozen = 22 * HOUR }
            assert.equal(22 * HOUR, calendar.clock(UTC_2026_10_29_14H, state))
            assert.equal(22 * HOUR, calendar.clock(UTC_2026_10_29_14H + 5000, state))
        end)

        it('calcule le décalage qui donne une heure voulue, entre −12 h et +12 h', function()
            assert.equal(7 * HOUR, calendar.shiftFor(UTC_2026_10_29_14H, 22 * HOUR))
            assert.equal(-12 * HOUR, calendar.shiftFor(UTC_2026_10_29_14H, 3 * HOUR))
            assert.equal(-3 * HOUR, calendar.shiftFor(UTC_2026_10_29_14H, 12 * HOUR))
            for target = 0, DAY - 60, 1800 do
                local shift = calendar.shiftFor(UTC_2026_10_29_14H, target)
                assert.is_true(shift >= -12 * HOUR and shift < 12 * HOUR)
                assert.equal(target, calendar.clock(UTC_2026_10_29_14H, { shift = shift }))
            end
        end)

        it('ramène un décalage dans [−12 h, +12 h[', function()
            assert.equal(-36400, calendar.normalizeShift(50000))
            assert.equal(-12 * HOUR, calendar.normalizeShift(12 * HOUR))
            assert.equal(11 * HOUR, calendar.normalizeShift(11 * HOUR + DAY))
            assert.equal(0, calendar.normalizeShift(-DAY))
        end)

        it('découpe une seconde du jour et nomme le moment', function()
            assert.same({ 15, 20, 5 }, { calendar.hms(15 * HOUR + 20 * 60 + 5.9) })
            assert.same({ 0, 0, 0 }, { calendar.hms(DAY) })
            assert.equal('la nuit', calendar.moment(3))
            assert.equal('la nuit', calendar.moment(5))
            assert.equal('l\'aube', calendar.moment(6))
            assert.equal('midi', calendar.moment(12))
            assert.equal('l\'après-midi', calendar.moment(15))
            assert.equal('la nuit', calendar.moment(23))
        end)
    end)

    describe('saisons au vrai calendrier', function()
        local function date(y, m, d)
            local result = calendar.realDate(y, m, d)
            return { result.season, result.day, result.year }
        end

        it('bascule aux dates de début, veilles comprises', function()
            assert.same({ 'hiver', 89, 1 }, date(2026, 3, 19))
            assert.same({ 'printemps', 1, 1 }, date(2026, 3, 20))
            assert.same({ 'printemps', 93, 1 }, date(2026, 6, 20))
            assert.same({ 'ete', 1, 1 }, date(2026, 6, 21))
            assert.same({ 'ete', 93, 1 }, date(2026, 9, 21))
            assert.same({ 'automne', 1, 1 }, date(2026, 9, 22))
            assert.same({ 'automne', 38, 1 }, date(2026, 10, 29))
            assert.same({ 'hiver', 1, 1 }, date(2026, 12, 21))
        end)

        it('garde l\'hiver à cheval sur deux années et change d\'an au printemps', function()
            assert.same({ 'hiver', 12, 1 }, date(2027, 1, 1))
            assert.same({ 'hiver', 71, 2 }, date(2028, 2, 29))
            assert.same({ 'printemps', 1, 2 }, date(2027, 3, 20))
            assert.same({ 'printemps', 1, 3 }, date(2028, 3, 20))
        end)

        it('ne descend jamais sous l\'an 1', function()
            assert.same({ 'hiver', 11, 1 }, date(2025, 12, 31))
            assert.same({ 'ete', 1, 1 }, date(2020, 6, 21))
        end)

        it('prend la date à Paris, pas à l\'UTC', function()
            local real = { mode = 'real', firstYear = 2026, starts = cfg.calendar.starts, seasons = cfg.calendar.seasons }
            -- 29 octobre 2026, 23:30 UTC = 30 octobre, 00:30 à Paris
            local result = calendar.date(calendar.daysFromCivil(2026, 10, 29) * DAY + 23 * HOUR + 1800, real)
            assert.same({ 'automne', 39, 1 }, { result.season, result.day, result.year })
        end)
    end)

    describe('calendrier par défaut : saisons de quatorze jours', function()
        -- origin : lundi 26 octobre 2026, minuit à Paris (heure d'hiver : 23:00 UTC la veille), printemps de l'an 1
        local function at(days)
            local origin = calendar.daysFromCivil(2026, 10, 26) * DAY - HOUR
            local result = calendar.date(origin + days * DAY)
            return { result.season, result.day, result.year }
        end

        it('suit le cycle de la config, ancré sur une date fixe', function()
            assert.equal('cycle', cfg.calendar.mode)
            assert.equal(14, calendar.seasonLength())
            assert.same({ 'printemps', 1, 1 }, at(0))
            assert.same({ 'printemps', 4, 1 }, { calendar.date(UTC_2026_10_29_14H).season, calendar.date(UTC_2026_10_29_14H).day, 1 })
            assert.same({ 'printemps', 14, 1 }, at(13.5))
            assert.same({ 'ete', 1, 1 }, at(14))
            assert.same({ 'automne', 1, 1 }, at(28))
            assert.same({ 'hiver', 14, 1 }, at(55.9))
        end)

        it('change d\'an à chaque nouveau printemps : une année dure huit semaines', function()
            assert.same({ 'printemps', 1, 2 }, at(56))
            assert.same({ 'printemps', 1, 3 }, at(112))
            assert.same({ 'printemps', 1, 1 }, at(-30))
        end)

        it('n\'a pas de durée fixe au vrai calendrier', function()
            assert.is_nil(calendar.seasonLength({ mode = 'real' }))
        end)
    end)

    describe('saisons en cycle', function()
        local cal, origin

        before_each(function()
            cal = {
                mode = 'cycle', firstYear = 2026, starts = cfg.calendar.starts, seasons = cfg.calendar.seasons,
                cycle = { seasonDays = 7, origin = { year = 2026, month = 10, day = 26 }, first = 'automne' },
            }
            -- minuit à Paris (heure d'hiver : 23:00 UTC la veille)
            origin = calendar.daysFromCivil(2026, 10, 26) * DAY - HOUR
        end)

        local function at(seconds)
            local result = calendar.date(origin + seconds, cal)
            return { result.season, result.day, result.year }
        end

        it('enchaîne les saisons à partir de la première', function()
            assert.same({ 'automne', 1, 1 }, at(0))
            assert.same({ 'automne', 4, 1 }, at(3.5 * DAY))
            assert.same({ 'hiver', 1, 1 }, at(7 * DAY))
            assert.same({ 'printemps', 1, 2 }, at(14 * DAY))
            assert.same({ 'ete', 7, 2 }, at(28 * DAY - 1))
            assert.same({ 'automne', 1, 2 }, at(28 * DAY))
        end)

        it('reste sur la première saison avant l\'origine', function()
            assert.same({ 'automne', 1, 1 }, at(-5 * DAY))
        end)

        it('accepte des saisons de quelques minutes (essais)', function()
            cal.cycle.seasonDays = 0.01
            assert.same({ 'hiver', 1, 1 }, at(864))
            assert.same({ 'printemps', 1, 2 }, at(2 * 864))
        end)
    end)

    describe('texte de /date', function()
        it('dit l\'heure, le jour, la saison, l\'an, le moment et le ciel', function()
            local text = calendar.describe(15 * HOUR + 20 * 60, false, { season = 'automne', day = 38, year = 1 }, 'il pleut')
            assert.equal('Il est 15 h 20, le 38e jour de la saison des brumes (automne), an 1 du royaume. C\'est l\'après-midi : il pleut.', text)
        end)

        it('écrit « 1er » et signale une heure figée', function()
            local text = calendar.describe(6 * HOUR + 5 * 60, true, { season = 'printemps', day = 1, year = 2 }, 'le ciel est clair')
            assert.equal('Il est 6 h 05, le 1er jour de la saison des semailles (printemps), an 2 du royaume. C\'est l\'aube : le ciel est clair. '
                .. cfg.messages.frozen, text)
        end)

        it('annonce une nuit de gel les jours où le serveur l\'a tirée, avant une heure figée', function()
            local date = { season = 'hiver', day = 4, year = 1, frost = true }
            local text = calendar.describe(18 * HOUR, false, date, 'il neige')
            assert.equal('Il est 18 h 00, le 4e jour de la saison des frimas (hiver), an 1 du royaume. C\'est le soir : il neige. '
                .. 'La nuit sera froide.', text)
            assert.equal('La nuit sera froide.', cfg.messages.frostTonight)
            local frozen = calendar.describe(18 * HOUR, true, date, 'il neige')
            assert.equal(text .. ' ' .. cfg.messages.frozen, frozen)
        end)

        it('ne dit rien du gel sans nuit de gel annoncée', function()
            for _, flag in ipairs({ false, 'oui', 1 }) do
                local text = calendar.describe(18 * HOUR, false, { season = 'hiver', day = 4, year = 1, frost = flag }, 'il neige')
                assert.is_nil(text:find(cfg.messages.frostTonight, 1, true))
            end
            local text = calendar.describe(18 * HOUR, false, { season = 'hiver', day = 4, year = 1 }, 'il neige')
            assert.is_nil(text:find(cfg.messages.frostTonight, 1, true))
        end)

        it('donne la date seule pour les interfaces', function()
            assert.equal('38e jour de la saison des brumes (automne), an 1 du royaume', calendar.dateText({ season = 'automne', day = 38, year = 1 }))
            assert.equal('an 3 du royaume', calendar.yearText(3))
        end)
    end)
end)
