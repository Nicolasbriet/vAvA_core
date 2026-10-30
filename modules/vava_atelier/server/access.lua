--[[
    vava_atelier/server/access.lua
    Rôle : sessions ouvertes et contrôle de chaque appel. Une session est ouverte par le RPC `home` pour un joueur ET
           son compte ; chaque RPC revérifie, dans l'ordre : personnage chargé, Registre du Conseil prêt, droit
           d'ouvrir l'Atelier (relu auprès de vava_admin, jamais gardé), session de ce compte, atelier déclaré, droit
           effectif de l'atelier (relu), type et champ déclarés. Une seule lecture ou vérification de module à la fois
           par joueur (`busy`). Un refus pour droit écrit une ligne en console, une fois par intervalle et par joueur.
    Dépendances : shared/constants.lua, config.lua, bridge/server.lua, server/core.lua, server/editors.lua
]]

local pairs, tostring, xpcall = pairs, tostring, xpcall
local pack, unpack = table.pack, table.unpack
local traceback = debug.traceback
local GetGameTimer = GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local Bridge = VavaAtelier.bridge
local editors = VavaAtelier.editors
local HOOK_SESSION = VavaAtelier.HOOKS.SESSION

local access = {}
VavaAtelier.access = access

---@class vAvA.AtelierSession
---@field accountId integer
---@field editor string|nil   atelier ouvert (descripteur demandé en dernier)
---@field busy boolean

---@type table<integer, vAvA.AtelierSession>
local sessions = {}
-- dernier refus écrit en console, par joueur
local lastRefusal = {}

---@class vAvA.AtelierContext
---@field source integer
---@field accountId integer
---@field session vAvA.AtelierSession|nil
---@field editor vAvA.AtelierEditor|nil
---@field kind vAvA.AtelierKind|nil

--- Refus pour droit : une ligne en console au plus par intervalle et par joueur.
local function refusal(source, accountId, rpc)
    local now = GetGameTimer()
    local last = lastRefusal[source]
    if last and now - last < cfg.limits.refusalLogMs then return end
    lastRefusal[source] = now
    VavaAtelier.log.warn('joueur %d, compte %s : %s refusé (droit)', source, tostring(accountId), rpc)
end

--- Contrôles communs à tous les RPC : personnage, Registre, droit d'ouvrir.
---@return vAvA.AtelierContext|nil ctx
---@return string|nil code
local function base(source, rpc)
    local character = Bridge.Character(source)
    if not character then return nil, 'no_character' end
    if not Bridge.AdminReady() then return nil, 'not_ready' end
    local accountId = character.accountId or Bridge.AccountId(source)
    if not Bridge.Can(source, cfg.rights.open) then
        refusal(source, accountId, rpc)
        return nil, 'not_allowed'
    end
    return { source = source, accountId = accountId }
end

--- Ouvre (ou remplace) la session d'un joueur : RPC `home`. Le hook `vava_atelier:session` part à l'ouverture, pas
--- au simple retour à l'accueil.
---@param source integer
---@param rpc string
---@return vAvA.AtelierContext|nil ctx
---@return string|nil code
function access.open(source, rpc)
    local ctx, code = base(source, rpc)
    if not ctx then return nil, code end
    local session = sessions[source]
    if not session or session.accountId ~= ctx.accountId then
        if session then access.close(source) end
        session = { accountId = ctx.accountId, busy = false }
        sessions[source] = session
        core.hooks.runAfter(HOOK_SESSION, { source = source, accountId = ctx.accountId, open = true })
    end
    ctx.session = session
    return ctx
end

---@class vAvA.AtelierCheckOptions
---@field editor? string   atelier demandé
---@field kind? string     type demandé (avec `editor`)

--- Contrôle d'un RPC hors `home` : contrôles communs, session de ce compte, atelier et type s'ils sont demandés.
---@param source integer
---@param rpc string
---@param options? vAvA.AtelierCheckOptions
---@return vAvA.AtelierContext|nil ctx
---@return string|nil code
function access.check(source, rpc, options)
    local ctx, code = base(source, rpc)
    if not ctx then return nil, code end
    local session = sessions[source]
    if not session or session.accountId ~= ctx.accountId then return nil, 'not_open' end
    ctx.session = session
    if options and options.editor then
        local editor = editors.get(options.editor)
        if not editor then return nil, 'unknown_editor' end
        if not Bridge.Can(source, editor.right) then
            refusal(source, ctx.accountId, rpc)
            return nil, 'not_allowed'
        end
        ctx.editor = editor
        if options.kind then
            local kind = editors.kind(editor, options.kind)
            if not kind then return nil, 'unknown_kind' end
            ctx.kind = kind
        end
    end
    return ctx
end

--- Lance `fn(ctx, …)` sous le verrou du joueur : une seule lecture ou vérification de module à la fois (`busy`). Le
--- verrou est rendu même si `fn` lève une erreur (renvoyée ensuite comme erreur serveur).
---@param ctx vAvA.AtelierContext
---@param fn fun(ctx: vAvA.AtelierContext, ...): any
---@return any
function access.locked(ctx, fn, ...)
    local session = ctx.session
    if session.busy then return false, 'busy' end
    session.busy = true
    local results = pack(xpcall(fn, traceback, ctx, ...))
    session.busy = false
    if not results[1] then error(results[2], 0) end
    return unpack(results, 2, results.n)
end

--- Ferme la session d'un joueur (fermeture, déchargement, départ, révocation). Rend vrai s'il en avait une.
---@param source integer
---@return boolean
function access.close(source)
    local session = sessions[source]
    if not session then return false end
    sessions[source] = nil
    core.hooks.runAfter(HOOK_SESSION, { source = source, accountId = session.accountId, open = false })
    return true
end

--- Joueur parti : session et compteur de refus oubliés.
---@param source integer
function access.forget(source)
    access.close(source)
    lastRefusal[source] = nil
end

---@param source integer
---@return boolean
function access.isOpen(source)
    return sessions[source] ~= nil
end

--- Sessions ouvertes (lecture seule) : joueur → session.
---@return table<integer, vAvA.AtelierSession>
function access.sessions()
    return sessions
end

--- Retient l'atelier ouvert d'une session (évènement `editorGone` s'il quitte le registre).
---@param ctx vAvA.AtelierContext
---@param editorId string
function access.setEditor(ctx, editorId)
    ctx.session.editor = editorId
end

--- Atelier retiré du registre : les joueurs dont la session l'avait ouvert, qui l'oublient.
---@param editorId string
---@return integer[]
function access.leaveEditor(editorId)
    local out = {}
    for source, session in pairs(sessions) do
        if session.editor == editorId then
            out[#out + 1] = source
            session.editor = nil
        end
    end
    return out
end
