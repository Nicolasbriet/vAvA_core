--[[
    vava_gathering/server/nodes.lua
    Rôle : charges des nœuds, tenues par le serveur : recalculées à la demande depuis `updatedAt` (une charge rendue
           toutes les `regenMs`, plus ou moins vite selon la saison de vava_time, le reste du délai conservé et recalé
           quand la saison change), prises par
           une récolte avant toute attente et rendues si elle n'aboutit pas, publiées aux seuls joueurs qui suivent la
           zone du nœud (clé `n:<nœud>` de la zone du core, server/share.lua), au seul changement.
           Écriture groupée sans perte : un changement pendant l'écriture reste à écrire.
    Dépendances : shared/constants.lua, config.lua, shared/zonestate.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua, server/share.lua
]]

local pairs, ipairs = pairs, ipairs
local min, max, floor = math.min, math.max, math.floor
local time = os.time

local bridge = VavaGathering.bridge
local catalog = VavaGathering.catalog
local share = VavaGathering.share
local nodeKey = VavaGathering.zonestate.nodeKey

local SELECT_SQL = 'SELECT `node`, `charges`, `updated_at` FROM `vava_gathering_nodes`'
local UPSERT_SQL = 'INSERT INTO `vava_gathering_nodes` (`node`, `zone`, `charges`, `updated_at`) VALUES (?, ?, ?, ?) '
    .. 'ON DUPLICATE KEY UPDATE `zone` = VALUES(`zone`), `charges` = VALUES(`charges`), `updated_at` = VALUES(`updated_at`)'

local nodes = {}
VavaGathering.nodes = nodes

