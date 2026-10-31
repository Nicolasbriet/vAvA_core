--[[
    vava_pause/client/main.lua
    Rôle : la bannière du royaume côté joueur :
      - ouverture sur Échap ou P (client/intercept.lua) : porte (shared/gate.lua), une seule demande au serveur
        (RPC vava_pause:open), attendue un instant puis la bannière se déroule, les données suivent ; refus du serveur
        (combat, ligoté, crochet) : repli et message ; à terre (décision 2) : bannière réduite ;
      - veille pendant qu'elle est ouverte (à terre, ligoté, coup reçu, personnage perdu) ;
      - rubriques : Codex en panneau (vava_codex openDocked, crochet vava_codex:closed), carte et paramètres du jeu
        (client/native.lua), fiche complète, réglages (client/settings.lua), Conseil (RPC vava_pause:council), Quitter
        (RPC vava_pause:leave, commande « quit ») ;
      - exports client isOpen, close, block ; crochet vava_pause:state ; commande d'essai du ligotage (facultative).
    Dépendances : shared/, config_client.lua, tous les autres fichiers client/ du module
]]

local type, tostring, pairs, ipairs, pcall = type, tostring, pairs, ipairs, pcall
local match, mathType = string.match, math.type
local pack = table.pack
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local AddEventHandler, RegisterCommand, ExecuteCommand = AddEventHandler, RegisterCommand, ExecuteCommand
local GetInvokingResource, GetResourceState, GetCurrentResourceName = GetInvokingResource, GetResourceState, GetCurrentResourceName
local PlayerPedId, IsPedCuffed, SetEnableHandcuffs = PlayerPedId, IsPedCuffed, SetEnableHandcuffs
local IsScreenFadedOut, IsScreenFadingOut, IsPauseMenuActive, IsNuiFocused =
    IsScreenFadedOut, IsScreenFadingOut, IsPauseMenuActive, IsNuiFocused
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config
local messages = cfg.messages
local RPC, HOOKS, LISTENED, BLOCK = VavaPause.RPC, VavaPause.HOOKS, VavaPause.LISTENED, VavaPause.BLOCK
local nui, sources, store, native = VavaPause.nui, VavaPause.sources, VavaPause.store, VavaPause.native
local intercept, gamepad = VavaPause.intercept, VavaPause.gamepad
local gate, plaque = VavaPause.gate, VavaPause.plaque

local RESOURCE = GetCurrentResourceName()
local HUD, VOICE, ADMIN = 'vava_hud', 'vava_voice', 'vava_admin'
local CODEX = cfg.codex.resource
local QUIT_COMMAND = 'quit'
local FEED_TEXT = 'STRING'
local DEFAULT_RUBRIC, DOWNED_RUBRIC = 'personnage', 'quitter'

local RUBRICS, KINDS, MODES = {}, {}, {}
for _, id in ipairs(VavaPause.RUBRICS) do RUBRICS[id] = true end
for _, id in ipairs(VavaPause.KINDS) do KINDS[id] = true end
for _, id in ipairs(VavaPause.LEAVE_MODES) do MODES[id] = true end

-- État de la bannière. `run` change à chaque ouverture et fermeture : une réponse ou une veille d'une session
-- passée n'agit plus.
local state = {
    open = false, opening = false, run = 0, mode = 'full',
    rubric = DEFAULT_RUBRIC, lastRubric = DEFAULT_RUBRIC,
    codex = false, native = false, baseline = nil,
}
-- Gardé jusqu'au déchargement du personnage : liste des touches et sa version ; dernier instantané reçu (repris si
-- le serveur refuse pour débit).
local keysCache = { version = '', list = nil }
local last = { data = nil, at = nil }
-- Version de la liste des touches que la page a déjà (relecture réseau R-4 : la liste ne repart que si elle change).
local sentKeys = ''
-- Dernier refus du serveur encore valable { reason, untilMs } (relecture réseau R-1) : refusé sur place jusque-là.
local verdict = nil
-- Blocages posés par d'autres modules : `<ressource>:<id>` → { owner, kind }.
local blocks, blockCount = {}, 0
-- Refus déjà montrés (raison → moment), pour ne pas les répéter.
local notices = {}

