--[[
    vava_atelier/client/nui.lua
    Rôle : SEUL pont entre l'interface web et le Lua : messages sortants `{ action, payload }` (open, close, notify,
           editorGone, mode, keys, entryChanged ; T-102 : placing, placed, placeRefused, undone, suspended), focus,
           retours entrants isolés (une erreur renvoie `{ ok = false, error = 'client_error' }` à l'interface au lieu
           de la laisser sans réponse).
    Dépendances : client/core.lua
]]

local type, tostring, xpcall = type, tostring, xpcall
local traceback = debug.traceback
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}

local nui = {}
VavaAtelier.nui = nui

--- Message vers la page : `{ action, payload }`, jamais à chaque image (seulement à un changement).
---@param action string
---@param payload? table
function nui.send(action, payload)
    SendNUIMessage({ action = action, payload = payload or EMPTY })
end

---@param enabled boolean
function nui.setFocus(enabled)
    SetNuiFocus(enabled, enabled)
end

--- Retour de la page : `handler(data)` rend la réponse `{ ok, error?, data? }` (ou rien : `{ ok = true }`).
---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            VavaAtelier.core.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end
