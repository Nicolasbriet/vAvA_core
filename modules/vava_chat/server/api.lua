--[[
    vava_chat/server/api.lua
    Rôle : export serveur pour les autres modules : un message du royaume dans l'onglet Général d'un joueur, ou de
           tous les joueurs en jeu (annonce : -1, comme la ressource « chat » de FiveM, mais jamais aux joueurs en
           connexion ou en sélection). Forme du message : un texte, { author?, text, color? } ou celle de
           chat:addMessage ({ args, color? }). Les messages d'un joueur passent par le RPC et ses hooks.
           TriggerClientEvent('chat:addMessage', joueur, …) marche toujours.
    Dépendances : shared/, config.lua, server/core.lua, server/sessions.lua
]]

local type, tostring, pairs, mathType, concat = type, tostring, pairs, math.type, table.concat
local TriggerClientEvent, GetPlayerName = TriggerClientEvent, GetPlayerName

local text = VavaChat.text
local sessions = VavaChat.sessions
local cfg = VavaChat.config
local ADD_MESSAGE = VavaChat.COMPAT.ADD_MESSAGE
local EVERYONE = -1
local AUTHOR_MAX = 32
local ARGS_MAX = 8
local COLOR_MAX = 255

---@param color any
---@return integer[]|nil
local function cleanColor(color)
    if type(color) ~= 'table' then return nil end
    for i = 1, 3 do
        local value = color[i]
        if mathType(value) ~= 'integer' or value < 0 or value > COLOR_MAX then return nil end
    end
    return { color[1], color[2], color[3] }
end

--- Auteur et texte d'un message, quelle que soit sa forme.
---@param message any
---@return string|nil author
---@return string|nil body
local function read(message)
    if type(message) == 'string' then return nil, message end
    if type(message) ~= 'table' then return nil, nil end
    if type(message.args) ~= 'table' then return message.author, message.text end
    local parts = {}
    for i = 1, ARGS_MAX do
        local value = message.args[i]
        if type(value) ~= 'string' and type(value) ~= 'number' then break end
        parts[i] = tostring(value)
    end
    if #parts < 2 then return nil, parts[1] end
    return parts[1], concat(parts, ' ', 2)
end

--- Message du royaume : `target` = numéro d'un joueur connecté, ou -1 pour tous les joueurs en jeu.
---@return boolean ok
---@return string|nil err
exports('addMessage', function(target, message)
    if not VavaChat.ready then return false, 'not_ready' end
    if mathType(target) ~= 'integer' or (target ~= EVERYONE and (target < 1 or not GetPlayerName(target))) then
        return false, 'invalid_target'
    end
    local author, body = read(message)
    body = text.clean(body, true)
    if not body or body == '' then return false, 'invalid_args' end
    author = text.clean(author)
    local args = { text.truncate(body, cfg.systemMaxLength) }
    if author and author ~= '' then args = { text.truncate(author, AUTHOR_MAX), args[1] } end
    local payload = { args = args, color = cleanColor(type(message) == 'table' and message.color or nil) }
    if target ~= EVERYONE then
        TriggerClientEvent(ADD_MESSAGE, target, payload)
        return true
    end
    for src in pairs(sessions.all()) do TriggerClientEvent(ADD_MESSAGE, src, payload) end
    return true
end)
