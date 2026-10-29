--[[
    vava_farming/server/granary.lua
    Rôle : greniers communs : un conteneur conservé de l'inventaire par parcelle qui en déclare un (créé au premier
           démarrage, retrouvé ensuite), ouvert au joueur qui a accès à la parcelle (communale : tous ; privée : son
           propriétaire), pas à terre, à portée du grenier, avec un ancrage (la distance est alors tenue par
           l'inventaire), dépôts et
           retraits d'après les hooks de l'inventaire (déplacer, diviser, fusionner, jeter) qui passent par le
           conteneur : hook `vava_farming:granary` (after) à chaque geste, journal regroupé par minute (journal.lua).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/slots.lua (accès)
]]

local ipairs, tostring = ipairs, tostring
local format = string.format
local time = os.time

local core = VavaFarming.core
local bridge = VavaFarming.bridge
local journal = VavaFarming.journal
local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local geometry = VavaFarming.geometry
local cfg = VavaFarming.config
local messages = cfg.messages

local HOOK = 'vava_farming:granary'
local SELECT_SQL = 'SELECT `parcel`, `container_id` FROM `vava_farming_granaries`'
local INSERT_SQL = 'INSERT INTO `vava_farming_granaries` (`parcel`, `container_id`, `created_at`) VALUES (?, ?, ?)'

local granary = {}
VavaFarming.granary = granary

-- parcelle → id de conteneur, et l'inverse
local containers, parcels = {}, {}

--- Retrouve ou crée le grenier de chaque parcelle qui en déclare un. Bloque le thread courant.
---@return boolean ok
---@return string|nil err
function granary.start()
    local rows, err = bridge.db.query(SELECT_SQL, {})
    if err then return false, err end
    local known = {}
    for _, row in ipairs(rows) do known[row.parcel] = bridge.Integer(row.container_id, 0) end
    for _, parcel in ipairs(catalog.parcels()) do
        local spec = parcel.granary
        if spec then
            local id = known[parcel.id]
            if not id or id == 0 then
                local created, code = bridge.CreateContainer({
                    kind = 'granary', ownerType = 'parcel', ownerId = parcel.id, width = spec.width, height = spec.height,
                    maxWeight = spec.maxWeight, label = spec.label,
                })
                if not created then return false, format('grenier de %s : %s', parcel.id, tostring(code)) end
                local _, insertErr = bridge.db.insert(INSERT_SQL, { parcel.id, created, time() })
                if insertErr then return false, insertErr end
                id = created
            end
            containers[parcel.id] = id
            parcels[id] = parcel.id
        end
    end
    for _, hook in ipairs({ 'vava_inventory:move', 'vava_inventory:split', 'vava_inventory:merge', 'vava_inventory:drop' }) do
        local id, hookErr = core.hooks.after(hook, granary.onInventoryGesture)
        if not id then return false, hookErr end
    end
    return true
end

--- Conteneur du grenier d'une parcelle, ou nil.
---@param parcelId string
---@return integer|nil
function granary.containerOf(parcelId)
    return containers[parcelId]
end

--- Ouvre le grenier au joueur qui a accès à la parcelle et se tient à portée (ancrage : l'inventaire revérifie la
--- distance à chaque geste). L'inventaire laisse le droit d'accès à l'appelant.
---@param src integer
---@param parcel vAvA.ParcelDefinition
---@return boolean ok
---@return string|nil code
function granary.open(src, parcel)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return false, 'no_character' end
    if bridge.IsDowned(src) then return false, 'downed' end
    local spec = parcel.granary
    local id = containers[parcel.id]
    if not spec or not id then return false, 'no_granary' end
    if not slots.canAccess(parcel, characterId) then
        bridge.Notify(src, messages.noAccess, 'warning')
        return false, 'no_access'
    end
    local x, y, z = bridge.Position(src)
    local reach = cfg.interact.distance + cfg.interact.serverTolerance
    if not x or not geometry.within(x, y, z, spec.x, spec.y, spec.z, reach) then return false, 'too_far' end
    local ok, code = bridge.OpenContainer(src, id, { x = spec.x, y = spec.y, z = spec.z, radius = reach })
    if not ok then return false, code or 'open_failed' end
    bridge.Notify(src, messages.granaryOpened, 'info')
    return true
end

--- Geste d'inventaire : s'il traverse un grenier, il est journalé (dépôt ou retrait).
---@param payload table  { source, item, quantity, from, to }
function granary.onInventoryGesture(payload)
    local fromParcel, toParcel = parcels[payload.from], parcels[payload.to]
    if fromParcel == toParcel then return end
    local characterId = bridge.GetCharacterId(payload.source)
    if toParcel then
        journal.granary(toParcel, characterId, 'deposit', payload.item, payload.quantity)
        core.hooks.runAfter(HOOK, { parcel = toParcel, action = 'deposit', source = payload.source, characterId = characterId, item = payload.item, quantity = payload.quantity })
    end
    if fromParcel then
        journal.granary(fromParcel, characterId, 'withdraw', payload.item, payload.quantity)
        core.hooks.runAfter(HOOK, { parcel = fromParcel, action = 'withdraw', source = payload.source, characterId = characterId, item = payload.item, quantity = payload.quantity })
    end
end
