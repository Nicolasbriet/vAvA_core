--[[
    vava_cameras/client/nui.lua
    Rôle : pont avec l'interface du module (capture invisible et mur des caméras). Les ordres arrivés avant que la
           page se dise prête attendent (en nombre borné) ; le focus n'est pris que mur ouvert. Chaque retour de
           l'interface est isolé : une erreur renvoie un code au lieu de la laisser sans réponse.
    Dépendances : client/core.lua
]]

local type, ipairs, tostring, xpcall = type, ipairs, tostring, xpcall
local traceback, remove = debug.traceback, table.remove
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}
-- ordres gardés avant que la page soit prête (au-delà, les plus anciens sont perdus : le serveur les rattrape)
local PENDING_MAX = 32

local nui = {}
VavaCameras.nui = nui

local ready = false
local pending = {}

---@return boolean
function nui.isReady()
    return ready
end

---@param action string
---@param payload? table
function nui.send(action, payload)
    local message = { action = action, payload = payload or EMPTY }
    if ready then
        SendNUIMessage(message)
        return
    end
    if #pending >= PENDING_MAX then remove(pending, 1) end
    pending[#pending + 1] = message
end

---@param enabled boolean
function nui.setFocus(enabled)
    SetNuiFocus(enabled, enabled)
end

---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            VavaCameras.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end

nui.on('ready', function()
    ready = true
    for _, message in ipairs(pending) do SendNUIMessage(message) end
    pending = {}
    return { ok = true }
end)