-- Messages hors de la bannière -------------------------------------------------------------------------------------

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string
local function feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Message d'un refus (raison de la porte ou du serveur), une fois par `noticeMs`.
---@param reason string
local function notifyRefusal(reason)
    -- refus d'un crochet du serveur (busy) : même message qu'un blocage
    local key = reason == 'busy' and 'blocked' or reason
    local text = messages.refused[key]
    if text and gate.shouldNotify(notices, key, GetGameTimer(), cfg.intercept.noticeMs) then feed(text, 'warning') end
end

-- Données de la page -------------------------------------------------------------------------------------------------

--- Touches du joueur, relues dans le jeu : { [nom] = touche affichée }.
---@return table<string, string>
local function keyLabels()
    local labels = {}
    for _, entry in ipairs(keysCache.list or {}) do labels[entry.name] = sources.keyLabel(entry) end
    return labels
end

--- Ce que le client lit lui-même : nom, vie, faim, soif, plaque (heure, saison), voix.
---@return table
local function localData()
    local character = core.characters.current()
    local health, needs = sources.health(), sources.needs()
    local P = cfg.plaque
    local hour = sources.hour()
    return {
        name = character and (tostring(character.firstName) .. ' ' .. tostring(character.lastName)) or '',
        health = health and health.health or nil,
        hunger = needs and needs.hunger or nil,
        thirst = needs and needs.thirst or nil,
        plaque = { time = plaque.time(hour, P.periods, P.timeFormat), season = plaque.season(sources.season(), P.seasons) },
        voice = sources.voice(),
    }
end

--- Instantané du serveur mis en forme pour la page ; les touches reçues sont gardées (sinon, celles gardées).
---@param answer table
---@return table
local function format(answer)
    if answer.downed == true then return { downed = true } end
    if type(answer.keys) == 'table' and type(answer.keysVersion) == 'string' then
        keysCache.version, keysCache.list = answer.keysVersion, answer.keys
    elseif answer.keysVersion ~= keysCache.version then
        keysCache.version, keysCache.list = '', nil   -- incohérent : tout sera redemandé
    end
    local people = mathType(answer.people) == 'integer' and answer.people or nil
    return {
        downed = false,
        skills = type(answer.skills) == 'table' and answer.skills or {},
        guild = type(answer.guild) == 'table' and answer.guild or nil,
        people = people,
        plaque = { people = people and plaque.people(people, cfg.plaque.people) or nil },
        council = answer.council == true,
        request = type(answer.request) == 'table' and answer.request or nil,
    }
end

--- Copie de données pour la page, avec la liste des touches seulement si la page ne l'a pas encore dans cette version
--- (absente : la page garde la sienne).
---@param data table
---@return table
local function withKeys(data)
    local copy = {}
    for key, value in pairs(data) do copy[key] = value end
    if keysCache.list and keysCache.version ~= sentKeys then
        copy.keys = keysCache.list
        sentKeys = keysCache.version
    end
    return copy
end

--- Réponse du RPC d'ouverture : 'ok', données | 'refused', raison | 'rate_limited' | 'failed'. Un refus est gardé
--- (`verdict`) : pour un combat, le temps restant donné par le serveur ; sinon `noticeMs`.
---@param reply table  résultats de core.rpc.callWith (table.pack)
---@return string outcome
---@return any value
local function interpret(reply)
    local ok, success, value = reply[1], reply[2], reply[3]
    if not ok then return success == 'rate_limited' and 'rate_limited' or 'failed' end
    if not success then
        if value == 'combat' or value == 'restrained' or value == 'busy' or value == 'no_character' then
            if value ~= 'no_character' then
                verdict = gate.remember(value, reply[4], GetGameTimer(), cfg.intercept.noticeMs)
            end
            return 'refused', value
        end
        return 'failed'
    end
    verdict = nil
    if type(value) ~= 'table' then return 'failed' end
    local data = format(value)
    last.data, last.at = data, GetGameTimer()
    return 'ok', data
