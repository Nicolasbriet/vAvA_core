--[[
    vava_gathering/server/zones.lua
    Rôle : vitalité des zones, tenue par le serveur : recalculée à la demande depuis `updatedAt` (régénération par
           heure, ralentie pendant une cicatrice), consommée par chaque récolte réussie, bandes (plein, réduit, épuisée),
           cicatrice à 0, épuisements répétés (réaction de la terre). État publié aux clients par un state bag global
           (bande, cicatrice, vitalité entière), écrit au seul changement ; relu et republié au passage de la boucle
           lente d'écriture pour que les props reviennent quand la zone se remet ; écriture groupée sans perte (un
           changement pendant l'écriture reste à écrire). Hooks `vava_gathering:zoneDepleted`, `zoneScarred`,
           `earthReaction` (after).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua, server/journal.lua,
                  server/catalog.lua
]]

local pairs, ipairs = pairs, ipairs
local floor, min, max = math.floor, math.min, math.max
local format = string.format
local time = os.time
local GlobalState = GlobalState

local core = VavaGathering.core
local bridge = VavaGathering.bridge
local journal = VavaGathering.journal
local catalog = VavaGathering.catalog
local cfg = VavaGathering.config
local bands = cfg.bands
local messages = cfg.messages
local BANDS = VavaGathering.BANDS
local STATE_ZONE = VavaGathering.STATE_ZONE

local HOOK_DEPLETED = 'vava_gathering:zoneDepleted'
local HOOK_SCARRED = 'vava_gathering:zoneScarred'
local HOOK_EARTH = 'vava_gathering:earthReaction'

local SELECT_SQL = 'SELECT `zone`, `vitality`, `updated_at`, `scarred_until`, `depletions`, `last_depletion_at` FROM `vava_gathering_zones`'
local UPSERT_SQL = 'INSERT INTO `vava_gathering_zones` (`zone`, `vitality`, `updated_at`, `scarred_until`, `depletions`, `last_depletion_at`) '
    .. 'VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `vitality` = VALUES(`vitality`), `updated_at` = VALUES(`updated_at`), '
    .. '`scarred_until` = VALUES(`scarred_until`), `depletions` = VALUES(`depletions`), `last_depletion_at` = VALUES(`last_depletion_at`)'

local zones = {}
VavaGathering.zones = zones

