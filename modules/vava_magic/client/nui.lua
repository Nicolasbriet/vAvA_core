--[[
    vava_magic/client/nui.lua
    Rôle : pont avec l'interface du module (barre d'incantation, parchemin reçu, parchemin d'écriture, offres de
           sigil, grimoire, registre). Les textes de la config partent à la page dès qu'elle se dit prête ; les ordres
           arrivés avant attendent (en nombre borné). Une seule fenêtre à la fois prend le focus ; Échap la ferme.
           Chaque retour de l'interface est isolé : une erreur renvoie un code au lieu de la laisser sans réponse.
    Dépendances : config_client.lua, client/core.lua
]]

local type, ipairs, tostring, xpcall = type, ipairs, tostring, xpcall
local traceback, remove = debug.traceback, table.remove
local SendNUIMessage, SetNuiFocus, RegisterNUICallback = SendNUIMessage, SetNuiFocus, RegisterNUICallback

local EMPTY = {}
-- ordres gardés avant que la page soit prête (au-delà, les plus anciens sont perdus)
local PENDING_MAX = 32

local nui = {}
VavaMagic.nui = nui

local ready = false
local pending = {}
-- fenêtre ouverte (qui a le focus) et ce qu'il faut faire à sa fermeture
local modal = nil
local onClose = nil

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

---@return string|nil
function nui.modal()
    return modal
end

--- Ouvre une fenêtre (une seule à la fois : la précédente est fermée sans réponse).
---@param name string
---@param payload table
---@param closed? fun()  appelée si la fenêtre se ferme sans réponse (Échap, bouton Fermer)
function nui.open(name, payload, closed)
    if modal and onClose then
        local previous = onClose
        onClose = nil
        previous()
    end
    modal = name
    onClose = closed
    nui.send('modal:' .. name, payload)
    SetNuiFocus(true, true)
end

--- Ferme la fenêtre ouverte (si c'est bien `name`, quand il est donné).
---@param name? string
function nui.close(name)
    if not modal or (name and modal ~= name) then return end
    modal = nil
    onClose = nil
    nui.send('modal:close')
    SetNuiFocus(false, false)
end

---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            VavaMagic.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end

nui.on('ready', function()
    ready = true
    SendNUIMessage({ action = 'init', payload = { texts = VavaMagic.config.texts.ui, sounds = VavaMagic.config.sounds.files } })
    for _, message in ipairs(pending) do SendNUIMessage(message) end
    pending = {}
    return { ok = true }
end)

-- Échap ou bouton Fermer
nui.on('close', function()
    local closed = onClose
    modal = nil
    onClose = nil
    SetNuiFocus(false, false)
    if closed then closed() end
    return { ok = true }
end)
