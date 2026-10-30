--[[
    server/core/netcommand.lua
    Rôle : commande du Conseil `/vava_reseau` (droit `tools` de vava_admin, repli ACE) : envois de la dernière minute,
           les plus lourds, ceux d'une ressource, ou ce que reçoit un joueur (suivi évènement par évènement, inscrit au
           journal du Registre) ; sortie dans le chat du seul membre, ou dans la console. Commande console
           `vava_reseau_essai` : mesure en jeu le débit réel du latent, l'ordre d'arrivée et l'envoi de proximité.
           Aucun RPC : rien n'entre par le réseau.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/string.lua, shared/core/logger.lua,
                  server/core/netstats.lua, server/core/net.lua, server/core/commands.lua ; vAvA.characters lu à
                  l'appel. Seule ressource extérieure lue : vava_admin (droit, journal), chaque appel isolé par pcall.
]]

local tonumber, tostring, type, pcall, print = tonumber, tostring, type, pcall, print
local tointeger, huge, max, min = math.tointeger, math.huge, math.max, math.min
local format, rep, match = string.format, string.rep, string.match
local RegisterCommand, GetResourceState, IsPlayerAceAllowed, DoesPlayerExist, GetGameTimer =
    RegisterCommand, GetResourceState, IsPlayerAceAllowed, DoesPlayerExist, GetGameTimer

local EVENTS = vAvA.EVENTS
local net = vAvA.net
local formatBytes = vAvA.netstats.formatBytes
local logger = vAvA.logger
local cfg = vAvA.config.server.net
local commandCfg = cfg.command
local texts = commandCfg.messages
local log = logger.create('net')

local CORE = vAvA.resourceName
local CONSOLE = 0
local CHAT_EVENT = 'chat:addMessage'
local PROBE = EVENTS.NET_PROBE
local LINES = max(1, min(20, commandCfg.lines))
local RESOURCE_MAX = 48
local RESOURCE_PATTERN = '^[%w_%-%.]+$'
local NUMBER_PATTERN = '^%d+$'
local NUMBER_MAX_DIGITS = 6
-- charge de l'essai : n Ko en tout pour le message (en-tête et nom de l'évènement compris)
local PROBE_OVERHEAD = 64

local netcommand = {}
vAvA.netcommand = netcommand

-- joueur → heure de sa dernière commande, membre ou non (oublié à son départ)
local lastUse = {}

---@param src integer
---@return boolean
local function allowed(src)
    if src == CONSOLE then return true end
    local admin = commandCfg.adminResource
    if GetResourceState(admin) == 'started' then
        local called, can = pcall(function() return exports[admin]:can(src, commandCfg.permission) end)
        return called and can == true
    end
    return IsPlayerAceAllowed(src, commandCfg.ace) == true
end

--- Une ligne au seul membre (chat), ou à la console.
---@param src integer
---@param line string
local function say(src, line)
    if src == CONSOLE then
        print(texts.author .. ' : ' .. line)
        return
    end
    net.dispatch(CORE, CHAT_EVENT, src, net.NEVER, CHAT_EVENT, { args = { texts.author, line } })
end

---@param text any
---@return integer|nil
local function readNumber(text)
    if type(text) ~= 'string' or #text > NUMBER_MAX_DIGITS or not match(text, NUMBER_PATTERN) then return nil end
    return tointeger(tonumber(text))
end

---@param src integer
---@param events table[]
local function sayEvents(src, events)
    for i = 1, #events do
        local event = events[i]
        say(src, format(texts.line, i, event.resource, event.label, event.messages, formatBytes(event.bytes),
            formatBytes(event.largest), event.latent > 0 and format(texts.lineLatent, event.latent) or ''))
    end
end

---@param src integer
---@param stats table
local function sayHeader(src, stats)
    local total = stats.total
    say(src, format(texts.header, stats.mode == 'exact' and texts.modeExact or texts.modeEstimate,
        total.messages, formatBytes(total.bytes), total.latent))
end

--- Vue d'ensemble, ou d'une seule ressource.
---@param src integer
---@param resource string|nil
local function overview(src, resource)
    local stats = net.stats({ limit = LINES, resource = resource })
    if not stats then return end
    sayHeader(src, stats)
    if #stats.events == 0 then say(src, texts.empty) else sayEvents(src, stats.events) end
    say(src, texts.footer)
end

---@param target integer
---@return string
local function playerLabel(target)
    local characters = vAvA.characters
    local info = characters and characters.describeActive(target)
    if not info then return texts.noCharacter end
    return info.firstName .. ' ' .. info.lastName
end

--- Suivi d'un joueur inscrit au journal du Registre (console : journal du serveur).
---@param src integer
---@param target integer
local function journal(src, target)
    local admin = commandCfg.adminResource
    if src ~= CONSOLE and GetResourceState(admin) == 'started' then
        local called, ok = pcall(function() return exports[admin]:log(src, 'Réseau d\'un joueur suivi', { joueur = target }) end)
        if called and ok == true then return end
    end
    log.info('réseau du joueur %d consulté (par %d)', target, src)
end

