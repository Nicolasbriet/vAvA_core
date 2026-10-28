--[[
    vava_gathering/server/harvest.lua
    Rôle : la récolte décidée par le serveur. Début : personnage, nœud, distance (lue côté serveur), charges, outil
           en main du bon genre et non brisé, place dans la besace, cooldown, hook annulable ; une seule récolte à la
           fois par joueur, jeton par geste, oubliée si jamais finie. Fin : durée et distance revérifiées, outil toujours
           en main et usé, échec selon la bande, rendement, palier et provenance sur la pile, charge et vitalité
           consommées, XP demandée à vava_skills, pièce supplémentaire (peau), hooks. La pêche partage la fin
           (fishing.lua).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/catalog.lua, server/zones.lua,
                  server/nodes.lua, server/quality.lua ; server/fishing.lua (lié à l'exécution)
]]

local type, tostring = type, tostring
local mathType, random, max = math.type, math.random, math.max
local format = string.format
local GetGameTimer, SetTimeout = GetGameTimer, SetTimeout

local core = VavaGathering.core
local bridge = VavaGathering.bridge
local catalog = VavaGathering.catalog
local zones = VavaGathering.zones
local nodes = VavaGathering.nodes
local quality = VavaGathering.quality
local geometry = VavaGathering.geometry
local cfg = VavaGathering.config
local interact, messages = cfg.interact, cfg.messages

local HOOK_HARVESTING = 'vava_gathering:harvesting'
local HOOK_HARVESTED = 'vava_gathering:harvested'
local MAX_TOKEN = VavaGathering.MAX_TOKEN
-- part de la solidité sous laquelle le joueur est prévenu de l'usure
local WORN_RATIO = 0.2

local harvest = {}
VavaGathering.harvest = harvest

---@class vAvA.HarvestSession
---@field token integer
---@field source integer
---@field characterId integer
---@field node vAvA.NodeDefinition
---@field resource vAvA.ResourceDefinition
---@field tool vAvA.ToolDefinition|nil
---@field heldId integer|nil
---@field level integer
---@field kind 'harvest'|'fishing'
---@field startedAt integer      GetGameTimer
---@field durationMs integer
---@field bitAt integer|nil      pêche : moment de la touche

---@type table<integer, vAvA.HarvestSession>
local sessions = {}
-- source → GetGameTimer de la dernière fin (cooldown)
local lastFinish = {}
local lastToken = 0

---@param tier integer
---@return string
local function tierLabel(tier)
    return messages.tiers[tier] or tostring(tier)
end

---@param kind string
---@return string
local function toolLabel(kind)
    return messages.toolKinds[kind] or kind
end

--- Vrai si le joueur est à portée du nœud (position lue côté serveur, tolérance du serveur comprise).
---@param src integer
---@param node vAvA.NodeDefinition
---@return boolean
local function nearNode(src, node)
    local x, y, z = bridge.Position(src)
    if not x then return false end
    return geometry.within(x, y, z, node.x, node.y, node.z, interact.distance + interact.serverTolerance)
end

---@param src integer
---@return vAvA.HarvestSession|nil
function harvest.session(src)
    return sessions[src]
end

--- Oublie la récolte en cours d'un joueur.
---@param src integer
function harvest.drop(src)
    sessions[src] = nil
end

--- Commence une récolte (ou lance la ligne). Bloque le thread courant (inventaire, hook).
---@param src integer
---@param nodeId any
---@return boolean ok
---@return table|string result  { token, kind, durationMs, anim, label } ou code
function harvest.begin(src, nodeId)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    local node = catalog.node(nodeId)
    if not node then return false, 'unknown_node' end
    if sessions[src] then return false, 'busy' end
    local now = GetGameTimer()
    if lastFinish[src] and now - lastFinish[src] < interact.cooldownMs then return false, 'cooldown' end
    if not nearNode(src, node) then return false, 'too_far' end
    if nodes.charges(node) <= 0 then
        bridge.Notify(src, messages.noCharges, 'info')
        return false, 'no_charges'
    end
    local resource = node.resource
    local tool, held
    if resource.tool then
        held = bridge.Held(src)
        if not held then
            bridge.Notify(src, format(messages.noTool, toolLabel(resource.tool)), 'warning')
            return false, 'no_tool'
        end
        tool = catalog.tool(held.item)
        if not tool or tool.kind ~= resource.tool then
            bridge.Notify(src, format(messages.noTool, toolLabel(resource.tool)), 'warning')
            return false, 'wrong_tool'
        end
        if type(held.metadata) == 'table' and held.metadata.broken == true then
            bridge.Notify(src, messages.brokenTool, 'warning')
            return false, 'broken_tool'
        end
    end
    local canCarry = bridge.CanCarry(src, resource.item, 1)
    if not canCarry then
        bridge.Notify(src, messages.noSpace, 'warning')
        return false, 'no_space'
    end
    local payload = { source = src, characterId = characterId, node = node.id, zone = node.zone.id, resource = resource.id, item = resource.item }
    local allowed, reason = core.hooks.runBefore(HOOK_HARVESTING, payload)
    if not allowed then return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused' end
    -- le hook a pu céder la main
    if sessions[src] then return false, 'busy' end

    local level = bridge.GetLevel(src, resource.skill)
    lastToken = (lastToken % MAX_TOKEN) + 1
    local session = {
        token = lastToken, source = src, characterId = characterId, node = node, resource = resource, tool = tool,
        heldId = held and held.id or nil, level = level, startedAt = GetGameTimer(),
        kind = resource.fishing and 'fishing' or 'harvest',
        durationMs = resource.fishing and 0 or quality.duration(resource, tool, level),
    }
    sessions[src] = session
    SetTimeout(interact.expireMs, function()
        if sessions[src] == session then sessions[src] = nil end
    end)
    if session.kind == 'fishing' then VavaGathering.fishing.cast(session) end
    return true, { token = session.token, kind = session.kind, durationMs = session.durationMs, anim = resource.anim, label = resource.label }
end

--- Interrompt la récolte en cours si le jeton correspond. Toujours vrai.
---@param src integer
---@param token any
---@return boolean
function harvest.cancel(src, token)
    local session = sessions[src]
    if session and session.token == token then sessions[src] = nil end
    return true
end

--- Use l'outil tenu (solidité par métadonnées ; brisé à 0). Un outil sans solidité connue en reçoit une.
---@param session vAvA.HarvestSession
---@param held table
local function wear(session, held)
    local tool = session.tool
    if not tool or tool.wear <= 0 then return end
    local meta = type(held.metadata) == 'table' and held.metadata or {}
    local maximum = type(meta.max_durability) == 'number' and meta.max_durability or cfg.toolDefaults.durability
    local current = type(meta.durability) == 'number' and meta.durability or maximum
    local left = max(0, current - tool.wear)
    local patch = { durability = left, max_durability = maximum }
    if left <= 0 then patch.broken = true end
    bridge.PatchMetadata(session.source, held.id, patch)
    local label = catalog.itemLabel(held.item)
    if left <= 0 then
        bridge.Notify(session.source, format(messages.toolBroken, label), 'danger')
    elseif left <= maximum * WORN_RATIO then
        bridge.Notify(session.source, format(messages.toolWorn, label, left), 'warning')
    end
end

--- Fin commune d'une récolte et d'une pêche réussies : contrôles, échec de la terre, rendement, palier, inventaire,
--- consommation, XP, hooks. Bloque le thread courant.
---@param session vAvA.HarvestSession
---@return boolean ok
---@return table|string result  { item, label, quantity, tier, extra? } ou code
function harvest.succeed(session)
    local src, node, resource = session.source, session.node, session.resource
    local zone = node.zone
    if not nearNode(src, node) then return false, 'too_far' end
    if nodes.charges(node) <= 0 then
        sessions[src] = nil
        bridge.Notify(src, messages.noCharges, 'info')
        return false, 'no_charges'
    end
    local held
    if resource.tool then
        held = bridge.Held(src)
        if not held or held.id ~= session.heldId then
            sessions[src] = nil
            bridge.Notify(src, format(messages.noTool, toolLabel(resource.tool)), 'warning')
            return false, 'no_tool'
        end
    end
    local state = zones.state(zone.id)
    zones.refresh(zone, state)
    local band = zones.band(state)
    local effects = zones.effects(state)
    -- l'outil s'use même quand la terre se refuse
    if held then wear(session, held) end
    lastFinish[src] = GetGameTimer()
    if quality.failed(effects) then
        sessions[src] = nil
        bridge.Notify(src, messages.failed, 'warning')
        return false, 'failed'
    end

    local amount = quality.yield(resource, session.tool, effects)
    local score = quality.score(session.level, quality.toolQuality(held), state.vitality, session.tool and session.tool.qualityBonus or 0)
    local tier = quality.tier(score, effects.tierMalus)
    local metadata = { tier = tier }
    if cfg.quality.origin then metadata.origin = zone.label end
    local ok = bridge.Add(src, resource.item, amount, metadata)
    if not ok then
        sessions[src] = nil
        bridge.Notify(src, messages.noSpace, 'warning')
        return false, 'no_space'
    end
    nodes.consume(node)
    zones.consume(zone, zone.cost, src)
    local extra
    if resource.extra and random() < resource.extra.chance then
        if bridge.Add(src, resource.extra.item, 1, metadata) then
            extra = { item = resource.extra.item, label = catalog.itemLabel(resource.extra.item), quantity = 1 }
        end
    end
    bridge.AddXp(src, { skill = resource.skill, source = resource.id, difficulty = resource.difficulty, amount = resource.xp })
    sessions[src] = nil

    local itemLabel = catalog.itemLabel(resource.item)
    bridge.Notify(src, format(messages.harvested, resource.label, amount, itemLabel, tierLabel(tier)), 'info')
    if extra then bridge.Notify(src, format(messages.harvestedExtra, extra.label), 'info') end
    core.hooks.runAfter(HOOK_HARVESTED, {
        source = src, characterId = session.characterId, node = node.id, zone = zone.id, resource = resource.id,
        item = resource.item, quantity = amount, tier = tier, band = band, extra = extra and extra.item or nil,
    })
    return true, { item = resource.item, label = itemLabel, quantity = amount, tier = tier, extra = extra }
end

--- Fin du geste de récolte : la durée annoncée doit être écoulée (tolérance de latence).
---@param src integer
---@param token any
---@return boolean ok
---@return table|string result
function harvest.finish(src, token)
    local session = sessions[src]
    if not session or session.token ~= token or session.kind ~= 'harvest' then return false, 'not_found' end
    if GetGameTimer() - session.startedAt < session.durationMs - interact.finishToleranceMs then return false, 'too_soon' end
    return harvest.succeed(session)
end

--- Joueur parti : sa récolte et son cooldown sont oubliés.
---@param src integer
function harvest.forget(src)
    sessions[src] = nil
    lastFinish[src] = nil
end

harvest.tierLabel = tierLabel
harvest.isToken = function(value) return mathType(value) == 'integer' and value >= 1 and value <= MAX_TOKEN end
