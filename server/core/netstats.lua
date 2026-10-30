--[[
    server/core/netstats.lua
    Rôle : compteur pur des envois serveur → client, sur une fenêtre glissante d'une minute (cases de bucketMs) :
           par couple (ressource, évènement), totaux par joueur, détail par évènement pour quelques joueurs suivis.
           Le temps est passé en argument (testable hors jeu) ; mémoire bornée (maxKeys, maxWatched, maxWatchedKeys),
           ménage des clés sans envoi depuis une fenêtre.
    Dépendances : shared/init.lua
]]

local type, pairs, setmetatable = type, pairs, setmetatable
local max, floor, huge = math.max, math.floor, math.huge
local format, gsub = string.format, string.gsub
local sort = table.sort

local netstats = {}
vAvA.netstats = netstats

-- Cumul des clés au-delà des bornes : '<' et '*' sont hors du motif des ressources et des identifiants.
local OTHER_RESOURCE = '*'
local OTHER_LABEL = '<autres>'
netstats.OTHER_RESOURCE, netstats.OTHER_LABEL = OTHER_RESOURCE, OTHER_LABEL

---@class vAvA.NetCounterConfig
---@field bucketMs integer
---@field buckets integer
---@field maxKeys integer
---@field maxWatched integer
---@field maxWatchedKeys integer
---@field watchMs integer

---@class vAvA.NetRing  une case par tranche de bucketMs ; stamp = numéro de la tranche qui l'a remplie
---@field stamp integer[]
---@field messages integer[]
---@field bytes integer[]
---@field latent integer[]
---@field largest integer[]
---@field last integer  dernière tranche qui a reçu un envoi

---@class vAvA.NetCounter
---@field cfg vAvA.NetCounterConfig
local Counter = {}
Counter.__index = Counter

---@param cfg vAvA.NetCounterConfig
---@return vAvA.NetCounter
function netstats.create(cfg)
    return setmetatable({
        cfg = cfg,
        keys = {},        -- ressource → évènement → anneau
        keyCount = 0,
        players = {},     -- joueur → anneau (tous évènements confondus)
        watched = {},     -- joueur → { untilMs, keys = ressource → évènement → anneau, keyCount }
        watchedCount = 0,
    }, Counter)
end

---@return vAvA.NetRing
local function newRing()
    return { stamp = {}, messages = {}, bytes = {}, latent = {}, largest = {}, last = -huge }
end

---@param ring vAvA.NetRing
---@param index integer  numéro de tranche
---@param slot integer   case de l'anneau
---@param messages integer
---@param bytes integer
---@param latent integer
---@param size integer   taille d'un message
local function add(ring, index, slot, messages, bytes, latent, size)
    if ring.stamp[slot] ~= index then
        -- case réutilisée après un tour : ce qu'elle tenait est sorti de la fenêtre
        ring.stamp[slot], ring.messages[slot], ring.bytes[slot], ring.latent[slot], ring.largest[slot] = index, 0, 0, 0, 0
    end
    ring.messages[slot] = ring.messages[slot] + messages
    ring.bytes[slot] = ring.bytes[slot] + bytes
    ring.latent[slot] = ring.latent[slot] + latent
    if size > ring.largest[slot] then ring.largest[slot] = size end
    ring.last = index
end

--- Somme d'un anneau sur la fenêtre qui finit à la tranche `index`.
---@param ring vAvA.NetRing
---@param index integer
---@param buckets integer
---@return integer messages
---@return integer bytes
---@return integer latent
---@return integer largest
local function sum(ring, index, buckets)
    local oldest = index - buckets
    if ring.last <= oldest then return 0, 0, 0, 0 end
    local messages, bytes, latent, largest = 0, 0, 0, 0
    for slot = 1, buckets do
        local stamp = ring.stamp[slot]
        if stamp and stamp > oldest and stamp <= index then
            messages = messages + ring.messages[slot]
            bytes = bytes + ring.bytes[slot]
            latent = latent + ring.latent[slot]
            largest = max(largest, ring.largest[slot])
        end
    end
    return messages, bytes, latent, largest
