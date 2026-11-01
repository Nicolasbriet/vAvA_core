local helper = require('tests.helper')

-- Chargeur du code du Conseil (T-157) : amorce réelle (modules/vava_atelier/client/nui.lua, notice.lua, loader.lua,
-- main.lua) sur la vue client de chaque joueur (constantes, config_client.lua) ; doublures : RPC du serveur scripté,
-- stockage local (KVP) en table, `load` espionné, page simulée derrière les natives NUI. Règles documentées : spec T-157
-- § 8.1 à § 8.5 et § 9.1, contrat docs/plan/rapports/T-157-contrat.md, README de vava_atelier :
--   hors du Conseil : refus, stockage effacé, rien d'exécuté ; premier chargement : description, morceaux 1 à n avec
--   l'empreinte annoncée, stockage écrit (empreinte en dernier), chaque fichier Lua par load(code, '@@vava_atelier/<chemin>',
--   't', env) dans un environnement du paquet, puis la page (bootPiece dans l'ordre, bootEnd, booted) et l'Atelier
--   ouvert ; stockage relu seulement s'il a l'empreinte annoncée dans cette séance ; erreurs : failed, plus d'essai.

local LUA_PIECES = {
    { kind = 'L', name = 'config_conseil.lua', code = 'VavaAtelier.ran[#VavaAtelier.ran + 1] = "config_conseil.lua"\n' },
    { kind = 'L', name = 'client/session.lua', code = [[
VavaAtelier.ran[#VavaAtelier.ran + 1] = 'client/session.lua'
local session = { opened = 0, open_ = false }
VavaAtelier.session = session
function session.open() session.opened = session.opened + 1 session.open_ = true end
function session.isOpen() return session.open_ end
function session.isSuspended() return false end
function session.close() session.open_ = false end
function session.release() session.released = true end
]] },
    { kind = 'L', name = 'client/placer.lua', code = [[
VavaAtelier.ran[#VavaAtelier.ran + 1] = 'client/placer.lua'
VavaAtelier.placer = { release = function() VavaAtelier.placerReleased = true end }
]] },
}
local WEB_PIECES = {
    { kind = 'C', name = 'web/css/style.css', code = '.a { color: #241b12; }\n' },
    -- un gros script : le paquet fait trois morceaux de 64 Ko
    { kind = 'J', name = 'web/js/app.js', code = '// « Atelier »\n' .. string.rep('a();\n', 30000) },
}

local function concatLists(...)
    local out = {}
    for _, list in ipairs({ ... }) do for _, v in ipairs(list) do out[#out + 1] = v end end
    return out
end

describe('vava_atelier chargeur du code du Conseil (client)', function()
    local server, kvp, kvpOps, loads, messages, callbacks, page, feeds, commands, hooks, stopHandlers, exported
    local netHandlers, chat, logs, realLoad

    --- Paquet servi : texte, empreinte, morceaux (codepack réel).
    local function serve(pieces)
        local text = assert(VavaAtelier.codepack.encode(pieces))
        server.text, server.fp = text, VavaAtelier.digest(text)
        server.parts = assert(VavaAtelier.codepack.cut(text, VavaAtelier.CODEPACK.PART_BYTES))
    end

    --- Amorce chargée comme au démarrage de la ressource (stockage local gardé d'une séance à l'autre).
    local function boot()
        helper.reset()
        VavaAtelier = nil
        helper.loadClientView('modules/vava_atelier', 'VavaAtelier')
        assert.is_nil(VavaAtelier.config.placement, 'config_conseil.lua ne doit pas être dans la vue de l\'amorce')
        helper.loadAll({ 'modules/vava_atelier/shared/digest.lua', 'modules/vava_atelier/shared/codepack.lua' })
        VavaAtelier.ran = {}
        logs = { warn = {}, error = {}, info = {} }
        local function logger(level) return function(fmt, ...) table.insert(logs[level], fmt:format(...)) end end
        VavaAtelier.core = {
            log = { warn = logger('warn'), error = logger('error'), info = logger('info') },
            hooks = { after = function(name, fn) hooks[name] = fn return 1 end },
            rpc = { call = function(name, fp, part)
                assert.equal('vava_atelier:code', name)
                server.calls[#server.calls + 1] = { fp = fp, part = part }
                if server.onCall then server.onCall(fp, part) end
                if server.transport then return false, server.transport end
                if not server.allowed then return true, false, 'not_allowed' end
                if part == 0 then return true, true, server.describe or { fp = server.fp, parts = #server.parts,
                    bytes = #server.text } end
                if server.staleLeft > 0 then
                    server.staleLeft = server.staleLeft - 1
                    return true, false, 'stale'
                end
                if fp ~= server.fp then return true, false, 'stale' end
                local chunk = server.parts[part]
                if server.tamper and part == 1 then chunk = chunk:gsub('opened = 0', 'opened = 9', 1) end
                return true, true, chunk
            end },
        }
        _G.GetCurrentResourceName = function() return 'vava_atelier' end
        _G.SendNUIMessage = function(message)
            messages[#messages + 1] = message
            page(message)
        end
        _G.SetNuiFocus = function() end
        _G.RegisterNUICallback = function(name, fn) callbacks[name] = fn end
        _G.GetResourceKvpString = function(key)
            local v = kvp[key]
            return type(v) == 'string' and v or nil
        end
        _G.GetResourceKvpInt = function(key)
            local v = kvp[key]
            return math.type(v) == 'integer' and v or 0
        end
        _G.SetResourceKvp = function(key, value) kvp[key] = value kvpOps[#kvpOps + 1] = 'set ' .. key end
        _G.SetResourceKvpInt = function(key, value) kvp[key] = value kvpOps[#kvpOps + 1] = 'set ' .. key end
        _G.DeleteResourceKvp = function(key) kvp[key] = nil kvpOps[#kvpOps + 1] = 'del ' .. key end
        _G.GetResourceState = function(name) return name == 'vava_chat' and 'started' or 'missing' end
        _G.BeginTextCommandThefeedPost = function() end
        _G.AddTextComponentSubstringPlayerName = function(text) feeds[#feeds + 1] = text end
        _G.EndTextCommandThefeedPostTicker = function() end
        _G.RegisterNetEvent = function(name, fn) netHandlers[name] = fn end
        _G.TriggerEvent = function(name, payload) chat[#chat + 1] = { name = name, payload = payload } end
        _G.RegisterCommand = function(name, fn) commands[name] = fn end
        _G.RegisterKeyMapping = function() end
        _G.AddEventHandler = function(name, fn) stopHandlers[name] = fn end
        _G.exports = function(name, fn) exported[name] = fn end
        -- attente d'une promesse : les échéances posées (SetTimeout) tombent si la page ne répond pas
        Citizen.Await = function(p)
            local i = 1
            while not p.resolved and i <= #helper.timers do
                local timer = helper.timers[i]
                if not timer.fired then
                    timer.fired = true
                    timer.fn()
                end
                i = i + 1
            end
            assert.is_true(p.resolved, 'promesse jamais résolue')
            return p.value
        end
        helper.loadAll({
            'modules/vava_atelier/client/nui.lua',
            'modules/vava_atelier/client/notice.lua',
            'modules/vava_atelier/client/loader.lua',
            'modules/vava_atelier/client/main.lua',
        })
        -- `load` espionné (le chargeur le lit à l'exécution) : chaque appel est noté, puis fait par le vrai `load`
        _G.load = function(code, name, mode, env)
            loads[#loads + 1] = { name = name, mode = mode, env = env }
            return realLoad(code, name, mode, env)
        end
    end

    --- Page simulée (web/boot.js) selon `pageMode` : 'normal' (prête au premier `hello`, compte rendu juste),
    --- 'mute' (rien), 'error' (un script en erreur), 'lost' (insère, mais perd le premier compte rendu).
    local pageMode, pageState
    local function post(name, data)
        local answered
        callbacks[name](data, function(reply) answered = reply end)
        assert.same({ ok = true }, answered)
    end
    local function makePage()
        pageState = { pieces = {}, ended = false, report = nil, lostOnce = false }
        return function(message)
            local action, payload = message.action, message.payload
            if pageMode == 'mute' then return end
            if action == 'hello' then
                if pageState.ended then post('booted', pageState.report) else post('pageReady', {}) end
            elseif action == 'bootPiece' then
                pageState.pieces[#pageState.pieces + 1] = payload
            elseif action == 'bootEnd' then
                pageState.ended = true
                if pageMode == 'error' then
                    pageState.report = { ok = false, piece = 'web/js/app.js' }
                else
                    pageState.report = { ok = true, count = #pageState.pieces }
                end
                if pageMode == 'lost' and not pageState.lostOnce then
                    pageState.lostOnce = true
                    return
                end
                post('booted', pageState.report)
            end
        end
    end

    local function f9() commands.atelier() end

    local function partCalls()
        local n = 0
        for _, call in ipairs(server.calls) do if call.part > 0 then n = n + 1 end end
        return n
    end

    local function actions()
        local out = {}
        for _, m in ipairs(messages) do out[#out + 1] = m.action end
        return out
    end

    before_each(function()
        realLoad = load
        server = { allowed = true, calls = {}, staleLeft = 0 }
        kvp, kvpOps, loads, messages, callbacks, feeds = {}, {}, {}, {}, {}, {}
        commands, hooks, stopHandlers, exported, netHandlers, chat = {}, {}, {}, {}, {}, {}
        pageMode = 'normal'
        page = makePage()
        boot()
        serve(concatLists(LUA_PIECES, WEB_PIECES))
    end)

    after_each(function()
        _G.load = realLoad
        VavaAtelier = nil
        for _, name in ipairs({ 'SendNUIMessage', 'SetNuiFocus', 'RegisterNUICallback', 'GetResourceKvpString',
            'GetResourceKvpInt', 'SetResourceKvp', 'SetResourceKvpInt', 'DeleteResourceKvp', 'GetResourceState',
            'BeginTextCommandThefeedPost', 'AddTextComponentSubstringPlayerName', 'EndTextCommandThefeedPostTicker',
            'RegisterNetEvent', 'TriggerEvent', 'RegisterCommand', 'RegisterKeyMapping', 'AddEventHandler',
            'exports' }) do
            _G[name] = nil
        end
    end)

    it('hors du Conseil : refus montré, stockage effacé, aucun load, aucun message à la page', function()
        kvp['paquet:empreinte'], kvp['paquet:1'] = server.fp, 'ancien'
        server.allowed = false
        f9()
        assert.same({ VavaAtelier.config.texts.refused.not_allowed }, feeds)
        assert.same({}, kvp)
        assert.equal(0, #loads)
        assert.same({}, messages)
        assert.equal(1, #server.calls)
        assert.equal('idle', VavaAtelier.loader.state())
    end)

    it('premier chargement : morceaux 1 à n avec l\'empreinte annoncée, stockage (empreinte en dernier), load des L '
        .. 'dans l\'ordre, page, puis l\'Atelier s\'ouvre', function()
        f9()
        assert.equal(3, #server.parts)
        assert.same({ { fp = '', part = 0 }, { fp = server.fp, part = 1 }, { fp = server.fp, part = 2 },
            { fp = server.fp, part = 3 } }, server.calls)
        assert.same({ VavaAtelier.config.texts.loading }, feeds)
        -- stockage : empreinte effacée d'abord, écrite en dernier
        assert.equal('del paquet:empreinte', kvpOps[1])
        assert.equal('set paquet:empreinte', kvpOps[#kvpOps])
        assert.equal(server.fp, kvp['paquet:empreinte'])
        assert.equal(#server.text, kvp['paquet:taille'])
        -- load : les seuls L, dans l'ordre, nom d'origine, texte seul, environnement du paquet (pas _G)
        assert.equal(3, #loads)
        for i, piece in ipairs(LUA_PIECES) do
            assert.equal('@@vava_atelier/' .. piece.name, loads[i].name)
            assert.equal('t', loads[i].mode)
            assert.is_table(loads[i].env)
            assert.is_false(rawequal(_G, loads[i].env))
            assert.equal(_G, getmetatable(loads[i].env).__index)
            assert.equal(loads[1].env, loads[i].env)
        end
        assert.same({ 'config_conseil.lua', 'client/session.lua', 'client/placer.lua' }, VavaAtelier.ran)
        -- page : hello (pas encore prête), les deux fichiers dans l'ordre, bootEnd
        assert.same({ 'hello', 'bootPiece', 'bootPiece', 'bootEnd' }, actions())
        assert.same({ index = 0, kind = 'css', name = 'web/css/style.css', code = WEB_PIECES[1].code }, messages[2].payload)
        assert.same({ index = 1, kind = 'js', name = 'web/js/app.js', code = WEB_PIECES[2].code }, messages[3].payload)
        assert.same({ count = 2 }, messages[4].payload)
        assert.equal('ready', VavaAtelier.loader.state())
        assert.equal(1, VavaAtelier.session.opened)
        assert.is_true(exported.isOpen())
    end)

    it('page déjà prête (pageReady à son chargement) : pas de hello', function()
        post('pageReady', {})
        f9()
        assert.same({ 'bootPiece', 'bootPiece', 'bootEnd' }, actions())
        assert.equal('ready', VavaAtelier.loader.state())
    end)

    it('second F9 de la séance : aucun RPC ; séance suivante, même empreinte : un seul RPC, aucun morceau', function()
        f9()
        local calls = #server.calls
        f9()
        assert.equal(calls, #server.calls)
        assert.is_false(VavaAtelier.session.isOpen())   -- la bascule de 1.3.0 : fermé
        f9()
        assert.equal(2, VavaAtelier.session.opened)
        -- nouvelle séance de jeu (reconnexion) : stockage local gardé
        server.calls, feeds, loads, messages = {}, {}, {}, {}
        page = makePage()
        boot()
        f9()
        assert.same({ { fp = '', part = 0 } }, server.calls)
        assert.same({}, feeds)
        assert.equal(3, #loads)
        assert.equal('ready', VavaAtelier.loader.state())
        assert.equal(1, VavaAtelier.session.opened)
    end)

    local ALTERED = {
        -- un octet du code d'un fichier : le paquet reste lisible, seule l'empreinte voit l'écart
        { 'un octet d\'un morceau', function() kvp['paquet:1'] = kvp['paquet:1']:gsub('opened = 0', 'opened = 9', 1) end },
        { 'un morceau manquant', function() kvp['paquet:2'] = nil end },
        { 'taille fausse', function() kvp['paquet:taille'] = kvp['paquet:taille'] + 1 end },
        { 'nombre de morceaux hors bornes', function() kvp['paquet:morceaux'] = 17 end },
        { 'empreinte gardée différente de l\'annoncée', function() kvp['paquet:empreinte'] = '0123456789abcdef' end },
    }
    for _, case in ipairs(ALTERED) do
        it('stockage altéré (' .. case[1] .. ') : effacé puis retéléchargé', function()
            f9()
            local before = kvp['paquet:1'] .. tostring(kvp['paquet:2']) .. kvp['paquet:empreinte'] .. kvp['paquet:taille']
                .. kvp['paquet:morceaux']
            case[2]()
            assert.not_equal(before, tostring(kvp['paquet:1']) .. tostring(kvp['paquet:2']) .. kvp['paquet:empreinte']
                .. kvp['paquet:taille'] .. kvp['paquet:morceaux'])
            server.calls, feeds, loads = {}, {}, {}
            page = makePage()
            boot()
            f9()
            assert.equal(3, partCalls())
            assert.same({ VavaAtelier.config.texts.loading }, feeds)
            assert.equal(server.fp, kvp['paquet:empreinte'])
            assert.equal(VavaAtelier.digest(server.text), VavaAtelier.digest((function()
                local parts = {}
                for i = 1, kvp['paquet:morceaux'] do parts[i] = kvp['paquet:' .. i] end
                return table.concat(parts)
            end)()))
            assert.equal('ready', VavaAtelier.loader.state())
            assert.equal(1, VavaAtelier.session.opened)   -- code d'origine (l'altéré compterait à partir de 9)
        end)
    end

    it('nouvelle version annoncée : le stockage de l\'ancienne n\'est pas exécuté, la nouvelle le remplace', function()
        f9()
        serve(concatLists({ LUA_PIECES[1], LUA_PIECES[2], LUA_PIECES[3] }, { WEB_PIECES[1] }))
        server.calls, loads = {}, {}
        page = makePage()
        boot()
        f9()
        assert.equal(1, partCalls())
        assert.equal(server.fp, kvp['paquet:empreinte'])
        assert.is_nil(kvp['paquet:2'])   -- morceaux en trop effacés
        assert.equal('ready', VavaAtelier.loader.state())
    end)

    it('morceaux reçus dont l\'empreinte diffère : rien d\'exécuté, rien de gardé', function()
        server.tamper = true
        f9()
        assert.equal(0, #loads)
        assert.is_nil(kvp['paquet:empreinte'])
        assert.same({ VavaAtelier.config.texts.loading, VavaAtelier.config.texts.refused.unavailable }, feeds)
        assert.equal('idle', VavaAtelier.loader.state())
        assert.truthy(logs.warn[1]:find('altéré', 1, true))
    end)

    it('description incohérente (empreinte, morceaux, taille) : rien demandé de plus', function()
        for _, bad in ipairs({ { fp = 'XYZ', parts = 1, bytes = 1 }, { fp = server.fp, parts = 9, bytes = 1 },
            { fp = server.fp, parts = 1, bytes = 65537 }, { fp = server.fp, parts = 1, bytes = 0 }, 'texte' }) do
            server.describe, server.calls = bad, {}
            f9()
            assert.equal(1, #server.calls)
            assert.equal(0, #loads)
        end
    end)

    it('stale une fois : reprise depuis la description ; deux fois : abandon', function()
        server.staleLeft = 1
        f9()
        assert.equal('ready', VavaAtelier.loader.state())
        assert.equal(2, #(function() local d = {} for _, c in ipairs(server.calls) do if c.part == 0 then d[#d + 1] = c end end return d end)())
        -- deux fois
        page = makePage()
        kvp = {}
        boot()
        server.calls, loads, feeds = {}, {}, {}
        server.staleLeft = 2
        f9()
        assert.equal(0, #loads)
        assert.equal('idle', VavaAtelier.loader.state())
        assert.same({ VavaAtelier.config.texts.loading, VavaAtelier.config.texts.loading,
            VavaAtelier.config.texts.refused.unavailable }, feeds)
    end)

    it('droit retiré pendant le téléchargement : arrêt, rien d\'exécuté, stockage effacé', function()
        kvp['paquet:empreinte'] = 'ancien'
        server.onCall = function(_, part) if part == 2 then server.allowed = false end end
        f9()
        assert.equal(0, #loads)
        assert.is_nil(kvp['paquet:empreinte'])
        assert.equal(VavaAtelier.config.texts.refused.not_allowed, feeds[#feeds])
    end)

    it('un fichier qui lève une erreur : failed, loadFailed, aucun fichier suivant ; F9 suivant sans RPC', function()
        serve(concatLists({ LUA_PIECES[1], { kind = 'L', name = 'client/drawing.lua', code = '\n\nerror("essai")\n' },
            LUA_PIECES[2], LUA_PIECES[3] }, WEB_PIECES))
        f9()
        assert.same({ 'config_conseil.lua' }, VavaAtelier.ran)
        assert.equal('failed', VavaAtelier.loader.state())
        assert.equal(VavaAtelier.config.texts.loadFailed, feeds[#feeds])
        assert.truthy(logs.error[1]:find('vava_atelier/client/drawing.lua:3: essai', 1, true), logs.error[1])
        assert.same({}, messages)
        local calls = #server.calls
        f9()
        assert.equal(calls, #server.calls)
        assert.equal(VavaAtelier.config.texts.loadFailed, feeds[#feeds])
    end)

    it('erreur de syntaxe : failed avec le nom et la ligne du fichier', function()
        serve(concatLists({ { kind = 'L', name = 'client/session.lua', code = 'local a = 1\nlocal = 2\n' } }, WEB_PIECES))
        f9()
        assert.equal('failed', VavaAtelier.loader.state())
        assert.truthy(logs.error[1]:find('vava_atelier/client/session.lua:2:', 1, true), logs.error[1])
    end)

    it('code précompilé (\\27Lua…) : refusé par le mode texte', function()
        serve(concatLists({ { kind = 'L', name = 'client/session.lua', code = '\27LuaT' } }, WEB_PIECES))
        f9()
        assert.equal('failed', VavaAtelier.loader.state())
        assert.equal('t', loads[1].mode)
        assert.truthy(logs.error[1]:find('mode', 1, true), logs.error[1])
    end)

    it('une globale posée par un fichier reste dans l\'environnement du paquet : _G intact, un avertissement', function()
        serve(concatLists({ LUA_PIECES[1], { kind = 'L', name = 'client/relay.lua', code = 'oubliee = 42\n' },
            LUA_PIECES[2], LUA_PIECES[3] }, WEB_PIECES))
        f9()
        assert.is_nil(rawget(_G, 'oubliee'))
        assert.equal(42, rawget(loads[1].env, 'oubliee'))
        assert.truthy(logs.warn[1]:find('oubliee', 1, true))
        assert.equal('ready', VavaAtelier.loader.state())
    end)

    it('séance ou outil absent après exécution : failed', function()
        serve(concatLists({ LUA_PIECES[1], LUA_PIECES[2] }, WEB_PIECES))
        f9()
        assert.equal('failed', VavaAtelier.loader.state())
        assert.same({}, messages)
    end)

    it('page muette : Lua prêt ; F9 suivant : la page seule, sans RPC', function()
        pageMode = 'mute'
        f9()
        assert.equal('luaReady', VavaAtelier.loader.state())
        assert.equal(0, VavaAtelier.session.opened)
        assert.equal(VavaAtelier.config.texts.refused.unavailable, feeds[#feeds])
        local calls, ran = #server.calls, #loads
        pageMode = 'normal'
        messages = {}
        f9()
        assert.equal(calls, #server.calls)
        assert.equal(ran, #loads)
        assert.same({ 'hello', 'bootPiece', 'bootPiece', 'bootEnd' }, actions())
        assert.equal('ready', VavaAtelier.loader.state())
        assert.equal(1, VavaAtelier.session.opened)
    end)

    it('compte rendu perdu : au F9 suivant, hello rend le même booted, rien n\'est renvoyé à la page', function()
        pageMode = 'lost'
        f9()
        assert.equal('luaReady', VavaAtelier.loader.state())
        messages = {}
        f9()
        assert.same({ 'hello' }, actions())
        assert.equal('ready', VavaAtelier.loader.state())
    end)

    it('compte rendu arrivé après l\'échéance : lu au F9 suivant sans rien demander', function()
        pageMode = 'lost'
        f9()
        post('booted', pageState.report)
        messages = {}
        f9()
        assert.same({}, messages)
        assert.equal('ready', VavaAtelier.loader.state())
    end)

    it('booted en erreur, ou d\'une autre forme : failed', function()
        pageMode = 'error'
        f9()
        assert.equal('failed', VavaAtelier.loader.state())
        assert.equal(VavaAtelier.config.texts.loadFailed, feeds[#feeds])
        assert.truthy(logs.error[1]:find('web/js/app.js', 1, true))
        -- compte faux
        page = makePage()
        kvp = {}
        boot()
        page = function(message)
            if message.action == 'hello' then post('pageReady', {}) end
            if message.action == 'bootEnd' then post('booted', { ok = true, count = 1 }) end
        end
        f9()
        assert.equal('failed', VavaAtelier.loader.state())
    end)

    it('F9 pendant le téléchargement : ignoré (une seule demande)', function()
        server.onCall = function(_, part) if part == 1 then f9() f9() end end
        f9()
        assert.equal(4, #server.calls)
        assert.equal('ready', VavaAtelier.loader.state())
        assert.equal(1, VavaAtelier.session.opened)
    end)

    it('forget (revoked) : stockage effacé', function()
        f9()
        assert.is_not_nil(kvp['paquet:empreinte'])
        VavaAtelier.loader.forget()
        assert.same({}, kvp)
    end)

    it('say traité sans paquet chargé ; isOpen faux, déchargement et arrêt sans erreur avant chargement', function()
        netHandlers[VavaAtelier.EVENTS.SAY]('Archives écrites.')
        assert.same({ 'Atelier', 'Archives écrites.' }, chat[1].payload.args)
        assert.is_false(exported.isOpen())
        hooks['core:character:unloaded']()
        stopHandlers.onClientResourceStop('vava_atelier')
        assert.equal(0, #server.calls)
        -- une fois chargé : les deux ferment la séance et lâchent l'outil
        f9()
        stopHandlers.onClientResourceStop('vava_atelier')
        assert.is_true(VavaAtelier.session.released)
        assert.is_true(VavaAtelier.placerReleased)
    end)

    it('transport en échec : refus montré, rien d\'effacé ni d\'exécuté', function()
        f9()
        server.transport = 'timeout'
        page = makePage()
        boot()
        loads, feeds = {}, {}
        f9()
        assert.equal(0, #loads)
        assert.same({ VavaAtelier.config.texts.refused.unavailable }, feeds)
        assert.is_not_nil(kvp['paquet:empreinte'])
    end)
end)
