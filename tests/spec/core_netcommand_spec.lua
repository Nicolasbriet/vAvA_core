local helper = require('tests.helper')

-- Commande du Conseil /vava_reseau (server/core/netcommand.lua), action « zones » (core 0.11.0, T-014) : vue d'ensemble
-- des zones et des abonnements, zones suivies par un joueur (inscrit au journal du Registre), arguments refusés, droit.
-- vava_admin, le registre des commandes et le service des zones sont des doublures.
describe('vAvA.netcommand : zones', function()
    local commands, lines, journal, allowed, existing, now, stats, names, printed, realPrint

    before_each(function()
        helper.reset()
        commands, lines, journal, printed = {}, {}, {}, {}
        allowed = { [1] = true }
        existing = { [1] = true, [2] = true, [3] = true }
        now = 0
        names = {}
        stats = {
            zones = 207,
            owners = {
                { owner = 'vava_voice', count = 200 }, { owner = 'vava_gathering', count = 4 },
                { owner = 'vava_farming', count = 3 },
            },
            subscriptions = 37, lastPassMs = 0.0812, maxPassMs = 0.1249, passMs = 1000,
        }
        realPrint = _G.print
        _G.print = function(line) printed[#printed + 1] = tostring(line) end
        _G.GetGameTimer = function() return now end
        _G.DoesPlayerExist = function(src) return existing[src] == true end
        _G.RegisterCommand = function(name, handler) commands[name] = handler end
        _G.GetResourceState = function() return 'started' end
        _G.IsPlayerAceAllowed = function() return false end
        _G.TriggerClientEvent = function(event, target, payload)
            if event == 'chat:addMessage' then lines[#lines + 1] = { target = target, text = payload.args[2] } end
        end
        _G.exports = {
            vava_admin = {
                can = function(_, src) return allowed[src] == true end,
                log = function(_, src, label, data)
                    journal[#journal + 1] = { src = src, label = label, data = data }
                    return true
                end,
            },
        }
        helper.loadAll({
            'shared/init.lua',
            'config/shared.lua',
            'shared/lib/string.lua',
            'shared/core/logger.lua',
            'config/server.lua',
            'server/core/netsize.lua',
            'server/core/netstats.lua',
            'server/core/net.lua',
        })
        vAvA.zones = {
            stats = function() return stats end,
            ofPlayer = function(src) return names[src] or {} end,
        }
        vAvA.commands = { declare = function(name, def) commands['declared:' .. name] = def return true end }
        helper.load('server/core/netcommand.lua')
        vAvA.netcommand.start()
    end)

    after_each(function()
        _G.print = realPrint
        _G.exports = nil
    end)

    --- Commande tapée par un joueur, deux secondes après la précédente.
    local function run(src, ...)
        now = now + 2000
        lines = {}
        commands.vava_reseau(src, { ... })
        local texts = {}
        for i, line in ipairs(lines) do texts[i] = line.text end
        return texts
    end

    it('zones : une ligne, durées à la virgule française, modules dans l’ordre rendu par le service', function()
        assert.same({
            'Zones : 207 (vava_voice 200, vava_gathering 4, vava_farming 3) ; 37 abonnements ; '
                .. 'dernier passage 0,08 ms, au plus 0,12 ms sur la minute.',
        }, run(1, 'zones'))
        assert.equal(1, lines[1].target)
        assert.same({}, journal)
    end)

    it('aucun passage encore mesuré ; aucune zone déclarée', function()
        stats.lastPassMs, stats.maxPassMs = nil, nil
        local texts = run(1, 'zones')
        assert.truthy(texts[1]:find('dernier passage – ms, au plus – ms', 1, true))
        stats.zones, stats.owners, stats.subscriptions = 0, {}, 0
        assert.same({ 'Aucune zone déclarée.' }, run(1, 'zones'))
    end)

    it('zones <n°> : noms tronqués à 20 suivis de « … », inscrit au journal', function()
        local list = {}
        for i = 1, 25 do list[i] = ('vava_voice:z%02d'):format(i) end
        names[2] = list
        local texts = run(1, 'zones', '2')
        local shown = {}
        for i = 1, 20 do shown[i] = list[i] end
        assert.same({ 'Joueur 2 : 25 zone(s) suivie(s) : ' .. table.concat(shown, ', ') .. '…' }, texts)
        assert.same({ { src = 1, label = 'Zones d\'un joueur consultées', data = { joueur = 2 } } }, journal)
    end)

    it('zones <n°> : aucune zone suivie, ou peu', function()
        assert.same({ 'Joueur 3 : 0 zone(s) suivie(s)' }, run(1, 'zones', '3'))
        names[3] = { 'vava_voice:z1', 'vava_gathering:mine' }
        assert.same({ 'Joueur 3 : 2 zone(s) suivie(s) : vava_voice:z1, vava_gathering:mine' }, run(1, 'zones', '3'))
    end)

    it('arguments refusés : usage ; joueur inconnu', function()
        local usage = vAvA.config.server.net.command.messages.usage
        assert.same({ usage }, run(1, 'zones', 'abc'))
        assert.same({ usage }, run(1, 'zones', '1234567'))
        assert.same({ usage }, run(1, 'zones', '-2'))
        assert.same({ 'Aucun joueur n° 9 en jeu.' }, run(1, 'zones', '9'))
        assert.same({ 'Aucun joueur n° 0 en jeu.' }, run(1, 'zones', '0'))
        assert.same({}, journal)
        assert.truthy(usage:find('zones [n°]', 1, true))
    end)

    it('sans droit : rien', function()
        assert.same({}, run(2, 'zones'))
        assert.same({}, run(2, 'zones', '1'))
        assert.same({}, journal)
    end)

    it('délai entre deux commandes d’un même membre', function()
        run(1, 'zones')
        now = now - 1000
        lines = {}
        commands.vava_reseau(1, { 'zones' })
        assert.same({}, lines)
    end)

    it('console : sortie en console, journal du serveur pour un joueur', function()
        names[2] = { 'vava_voice:z1' }
        commands.vava_reseau(0, { 'zones', '2' })
        local found, logged = false, false
        for _, line in ipairs(printed) do
            if line:find('Joueur 2 : 1 zone(s) suivie(s) : vava_voice:z1', 1, true) then found = true end
            if line:find('Zones d\'un joueur consultées', 1, true) then logged = true end
        end
        assert.is_true(found)
        assert.is_true(logged)
        assert.same({}, journal)
    end)

    it('déclarée au registre des commandes avec l’action zones', function()
        local def = commands['declared:vava_reseau']
        local action = def.actions[#def.actions]
        assert.same({ id = 'zones', label = 'Zones et abonnements',
            args = { { name = 'joueur', type = 'player', optional = true } } }, action)
    end)
end)