end

--- Instantané précédent s'il a moins de `reuseMs`, ou nil.
---@return table|nil
local function reusable()
    if last.data and last.at and GetGameTimer() - last.at < cfg.open.reuseMs then return last.data end
    return nil
end

-- Ouverture et fermeture ---------------------------------------------------------------------------------------------

local function isOpen()
    return state.open
end

local function closeDocked()
    sources.call(CODEX, 'closeDocked')
end

--- Replie la bannière ; `message` : notification après le repli.
---@param message? string
local function close(message)
    if not state.open then return end
    state.open = false
    state.run = state.run + 1
    nui.send('close')
    nui.setFocus(false)
    intercept.touch()
    if state.codex then
        state.codex = false
        closeDocked()
    end
    core.hooks.runAfter(HOOKS.STATE, { open = false })
    if message then feed(message, 'warning') end
end

--- Veille de la bannière ouverte (500 ms) : personnage perdu, à terre (bannière entière), ligoté, coup reçu.
---@param run integer
local function watch(run)
    CreateThread(function()
        while state.open and state.run == run do
            Wait(cfg.open.watchMs)
            if not state.open or state.run ~= run then return end
            local health = sources.health()
            if not intercept.armed() then
                close()
            elseif state.mode == 'full' and health and health.downed then
                close(messages.interrupted)
            elseif IsPedCuffed(PlayerPedId()) then
                close(messages.refused.restrained)
            elseif health and state.baseline then
                if state.baseline - health.health >= cfg.open.hitDrop then
                    close(messages.interrupted)
                elseif health.health > state.baseline then
                    state.baseline = health.health
                end
            end
        end
    end)
end

--- Direction lue à la manette : à la page, sauf pendant un menu natif ou le Codex en panneau.
---@param direction string
local function onNav(direction)
    if state.native then return end
    if direction == 'resume' then
        close()
    elseif state.codex then
        if direction == 'back' then closeDocked() end
    else
        nui.send('nav', { dir = direction })
    end
end

--- Déroule la bannière : `mode` 'full' ou 'downed', `data` mise en forme (nil : à venir), `failed` : rien du serveur.
---@param mode string
---@param data table|nil
---@param failed boolean
local function show(mode, data, failed)
    state.open = true
    state.run = state.run + 1
    state.mode = mode
    state.rubric = mode == 'downed' and DOWNED_RUBRIC or DEFAULT_RUBRIC
    state.lastRubric = state.rubric
    state.codex, state.native = false, false
    state.labelsSent = keysCache.list ~= nil
    local health = sources.health()
    state.baseline = health and health.health or nil
    -- false : le registre ne répond pas ; absente : il se consulte (les données suivront)
    local served = data and withKeys(data) or nil
    if failed then served = false end
    local message = {
        rubric = state.rubric,
        ['local'] = localData(),
        data = served,
        settings = { defs = store.definitions(), values = store.values() },
        -- touches liées relues une fois par ouverture (R-4), ici si la liste est connue, sinon avec les données
        keyLabels = keysCache.list and keyLabels() or nil,
        resources = {
            codex = sources.started(CODEX), sheet = sources.started(cfg.sheet.resource),
            voice = sources.started(VOICE), council = sources.started(ADMIN),
        },
        closeKey = cfg.closeKey,
        gamepad = gamepad.inUse(),
        -- ajouts au contrat du § 9.10, communs avec la page (rapports de T-145) : forme réduite à terre, teintes et
        -- durée du déroulé lues dans config_client.lua
        downed = mode == 'downed',
        royal = cfg.royal,
        rankInks = cfg.rankInks,
        rollMs = cfg.open.rollMs,
    }
    nui.setFocus(true)
    nui.send('open', message)
    core.hooks.runAfter(HOOKS.STATE, { open = true })
    gamepad.start(isOpen, onNav, function() return state.native or state.codex end)
    watch(state.run)
end

