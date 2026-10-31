--[[
    vava_atelier/server/main.lua
    Rôle : déclaration du module auprès du core et RPC du client (schéma strict et borné, débit limité ; chaque handler
           commence par les contrôles de server/access.lua) : accueil, descripteur d'un atelier, liste, fiche,
           « Vérifier », valeurs proposées, recherche, journal, fermeture. Hooks écoutés : registres (éditeurs : cache,
           propriétaire, `editorGone` ; objets du royaume), déchargement et départ (session retirée), actions du
           Registre (`revoked` à qui perd le droit d'ouvrir l'Atelier). Le setup refuse une config de droits fausse
           (shared/rights.lua › checkSettings) et avertit si config.lua garde la forme d'avant 1.2.0 (T-132) ; en fin
           de setup : journal purgé, hook vava_atelier:editorsReady (les modules redéclarent leurs éditeurs).
           T-101 : douze RPC des définitions gardées (enregistrer, essayer, arrêter l'essai, résumer, publier, revenir
           à une version, abandonner, retirer, reprendre, historique, version, retirées), chacun borné et limité ;
           hooks : séance fermée ou départ → fin de l'essai du membre ; /atelier_archives ; au démarrage, dans un fil :
           réparation (essais rendus aux brouillons, doublons), editorsReady, puis (après `history.purgeDelayMs`)
           purge de l'historique.
    Dépendances : tous les fichiers server/ du module, bridge/server.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local CreateThread = CreateThread

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local RPC, EVENTS, HOOKS = VavaAtelier.RPC, VavaAtelier.EVENTS, VavaAtelier.HOOKS
local REGISTRY, ITEMS = VavaAtelier.REGISTRY, VavaAtelier.ITEMS_REGISTRY
local Bridge = VavaAtelier.bridge
local editors, access, home = VavaAtelier.editors, VavaAtelier.access, VavaAtelier.home
local entries, check, journal = VavaAtelier.entries, VavaAtelier.check, VavaAtelier.journal
local rights = VavaAtelier.rights
local cycle, history, trials, sync = VavaAtelier.cycle, VavaAtelier.history, VavaAtelier.trials, VavaAtelier.sync
local archives = VavaAtelier.archives
local placement = VavaAtelier.placement
local limits = cfg.rateLimits
local DEF = VavaAtelier.DEF

-- Schémas communs (§ 6.1 de la spec) : identifiants au motif, textes et pages bornés.
local EDITOR = { type = 'string', min = 3, max = VavaAtelier.MAX_EDITOR, pattern = VavaAtelier.EDITOR_PATTERN }
local EDITOR_OR_ALL = { type = 'string', min = 0, max = VavaAtelier.MAX_EDITOR, pattern = '^[A-Za-z0-9_:]*$' }   -- '' : tous
local KIND = { type = 'string', min = 1, max = VavaAtelier.MAX_KEY, pattern = VavaAtelier.KEY_PATTERN }
local FIELD = KIND
local ENTRY = { type = 'string', min = 1, max = VavaAtelier.MAX_ENTRY, pattern = VavaAtelier.ENTRY_PATTERN }
-- '' : entrée nouvelle
local ENTRY_OR_NEW = { type = 'string', min = 0, max = VavaAtelier.MAX_ENTRY, pattern = '^[A-Za-z0-9_%-]*$' }
local VERSION = { type = 'string', min = 0, max = VavaAtelier.VERSION_LENGTH, pattern = VavaAtelier.VERSION_PATTERN }
local QUERY = { type = 'string', min = 0, max = VavaAtelier.MAX_QUERY, pattern = VavaAtelier.QUERY_PATTERN }
local SEARCH = { type = 'string', min = 2, max = VavaAtelier.MAX_QUERY, pattern = VavaAtelier.QUERY_PATTERN }
local PAGE = { type = 'integer', min = 1, max = 200 }
local BEFORE = { type = 'integer', min = 0, max = 4294967295 }                                         -- 0 : récentes
local LIMITS = VavaAtelier.LIMITS
local VALUES = { type = 'table', fields = {
    n = { type = 'map', min = 0, max = LIMITS.fields, optional = true, key = FIELD,
        value = { type = 'number', min = -LIMITS.sliderAbs, max = LIMITS.sliderAbs } },
    s = { type = 'map', min = 0, max = LIMITS.cardS, optional = true, key = FIELD,
        value = { type = 'string', min = 0, max = VavaAtelier.MAX_VALUE_STRING } },
    b = { type = 'map', min = 0, max = LIMITS.cardB, optional = true, key = FIELD, value = { type = 'boolean' } },
} }

-- T-101 (§ 6.1 de la spec) : révision lue, versions, jeton d'un résumé.
local REV = { type = 'integer', min = 0, max = DEF.revMax }                     -- 0 : aucun brouillon lu
local VERSION_NO = { type = 'integer', min = 1, max = DEF.versionMax }
local BEFORE_NO = { type = 'integer', min = 0, max = DEF.versionMax }           -- 0 : les plus récentes
-- preview : la révision lue (publish) ou la version visée (restore)
local REF = { type = 'integer', min = 0, max = DEF.versionMax }
local TOKEN = { type = 'string', min = DEF.tokenLength, max = DEF.tokenLength, pattern = '^[0-9a-f]+$' }
local WHAT = { type = 'string', enum = { 'publish', 'restore' } }

-- T-102 (§ 6.1 de la spec) : lieu d'une pose (clés de toutes les formes, facultatives : shared/place.lua refuse celles
-- qui ne sont pas de la forme du type), bornes tirées de config.place ; parent ('' : aucun).
local PLACE_LIMITS = cfg.place
local COORD = { type = 'number', min = -PLACE_LIMITS.maxXY, max = PLACE_LIMITS.maxXY }
local PLACE = { type = 'table', fields = {
    x = { type = 'number', min = -PLACE_LIMITS.maxXY, max = PLACE_LIMITS.maxXY, optional = true },
    y = { type = 'number', min = -PLACE_LIMITS.maxXY, max = PLACE_LIMITS.maxXY, optional = true },
    z = { type = 'number', min = -PLACE_LIMITS.maxZ, max = PLACE_LIMITS.maxZ, optional = true },
    h = { type = 'number', min = -720, max = 720, optional = true },
    r = { type = 'number', min = 0, max = PLACE_LIMITS.maxRadius, optional = true },
    points = { type = 'array', min = PLACE_LIMITS.polygonPoints.min, max = PLACE_LIMITS.polygonPoints.max,
        optional = true, items = { type = 'table', fields = { x = COORD, y = COORD } } },
} }
local PARENT = ENTRY_OR_NEW

-- Handlers ----------------------------------------------------------------------------------------------------------

local function homeRpc(source, version)
    local ctx, code = access.open(source, RPC.HOME)
    if not ctx then return false, code end
    access.leaveAll(ctx)
    return access.locked(ctx, home.answer, version)
end

local function editorRpc(source, editorId, version)
    local ctx, code = access.check(source, RPC.EDITOR, { editor = editorId })
    if not ctx then return false, code end
    access.setEditor(ctx, editorId)
    local editor = ctx.editor
    local answer = { version = editor.version }
    if version == '' or version ~= editor.version then answer.descriptor = editor.descriptor end
    return true, answer
end

local function listRpc(source, editorId, kindId, page, query)
    local ctx, code = access.check(source, RPC.LIST, { editor = editorId, kind = kindId })
    if not ctx then return false, code end
    return access.locked(ctx, entries.list, page, query)
end

local function readRpc(source, editorId, kindId, id)
    local ctx, code = access.check(source, RPC.READ, { editor = editorId, kind = kindId })
    if not ctx then return false, code end
    return access.locked(ctx, entries.read, id)
end

local function checkRpc(source, editorId, kindId, id, values)
    local ctx, code = access.check(source, RPC.CHECK, { editor = editorId, kind = kindId })
    if not ctx then return false, code end
    return access.locked(ctx, check.run, id, values)
end

local function optionsRpc(source, editorId, kindId, fieldId, query, page)
    local ctx, code = access.check(source, RPC.OPTIONS, { editor = editorId, kind = kindId })
    if not ctx then return false, code end
    return access.locked(ctx, entries.options, fieldId, query, page)
end

local function searchRpc(source, query)
    local ctx, code = access.check(source, RPC.SEARCH)
    if not ctx then return false, code end
    local visible = home.visible(home.held(source))
    return access.locked(ctx, function() return entries.search(visible, query) end)
end

local function journalRpc(source, before, editorId)
    local ctx, code = access.check(source, RPC.JOURNAL)
    if not ctx then return false, code end
    access.leaveAll(ctx)
    local held = home.held(source)
    if editorId ~= '' then
        local editor = editors.get(editorId)
        if not editor then return false, 'unknown_editor' end
        if not rights.holds(held, editor.right) then return false, 'not_allowed' end
    end
    local result, err = journal.read(held, before, editorId, cfg.journal.pageLines)
    if not result then return false, err end
    return true, result
end

local function closeRpc(source)
    access.close(source)
    return true
end

--- Handler d'un RPC de T-101 : contrôles communs (atelier et type demandés), puis `fn` sous le verrou du joueur.
local function storedRpc(name, fn)
    return function(source, editorId, kindId, ...)
        local ctx, code = access.check(source, name, { editor = editorId, kind = kindId })
        if not ctx then return false, code end
        return access.locked(ctx, fn, ...)
    end
end

local RPCS = {
    { RPC.HOME, { VERSION }, limits.home, homeRpc },
    { RPC.EDITOR, { EDITOR, VERSION }, limits.editor, editorRpc },
    { RPC.LIST, { EDITOR, KIND, PAGE, QUERY }, limits.read, listRpc },
    { RPC.READ, { EDITOR, KIND, ENTRY }, limits.read, readRpc },
    { RPC.CHECK, { EDITOR, KIND, ENTRY_OR_NEW, VALUES }, limits.check, checkRpc },
    { RPC.OPTIONS, { EDITOR, KIND, FIELD, QUERY, PAGE }, limits.lookup, optionsRpc },
    { RPC.SEARCH, { SEARCH }, limits.lookup, searchRpc },
    { RPC.JOURNAL, { BEFORE, EDITOR_OR_ALL }, limits.read, journalRpc },
    { RPC.CLOSE, {}, limits.close, closeRpc },
    -- T-101
    { RPC.SAVE, { EDITOR, KIND, ENTRY_OR_NEW, REV, VALUES }, limits.write, storedRpc(RPC.SAVE, cycle.save) },
    { RPC.TRIAL, { EDITOR, KIND, ENTRY, REV }, limits.write, storedRpc(RPC.TRIAL, cycle.trial) },
    { RPC.END_TRIAL, { EDITOR, KIND, ENTRY }, limits.write, storedRpc(RPC.END_TRIAL, cycle.endTrial) },
    { RPC.PREVIEW, { EDITOR, KIND, ENTRY, WHAT, REF }, limits.preview, storedRpc(RPC.PREVIEW, cycle.preview) },
    { RPC.PUBLISH, { EDITOR, KIND, ENTRY, REV, TOKEN }, limits.publish, storedRpc(RPC.PUBLISH, cycle.publish) },
    { RPC.RESTORE, { EDITOR, KIND, ENTRY, VERSION_NO, TOKEN }, limits.publish, storedRpc(RPC.RESTORE, cycle.restore) },
    { RPC.DISCARD, { EDITOR, KIND, ENTRY, REV }, limits.write, storedRpc(RPC.DISCARD, cycle.discard) },
    { RPC.RETIRE, { EDITOR, KIND, ENTRY }, limits.write, storedRpc(RPC.RETIRE, cycle.retire) },
    { RPC.TAKE, { EDITOR, KIND, ENTRY, REV }, limits.write, storedRpc(RPC.TAKE, cycle.take) },
    { RPC.HISTORY, { EDITOR, KIND, ENTRY, BEFORE_NO }, limits.read, storedRpc(RPC.HISTORY, history.list) },
    { RPC.VERSION, { EDITOR, KIND, ENTRY, VERSION_NO }, limits.read, storedRpc(RPC.VERSION, history.version) },
    { RPC.REMOVED, { EDITOR, KIND, PAGE }, limits.read, storedRpc(RPC.REMOVED, history.removed) },
    -- T-102 : outil de placement
    { RPC.PLACE, { EDITOR, KIND, ENTRY_OR_NEW, REV, PLACE, PARENT, VALUES }, limits.place,
        storedRpc(RPC.PLACE, placement.place) },
    { RPC.CHILDREN, { EDITOR, KIND, ENTRY }, limits.children, storedRpc(RPC.CHILDREN, placement.children) },
}

-- Hooks -------------------------------------------------------------------------------------------------------------

local function onRegistryAdded(payload)
    if payload.registry == REGISTRY then
        editors.added(payload.key, payload.owner)
    elseif payload.registry == ITEMS then
        Bridge.ItemsChanged('added', payload.key)
    end
end

--- Un atelier quitte le registre (module arrêté, ou entrée retirée) : listes oubliées, et les seuls membres qui
--- l'avaient ouvert reviennent à l'accueil.
local function onRegistryRemoved(payload)
    if payload.registry == REGISTRY then
        if editors.removed(payload.key) then
            entries.forget(payload.key)
            for _, source in ipairs(access.leaveEditor(payload.key)) do
                Bridge.Send(source, EVENTS.EDITOR_GONE, payload.key)
            end
        end
    elseif payload.registry == ITEMS then
        Bridge.ItemsChanged('removed', payload.key)
    end
end

local function onRegistryDropped(payload)
    if payload.registry == ITEMS then Bridge.ItemsChanged('dropped') end
end

local function onUnloading(payload)
    if payload.source then access.close(payload.source) end
end

local function onDropped(payload)
    if not payload.source then return end
    -- l'essai du membre prend fin (`dropped`) avant que la fermeture de sa séance ne le fasse (`session`)
    local session = access.sessions()[payload.source]
    if session then trials.sessionClosed(session.accountId, 'dropped') end
    access.forget(payload.source)
    archives.forget(payload.source)
end

--- Séance fermée (fermeture, déchargement, révocation) : l'essai du membre prend fin.
local function onSession(payload)
    if type(payload) ~= 'table' or payload.open ~= false or not payload.accountId then return end
    trials.sessionClosed(payload.accountId, 'session')
end

-- actions du Registre qui changent le rang d'un compte
local RANK_ACTIONS = { staffGrant = true, staffRevoke = true }

--- Un rang donné ou retiré : chaque session de ce compte est revue ; qui a perdu le droit d'ouvrir l'Atelier voit
--- son interface se fermer (et tout appel suivant serait refusé de toute façon).
local function onAdminAction(payload)
    if type(payload) ~= 'table' or not RANK_ACTIONS[payload.action] then return end
    local target = type(payload.target) == 'table' and payload.target.accountId or nil
    for source, session in pairs(access.sessions()) do
        if (target == nil or session.accountId == target) and not Bridge.Can(source, cfg.rights.open) then
            access.close(source)
            Bridge.Send(source, EVENTS.REVOKED)
        end
    end
end

local HOOKED = {
    { 'core:registry:added', onRegistryAdded },
    { 'core:registry:removed', onRegistryRemoved },
    { 'core:registry:dropped', onRegistryDropped },
    { 'core:character:unloading', onUnloading },
    { 'core:player:dropped', onDropped },
    { 'vava_admin:action', onAdminAction },
    { HOOKS.SESSION, onSession },
}

local function setup()
    -- T-132 : un config.lua d'avant 1.2.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if cfg.clientFile ~= true then
        VavaAtelier.log.warn('config.lua garde la forme d\'avant 1.2.0 (il remplace la table de config_client.lua) : '
            .. 'les réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    -- un plancher, une surcharge ou le droit d'ouvrir hors des droits permis ouvrirait ou fermerait un atelier à tort
    local valid, invalid = rights.checkSettings(cfg)
    if not valid then return false, 'config.lua, droits : ' .. tostring(invalid) end
    for _, hook in ipairs(HOOKED) do
        local id, err = core.hooks.after(hook[1], hook[2])
        if not id then return false, hook[1] .. ' : ' .. tostring(err) end
    end
    local ok, err = editors.define()
    if not ok then return false, 'registre des éditeurs : ' .. tostring(err) end
    ok, err = VavaAtelier.commands.declare()
    if not ok then return false, 'commandes : ' .. tostring(err) end
    for _, def in ipairs(RPCS) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end
    archives.register()
    journal.purge()
    -- dans un fil : réparation de la base (essais rendus aux brouillons, doublons), puis les modules déjà en jeu
    -- (redémarrage de l'Atelier) redéclarent leurs éditeurs et sont synchronisés ; la purge de l'historique attend
    -- `history.purgeDelayMs` (les synchronisations d'abord)
    CreateThread(function()
        if not sync.repair() then
            VavaAtelier.log.error('définitions : réparation impossible (registres muets) ; chaque atelier gardé sera '
                .. 'synchronisé à sa déclaration')
        end
        core.hooks.runAfter(HOOKS.EDITORS_READY, {})
        history.purge()
    end)
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaAtelier.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
