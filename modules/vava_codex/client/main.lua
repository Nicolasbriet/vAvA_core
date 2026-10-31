--[[
    vava_codex/client/main.lua
    Rôle : le Codex côté joueur : ouverture par une touche (RegisterKeyMapping : réglable par le joueur, aucune
           boucle) ou /codex ; à chaque ouverture, le serveur reçoit les versions du contenu et des préférences que
           la page garde et ne renvoie que ce qui a changé (touches du joueur résolues ici à chaque fois) ; gestes
           de l'interface relayés au serveur (RPC à schéma strict), lancement d'une commande composée par
           ExecuteCommand (une commande du serveur y arrive comme si elle était tapée), export `noteCommand` pour que
           le chat inscrive aux dernières pages ce que le joueur tape lui-même, export `openAt` pour ouvrir le livre à
           un chapitre (1.4.0, accueil des nouveaux venus ; 1.5.0 : aussi une page ou un chapitre de lecture, résolus
           par la page), texte d'une page de lecture relayé à la demande (1.5.0). Souris et clavier rendus au jeu si la
           ressource s'arrête livre ouvert. Codex « en panneau » (1.7.0) : exports `openDocked(chapitre, rectangle)` et
           `closeDocked()`, réservés à la ressource hôte (`config.docked.host`, la bannière de vava_pause) : le livre se
           dessine dans le rectangle donné, sans voile, et le crochet client `vava_codex:closed` dit chaque fermeture
           (échec de l'ouverture compris) pour que l'hôte reprenne la main.
    Dépendances : shared/constants.lua, config_client.lua, shared/dock.lua, client/core.lua, client/nui.lua, client/keys.lua
]]

local type, tostring, pcall, ipairs = type, tostring, pcall, ipairs
local pack, unpack = table.pack, table.unpack
local match, sub = string.match, string.sub
local CreateThread, Wait, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, Wait, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local AddEventHandler, GetCurrentResourceName, GetInvokingResource = AddEventHandler, GetCurrentResourceName, GetInvokingResource
local IsPauseMenuActive, GetResourceState, ExecuteCommand, IsNuiFocused = IsPauseMenuActive, GetResourceState, ExecuteCommand, IsNuiFocused
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local RPC = VavaCodex.RPC
local READING = VavaCodex.READING
local EVENTS = VavaCodex.EVENTS
local HOOK_CLOSED = VavaCodex.HOOKS.CLOSED
local dock = VavaCodex.dock
local MAX_LINE = VavaCodex.MAX_LINE
local nui, keys = VavaCodex.nui, VavaCodex.keys

local RESOURCE = GetCurrentResourceName()
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'
-- après « Lancer » en restant ouvert : délai avant de reprendre le focus si aucune autre interface ne l'a pris
local REFOCUS_MS = 150

local open = false
local keepOpen = cfg.keepOpenDefault
-- 1.7.0 : rectangle du livre ouvert en panneau (nil : plein écran) ; ouverture en cours (réponse du serveur attendue)
-- et, pour une ouverture en panneau, son annulation par l'hôte (closeDocked) avant la réponse
local docked = nil
local opening = false
local dockCancelled = false

-- Ce que la page garde entre deux ouvertures : les empreintes données par le serveur avec le dernier contenu et les
-- dernières préférences qu'elle a reçus ('' : rien, ou changé par la page depuis), et les touches à relire.
local known = { version = '', prefsVersion = '', keyed = {} }

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

--- Crochet client `vava_codex:closed` (1.7.0) : l'hôte d'un livre en panneau reprend la main.
---@param wasDocked boolean
---@param reason string  close | run | failed | unloaded | stopped
local function closed(wasDocked, reason)
    core.hooks.runAfter(HOOK_CLOSED, { docked = wasDocked, reason = reason })
end

---@param reason? string  défaut : close
local function close(reason)
    if not open then return end
    open = false
    local wasDocked = docked ~= nil
    docked = nil
    nui.send('close')
    nui.setFocus(false)
    closed(wasDocked, reason or 'close')
end

--- Entrées liées à une touche, gardées pour relire à chaque ouverture la touche du joueur (sans le contenu entier).
---@param entries any
---@return { name: string, key: string, hold?: boolean, keyDisplay?: string }[]
local function keyedEntries(entries)
    local out = {}
    if type(entries) ~= 'table' then return out end
    for _, entry in ipairs(entries) do
        if type(entry) == 'table' and type(entry.name) == 'string' and type(entry.key) == 'string' then
            out[#out + 1] = { name = entry.name, key = entry.key, hold = entry.hold == true, keyDisplay = entry.keyDisplay }
        end
    end
    return out
end

--- Les touches du joueur, résolues ici (le serveur ne connaît que les défauts) : { [nom] = touche affichée }.
---@return table<string, string>
local function keyLabels()
    local labels = {}
    for _, entry in ipairs(known.keyed) do labels[entry.name] = keys.label(entry) end
    return labels
end

--- Range la réponse du serveur à l'ouverture et compose le message de la page : le contenu et les préférences
--- seulement s'ils sont arrivés (la page garde les précédents), les touches du joueur relues à chaque fois (elles se
--- changent dans les réglages du jeu, le serveur ne le sait pas), la touche de fermeture, le nombre de dernières
--- pages gardées. À n'appeler que si le message part aussitôt vers la page : `known` dit ce qu'elle a.
---@param answer table  { version, prefsVersion, content?, prefs? }
---@return table|nil message  nil : réponse incohérente (rien de gardé ; la prochaine ouverture redemande tout)
local function absorb(answer)
    local content, current = answer.content, answer.prefs
    if type(answer.version) ~= 'string' or type(answer.prefsVersion) ~= 'string'
        or (type(content) ~= 'table' and answer.version ~= known.version)
        or (type(current) ~= 'table' and answer.prefsVersion ~= known.prefsVersion) then
        known.version, known.prefsVersion = '', ''
        return nil
    end
    if type(content) == 'table' then
        known.version, known.keyed = answer.version, keyedEntries(content.entries)
    else
        content = nil
    end
    if type(current) == 'table' then
        known.prefsVersion = answer.prefsVersion
        keepOpen = current.keepOpen ~= false
    else
        current = nil
    end
    return {
        version = known.version, content = content, prefs = current, keys = keyLabels(),
        closeKey = cfg.keys.open, recentMax = cfg.recent.max,
    }
end

--- Ouvre le Codex : le serveur reçoit les versions que la page garde et ne renvoie que ce qui a changé, puis le livre
--- s'affiche. Rien n'est ouvert si la réponse manque. `focus` (1.4.0) : chapitre à ouvrir (export openAt), transmis à
--- la page ; nil pour F1 et /codex. `rect` (1.7.0) : rectangle du panneau (export openDocked, déjà validé), transmis
--- à la page (`dock`) ; nil : plein écran. Un échec rend la main à l'hôte par le crochet (`failed`) ; un livre en
--- panneau ne notifie rien, l'hôte dit lui-même que le Codex est fermé.
---@param focus? string
---@param rect? table
local function openCodex(focus, rect)
    if open or opening or not core.characters.current() or IsPauseMenuActive() then return end
    opening, dockCancelled = true, false
    local wantDock = rect ~= nil
    CreateThread(function()
        local ok, success, answer = core.rpc.call(RPC.OPEN, known.version, known.prefsVersion)
        opening = false
        if not ok or not success or type(answer) ~= 'table' then
            core.log.warn('Codex indisponible : %s', tostring(ok and answer or success))
            if not wantDock then feed(cfg.messages.unavailable, 'warning') end
            closed(wantDock, 'failed')
            return
        end
        -- rien n'est gardé d'une réponse qui n'ira pas à la page
        if wantDock and dockCancelled then
            closed(true, 'close')
            return
        end
        if open or not core.characters.current() or IsPauseMenuActive() then
            closed(wantDock, 'failed')
            return
        end
        local message = absorb(answer)
        if not message then
            core.log.warn('Codex : réponse incomplète, tout sera redemandé')
            if not wantDock then feed(cfg.messages.unavailable, 'warning') end
            closed(wantDock, 'failed')
            return
        end
        message.focus = focus
        message.dock = rect
        open = true
        docked = rect
        nui.send('open', message)
        nui.setFocus(true)
    end)
end

local function toggle()
    if open then close() else openCodex(nil) end
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
    known.prefsVersion = ''   -- la page note la ligne elle-même : ses préférences ne sont plus celles de l'empreinte
    local closing = d.ui == true or not keepOpen
    if closing then close('run') end
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
-- Un signet ou un réglage accepté change les préférences de la page : leur empreinte ne vaut plus, la prochaine
-- ouverture les redemande (celles du serveur font foi).

nui.on('options', function(d)
    return forward(RPC.OPTIONS, function(r, options) r.options = options end,
        tostring(d.name or ''), type(d.action) == 'string' and d.action or '', math.tointeger(tonumber(d.index or 0)) or 1)
end)
nui.on('favorite', function(d)
    return forward(RPC.FAVORITE, function(r, favorites)
        known.prefsVersion = ''
        r.favorites = favorites
    end, tostring(d.name or ''), d.on == true)
end)
nui.on('keepOpen', function(d)
    return forward(RPC.KEEP_OPEN, function(r, value)
        known.prefsVersion = ''
        keepOpen = value ~= false
        r.keepOpen = keepOpen
    end, d.value == true)
end)
nui.on('run', run)
-- Texte d'une page de lecture (1.5.0), demandé quand le joueur ouvre une page que la page ne garde pas encore. Le
-- serveur revérifie que le joueur peut la voir ; l'identifiant est vérifié ici pour ne rien relayer d'informe.
nui.on('page', function(d)
    local id = d.id
    if type(id) ~= 'string' or #id == 0 or #id > READING.MAX_ID or not match(id, READING.ID_PATTERN) then
        return { ok = false, error = 'invalid_request' }
    end
    return forward(RPC.PAGE, function(r, page) r.page = page end, id)
end)
-- La page n'a pas le contenu que les versions annoncent (secours). Sans aucun contenu : tout est redemandé, et rangé
-- comme à l'ouverture. Avec un contenu plus ancien : versions oubliées, sans appel au serveur ; la prochaine ouverture
-- renverra tout.
nui.on('stale', function()
    known.version, known.prefsVersion = '', ''
    return { ok = true }
end)
nui.on('refresh', function()
    local ok, success, answer = core.rpc.call(RPC.OPEN, '', '')
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(answer) } end
    local message = type(answer) == 'table' and absorb(answer) or nil
    if not message then return { ok = false, error = 'invalid_response' } end
    return { ok = true, payload = message }
end)
nui.on('close', function()
    close('close')
    return { ok = true }
end)