--- Réponse arrivée après le déroulé.
---@param run integer
---@param reply table
local function late(run, reply)
    local outcome, value = interpret(reply)
    if not state.open or state.run ~= run then return end
    local refusal = outcome == 'refused' and value or nil
    local reuse = nil
    if outcome == 'rate_limited' then
        -- débit dépassé : jamais d'ouverture contre un refus encore valable (R-1)
        local allowed, how = gate.onRateLimited(verdict, GetGameTimer(), reusable() ~= nil)
        if allowed then reuse = how else refusal = how end
    end
    if outcome == 'ok' then
        state.mode = value.downed and 'downed' or 'full'
        local data = withKeys(value)
        if not state.labelsSent and keysCache.list then
            data.keyLabels = keyLabels()
            state.labelsSent = true
        end
        nui.send('data', data)
    elseif refusal then
        nui.send('refused', { reason = refusal })
        close()
        notifyRefusal(refusal)
    else
        local reused = reuse == 'reuse' and reusable() or nil
        nui.send('data', reused and withKeys(reused) or { unavailable = true })
    end
end

--- Appui sur Échap ou P : porte, demande au serveur, déroulé.
local function tryOpen()
    if state.opening then return end
    local character = intercept.armed() and core.characters.current() ~= nil
    local kinds = {}
    for key, block in pairs(blocks) do kinds[key] = block.kind end
    local ok, how, muted = gate.decide({
        open = state.open, character = character, faded = IsScreenFadedOut() or IsScreenFadingOut(),
        native = IsPauseMenuActive() or native.active(), focused = IsNuiFocused(), now = GetGameTimer(),
        lastFocusAt = intercept.lastFocusAt(), graceMs = cfg.intercept.graceMs,
        cuffed = IsPedCuffed(PlayerPedId()), downed = sources.downed(), blocks = kinds,
    })
    if not ok then
        if not muted then notifyRefusal(how) end
        return
    end
    -- dernier refus du serveur encore valable (combat : jusqu'à la fin de la fenêtre) : refusé sur place, sans
    -- redemander ni dérouler (relecture réseau R-1)
    local standing = gate.standing(verdict, GetGameTimer())
    if standing then
        notifyRefusal(standing)
        return
    end
    if not nui.isReady() then
        if gate.shouldNotify(notices, 'unavailable', GetGameTimer(), cfg.intercept.noticeMs) then
            feed(messages.unavailable, 'warning')
        end
        return
    end
    state.opening = true
    local run = state.run
    local reply, waitingLate = nil, nil
    -- la réponse ou l'échéance de `waitMs`, la première des deux (aucune attente par image)
    local arrived, settled = promise.new(), false
    local function settle(value)
        if settled then return end
        settled = true
        arrived:resolve(value)
    end
    CreateThread(function()
        reply = pack(core.rpc.callWith({ timeout = cfg.open.timeoutMs }, RPC.OPEN, keysCache.version))
        settle(true)
        if waitingLate then late(waitingLate, reply) end
    end)
    SetTimeout(cfg.open.waitMs, function() settle(false) end)
    Citizen.Await(arrived)
    state.opening = false
    if state.open or state.run ~= run then return end
    if reply then
        local outcome, value = interpret(reply)
        if outcome == 'ok' then
            show(value.downed and 'downed' or 'full', value, false)
        elseif outcome == 'refused' then
            if value ~= 'no_character' then notifyRefusal(value) end
        elseif outcome == 'rate_limited' then
            local allowed, mode = gate.onRateLimited(verdict, GetGameTimer(), reusable() ~= nil)
            if not allowed then
                notifyRefusal(mode)
            else
                local reused = mode == 'reuse' and reusable() or nil
                show(reused and (reused.downed and 'downed' or 'full') or how, reused, reused == nil)
            end
        else
            show(how, nil, true)
        end
        return
    end
    -- pas encore de réponse : la bannière se déroule, les données suivront
    show(how, nil, false)
    waitingLate = state.run
end

intercept.bind(isOpen, function()
    if not state.opening then CreateThread(tryOpen) end
end)

-- Rappels de la page -------------------------------------------------------------------------------------------------

local UNAVAILABLE = { ok = false, error = 'unavailable' }

--- Rubrique réservée à la bannière entière (absente à terre).
---@return boolean
local function full()
    return state.open and state.mode == 'full'
end

nui.on('close', function()
    close()
    return { ok = true }
end)

nui.on('rubric', function(d)
    if not RUBRICS[d.id] then return { ok = false, error = 'invalid_rubric' } end
    state.rubric = d.id
    if d.id ~= 'codex' then state.lastRubric = d.id end
    return { ok = true }
end)

nui.on('codex', function()
    if not full() or not sources.started(CODEX) then return UNAVAILABLE end
    if state.codex then return { ok = true } end
    if state.native then return { ok = false, error = 'busy' } end
    nui.setFocus(false)
    local called, opened, code = sources.call(CODEX, 'openDocked', nil, cfg.codex.rect)
    if not called or opened ~= true then
        nui.setFocus(true)
        return { ok = false, error = called and tostring(code) or 'unavailable' }
    end
    state.codex = true
    return { ok = true }
end)

--- Menu natif depuis la bannière : la page se masque (`native`), le focus revient à son retour.
---@param kind string
---@return table
local function openNative(kind)
    if state.native or state.codex then return { ok = false, error = 'busy' } end
    local run = state.run
    state.native = true
    nui.send('native', { hidden = true })
    nui.setFocus(false)
    local started = native.open(kind, function()
        state.native = false
        if state.open and state.run == run then
            nui.setFocus(true)
            nui.send('native', { hidden = false })
        end
    end)
    if not started then
        state.native = false
        nui.setFocus(true)
        nui.send('native', { hidden = false })
        return { ok = false, error = 'busy' }
    end
    return { ok = true }
end

nui.on('map', function()
    if not full() then return UNAVAILABLE end
    return openNative('map')
end)
nui.on('gameSettings', function()
    if not state.open then return UNAVAILABLE end
    return openNative('settings')
end)
nui.on('keyBindings', function()
    if not full() then return UNAVAILABLE end
    return openNative('keymapping')
end)

nui.on('sheet', function()
    if not full() or not sources.started(cfg.sheet.resource) then return UNAVAILABLE end
    close()
    -- au tour suivant : le focus de la bannière est rendu avant que le livre ne le prenne
    SetTimeout(0, function() ExecuteCommand(cfg.sheet.command) end)
    return { ok = true }
end)

nui.on('setting', function(d)
    if type(d.key) ~= 'string' or #d.key > VavaPause.MAX_SETTING_KEY then return { ok = false, error = 'unknown_setting' } end
    local ok, value = store.set(d.key, d.value)
    if not ok then return { ok = false, error = value } end
    return { ok = true, value = value }
end)

nui.on('resetSettings', function()
    return { ok = true, values = store.reset() }
end)

nui.on('council', function(d)
    if not full() then return UNAVAILABLE end
    local text = d.text
    if not KINDS[d.kind] then return { ok = false, error = 'invalid_kind' } end
    if type(text) ~= 'string' or #text > VavaPause.MAX_COUNCIL_TEXT then return { ok = false, error = 'invalid_text' } end
    if #text == 0 then return { ok = false, error = 'too_short' } end
    if type(d.withPosition) ~= 'boolean' then return { ok = false, error = 'invalid_request' } end
    local ok, success, value, seconds = core.rpc.call(RPC.COUNCIL, d.kind, text, d.withPosition)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then
        return { ok = false, error = tostring(value), wait = mathType(seconds) == 'integer' and seconds or nil }
    end
    if type(value) ~= 'table' then return { ok = false, error = 'invalid_response' } end
    if last.data then last.data.request = value end
    return { ok = true, request = value }
end)

nui.on('leave', function(d)
    if not state.open or not MODES[d.mode] then return { ok = false, error = 'invalid_mode' } end
    if d.mode == 'disconnect' then
        local ok, success, code = core.rpc.call(RPC.LEAVE, 'disconnect')
        if not ok then return { ok = false, error = tostring(success) } end
        if not success then return { ok = false, error = tostring(code) } end
        return { ok = true }
    end
    -- quitter le jeu : la commande du jeu, puis, si le jeu tourne encore, le serveur déconnecte avec un message
    CreateThread(function()
        ExecuteCommand(QUIT_COMMAND)
        Wait(cfg.quit.fallbackMs)
        core.rpc.call(RPC.LEAVE, 'quit')
    end)
    return { ok = true }
end)

-- Codex en panneau ---------------------------------------------------------------------------------------------------

--- Le Codex en panneau s'est refermé (ou n'a pas pu s'ouvrir) : `run` ferme aussi la bannière (la commande lancée ouvre
--- peut-être une interface) ; sinon le focus revient à la bannière, sur la rubrique d'avant.
---@param reason string
local function codexClosed(reason)
    if not state.codex then return end
    state.codex = false
    if not state.open then return end
    if reason == 'run' then
        close()
        return
    end
    state.rubric = state.lastRubric
    nui.setFocus(true)
    nui.send('codexClosed', { rubric = state.lastRubric, reason = reason })
