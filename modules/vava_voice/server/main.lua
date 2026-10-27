--[[
    vava_voice/server/main.lua
    Rôle : déclaration du module auprès du core : zones lues en base, micro ouvert à l'apparition du personnage et
           coupé hors du jeu, liens avec la santé et le Conseil, intentions du client (liste des zones, éditeur du
           Conseil) en RPC à schéma strict et à débit limité ; chaque action de l'éditeur revérifie le droit.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local AddEventHandler, GetPlayers, GetPlayerPed, SetEntityCoords = AddEventHandler, GetPlayers, GetPlayerPed, SetEntityCoords

local core = VavaVoice.core
if not core then return end

local presence = VavaVoice.presence
local links = VavaVoice.links
local zones = VavaVoice.zones
local cfg = VavaVoice.config
local zoneCfg = cfg.zones
local limits = cfg.rateLimits
local RPC = VavaVoice.RPC

local ID = { type = 'integer', min = 1, max = 0xFFFFFFFF }
local LABEL = { type = 'string', min = 1, max = zoneCfg.labelMax, pattern = '^[^%c]+$' }
local RADIUS = { type = 'number', min = zoneCfg.radius.min, max = zoneCfg.radius.max }
local HEIGHT = { type = 'number', min = zoneCfg.height.min, max = zoneCfg.height.max }
local MULTIPLIER = { type = 'number', enum = zoneCfg.multipliers }
local BOOL = { type = 'boolean' }

--- Handler réservé au droit des zones : refus 'forbidden' sinon.
---@param permission string
---@param handler function
local function guarded(permission, handler)
    return function(src, ...)
        if not links.can(src, permission) then return false, 'forbidden' end
        return handler(src, ...)
    end
end

local function editor(src)
    return true, {
        zones = zones.all(),
        canTeleport = links.can(src, zoneCfg.teleportPermission),
    }
end

local function reach(src, id)
    local zone = zones.get(id)
    if not zone then return false, 'unknown_zone' end
    if not links.can(src, zoneCfg.teleportPermission) then return false, 'forbidden' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'no_position' end
    SetEntityCoords(ped, zone.x, zone.y, zone.z, false, false, false, false)
    return true
end

local function onSpawned(payload)
    links.syncHealth(payload.source)
    presence.enable(payload.source)
end

local function setup()
    local ok, err = zones.load()
    if not ok then return false, 'zones : ' .. tostring(err) end
    ok, err = links.start()
    if not ok then return false, err end
    for _, def in ipairs({
        { 'core:player:joined', function(payload) presence.disable(payload.source) end },
        { 'core:character:spawned', onSpawned },
        { 'core:character:unloading', function(payload) presence.disable(payload.source) end },
        { 'core:player:dropped', function(payload) presence.forget(payload.source) end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end
    for _, def in ipairs({
        { RPC.ZONES, {}, limits.zones, function() return true, zones.all() end },
        { RPC.EDITOR, {}, limits.editor, guarded(zoneCfg.permission, editor) },
        { RPC.CREATE, { LABEL, RADIUS, HEIGHT, MULTIPLIER }, limits.edit, guarded(zoneCfg.permission, zones.create) },
        { RPC.UPDATE, { ID, LABEL, RADIUS, HEIGHT, MULTIPLIER, BOOL }, limits.edit, guarded(zoneCfg.permission, zones.update) },
        { RPC.DELETE, { ID }, limits.edit, guarded(zoneCfg.permission, zones.remove) },
        { RPC.REACH, { ID }, limits.edit, guarded(zoneCfg.permission, reach) },
    }) do
        ok, err = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, err end
    end
    VavaVoice.ready = true
    -- module démarré en cours de partie : micro ouvert aux seuls joueurs dont le personnage est en jeu
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local session = src and core.players.get(src)
        if session and session.state == 'active' then onSpawned({ source = src }) elseif src then presence.disable(src) end
    end
    return true
end

-- arrêt du module : plus aucun micro coupé par lui
AddEventHandler('onResourceStop', function(resource)
    if resource == VavaVoice.resource then presence.releaseAll() end
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaVoice.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
