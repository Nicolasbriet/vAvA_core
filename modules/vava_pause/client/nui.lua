--[[
    vava_pause/client/nui.lua
    Rôle : SEUL fichier qui parle à la page de la bannière : messages sortants (jamais par image), focus, rappels
           entrants isolés (une erreur renvoie un code à la page au lieu de la laisser sans réponse). La page se dit
           prête par le rappel `ready` ; avant, rien n'est déployé (une page absente ne prend pas la souris).
    Dépendances : client/core.lua
]]

local type, tostring, xpcall = type, tostring, xpcall
local traceback = debug.traceback
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}

local nui = {}
VavaPause.nui = nui

local ready = false

---@param action string
---@param payload? table
function nui.send(action, payload)
    SendNUIMessage({ action = action, payload = payload or EMPTY })
end

---@param enabled boolean
function nui.setFocus(enabled)
    SetNuiFocus(enabled, enabled)
end

---@return boolean  la page s'est dite prête
function nui.isReady()
    return ready
end

---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            VavaPause.core.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end

nui.on('ready', function()
    ready = true
    return { ok = true }
end)