---@class vAvA.ZoneState
---@field vitality number
---@field updatedAt integer
---@field scarredUntil integer|nil
---@field depletions integer
---@field lastDepletionAt integer|nil
---@field published { band: string, scarred: boolean, vitality: integer }|nil
---@field dirty boolean|'writing'  true : à écrire ; WRITING : écriture en cours (un changement pendant l'attente → true)

---@type table<string, vAvA.ZoneState>
local states = {}
local WRITING = 'writing'

---@param now integer
---@return vAvA.ZoneState
local function fresh(now)
    return { vitality = 100.0, updatedAt = now, scarredUntil = nil, depletions = 0, lastDepletionAt = nil, published = nil, dirty = true }
end

--- Charge l'état de toutes les zones de la config (100 % pour une zone jamais vue). Bloque le thread courant.
---@return boolean ok
---@return string|nil err
function zones.load()
    local rows, err = bridge.db.query(SELECT_SQL, {})
    if err then return false, err end
    local byId = {}
    for _, row in ipairs(rows) do byId[row.zone] = row end
    local now = time()
    for _, def in ipairs(catalog.zones()) do
        local row = byId[def.id]
        if row then
            local scarredUntil = row.scarred_until ~= nil and bridge.Integer(row.scarred_until, 0) or nil
            if scarredUntil == 0 then scarredUntil = nil end
            local lastDepletion = row.last_depletion_at ~= nil and bridge.Integer(row.last_depletion_at, 0) or nil
            if lastDepletion == 0 then lastDepletion = nil end
            states[def.id] = {
                vitality = min(100.0, max(0.0, bridge.Number(row.vitality, 100.0))), updatedAt = bridge.Integer(row.updated_at, now),
                scarredUntil = scarredUntil, depletions = bridge.Integer(row.depletions, 0), lastDepletionAt = lastDepletion,
                published = nil, dirty = false,
            }
        else
            states[def.id] = fresh(now)
        end
    end
    return true
end

--- Applique le temps écoulé : fin de cicatrice, régénération (ralentie pendant une cicatrice). Pur calcul en
--- mémoire : rien n'est marqué à écrire (la paire vitalité / date reste cohérente en base).
---@param def vAvA.ZoneDefinition
---@param state vAvA.ZoneState
---@param now? integer
function zones.refresh(def, state, now)
    now = now or time()
    if state.scarredUntil and now >= state.scarredUntil then state.scarredUntil = nil end
    local elapsed = now - state.updatedAt
    if elapsed <= 0 then return end
    local factor = state.scarredUntil and cfg.scar.regenFactor or 1.0
    state.vitality = min(100.0, state.vitality + def.regenPerHour * (elapsed / 3600) * factor)
    state.updatedAt = now
end

--- Bande d'une zone : épuisée pendant une cicatrice ou sous `reduced`, réduite sous `normal`, pleine au-dessus.
---@param state vAvA.ZoneState
---@return string
function zones.band(state)
    if state.scarredUntil or state.vitality < bands.reduced then return BANDS.DEPLETED end
    if state.vitality < bands.normal then return BANDS.REDUCED end
    return BANDS.NORMAL
end

--- Effets de la bande d'une zone : { yield, tierMalus, failure }.
---@param state vAvA.ZoneState
---@return table
function zones.effects(state)
    return bands.effects[zones.band(state)]
end

--- Publie l'état aux clients si quelque chose de visible a changé.
---@param def vAvA.ZoneDefinition
---@param state vAvA.ZoneState
function zones.publish(def, state)
    local snapshot = { band = zones.band(state), scarred = state.scarredUntil ~= nil, vitality = floor(state.vitality + 0.5) }
    local previous = state.published
    if previous and previous.band == snapshot.band and previous.scarred == snapshot.scarred and previous.vitality == snapshot.vitality then return end
    state.published = snapshot
    GlobalState[STATE_ZONE .. def.id] = snapshot
end

---@param id string
---@return vAvA.ZoneState|nil
function zones.state(id)
    return states[id]
end

--- Une récolte réussie fatigue la zone. Cicatrice à 0 (épuisements comptés dans la fenêtre de la réaction de la
--- terre), hooks et journal aux passages de bande.
---@param def vAvA.ZoneDefinition
---@param cost number
---@param src integer|nil  joueur à prévenir
function zones.consume(def, cost, src)
    local state = states[def.id]
    if not state then return end
    local now = time()
    zones.refresh(def, state, now)
    local before = zones.band(state)
    state.vitality = max(0.0, state.vitality - cost)
    state.dirty = true
    if state.vitality <= 0.0 and not state.scarredUntil then
        state.scarredUntil = now + def.scarHours * 3600
        local window = cfg.earthReaction.windowDays * 86400
        if state.lastDepletionAt and now - state.lastDepletionAt <= window then
            state.depletions = state.depletions + 1
        else
            state.depletions = 1
        end
        state.lastDepletionAt = now
        journal.write('scarred', { zone = def.id, characterId = src and bridge.GetCharacterId(src) or nil, details = { until_ = state.scarredUntil, depletions = state.depletions } })
        core.hooks.runAfter(HOOK_SCARRED, { zone = def.id, scarredUntil = state.scarredUntil, depletions = state.depletions })
        if src then bridge.Notify(src, format(messages.scarred, def.label), 'danger') end
        if state.depletions >= cfg.earthReaction.depletions then
            journal.write('earth_reaction', { zone = def.id, details = { depletions = state.depletions } })
            core.hooks.runAfter(HOOK_EARTH, { zone = def.id, depletions = state.depletions })
        end
    end
    local after = zones.band(state)
    if after == BANDS.DEPLETED and before ~= BANDS.DEPLETED then
        journal.write('depleted', { zone = def.id, characterId = src and bridge.GetCharacterId(src) or nil, details = { vitality = state.vitality } })
        core.hooks.runAfter(HOOK_DEPLETED, { zone = def.id, vitality = state.vitality })
        if src and state.scarredUntil == nil then bridge.Notify(src, format(messages.depleted, def.label), 'warning') end
    end
    zones.publish(def, state)
end

--- Fixe la vitalité (Conseil, module). Une valeur strictement positive lève la cicatrice.
---@param def vAvA.ZoneDefinition
---@param value number
---@param actor { source?: integer, accountId?: integer, module?: string }
function zones.setVitality(def, value, actor)
    local state = states[def.id]
    if not state then return end
    state.vitality = min(100.0, max(0.0, value))
    state.updatedAt = time()
    if state.vitality > 0.0 then state.scarredUntil = nil end
    state.dirty = true
    journal.write('admin_set', { zone = def.id, accountId = actor.accountId, details = { vitality = state.vitality, module = actor.module } })
    zones.publish(def, state)
end

--- Vue d'une zone (état relu) : { id, label, kind, vitality, band, scarred, x, y, z, radius }.
---@param def vAvA.ZoneDefinition
---@return table
function zones.view(def)
    local state = states[def.id]
    zones.refresh(def, state)
    return {
        id = def.id, label = def.label, kind = def.kind, vitality = floor(state.vitality + 0.5), band = zones.band(state),
        scarred = state.scarredUntil ~= nil, x = def.x, y = def.y, z = def.z, radius = def.radius,
    }
end

--- Relit et republie toutes les zones (passage de la boucle lente) : une zone qui se remet change de bande sans
--- qu'on y touche.
function zones.tick()
    local now = time()
    for _, def in ipairs(catalog.zones()) do
        local state = states[def.id]
        zones.refresh(def, state, now)
        zones.publish(def, state)
    end
end

--- Requêtes des zones à écrire, marquées « en cours d'écriture » : l'écriture cède la main, et une récolte pendant
--- l'attente les marque de nouveau à écrire au lieu d'être effacée par `markClean`.
---@param queries table[]
function zones.collect(queries)
    for id, state in pairs(states) do
        if state.dirty then
            state.dirty = WRITING
            queries[#queries + 1] = { query = UPSERT_SQL, values = {
                id, floor(state.vitality * 100 + 0.5) / 100, state.updatedAt, state.scarredUntil, state.depletions, state.lastDepletionAt,
            } }
        end
    end
end

--- Écriture réussie : seules les zones restées telles qu'écrites sont propres (en échec, elles restent à écrire).
function zones.markClean()
    for _, state in pairs(states) do
        if state.dirty == WRITING then state.dirty = false end
    end
end
