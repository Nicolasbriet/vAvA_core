--[[
    vava_magic/client/register.lua
    Rôle : registre des murmures ouvert en l'utilisant (pages envoyées par le serveur, les plus récentes d'abord) ;
           celui qui le porte peut arracher une page (le serveur vérifie qu'il l'a sur lui).
    Dépendances : shared/, config.lua, client/ (noyau)
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
