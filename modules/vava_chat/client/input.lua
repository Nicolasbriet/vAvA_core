--[[
    vava_chat/client/input.lua
    Rôle : ouverture du chat par sa touche (réglable dans Paramètres > Raccourcis > FiveM), au relâchement pour que
           la lettre ne soit pas tapée dans la saisie ; jamais par-dessus une autre fenêtre ni le menu pause. Le chat
           ouvert a le clavier et la souris (onglets, déplacement) ; Entrée envoie et ferme, Échap ferme.
           Le chat de GTA (touche T du mode en ligne) est coupé.
    Dépendances : config.lua, client/nui.lua, client/suggestions.lua, client/commands.lua
]]

local type, mathType = type, math.type
local RegisterCommand, RegisterKeyMapping, IsNuiFocused, IsPauseMenuActive, SetTextChatEnabled =
    RegisterCommand, RegisterKeyMapping, IsNuiFocused, IsPauseMenuActive, SetTextChatEnabled

local nui = VavaChat.nui
local suggestions = VavaChat.suggestions
local commands = VavaChat.commands
local cfg = VavaChat.config
local KEY = cfg.key
local TAB_MAX = 16
local CHAT_MAX = 0x7FFFFFFF
-- borne de ce que la page peut envoyer (message et sa commande)
local SUBMIT_MAX = cfg.maxBytes + 160

local input = {}
VavaChat.input = input

local playing = false
local open = false

---@param value boolean
function input.setPlaying(value)
    playing = value
    if not value then input.close() end
end

---@return boolean
function input.isOpen()
    return open
end

function input.open()
    if open or not playing or IsNuiFocused() or IsPauseMenuActive() then return end
    open = true
    suggestions.refresh()
    nui.send('open')
    nui.focus(true)
end

--- Ferme le chat (sélection du personnage, arrêt du module).
function input.close()
    if not open then return end
    open = false
    nui.send('close')
    nui.focus(false)
end

-- la page s'est fermée (Échap, ou après un envoi)
nui.on('close', function()
    open = false
    nui.focus(false)
    return { ok = true }
end)

-- texte tapé : { text, tab, chat? } (chat : correspondant d'un onglet privé)
nui.on('submit', function(data)
    local message, tab, chat = data.text, data.tab, data.chat
    if type(message) ~= 'string' or #message > SUBMIT_MAX or type(tab) ~= 'string' or #tab > TAB_MAX then
        return { ok = false, error = 'invalid_args' }
    end
    if chat ~= nil and (mathType(chat) ~= 'integer' or chat < 1 or chat > CHAT_MAX) then
        return { ok = false, error = 'invalid_args' }
    end
    commands.submit(message, tab, chat)
    return { ok = true }
end)

RegisterCommand('+' .. KEY.command, function() end, false)
RegisterCommand('-' .. KEY.command, function() input.open() end, false)
RegisterKeyMapping('+' .. KEY.command, KEY.label, 'keyboard', KEY.key)

SetTextChatEnabled(false)
