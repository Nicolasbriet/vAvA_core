--[[
    vava_chat/client/commands.lua
    Rôle : ce que le joueur tape, d'où qu'il le tape :
      - une commande du chat (/ooc, /me, /do, /mp, /r, /staff, /chat) est traitée ici, avec l'onglet d'origine
        pour y montrer un refus ; toute autre commande part à FiveM (ExecuteCommand : commandes du client, puis du
        serveur) ;
      - un texte sans commande dépend de l'onglet : hors-RP dans Général, message à son correspondant dans un
        onglet privé, au Conseil dans le sien ; rien dans Actions (un rappel de /me et /do s'affiche).
      Les commandes du chat marchent aussi depuis la console F8. Suggestions françaises de chaque commande (/staff
      pour le seul Conseil).
      Toute commande tapée est signalée au Codex (vava_codex, s'il est là) pour ses « dernières pages ».
    Dépendances : shared/, config.lua, client/outbox.lua, client/suggestions.lua, client/layout.lua
]]

local type, tonumber, pairs, pcall, tostring, match, sub, lower = type, tonumber, pairs, pcall, tostring, string.match, string.sub, string.lower
local RegisterCommand, ExecuteCommand, GetResourceState = RegisterCommand, ExecuteCommand, GetResourceState
local CODEX = 'vava_codex'

local outbox = VavaChat.outbox
local suggestions = VavaChat.suggestions
local layout = VavaChat.layout
local cfg = VavaChat.config
local texts = cfg.texts
local COMMANDS = cfg.commands
local KINDS = VavaChat.KINDS
local TABS = { GENERAL = 'general', ACTIONS = 'actions', STAFF = 'staff', MP = 'mp' }

local commands = {}
VavaChat.commands = commands
commands.TABS = TABS

-- dernier correspondant qui a écrit (/r)
local replyChat = nil

---@param chat integer
function commands.replyTo(chat)
    replyChat = chat
end

function commands.reset()
    replyChat = nil
end

---@param value string
---@return string
local function trim(value)
    return match(value, '^ *(.-) *$')
end

--- Commande qui envoie son texte tel quel (genre de message).
---@param kind string
---@param usage string
local function speak(kind, usage)
    return function(body, tab)
        if body == '' then return outbox.say(tab, usage) end
        outbox.send(kind, body, nil, nil, tab)
    end
end

---@type table<string, fun(body: string, tab: string|nil)>
local handlers = {
    [COMMANDS.ooc] = speak(KINDS.OOC, texts.usage.ooc),
    [COMMANDS.me] = speak(KINDS.ME, texts.usage.me),
    [COMMANDS['do']] = speak(KINDS.DO, texts.usage['do']),
    [COMMANDS.staff] = speak(KINDS.STAFF, texts.usage.staff),
    [COMMANDS.mp] = function(body, tab)
        local id, message = match(body, '^([0-9]+) +(.+)$')
        local target = id and tonumber(id)
        if not target then return outbox.say(tab, texts.usage.mp) end
        outbox.send(KINDS.MP, message, target, nil, tab)
    end,
    [COMMANDS.reply] = function(body, tab)
        if body == '' then return outbox.say(tab, texts.usage.reply) end
        if not replyChat then return outbox.notice(tab, 'no_reply') end
        outbox.send(KINDS.MP, body, nil, replyChat, tab)
    end,
    [COMMANDS.chat] = function(body, tab)
        if lower(body) ~= COMMANDS.reset then return outbox.say(tab, texts.usage.chat) end
        layout.reset()
        outbox.say(tab, texts.reset)
    end,
}

--- Ligne tapée dans le chat (sans le « / » pour une commande).
---@param line string   commande et ses arguments
---@param tab string|nil
local function noteToCodex(line)
    return exports[CODEX]:noteCommand(line)
end

--- Le Codex inscrit la commande tapée à ses « dernières pages » ; isolé : sans lui, rien.
---@param line string
local function note(line)
    if GetResourceState(CODEX) ~= 'started' then return end
    local called, err = pcall(noteToCodex, line)
    if not called then VavaChat.log.warn('%s.noteCommand en erreur : %s', CODEX, tostring(err)) end
end

local function runCommand(line, tab)
    local name, rest = match(line, '^([^ ]+) ?(.*)$')
    local handler = name and handlers[lower(name)]
    if name then note(line) end
    if handler then
        handler(trim(rest), tab)
    elseif name then
        ExecuteCommand(line)
    end
end

--- Ce que le joueur a tapé dans l'onglet `tab` (`chat` : son correspondant dans un onglet privé).
---@param message string
---@param tab string
---@param chat integer|nil
function commands.submit(message, tab, chat)
    message = trim(message)
    if message == '' then return end
    -- onglet où montrer un refus (« mp:<conversation> » pour un onglet privé)
    local origin = (tab == TABS.MP and chat) and (TABS.MP .. ':' .. chat) or tab
    if sub(message, 1, 1) == '/' then return runCommand(sub(message, 2), origin) end
    if tab == TABS.ACTIONS then return outbox.notice(origin, 'actions_hint') end
    if tab == TABS.STAFF then return outbox.send(KINDS.STAFF, message, nil, nil, origin) end
    if tab == TABS.MP then
        -- un onglet privé sans correspondant n'envoie rien (jamais en hors-RP par erreur)
        if chat then outbox.send(KINDS.MP, message, nil, chat, origin) end
        return
    end
    outbox.send(KINDS.OOC, message, nil, nil, TABS.GENERAL)
end

-- les mêmes commandes depuis la console F8 (avis dans Général)
for name, handler in pairs(handlers) do
    RegisterCommand(name, function(_, _, raw)
        handler(trim(type(raw) == 'string' and (match(raw, '^[^ ]* ?(.*)$') or '') or ''), nil)
    end, false)
end

-- /staff n'est suggéré qu'au Conseil (profil) ; les autres commandes du chat à tous
for key, name in pairs(COMMANDS) do
    local suggestion = texts.suggestions[key]
    if suggestion then
        local declare = key == 'staff' and suggestions.reserve or suggestions.add
        declare(name, suggestion.help, suggestion.params)
    end
end
