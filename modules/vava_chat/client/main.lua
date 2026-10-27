--[[
    vava_chat/client/main.lua
    Rôle : assemblage côté client : à l'apparition du personnage, profil demandé au serveur (droits du Conseil,
           commandes du serveur) ; hors du jeu (sélection), chat fermé et caché, onglets privés et textes au-dessus des
           têtes oubliés ; messages du serveur vérifiés puis remis à la page (et au-dessus de la tête pour /me et /do) ;
           liste des commandes relue quand une ressource démarre ou s'arrête ; redémarrage du module lui-même.
    Dépendances : shared/, config.lua, tous les fichiers client/ du module
]]

local type, mathType = type, math.type
local CreateThread, Wait, RegisterNetEvent, AddEventHandler, GetPlayerServerId, PlayerId =
    CreateThread, Wait, RegisterNetEvent, AddEventHandler, GetPlayerServerId, PlayerId

local core = VavaChat.core
if not core then return end

local nui = VavaChat.nui
local input = VavaChat.input
local visibility = VavaChat.visibility
local suggestions = VavaChat.suggestions
local commands = VavaChat.commands
local overhead = VavaChat.overhead
local outbox = VavaChat.outbox
local cfg = VavaChat.config
local KINDS = VavaChat.KINDS
local EVENTS = VavaChat.EVENTS
local RPC = VavaChat.RPC
local NAME_MAX = 96
local RANK_MAX = 64
local DETAIL_MAX = 160

local playing = false
-- profil courant, renvoyé à la page si elle se recharge
local profile = { staff = false }

-- genres reçus du serveur, et ceux qui s'écrivent aussi au-dessus de la tête
local RECEIVED = { [KINDS.OOC] = true, [KINDS.ME] = true, [KINDS.DO] = true, [KINDS.MP] = true, [KINDS.STAFF] = true }
local OVERHEAD = { [KINDS.ME] = true, [KINDS.DO] = true }

---@param value any
---@param max integer
---@return boolean
local function isText(value, max)
    return type(value) == 'string' and #value > 0 and #value <= max
end

---@param value any
---@return boolean
local function isId(value)
    return mathType(value) == 'integer' and value > 0
end

local function sendProfile()
    nui.send('profile', { id = GetPlayerServerId(PlayerId()), staff = profile.staff, rank = profile.rank })
end

--- Profil demandé au serveur, avec quelques essais s'il n'est pas encore prêt (module ou personnage).
local function fetchProfile()
    CreateThread(function()
        for _ = 1, cfg.profile.attempts do
            if not playing then return end
            local transport, success, result = core.rpc.call(RPC.PROFILE)
            if transport and success and type(result) == 'table' then
                profile = { staff = result.staff == true, rank = isText(result.rank, RANK_MAX) and result.rank or nil }
                suggestions.setServer(result.commands)
                sendProfile()
                return
            end
            Wait(cfg.profile.retryMs)
        end
    end)
end

local function start()
    if playing then return end
    playing = true
    input.setPlaying(true)
    visibility.setPlaying(true)
    sendProfile()
    fetchProfile()
end

local function stop()
    if not playing then return end
    playing = false
    input.setPlaying(false)
    visibility.setPlaying(false)
    overhead.clear()
    commands.reset()
    profile = { staff = false }
    nui.send('reset')
end

core.hooks.after('core:character:spawning', start)
core.hooks.after('core:character:selection', stop)
core.hooks.after('core:character:unloaded', stop)

nui.onReady(sendProfile)

RegisterNetEvent(EVENTS.MESSAGE, function(message)
    if type(message) ~= 'table' or not RECEIVED[message.kind] or not isId(message.id) then return end
    if not isText(message.name, NAME_MAX) or not isText(message.text, cfg.maxBytes) then return end
    local kind = message.kind
    local chat = message.chat
    if kind == KINDS.MP then
        if not isId(chat) then return end
        if message.out ~= true then commands.replyTo(chat) end
    end
    nui.send('message', {
        kind = kind, id = message.id, name = message.name, text = message.text,
        chat = kind == KINDS.MP and chat or nil,
        out = message.out == true or nil,
        staff = message.staff == true or nil,
        rank = isText(message.rank, RANK_MAX) and message.rank or nil,
    })
    if OVERHEAD[kind] then overhead.add(message.id, kind, message.text) end
end)

RegisterNetEvent(EVENTS.GONE, function(chat)
    if isId(chat) then nui.send('gone', { chat = chat }) end
end)

RegisterNetEvent(EVENTS.PROFILE, function(update)
    if type(update) ~= 'table' or not playing then return end
    profile = { staff = update.staff == true, rank = isText(update.rank, RANK_MAX) and update.rank or nil }
    sendProfile()
end)

RegisterNetEvent(EVENTS.NOTICE, function(code, detail)
    if not isText(code, DETAIL_MAX) then return end
    outbox.notice(nil, code, isText(detail, DETAIL_MAX) and detail or nil)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= VavaChat.resource then suggestions.changed() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == VavaChat.resource then
        nui.focus(false)
        return
    end
    suggestions.changed()
end)

-- module redémarré en cours de partie
if core.characters.current() and not core.characters.awaitingSelection() then start() end