end

--- Anneau d'un couple (ressource, évènement) dans une table de clés ; au-delà de `limit` clés, celui de
--- (*, <autres>), qui ne compte pas dans la borne.
---@param holder table  { keys, keyCount }
---@param resource string
---@param label string
---@param limit integer
---@return vAvA.NetRing
local function ringOf(holder, resource, label, limit)
    local byLabel = holder.keys[resource]
    local ring = byLabel and byLabel[label]
    if ring then return ring end
    if holder.keyCount >= limit then
        resource, label = OTHER_RESOURCE, OTHER_LABEL
        byLabel = holder.keys[resource]
        ring = byLabel and byLabel[label]
        if ring then return ring end
    else
        holder.keyCount = holder.keyCount + 1
    end
    if not byLabel then
        byLabel = {}
        holder.keys[resource] = byLabel
    end
    ring = newRing()
    byLabel[label] = ring
    return ring
end

---@param self vAvA.NetCounter
---@param now integer
---@return integer index
---@return integer slot
local function position(self, now)
    local index = now // self.cfg.bucketMs
    return index, index % self.cfg.buckets + 1
end

--- Suivi en cours d'un joueur ; un suivi expiré est retiré au passage.
---@param self vAvA.NetCounter
---@param now integer
---@param src integer
---@return table|nil
local function activeWatch(self, now, src)
    local watch = self.watched[src]
    if not watch then return nil end
    if now >= watch.untilMs then
        self.watched[src] = nil
        self.watchedCount = self.watchedCount - 1
        return nil
    end
    return watch
end

