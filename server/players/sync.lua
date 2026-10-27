--[[
    server/players/sync.lua
    Rôle : diffusion des données de personnage vers les clients, au plus juste.
      - owner  : envoyé au seul joueur concerné ; les modifications d'un même tick partent en un seul event.
      - public : statebag du joueur répliqué (visible par tous) ; à réserver à ce qui doit vraiment l'être.
      - private : jamais envoyé.
    Dépendances : shared/init.lua, server/players/fields.lua
]]

local pairs = pairs
local TriggerClientEvent, SetTimeout, DoesPlayerExist, Player = TriggerClientEvent, SetTimeout, DoesPlayerExist, Player

local EVENTS = vAvA.EVENTS
local fields = vAvA.fields

local sync = {}
vAvA.sync = sync

-- source → { values = { champ → valeur }, cleared = { champ → true } }, vidé au tick suivant
local pending = {}
local flushScheduled = false

local function flush()
    flushScheduled = false
    local batches = pending
    pending = {}
    for src, batch in pairs(batches) do
        local cleared = {}
        for name in pairs(batch.cleared) do cleared[#cleared + 1] = name end
        TriggerClientEvent(EVENTS.CHARACTER_FIELDS, src, batch.values, cleared)
    end
end

---@param src integer
---@param name string
---@param value any  nil : le champ n'a plus de valeur pour le client
local function queue(src, name, value)
    local batch = pending[src]
    if not batch then
        batch = { values = {}, cleared = {} }
        pending[src] = batch
    end
    if value == nil then
        batch.values[name], batch.cleared[name] = nil, true
    else
        batch.values[name], batch.cleared[name] = value, nil
    end
    if not flushScheduled then
        flushScheduled = true
        SetTimeout(0, flush)
    end
end

--- Envoie au joueur son personnage (identité + champs visibles) et publie les champs publics.
---@param character vAvA.Character
function sync.sendCharacter(character)
    local src = character.source
    pending[src] = nil
    local visible = {}
    fields.forEachVisible(function(name)
        local value = fields.get(character, name)
        if value ~= nil then visible[name] = value end
    end)
    TriggerClientEvent(EVENTS.CHARACTER_LOADED, src, {
        id = character.id, firstName = character.firstName, lastName = character.lastName,
        sex = character.sex, fields = visible,
    })
    local state = Player(src).state
    fields.forEachPublic(function(name)
        state:set(name, fields.get(character, name), true)
    end)
end

--- Diffuse un champ modifié selon sa visibilité.
---@param character vAvA.Character
---@param def vAvA.FieldDefinition
function sync.fieldChanged(character, def)
    if def.visibility == 'private' then return end
    local value = fields.get(character, def.name)
    queue(character.source, def.name, value)
    if def.visibility == 'public' then
        Player(character.source).state:set(def.name, value, true)
    end
end

--- Retire les données d'un personnage déchargé : statebags publics vidés, client prévenu.
---@param character vAvA.Character
function sync.clearCharacter(character)
    local src = character.source
    pending[src] = nil
    if not DoesPlayerExist(src) then return end
    local state = Player(src).state
    fields.forEachPublic(function(name)
        state:set(name, nil, true)
    end)
    TriggerClientEvent(EVENTS.CHARACTER_UNLOADED, src, character.id)
end

---@param src integer
function sync.purgePlayer(src)
    pending[src] = nil
end
