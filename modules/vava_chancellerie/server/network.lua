--[[
    vava_chancellerie/server/network.lua
    Rôle : page Réseau de la Chancellerie, en lecture seule : le compteur des envois du core sur la dernière minute
           (core.net.stats, core ≥ 0.12.0) — vue d'ensemble, un module, la liste des joueurs connectés (numéro, nom du
           personnage, volume reçu ; 128 au plus, les plus chargés d'abord) ou ce que reçoit un joueur —, ce que montre
           `/vava_reseau` en jeu. Droit `net.permission` (tools) vérifié auprès du Registre (webCan), lectures d'un même
           compte du panneau espacées de `net.minIntervalMs`, consultation inscrite au journal du Registre (webLog) au
           nom de « Chancellerie : <compte> » : à l'ouverture de la page (dite par la page, prise au plus une fois par
           `net.openLogMinMs`), à chaque autre joueur lu (numéro et compte de jeu), et au plus tard toutes les
           `net.logEveryMs` (shared/rules.lua, netJournal), jamais à chaque relecture ; lire la liste des joueurs
           n'inscrit rien de plus, seul le détail d'un joueur est inscrit. Chaque joueur connecté est suivi d'office par
           le core (0.12.0) : son détail par évènement et le nom de son personnage sont toujours lisibles, sans suivi à
           lancer ; rien ne change côté jeu.
    Dépendances : shared/constants.lua, shared/rules.lua, config.lua, server/core.lua, server/routes.lua
]]

local type, tostring, tonumber, pcall = type, tostring, tonumber, pcall
local max, mathType = math.max, math.type
local GetGameTimer, DoesPlayerExist = GetGameTimer, DoesPlayerExist

local call = VavaBridge.call
local rules = VavaBridge.rules
local requests = VavaBridge.routes.requests
local cfg = VavaBridge.config.net
local messages = VavaBridge.config.messages
local ADMIN = VavaBridge.ADMIN
local LIMIT = math.min(50, math.max(1, cfg.lines))

-- Compte du panneau (nom) → { readAt, pageAt?, player?, playerAt? } : dernière lecture et lignes inscrites au journal.
-- Une entrée par compte qui a lu la page : bornée par le nombre de comptes du panneau.
---@type table<string, table>
local accounts = {}

local function failure(code)
    return { ok = false, error = tostring(code) }
end

---@param actor any
---@return string|nil
local function actorName(actor)
    return type(actor) == 'table' and type(actor.label) == 'string' and actor.label ~= '' and actor.label or nil
end

--- Une ligne au journal du Registre ; vrai seulement si le Registre l'a acceptée (sinon la lecture suivante réessaie).
---@return boolean
local function journal(actor, label, details)
    local called, ok = call(ADMIN, 'webLog', actor, label, details)
    return called and ok == true
end

---@param value any
---@return integer
local function count(value)
    local n = tonumber(value)
    return n and n >= 0 and n or 0
end

--- Copie des évènements rendus par le core : champs connus seulement, liste pure ; et le plus gros message de la liste.
---@param events any
---@return table[] list
---@return integer largest
local function copyEvents(events)
    local list, largest = {}, 0
    if type(events) ~= 'table' then return list, largest end
    for i = 1, #events do
        local event = events[i]
        if type(event) == 'table' then
            local copy = {
                resource = tostring(event.resource), label = tostring(event.label), messages = count(event.messages),
                bytes = count(event.bytes), latent = count(event.latent), largest = count(event.largest),
            }
            list[#list + 1] = copy
            largest = max(largest, copy.largest)
        end
    end
    return list, largest
end

--- Ligne du journal pour un joueur lu : son numéro de connexion (réattribué après son départ) et, si le core le
--- connaît, son compte de jeu (core.players.get, sans personnage chargé).
---@param target integer
---@return table
local function playerDetails(target)
    local details = { joueur = target }
    local core = VavaBridge.core
    local players = core and core.players
    if not players then return details end
    local called, session = pcall(players.get, target)
    if called and type(session) == 'table' and mathType(session.accountId) == 'integer' then
        details.compte = session.accountId
    end
    return details
end

-- args : { portée ('all' | 'players' | 'resource' | 'player'), valeur ('' | nom de ressource | numéro de joueur),
-- ouverture }
requests.netStats = function(actor, args)
    local name = actorName(actor)
    if not name then return failure('forbidden') end
    local query, err = rules.netQuery(args[1], args[2], args[3])
    if not query then return failure(err) end
    -- délai avant le droit : une page relue en boucle ne coûte pas un appel au Registre par demande
    local now = GetGameTimer()
    local state = accounts[name]
    if state and now - state.readAt < cfg.minIntervalMs then return failure('rate_limited') end
    if not state then
        state = {}
        accounts[name] = state
    end
    state.readAt = now
    local called, allowed = call(ADMIN, 'webCan', actor, cfg.permission)
    if not called or allowed ~= true then return failure('forbidden') end
    local core = VavaBridge.core
    local net = core and core.net
    if type(net) ~= 'table' or not net.stats then return failure('net_unavailable') end
    if query.target and not DoesPlayerExist(query.target) then return failure('unknown_player') end
    local listing = query.scope == 'players' or nil
    local read, stats, code = pcall(net.stats,
        { limit = LIMIT, resource = query.resource, target = query.target, players = listing })
    -- liste des joueurs refusée : core antérieur à 0.12.0
    if read and not stats and listing and code == 'invalid_options' then return failure('net_unavailable') end
    if not read or type(stats) ~= 'table' then return failure(read and code or 'net_unavailable') end

    local page, player = rules.netJournal(state, query, now, cfg.logEveryMs, cfg.openLogMinMs)
    if page and journal(actor, messages.logNet, query.resource and { ressource = query.resource } or {}) then
        state.pageAt = now
    end
    if player and journal(actor, messages.logNetPlayer, playerDetails(query.target)) then
        state.player, state.playerAt = query.target, now
    end

    local total = type(stats.total) == 'table' and stats.total or {}
    local events, largest = copyEvents(stats.events)
    local result = {
        scope = query.scope,
        resource = query.resource,
        target = query.target,
        mode = stats.mode == 'exact' and 'exact' or 'estimate',
        windowMs = count(stats.windowMs),
        total = { messages = count(total.messages), bytes = count(total.bytes), latent = count(total.latent) },
        largest = largest,
        events = events,
    }
    -- chaque joueur est suivi d'office (core 0.12.0) : son nom vient du core, sans condition de suivi
    if query.target then result.name = rules.netName(stats.name) end
    if listing then
        result.players = rules.netPlayers(stats.players)
        result.playerCount = count(stats.playerCount)
    end
    return { ok = true, result = result }
end