RegisterCommand(cfg.command, toggle, false)
RegisterKeyMapping(cfg.command, cfg.labels.open, 'keyboard', cfg.keys.open)

core.hooks.after('core:character:unloaded', function()
    close('unloaded')
    known.prefsVersion = ''   -- préférences propres au personnage : celles du suivant sont redemandées
end)

-- Arrêt de la ressource livre ouvert : la page disparaît avec elle, mais la souris et le clavier resteraient pris.
-- Arrêt de l'hôte (1.7.0) livre en panneau ouvert : le livre se referme, la main revient au jeu.
AddEventHandler('onClientResourceStop', function(resource)
    if resource == RESOURCE then
        if not open then return end
        local wasDocked = docked ~= nil
        open, docked = false, nil
        nui.setFocus(false)
        closed(wasDocked, 'stopped')
    elseif docked and cfg.docked and resource == cfg.docked.host then
        close('stopped')
    end
end)

--- Ouvre le Codex à un chapitre (1.4.0 ; vava_arrival à la première venue) : même chemin que F1 (RPC vava_codex:open,
--- empreintes, préférences), puis la page choisit le chapitre s'il existe (sinon le livre reste à son index). Depuis
--- 1.5.0, la page résout d'abord une page de lecture, puis un chapitre de lecture (`premiers_pas` : onglet Lecture,
--- première page du chapitre), puis un chapitre de commandes ; le motif accepte déjà ces identifiants.
--- `true` : ouverture lancée ; `false, code` : invalid_chapter (pas un identifiant de 64 octets au plus),
--- no_character, busy (livre déjà ouvert, menu pause, ou une autre interface a le focus).
---@param chapter string
---@return boolean ok
---@return string|nil code
---@param chapter any
---@return boolean
local function isChapter(chapter)
    return type(chapter) == 'string' and #chapter > 0 and #chapter <= VavaCodex.MAX_NAME
        and match(chapter, VavaCodex.NAME_PATTERN) ~= nil
