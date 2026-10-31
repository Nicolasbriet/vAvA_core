--[[
    vava_provisions/server/containers.lua
    Rôle : le contenant qui revient. Abonné au hook vava_inventory:use : en phase before, le palier de l'outre d'eau
           sur le point d'être bue est relevé (la pile peut disparaître avec sa dernière unité ; jamais de refus) ; en
           phase after, une outre d'eau réellement bue (`consumed`, que l'inventaire ne met qu'après avoir retiré une
           unité) rend une outre vide du même palier, sauf quand elle se fend (risque selon le palier : savoir du
           tanneur, T-135) ; sans place dans la besace, elle est abandonnée. Le personnage est lu dans le hook, l'ajout
           se fait dans un thread (jamais d'appel à l'inventaire qui modifie la besace pendant son propre `use`) et
           seulement si le joueur a toujours le même personnage. Avis (`torn`, `lost`) au SEUL buveur.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua
]]

local type, tostring, ipairs, next = type, tostring, ipairs, next
local mathType, random = math.type, math.random
local CreateThread = CreateThread

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local cfg = VavaProvisions.config
local EVENTS, NOTICES = VavaProvisions.EVENTS, VavaProvisions.NOTICES

-- paliers relevés et pas encore bus, par joueur : au-delà, la table du joueur repart de zéro (gorgées refusées par un
-- autre abonné, qui n'arrivent jamais en phase after)
local MAX_PENDING = 8
-- palier relevé « sans palier » (distinct de « rien relevé »)
local NO_TIER = false
-- relevé manqué (inventaire muet, pile introuvable, gorgée sans phase before) : un avertissement en console au plus
-- par minute (relecture sécurité S-3 de T-135)
local WARN_INTERVAL_MS = 60000

local containers = {}
VavaProvisions.containers = containers

-- joueur → { [identifiant de pile] = palier | NO_TIER }, relevé en phase before, repris en phase after.
-- CONDITION (relecture sécurité S-2 de T-135) : rien ne cède la main entre ce relevé et la phase after. L'abonné before
-- est le dernier de la chaîne (priorité 1000) ; l'Outre d'eau n'a pas d'`onUse` (effets seuls) et l'inventaire retire
-- l'unité puis lance la phase after d'un bloc : la pile relevée est bien celle qui vient d'être bue, avec les
-- métadonnées lues. Un futur `onUse` de l'eau, ou un abonné before qui céderait la main après celui-ci, romprait cette
-- condition : il faudrait alors lire les métadonnées dans le payload de `vava_inventory:use` (suite notée au rapport).
local pending = {}
-- horloge (bridge.Timer) du dernier avertissement de relevé manqué, et relevés manqués tus depuis
local warnedAt, silenced = nil, 0

---@param tbl table
---@return integer
local function size(tbl)
    local count = 0
    for _ in next, tbl do count = count + 1 end
    return count
end

--- Relevé manqué : avertissement en console, au plus un par `WARN_INTERVAL_MS` (les suivants comptés et tus).
---@param source integer
---@param instanceId any
local function warnUnread(source, instanceId)
    local now = bridge.Timer()
    if warnedAt and now - warnedAt < WARN_INTERVAL_MS then
        silenced = silenced + 1
        return
    end
    local note = silenced > 0 and (' (%d autres depuis le précédent avis)'):format(silenced) or ''
    warnedAt, silenced = now, 0
    VavaProvisions.log.warn("palier de l'outre d'eau non relevé (joueur %d, pile %s) : risque de fente et outre rendue "
        .. 'sans palier%s', source, tostring(instanceId), note)
end

--- Oublie le relevé d'une pile (relecture sécurité S-1 de T-135 : un relevé ancien ne doit jamais servir).
---@param source integer
---@param instanceId integer
local function dropTier(source, instanceId)
    local known = pending[source]
    if not known then return end
    known[instanceId] = nil
    if next(known) == nil then pending[source] = nil end
end

--- Avant l'utilisation d'un objet de la besace : relève le palier de l'outre d'eau visée. Ne refuse jamais (rien n'est
--- rendu) ; lecture seule de la besace, sans attente. Inventaire muet ou pile introuvable : relevé de cette pile
--- effacé (la phase after avertit et traite l'outre sans palier).
---@param payload { source: integer, instanceId: integer, item: string }
function containers.beforeUse(payload)
    if type(payload) ~= 'table' or not cfg.containers[payload.item] then return end
    local source, instanceId = payload.source, payload.instanceId
    if mathType(source) ~= 'integer' or source <= 0 or mathType(instanceId) ~= 'integer' then return end
    local piles = bridge.Piles(source, payload.item)
    if not piles then return dropTier(source, instanceId) end
    local tier = nil
    for _, pile in ipairs(piles) do
        if type(pile) == 'table' and pile.id == instanceId then
            tier = rules.tierOf(pile.metadata) or NO_TIER
            break
        end
    end
    if tier == nil then return dropTier(source, instanceId) end
    local known = pending[source]
    if not known or size(known) >= MAX_PENDING then
        known = {}
        pending[source] = known
    end
    known[instanceId] = tier
end

--- Palier relevé pour cette pile (et oublié) : palier, NO_TIER (relevé, sans palier) ou nil (rien relevé).
---@param source integer
---@param instanceId any
---@return integer|false|nil
local function takeTier(source, instanceId)
    local known = pending[source]
    if not known or instanceId == nil then return nil end
    local tier = known[instanceId]
    known[instanceId] = nil
    if next(known) == nil then pending[source] = nil end
    return tier
end

--- Après l'utilisation d'un objet de la besace.
---@param payload { source: integer, instanceId: integer, item: string, consumed: boolean }
function containers.onUse(payload)
    if type(payload) ~= 'table' or payload.consumed ~= true then return end
    local container = cfg.containers[payload.item]
    if not container then return end
    local source = payload.source
    if mathType(source) ~= 'integer' or source <= 0 then return end
    local tier = takeTier(source, payload.instanceId)
    if tier == nil then warnUnread(source, payload.instanceId) end
    tier = tier or nil   -- NO_TIER : sans palier
    local characterId = bridge.ActiveCharacterId(source)
    if not characterId then return end
    CreateThread(function()
        if bridge.ActiveCharacterId(source) ~= characterId then return end
        if not rules.keepsContainer(random(), rules.tearChance(container, tier)) then
            bridge.Send(source, EVENTS.NOTICE, NOTICES.TORN)
            return
        end
        local ok, code = bridge.Add(source, container.empty, 1, rules.tierMetadata(tier))
        if not ok then
            VavaProvisions.log.debug("outre vide non rendue au joueur %d (personnage n° %d) : %s", source, characterId, tostring(code))
            bridge.Send(source, EVENTS.NOTICE, NOTICES.LOST)
        end
    end)
end

--- Joueur déchargé ou parti : paliers relevés oubliés.
---@param source integer
function containers.forget(source)
    pending[source] = nil
end
