--[[
    vava_chancellerie/server/http.lua
    Rôle : écoute HTTP du pont, sur l'adresse du serveur de jeu (http://127.0.0.1:<port>/vava_chancellerie/…).
           Chaque requête est d'abord authentifiée (machine locale et clé), son corps borné et lu en JSON, puis
           traitée dans son propre thread (les demandes peuvent attendre la base) ; une erreur renvoie une réponse,
           jamais un silence.
    Dépendances : config.lua, server/core.lua, server/auth.lua, server/routes.lua
]]

local type, pcall, tostring = type, pcall, tostring
local CreateThread, SetHttpHandler = CreateThread, SetHttpHandler
local encode, decode = json.encode, json.decode

local auth = VavaBridge.auth
local routes = VavaBridge.routes
local cfg = VavaBridge.config

local http = {}
VavaBridge.http = http

local function reply(response, status, body)
    response.writeHead(status, { ['Content-Type'] = 'application/json; charset=utf-8', ['Cache-Control'] = 'no-store' })
    response.send(encode(body))
end

---@param handler function
---@param body table
---@param response table
local function run(handler, body, response)
    CreateThread(function()
        local ok, result = pcall(handler, body)
        if not ok then
            VavaBridge.log.error('requête du pont en erreur : %s', tostring(result))
            reply(response, 500, { ok = false, error = 'server_error' })
            return
        end
        reply(response, 200, result)
    end)
end

--- Ouvre l'écoute. Appelé pendant le setup du module.
function http.start()
    SetHttpHandler(function(request, response)
        if not VavaBridge.ready or not auth.check(request) then
            reply(response, 403, { ok = false, error = 'forbidden' })
            return
        end
        local handler = routes.find(request.method, request.path)
        if not handler then
            reply(response, 404, { ok = false, error = 'not_found' })
            return
        end
        if request.method ~= 'POST' then
            run(handler, {}, response)
            return
        end
        request.setDataHandler(function(raw)
            if type(raw) ~= 'string' or #raw > cfg.bodyMax then
                reply(response, 413, { ok = false, error = 'too_large' })
                return
            end
            local decoded, body = pcall(decode, raw)
            if not decoded or type(body) ~= 'table' then
                reply(response, 400, { ok = false, error = 'bad_request' })
                return
            end
            run(handler, body, response)
        end)
    end)
end
