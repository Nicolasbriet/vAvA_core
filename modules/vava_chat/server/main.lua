--[[
    vava_chat/server/main.lua
    Rôle : déclaration du module auprès du core : intentions du client en RPC à schéma strict et à débit limité
           (envoyer un message, demander son profil), arrivée et départ des personnages, droits du Conseil relus quand
           un rang change ou que vava_admin (re)démarre, journal écrit régulièrement et à l'arrêt.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local AddEventHandler, GetPlayers, CreateThread = AddEventHandler, GetPlayers, CreateThread

local core = VavaChat.core
if not core then return end

local links = VavaChat.links
local sessions = VavaChat.sessions
local messages = VavaChat.messages
local compat = VavaChat.compat
local logs = VavaChat.logs
local cfg = VavaChat.config
local limits = cfg.rateLimits
local RPC = VavaChat.RPC
local ADMIN = VavaChat.ADMIN
local STAFF_ACTIONS = VavaChat.STAFF_ACTIONS

local KIND = { type = 'string', enum = VavaChat.SENDABLE }
local TEXT = { type = 'string', max = cfg.maxBytes }
local PLAYER = { type = 'integer', min = 0, max = 0xFFFF }
local CHAT = { type = 'integer', min = 0, max = 0x7FFFFFFF }

--- Profil du joueur à l'apparition : numéro de conversation, Conseil, commandes du serveur permises, suggestions
--- décrites par le registre des commandes (Codex).
local function profile(src)
    local session = sessions.get(src)
    if not session then return false, 'not_ready' end
    return true, {
        chat = session.chat, staff = session.staff, rank = session.rank,
        commands = compat.commands(src), suggestions = compat.suggestions(src),
    }
end

---@param src integer
---@param characterId integer
local function arrive(src, characterId)
    if not sessions.open(src, characterId) then
        VavaChat.log.warn('personnage %d du joueur %d introuvable pour le chat', characterId, src)
    end
end

---@param src integer
local function leave(src)
    sessions.close(src)
end

--- Action du Conseil (vava_admin) : un rang donné ou retiré change le canal du Conseil du joueur visé.
local function adminAction(payload)
    if not STAFF_ACTIONS[payload.action] or not payload.target then return end
    local src = payload.target.source
        or (payload.target.accountId and core.players.getByAccount(payload.target.accountId))
    -- relu au tick suivant : vava_admin a fini d'enregistrer le rang
    if src then CreateThread(function() sessions.refreshStaff(src) end) end
end

local function adminModule(payload)
    if payload.name == ADMIN then CreateThread(sessions.refreshAllStaff) end
end

local function setup()
    -- T-132 : un config.lua d'avant 1.4.0 (gardé par une mise à jour) remplace la table de config_client.lua ; il
    -- contient tout ce que lit le serveur, le module démarre, mais un réglage client qu'on y change reste sans effet
    if VavaChat.config.clientFile ~= true then
        core.log.warn('config.lua garde la forme d\'avant 1.4.0 (il remplace la table de config_client.lua) : les '
            .. 'réglages lus par les joueurs sont dans config_client.lua ; reportez vos changements d\'après '
            .. 'config.lua.nouveau')
    end
    local declared, declareErr = VavaChat.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    for _, def in ipairs({
        { RPC.SEND, { KIND, TEXT, PLAYER, CHAT }, limits.send, messages.send },
        { RPC.PROFILE, {}, limits.profile, profile },
    }) do
        local ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, err end
    end
    for _, def in ipairs({
        { 'core:character:loaded', function(payload) arrive(payload.source, payload.characterId) end },
        { 'core:character:unloading', function(payload) leave(payload.source) end },
        { 'core:player:dropped', function(payload)
            leave(payload.source)
            compat.forget(payload.source)
        end },
        { VavaChat.ADMIN_ACTION, adminAction },
        { 'core:module:ready', adminModule },
        { 'core:module:stopped', adminModule },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end
    VavaChat.ready = true
    logs.start()
    -- module (re)démarré en cours de partie : les personnages déjà en jeu
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local characterId = src and links.characterId(src)
        if characterId then arrive(src, characterId) end
    end
    return true
end

-- arrêt du module : la file du journal part en base
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaChat.resource or not VavaChat.ready then return end
    logs.flushAll()
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaChat.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