---@param src integer
---@param target integer
local function playerView(src, target)
    local stats = net.stats({ limit = LINES, target = target })
    if not stats then return end
    journal(src, target)
    say(src, format(texts.player, target, playerLabel(target), stats.total.messages, formatBytes(stats.total.bytes)))
    if stats.watched then
        if #stats.events == 0 then say(src, texts.empty) else sayEvents(src, stats.events) end
    else
        local started = net.watch(target)
        if started then
            say(src, format(texts.watchStarted, cfg.counter.watchMs // 60000))
        else
            say(src, format(texts.watchFull, cfg.counter.maxWatched))
        end
    end
    say(src, texts.footer)
end

---@param source any
---@param args string[]
local function onCommand(source, args)
    local src = tonumber(source) or CONSOLE
    -- délai avant le droit : une commande tapée en boucle ne coûte pas un appel à vava_admin par frappe
    if src ~= CONSOLE then
        local now = GetGameTimer()
        local last = lastUse[src]
        if last and now - last < commandCfg.cooldownMs then return end
        lastUse[src] = now
    end
    if not allowed(src) then return end
    args = type(args) == 'table' and args or {}
    local action = args[1]
    if action == nil then return overview(src, nil) end
    if action == 'joueur' then
        local target = readNumber(args[2])
        if not target then return say(src, texts.usage) end
        if target <= 0 or not DoesPlayerExist(target) then return say(src, format(texts.unknownPlayer, args[2])) end
        return playerView(src, target)
    end
    if action == 'ressource' then
        local resource = args[2]
        if type(resource) ~= 'string' or #resource > RESOURCE_MAX or not match(resource, RESOURCE_PATTERN) then
            return say(src, texts.usage)
        end
        return overview(src, resource)
    end
    say(src, texts.usage)
end

---@param text string|nil
---@return number|nil radius
---@return boolean ok  false : rayon donné mais refusé
local function readRadius(text)
    if text == nil then return nil, true end
    local radius = tonumber(text)
    if not radius or radius ~= radius or radius == huge or radius <= 0 or radius > cfg.near.maxRadius then
        return nil, false
    end
    return radius, true
end

--- Essai du réseau (console seulement) : n° 1 fiable, n° 2 de n Ko toujours latent, n° 3 fiable au joueur, ou aux
--- joueurs à portée de lui si un rayon est donné. Le client écrit en console F8 l'heure d'arrivée et l'ordre.
---@param source any
---@param args string[]
local function onProbe(source, args)
    if tonumber(source) ~= CONSOLE then return end
    args = type(args) == 'table' and args or {}
    local target, kb = readNumber(args[1]), readNumber(args[2])
    local radius, radiusOk = readRadius(args[3])
    if not target or not kb or kb < 1 or kb > commandCfg.probeMaxKb or not radiusOk then
        return print(texts.probeUsage)
    end
    if target <= 0 or not DoesPlayerExist(target) then return print(format(texts.probeRefused, 'invalid_target')) end
    local packet, code = net.prepare(CORE, PROBE, PROBE, 2, 'bulk', rep('x', kb * 1024 - PROBE_OVERHEAD))
    if not packet then return print(format(texts.probeRefused, code)) end
    -- refus avant tout envoi : le client n'attend pas un essai qui ne viendra pas
    if net.wouldSaturate(target, packet.bytes) then return print(format(texts.probeRefused, 'saturated')) end
    local center
    if radius then
        center = net.positionOf(target)
        if not center then return print(format(texts.probeRefused, 'invalid_coords')) end
    end
    net.dispatch(CORE, PROBE, target, net.NEVER, PROBE, 1, 'start')
    local ok, err = net.deliver(CORE, PROBE, target, net.ALWAYS, packet)
    if not ok then return print(format(texts.probeRefused, tostring(err))) end
    if radius then
        local _, count = net.dispatchNear(CORE, PROBE, net.NEVER, center, radius, PROBE, 3, 'near')
        print(format(texts.probeSent, target, kb, type(count) == 'number' and count or 0, radius))
    else
        net.dispatch(CORE, PROBE, target, net.NEVER, PROBE, 3, 'after')
        print(format(texts.probeSentAlone, target, kb))
    end
end

--- Oublie le délai d'un membre parti.
---@param src integer
function netcommand.purgePlayer(src)
    lastUse[src] = nil
end

--- Enregistre les deux commandes et les déclare au registre core:commands (Codex). Appelé par init.lua, core prêt.
function netcommand.start()
    -- droit vérifié par la commande elle-même (vava_admin ou ACE) : pas de restriction ACE de FiveM
    RegisterCommand(commandCfg.name, onCommand, false)
    -- console seulement (la commande ignore aussi tout joueur)
    RegisterCommand(commandCfg.probeName, onProbe, true)
    local maxRadius = cfg.near.maxRadius
    local ok, err = vAvA.commands.declare(commandCfg.name, {
        kind = 'command', scope = 'admin', permission = commandCfg.permission, ace = commandCfg.ace,
        label = 'Compteur réseau',
        description = 'Évènements envoyés aux joueurs pendant la dernière minute, par module.',
        actions = {
            { label = 'Les plus gros envois' },
            { id = 'joueur', label = 'Ce que reçoit un joueur', args = { { name = 'joueur', type = 'player' } } },
            { id = 'ressource', label = 'Envois d\'un module',
                args = { { name = 'ressource', type = 'text', hint = 'nom de la ressource' } } },
        },
    })
    if not ok then log.warn('%s non déclarée au registre des commandes : %s', commandCfg.name, tostring(err)) end
    ok, err = vAvA.commands.declare(commandCfg.probeName, {
        kind = 'command', scope = 'console', label = 'Essai du réseau',
        description = 'Envoie au joueur un message latent de la taille voulue, entre deux messages fiables ; '
            .. 'sa console F8 dit le débit et l\'ordre d\'arrivée.',
        args = {
            { name = 'joueur', type = 'player' },
            { name = 'Ko', type = 'integer', min = 1, max = commandCfg.probeMaxKb },
            { name = 'rayon', type = 'number', min = 1, max = maxRadius, optional = true },
        },
    })
    if not ok then log.warn('%s non déclarée au registre des commandes : %s', commandCfg.probeName, tostring(err)) end
end
