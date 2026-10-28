--[[
    vava_chat/client/suggestions.lua
    Rôle : suggestions de commandes sous la saisie :
      - celles que les ressources déclarent (chat:addSuggestion, avec aide et paramètres), gardées ici pour être
        renvoyées si la page se recharge ;
      - les commandes permises au joueur : celles du client (relues à l'ouverture du chat, seulement si une
        ressource a démarré ou s'est arrêtée depuis) et celles du serveur (reçues avec le profil) ;
      - les suggestions décrites par le registre des commandes du core (Codex), reçues avec le profil : elles
        l'emportent sur une déclaration du même nom, et peuvent nommer une sous-commande (« metiers niveau »).
    Dépendances : shared/text.lua, config.lua, client/nui.lua
]]

local type, pairs, ipairs, match, sub = type, pairs, ipairs, string.match, string.sub
local GetRegisteredCommands, IsAceAllowed = GetRegisteredCommands, IsAceAllowed

local text = VavaChat.text
local nui = VavaChat.nui
local cfg = VavaChat.config
local LIST = cfg.commandList
-- bornes des suggestions venues d'autres ressources
local NAME_MAX = 64
local HELP_MAX = 160
local PARAMS_MAX = 8
local PARAM_NAME_MAX = 32
local SUGGESTIONS_MAX = 400

local suggestions = {}
VavaChat.suggestions = suggestions

---@type table<string, table>
local declared = {}
local declaredCount = 0
---@type table<string, table>  suggestions du registre des commandes (profil), par nom
local described = {}
local serverCommands = {}
local dirty = true

--- Nom de commande sans « / », ou nil. `words` : des espaces simples sont admis à l'intérieur (sous-commande).
---@param name any
---@param words? boolean
---@return string|nil
local function commandName(name, words)
    if type(name) ~= 'string' then return nil end
    if sub(name, 1, 1) == '/' then name = sub(name, 2) end
    name = text.clean(name)
    if not name or name == '' or #name > NAME_MAX then return nil end
    if words then
        if match(name, '^ ') or match(name, ' $') or match(name, '  ') then return nil end
    elseif match(name, ' ') then
        return nil
    end
    return name
end

---@param value any
---@param max integer
---@return string
local function label(value, max)
    local cleaned = text.clean(value)
    return cleaned and text.truncate(cleaned, max) or ''
end

---@param params any
---@return table[]
local function cleanParams(params)
    local list = {}
    if type(params) ~= 'table' then return list end
    for i = 1, PARAMS_MAX do
        local param = params[i]
        if type(param) ~= 'table' then break end
        list[i] = { name = label(param.name, PARAM_NAME_MAX), help = label(param.help, HELP_MAX) }
    end
    return list
end

---@param name string
---@return boolean
local function hidden(name)
    for _, pattern in ipairs(LIST.hidden) do
        if match(name, pattern) then return true end
    end
    return false
end

--- Suggestion d'une ressource (chat:addSuggestion).
---@param name any
---@param help any
---@param params any
function suggestions.add(name, help, params)
    name = commandName(name)
    if not name then return end
    if not declared[name] then
        if declaredCount >= SUGGESTIONS_MAX then return end
        declaredCount = declaredCount + 1
    end
    local entry = { name = name, help = label(help, HELP_MAX), params = cleanParams(params) }
    declared[name] = entry
    -- avant que la page soit prête, la liste entière lui partira d'un coup
    if nui.isReady() then nui.send('suggestions', { list = { entry } }) end
end

---@param name any
function suggestions.remove(name)
    name = commandName(name)
    if not name or not declared[name] then return end
    declared[name] = nil
    declaredCount = declaredCount - 1
    if nui.isReady() then nui.send('suggestion:remove', { name = name }) end
end

--- Suggestions décrites par le registre des commandes (profil) : nettoyées aux mêmes bornes, elles remplacent les
--- précédentes du même genre et passent à la page après les déclarations, pour l'emporter à nom égal.
---@param list any
function suggestions.setDescribed(list)
    described = {}
    if type(list) ~= 'table' then return end
    local count = 0
    for _, raw in ipairs(list) do
        if count >= SUGGESTIONS_MAX then break end
        local name = type(raw) == 'table' and commandName(raw.name, true)
        if name then
            count = count + 1
            described[name] = { name = name, help = label(raw.help, HELP_MAX), params = cleanParams(raw.params) }
        end
    end
    if nui.isReady() then
        local out = {}
        for _, entry in pairs(described) do out[#out + 1] = entry end
        nui.send('suggestions', { list = out })
    end
end

--- Commandes du serveur permises au joueur (profil).
---@param list any
function suggestions.setServer(list)
    serverCommands = {}
    if type(list) ~= 'table' then return end
    for i = 1, LIST.max do
        local name = commandName(list[i])
        if not name then break end
        serverCommands[#serverCommands + 1] = name
    end
    dirty = true
end

--- Une ressource a démarré ou s'est arrêtée : la liste des commandes sera relue à la prochaine ouverture.
function suggestions.changed()
    dirty = true
end

--- Avant l'ouverture du chat : liste des commandes renvoyée à la page si elle a pu changer.
function suggestions.refresh()
    if not dirty then return end
    dirty = false
    local names, seen = {}, {}
    local registered = GetRegisteredCommands()
    if type(registered) == 'table' then
        for _, command in ipairs(registered) do
            local name = type(command) == 'table' and command.name
            if type(name) == 'string' and #names < LIST.max and not seen[name] and not hidden(name)
                and IsAceAllowed('command.' .. name) then
                seen[name] = true
                names[#names + 1] = name
            end
        end
    end
    for _, name in ipairs(serverCommands) do
        if #names >= LIST.max then break end
        if not seen[name] then
            seen[name] = true
            names[#names + 1] = name
        end
    end
    nui.send('commands', { names = names })
end

nui.onReady(function()
    local list = {}
    for _, entry in pairs(declared) do list[#list + 1] = entry end
    -- après les déclarations : à nom égal, la description du registre l'emporte
    for _, entry in pairs(described) do list[#list + 1] = entry end
    nui.send('suggestions', { list = list })
    dirty = true
end)
