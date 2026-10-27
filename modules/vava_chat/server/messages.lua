--[[
    vava_chat/server/messages.lua
    Rôle : un message de joueur, de l'intention reçue à sa remise : texte nettoyé et borné, destinataires choisis par
           le serveur (portée pour /ooc, /me, /do ; un seul joueur pour /mp ; le Conseil pour /staff), hook « before »
           qui peut le refuser (sourdine d'un autre module…), remise à chaque destinataire (jamais à tout le serveur),
           journal pour les genres choisis, hook « after ».
    Dépendances : shared/, config.lua, server/core.lua, server/sessions.lua, server/audience.lua, server/logs.lua
]]

local type = type
local TriggerClientEvent = TriggerClientEvent

local core = VavaChat.core
if not core then return end

local text = VavaChat.text
local sessions = VavaChat.sessions
local audience = VavaChat.audience
local logs = VavaChat.logs
local cfg = VavaChat.config
local KINDS = VavaChat.KINDS
local HOOKS = VavaChat.HOOKS
local EVENT = VavaChat.EVENTS.MESSAGE
local NONE = 0

local messages = {}
VavaChat.messages = messages

---@param recipients integer[]
---@param payload table
local function deliver(recipients, payload)
    for i = 1, #recipients do TriggerClientEvent(EVENT, recipients[i], payload) end
end

--- Correspondant d'un message privé : par numéro de conversation (réponse dans son onglet), sinon par numéro de joueur.
---@param session vAvA.ChatSession
---@param targetId integer
---@param chat integer
---@return vAvA.ChatSession|nil peer
---@return string|nil code
local function resolvePeer(session, targetId, chat)
    local peer
    if chat ~= NONE then
        peer = sessions.byChat(chat)
        if not peer then return nil, 'offline' end
    elseif targetId ~= NONE then
        peer = sessions.get(targetId)
        if not peer then return nil, 'unknown_player' end
    else
        return nil, 'invalid'
    end
    if peer == session then return nil, 'self' end
    return peer
end

--- Envoie un message (RPC `vava_chat:send`, arguments déjà validés par le schéma).
---@param src integer
---@param kind string        ooc, me, do, mp, staff
---@param raw string
---@param targetId integer   numéro du joueur (/mp <n°>), 0 sinon
---@param chat integer       numéro de conversation (réponse dans un onglet), 0 sinon
---@return boolean ok
---@return string|nil code
function messages.send(src, kind, raw, targetId, chat)
    local session = sessions.get(src)
    if not session then return false, 'not_ready' end
    local body = text.clean(raw)
    if not body then return false, 'invalid' end
    if body == '' then return false, 'empty' end
    body = text.truncate(body, cfg.maxLength)

    local peer, recipients, code
    if kind == KINDS.MP then
        peer, code = resolvePeer(session, targetId, chat)
        if not peer then return false, code end
    elseif kind == KINDS.STAFF then
        -- droits relus à chaque message du Conseil (rares) : un rang retiré ferme le canal tout de suite
        sessions.refreshStaff(src)
        if not session.staff then return false, 'not_staff' end
        recipients = audience.staff()
    else
        recipients = audience.nearby(src, cfg.ranges[kind])
    end

    local payload = {
        source = src, characterId = session.characterId, kind = kind, text = body, target = peer and peer.source or nil,
    }
    local allowed, reason = core.hooks.runBefore(HOOKS.SENDING, payload)
    if not allowed then return false, type(reason) == 'string' and reason or 'refused' end

    local count
    if peer then
        sessions.link(session, peer)
        TriggerClientEvent(EVENT, peer.source, {
            kind = kind, id = src, chat = session.chat, name = session.name, staff = session.staff or nil, text = body,
        })
        TriggerClientEvent(EVENT, src, {
            kind = kind, out = true, id = peer.source, chat = peer.chat, name = peer.name, text = body,
        })
        count = 1
    else
        deliver(recipients, {
            kind = kind, id = src, name = session.name, text = body,
            staff = (kind == KINDS.OOC and session.staff) or nil,
            rank = kind == KINDS.STAFF and session.rank or nil,
        })
        count = #recipients
    end

    if cfg.log.kinds[kind] then
        logs.push(kind, session.characterId, session.name, peer and peer.characterId or NONE, peer and peer.name or '', count, body)
    end
    payload.recipients = count
    core.hooks.runAfter(HOOKS.SENT, payload)
    return true
end
