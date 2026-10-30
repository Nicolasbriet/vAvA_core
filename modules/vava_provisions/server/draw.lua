--[[
    vava_provisions/server/draw.lua
    Rôle : RPC vava_provisions:draw — le joueur désigne un point d'eau, le serveur décide tout. Dans l'ordre : personnage
           actif, une demande à la fois par joueur (`busy`, pris sans céder la main, rendu en fin de traitement même en
           erreur), délai entre deux actions, à terre (vava_health), point connu, distance réelle lue par le serveur
           (distance d'usage + tolérance, 3D), outres vides réellement possédées, soif (vava_needs, si la sorte permet
           de boire), réserve, choix de l'action (rules.decide), hook `vava_provisions:drawing` annulable, puis :
           personnage et distance relus (le hook a pu céder la main), remplir (puisages RÉSERVÉS avant l'échange
           atomique de l'inventaire, rendus s'il échoue ; besace pleine ou trop lourde : le joueur qui a soif boit sur
           place) ou boire quelques gorgées (vava_needs). Payloads des hooks reconstruits à chaque fois. Le client ne
           dit ni ce qu'il veut faire, ni ce qu'il porte, ni sa soif.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/points.lua
]]

local type, tostring, pcall = type, tostring, pcall
local pack, unpack = table.pack, table.unpack
local sqrt = math.sqrt

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local points = VavaProvisions.points
local cfg = VavaProvisions.config
local ACTIONS, HOOKS = VavaProvisions.ACTIONS, VavaProvisions.HOOKS
local MAX_REASON = VavaProvisions.MAX_NOTIFICATION
local fill, drink = cfg.fill, cfg.drink

local draw = {}
VavaProvisions.draw = draw

-- joueur → vrai pendant le traitement d'une demande
local busy = {}
-- joueur → horloge (GetGameTimer) avant laquelle une nouvelle action est refusée
local nextAt = {}

-- codes de l'inventaire rendus tels quels au joueur ; tout autre refus de l'échange : `unavailable`
local INVENTORY_CODES = { no_space = true, too_heavy = true }

--- Le joueur est-il à portée du point (position lue par le serveur, tolérance comprise, distance 3D) ?
---@param source integer
---@param point table
---@return boolean
local function near(source, point)
    local x, y, z = bridge.Position(source)
    if not x then return false end
    local dx, dy, dz = x - point.x, y - point.y, z - point.z
    return sqrt(dx * dx + dy * dy + dz * dz) <= cfg.interact.distance + cfg.interact.serverTolerance
end

--- Raison d'un refus du hook `drawing`, montrée au joueur (texte coupé à 200 octets) ; erreur d'un hook : indisponible.
---@param reason any
---@return boolean false
---@return string code
---@return string|nil reason
local function refused(reason)
    if reason == 'hook_error' then return false, 'unavailable' end
    local text = rules.cutText(reason, MAX_REASON)
    if not text then return false, 'unavailable' end
    return false, 'refused', text
end

--- Payload d'un hook, construit par le serveur à chaque fois (jamais la table passée à un autre hook, qu'un abonné
--- aurait pu modifier).
---@param source integer
---@param characterId integer
---@param point table
---@param action string
---@param count integer
---@param reserve integer|nil  après le geste (sortes à réserve seulement)
---@return table
local function payloadOf(source, characterId, point, action, count, reserve)
    return {
        source = source, characterId = characterId, point = point.id, kind = point.kind, action = action, count = count,
        reserve = reserve,
    }
end

--- Après un hook (qui a pu céder la main) : même personnage, toujours à portée. Rend nil, ou le code du refus.
---@param source integer
---@param characterId integer
---@param point table
---@return string|nil code
local function recheck(source, characterId, point)
    if bridge.ActiveCharacterId(source) ~= characterId then return 'unavailable' end
    if not near(source, point) then return 'too_far' end
    return nil
end

--- Quelques gorgées au point d'eau (la réserve n'est pas touchée), délai posé, hook `drawn`.
---@return boolean ok
local function sip(source, characterId, point, kind)
    if not bridge.AddThirst(source, drink.thirst) then return false end
    nextAt[source] = bridge.Timer() + cfg.cooldownMs
    local reserve = nil
    if kind.reserve.capacity > 0 then reserve = rules.available(points.level(point, bridge.Now())) end
    bridge.RunAfter(HOOKS.DRAWN, payloadOf(source, characterId, point, ACTIONS.DRINK, 0, reserve))
    return true
end

