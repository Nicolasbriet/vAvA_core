--[[
    vava_needs/server/decay.lua
    Rôle : baisse des besoins avec le temps. Une seule boucle serveur pour tous les personnages actifs (liste tenue
           par les hooks de chargement et de déchargement) :
      - entre deux passages, l'activité est échantillonnée côté serveur (course à pied ; un véhicule ne compte pas) ;
      - à chaque passage : hook annulable vava_needs:decay, baisse proportionnelle au temps écoulé, à l'activité et
        aux modificateurs posés par d'autres modules, puis perte de vie si un besoin est épuisé : décidée et appliquée
        par le serveur quand vava_health tourne (export damage) ; sans lui, seul repli, envoyée au seul joueur, dont
        le client l'applique avec son plancher.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/starvation.lua, server/core.lua, bridge/server.lua,
                  server/state.lua
]]

local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local sqrt, max = math.sqrt, math.max
local GetGameTimer, GetPlayerPed, GetVehiclePedIsIn, GetEntityVelocity, GetPlayers =
    GetGameTimer, GetPlayerPed, GetVehiclePedIsIn, GetEntityVelocity, GetPlayers
local GetEntityMaxHealth = GetEntityMaxHealth
local TriggerClientEvent, CreateThread, Wait = TriggerClientEvent, CreateThread, Wait

local state = VavaNeeds.state
local bridge = VavaNeeds.bridge
local starvation = VavaNeeds.starvation
local cfg = VavaNeeds.config
local activity = cfg.activity
local MAX = VavaNeeds.MAX
local HOOK_DECAY = VavaNeeds.HOOKS.DECAY
local STARVE = VavaNeeds.EVENTS.STARVE
local HOUR_MS = 3600000

-- baisse par milliseconde de chaque besoin, au repos
local ratePerMs = {}
for _, need in ipairs(cfg.needs) do ratePerMs[need.name] = MAX / (need.durationHours * HOUR_MS) end

local decay = {}
VavaNeeds.decay = decay

---@class vAvA.NeedsModifier
---@field owner string                     ressource qui l'a posé (retiré à son arrêt)
---@field multipliers table<string, number>

---@class vAvA.NeedsEntry
---@field characterId integer
---@field lastAt integer        dernier passage (ou chargement)
---@field samples integer       échantillons d'activité depuis le dernier passage
---@field running integer       dont à la course
---@field busyUntil integer     fin du geste de consommation en cours
---@field modifiers table<string, vAvA.NeedsModifier>

---@type table<integer, vAvA.NeedsEntry>
local tracked = {}

---@param src integer
---@return vAvA.NeedsEntry|nil
function decay.entry(src)
    return tracked[src]
end

---@param src integer
---@param characterId integer
function decay.track(src, characterId)
    tracked[src] = { characterId = characterId, lastAt = GetGameTimer(), samples = 0, running = 0, busyUntil = 0, modifiers = {} }
end

--- Personnage chargé. Un abonné précédent a pu céder la main (lecture en base) : un joueur parti entre-temps a déjà
--- été déchargé, son suivi ne doit pas renaître (entrée orpheline : baisse en double au retour du personnage).
---@param payload table  { source, characterId }
local function onLoaded(payload)
    local character = VavaNeeds.core.characters.getActive(payload.source)
    if character and character.id == payload.characterId then decay.track(payload.source, payload.characterId) end
end

---@param src integer
function decay.untrack(src)
    tracked[src] = nil
end

