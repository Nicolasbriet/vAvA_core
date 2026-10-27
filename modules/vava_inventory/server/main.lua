--[[
    vava_inventory/server/main.lua
    Rôle : déclaration du module auprès du core et enregistrement des intentions du joueur (RPC à schéma strict).
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tostring = ipairs, tostring
local AddEventHandler = AddEventHandler

local core = VavaInventory.core
if not core then return end

local containers = VavaInventory.containers
local persistence = VavaInventory.persistence
local operations = VavaInventory.operations
local characters = VavaInventory.characters
local drops = VavaInventory.drops
local cfg = VavaInventory.config
local RPC = VavaInventory.RPC
local MAX_ID = VavaInventory.MAX_ID

local INSTANCE = { type = 'integer', min = 1, max = MAX_ID }
local CONTAINER = { type = 'integer', min = -MAX_ID, max = MAX_ID }   -- négatif : sac au sol ; 0 : aucun
local COORD = { type = 'integer', min = 0, max = VavaInventory.MAX_GRID - 1 }
local QUANTITY = { type = 'integer', min = 1, max = VavaInventory.MAX_QUANTITY }
local OPTIONAL_QUANTITY = { type = 'integer', min = 1, max = VavaInventory.MAX_QUANTITY, optional = true }
local ROTATED = { type = 'boolean' }
local SLOT = { type = 'integer', min = 1, max = cfg.hotbarSize }
local SLOT_CONTENT = { type = 'integer', min = 0, max = MAX_ID }
local limits = cfg.rateLimits

local RPCS = {
    { RPC.OPEN, { CONTAINER }, limits.open, operations.open },
    { RPC.CLOSE, {}, limits.action, function(src) operations.close(src) return true end },
    { RPC.MOVE, { INSTANCE, CONTAINER, COORD, COORD, ROTATED }, limits.action, operations.move },
    { RPC.SPLIT, { INSTANCE, QUANTITY, CONTAINER, COORD, COORD, ROTATED }, limits.action, operations.split },
    { RPC.MERGE, { INSTANCE, INSTANCE, OPTIONAL_QUANTITY }, limits.action, operations.merge },
    { RPC.DROP, { INSTANCE, OPTIONAL_QUANTITY }, limits.action, operations.drop },
    { RPC.USE, { INSTANCE }, limits.use, function(src, id)
        local ok, code = operations.use(src, id)
        return ok, code
    end },
    { RPC.HOTBAR_SET, { SLOT, SLOT_CONTENT }, limits.action, operations.hotbarSet },
    { RPC.HOTBAR_USE, { SLOT }, limits.use, operations.hotbarUse },
}

local function setup()
    local ok, err = VavaInventory.items.define()
    if not ok then return false, err end

    local empty = {}
    for i = 1, cfg.hotbarSize do empty[i] = 0 end
    ok, err = core.characters.defineField(VavaInventory.HOTBAR_FIELD, {
        schema = { type = 'array', min = cfg.hotbarSize, max = cfg.hotbarSize, items = SLOT_CONTENT },
        default = empty,
        visibility = 'owner',
    })
    if not ok then return false, err end

    ok, err = containers.init()
    if not ok then return false, 'identifiants d\'objets : ' .. tostring(err) end
    ok, err = characters.start()
    if not ok then return false, err end

    for _, def in ipairs(RPCS) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(err) end
    end

    persistence.start()
    VavaInventory.ready = true
    characters.adoptActive()
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaInventory.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaInventory.resource then return end
    -- les sacs sont des entités du monde : ils ne doivent pas survivre au module
    drops.clear()
    local pending = persistence.pending()
    if pending > 0 then
        core.log.warn('%d objet(s) d\'inventaire non écrits à l\'arrêt (écriture toutes les %d ms)', pending, cfg.flushIntervalMs)
    end
end)
