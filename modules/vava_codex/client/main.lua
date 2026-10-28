--[[
    vava_codex/client/main.lua
    Rôle : le Codex côté joueur : ouverture par une touche (RegisterKeyMapping : réglable par le joueur, aucune
           boucle) ou /codex, contenu demandé au serveur à chaque ouverture (touches du joueur résolues ici), gestes
           de l'interface relayés au serveur (RPC à schéma strict), lancement d'une commande composée par
           ExecuteCommand (une commande du serveur y arrive comme si elle était tapée), export `noteCommand` pour que
           le chat inscrive aux dernières pages ce que le joueur tape lui-même.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/keys.lua
]]

local type, tostring, pcall, ipairs = type, tostring, pcall, ipairs
local pack, unpack = table.pack, table.unpack
local match, sub = string.match, string.sub
local CreateThread, Wait, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, Wait, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState, ExecuteCommand, IsNuiFocused = IsPauseMenuActive, GetResourceState, ExecuteCommand, IsNuiFocused
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local RPC = VavaCodex.RPC
local EVENTS = VavaCodex.EVENTS
local MAX_LINE = VavaCodex.MAX_LINE
local nui, keys = VavaCodex.nui, VavaCodex.keys

local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'
-- après « Lancer » en restant ouvert : délai avant de reprendre le focus si aucune autre interface ne l'a pris
local REFOCUS_MS = 150

local open = false
local keepOpen = cfg.keepOpenDefault

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message hors de l'interface : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string
local function feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function close()
    if not open then return end
    open = false
    nui.send('close')
    nui.setFocus(false)
end

--- Les touches du joueur, résolues ici : le serveur ne connaît que les défauts.
---@param entries table[]
local function resolveKeys(entries)
    for _, entry in ipairs(entries) do
        if entry.kind == 'key' or entry.key then entry.keyLabel = keys.label(entry) end
    end
end

--- Ouvre le Codex : le contenu est demandé au serveur, puis affiché. Rien n'est ouvert s'il manque.
local function openCodex()
    if open or not core.characters.current() or IsPauseMenuActive() then return end
    CreateThread(function()
        local ok, success, payload = core.rpc.call(RPC.OPEN)
        if not ok or not success or type(payload) ~= 'table' then
            core.log.warn('Codex indisponible : %s', tostring(ok and payload or success))
            feed(cfg.messages.unavailable, 'warning')
            return
        end
        if open or not core.characters.current() or IsPauseMenuActive() then return end
        resolveKeys(payload.entries or {})
        payload.closeKey = cfg.keys.open
        keepOpen = payload.prefs and payload.prefs.keepOpen ~= false
        open = true
        nui.send('open', payload)
        nui.setFocus(true)
    end)
end

local function toggle()
    if open then close() else openCodex() end
end

--- Relaie un geste de l'interface au serveur ; `shape(réponse, …valeurs)` range les valeurs renvoyées dans la
--- réponse homogène { ok, error? } attendue par l'interface.
---@param name string
---@param shape? fun(response: table, ...: any)
---@return table
local function forward(name, shape, ...)
    local results = pack(core.rpc.call(name, ...))
    local ok, success = results[1], results[2]
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(results[3]) } end
    local response = { ok = true }
    if shape then shape(response, unpack(results, 3, results.n)) end
    return response
end

--- Lance une ligne composée par l'interface : notée aux dernières pages (le serveur revérifie le droit), puis
--- exécutée comme si elle était tapée. Une commande qui ouvre une interface ferme le Codex d'abord ; sinon le
--- réglage du joueur décide, et le focus revient au Codex si aucune autre interface ne l'a pris.
---@param d { name: string, action?: string, line: string, ui?: boolean }
---@return table
local function run(d)
    local name, line = d.name, d.line
    if type(name) ~= 'string' or type(line) ~= 'string' or #line == 0 or #line > MAX_LINE then return { ok = false, error = 'invalid_request' } end
    -- la ligne commence par la commande désignée : l'interface ne lance rien d'autre que ce qu'elle montre
    if match(line, '^(%S+)') ~= name then return { ok = false, error = 'invalid_request' } end
    local noted = forward(RPC.RECENT, nil, name, type(d.action) == 'string' and d.action or '')
    if not noted.ok then return noted end
    local closing = d.ui == true or not keepOpen
    if closing then close() end
    ExecuteCommand(line)
    if not closing then
        CreateThread(function()
            Wait(REFOCUS_MS)
            if open and not IsNuiFocused() then nui.setFocus(true) end
        end)
    end
    return { ok = true, closed = closing }
end

RegisterNetEvent(EVENTS.NOTIFY, function(message, kind)
    if type(message) ~= 'string' then return end
    if open then nui.send('notify', { message = message, kind = kind }) else feed(message, kind) end
end)

-- Gestes de l'interface ---------------------------------------------------------------------------------------------

nui.on('options', function(d)
    return forward(RPC.OPTIONS, function(r, options) r.options = options end,
        tostring(d.name or ''), type(d.action) == 'string' and d.action or '', math.tointeger(tonumber(d.index or 0)) or 1)
end)
nui.on('favorite', function(d)
    return forward(RPC.FAVORITE, function(r, favorites) r.favorites = favorites end, tostring(d.name or ''), d.on == true)
end)
nui.on('keepOpen', function(d)
    return forward(RPC.KEEP_OPEN, function(r, value)
        keepOpen = value ~= false
        r.keepOpen = keepOpen
    end, d.value == true)
end)
nui.on('run', run)
nui.on('refresh', function()
    return forward(RPC.OPEN, function(r, payload)
        if type(payload) == 'table' then
            resolveKeys(payload.entries or {})
            payload.closeKey = cfg.keys.open
        end
        r.payload = payload
    end)
end)
nui.on('close', function()
    close()
    return { ok = true }
end)

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, cfg.labels.open, 'keyboard', cfg.keys.open)

core.hooks.after('core:character:unloaded', close)

--- Une commande tapée ailleurs (chat) : inscrite aux dernières pages. `line` sans son « / » ; le serveur ignore ce
--- qu'il ne connaît pas ou ce que le joueur n'a pas le droit de lancer.
---@param line string
exports('noteCommand', function(line)
    if type(line) ~= 'string' then return end
    local name, action = match(line, '^/?(%S+)%s*(%S*)')
    if not name or name == '' then return end
    if sub(name, 1, 1) == '+' or sub(name, 1, 1) == '-' then return end
    core.rpc.emit(RPC.RECENT, name, action or '')
end)