--- Vrai si le joueur court à pied en ce moment (lu côté serveur, OneSync).
---@param src integer
---@return boolean
local function isRunning(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or GetVehiclePedIsIn(ped, false) ~= 0 then return false end
    local velocity = GetEntityVelocity(ped)
    -- vitesse horizontale : une chute ne compte pas comme une course
    return sqrt(velocity.x * velocity.x + velocity.y * velocity.y) >= activity.runningSpeed
end

local function sample()
    for src, entry in pairs(tracked) do
        entry.samples = entry.samples + 1
        if isRunning(src) then entry.running = entry.running + 1 end
    end
end

---@param entry vAvA.NeedsEntry
---@param name string
---@return number
local function modifierFor(entry, name)
    local factor = 1
    for _, modifier in pairs(entry.modifiers) do
        factor = factor * (modifier.multipliers[name] or 1)
    end
    return factor
end

-- codes de vava_health qui disent seulement qu'il n'y a rien à retirer maintenant (à terre, pas encore apparu,
-- personnage pas encore suivi, module en démarrage)
local QUIET_HEALTH_CODES = { downed = true, not_spawned = true, no_character = true, not_ready = true }

--- Perte de vie d'un besoin épuisé (points de vie GTA). Avec vava_health, le serveur la décide et l'applique (part de
--- la vie au-dessus du seuil, d'après la vie maximale lue sur le ped serveur) : vava_health tient la vie, la mise à
--- terre, et prévient lui-même le client. Sans lui, seul repli : le client l'applique avec son plancher.
---@param src integer
---@param damage number
local function starve(src, damage)
    if not bridge.HealthRunning() then
        TriggerClientEvent(STARVE, src, damage)
        return
    end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    local amount = starvation.share(damage, GetEntityMaxHealth(ped), cfg.health.downThreshold)
    if not amount then return end
    local ok, code = bridge.Damage(src, amount)
    if not ok and not QUIET_HEALTH_CODES[code] then
        VavaNeeds.log.warn('perte de vie (faim, soif) du joueur %d non appliquée : %s', src, tostring(code))
    end
end

---@param src integer
---@param entry vAvA.NeedsEntry
---@param now integer
local function decayOne(src, entry, now)
    local elapsed = now - entry.lastAt
    local share = entry.samples > 0 and entry.running / entry.samples or 0
    entry.lastAt, entry.samples, entry.running = now, 0, 0
    if elapsed <= 0 then return end

    local core = VavaNeeds.core
    local allowed = core.hooks.runBefore(HOOK_DECAY, { source = src, characterId = entry.characterId, elapsedMs = elapsed })
    if not allowed then return end

    local previous = state.read(entry.characterId)
    local pace = 1 + (activity.runningMultiplier - 1) * share
    local values = {}
    for name, rate in pairs(ratePerMs) do
        values[name] = previous[name] - rate * elapsed * pace * modifierFor(entry, name)
    end
    local written, err = state.write(src, entry.characterId, previous, values, 'decay')
    if not written then
        VavaNeeds.log.warn('besoins du personnage #%d non écrits : %s', entry.characterId, tostring(err))
        return
    end

    local damage = 0
    for _, need in ipairs(cfg.needs) do
        if written[need.name] <= 0 then damage = damage + need.damage end
    end
    if damage > 0 then starve(src, damage) end
end

--- Un passage sur tous les personnages actifs.
function decay.tick()
    local now = GetGameTimer()
    -- liste figée : un handler de hook peut céder la main, et un personnage se charger entre-temps
    local sources, count = {}, 0
    for src in pairs(tracked) do
        count = count + 1
        sources[count] = src
    end
    for i = 1, count do
        local src = sources[i]
        local entry = tracked[src]
        if entry then decayOne(src, entry, now) end
    end
end

-- Modificateurs ----------------------------------------------------------------------------------------------

--- Pose (ou remplace) un modificateur de vitesse de baisse sur le personnage d'un joueur.
---@param entry vAvA.NeedsEntry
---@param key string
---@param owner string
---@param multipliers table<string, number>
---@return boolean ok
---@return string|nil code
function decay.setModifier(entry, key, owner, multipliers)
    local existing = entry.modifiers[key]
    if existing and existing.owner ~= owner then return false, 'key_taken' end
    entry.modifiers[key] = { owner = owner, multipliers = multipliers }
    return true
end

---@param entry vAvA.NeedsEntry
---@param key string
---@param owner string
---@return boolean ok
---@return string|nil code
function decay.removeModifier(entry, key, owner)
    local existing = entry.modifiers[key]
    if not existing then return false, 'not_found' end
    if existing.owner ~= owner then return false, 'not_owner' end
    entry.modifiers[key] = nil
    return true
end

--- Retire les modificateurs posés par une ressource arrêtée.
---@param owner string
function decay.purgeOwner(owner)
    for _, entry in pairs(tracked) do
        for key, modifier in pairs(entry.modifiers) do
            if modifier.owner == owner then entry.modifiers[key] = nil end
        end
    end
end

-- Démarrage -----------------------------------------------------------------------------------------------------

--- Reprend les personnages déjà joués (module redémarré en cours de partie). Bloque le thread courant.
function decay.adoptActive()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = src and VavaNeeds.core.characters.getActive(src)
        if character and not tracked[src] then decay.track(src, character.id) end
    end
end

--- Branche les hooks du core et lance la boucle. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function decay.start()
    local hooks = VavaNeeds.core.hooks
    local id, err = hooks.after('core:character:loaded', onLoaded)
    if not id then return false, err end
    id, err = hooks.after('core:character:unloading', function(payload) decay.untrack(payload.source) end)
    if not id then return false, err end

    local samplesPerTick = max(1, cfg.tickMs // activity.sampleMs)
    CreateThread(function()
        local count = 0
        while true do
            Wait(activity.sampleMs)
            sample()
            count = count + 1
            if count >= samplesPerTick then
                count = 0
                decay.tick()
            end
        end
    end)
    return true
end
