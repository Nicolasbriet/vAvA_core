--[[
    vava_chat/client/compat.lua
    Rôle : évènements de la ressource « chat » de FiveM, repris tels quels pour que les autres ressources marchent
           sans changement (localement par TriggerEvent, ou depuis le serveur par TriggerClientEvent) :
           chat:addMessage, chatMessage, chat:addSuggestion(s), chat:removeSuggestion, chat:clear et l'affichage des
           réponses des commandes du serveur. Leurs messages arrivent dans l'onglet Général, en texte brut : les
           modèles HTML (chat:addTemplate, templateId) ne sont jamais interprétés, seuls leurs arguments sont lus.
           Les modes (chat:addMode) n'existent pas ici : leurs évènements sont acceptés sans effet.
    Dépendances : shared/, config.lua, client/nui.lua, client/suggestions.lua
]]

local type, tostring, pairs, floor, concat = type, tostring, pairs, math.floor, table.concat
local RegisterNetEvent = RegisterNetEvent

local text = VavaChat.text
local nui = VavaChat.nui
local suggestions = VavaChat.suggestions
local cfg = VavaChat.config
local COMPAT = VavaChat.COMPAT
local SYSTEM = VavaChat.KINDS.SYSTEM
local ARGS_MAX = 8
local AUTHOR_MAX = 32
local COLOR_MAX = 255
local LIST_MAX = 400

local compat = {}
VavaChat.compat = compat

---@param color any
---@return integer[]|nil
local function cleanColor(color)
    if type(color) ~= 'table' then return nil end
    local clean = {}
    for i = 1, 3 do
        local value = color[i]
        if type(value) ~= 'number' or value ~= value or value < 0 or value > COLOR_MAX then return nil end
        clean[i] = floor(value)
    end
    return clean
end

--- Message d'une autre ressource, montré dans l'onglet Général.
---@param author any
---@param body any
---@param color any
function compat.show(author, body, color)
    body = text.clean(type(body) == 'number' and tostring(body) or body, true)
    if not body or body == '' then return end
    author = text.clean(author)
    nui.send('message', {
        kind = SYSTEM,
        author = author and author ~= '' and text.truncate(author, AUTHOR_MAX) or nil,
        text = text.truncate(body, cfg.systemMaxLength),
        color = cleanColor(color),
    })
end

--- Forme { args, color, multiline, template, templateId, params } ou texte de chat:addMessage.
---@param message any
local function addMessage(message)
    if type(message) == 'string' then
        compat.show(nil, message)
        return
    end
    if type(message) ~= 'table' or type(message.args) ~= 'table' then return end
    local parts = {}
    for i = 1, ARGS_MAX do
        local value = message.args[i]
        local kind = type(value)
        if kind ~= 'string' and kind ~= 'number' then break end
        parts[#parts + 1] = tostring(value)
    end
    if #parts == 0 then return end
    if #parts == 1 then
        compat.show(nil, parts[1], message.color)
    else
        compat.show(parts[1], concat(parts, ' ', 2), message.color)
    end
end

local handlers = {
    [COMPAT.ADD_MESSAGE] = addMessage,
    [COMPAT.CHAT_MESSAGE] = function(author, color, body) compat.show(author, body, color) end,
    [COMPAT.ADD_SUGGESTION] = suggestions.add,
    [COMPAT.ADD_SUGGESTIONS] = function(list)
        if type(list) ~= 'table' then return end
        for i = 1, LIST_MAX do
            local entry = list[i]
            if type(entry) ~= 'table' then break end
            suggestions.add(entry.name, entry.help, entry.params)
        end
    end,
    [COMPAT.REMOVE_SUGGESTION] = suggestions.remove,
    [COMPAT.CLEAR] = function() nui.send('clear') end,
    [COMPAT.SERVER_PRINT] = function(message) compat.show(nil, message) end,
    [COMPAT.ADD_TEMPLATE] = function() end,
    [COMPAT.ADD_MODE] = function() end,
    [COMPAT.REMOVE_MODE] = function() end,
}

for name, handler in pairs(handlers) do RegisterNetEvent(name, handler) end