--- Remplissage refusé par la besace (pleine, trop lourde) : le joueur qui a soif boit sur place plutôt que de repartir
--- sans rien, si la sorte le permet et qu'un hook `drawing` l'accepte. Sinon, le code de l'inventaire.
---@return boolean ok
---@return any resultOrCode
local function sipInstead(source, characterId, point, kind, blocked)
    if not kind.drink then return false, blocked end
    local thirst = bridge.Thirst(source)
    if type(thirst) ~= 'number' or thirst >= drink.fullAt then return false, blocked end
    local allowed = bridge.RunBefore(HOOKS.DRAWING, payloadOf(source, characterId, point, ACTIONS.DRINK, 0))
    if not allowed or recheck(source, characterId, point) then return false, blocked end
    if not sip(source, characterId, point, kind) then return false, blocked end
    return true, { action = ACTIONS.DRINK, dry = false, blocked = blocked }
end

---@param source integer
---@param characterId integer
---@param pointId string
local function process(source, characterId, pointId)
    local timer = bridge.Timer()
    local readyAt = nextAt[source]
    if readyAt and timer < readyAt then return false, 'wait' end
    if bridge.IsDowned(source) then return false, 'downed' end
    local point = points.get(pointId)
    if not point then return false, 'unknown_point' end
    if not near(source, point) then return false, 'too_far' end
    local empties = bridge.Count(source, fill.from)
    if empties == nil then return false, 'unavailable' end
    local kind = cfg.kinds[point.kind]
    local thirst = nil
    if kind.drink then thirst = bridge.Thirst(source) end

    local now = bridge.Now()
    local level = points.level(point, now)
    local decision, code = rules.decide({
        empties = empties, maxPerDraw = fill.maxPerDraw, available = rules.available(level),
        drinkable = kind.drink, thirst = thirst, fullAt = drink.fullAt,
    })
    if not decision then
        if code == 'dry' then return false, 'dry', rules.waitSeconds(level, kind.reserve) end
        return false, code
    end

    local allowed, reason = bridge.RunBefore(HOOKS.DRAWING, payloadOf(source, characterId, point, decision.action, decision.count or 0))
    if not allowed then return refused(reason) end
    -- un hook a pu céder la main : personnage et distance relus (rien n'est encore réservé)
    local moved = recheck(source, characterId, point)
    if moved then return false, moved end

    if decision.action == ACTIONS.FILL then
        -- niveau relu, puisages réservés AVANT l'échange (rien ne cède la main entre les deux) ; deux joueurs sur la
        -- dernière unité : le premier réserve, le second lit 0
        now = bridge.Now()
        level = points.level(point, now)
        local count = decision.count
        local available = rules.available(level)
        if available < count then count = available end
        if count < 1 then return false, 'dry', rules.waitSeconds(level, kind.reserve) end
        points.take(point, level, count, now)
        local ok, exchangeCode = bridge.Exchange(source, { { item = fill.from, quantity = count } }, { { item = fill.to, quantity = count } })
        if not ok then
            points.giveBack(point, count)
            if INVENTORY_CODES[exchangeCode] then return sipInstead(source, characterId, point, kind, exchangeCode) end
            return false, 'unavailable'
        end
        nextAt[source] = bridge.Timer() + cfg.cooldownMs
        local reserve = nil
        if kind.reserve.capacity > 0 then reserve = rules.available(level - count) end
        bridge.RunAfter(HOOKS.DRAWN, payloadOf(source, characterId, point, ACTIONS.FILL, count, reserve))
        return true, { action = ACTIONS.FILL, count = count }
    end

    if not sip(source, characterId, point, kind) then return false, 'unavailable' end
    return true, { action = ACTIONS.DRINK, dry = decision.dry == true }
end

--- RPC vava_provisions:draw (schéma : identifiant du point, débit limité par le core).
---@param source integer
---@param pointId string
---@return boolean ok
---@return any resultOrCode
---@return any extra  secondes d'attente (dry), raison (refused)
function draw.handle(source, pointId)
    local characterId = bridge.ActiveCharacterId(source)
    if not characterId then return false, 'no_character' end
    if busy[source] then return false, 'busy' end
    busy[source] = true
    local results = pack(pcall(process, source, characterId, pointId))
    busy[source] = nil
    if not results[1] then
        VavaProvisions.log.error('puisage du joueur %d en erreur : %s', source, tostring(results[2]))
        return false, 'unavailable'
    end
    return unpack(results, 2, results.n)
end

--- Joueur déchargé ou parti : son délai et son traitement en cours sont oubliés.
---@param source integer
function draw.forget(source)
    busy[source], nextAt[source] = nil, nil
end
