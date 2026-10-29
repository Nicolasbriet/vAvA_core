--[[
    vava_health/server/life.lua
    Rôle : vie des personnages en jeu, décidée par le serveur.
      - Une boucle lit la vie de chaque joueur apparu (une native par joueur, aucun message du client) : sous le
        seuil, le joueur est mis à terre, avec la cause et l'auteur lus côté serveur.
      - À terre : temps compté, retour automatique au lieu de soins à échéance ; un client qui se relève seul est
        remis à terre (seul le serveur relève), journalisé une fois par mise à terre.
      - Vie enregistrée dans le personnage à intervalle régulier et au déchargement (déconnexion comprise : se
        déconnecter à terre ne sert à rien). Au départ, la vie est relue avec la même règle si le ped est encore
        lisible : un coup mortel reçu juste avant de partir met à terre.
      - Soins, blessures, réanimation et retour au lieu de soins pour les autres fichiers et l'API.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/state.lua (server/assist.lua à l'exécution)
]]

local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local abs, huge = math.abs, math.huge
local GetGameTimer, GetPlayers, GetPlayerPed, DoesEntityExist = GetGameTimer, GetPlayers, GetPlayerPed, DoesEntityExist
local GetEntityHealth, GetEntityMaxHealth, GetEntityCoords = GetEntityHealth, GetEntityMaxHealth, GetEntityCoords
local GetPedCauseOfDeath, GetPedSourceOfDeath = GetPedCauseOfDeath, GetPedSourceOfDeath
local TriggerClientEvent, CreateThread, Wait = TriggerClientEvent, CreateThread, Wait

local state = VavaHealth.state
local cfg = VavaHealth.config
local EVENTS = VavaHealth.EVENTS
local HOOKS = VavaHealth.HOOKS
local DOWN = cfg.downThreshold
-- départ lu avant les autres abonnés : le ped n'est lisible qu'un temps, et un abonné précédent pourrait attendre la
-- base (l'inventaire écrit au déchargement)
local UNLOADING_PRIORITY = 10

local life = {}
VavaHealth.life = life

---@class vAvA.HealthEntry
---@field characterId integer
---@field spawned boolean       apparition confirmée (la vie est alors lisible)
---@field graceUntil integer    avant : lecture de la vie ignorée (apparition, réanimation récentes)
---@field health number
---@field downed boolean
---@field downedFor integer
---@field sampledAt integer
---@field resentAt integer
---@field reported boolean|nil  relevé seul déjà journalisé pour cette mise à terre
---@field saved vAvA.HealthState  dernière valeur écrite dans le personnage

---@type table<integer, vAvA.HealthEntry>
local entries = {}

---@param src integer
---@return vAvA.HealthEntry|nil
function life.entry(src)
    return entries[src]
end

--- Vie actuelle d'un ped (0 à 1), lue côté serveur.
---@param ped integer
---@return number
local function ratioOf(ped)
    local maxHealth = GetEntityMaxHealth(ped)
    if maxHealth <= DOWN then return 0 end
    local value = (GetEntityHealth(ped) - DOWN) / (maxHealth - DOWN)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Vie actuelle d'un joueur apparu, sinon la dernière connue.
---@param src integer
---@param entry vAvA.HealthEntry
---@return number
local function currentHealth(src, entry)
    local ped = GetPlayerPed(src)
    if entry.spawned and not entry.downed and ped ~= 0 then return ratioOf(ped) end
    return entry.health
end
life.currentHealth = currentHealth

--- Écrit la santé dans le personnage si elle a changé depuis la dernière écriture.
---@param entry vAvA.HealthEntry
local function persist(entry)
    local saved = entry.saved
    if saved.downed == entry.downed and saved.downedFor == entry.downedFor
        and abs(saved.health - entry.health) < cfg.sampleEpsilon then
        return
    end
    local value = { health = state.ratio(entry.health), downed = entry.downed, downedFor = entry.downedFor }
    local ok, err = state.write(entry.characterId, value)
    if not ok then
        VavaHealth.log.warn('santé du personnage #%d non écrite : %s', entry.characterId, tostring(err))
        return
    end
    entry.saved = value
end

---@param src integer
---@return integer|nil killer  joueur à l'origine de la mise à terre
local function killerOf(src, ped)
    local origin = GetPedSourceOfDeath(ped)
    if not origin or origin == 0 or origin == ped then return nil end
    for _, id in ipairs(GetPlayers()) do
        local other = tonumber(id)
        if other and other ~= src and GetPlayerPed(other) == origin then return other end
    end
    return nil
end

---@param src integer
---@return table|nil point  lieu de soins le plus proche
local function nearestPoint(src)
    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped)
    local best, bestDistance = nil, huge
    for _, point in ipairs(cfg.respawn.points) do
        local distance = coords and ((point.x - coords.x) ^ 2 + (point.y - coords.y) ^ 2) or 0
        if distance < bestDistance then best, bestDistance = point, distance end
    end
    return best
