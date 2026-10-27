--[[
    vava_magic/client/spells/murmure.lua
    Rôle : sort Murmure côté client : parchemin d'écriture (touche ou /murmure ; contacts gardés, cercle et longueur
           selon le niveau, position jointe dès le niveau 3), envoi direct par `/murmure <n°[,n°…]> <message>`,
           fragments reçus du serveur pour l'affichage au-dessus des mains, message reçu sur un parchemin (nom du
           contact ou « présence inconnue »), point de passage sur la carte si la position est jointe.
    Le serveur décide de tout (contacts, longueur, fragments, déformation, portée).
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local type, ipairs, tonumber, tointeger = type, ipairs, tonumber, math.tointeger
local gmatch, concat = string.gmatch, table.concat
local CreateThread, RegisterNetEvent, SetNewWaypoint = CreateThread, RegisterNetEvent, SetNewWaypoint

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local casting = VavaMagic.casting
local ambient = VavaMagic.ambient
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local cfg = VavaMagic.config
local spellCfg = cfg.spells.murmure
local texts = cfg.texts
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local NAME = 'murmure'

local murmure = {}
VavaMagic.murmure = murmure

--- Lance l'incantation d'un murmure.
---@param targets integer[]  rangs des contacts
---@param message string
---@param sharePosition boolean
local function send(targets, message, sharePosition)
    casting.start(NAME, { args = { targets, message, sharePosition == true }, count = 3 })
end

--- Ouvre le parchemin d'écriture (contacts demandés au serveur).
function murmure.compose()
    CreateThread(function()
        local ok, code = casting.check(NAME, {})
        if not ok then
            messages.refuse(code)
            return
        end
        local transport, success, list = core.rpc.call(RPC.SIGILS)
        if not transport or not success then
            messages.refuse(transport and list or success)
            return
        end
        local levelCfg = spellCfg.levels[state.level(NAME)]
        nui.open('composer', {
            contacts = list.contacts, circle = levelCfg.circle, maxLength = levelCfg.maxLength,
            waypoint = levelCfg.waypoint, cost = state.cost(NAME),
        })
    end)
end

nui.on('composer:send', function(data)
    nui.close('composer')
    local targets = {}
    if type(data.targets) == 'table' then
        for _, value in ipairs(data.targets) do
            local index = tointeger(tonumber(value))
            if index then targets[#targets + 1] = index end
        end
    end
    if #targets == 0 then
        messages.refuse('no_target')
        return { ok = true }
    end
    if type(data.text) ~= 'string' or data.text == '' then
        messages.refuse('empty_message')
        return { ok = true }
    end
    send(targets, data.text, data.position == true)
    return { ok = true }
end)

-- fragments d'un murmure en cours près de soi (envoyés par le seul serveur, aux joueurs à moins de 3 m)
RegisterNetEvent(EVENTS.FRAGMENTS, function(caster, _, words, ms)
    if type(caster) ~= 'number' or type(words) ~= 'table' or type(ms) ~= 'number' then return end
    ambient.setFragments(caster, words, ms)
end)

-- murmure reçu
RegisterNetEvent(EVENTS.MURMUR, function(payload)
    if type(payload) ~= 'table' or type(payload.text) ~= 'string' then return end
    local waypoint = type(payload.waypoint) == 'table' and payload.waypoint or nil
    nui.send('murmur:show', {
        from = type(payload.from) == 'string' and payload.from or nil, text = payload.text,
        waypoint = waypoint ~= nil, ms = spellCfg.readMs,
    })
    nui.send('sound', { name = 'chime', volume = 1.0 })
    if waypoint and type(waypoint.x) == 'number' and type(waypoint.y) == 'number' then
        SetNewWaypoint(waypoint.x, waypoint.y)
        bridge.Notify(texts.notify.murmurWaypoint, 'info')
    end
end)

keys.bind('murmure', murmure.compose)

-- /murmure ouvre le parchemin ; /murmure 1,3 Rendez-vous au moulin : envoi direct
keys.command(cfg.commands.murmure, texts.suggestions.murmure, function(args)
    if #args == 0 then
        murmure.compose()
        return
    end
    local targets = {}
    for value in gmatch(args[1], '[^,]+') do
        local index = tointeger(tonumber(value))
        if not index then
            bridge.ChatLines({ texts.chat.murmurUsage })
            return
        end
        targets[#targets + 1] = index
    end
    local message = concat(args, ' ', 2)
    if #targets == 0 or message == '' then
        bridge.ChatLines({ texts.chat.murmurUsage })
        return
    end
    send(targets, message, false)
end)
