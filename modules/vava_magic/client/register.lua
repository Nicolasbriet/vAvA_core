--[[
    vava_magic/client/register.lua
    Rôle : registre des murmures ouvert en l'utilisant (premier lot de pages envoyé par le serveur, les plus récentes
           d'abord) ; la page demande les lots plus anciens quand le lecteur feuillette (le serveur revérifie qu'il
           porte le registre) ; celui qui le porte peut arracher une page (même vérification).
    Dépendances : shared/, config_client.lua, client/ (noyau)
]]

local type, tonumber, tointeger = type, tonumber, math.tointeger
local RegisterNetEvent = RegisterNetEvent

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local messages = VavaMagic.messages
local notify = VavaMagic.config.texts.notify
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS

RegisterNetEvent(EVENTS.REGISTER, function(payload)
    if type(payload) ~= 'table' or type(payload.pages) ~= 'table' then return end
    nui.open('register', payload)
end)

-- lot plus ancien : `before` = numéro de la plus ancienne page déjà reçue
nui.on('register:more', function(data)
    local id, before = tointeger(tonumber(data.id)), tointeger(tonumber(data.before))
    if not id or not before or id < 1 or before < 1 then return { ok = false } end
    local transport, success, result = core.rpc.call(RPC.REGISTER_PAGES, id, before)
    if not transport or not success then
        messages.refuse(transport and result or success)
        return { ok = false }
    end
    if type(result) ~= 'table' or type(result.pages) ~= 'table' then return { ok = false } end
    return { ok = true, pages = result.pages, more = result.more == true }
end)

nui.on('register:tear', function(data)
    local id, page = tointeger(tonumber(data.id)), tointeger(tonumber(data.page))
    if not id or not page then return { ok = false } end
    local transport, success, code = core.rpc.call(RPC.REGISTER_TEAR, id, page)
    if not transport or not success then
        messages.refuse(transport and code or success)
        return { ok = false }
    end
    bridge.Notify(notify.pageTorn, 'info')
    return { ok = true }
end)
