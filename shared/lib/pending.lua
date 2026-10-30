--[[
    shared/lib/pending.lua
    Rôle : stockage des requêtes en attente de réponse (identifiant unique, timeout, résolution unique).
    Utilisé par le RPC client et serveur. Chaque entrée est retirée à sa résolution : aucune fuite possible.
    L'échéance d'une entrée peut être repoussée (extend) quand on sait que la réponse sera longue à arriver (envoi
    latent) : chaque minuterie porte le numéro de génération de l'échéance qu'elle garde, une minuterie dépassée ne
    résout rien.
    Dépendances : shared/init.lua (SetTimeout, GetGameTimer, promise et Citizen.Await sont fournis par le runtime FiveM)
]]

local setmetatable, pairs = setmetatable, pairs
local pack, unpack = table.pack, table.unpack
local SetTimeout, GetGameTimer = SetTimeout, GetGameTimer
local newPromise = promise.new
local await = Citizen.Await

local pending = {}
vAvA.lib.pending = pending

---@class vAvA.PendingEntry
---@field meta any            données de l'appelant (source ciblée, propriétaire…)
---@field promise table       résolue avec table.pack(ok, ...)
---@field deadline integer    échéance courante (GetGameTimer, ms)
---@field generation integer  numéro de l'échéance courante : seule la minuterie qui le porte peut résoudre

---@class vAvA.PendingStore
---@field entries table<integer, vAvA.PendingEntry>
---@field size integer
---@field lastId integer
---@field maxPending integer
---@field maxId integer
local Store = {}
Store.__index = Store

--- Crée un store. maxPending doit rester très inférieur à maxId pour qu'un identifiant libre soit trouvé immédiatement.
---@param maxPending integer
---@param maxId integer
---@return vAvA.PendingStore
function pending.create(maxPending, maxId)
    return setmetatable({ entries = {}, size = 0, lastId = 0, maxPending = maxPending, maxId = maxId }, Store)
end

---@param self vAvA.PendingStore
---@return integer
local function nextId(self)
    local entries, maxId, id = self.entries, self.maxId, self.lastId
    -- au plus maxPending identifiants occupés : la boucle s'arrête en au plus maxPending + 1 tours
    repeat
        id = id >= maxId and 1 or id + 1
    until entries[id] == nil
    self.lastId = id
    return id
end

--- Minuterie d'une échéance : résout (false, 'timeout') si l'entrée est toujours là et que son échéance n'a pas été
--- repoussée entre-temps.
---@param self vAvA.PendingStore
---@param id integer
---@param entry vAvA.PendingEntry
---@param ms integer
local function arm(self, id, entry, ms)
    local generation = entry.generation
    SetTimeout(ms, function()
        -- comparaison d'identité : un timer périmé ne résout jamais une requête qui a réutilisé le même id
        if self.entries[id] == entry and entry.generation == generation then
            self:settle(id, false, 'timeout')
        end
    end)
end

--- Enregistre une requête. Résolue automatiquement par (false, 'timeout') si personne ne répond à temps.
---@param meta any
---@param timeoutMs integer
---@return integer|nil id    nil si le store est plein
---@return vAvA.PendingEntry|nil entry
function Store:add(meta, timeoutMs)
    if self.size >= self.maxPending then return nil end
    local id = nextId(self)
    local entry = { meta = meta, promise = newPromise(), deadline = GetGameTimer() + timeoutMs, generation = 1 }
    self.entries[id] = entry
    self.size = self.size + 1
    arm(self, id, entry, timeoutMs)
    return id, entry
end

---@param id integer
---@return vAvA.PendingEntry|nil
function Store:get(id)
    return self.entries[id]
end

--- Repousse l'échéance d'une requête à maintenant + ms, si c'est plus tard que l'échéance actuelle (jamais plus tôt).
---@param id integer
---@param ms integer
---@return boolean found  false : requête inconnue (déjà résolue, ou jamais posée)
function Store:extend(id, ms)
    local entry = self.entries[id]
    if not entry then return false end
    local deadline = GetGameTimer() + ms
    if deadline > entry.deadline then
        entry.deadline = deadline
        entry.generation = entry.generation + 1
        arm(self, id, entry, ms)
    end
    return true
end

--- Résout une requête une seule fois et la retire. Les valeurs sont rendues telles quelles à l'appelant.
---@param id integer
---@return boolean settled
function Store:settle(id, ...)
    local entry = self.entries[id]
    if not entry then return false end
    self.entries[id] = nil
    self.size = self.size - 1
    entry.promise:resolve(pack(...))
    return true
end

--- Résout toutes les requêtes dont la méta satisfait le prédicat (déconnexion d'un joueur, arrêt d'une ressource).
---@param predicate fun(meta: any): boolean
---@return integer count
function Store:settleWhere(predicate, ...)
    local ids = {}
    for id, entry in pairs(self.entries) do
        if predicate(entry.meta) then ids[#ids + 1] = id end
    end
    for i = 1, #ids do
        self:settle(ids[i], ...)
    end
    return #ids
end

--- Attend la résolution d'une entrée et renvoie ses valeurs (ok, ...). À appeler depuis un thread.
---@param entry vAvA.PendingEntry
---@return boolean ok
---@return any ...
function pending.await(entry)
    local result = await(entry.promise)
    return unpack(result, 1, result.n)
end
