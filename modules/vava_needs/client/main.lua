--[[
    vava_needs/client/main.lua
    Rôle : assemblage côté client : valeurs reçues par le champ du personnage (aucun appel réseau), effets, jauges,
           événements du serveur (perte de vie, geste de consommation). Export `get` pour les autres scripts clients.
    Dépendances : shared/, config_client.lua, client/core.lua, client/effects.lua, client/hud.lua
]]

local type, ipairs, pairs = type, ipairs, pairs
local RegisterNetEvent, AddEventHandler = RegisterNetEvent, AddEventHandler

local core = VavaNeeds.core
if not core then return end

local cfg = VavaNeeds.config
local FIELD = VavaNeeds.FIELD
local EVENTS = VavaNeeds.EVENTS
local effects, hud = VavaNeeds.effects, VavaNeeds.hud

-- borne d'une perte de vie reçue : tous les besoins épuisés à la fois
local MAX_DAMAGE = 0
for _, need in ipairs(cfg.needs) do MAX_DAMAGE = MAX_DAMAGE + need.damage end

---@type table<string, number>|nil
local current = nil

---@param raw any
---@return table<string, number>
local function normalize(raw)
    local values = {}
    for _, need in ipairs(cfg.needs) do
        local value = type(raw) == 'table' and raw[need.name]
        values[need.name] = type(value) == 'number' and value or cfg.initial
    end
    return values
end

---@param raw any
local function apply(raw)
    local previous = current
    current = normalize(raw)
    effects.update(current, previous)
    hud.show(current)
end

---@param character table|nil
local function load(character)
    current = nil
    apply(character and character.fields and character.fields[FIELD])
end

core.hooks.after('core:character:loaded', load)
core.hooks.after('core:character:fieldChanged', function(change)
    if change.field == FIELD then apply(change.value) end
end)
core.hooks.after('core:character:spawning', function()
    effects.refresh(current)
end)
core.hooks.after('core:character:unloaded', function()
    current = nil
    effects.reset()
    hud.hide()
end)

RegisterNetEvent(EVENTS.STARVE, function(amount)
    if current and type(amount) == 'number' and amount > 0 and amount <= MAX_DAMAGE then effects.starve(amount) end
end)

RegisterNetEvent(EVENTS.CONSUME, function(name)
    if current and type(name) == 'string' then effects.gesture(name) end
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= hud.RESOURCE then return end
    hud.restarted()
    if current then hud.show(current) end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == VavaNeeds.resource then effects.reset() end
end)

--- Valeurs du personnage local (copie), ou nil.
exports('get', function()
    if not current then return nil end
    local copy = {}
    for name, value in pairs(current) do copy[name] = value end
    return copy
end)

-- module redémarré en cours de partie
local character = core.characters.current()
if character then load(character) end
