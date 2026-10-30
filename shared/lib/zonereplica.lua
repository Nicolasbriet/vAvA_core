--[[
    shared/lib/zonereplica.lua
    Rôle : réplique d'une zone côté client (logique pure) : règles de révision. Un instantané remplace l'état ; une
           différence s'applique si elle porte la révision attendue (+ 1), est ignorée si elle est ancienne, gardée si
           elle arrive trop tôt (instantané attendu, ou trou : l'instantané est alors redemandé). Tampon borné : au-delà,
           les différences sont perdues et l'instantané suivant est redemandé. Aucune révision passée n'est gardée.
    Résultats : 'ready', 'applied', 'buffered', 'awaiting', 'ignored', 'resync'.
    Dépendances : shared/init.lua
]]

local setmetatable, next, type, rawlen = setmetatable, next, type, rawlen

local zonereplica = {}
vAvA.lib.zonereplica = zonereplica

---@class vAvA.ZoneReplica
---@field revision integer|nil   nil avant le premier instantané
---@field state table|nil
---@field buffer table<integer, { set: table|nil, removed: table|nil }>  révision → différence gardée
---@field buffered integer
---@field maxBuffered integer
---@field awaiting boolean      instantané attendu (préavis reçu, trou, tampon débordé)
---@field overflow boolean      des différences n'ont pas pu être gardées
local Replica = {}
Replica.__index = Replica

--- Nouvelle réplique vide.
---@param maxBuffered integer  différences gardées en attendant un instantané
---@return vAvA.ZoneReplica
function zonereplica.new(maxBuffered)
    return setmetatable({
        revision = nil, state = nil, buffer = {}, buffered = 0, maxBuffered = maxBuffered,
        awaiting = false, overflow = false,
    }, Replica)
end

--- Applique une différence à l'état.
---@param state table
---@param set table|nil
---@param removed table|nil
local function apply(state, set, removed)
    if set then
        for key, value in next, set do state[key] = value end
    end
    if removed then
        for i = 1, rawlen(removed) do
            local key = removed[i]
            if key ~= nil then state[key] = nil end
        end
    end
end

---@param self vAvA.ZoneReplica
---@param revision integer
---@param set table|nil
---@param removed table|nil
local function keep(self, revision, set, removed)
    if self.buffer[revision] then return end
    if self.buffered >= self.maxBuffered then
        self.overflow = true
        return
    end
    self.buffer[revision] = { set = set, removed = removed }
    self.buffered = self.buffered + 1
end

--- Instantané reçu (état complet à cette révision).
---@param revision integer
---@param state table
---@return string result  'ignored' | 'ready' | 'resync'
function Replica:snapshot(revision, state)
    if self.revision and revision < self.revision then return 'ignored' end
    self.state, self.revision = state, revision
    -- différences gardées : les anciennes jetées, les suivantes appliquées dans l'ordre
    local buffer = self.buffer
    for kept in next, buffer do
        if kept <= revision then
            buffer[kept] = nil
            self.buffered = self.buffered - 1
        end
    end
    local nextRevision = revision + 1
    local diff = buffer[nextRevision]
    while diff do
        apply(state, diff.set, diff.removed)
        buffer[nextRevision] = nil
        self.buffered = self.buffered - 1
        self.revision = nextRevision
        nextRevision = nextRevision + 1
        diff = buffer[nextRevision]
    end
    local overflow = self.overflow
    self.overflow = false
    if overflow or self.buffered > 0 then
        self.awaiting = true
        return 'resync'
    end
    self.awaiting = false
    return 'ready'
end

--- Différence reçue.
---@param revision integer
---@param set table|nil
---@param removed table|nil
---@return string result  'ignored' | 'applied' | 'buffered' | 'resync'
function Replica:diff(revision, set, removed)
    local current = self.revision
    if current and revision <= current then return 'ignored' end
    if self.awaiting then
        keep(self, revision, set, removed)
        return 'buffered'
    end
    if current and revision == current + 1 then
        apply(self.state, set, removed)
        self.revision = revision
        return 'applied'
    end
    -- trou (ou aucune base connue) : gardée, instantané redemandé
    keep(self, revision, set, removed)
    self.awaiting = true
    return 'resync'
end

--- Préavis d'un instantané envoyé en latent : les différences qui arriveront avant lui sont gardées.
---@param revision integer
---@return string result  'awaiting' | 'ignored'
function Replica:notice(revision)
    if self.revision == nil or revision > self.revision then
        self.awaiting = true
        return 'awaiting'
    end
    return 'ignored'
end

--- Vrai si la réplique a un état à jour (instantané reçu, rien d'attendu).
---@return boolean
function Replica:isReady()
    return self.revision ~= nil and not self.awaiting
end

--- Valeur de type attendue pour une liste de clés retirées (aide aux vérifications du service client).
---@param value any
---@return boolean
function zonereplica.isKeyList(value)
    if type(value) ~= 'table' then return false end
    local length = rawlen(value)
    local count = 0
    for key, item in next, value do
        count = count + 1
        if type(key) ~= 'number' or key < 1 or key > length or type(item) ~= 'string' then return false end
    end
    return count == length
end
