--[[
    server/core/netstats.lua
    Rôle : compteur pur des envois serveur → client, sur une fenêtre glissante d'une minute (cases de bucketMs) :
           par couple (ressource, évènement), et pour **chaque joueur** son total et son détail par évènement (depuis
           0.12.0 : plus de suivi à lancer). Le temps est passé en argument (testable hors jeu) ; mémoire bornée
           (maxKeys couples en tout ; playerKeys évènements par joueur, les plus lourds, le reste sous <autres>),
           ménage des clés sans envoi depuis une fenêtre, joueur oublié à sa sortie.
    Dépendances : shared/init.lua
]]

local type, pairs, next, setmetatable = type, pairs, next, setmetatable
local max, floor, huge = math.max, math.floor, math.huge
local format, gsub = string.format, string.gsub
local sort, unpack = table.sort, table.unpack

local netstats = {}
vAvA.netstats = netstats

-- Cumul des clés au-delà des bornes : '<' et '*' sont hors du motif des ressources et des identifiants.
local OTHER_RESOURCE = '*'
local OTHER_LABEL = '<autres>'
netstats.OTHER_RESOURCE, netstats.OTHER_LABEL = OTHER_RESOURCE, OTHER_LABEL

---@class vAvA.NetCounterConfig
---@field bucketMs integer
---@field buckets integer
---@field maxKeys integer      couples (ressource, évènement) comptés en tout
---@field playerKeys integer   évènements détaillés par joueur

-- Un anneau est une seule table plate (moins de mémoire que cinq tables) : pour la case n (1 à buckets), aux indices
-- (n - 1) * FIELDS + 1 à + 5 : numéro de la tranche qui l'a remplie (STAMP, -1 : vide), messages, octets, latents, plus
-- gros message. `last` : dernière tranche qui a reçu un envoi.
local FIELDS = 5
local STAMP, MESSAGES, BYTES, LATENT, LARGEST = 1, 2, 3, 4, 5
local EMPTY = -1

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
        -- joueur → { total = anneau, keys = ressource → évènement → anneau, keyCount, light* (plus léger, en cache) }
        players = {},
    }, Counter)
end

