--[[
    vava_skills/client/nui.lua
    Rôle : pont entre l'interface web (livre des compétences) et le Lua : messages sortants, retours entrants isolés
           (une erreur renvoie un code à l'interface au lieu de la laisser sans réponse).
    Dépendances : client/core.lua
]]

local type, tostring, xpcall = type, tostring, xpcall
local traceback = debug.traceback
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}

local nui = {}
VavaSkills.nui = nui

---@param action string
---@param payload? table
function nui.send(action, payload)
    SendNUIMessage({ action = action, payload = payload or EMPTY })
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
            VavaSkills.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end
