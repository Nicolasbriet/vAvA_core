--[[
    server/core/zonestate.lua
    Rôle : état d'une zone (logique pure) : paires clé → valeur tenues par le core, révision, changements en attente du
           prochain envoi (regroupés : une clé changée puis retirée dans le même tour n'est que retirée, et l'inverse),
           tailles estimées (règles de netsize) tenues à jour, budget commun à toutes les zones. Chaque opération est
           tout ou rien : un seul élément refusé, rien n'est appliqué. Aucune native, aucun envoi.
    Codes : invalid_state, invalid_key, invalid_value, too_large, too_many_keys, full.
    Dépendances : shared/init.lua, server/core/netsize.lua
]]

local type, next, pairs, setmetatable, rawlen, rawget = type, next, pairs, setmetatable, rawlen, rawget
local mathType = math.type
local find, sort = string.find, table.sort

local netsize = vAvA.netsize

local zonestate = {}
vAvA.zonestate = zonestate

local KEY_PATTERN = '^[%w_%-%.:]+$'
-- en-tête d'une différence ou d'un instantané (numéro, révision, deux en-têtes de table) : estimation
local DIFF_OVERHEAD = 16

---@class vAvA.ZoneLimits
---@field maxKeys integer
---@field keyMaxLength integer
---@field maxChanges integer
---@field maxValueBytes integer
---@field maxStateBytes integer

---@class vAvA.ZoneBudget
---@field used integer  octets estimés de tous les états
---@field max integer

---@class vAvA.ZoneDiff
---@field revision integer
---@field set table<string, any>|nil
---@field removed string[]|nil
---@field bytes integer  taille estimée de la différence

---@class vAvA.ZoneState
---@field state table<string, any>   état (propre au core : jamais rendu à un module)
---@field sizes table<string, integer>  clé → octets estimés (clé + valeur)
---@field keys integer
---@field bytes integer
---@field revision integer
---@field changed table<string, true>   clés changées depuis le dernier envoi
---@field dropped table<string, true>   clés retirées depuis le dernier envoi
---@field limits vAvA.ZoneLimits
---@field budget vAvA.ZoneBudget
local State = {}
State.__index = State

--- Budget commun à toutes les zones.
---@param max integer  octets
---@return vAvA.ZoneBudget
function zonestate.budget(max)
    return { used = 0, max = max }
end

--- Nouvel état vide (révision 1).
---@param limits vAvA.ZoneLimits
---@param budget vAvA.ZoneBudget
---@return vAvA.ZoneState
function zonestate.new(limits, budget)
    return setmetatable({
        state = {}, sizes = {}, keys = 0, bytes = 0, revision = 1, changed = {}, dropped = {},
        limits = limits, budget = budget,
    }, State)
end

---@param limits vAvA.ZoneLimits
---@param key any
---@return boolean
local function validKey(limits, key)
    return type(key) == 'string' and #key > 0 and #key <= limits.keyMaxLength and find(key, KEY_PATTERN) ~= nil
end

--- Taille estimée d'une paire (clé + valeur), ou code.
---@param limits vAvA.ZoneLimits
---@param key string
---@param value any
---@return integer|nil bytes
---@return string|nil code
local function pairSize(limits, key, value)
    local size, err = netsize.value(limits.maxValueBytes, value)
    if not size then return nil, err == 'too_large' and 'too_large' or 'invalid_value' end
    return size + #key + 1
end

--- Vérifie un état complet : table à clés chaînes valides, valeurs sérialisables, bornes.
---@param limits vAvA.ZoneLimits
---@param state any
---@return integer|nil keys
---@return integer|string bytesOrCode
local function measureState(limits, state)
    if state == nil then return 0, 0 end
    if type(state) ~= 'table' then return nil, 'invalid_value' end
    local keys, bytes = 0, 0
    for key, value in next, state do
        if not validKey(limits, key) then return nil, 'invalid_key' end
        keys = keys + 1
        if keys > limits.maxKeys then return nil, 'too_many_keys' end
        local size, code = pairSize(limits, key, value)
        if not size then return nil, code end
        bytes = bytes + size
        if bytes > limits.maxStateBytes then return nil, 'too_large' end
    end
    return keys, bytes
end

--- Remplace l'état (vérifié par measureState) ; budget déjà contrôlé.
---@param self vAvA.ZoneState
---@param state table|nil
---@param keys integer
---@param bytes integer
local function adopt(self, state, keys, bytes)
    local sizes = {}
    local limits = self.limits
    local copy = {}
    if state then
        for key, value in next, state do
            copy[key] = value
            sizes[key] = pairSize(limits, key, value)
        end
    end
    self.budget.used = self.budget.used - self.bytes + bytes
    self.state, self.sizes, self.keys, self.bytes = copy, sizes, keys, bytes
    self.changed, self.dropped = {}, {}
end

--- État de départ (déclaration de la zone) : révision 1.
---@param state table|nil
---@return boolean ok
---@return string|nil code
function State:load(state)
    local keys, bytes = measureState(self.limits, state)
    if not keys then return false, bytes end
    if self.budget.used - self.bytes + bytes > self.budget.max then return false, 'full' end
    adopt(self, state, keys, bytes)
    self.revision = 1
    return true