---@class vAvA.NodeState
---@field charges integer
---@field updatedAt integer   début du délai de la prochaine charge (plein : maintenant)
---@field published integer|nil
---@field factor number|nil       facteur de saison appliqué au dernier passage
---@field refreshedAt integer|nil dernier passage
---@field held number|nil         secondes de repousse acquises, gardées tant que le facteur vaut 0
---@field dirty boolean|'writing'  true : à écrire ; WRITING : écriture en cours (un changement pendant l'attente → true)

---@type table<string, vAvA.NodeState>
local states = {}
local WRITING = 'writing'

--- Charge l'état de tous les nœuds de la config (plein pour un nœud jamais vu). Bloque le thread courant.
---@return boolean ok
---@return string|nil err
function nodes.load()
    local rows, err = bridge.db.query(SELECT_SQL, {})
    if err then return false, err end
    local byId = {}
    for _, row in ipairs(rows) do byId[row.node] = row end
    local now = time()
    for id, def in pairs(catalog.nodes()) do
        local row = byId[id]
        if row then
            states[id] = { charges = min(def.charges, bridge.Integer(row.charges, def.charges)), updatedAt = bridge.Integer(row.updated_at, now), published = nil, dirty = false }
        else
            states[id] = { charges = def.charges, updatedAt = now, published = nil, dirty = true }
        end
    end
    return true
end

--- Applique le temps écoulé : charges rendues, reste du délai conservé. Pur calcul en mémoire. La saison (vava_time,
--- facteur `regen` de la compétence) accélère ou ralentit la repousse ; à 0, rien ne repousse et le temps ne s'accumule
--- pas (pas de charges rendues d'un coup à la saison suivante). Quand le facteur change entre deux passages, l'avance
--- prise sur la prochaine charge (jusqu'au passage précédent) est gardée et recomptée au nouveau rythme ; tant que le
--- facteur vaut 0, elle est gardée à part. Le nœud recalé est à écrire. Saison en attente (vava_time démarre) : rien ne
--- change, `updatedAt` compris.
---@param def vAvA.NodeDefinition
---@param state vAvA.NodeState
---@param now? integer
function nodes.refresh(def, state, now)
    now = now or time()
    local factor = bridge.SeasonFactor('regen', def.resource.skill)
    -- vava_time démarre, saison pas encore connue : rien ne bouge (le temps compté plus tard le sera à la bonne saison)
    if factor == false then return end
    local previous, at = state.factor, state.refreshedAt
    state.factor, state.refreshedAt = factor, now
    if state.charges >= def.charges then
        state.updatedAt, state.held = now, nil
        return
    end
    if previous ~= nil and previous ~= factor and at then
        -- secondes de repousse acquises au rythme d'avant, jusqu'au passage précédent
        local progress = state.held or max(0, at - state.updatedAt) * previous
        if factor > 0 then
            state.updatedAt, state.held = at - floor(progress / factor), nil
        else
            state.held = progress
        end
        state.dirty = true
    end
    if factor <= 0 then
        state.updatedAt = now
        return
    end
    local period = max(1, def.regenMs // 1000)
    local gained = floor((now - state.updatedAt) * factor / period)
    if gained <= 0 then return end
    state.charges = min(def.charges, state.charges + gained)
    state.updatedAt = state.charges >= def.charges and now or (state.updatedAt + floor(gained * period / factor))
end

--- Publie les charges aux joueurs qui suivent la zone du nœud, si elles ont changé.
---@param def vAvA.NodeDefinition
---@param state vAvA.NodeState
function nodes.publish(def, state)
    if state.published == state.charges then return end
    state.published = state.charges
    share.set(def.zone.id, nodeKey(def.id), state.charges)
end

--- Dernières charges publiées d'un nœud, pour déclarer sa zone entière au core.
---@param id string
---@return integer|nil
function nodes.published(id)
    local state = states[id]
    return state and state.published or nil
end

--- Charges disponibles (état relu).
---@param def vAvA.NodeDefinition
---@return integer
function nodes.charges(def)
    local state = states[def.id]
    if not state then return 0 end
    nodes.refresh(def, state)
    nodes.publish(def, state)
    return state.charges
end

--- Consomme une charge ; faux s'il n'en reste aucune.
---@param def vAvA.NodeDefinition
---@return boolean
function nodes.consume(def)
    local state = states[def.id]
    if not state then return false end
    local now = time()
    nodes.refresh(def, state, now)
    if state.charges <= 0 then return false end
    -- le délai de la prochaine charge part de la première consommation d'un nœud plein
    if state.charges >= def.charges then state.updatedAt = now end
    state.charges = state.charges - 1
    state.dirty = true
    nodes.publish(def, state)
    return true
end

--- Rend une charge prise par une récolte qui n'a pas abouti (besace pleine), sans dépasser le maximum.
---@param def vAvA.NodeDefinition
function nodes.restore(def)
    local state = states[def.id]
    if not state then return end
    local now = time()
    nodes.refresh(def, state, now)
    if state.charges >= def.charges then return end
    state.charges = state.charges + 1
    -- de nouveau plein : le délai de la prochaine charge partira de la prochaine consommation
    if state.charges >= def.charges then state.updatedAt = now end
    state.dirty = true
    nodes.publish(def, state)
end

--- Remet un nœud à plein (Conseil).
---@param def vAvA.NodeDefinition
function nodes.recharge(def)
    local state = states[def.id]
    if not state then return end
    state.charges, state.updatedAt, state.dirty = def.charges, time(), true
    nodes.publish(def, state)
end

--- Vue d'un nœud : { id, zone, resource, charges, max }.
---@param def vAvA.NodeDefinition
---@return table
function nodes.view(def)
    return { id = def.id, zone = def.zone.id, resource = def.resource.id, charges = nodes.charges(def), max = def.charges }
end

--- Relit et republie tous les nœuds (passage de la boucle lente).
function nodes.tick()
    local now = time()
    for id, def in pairs(catalog.nodes()) do
        local state = states[id]
        nodes.refresh(def, state, now)
        nodes.publish(def, state)
    end
end

--- Requêtes des nœuds à écrire, marqués « en cours d'écriture » : l'écriture cède la main, et une récolte pendant
--- l'attente les marque de nouveau à écrire au lieu d'être effacée par `markClean`.
---@param queries table[]
function nodes.collect(queries)
    for id, state in pairs(states) do
        if state.dirty then
            state.dirty = WRITING
            local def = catalog.node(id)
            queries[#queries + 1] = { query = UPSERT_SQL, values = { id, def.zone.id, state.charges, state.updatedAt } }
        end
    end
end

--- Écriture réussie : seuls les nœuds restés tels qu'écrits sont propres (en échec, ils restent à écrire).
function nodes.markClean()
    for _, state in pairs(states) do
        if state.dirty == WRITING then state.dirty = false end
    end
end
