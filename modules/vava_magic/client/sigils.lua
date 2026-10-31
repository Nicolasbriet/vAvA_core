--[[
    vava_magic/client/sigils.lua
    Rôle : sigils côté client : répondre à un sigil tendu (le nommer, confier le sien en retour, ou refuser), nommer
           celui reçu en retour, confirmer le brouillage de son sigil ; commandes /sigils (liste dans le chat) et
           /sigil offrir | renommer <n°> <nom> | oublier <n°> | brouiller. Le serveur décide de tout (distance,
           mémoire pleine, mana, recharge).
    Dépendances : shared/, config_client.lua, client/ (noyau)
]]

local type, ipairs, tonumber, select, tointeger, lower = type, ipairs, tonumber, select, math.tointeger, string.lower
local concat, unpack = table.concat, table.unpack
local CreateThread, RegisterNetEvent = CreateThread, RegisterNetEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local cfg = VavaMagic.config
local texts = cfg.texts
local actions = cfg.commands.sigilActions
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS

-- offre affichée (une à la fois)
local shown = nil

--- Appel au serveur dans un thread ; `done(result)` en cas de succès, message de refus sinon.
local function request(name, done, ...)
    local args, count = { ... }, select('#', ...)
    CreateThread(function()
        local transport, success, result, extra = core.rpc.call(name, unpack(args, 1, count))
        if not transport then
            messages.refuse(success)
        elseif not success then
            messages.refuse(result, extra)
        elseif done then
            done(result)
        end
    end)
end

RegisterNetEvent(EVENTS.SIGIL_OFFER, function(id, seconds)
    if type(id) ~= 'number' or type(seconds) ~= 'number' then return end
    shown = id
    nui.open('offer', { id = id, seconds = seconds, nameMax = cfg.sigils.nameMax }, function()
        -- fenêtre fermée sans réponse : refus
        if shown == id then
            shown = nil
            request(RPC.SIGIL_ANSWER, nil, id, false, '', false)
        end
    end)
end)

RegisterNetEvent(EVENTS.SIGIL_NAMING, function(id, seconds)
    if type(id) ~= 'number' or type(seconds) ~= 'number' then return end
    shown = id
    nui.open('naming', { id = id, seconds = seconds, nameMax = cfg.sigils.nameMax }, function()
        if shown == id then
            shown = nil
            request(RPC.SIGIL_NAME, nil, id, false, '')
        end
    end)
end)

RegisterNetEvent(EVENTS.SIGIL_CLOSED, function(id)
    if shown == id then
        shown = nil
        local modal = nui.modal()
        if modal == 'offer' or modal == 'naming' then nui.close(modal) end
    end
end)

nui.on('offer:answer', function(data)
    local id = tointeger(tonumber(data.id))
    if not id or id ~= shown then return { ok = false } end
    shown = nil
    nui.close('offer')
    request(RPC.SIGIL_ANSWER, nil, id, data.accept == true, type(data.name) == 'string' and data.name or '', data.giveBack == true)
    return { ok = true }
end)

nui.on('naming:answer', function(data)
    local id = tointeger(tonumber(data.id))
    if not id or id ~= shown then return { ok = false } end
    shown = nil
    nui.close('naming')
    request(RPC.SIGIL_NAME, nil, id, data.accept == true, type(data.name) == 'string' and data.name or '')
    return { ok = true }
end)

nui.on('confirm:answer', function(data)
    nui.close('confirm')
    if data.kind == 'scramble' and data.accept == true then request(RPC.SIGIL_SCRAMBLE) end
    return { ok = true }
end)

--- Liste des sigils dans le chat.
local function list()
    request(RPC.SIGILS, function(result)
        local chat = texts.chat
        local lines = { chat.sigilsTitle:format(#result.contacts, result.limit) }
        if #result.contacts == 0 then lines[#lines + 1] = chat.sigilsNone end
        for _, contact in ipairs(result.contacts) do lines[#lines + 1] = chat.sigilLine:format(contact.index, contact.name) end
        lines[#lines + 1] = chat.sigilsHint
        bridge.ChatLines(lines)
    end)
end

keys.command(cfg.commands.sigils, texts.suggestions.sigils, list)

keys.command(cfg.commands.sigil, texts.suggestions.sigil, function(args)
    local action = lower(args[1] or '')
    if action == actions.offer then
        request(RPC.SIGIL_OFFER, function() bridge.Notify(texts.notify.sigilOffered, 'info') end)
    elseif action == actions.rename then
        local index = tointeger(tonumber(args[2]))
        local name = concat(args, ' ', 3)
        if not index or name == '' then
            bridge.ChatLines({ texts.chat.sigilUsage })
            return
        end
        request(RPC.SIGIL_RENAME, nil, index, name)
    elseif action == actions.forget then
        local index = tointeger(tonumber(args[2]))
        if not index then
            bridge.ChatLines({ texts.chat.sigilUsage })
            return
        end
        request(RPC.SIGIL_FORGET, nil, index)
    elseif action == actions.scramble then
        if not state.isMage() or not state.level(cfg.sigils.spell) then
            messages.refuse(not state.isMage() and 'not_mage' or 'unknown_spell')
            return
        end
        nui.open('confirm', { kind = 'scramble', cost = cfg.sigils.scramble.cost })
    elseif action == '' then
        list()
    else
        bridge.ChatLines({ texts.chat.sigilUsage })
    end
end)
