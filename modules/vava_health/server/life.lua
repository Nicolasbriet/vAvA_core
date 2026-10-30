--[[
    vava_health/server/life.lua
    Rôle : vie des personnages en jeu, tenue par le serveur (spec T-110 § 7.3).
      - La vie de référence est `entry.health` (part de 0 à 1) : coups de la chaîne, soins, `setHealth` la changent ;
        le client ne fait qu'appliquer l'ordre `vava_health:set`. Les coups d'un même tour partent en un seul ordre
        (valeur relue au moment de l'envoi). Vie du serveur à 0 : mise à terre aussitôt.
      - Une boucle lit le ped de chaque joueur (une native par joueur, aucun message du client) après la fenêtre
        d'application d'un ordre : ped plus bas = perte native (chute, noyade, feu du décor…) acceptée telle quelle,
        sans modificateurs ; ped au seuil ou dessous = mise à terre native (cause et auteur lus côté serveur) ; ped
        plus haut = client en retard ou modifié : la valeur du serveur est renvoyée au plus toutes les `sync.resendMs`,
        avec une ligne de console à la 1re correction puis toutes les `sync.logEvery`.
      - Porte d'apparition : rien dans l'écriture de la vie n'en dépend ; un client qui ne confirme pas son
        apparition voit son ped lu d'office `spawn.confirmTimeoutMs` après l'ordre.
      - Toute mise à terre ordonne au client de coucher son ped (vie GTA à 0). À terre : temps compté, retour
        automatique au lieu de soins à échéance ; un ped resté au seuil ou au-dessus est recouché (seul le serveur
        relève), journalisé une fois par mise à terre.
      - Écriture dans le personnage : différée pour les coups et les pertes (au plus toutes les `sampleMs`), immédiate
        aux transitions, aux soins, au départ et à l'arrêt du module. Au départ, un ped encore lisible est relu : un
        coup mortel reçu juste avant de partir met à terre ; une perte native est gardée ; jamais une hausse.
      - Pertes natives : hook vava_health:hit `after` (origin vava_health, kind monde, tags.native) ; mises à terre
        natives inscrites au journal des coups.
    Dépendances : shared/constants.lua, config.lua, shared/vitality.lua, shared/sync.lua, server/core.lua,
                  server/state.lua, server/journal.lua (server/assist.lua à l'exécution)
]]

local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local abs, huge, min = math.abs, math.huge, math.min
local GetGameTimer, GetPlayers, GetPlayerPed, DoesEntityExist = GetGameTimer, GetPlayers, GetPlayerPed, DoesEntityExist
local GetEntityHealth, GetEntityMaxHealth, GetEntityCoords = GetEntityHealth, GetEntityMaxHealth, GetEntityCoords
local GetPedCauseOfDeath, GetPedSourceOfDeath, GetPlayerPing = GetPedCauseOfDeath, GetPedSourceOfDeath, GetPlayerPing
local CreateThread, Wait, SetTimeout = CreateThread, Wait, SetTimeout

local state = VavaHealth.state
local vitality = VavaHealth.vitality
local sync = VavaHealth.sync
local journal = VavaHealth.journal
local cfg = VavaHealth.config
local syncCfg = cfg.sync
local EVENTS = VavaHealth.EVENTS
local HOOKS = VavaHealth.HOOKS
local DOWN = cfg.downThreshold
local HEALTH_POINTS = cfg.chain.healthPoints
-- départ lu avant les autres abonnés : le ped n'est lisible qu'un temps, et un abonné précédent pourrait attendre la
-- base (l'inventaire écrit au déchargement)
local UNLOADING_PRIORITY = 10
-- en dessous, une vie est nulle (arrondi des flottants)
local EPSILON = 1e-9
-- origine et type des pertes natives (hook after, journal)
local NATIVE_KIND = 'monde'

local life = {}
VavaHealth.life = life

---@class vAvA.HealthEntry
---@field characterId integer
---@field spawned boolean       apparition confirmée (ou lue d'office)
---@field graceUntil integer    avant : lecture du ped ignorée (apparition, réanimation récentes)
---@field health number         vie de référence (serveur), 0 à 1
---@field downed boolean
---@field downedFor integer
---@field sampledAt integer
---@field resentAt integer
---@field reported boolean|nil  relevé seul déjà journalisé pour cette mise à terre
---@field saved vAvA.HealthState  dernière valeur écrite dans le personnage
---@field syncUntil integer     avant : lecture du ped ignorée (ordre de vie en cours d'application)
---@field pushPending boolean   un envoi de la vie est déjà prévu ce tour
---@field dirty boolean         vie à écrire dans le personnage
---@field correctedAt integer|nil
---@field corrections integer
---@field spawnOrderedAt integer|nil
---@field forcedSpawn boolean   apparition lue d'office (console une fois par chargement)

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

--- Vie de référence d'un joueur (valeur du serveur ; 0 à terre).
---@param _ integer
---@param entry vAvA.HealthEntry
---@return number
local function currentHealth(_, entry)
    if entry.downed then return 0 end
    return entry.health
end
life.currentHealth = currentHealth

--- Position du ped lue côté serveur, ou nil.
---@param src integer
---@return table|nil
local function positionOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = coords.x, y = coords.y, z = coords.z }
end
life.positionOf = positionOf

--- Écrit la santé dans le personnage si elle a changé depuis la dernière écriture.
---@param entry vAvA.HealthEntry
local function persist(entry)
    entry.dirty = false
    local saved = entry.saved
    if saved.downed == entry.downed and saved.downedFor == entry.downedFor
        and abs(saved.health - entry.health) < cfg.sampleEpsilon then
        return
    end
    local value = { health = state.ratio(entry.health), downed = entry.downed, downedFor = entry.downedFor }
    local ok, err = state.write(entry.characterId, value)
    if not ok then
        VavaHealth.log.warn('santé du personnage #%d non écrite : %s', entry.characterId, tostring(err))
        entry.dirty = true
        return
    end
    entry.saved = value
end

--- Fenêtre d'application d'un ordre de vie envoyé maintenant à ce joueur.
---@param src integer
---@param entry vAvA.HealthEntry
---@param now integer
local function openWindow(src, entry, now)
    local until_ = sync.window(now, syncCfg.applyMs, GetPlayerPing(src) or 0, syncCfg.maxPingMs)
    if until_ > (entry.syncUntil or 0) then entry.syncUntil = until_ end
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

-- Envoi groupé de la vie -------------------------------------------------------------------------------------------

--- Prévoit l'envoi de la vie au joueur en fin de tour : un seul envoi par joueur et par tour, avec la valeur relue au
--- moment de l'envoi (plusieurs coups dans le même tour ne coûtent qu'un message).
---@param src integer
---@param entry vAvA.HealthEntry
local function schedulePush(src, entry)
    if entry.pushPending then return end
    entry.pushPending = true
    SetTimeout(0, function()
        entry.pushPending = false
        -- parti, remplacé ou à terre entre-temps (l'ordre DOWN a suivi) : rien à envoyer
        if entries[src] ~= entry or entry.downed then return end
        openWindow(src, entry, GetGameTimer())
        VavaHealth.send(src, EVENTS.SET, entry.health)
    end)
end

--- Retire une part de vie à la valeur du serveur. Une perte de toute la vie restante (à l'arrondi près) donne 0.
--- `push` : l'ordre de vie part en fin de tour (coup de la chaîne) ; sans, le ped l'a déjà (perte native).
---@param src integer
---@param part number
---@param push boolean|nil
---@return number|nil health  vie après la perte, ou nil sans personnage suivi
function life.applyLoss(src, part, push)
    local entry = entries[src]
    if not entry then return nil end
    local left = entry.health - part
    if left < EPSILON then left = 0 end
    entry.health, entry.dirty = left, true
    if push then
        -- le ped garde l'ancienne vie jusqu'à l'application : pas de correction en attendant
        openWindow(src, entry, GetGameTimer())
        schedulePush(src, entry)
    end
    return left
end

-- Transitions ------------------------------------------------------------------------------------------------

--- Met un joueur à terre. `reason` : death (ped lu au seuil ou sous lui), hit (vie du serveur vidée par la chaîne) ou
--- api (décision d'un module). Le client couche toujours son ped (vie GTA à 0) : une vie lue exactement au seuil peut
--- être celle d'un ped que GTA laisse debout.
---@param src integer
---@param reason string
---@param cause? integer|string
---@param killer? integer
---@param extra? { origin: string|nil, hitId: integer|nil }
---@return boolean ok
---@return string|nil code
function life.down(src, reason, cause, killer, extra)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if entry.downed then return false, 'already_downed' end
    local now = GetGameTimer()
    entry.downed, entry.downedFor, entry.health, entry.reported = true, 0, 0, false
    entry.sampledAt, entry.resentAt, entry.graceUntil = now, now, now + cfg.graceMs
    persist(entry)
    assist().cancelFor(src)
    VavaHealth.send(src, EVENTS.DOWN)
    VavaHealth.core.hooks.runAfter(HOOKS.DOWNED, {
        source = src, characterId = entry.characterId, reason = reason, cause = cause, killer = killer,
        origin = extra and extra.origin, hitId = extra and extra.hitId,
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
    openWindow(src, entry, now)
    VavaHealth.send(src, EVENTS.REVIVE, health)
    VavaHealth.core.hooks.runAfter(HOOKS.REVIVED, {
        source = src, characterId = entry.characterId, reason = reason, by = by,
    })
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
    local now = GetGameTimer()
    entry.downed, entry.downedFor, entry.health = false, 0, health
    -- le ped redevient lisible à la confirmation de l'apparition (ou d'office, porte d'apparition)
    entry.spawned, entry.spawnOrderedAt = false, now
    persist(entry)
    assist().cancelFor(src)
    openWindow(src, entry, now)
    -- avant l'ordre d'apparition (même canal, même ordre) : le client ne recouche pas son ped à l'arrivée
    VavaHealth.send(src, EVENTS.RESPAWN, health)
    local ok, err = VavaHealth.core.characters.spawn(src, point)
    if not ok then VavaHealth.log.warn('retour au lieu de soins du joueur %d impossible : %s', src, tostring(err)) end
    VavaHealth.send(src, EVENTS.MESSAGE, 'respawned')
    VavaHealth.core.hooks.runAfter(HOOKS.RESPAWNED, {
        source = src, characterId = entry.characterId, reason = reason,
        point = { x = point.x, y = point.y, z = point.z },
    })
    return true
end

--- Fixe la vie d'un joueur debout (0 à 1), sans condition d'apparition. À 0, il est mis à terre aussitôt (`api`).
---@param src integer
---@param health number
---@return boolean ok
---@return string|nil code
function life.setHealth(src, health)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if entry.downed then return false, 'downed' end
    local value = state.ratio(health)
    if value <= 0 then return life.down(src, 'api', 'set') end
    local now = GetGameTimer()
    entry.health, entry.sampledAt = value, now
    persist(entry)
    openWindow(src, entry, now)
    VavaHealth.send(src, EVENTS.SET, entry.health)
    return true
end

--- Ajoute (ou retire) de la vie à partir de la valeur du serveur (soins ; ce n'est pas un dégât).
---@param src integer
---@param delta number
---@return boolean ok
---@return string|nil code
function life.adjust(src, delta)
    local entry = entries[src]
    if not entry then return false, 'no_character' end
    if entry.downed then return false, 'downed' end
    return life.setHealth(src, entry.health + delta)
end

-- Pertes natives ---------------------------------------------------------------------------------------------------

--- Hook after d'une perte native, et journal pour une mise à terre.
---@param src integer
---@param entry vAvA.HealthEntry
---@param id integer
---@param points number
---@param downed boolean
local function reportNative(src, entry, id, points, downed)
    local tags = { native = true }
    VavaHealth.core.hooks.runAfter(HOOKS.HIT, {
        id = id, target = src, targetCharacter = entry.characterId, origin = VavaHealth.resource, kind = NATIVE_KIND,
        tags = tags, base = points, amount = points, applied = points, blocked = 0, absorbed = 0, resisted = 0,
        added = 0, downed = downed, health = currentHealth(src, entry),
    })
    if downed then
        journal.add({
            targetCharacter = entry.characterId, origin = VavaHealth.resource, kind = NATIVE_KIND, amount = points,
            applied = points, blocked = 0, absorbed = 0, resisted = 0, downed = true, position = positionOf(src),
        })
    end
end

--- Perte native lue sur le ped (chute, noyade…) : appliquée telle quelle, sans modificateurs (le jeu l'a déjà faite).
---@param src integer
---@param entry vAvA.HealthEntry
---@param part number
local function nativeLoss(src, entry, part)
    local points = min(part, entry.health) * HEALTH_POINTS
    life.applyLoss(src, part, false)
    reportNative(src, entry, VavaHealth.nextHitId(), points, false)
end

--- Mise à terre native (ped lu au seuil ou dessous) : toute la vie restante perdue, mise à terre `death`.
---@param src integer
---@param entry vAvA.HealthEntry
---@param ped integer
local function nativeFall(src, entry, ped)
    local points = entry.health * HEALTH_POINTS
    local id = VavaHealth.nextHitId()
    local killer = killerOf(src, ped)
    if killer then
        VavaHealth.log.warn('joueur %d mis à terre par un coup natif du joueur %d (hors chaîne)', src, killer)
    end
    life.applyLoss(src, entry.health, false)
    life.down(src, 'death', GetPedCauseOfDeath(ped), killer, { origin = VavaHealth.resource, hitId = id })
    reportNative(src, entry, id, points, true)
end

--- Ped au-dessus de la valeur du serveur : la valeur est renvoyée (au plus toutes les `sync.resendMs`).
---@param src integer
---@param entry vAvA.HealthEntry
---@param now integer
local function correct(src, entry, now)
    if entry.correctedAt and now - entry.correctedAt < syncCfg.resendMs then return end
    entry.correctedAt = now
    entry.corrections = entry.corrections + 1
    if entry.corrections == 1 or entry.corrections % syncCfg.logEvery == 0 then
        VavaHealth.log.warn('joueur %d : vie du client au-dessus de celle du serveur (%d fois), remise', src,
            entry.corrections)
    end
    openWindow(src, entry, now)
    VavaHealth.send(src, EVENTS.SET, entry.health)
end

-- Boucle ------------------------------------------------------------------------------------------------------

---@param src integer
---@return integer|nil ped
local function readablePed(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

---@param src integer
---@param entry vAvA.HealthEntry
---@param now integer
local function confirmSpawn(src, entry, now)
    local gate = sync.spawnGate(entry, now, readablePed(src) ~= nil, cfg.spawn.confirmTimeoutMs)
    if gate ~= 'forced' then return end
    entry.spawned, entry.graceUntil, entry.sampledAt = true, now + cfg.graceMs, now
    if not entry.forcedSpawn then
        entry.forcedSpawn = true
        VavaHealth.log.warn('joueur %d : apparition non confirmée après %d s, vie lue d\'office', src,
            cfg.spawn.confirmTimeoutMs // 1000)
    end
end

---@param src integer
---@param entry vAvA.HealthEntry
---@param now integer
---@param elapsed integer
local function check(src, entry, now, elapsed)
    if not entry.spawned then
        confirmSpawn(src, entry, now)
        if not entry.spawned then return end
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

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
        -- un ped couché par le client lit 0 : au seuil ou au-dessus, il n'a pas été couché (le seuil compris, puisque
        -- GTA peut y laisser un ped debout)
        if now >= entry.graceUntil and not vitality.laidDown(GetEntityHealth(ped), DOWN)
            and now - entry.resentAt >= cfg.downed.resendMs then
            entry.resentAt = now
            -- remis à terre à chaque fois, journalisé une seule fois par mise à terre
            if not entry.reported then
                entry.reported = true
                VavaHealth.log.warn('joueur %d debout sans avoir été relevé : remis à terre', src)
            end
            VavaHealth.send(src, EVENTS.DOWN)
        end
        return
    end

    if now >= entry.graceUntil then
        if vitality.fallen(GetEntityHealth(ped), DOWN) then
            nativeFall(src, entry, ped)
            return
        end
        local verdict, gap = sync.judge(ratioOf(ped), entry.health, now, entry.syncUntil, syncCfg.tolerance)
        if verdict == 'loss' then
            nativeLoss(src, entry, gap)
        elseif verdict == 'above' then
            correct(src, entry, now)
        end
    end
    -- un hook a pu céder la main : l'entrée a pu partir
    if entries[src] == entry and entry.dirty and now - entry.sampledAt >= cfg.sampleMs then
        entry.sampledAt = now
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
life.tick = tick

-- Suivi des personnages -------------------------------------------------------------------------------------------

---@param src integer
---@param characterId integer
function life.track(src, characterId)
    local saved = state.read(characterId)
    local now = GetGameTimer()
    entries[src] = {
        characterId = characterId, spawned = false, graceUntil = huge,
        health = saved.health, downed = saved.downed, downedFor = saved.downedFor,
        sampledAt = now, resentAt = 0, saved = saved,
        -- le core ordonne l'apparition juste après le chargement
        syncUntil = 0, pushPending = false, dirty = false, correctedAt = nil, corrections = 0,
        spawnOrderedAt = now, forcedSpawn = false,
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
life.onSpawned = onSpawned

--- Départ du personnage (déconnexion comprise). Si le ped est encore lisible (et la lecture fiable), il est relu avec
--- la règle de la boucle : un coup mortel reçu depuis la dernière lecture met à terre ; une perte native est gardée ;
--- jamais une hausse. Puis la valeur du serveur est écrite.
---@param src integer
local function onUnloading(src)
    local entry = entries[src]
    if not entry then return end
    local now = GetGameTimer()
    local ped = entry.spawned and not entry.downed and now >= entry.graceUntil and readablePed(src)
    if ped then
        if vitality.fallen(GetEntityHealth(ped), DOWN) then
            nativeFall(src, entry, ped)
        else
            local verdict, gap = sync.judge(ratioOf(ped), entry.health, now, entry.syncUntil, syncCfg.tolerance)
            if verdict == 'loss' then nativeLoss(src, entry, gap) end
        end
    end
    persist(entry)
    assist().cancelFor(src)
    entries[src] = nil
end

--- Écrit la vie de chaque personnage suivi (arrêt du module : l'API reste servie en `stopping`).
function life.persistAll()
    for _, entry in pairs(entries) do persist(entry) end
end

--- Reprend les personnages déjà joués (module redémarré en cours de partie). Bloque le thread courant.
function life.adoptActive()
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local character = src and VavaHealth.core.characters.getActive(src)
        if character and not entries[src] then
            life.track(src, character.id)
            -- déjà en jeu : le ped est lisible, après le délai habituel
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