end

--- Tout l'état remplacé : changements en attente oubliés, révision + 1.
---@param state table|nil
---@return boolean ok
---@return string|nil code
function State:replace(state)
    local keys, bytes = measureState(self.limits, state)
    if not keys then return false, bytes end
    if self.budget.used - self.bytes + bytes > self.budget.max then return false, 'full' end
    adopt(self, state, keys, bytes)
    self.revision = self.revision + 1
    return true
end

--- Vrai si `list` est une liste pure (clés 1..n exactement).
---@param list table
---@return boolean
local function isList(list)
    local length = rawlen(list)
    local count = 0
    for key in next, list do
        count = count + 1
        if mathType(key) ~= 'integer' or key < 1 or key > length then return false end
    end
    return count == length
end

--- Change des clés et en retire. Une valeur scalaire égale à l'actuelle n'est pas marquée changée ; une table l'est
--- toujours. Une même clé changée et retirée dans le même appel : invalid_key.
---@param changes table|nil  clé → nouvelle valeur
---@param removed string[]|nil
---@return boolean ok
---@return string|nil code
---@return boolean|nil pending  vrai si quelque chose est à envoyer
function State:set(changes, removed)
    local limits = self.limits
    if changes ~= nil and type(changes) ~= 'table' then return false, 'invalid_value' end
    if removed ~= nil and (type(removed) ~= 'table' or not isList(removed)) then return false, 'invalid_key' end
    local state, sizes = self.state, self.sizes
    local count, keys, bytes = 0, self.keys, self.bytes
    local newSizes = {}
    if changes then
        for key, value in next, changes do
            if not validKey(limits, key) then return false, 'invalid_key' end
            count = count + 1
            if count > limits.maxChanges then return false, 'too_many_keys' end
            local size, code = pairSize(limits, key, value)
            if not size then return false, code end
            newSizes[key] = size
            local old = sizes[key]
            if old then bytes = bytes - old else keys = keys + 1 end
            bytes = bytes + size
        end
    end
    local removedCount = removed and rawlen(removed) or 0
    -- une clé retirée deux fois dans la liste ne compte qu'une fois
    local seen = removedCount > 0 and {} or nil
    for i = 1, removedCount do
        local key = rawget(removed, i)
        if not validKey(limits, key) or newSizes[key] then return false, 'invalid_key' end
        count = count + 1
        if count > limits.maxChanges then return false, 'too_many_keys' end
        if not seen[key] then
            seen[key] = true
            local old = sizes[key]
            if old then
                bytes = bytes - old
                keys = keys - 1
            end
        end
    end
    if keys > limits.maxKeys then return false, 'too_many_keys' end
    if bytes > limits.maxStateBytes then return false, 'too_large' end
    local budget = self.budget
    if budget.used - self.bytes + bytes > budget.max then return false, 'full' end
    -- tout est accepté : application
    local pending = false
    local changed, dropped = self.changed, self.dropped
    if changes then
        for key, value in next, changes do
            local current = state[key]
            if type(value) == 'table' or current ~= value then
                state[key], sizes[key] = value, newSizes[key]
                changed[key], dropped[key] = true, nil
                pending = true
            end
        end
    end
    for i = 1, removedCount do
        local key = rawget(removed, i)
        if state[key] ~= nil then
            state[key], sizes[key] = nil, nil
            changed[key], dropped[key] = nil, true
            pending = true
        end
    end
    budget.used = budget.used - self.bytes + bytes
    self.keys, self.bytes = keys, bytes
    return true, nil, pending
end

--- Vrai si des changements attendent leur envoi.
---@return boolean
function State:hasPending()
    return next(self.changed) ~= nil or next(self.dropped) ~= nil
end

--- Changements en attente regroupés en une différence, révision + 1 ; nil s'il n'y a rien.
---@return vAvA.ZoneDiff|nil
function State:flush()
    local changed, dropped = self.changed, self.dropped
    if next(changed) == nil and next(dropped) == nil then return nil end
    local set, removed, bytes = nil, nil, DIFF_OVERHEAD
    local state, sizes = self.state, self.sizes
    for key in pairs(changed) do
        set = set or {}
        set[key] = state[key]
        bytes = bytes + sizes[key]
    end
    for key in pairs(dropped) do
        removed = removed or {}
        removed[#removed + 1] = key
        bytes = bytes + #key + 1
    end
    if removed then sort(removed) end
    self.changed, self.dropped = {}, {}
    self.revision = self.revision + 1
    return { revision = self.revision, set = set, removed = removed, bytes = bytes }
end

--- Taille estimée de l'instantané (état entier).
---@return integer
function State:snapshotBytes()
    return self.bytes + DIFF_OVERHEAD
end

--- Rend la place de l'état au budget commun (zone retirée).
function State:release()
    self.budget.used = self.budget.used - self.bytes
    self.state, self.sizes, self.keys, self.bytes = {}, {}, 0, 0
    self.changed, self.dropped = {}, {}
end
