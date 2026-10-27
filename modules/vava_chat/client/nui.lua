--[[
    vava_chat/client/nui.lua
    Rôle : pont avec la page du chat. Quand la page se dit prête (premier chargement ou rechargement), elle reçoit
           ses textes et réglages, puis chaque fichier du module lui renvoie son état complet (place, suggestions,
           profil) ; les ordres arrivés avant attendent (en nombre borné). Chaque retour de la page est isolé : une
           erreur renvoie un code au lieu de la laisser sans réponse.
    Dépendances : config.lua, client/core.lua
]]

local type, ipairs, tostring, xpcall = type, ipairs, tostring, xpcall
local traceback, remove = debug.traceback, table.remove
local SendNUIMessage, RegisterNUICallback, SetNuiFocus, SetNuiFocusKeepInput =
    SendNUIMessage, RegisterNUICallback, SetNuiFocus, SetNuiFocusKeepInput

local cfg = VavaChat.config
local EMPTY = {}
-- ordres gardés avant que la page soit prête (au-delà, les plus anciens sont perdus)
local PENDING_MAX = 64
-- signes de commande permis en plus du message dans la saisie (« /mp 128 »)
local COMMAND_ROOM = 40

local nui = {}
VavaChat.nui = nui

local ready = false
local pending = {}
local readyHandlers = {}

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

--- La page a-t-elle dit qu'elle était prête ?
---@return boolean
function nui.isReady()
    return ready
end

--- `handler` est appelé chaque fois que la page (re)devient prête, pour lui renvoyer un état complet.
---@param handler fun()
function nui.onReady(handler)
    readyHandlers[#readyHandlers + 1] = handler
end

---@param name string
---@param handler fun(data: table): table|nil
function nui.on(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = xpcall(handler, traceback, type(data) == 'table' and data or {})
        if not ok then
            VavaChat.log.error("retour d'interface '%s' en erreur : %s", name, tostring(result))
            cb({ ok = false, error = 'client_error' })
            return
        end
        cb(result or { ok = true })
    end)
end

--- Clavier et souris à la page (chat ouvert), ou rendus au jeu.
---@param enabled boolean
function nui.focus(enabled)
    SetNuiFocus(enabled, enabled)
    if enabled then SetNuiFocusKeepInput(false) end
end

nui.on('ready', function()
    ready = true
    local ui = cfg.ui
    SendNUIMessage({ action = 'init', payload = {
        texts = cfg.texts.ui,
        settings = {
            maxLength = cfg.maxLength,
            inputMax = cfg.maxLength + COMMAND_ROOM,
            maxMessages = ui.maxMessages,
            historyMax = ui.historyMax,
            fadeMs = ui.fadeMs,
            suggestionsMax = ui.suggestionsMax,
            minSize = ui.minSize,
            defaultLayout = ui.defaultLayout,
            mpCommand = cfg.commands.mp,
        },
    } })
    for _, handler in ipairs(readyHandlers) do handler() end
    for _, message in ipairs(pending) do SendNUIMessage(message) end
    pending = {}
    return { ok = true }
end)
