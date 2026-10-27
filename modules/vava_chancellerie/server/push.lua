--[[
    vava_chancellerie/server/push.lua
    Rôle : prévenir la Chancellerie (signalement, arrivée ou départ d'un joueur, offre ou fin d'une caméra), par une
           requête HTTP vers son adresse locale, avec la clé du lancement. Rien n'attend la réponse ; une Chancellerie
           fermée ne fait que perdre l'évènement (signalé une fois par intervalle).
    Dépendances : config.lua, server/core.lua, server/auth.lua
]]

local tostring = tostring
local GetConvar, PerformHttpRequest, GetGameTimer = GetConvar, PerformHttpRequest, GetGameTimer
local encode = json.encode

local auth = VavaBridge.auth
local cfg = VavaBridge.config
local OK_MIN, OK_MAX = 200, 299

local push = {}
VavaBridge.push = push

local warnedAt = nil

---@param event table  { type, … }
function push.send(event)
    local base = GetConvar(cfg.convars.url, '')
    if base == '' or not auth.enabled() then return end
    PerformHttpRequest(base .. cfg.eventPath, function(status)
        if status >= OK_MIN and status <= OK_MAX then return end
        local now = GetGameTimer()
        if not warnedAt or now - warnedAt >= cfg.pushWarnEveryMs then
            warnedAt = now
            VavaBridge.log.warn('la Chancellerie ne reçoit pas les évènements (réponse %s)', tostring(status))
        end
    end, 'POST', encode(event), { ['Content-Type'] = 'application/json', [auth.HEADER] = auth.token() })
end
