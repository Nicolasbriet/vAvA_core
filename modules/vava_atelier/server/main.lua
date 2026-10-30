--[[
    vava_atelier/server/main.lua
    Rôle : déclaration du module auprès du core et RPC du client (schéma strict et borné, débit limité ; chaque handler
           commence par les contrôles de server/access.lua) : accueil, descripteur d'un atelier, liste, fiche,
           « Vérifier », valeurs proposées, recherche, journal, fermeture. Hooks écoutés : registres (éditeurs : cache,
           propriétaire, `editorGone` ; objets du royaume), déchargement et départ (session retirée), actions du
           Registre (`revoked` à qui perd le droit d'ouvrir l'Atelier). Le setup refuse une config de droits fausse
           (shared/rights.lua › checkSettings) ; en fin de setup : journal purgé, hook vava_atelier:editorsReady (les
           modules redéclarent leurs éditeurs).
    Dépendances : tous les fichiers server/ du module, bridge/server.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local RPC, EVENTS, HOOKS = VavaAtelier.RPC, VavaAtelier.EVENTS, VavaAtelier.HOOKS
local REGISTRY, ITEMS = VavaAtelier.REGISTRY, VavaAtelier.ITEMS_REGISTRY
local Bridge = VavaAtelier.bridge
local editors, access, home = VavaAtelier.editors, VavaAtelier.access, VavaAtelier.home
local entries, check, journal = VavaAtelier.entries, VavaAtelier.check, VavaAtelier.journal
local rights = VavaAtelier.rights
local limits = cfg.rateLimits

-- Schémas communs (§ 6.1 de la spec) : identifiants au motif, textes et pages bornés.
local EDITOR = { type = 'string', min = 3, max = VavaAtelier.MAX_EDITOR, pattern = VavaAtelier.EDITOR_PATTERN }
local EDITOR_OR_ALL = { type = 'string', min = 0, max = VavaAtelier.MAX_EDITOR, pattern = '^[%w_:]*$' }   -- '' : tous
local KIND = { type = 'string', min = 1, max = VavaAtelier.MAX_KEY, pattern = VavaAtelier.KEY_PATTERN }
local FIELD = KIND
local ENTRY = { type = 'string', min = 1, max = VavaAtelier.MAX_ENTRY, pattern = VavaAtelier.ENTRY_PATTERN }
-- '' : entrée nouvelle
local ENTRY_OR_NEW = { type = 'string', min = 0, max = VavaAtelier.MAX_ENTRY, pattern = '^[%w_%-]*$' }
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

-- Handlers ----------------------------------------------------------------------------------------------------------

local function homeRpc(source, version)
    local ctx, code = access.open(source, RPC.HOME)
    if not ctx then return false, code end
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
    if payload.source then access.forget(payload.source) end
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
}

local function setup()
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
    journal.purge()
    -- les modules déjà en jeu (redémarrage de l'Atelier) redéclarent leurs éditeurs
    core.hooks.runAfter(HOOKS.EDITORS_READY, {})
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
