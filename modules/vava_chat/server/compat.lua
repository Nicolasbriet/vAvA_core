--[[
    vava_chat/server/compat.lua
    Rôle : ce que faisait la ressource « chat » de FiveM côté serveur, sans ses diffusions à tout le serveur :
      - commande inconnue (__cfx_internal:commandFallback) : un avis au seul joueur, à débit limité (la ressource
        d'origine la diffusait à tous comme un message) ;
      - commandes du serveur permises au joueur (ACE), pour les suggestions, envoyées une fois à l'apparition.
    Dépendances : shared/, config.lua, server/core.lua
]]

local type, ipairs, min, match = type, ipairs, math.min, string.match
local RegisterNetEvent, CancelEvent, TriggerClientEvent, GetRegisteredCommands, IsPlayerAceAllowed, GetGameTimer =
    RegisterNetEvent, CancelEvent, TriggerClientEvent, GetRegisteredCommands, IsPlayerAceAllowed, GetGameTimer

local text = VavaChat.text
local cfg = VavaChat.config
local limit = cfg.rateLimits.fallback
local COMPAT = VavaChat.COMPAT
local NOTICE = VavaChat.EVENTS.NOTICE
local MS = 1000
-- signes du nom de commande repris dans l'avis
local COMMAND_SHOWN = 32
local COMMAND_MAX_BYTES = 512

local compat = {}
VavaChat.compat = compat

-- seau de jetons par joueur pour les avis « commande inconnue »
local buckets = {}

---@param src integer
---@return boolean
local function take(src)
    local now = GetGameTimer()
    local bucket = buckets[src]
    if not bucket then
        bucket = { tokens = limit.capacity, at = now }
        buckets[src] = bucket
    end
    bucket.tokens = min(limit.capacity, bucket.tokens + (now - bucket.at) * limit.refillPerSecond / MS)
    bucket.at = now
    if bucket.tokens < 1 then return false end
    bucket.tokens = bucket.tokens - 1
    return true
end

---@param name string
---@return boolean
local function hidden(name)
    for _, pattern in ipairs(cfg.commandList.hidden) do
        if match(name, pattern) then return true end
    end
    return false
end

--- Noms des commandes du serveur que le joueur a le droit de lancer (suggestions du chat).
---@param src integer
---@return string[]
function compat.commands(src)
    local list = {}
    local registered = GetRegisteredCommands()
    if type(registered) ~= 'table' then return list end
    for _, command in ipairs(registered) do
        if #list >= cfg.commandList.max then break end
        local name = type(command) == 'table' and command.name
        if type(name) == 'string' and not hidden(name) and IsPlayerAceAllowed(src, 'command.' .. name) then
            list[#list + 1] = name
        end
    end
    return list
end

---@param src integer
function compat.forget(src)
    buckets[src] = nil
end

RegisterNetEvent(COMPAT.COMMAND_FALLBACK, function(command)
    local src = source
    CancelEvent()
    if type(command) ~= 'string' or #command > COMMAND_MAX_BYTES or not take(src) then return end
    local name = text.clean(match(command, '^([^ ]+)') or '')
    if not name or name == '' then return end
    TriggerClientEvent(NOTICE, src, 'unknown_command', text.truncate(name, COMMAND_SHOWN))
end)