end

exports('openAt', function(chapter)
    if not isChapter(chapter) then return false, 'invalid_chapter' end
    if not core.characters.current() then return false, 'no_character' end
    if open or opening or IsPauseMenuActive() or IsNuiFocused() then return false, 'busy' end
    openCodex(chapter)
    return true
end)

--- Seule la ressource hôte (`config.docked.host`) ouvre ou ferme le livre en panneau.
---@return boolean
local function fromHost()
    return type(cfg.docked) == 'table' and GetInvokingResource() == cfg.docked.host
end

--- Ouvre le Codex en panneau (1.7.0, bannière de vava_pause) : même chemin que F1 (RPC vava_codex:open, empreintes,
--- préférences), le livre dessiné dans `rect` ({ left, top, width, height } en vw et vh, shared/dock.lua), sans voile.
--- L'hôte rend le focus juste avant : l'ouverture ne se refuse pas parce qu'une interface a le focus. `chapter` : nil
--- (index) ou comme openAt. `true` : ouverture lancée, sa fin dite par le crochet `vava_codex:closed` ; `false, code` :
--- not_allowed (appelant autre que l'hôte), invalid_chapter, invalid_rect, no_character, busy (livre ouvert ou en
--- cours d'ouverture, menu de GTA ouvert).
---@param chapter string|nil
---@param rect table
---@return boolean ok
---@return string|nil code
exports('openDocked', function(chapter, rect)
    if not fromHost() then return false, 'not_allowed' end
    if chapter ~= nil and not isChapter(chapter) then return false, 'invalid_chapter' end
    local clean, code = dock.rect(rect)
    if not clean then return false, code end
    if not core.characters.current() then return false, 'no_character' end
    if open or opening or IsPauseMenuActive() then return false, 'busy' end
    openCodex(chapter, clean)
    return true
end)

--- Referme le livre s'il est en panneau, ou annule son ouverture en cours (1.7.0) ; le crochet le dit (`close`).
---@return boolean ok
---@return string|nil code  not_allowed
exports('closeDocked', function()
    if not fromHost() then return false, 'not_allowed' end
    if opening then dockCancelled = true end
    if open and docked then close('close') end
    return true
end)

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
