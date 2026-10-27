--[[
    vava_health/server/assist.lua
    Rôle : relever une personne à terre. Le joueur exprime l'intention ; le serveur choisit la personne à terre la
           plus proche (positions lues côté serveur : rien n'est diffusé pour la repérer), demande l'accord des
           modules (hook vava_health:reviving), puis revérifie tout à la fin du geste : distance, états, objet requis.
           Un geste en cours s'annule si l'un des deux tombe, se déconnecte ou part.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/life.lua
]]

local ipairs, pairs, tonumber, tostring, pcall, type = ipairs, pairs, tonumber, tostring, pcall, type
local GetPlayers, GetPlayerPed, GetEntityCoords, GetResourceState = GetPlayers, GetPlayerPed, GetEntityCoords, GetResourceState
local TriggerClientEvent, SetTimeout = TriggerClientEvent, SetTimeout

local life = VavaHealth.life
local cfg = VavaHealth.config.assist
local EVENTS = VavaHealth.EVENTS
local HOOK_REVIVING = VavaHealth.HOOKS.REVIVING

local INVENTORY = 'vava_inventory'

local assist = {}
VavaHealth.assist = assist

---@class vAvA.AssistChannel
---@field helper integer
---@field patient integer

---@type table<integer, vAvA.AssistChannel>  relevant → geste
local byHelper = {}
---@type table<integer, vAvA.AssistChannel>  personne à terre → geste
local byPatient = {}

---@param a integer
---@param b integer
---@return number|nil
local function distance(a, b)
    local pedA, pedB = GetPlayerPed(a), GetPlayerPed(b)
    if pedA == 0 or pedB == 0 then return nil end
    local ca, cb = GetEntityCoords(pedA), GetEntityCoords(pedB)
    return ((ca.x - cb.x) ^ 2 + (ca.y - cb.y) ^ 2 + (ca.z - cb.z) ^ 2) ^ 0.5
end

---@param helper integer
---@return integer|nil patient
local function nearestDowned(helper)
    local best, bestDistance = nil, cfg.distance
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local entry = src and src ~= helper and life.entry(src)
        if entry and entry.downed and entry.spawned and not byPatient[src] then
            local d = distance(helper, src)
            if d and d <= bestDistance then best, bestDistance = src, d end
        end
    end
    return best
end

--- Appel isolé à l'inventaire (facultatif) pour l'objet requis.
---@return boolean
local function inventory(fn, ...)
    if GetResourceState(INVENTORY) ~= 'started' then return false end
    local called, result = pcall(function(...) return exports[INVENTORY][fn](exports[INVENTORY], ...) end, ...)
    if not called then
        VavaHealth.log.warn('%s.%s en erreur : %s', INVENTORY, fn, tostring(result))
        return false
    end
    return result
end

---@param channel vAvA.AssistChannel
---@param state string
local function tell(channel, state)
    TriggerClientEvent(EVENTS.CHANNEL, channel.helper, { role = 'helper', state = state })
    TriggerClientEvent(EVENTS.CHANNEL, channel.patient, { role = 'patient', state = state })
end

---@param channel vAvA.AssistChannel
local function close(channel)
    if byHelper[channel.helper] == channel then byHelper[channel.helper] = nil end
    if byPatient[channel.patient] == channel then byPatient[channel.patient] = nil end
end

--- Annule le geste auquel un joueur prend part (comme relevant ou comme personne à terre).
---@param src integer
function assist.cancelFor(src)
    local channel = byHelper[src] or byPatient[src]
    if not channel then return end
    close(channel)
    tell(channel, 'cancel')
end

---@param channel vAvA.AssistChannel
local function finish(channel)
    -- annulé ou remplacé entre-temps
    if byHelper[channel.helper] ~= channel then return end
    close(channel)
    local helperEntry, patientEntry = life.entry(channel.helper), life.entry(channel.patient)
    local d = distance(channel.helper, channel.patient)
    local valid = helperEntry and not helperEntry.downed and helperEntry.spawned
        and patientEntry and patientEntry.downed and d and d <= cfg.distance + cfg.tolerance
    if valid and cfg.item then valid = inventory('remove', channel.helper, cfg.item, 1) == true end
    if not valid then
        tell(channel, 'cancel')
        return
    end
    TriggerClientEvent(EVENTS.CHANNEL, channel.helper, { role = 'helper', state = 'done' })
    life.revive(channel.patient, cfg.health, 'assist', channel.helper)
end

--- Intention de relever quelqu'un (RPC). Renvoie une clé de message en cas de refus, ou la raison d'un module.
---@param helper integer
---@return boolean ok
---@return string|nil code
function assist.start(helper)
    local entry = life.entry(helper)
    if not entry or not entry.spawned then return false, 'no_character' end
    if entry.downed then return false, 'downed' end
    if byHelper[helper] then return false, 'busy' end
    local patient = nearestDowned(helper)
    if not patient then return false, 'nobody' end
    if cfg.item then
        local count = inventory('count', helper, cfg.item)
        if type(count) ~= 'number' or count < 1 then return false, 'missing_item' end
    end
    local allowed, reason = VavaHealth.core.hooks.runBefore(HOOK_REVIVING, { source = helper, target = patient })
    if not allowed then return false, type(reason) == 'string' and reason ~= 'hook_error' and reason or 'default' end
    -- un module a pu céder la main : la personne peut avoir été relevée ou prise en charge
    if byPatient[patient] or byHelper[helper] or not (life.entry(patient) or {}).downed then return false, 'busy' end

    local channel = { helper = helper, patient = patient }
    byHelper[helper], byPatient[patient] = channel, channel
    TriggerClientEvent(EVENTS.CHANNEL, helper, { role = 'helper', state = 'start', durationMs = cfg.durationMs })
    TriggerClientEvent(EVENTS.CHANNEL, patient, { role = 'patient', state = 'start', durationMs = cfg.durationMs })
    SetTimeout(cfg.durationMs, function() finish(channel) end)
    return true
end

--- Gestes en cours (diagnostic, tests).
---@return integer
function assist.count()
    local n = 0
    for _ in pairs(byHelper) do n = n + 1 end
    return n
end
