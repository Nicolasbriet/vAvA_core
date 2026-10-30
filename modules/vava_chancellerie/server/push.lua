--[[
    vava_chancellerie/server/push.lua
    Rôle : prévenir la Chancellerie (signalement, arrivée ou départ d'un joueur, offre ou fin d'une caméra, pont prêt),
           par une requête HTTP vers son adresse locale, avec la clé du lancement. Rien n'attend la réponse ; une
           Chancellerie fermée ne fait que perdre l'évènement (signalé une fois par intervalle). Une demande avec
           réponse (liaison d'un compte du panneau) rend le JSON de la Chancellerie.
    Dépendances : config.lua, server/core.lua, server/auth.lua
]]

local tostring, type, pcall = tostring, type, pcall
local PerformHttpRequest, GetGameTimer = PerformHttpRequest, GetGameTimer
local encode, decode = json.encode, json.decode

local auth = VavaBridge.auth
local cfg = VavaBridge.config
local OK_MIN, OK_MAX = 200, 299

local push = {}
VavaBridge.push = push

local warnedAt = nil

--- Évènement avec réponse : `callback(answer)` reçoit le JSON renvoyé par la Chancellerie, ou nil (fermée, erreur).
---@param event table  { type, … }
---@param callback fun(answer: table|nil)
function push.request(event, callback)
    local base = auth.panelUrl()
    if not base or not auth.enabled() then
        callback(nil)
        return
    end
    PerformHttpRequest(base .. cfg.eventPath, function(status, body)
        if status < OK_MIN or status > OK_MAX or type(body) ~= 'string' then
            callback(nil)
            return
        end
        local decoded, answer = pcall(decode, body)
        callback(decoded and type(answer) == 'table' and answer or nil)
    end, 'POST', encode(event), { ['Content-Type'] = 'application/json', [auth.HEADER] = auth.token() })
end

---@param event table  { type, … }
function push.send(event)
    local base = auth.panelUrl()
    if not base or not auth.enabled() then return end
    PerformHttpRequest(base .. cfg.eventPath, function(status)
        if status >= OK_MIN and status <= OK_MAX then return end
        local now = GetGameTimer()
        if not warnedAt or now - warnedAt >= cfg.pushWarnEveryMs then
            warnedAt = now
            VavaBridge.log.warn('la Chancellerie ne reçoit pas les évènements (réponse %s)', tostring(status))
        end
    end, 'POST', encode(event), { ['Content-Type'] = 'application/json', [auth.HEADER] = auth.token() })
end