--- Compte un message de `size` octets envoyé à chacune des cibles.
---@param now integer
---@param resource string
---@param label string
---@param size integer  octets d'un message
---@param latent boolean
---@param targets integer|integer[]  un joueur, ou une liste
---@param count? integer  nombre de cibles de la liste (défaut : #targets)
function Counter:record(now, resource, label, size, latent, targets, count)
    local single = type(targets) == 'number'
    if single then count = 1 elseif not count then count = #targets end
    if count <= 0 then return end
    local index, slot = position(self, now)
    local latentCount = latent and 1 or 0
    add(ringOf(self, resource, label, self.cfg.maxKeys), index, slot, count, size * count, latentCount * count, size)
    local players, watched = self.players, self.watched
    for i = 1, count do
        local src = single and targets or targets[i]
        local ring = players[src]
        if not ring then
            ring = newRing()
            players[src] = ring
        end
        add(ring, index, slot, 1, size, latentCount, size)
        if watched[src] then
            local watch = activeWatch(self, now, src)
            if watch then
                add(ringOf(watch, resource, label, self.cfg.maxWatchedKeys), index, slot, 1, size, latentCount, size)
            end
        end
    end
end

--- Commence le suivi d'un joueur (détail par évènement) pour watchMs.
---@param now integer
---@param src integer
---@return boolean ok
---@return string state  'started' | 'already' | 'full'
function Counter:watch(now, src)
    if activeWatch(self, now, src) then return true, 'already' end
    for other in pairs(self.watched) do activeWatch(self, now, other) end
    if self.watchedCount >= self.cfg.maxWatched then return false, 'full' end
    self.watched[src] = { untilMs = now + self.cfg.watchMs, keys = {}, keyCount = 0 }
    self.watchedCount = self.watchedCount + 1
    return true, 'started'
end

---@param now integer
---@param src integer
---@return boolean
function Counter:isWatched(now, src)
    return activeWatch(self, now, src) ~= nil
end

--- Oublie tout d'un joueur (départ : son numéro peut être redonné).
---@param src integer
function Counter:forget(src)
    self.players[src] = nil
    if self.watched[src] then
        self.watched[src] = nil
        self.watchedCount = self.watchedCount - 1
    end
end

--- Retire d'une table de clés les anneaux sans envoi depuis une fenêtre.
---@param holder table
---@param index integer
---@param buckets integer
local function sweepKeys(holder, index, buckets)
    for resource, byLabel in pairs(holder.keys) do
        local remaining = false
        for label, ring in pairs(byLabel) do
            if ring.last <= index - buckets then
                byLabel[label] = nil
                if resource ~= OTHER_RESOURCE or label ~= OTHER_LABEL then
                    holder.keyCount = holder.keyCount - 1
                end
            else
                remaining = true
            end
        end
        if not remaining then holder.keys[resource] = nil end
    end
end

--- Ménage : clés, totaux de joueurs et clés suivies sans envoi depuis une fenêtre, suivis expirés.
---@param now integer
function Counter:sweep(now)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    sweepKeys(self, index, buckets)
    for src, ring in pairs(self.players) do
        if ring.last <= index - buckets then self.players[src] = nil end
    end
    for src in pairs(self.watched) do
        local watch = activeWatch(self, now, src)
        if watch then sweepKeys(watch, index, buckets) end
    end
end

--- Ordre d'affichage : octets décroissants, puis messages, puis ressource et évènement (déterministe).
---@param a table
---@param b table
---@return boolean
local function before(a, b)
    if a.bytes ~= b.bytes then return a.bytes > b.bytes end
    if a.messages ~= b.messages then return a.messages > b.messages end
    if a.resource ~= b.resource then return a.resource < b.resource end
    return a.label < b.label
end

--- Évènements d'une table de clés sur la fenêtre, triés, filtrés par ressource, et leur total.
---@param holder table
---@param index integer
---@param buckets integer
---@param resource string|nil
---@return table[] events
---@return table total
local function collect(holder, index, buckets, resource)
    local events = {}
    local total = { messages = 0, bytes = 0, latent = 0 }
    for name, byLabel in pairs(holder.keys) do
        if resource == nil or name == resource then
            for label, ring in pairs(byLabel) do
                local messages, bytes, latent, largest = sum(ring, index, buckets)
                if messages > 0 then
                    events[#events + 1] = {
                        resource = name, label = label, messages = messages, bytes = bytes, latent = latent,
                        largest = largest,
                    }
                    total.messages = total.messages + messages
                    total.bytes = total.bytes + bytes
                    total.latent = total.latent + latent
                end
            end
        end
    end
    sort(events, before)
    return events, total
end

---@class vAvA.NetReadOptions
---@field limit integer         évènements rendus au plus
---@field resource? string      seulement cette ressource
---@field target? integer       ce que reçoit ce joueur

--- Lecture de la fenêtre qui finit à `now`.
--- Sans target : total des envois (de la ressource si elle est filtrée), évènements les plus lourds.
--- Avec target : total du joueur, watched, et ses évènements s'il est suivi (sinon une liste vide).
---@param now integer
---@param options vAvA.NetReadOptions
---@return table
function Counter:read(now, options)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    local result = { windowMs = self.cfg.bucketMs * buckets }
    local events, total
    if options.target then
        local ring = self.players[options.target]
        local messages, bytes, latent = 0, 0, 0
        if ring then messages, bytes, latent = sum(ring, index, buckets) end
        local watch = activeWatch(self, now, options.target)
        result.watched = watch ~= nil
        events = watch and collect(watch, index, buckets, options.resource) or {}
        total = { messages = messages, bytes = bytes, latent = latent }
    else
        events, total = collect(self, index, buckets, options.resource)
    end
    for i = #events, options.limit + 1, -1 do events[i] = nil end
    result.total, result.events = total, events
    return result
end

--- Taille lisible, à la française : « 512 o », « 12,5 Ko », « 1,25 Mo ».
---@param bytes number
---@return string
function netstats.formatBytes(bytes)
    local text
    if bytes < 1024 then
        text = format('%d o', floor(bytes))
    elseif bytes < 1048576 then
        text = format('%.1f Ko', bytes / 1024)
    else
        text = format('%.2f Mo', bytes / 1048576)
    end
    return (gsub(text, '%.', ','))
end
