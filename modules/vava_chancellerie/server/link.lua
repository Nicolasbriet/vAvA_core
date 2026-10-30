--[[
    vava_chancellerie/server/link.lua
    Rôle : relier un compte du panneau à son joueur. Le panneau affiche un code ; le joueur le tape en jeu (console F8 :
           « chancellerie 482913 »). Le pont envoie à la Chancellerie le code, la license et l'identifiant fivem du
           joueur, et son numéro de compte vAvA : elle les attache au compte du panneau qui a demandé ce code, puis
           applique son rang du Conseil en jeu. Essais limités par joueur ; le joueur est prévenu du résultat. Une
           liaison confirmée fait entrer le compte de jeu parmi ceux que le pont a vus reliés (server/links.lua).
    Dépendances : config.lua, server/core.lua, server/push.lua, server/links.lua
]]

local tostring, tonumber, ipairs = tostring, tonumber, ipairs
local RegisterCommand, GetPlayerIdentifierByType, GetPlayerName, GetGameTimer, TriggerClientEvent =
    RegisterCommand, GetPlayerIdentifierByType, GetPlayerName, GetGameTimer, TriggerClientEvent

local cfg = VavaBridge.config.link
local push = VavaBridge.push
local links = VavaBridge.links
local core = VavaBridge.core
local CODE_PATTERN = '^%d%d%d%d%d%d$'
local MINUTE_MS = 60000

local link = {}
VavaBridge.link = link

---@type table<integer, integer[]>  joueur → instants de ses derniers essais
local attempts = {}

local function notify(src, text, kind)
    TriggerClientEvent(VavaBridge.ADMIN_NOTIFY, src, { text = text, kind = kind, title = cfg.title })
end

--- Encore un essai permis dans la minute ?
---@param src integer
---@return boolean
local function allowed(src)
    local now = GetGameTimer()
    local kept = {}
    for _, at in ipairs(attempts[src] or {}) do
        if now - at < MINUTE_MS then kept[#kept + 1] = at end
    end
    if #kept >= cfg.attemptsPerMinute then
        attempts[src] = kept
        return false
    end
    kept[#kept + 1] = now
    attempts[src] = kept
    return true
end

---@param src integer
---@param args string[]
local function onCommand(src, args)
    if src == 0 then return end
    local code = tostring(args[1] or ''):gsub('%s', '')
    if not code:find(CODE_PATTERN) then
        notify(src, cfg.messages.usage:format(cfg.command), 'warning')
        return
    end
    if not allowed(src) then
        notify(src, cfg.messages.tooMany, 'error')
        return
    end
    local session = core.players.get(src)
    local license = GetPlayerIdentifierByType(src, 'license')
    if not session or not session.accountId or not license then
        notify(src, cfg.messages.notReady, 'warning')
        return
    end
    local accountId = session.accountId
    -- le panneau applique le rang pendant qu'il répond : la liaison en cours est attendue par /staff/sync
    links.begin(accountId)
    push.request({
        type = 'link', code = code, license = license, fivem = GetPlayerIdentifierByType(src, 'fivem'),
        discord = GetPlayerIdentifierByType(src, 'discord'),
        accountId = accountId, player = GetPlayerName(src),
    }, function(answer)
        -- seule la réponse à la demande du pont lui-même fait entrer ce compte parmi ceux vus reliés en jeu
        links.finish(accountId, answer ~= nil and answer.ok == true, answer and answer.account)
        if not answer then
            notify(src, cfg.messages.unreachable, 'error')
        elseif answer.ok then
            notify(src, cfg.messages.linked:format(tostring(answer.account)), 'success')
        else
            notify(src, cfg.messages[answer.error] or cfg.messages.refused, 'error')
        end
    end)
end

--- Déclare la commande. Appelé pendant le setup du module.
function link.start()
    RegisterCommand(cfg.command, function(source, args) onCommand(tonumber(source) or 0, args or {}) end, false)
end

AddEventHandler('playerDropped', function()
    attempts[source] = nil
end)