end

core.hooks.after(LISTENED.CODEX_CLOSED, function(payload)
    if type(payload) == 'table' and payload.docked == true then codexClosed(tostring(payload.reason)) end
end)

-- Exports ------------------------------------------------------------------------------------------------------------

exports('isOpen', function()
    return state.open
end)

--- Replie la bannière (arrestation, cinématique…).
exports('close', function()
    close()
    return true
end)

--- Pose (`on = true`) ou lève un blocage : tant qu'il est posé, la bannière ne se déploie pas (refus `restrained`,
--- `combat` ou `blocked` selon `kind`) ; le poser replie la bannière ouverte. Levé à l'arrêt de la ressource appelante.
--- `true` ou `false, code` : invalid_id (`^[%w_]+$`, 32 octets), invalid_kind, too_many (16 blocages).
---@param id string
---@param on boolean
---@param kind? string  restrained | combat | other (défaut)
exports('block', function(id, on, kind)
    if type(id) ~= 'string' or #id == 0 or #id > BLOCK.MAX_ID or not match(id, BLOCK.ID_PATTERN) then
        return false, 'invalid_id'
    end
    if kind ~= nil and not BLOCK.KINDS[kind] then return false, 'invalid_kind' end
    local owner = GetInvokingResource() or RESOURCE
    local key = owner .. ':' .. id
    if on then
        if not blocks[key] then
            if blockCount >= BLOCK.MAX then return false, 'too_many' end
            blockCount = blockCount + 1
        end
        blocks[key] = { owner = owner, kind = kind or 'other' }
        if state.open then
            close(kind == 'restrained' and messages.refused.restrained or kind == 'combat' and messages.interrupted or nil)
        end
    elseif blocks[key] then
        blocks[key] = nil
        blockCount = blockCount - 1
    end
    return true
end)