end

local function assist()
    return VavaHealth.assist
end

-- Transitions ------------------------------------------------------------------------------------------------

--- Met un joueur à terre. `reason` : death (vie lue sous le seuil) ou api (décision d'un module : le client couche
--- son ped).
---@param src integer
---@param reason string
---@param cause? integer|string
---@param killer? integer
---@return boolean ok
---@return string|nil code
function life.down(src, reason, cause, killer)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if entry.downed then return false, 'already_downed' end
    local now = GetGameTimer()
    entry.downed, entry.downedFor, entry.health, entry.reported = true, 0, 0, false
    entry.sampledAt, entry.resentAt, entry.graceUntil = now, now, now + cfg.graceMs
    persist(entry)
    assist().cancelFor(src)
    if reason ~= 'death' then TriggerClientEvent(EVENTS.DOWN, src) end
    VavaHealth.core.hooks.runAfter(HOOKS.DOWNED, {
        source = src, characterId = entry.characterId, reason = reason, cause = cause, killer = killer,
    })
    return true
end

--- Relève un joueur à terre, sur place.
---@param src integer
---@param health number  vie de départ (0 à 1)
---@param reason string  assist ou api
---@param by? integer    joueur qui l'a relevé
---@return boolean ok
---@return string|nil code
function life.revive(src, health, reason, by)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if not entry.downed then return false, 'not_downed' end
    local now = GetGameTimer()
    entry.downed, entry.downedFor, entry.health = false, 0, health
    entry.sampledAt, entry.graceUntil = now, now + cfg.graceMs
    persist(entry)
    assist().cancelFor(src)
    TriggerClientEvent(EVENTS.REVIVE, src, health)
    VavaHealth.core.hooks.runAfter(HOOKS.REVIVED, { source = src, characterId = entry.characterId, reason = reason, by = by })
    return true
end

