--[[
    vava_chancellerie/server/whitelist.lua
    Rôle : liste blanche Discord de la Chancellerie. À la connexion d'un joueur (hook core:player:connecting, avant
           toute création de données), le pont demande à la Chancellerie s'il peut entrer (rôle sur le serveur Discord,
           ou compte du panneau relié à ce joueur) ; elle répond avec le message à lui montrer. Sans réponse à temps :
           refusé si la liste blanche était active à la dernière réponse, accepté sinon. Serveur lancé par la
           Chancellerie dont la clé n'est pas encore arrivée : refusé (« le registre des portes s'ouvre »), jamais
           accepté faute de réponse. Serveur lancé sans la Chancellerie : rien n'est vérifié.
    Dépendances : config.lua, server/core.lua, server/auth.lua, server/push.lua
]]

local GetPlayerIdentifierByType, SetTimeout = GetPlayerIdentifierByType, SetTimeout

local cfg = VavaBridge.config.whitelist
local auth = VavaBridge.auth
local push = VavaBridge.push
local core = VavaBridge.core

local whitelist = {}
VavaBridge.whitelist = whitelist

-- dernier état connu de la liste blanche (réponse de la Chancellerie) : ce qui vaut quand elle ne répond pas
local enabled = false

---@param value any
function whitelist.setEnabled(value)
    enabled = value == true
end

---@param payload table  { source, license, name, accountId }
---@return boolean|nil allowed
---@return string|nil reason
local function check(payload)
    -- lancé par la Chancellerie mais clé pas encore là : la liste ne peut pas être lue, personne n'entre à l'aveugle
    if not auth.enabled() then return false, cfg.messages.opening end
    local src = payload.source
    local p = promise.new()
    local settled = false
    local function settle(answer)
        if settled then return end
        settled = true
        p:resolve(answer)
    end
    push.request({
        type = 'whitelist', license = payload.license, name = payload.name,
        discord = src and GetPlayerIdentifierByType(src, 'discord') or nil,
    }, settle)
    SetTimeout(cfg.timeoutMs, function() settle(false) end)
    local answer = Citizen.Await(p)
    if not answer then
        if enabled then return false, cfg.messages.unreachable end
        return true
    end
    if answer.ok == false then return false, cfg.messages.unreachable end
    if answer.whitelist ~= nil then enabled = answer.whitelist == true end
    if answer.allowed then return true end
    return false, type(answer.reason) == 'string' and answer.reason or cfg.messages.refused
end

--- Branche la vérification à la connexion. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function whitelist.start()
    -- lancé par la Chancellerie (adresse figée par auth.capture, appelé avant) : branchée même si la clé n'est pas
    -- encore arrivée ; d'ici là, la connexion est refusée
    if not auth.expected() then return true end
    local id, err = core.hooks.before('core:player:connecting', check)
    if not id then return false, err end
    return true
end
