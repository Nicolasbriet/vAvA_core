--[[
    server/players/accounts.lua
    Rôle : connexion des joueurs (deferrals), compte par license, sessions (license ↔ compte ↔ source).
    Une license n'a qu'une session à la fois : la double connexion est refusée (anti-duplication), sauf session
    fantôme (joueur disparu sans déconnexion propre), qui est nettoyée.
    Une connexion acceptée puis abandonnée (FiveM fermé pendant le chargement) libère sa license dès que FXServer
    n'en connaît plus l'identifiant temporaire (relevé lent, actif seulement tant qu'une connexion est en cours).
    Seule la license est conservée (minimisation des données personnelles) : ni IP, ni autre identifiant, ni pseudo.
    Porte gardée (0.9.1) : tant qu'un module « garde de connexion » (players.connectionGuards : les bans) est démarré
    sans être prêt, ou en échec, les connexions sont refusées ; absent du serveur ou arrêté, il n'est pas attendu.
    Dépendances : config/server.lua, shared/core/logger.lua, shared/core/hooks.lua, server/core/database.lua,
                  server/core/modules.lua
]]

local tonumber, tostring, type, ipairs, pairs, next, xpcall = tonumber, tostring, type, ipairs, pairs, next, xpcall
local traceback = debug.traceback
local GetPlayerIdentifierByType, GetPlayers, DoesPlayerExist, DropPlayer = GetPlayerIdentifierByType, GetPlayers, DoesPlayerExist, DropPlayer
local GetGameTimer, SetTimeout, Wait, AddEventHandler = GetGameTimer, SetTimeout, Wait, AddEventHandler
local GetResourceState = GetResourceState

local hooks = vAvA.hooks
local database = vAvA.database
local modules = vAvA.modules
local cfg = vAvA.config.server.players
local messages = cfg.messages
local log = vAvA.logger.create('accounts')

local CORE = vAvA.CORE_OWNER
-- La clé de compte fait partie du modèle de données (colonne `license`) : non réglable.
local IDENTIFIER_TYPE = 'license'
-- Relevés manquants d'affilée avant de libérer une connexion : au playerJoining, FXServer remplace l'identifiant
-- temporaire par le définitif juste avant que notre handler ne passe la session en « joined ». Un relevé tombé
-- entre les deux ne suffit jamais à libérer : le suivant, connectCheckMs plus tard, trouve la session rejointe.
local MISSED_CHECKS_TO_RELEASE = 2

local SELECT_ACCOUNT_SQL = 'SELECT `id` FROM `vava_accounts` WHERE `license` = ?'
local INSERT_ACCOUNT_SQL = 'INSERT INTO `vava_accounts` (`license`) VALUES (?)'
local TOUCH_ACCOUNT_SQL = 'UPDATE `vava_accounts` SET `last_seen_at` = CURRENT_TIMESTAMP WHERE `id` = ?'

local HOOK_CONNECTING = 'core:player:connecting'
local HOOK_JOINED = 'core:player:joined'
local HOOK_DROPPED = 'core:player:dropped'

local accounts = {}
vAvA.accounts = accounts

-- États FXServer d'une ressource qui ne tourne pas du tout : son module n'est pas attendu à la porte.
local NOT_RUNNING = { missing = true, uninitialized = true, stopped = true }

--- Verdict de la porte pour un module garde de connexion (logique pure).
---@param resourceState string|nil  GetResourceState de la ressource
---@param moduleState string|nil    état du module au core (nil : pas encore déclaré)
---@return 'open'|'absent'|'closed'
function accounts.guardVerdict(resourceState, moduleState)
    if NOT_RUNNING[resourceState] then return 'absent' end
    if resourceState == 'started' and moduleState == 'ready' then return 'open' end
    return 'closed'
end
local guardVerdict = accounts.guardVerdict

--- Premier garde de connexion qui ferme la porte (démarré sans être prêt, ou en échec), ou nil. Un garde absent est
--- signalé à la console (sauf `quiet`) : ce qu'il vérifie (les bans) ne l'est plus.
---@param quiet? boolean
---@return string|nil name
---@return string|nil detail  états de la ressource et du module
function accounts.closedGuard(quiet)
    local guards = cfg.connectionGuards or {}
    for i = 1, #guards do
        local name = guards[i]
        local resourceState = GetResourceState(name)
        local info = modules.get(name)
        local moduleState = info and info.state
        local verdict = guardVerdict(resourceState, moduleState)
        if verdict == 'closed' then
            local detail = ('ressource %s, module %s'):format(tostring(resourceState), tostring(moduleState or 'non déclaré'))
            return name, detail
        elseif verdict == 'absent' and not quiet then
            log.warn("connexion accordée sans le garde '%s' (ressource %s) : ce qu'il vérifie ne l'est pas",
                name, tostring(resourceState))
        end
    end
    return nil
end

---@alias vAvA.SessionState 'connecting'|'joined'|'loading'|'active'|'unloading'

---@class vAvA.Session
---@field license string
---@field accountId integer|nil
---@field source integer|nil          nil tant que le joueur n'a pas rejoint
---@field tempSource integer|nil      identifiant temporaire de connexion (surveillé tant que l'état est connecting)
---@field missedChecks integer|nil    relevés consécutifs où la connexion n'existait plus côté FXServer
---@field state vAvA.SessionState
---@field openedAt integer
---@field busy boolean                une action de personnage est en cours : les autres sont refusées
---@field idle table|nil              promesse résolue à la fin de l'action en cours (fermeture qui l'attend)
---@field closing boolean
---@field characters table<integer, table>  résumés des personnages du compte (id → résumé)
---@field characterId integer|nil

---@type table<string, vAvA.Session>
local byLicense = {}
---@type table<integer, vAvA.Session>
local bySource = {}
---@type table<integer, vAvA.Session>
local byAccount = {}
-- connexions acceptées en attente de playerJoining : session → true ; le relevé ne tourne que si elle n'est pas vide
---@type table<vAvA.Session, true>
local watched = {}
local watching = false

-- Fournis par init.lua (domaine personnages) : préparer une session, décharger avant fermeture.
---@type fun(session: vAvA.Session): boolean, string?
local prepare = function() return true end
---@type fun(session: vAvA.Session, reason: string)
local beforeClose = function() end

---@param session vAvA.Session
local function release(session)
    watched[session] = nil
    if byLicense[session.license] == session then byLicense[session.license] = nil end
    if session.source and bySource[session.source] == session then bySource[session.source] = nil end
    if session.accountId and byAccount[session.accountId] == session then byAccount[session.accountId] = nil end
end

--- Licenses des joueurs en jeu (identifiant définitif). Lu seulement quand une connexion semble disparue.
---@return table<string, true>
local function licensesInGame()
    local set = {}
    for _, id in ipairs(GetPlayers()) do
        local license = GetPlayerIdentifierByType(id, IDENTIFIER_TYPE)
        if license then set[license] = true end
    end
    return set
end

--- Un relevé des connexions surveillées. Une connexion existe tant que FXServer connaît son identifiant
--- temporaire, ou qu'un joueur en jeu porte sa license (passage au définitif, playerJoining pas encore traité).
local function sweepConnecting()
    local inGame
    for session in pairs(watched) do
        if byLicense[session.license] ~= session or session.state ~= 'connecting' then
            watched[session] = nil
        else
            local present = DoesPlayerExist(session.tempSource)
            if not present then
                inGame = inGame or licensesInGame()
                present = inGame[session.license] == true
            end
            if present then
                session.missedChecks = 0
            else
                session.missedChecks = session.missedChecks + 1
                if session.missedChecks >= MISSED_CHECKS_TO_RELEASE then
                    log.info('connexion du compte #%s abandonnée pendant le chargement : license libérée', tostring(session.accountId))
                    release(session)
                end
            end
        end
    end
end

local function checkConnecting()
    local ok, err = xpcall(sweepConnecting, traceback)
    if not ok then log.error('relevé des connexions en cours : %s', tostring(err)) end
    -- reprogrammé tant qu'une connexion est en cours, même après une erreur ; arrêté sinon (aucun coût au repos)
    if next(watched) then
        SetTimeout(cfg.connectCheckMs, checkConnecting)
    else
        watching = false
    end
end

--- Surveille une connexion acceptée jusqu'à son playerJoining.
---@param session vAvA.Session
---@param tempSource integer
local function watch(session, tempSource)
    session.tempSource, session.missedChecks = tempSource, 0
    watched[session] = true
    if not watching then
        watching = true
        SetTimeout(cfg.connectCheckMs, checkConnecting)
    end
end

--- Compte existant d'une license, sans rien créer (connexion refusée : aucune donnée enregistrée).
---@param license string
---@return integer|nil accountId
---@return string|nil err
local function findAccount(license)
    local row, err = database.single(CORE, SELECT_ACCOUNT_SQL, { license })
    if err then return nil, err end
    return row and tonumber(row.id) or nil
end

---@param license string
---@return integer|nil accountId
---@return string|nil err
local function loadAccount(license)
    local existing, err = findAccount(license)
    if err then return nil, err end
    if existing then return existing end
    local id, insertErr = database.insert(CORE, INSERT_ACCOUNT_SQL, { license })
    if insertErr then return nil, insertErr end
    log.info('nouveau compte #%d', id)
    return id
end

---@param license string
---@return vAvA.Session
local function open(license)
    local session = {
        license = license, state = 'connecting', openedAt = GetGameTimer(),
        busy = false, closing = false, characters = {},
    }
    byLicense[license] = session
    return session
end

--- Charge le compte (créé s'il n'existe pas encore) et prépare la session. Bloque le thread courant.
---@param session vAvA.Session
---@param knownAccount? integer  compte déjà trouvé à la connexion
---@return boolean ok
---@return string|nil err
local function load(session, knownAccount)
    local accountId, err = knownAccount, nil
    if not accountId then accountId, err = loadAccount(session.license) end
    if not accountId then return false, err end
    if byLicense[session.license] ~= session then return false, 'session remplacée pendant le chargement' end
    session.accountId = accountId
    byAccount[accountId] = session
    return prepare(session)
end

--- Une session existante bloque-t-elle encore sa license ?
---@param session vAvA.Session
---@return boolean
local function isAlive(session)
    if session.source then return DoesPlayerExist(session.source) end
    return GetGameTimer() - session.openedAt < cfg.connectTimeoutMs
end

--- Ferme une session : le domaine personnages décharge et sauvegarde d'abord, puis tout est libéré.
--- La libération a lieu même si le déchargement échoue : aucune license ne peut rester bloquée.
---@param session vAvA.Session
---@param reason string
local function close(session, reason)
    if session.closing then return end
    session.closing = true
    local ok, err = xpcall(beforeClose, traceback, session, reason)
    if not ok then
        log.error('fermeture de la session du compte #%s : %s', tostring(session.accountId), tostring(err))
    end
    release(session)
    if session.source then
        if session.accountId then database.update(CORE, TOUCH_ACCOUNT_SQL, { session.accountId }) end
        hooks.runAfter(HOOK_DROPPED, { source = session.source, accountId = session.accountId, reason = reason })
    end
end

--- Message de refus montré au joueur : celui d'un module (ban…) s'il en fournit un, sinon le message générique.
---@param reason any
---@return string
local function refusalMessage(reason)
    if type(reason) == 'string' and reason ~= 'hook_error' and reason ~= 'cancelled' then return reason end
    return messages.refused
end

local function onConnecting(name, _, deferrals)
    local tempSource = tonumber(source)
    deferrals.defer()
    -- FiveM exige un tick entre defer() et update() : attente unique, pas une boucle
    Wait(0)
    deferrals.update(messages.checking)

    if not modules.isCoreReady() then
        deferrals.update(messages.starting)
        -- attente bornée : passé le délai, la tentative se termine (le joueur réessaie) au lieu de rester en suspens
        -- et de reprendre bien plus tard, licence bloquée, alors que le joueur est peut-être déjà reparti
        local ready, reason = modules.awaitCore(cfg.coreWaitTimeoutMs)
        if not ready then
            deferrals.done(reason == 'timeout' and messages.stillStarting or messages.unavailable)
            return
        end
    end

    -- porte gardée : les bans (vava_admin) sont des hooks ; module démarré sans être prêt, ou en échec, ils
    -- n'existeraient pas et la connexion passerait sans vérification
    local guard, detail = accounts.closedGuard()
    if guard then
        log.error("connexion refusée : le garde de connexion '%s' n'est pas prêt (%s)", guard, detail)
        deferrals.done(messages.guardNotReady)
        return
    end

    local license = tempSource and GetPlayerIdentifierByType(tempSource, IDENTIFIER_TYPE)
    if not license then
        deferrals.done(messages.noLicense)
        return
    end

    local existing = byLicense[license]
    if existing then
        if isAlive(existing) then
            log.warn('connexion refusée : le compte #%s est déjà connecté', tostring(existing.accountId))
            deferrals.done(messages.alreadyConnected)
            return
        end
        log.info('session fantôme du compte #%s nettoyée', tostring(existing.accountId))
        close(existing, 'ghost')
    end

    local session = open(license)
    -- compte déjà connu (nil pour une première venue) : un ban, une liste blanche s'y rattachent. Base qui ne répond
    -- pas : refus, sans quoi un compte existant passerait aux hooks pour une première venue (aucun ban vérifié)
    local knownAccount, findErr = findAccount(license)
    if findErr then
        release(session)
        log.error('connexion refusée : compte de la license introuvable, base indisponible (%s)', tostring(findErr))
        deferrals.done(messages.unavailable)
        return
    end
    local allowed, reason = hooks.runBefore(HOOK_CONNECTING, { source = tempSource, license = license, name = name, accountId = knownAccount })
    if byLicense[license] ~= session then
        deferrals.done(messages.refused)
        return
    end
    if not allowed then
        release(session)
        deferrals.done(refusalMessage(reason))
        return
    end
    -- garde arrêté pendant les hooks (ses hooks retirés, chaîne passée sans lui) : même refus
    guard, detail = accounts.closedGuard(true)
    if guard then
        release(session)
        log.error("connexion refusée : le garde de connexion '%s' s'est arrêté pendant la vérification (%s)",
            guard, detail)
        deferrals.done(messages.guardNotReady)
        return
    end

    local ok, err = load(session, knownAccount)
    if not ok then
        release(session)
        log.error('connexion impossible : %s', tostring(err))
        deferrals.done(messages.unavailable)
        return
    end
    deferrals.done()

    -- joueur parti pendant son chargement (aucun playerJoining) : libéré dès que FXServer ne connaît plus sa
    -- connexion (relevé toutes les connectCheckMs), et au plus tard après connectTimeoutMs (filet, posé d'abord)
    SetTimeout(cfg.connectTimeoutMs, function()
        if byLicense[license] == session and session.state == 'connecting' then release(session) end
    end)
    watch(session, tempSource)
end

local function onJoining()
    local src = tonumber(source)
    if not src then return end
    local license = GetPlayerIdentifierByType(src, IDENTIFIER_TYPE)
    local session = license and byLicense[license]
    if not session or session.state ~= 'connecting' or not session.accountId then
        -- connexion non validée par playerConnecting (core redémarré pendant le chargement du joueur)
        DropPlayer(src, messages.unavailable)
        return
    end
    session.source = src
    session.state = 'joined'
    watched[session] = nil
    bySource[src] = session
    database.update(CORE, TOUCH_ACCOUNT_SQL, { session.accountId })
    hooks.runAfter(HOOK_JOINED, { source = src, accountId = session.accountId })
end

--- Injecte les traitements du domaine personnages (appelé par init.lua).
---@param handlers { prepare: fun(session: vAvA.Session): boolean, string?, close: fun(session: vAvA.Session, reason: string) }
function accounts.setHandlers(handlers)
    prepare, beforeClose = handlers.prepare, handlers.close
end

---@param src integer
---@return vAvA.Session|nil
function accounts.get(src)
    return bySource[src]
end

--- Vrai si la session est toujours celle du joueur (il a pu partir pendant une attente).
---@param session vAvA.Session
---@return boolean
function accounts.isCurrent(session)
    return session.source ~= nil and bySource[session.source] == session and not session.closing
end

---@param accountId integer
---@return integer|nil source
function accounts.sourceOf(accountId)
    local session = byAccount[accountId]
    return session and session.source
end

---@class vAvA.PlayerInfo
---@field source integer
---@field accountId integer
---@field state vAvA.SessionState
---@field characterId integer|nil

---@param src integer
---@return vAvA.PlayerInfo|nil
function accounts.describe(src)
    local session = bySource[src]
    if not session then return nil end
    return { source = session.source, accountId = session.accountId, state = session.state, characterId = session.characterId }
end

--- Déconnexion : déchargement, sauvegarde, libération. Bloque le thread courant.
---@param src integer
---@param reason string
function accounts.handleDropped(src, reason)
    local session = bySource[src]
    if session then close(session, reason) end
end

--- Reprend les joueurs déjà connectés (redémarrage du core en cours de partie). Bloque le thread courant.
function accounts.adoptConnected()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local license = src and GetPlayerIdentifierByType(src, IDENTIFIER_TYPE)
        if license and not byLicense[license] and not bySource[src] then
            local session = open(license)
            local ok, err = load(session)
            if ok then
                session.source, session.state = src, 'joined'
                bySource[src] = session
            else
                release(session)
                log.error('reprise du joueur %d impossible : %s', src, tostring(err))
            end
        end
    end
end

--- Branche les events de connexion. Appelé par init.lua.
function accounts.start()
    AddEventHandler('playerConnecting', onConnecting)
    AddEventHandler('playerJoining', onJoining)
end