-- Personnage et ressources -------------------------------------------------------------------------------------------

local function disarm()
    intercept.arm(false)
    close()
    keysCache.version, keysCache.list = '', nil
    last.data, last.at = nil, nil
    sentKeys, verdict = '', nil
end

core.hooks.after('core:character:spawning', function() intercept.arm(true) end)
core.hooks.after('core:character:selection', disarm)
core.hooks.after('core:character:unloaded', disarm)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == RESOURCE then
        -- la page disparaît avec la ressource, mais la souris et le clavier resteraient pris
        if state.open then nui.setFocus(false) end
        return
    end
    if resource == CODEX then codexClosed('stopped') end
    for key, block in pairs(blocks) do
        if block.owner == resource then
            blocks[key] = nil
            blockCount = blockCount - 1
        end
    end
end)

-- Essai du ligotage sans module qui lie (config `devCuffCommand`, '' en service) : sur son seul ped.
if type(cfg.devCuffCommand) == 'string' and cfg.devCuffCommand ~= '' then
    RegisterCommand(cfg.devCuffCommand, function()
        local ped = PlayerPedId()
        SetEnableHandcuffs(ped, not IsPedCuffed(ped))
    end, false)
end

-- ressource redémarrée en cours de partie
if core.characters.current() and not core.characters.awaitingSelection() then intercept.arm(true) end
