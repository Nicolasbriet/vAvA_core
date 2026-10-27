--[[
    vava_chat/client/outbox.lua
    Rôle : départ d'un message vers le serveur (RPC) et avis montrés dans le chat, dans l'onglet d'où le message est
           parti : refus du serveur, limite de débit, usage d'une commande. Le message lui-même revient du serveur
           (texte nettoyé) : rien n'est affiché avant son accord.
    Dépendances : config.lua, client/core.lua, client/nui.lua
]]

local type, format = type, string.format
local CreateThread = CreateThread

local core = VavaChat.core
if not core then return end

local nui = VavaChat.nui
local texts = VavaChat.config.texts
local RPC = VavaChat.RPC
local MP = VavaChat.KINDS.MP
local GENERAL = 'general'
local NONE = 0

-- codes de transport du core ramenés à un avis connu
local TRANSPORT = {
    busy = 'rate_limited',
    unknown_rpc = 'not_ready',
    invalid_args = 'invalid',
}

local outbox = {}
VavaChat.outbox = outbox

--- Avis dans un onglet (Général par défaut) : code d'erreur, ou texte déjà écrit.
---@param tab string|nil
---@param code string
---@param detail? string
function outbox.notice(tab, code, detail)
    local template = texts.errors[code]
    local message = template and (detail and format(template, detail) or template) or format(texts.errors.unknown, code)
    nui.send('notice', { tab = tab or GENERAL, text = message })
end

--- Texte d'avis tel quel (usage d'une commande, confirmation).
---@param tab string|nil
---@param message string
function outbox.say(tab, message)
    nui.send('notice', { tab = tab or GENERAL, text = message })
end

--- Envoie un message ; un refus s'affiche dans l'onglet `tab`.
---@param kind string
---@param body string
---@param target integer|nil   numéro du joueur (/mp <n°>)
---@param chat integer|nil     numéro de conversation (réponse dans un onglet)
---@param tab string|nil
function outbox.send(kind, body, target, chat, tab)
    CreateThread(function()
        local transport, success, code = core.rpc.call(RPC.SEND, kind, body, target or NONE, chat or NONE)
        if transport and success then return end
        local reason = transport and code or success
        reason = type(reason) == 'string' and (TRANSPORT[reason] or reason) or 'unknown'
        -- le correspondant est parti : son onglet se grise
        if reason == 'offline' and kind == MP and chat then nui.send('gone', { chat = chat }) end
        outbox.notice(tab, reason)
    end)
end