-- Modèles d'anneau vide, un par nombre de cases, préparés une fois : un anneau neuf se construit en une seule
-- allocation, à sa taille exacte (sans les agrandissements successifs d'une boucle).
---@type table<integer, number[]>
local templates = {}

---@param buckets integer
---@return number[]
local function templateOf(buckets)
    local template = templates[buckets]
    if template then return template end
    template = {}
    for base = 0, (buckets - 1) * FIELDS, FIELDS do
        template[base + STAMP], template[base + MESSAGES], template[base + BYTES], template[base + LATENT],
            template[base + LARGEST] = EMPTY, 0, 0, 0, 0
    end
    templates[buckets] = template
    return template
end

---@param buckets integer
---@return table ring
local function newRing(buckets)
    local template = templateOf(buckets)
    return { last = -huge, unpack(template, 1, #template) }
end

--- Remet un anneau à vide, sur place (anneau d'un évènement écarté, rattaché au nouvel évènement).
local function clearRing(ring, buckets)
    for base = 0, (buckets - 1) * FIELDS, FIELDS do
        ring[base + STAMP], ring[base + MESSAGES], ring[base + BYTES], ring[base + LATENT], ring[base + LARGEST] =
            EMPTY, 0, 0, 0, 0
    end
    ring.last = -huge
end

---@param ring table
---@param index integer  numéro de tranche
---@param base integer   début de la case dans l'anneau (0, FIELDS, 2 × FIELDS…)
---@param messages integer
---@param bytes integer
---@param latent integer
---@param size integer   taille d'un message
local function add(ring, index, base, messages, bytes, latent, size)
    if ring[base + STAMP] ~= index then
        -- case réutilisée après un tour : ce qu'elle tenait est sorti de la fenêtre
        ring[base + STAMP], ring[base + MESSAGES], ring[base + BYTES], ring[base + LATENT], ring[base + LARGEST] =
            index, 0, 0, 0, 0
    end
    ring[base + MESSAGES] = ring[base + MESSAGES] + messages
    ring[base + BYTES] = ring[base + BYTES] + bytes
    ring[base + LATENT] = ring[base + LATENT] + latent
    if size > ring[base + LARGEST] then ring[base + LARGEST] = size end
    ring.last = index
end

--- Somme d'un anneau sur la fenêtre qui finit à la tranche `index`.
---@return integer messages
---@return integer bytes
---@return integer latent
---@return integer largest
local function sum(ring, index, buckets)
    local oldest = index - buckets
    if ring.last <= oldest then return 0, 0, 0, 0 end
    local messages, bytes, latent, largest = 0, 0, 0, 0
    for base = 0, (buckets - 1) * FIELDS, FIELDS do
        local stamp = ring[base + STAMP]
        if stamp > oldest and stamp <= index then
            messages = messages + ring[base + MESSAGES]
            bytes = bytes + ring[base + BYTES]
            latent = latent + ring[base + LATENT]
            largest = max(largest, ring[base + LARGEST])
        end
    end
    return messages, bytes, latent, largest
end

--- Octets d'un anneau sur la fenêtre (choix du plus léger).
local function bytesOf(ring, index, buckets)
    local oldest = index - buckets
    if ring.last <= oldest then return 0 end
    local bytes = 0
    for base = 0, (buckets - 1) * FIELDS, FIELDS do
        local stamp = ring[base + STAMP]
        if stamp > oldest and stamp <= index then bytes = bytes + ring[base + BYTES] end
    end
    return bytes
end

--- Verse les cases encore dans la fenêtre de `from` dans `into` (évènement évincé vers <autres>).
local function merge(into, from, index, buckets)
    local oldest = index - buckets
    for base = 0, (buckets - 1) * FIELDS, FIELDS do
        local stamp = from[base + STAMP]
        if stamp > oldest and stamp <= index then
            -- une même case ne peut tenir qu'une tranche de la fenêtre : différente, celle de `into` est sortie
            if into[base + STAMP] ~= stamp then
                into[base + STAMP], into[base + MESSAGES], into[base + BYTES], into[base + LATENT], into[base + LARGEST] =
                    stamp, 0, 0, 0, 0
            end
            into[base + MESSAGES] = into[base + MESSAGES] + from[base + MESSAGES]
            into[base + BYTES] = into[base + BYTES] + from[base + BYTES]
            into[base + LATENT] = into[base + LATENT] + from[base + LATENT]
            if from[base + LARGEST] > into[base + LARGEST] then into[base + LARGEST] = from[base + LARGEST] end
        end
    end
    if from.last > into.last then into.last = from.last end
end

--- Anneau de (*, <autres>) d'une table de clés (ne compte pas dans la borne).
local function otherOf(holder, buckets)
    local byLabel = holder.keys[OTHER_RESOURCE]
    local ring = byLabel and byLabel[OTHER_LABEL]
    if ring then return ring end
    if not byLabel then
        byLabel = {}
        holder.keys[OTHER_RESOURCE] = byLabel
    end
    ring = newRing(buckets)
    byLabel[OTHER_LABEL] = ring
    return ring
end

---@param holder table  { keys, keyCount }
---@param resource string
---@param label string
---@param buckets integer
---@return table ring
local function addKey(holder, resource, label, buckets)
    local byLabel = holder.keys[resource]
    if not byLabel then
        byLabel = {}
        holder.keys[resource] = byLabel
    end
    local ring = newRing(buckets)
    byLabel[label] = ring
    holder.keyCount = holder.keyCount + 1
    return ring
end

--- Anneau d'un couple (ressource, évènement) du compteur général : au-delà de maxKeys clés, (*, <autres>).
local function globalRing(self, resource, label)
    local byLabel = self.keys[resource]
    local ring = byLabel and byLabel[label]
    if ring then return ring end
    if self.keyCount >= self.cfg.maxKeys then return otherOf(self, self.cfg.buckets) end
    return addKey(self, resource, label, self.cfg.buckets)
end

--- Évènement le plus léger d'un joueur sur la fenêtre (gardé en cache le temps d'une case).
local function findLightest(entry, index, buckets)
    local lightBytes, lightResource, lightLabel, lightRing = huge, nil, nil, nil
    for resource, byLabel in pairs(entry.keys) do
        if resource ~= OTHER_RESOURCE then
            for label, ring in pairs(byLabel) do
                local bytes = bytesOf(ring, index, buckets)
                if bytes < lightBytes then lightBytes, lightResource, lightLabel, lightRing = bytes, resource, label, ring end
                if bytes == 0 then break end
            end
            -- rien de plus léger qu'un évènement muet sur la fenêtre
            if lightBytes == 0 then break end
        end
    end
    entry.lightIndex, entry.lightBytes, entry.lightResource, entry.lightLabel, entry.lightRing =
        index, lightBytes, lightResource, lightLabel, lightRing
end

--- Anneau d'un évènement dans le détail d'un joueur. Au-delà de playerKeys évènements, un nouveau message plus gros
--- que tout ce qu'a envoyé l'évènement le plus léger du joueur sur la fenêtre prend sa place (le plus léger rejoint
--- <autres>) ; sinon il part dans <autres>. Ainsi restent, à peu près, les évènements les plus lourds de chacun.
--- Le plus léger est gardé en cache le temps d'une case. Dans une même case, les poids ne font que croître : un
--- message qui ne dépasse pas le poids gardé part sans autre calcul dans <autres> ; s'il le dépasse, le poids du plus
--- léger est relu avant d'écarter, et s'il a changé (il a reçu depuis), le plus léger est recherché de nouveau : un
--- évènement devenu lourd n'est jamais écarté sur un poids périmé. L'anneau écarté, vidé sur place, sert au nouvel
--- évènement : un remplacement n'alloue rien.
local function playerRing(self, entry, resource, label, size, index)
    local byLabel = entry.keys[resource]
    local ring = byLabel and byLabel[label]
    if ring then return ring end
    local buckets = self.cfg.buckets
    if entry.keyCount < self.cfg.playerKeys then return addKey(entry, resource, label, buckets) end
    if entry.lightIndex ~= index or not entry.lightRing then
        findLightest(entry, index, buckets)
    end
    if not entry.lightResource or size <= entry.lightBytes then return otherOf(entry, buckets) end
    if bytesOf(entry.lightRing, index, buckets) ~= entry.lightBytes then
        findLightest(entry, index, buckets)
        if not entry.lightResource or size <= entry.lightBytes then return otherOf(entry, buckets) end
    end
    local lightResource = entry.lightResource
    local lightKeys, light = entry.keys[lightResource], entry.lightRing
    merge(otherOf(entry, buckets), light, index, buckets)
    lightKeys[entry.lightLabel] = nil
    if next(lightKeys) == nil then entry.keys[lightResource] = nil end
    entry.lightIndex, entry.lightRing = nil, nil
    clearRing(light, buckets)
    -- relu : la table de la ressource a pu être retirée avec le plus léger (même ressource, dernier évènement)
    byLabel = entry.keys[resource]
    if not byLabel then
        byLabel = {}
        entry.keys[resource] = byLabel
    end
    byLabel[label] = light
    return light
end

---@param self vAvA.NetCounter
---@param now integer
---@return integer index
---@return integer base  début de la case dans un anneau
local function position(self, now)
    local index = now // self.cfg.bucketMs
    return index, (index % self.cfg.buckets) * FIELDS
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
    local index, base = position(self, now)
    local latentCount = latent and 1 or 0
    add(globalRing(self, resource, label), index, base, count, size * count, latentCount * count, size)
    local players, buckets = self.players, self.cfg.buckets
    for i = 1, count do
        local src = single and targets or targets[i]
        local entry = players[src]
        if not entry then
            entry = { total = newRing(buckets), keys = {}, keyCount = 0 }
            players[src] = entry
        end
        add(entry.total, index, base, 1, size, latentCount, size)
        add(playerRing(self, entry, resource, label, size, index), index, base, 1, size, latentCount, size)
    end
end

--- Oublie tout d'un joueur (départ : son numéro peut être redonné).
---@param src integer
function Counter:forget(src)
    self.players[src] = nil
end

--- Retire d'une table de clés les anneaux sans envoi depuis une fenêtre.
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

--- Ménage : clés, et joueurs sans envoi depuis une fenêtre (un joueur encore là revient au premier envoi).
---@param now integer
function Counter:sweep(now)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    sweepKeys(self, index, buckets)
    for src, entry in pairs(self.players) do
        if entry.total.last <= index - buckets then
            self.players[src] = nil
        else
            sweepKeys(entry, index, buckets)
            entry.lightIndex = nil
        end
    end
end

--- Ordre d'affichage : octets décroissants, puis messages, puis ressource et évènement (déterministe).
local function before(a, b)
    if a.bytes ~= b.bytes then return a.bytes > b.bytes end
    if a.messages ~= b.messages then return a.messages > b.messages end
    if a.resource ~= b.resource then return a.resource < b.resource end
    return a.label < b.label
end

--- Évènements d'une table de clés sur la fenêtre, triés, filtrés par ressource, et leur total.
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

--- Total de tous les envois sur la fenêtre, sommé sans construire de liste ni trier (liste des joueurs : seul le
--- total du royaume est rendu avec elle).
---@param now integer
---@return table  { messages, bytes, latent }
function Counter:total(now)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    local messages, bytes, latent = 0, 0, 0
    for _, byLabel in pairs(self.keys) do
        for _, ring in pairs(byLabel) do
            local m, b, l = sum(ring, index, buckets)
            messages, bytes, latent = messages + m, bytes + b, latent + l
        end
    end
    return { messages = messages, bytes = bytes, latent = latent }
end

--- Lecture de la fenêtre qui finit à `now`.
--- Sans target : total des envois (de la ressource si elle est filtrée), évènements les plus lourds.
--- Avec target : total du joueur et ses évènements les plus lourds (filtrés par ressource si elle est donnée).
---@param now integer
---@param options vAvA.NetReadOptions
---@return table
function Counter:read(now, options)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    local result = { windowMs = self.cfg.bucketMs * buckets }
    local events, total
    if options.target then
        local entry = self.players[options.target]
        local messages, bytes, latent = 0, 0, 0
        if entry then
            messages, bytes, latent = sum(entry.total, index, buckets)
            events = collect(entry, index, buckets, options.resource)
        else
            events = {}
        end
        total = { messages = messages, bytes = bytes, latent = latent }
    else
        events, total = collect(self, index, buckets, options.resource)
    end
    for i = #events, options.limit + 1, -1 do events[i] = nil end
    result.total, result.events = total, events
    return result
end

--- Ordre des joueurs : octets décroissants, puis messages, puis numéro.
local function heavier(a, b)
    if a.bytes ~= b.bytes then return a.bytes > b.bytes end
    if a.messages ~= b.messages then return a.messages > b.messages end
    return a.source < b.source
end

--- Ce qu'a reçu chacun des joueurs donnés sur la fenêtre (0 pour qui n'a rien reçu), du plus chargé au moins chargé,
--- `limit` au plus : liste de { source, messages, bytes, latent }.
---@param now integer
---@param sources integer[]  joueurs connectés
---@param limit integer
---@return table[]
function Counter:listPlayers(now, sources, limit)
    local index = position(self, now)
    local buckets = self.cfg.buckets
    local list = {}
    for i = 1, #sources do
        local src = sources[i]
        local entry = self.players[src]
        local messages, bytes, latent = 0, 0, 0
        if entry then messages, bytes, latent = sum(entry.total, index, buckets) end
        list[i] = { source = src, messages = messages, bytes = bytes, latent = latent }
    end
    sort(list, heavier)
    for i = #list, limit + 1, -1 do list[i] = nil end
    return list
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
