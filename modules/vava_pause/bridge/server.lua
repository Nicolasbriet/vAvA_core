--[[
    vava_pause/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre la bannière et les autres modules : savoir-faire (vava_skills),
           à terre (vava_health), confrérie (vava_guilds, facultatif, export réglable), demande au Conseil et son état
           (vava_admin), Conseil prêt à recevoir. Chaque appel est isolé : un module absent, arrêté, ancien ou en erreur
           ne retire que ce qu'il donne (valeur par défaut du tableau de la spec, § 10.4).
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local pack, unpack = table.pack, table.unpack
local GetResourceState = GetResourceState

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config
local SKILLS, HEALTH, ADMIN = 'vava_skills', 'vava_health', 'vava_admin'

local Bridge = {}
VavaPause.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie `called` (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if type(resource) ~= 'string' or GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaPause.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

--- Vues des savoir-faire du joueur (vava_skills), ou {}.
---@param src integer
---@return table
function Bridge.getSkills(src)
    local called, views = call(SKILLS, 'getSkills', src)
    return called and type(views) == 'table' and views or {}
end

--- Vrai si le joueur est à terre (vava_health) ; module absent : pas à terre.
---@param src integer
---@return boolean
function Bridge.isDowned(src)
    local called, downed = call(HEALTH, 'isDowned', src)
    return called and downed == true
end

--- Bannière de la confrérie du joueur (brute, revalidée par shared/snapshot.lua), ou nil : bannière royale.
---@param src integer
---@return any
function Bridge.guildOf(src)
    local guild = cfg.guild
    local called, raw = call(guild.resource, guild.export, src)
    if not called then return nil end
    return raw
end

--- Demande au Conseil (vava_admin.submitRequest) : `true, demande` ou `false, code[, secondes]` ; module absent,
--- arrêté, ancien ou en erreur : `false, 'council_unavailable'`.
---@return boolean ok
---@return table|string requestOrCode
---@return integer|nil seconds
function Bridge.submitRequest(src, kind, text, withPosition)
    local called, ok, value, seconds = call(ADMIN, 'submitRequest', src, kind, text, withPosition)
    if not called then return false, 'council_unavailable' end
    if ok == true then return true, value end
    if type(value) ~= 'string' or value == 'not_allowed' or value == 'not_ready' or value == 'invalid_kind' then
        if value == 'not_allowed' then
            VavaPause.log.warn('vava_admin refuse les demandes de la bannière : ajouter %s à requests.callers', VavaPause.resource)
        end
        return false, 'council_unavailable'
    end
    return false, value, seconds
end

--- État de la demande du compte du joueur (vava_admin.requestOf), brut, ou nil.
---@param src integer
---@return any
function Bridge.requestOf(src)
    local called, status = call(ADMIN, 'requestOf', src)
    if not called then return nil end
    return status
end

--- Vrai si le Registre du Conseil est démarré et prêt à recevoir une demande.
---@return boolean
function Bridge.councilReady()
    if GetResourceState(ADMIN) ~= 'started' then return false end
    local info = core.modules.get(ADMIN)
    return type(info) == 'table' and info.state == 'ready'
end
