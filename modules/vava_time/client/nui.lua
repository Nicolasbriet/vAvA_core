--[[
    vava_time/client/nui.lua
    Rôle : pont avec l'interface de l'outil « Ciel et heure ». Rien n'est envoyé avant que la page se dise prête ; le
           focus n'est pris qu'outil ouvert. Chaque retour de l'interface est isolé : une erreur renvoie un code au lieu
           de la laisser sans réponse.
    Dépendances : client/core.lua
]]

local type, tostring, xpcall = type, tostring, xpcall
local traceback = debug.traceback
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}

local nui = {}
VavaTime.nui = nui

local ready = false

---@return boolean
function nui.isReady()
    return ready
end

---@param action string
---@param payload? table
function nui.send(action, payload)
    if ready then SendNUIMessage({ action = action, payload = payload or EMPTY }) end
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
            VavaTime.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
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
