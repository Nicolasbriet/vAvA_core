--[[
    vava_characters_ui/client/nui.lua
    Rôle : pont entre l'interface web et le Lua : messages sortants, retours entrants. Chaque retour est isolé :
           une erreur renvoie un code à l'interface au lieu de la laisser sans réponse.
    Dépendances : client/core.lua
]]

local type, tostring, xpcall = type, tostring, xpcall
local traceback = debug.traceback
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local log = VavaCharactersUi.core.log
local EMPTY = {}

local nui = {}
VavaCharactersUi.nui = nui

---@param action string
---@param payload? table
function nui.send(action, payload)
    SendNUIMessage({ action = action, payload = payload or EMPTY })
end

--- Le focus (clavier et souris) n'est pris que pendant que l'interface est ouverte.
---@param enabled boolean
function nui.setFocus(enabled)
    SetNuiFocus(enabled, enabled)
end

--- Enregistre un retour de l'interface. Le handler reçoit une table (jamais nil) et renvoie la réponse.
---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end