--- Porte un joueur à terre jusqu'au lieu de soins le plus proche.
---@param src integer
---@param reason string  choice (il a rendu l'âme), timeout ou api
---@return boolean ok
---@return string|nil code
function life.respawn(src, reason)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if not entry.downed then return false, 'not_downed' end
    local point = nearestPoint(src)
    local health = cfg.respawn.health
    entry.downed, entry.downedFor, entry.health = false, 0, health
    -- la vie redevient lisible à la confirmation de l'apparition
    entry.spawned = false
    persist(entry)
    assist().cancelFor(src)
    -- avant l'ordre d'apparition (même canal, même ordre) : le client ne recouche pas son ped à l'arrivée
    TriggerClientEvent(EVENTS.RESPAWN, src, health)
    local ok, err = VavaHealth.core.characters.spawn(src, point)
    if not ok then VavaHealth.log.warn('retour au lieu de soins du joueur %d impossible : %s', src, tostring(err)) end
    TriggerClientEvent(EVENTS.MESSAGE, src, 'respawned')
    VavaHealth.core.hooks.runAfter(HOOKS.RESPAWNED, {
        source = src, characterId = entry.characterId, reason = reason, point = { x = point.x, y = point.y, z = point.z },
    })
    return true
end

--- Fixe la vie d'un joueur debout (0 à 1). À 0, il tombe : la boucle le met alors à terre.
---@param src integer
---@param health number
---@return boolean ok
---@return string|nil code
function life.setHealth(src, health)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if entry.downed then return false, 'downed' end
    if not entry.spawned then return false, 'not_spawned' end
    entry.health = state.ratio(health)
    entry.sampledAt = GetGameTimer()
    persist(entry)
    TriggerClientEvent(EVENTS.SET, src, entry.health)
    return true
end

--- Ajoute (ou retire) de la vie à partir de la vie actuelle, lue côté serveur.
---@param src integer
---@param delta number
---@return boolean ok
---@return string|nil code
function life.adjust(src, delta)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    return life.setHealth(src, currentHealth(src, entry) + delta)
end

-- Boucle ------------------------------------------------------------------------------------------------------

---@param src integer
---@param entry vAvA.HealthEntry
---@param now integer
---@param elapsed integer
local function check(src, entry, now, elapsed)
    if not entry.spawned then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end

    if entry.downed then
        entry.downedFor = entry.downedFor + elapsed
        if entry.downedFor >= cfg.downed.autoRespawnMs then
            life.respawn(src, 'timeout')
            return
        end
        if now - entry.sampledAt >= cfg.sampleMs then
            entry.sampledAt = now
            persist(entry)
        end
        if now >= entry.graceUntil and GetEntityHealth(ped) > DOWN and now - entry.resentAt >= cfg.downed.resendMs then
            entry.resentAt = now
            -- remis à terre à chaque fois, journalisé une seule fois par mise à terre
            if not entry.reported then
                entry.reported = true
                VavaHealth.log.warn('joueur %d debout sans avoir été relevé : remis à terre', src)
            end
            TriggerClientEvent(EVENTS.DOWN, src)
        end
        return
    end

    if now < entry.graceUntil then return end
    if GetEntityHealth(ped) <= DOWN then
        life.down(src, 'death', GetPedCauseOfDeath(ped), killerOf(src, ped))
        return
    end
    if now - entry.sampledAt >= cfg.sampleMs then
        entry.sampledAt = now
        entry.health = ratioOf(ped)
        persist(entry)
    end
end

local function tick(elapsed)
    local now = GetGameTimer()
    -- liste figée : un handler de hook peut céder la main, et un personnage se charger entre-temps
    local sources, count = {}, 0
    for src in pairs(entries) do
        count = count + 1
        sources[count] = src
    end
    for i = 1, count do
        local src = sources[i]
        local entry = entries[src]
        if entry then check(src, entry, now, elapsed) end
    end
end

-- Suivi des personnages -------------------------------------------------------------------------------------------

---@param src integer
---@param characterId integer
function life.track(src, characterId)
    local saved = state.read(characterId)
    entries[src] = {
        characterId = characterId, spawned = false, graceUntil = huge,
        health = saved.health, downed = saved.downed, downedFor = saved.downedFor,
        sampledAt = GetGameTimer(), resentAt = 0, saved = saved,
    }
end

--- Personnage chargé. Un abonné précédent a pu céder la main (lecture en base) : un joueur parti entre-temps a déjà
--- été déchargé, son suivi ne doit pas renaître (entrée orpheline jamais retirée).
---@param src integer
---@param characterId integer
local function onLoaded(src, characterId)
    local character = VavaHealth.core.characters.getActive(src)
    if character and character.id == characterId then life.track(src, characterId) end
end

---@param src integer
local function onSpawned(src)
    local entry = entries[src]
    if not entry then return end
    local now = GetGameTimer()
    entry.spawned, entry.graceUntil, entry.sampledAt = true, now + cfg.graceMs, now
end

--- Ped d'un joueur, s'il existe encore (au départ, il peut déjà avoir été retiré).
---@param src integer
---@return integer|nil
local function readablePed(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

--- Départ du personnage (déconnexion comprise). Si le ped est encore lisible, la vie est relue avec la règle de la
--- boucle : un coup mortel reçu depuis la dernière lecture met à terre, au lieu d'être sauvé debout. Ped retiré, ou
--- lecture pas encore fiable (délai de grâce) : la dernière valeur connue est gardée, rien n'est supposé.
---@param src integer
local function onUnloading(src)
    local entry = entries[src]
    if not entry then return end
    local ped = entry.spawned and not entry.downed and GetGameTimer() >= entry.graceUntil and readablePed(src)
    if ped then
        if GetEntityHealth(ped) <= DOWN then
            life.down(src, 'death', GetPedCauseOfDeath(ped), killerOf(src, ped))
        else
            entry.health = ratioOf(ped)
        end
    end
    persist(entry)
    assist().cancelFor(src)
    entries[src] = nil
end

--- Reprend les personnages déjà joués (module redémarré en cours de partie). Bloque le thread courant.
function life.adoptActive()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = src and VavaHealth.core.characters.getActive(src)
        if character and not entries[src] then
            life.track(src, character.id)
            -- déjà en jeu : la vie est lisible, après le délai habituel
            onSpawned(src)
        end
    end
end

--- Branche les hooks du core et lance la boucle. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function life.start()
    local hooks = VavaHealth.core.hooks
    for _, def in ipairs({
        { 'core:character:loaded', function(payload) onLoaded(payload.source, payload.characterId) end },
        { 'core:character:spawned', function(payload) onSpawned(payload.source) end },
        { 'core:character:unloading', function(payload) onUnloading(payload.source) end, UNLOADING_PRIORITY },
    }) do
        local id, err = hooks.after(def[1], def[2], def[3])
        if not id then return false, err end
    end

    CreateThread(function()
        local last = GetGameTimer()
        while true do
            Wait(cfg.pollMs)
            local now = GetGameTimer()
            tick(now - last)
            last = now
        end
    end)
    return true
end
