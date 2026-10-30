--[[
    vava_voice/server/main.lua
    Rôle : déclaration du module auprès du core : zones lues en base et déclarées au core (envoyées aux seuls joueurs
           proches), micro ouvert à l'apparition du personnage et coupé hors du jeu, liens avec la santé et le Conseil,
           intentions du client (limite de portée redemandée, éditeur du Conseil) en RPC à schéma strict et à débit
           limité ; chaque action de l'éditeur revérifie le droit.
           À l'arrêt, rien n'est rendu : un micro coupé (joueur hors du jeu) le reste pendant un `restart`.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, tonumber, tostring = ipairs, tonumber, tostring
local GetPlayers, GetPlayerPed, SetEntityCoords = GetPlayers, GetPlayerPed, SetEntityCoords

local core = VavaVoice.core
if not core then return end

local presence = VavaVoice.presence
local links = VavaVoice.links
local zones = VavaVoice.zones
local names = VavaVoice.label
local cfg = VavaVoice.config
local zoneCfg = cfg.zones
local limits = cfg.rateLimits
local RPC = VavaVoice.RPC

local ID = { type = 'integer', min = 1, max = 0xFFFFFFFF }
-- borne en octets tirée de la borne en signes (shared/label.lua) : le nombre de signes est revérifié à l'enregistrement
local LABEL = { type = 'string', min = 1, max = names.BYTES_MAX, pattern = names.PATTERN }
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

--- Demandé par le client à l'apparition et au redémarrage du module : la limite de portée du moment lui repart par son
--- évènement habituel (un client qui redémarre a pu manquer celle du démarrage). Les zones, elles, arrivent d'elles-mêmes
--- aux joueurs proches (abonnements de zone du core, 1.3.0).
local function zoneList(src)
    presence.resend(src)
    return true
end

local function onSpawned(payload)
    links.syncHealth(payload.source)
    presence.enable(payload.source)
end

local function setup()
    local declared, declareErr = VavaVoice.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local ok, err = zones.load()
    if not ok then return false, 'zones : ' .. tostring(err) end
    -- chaque zone devient une zone du core : seuls les joueurs proches la reçoivent
    zones.declareAll()
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
        { RPC.ZONES, {}, limits.zones, zoneList },
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

-- Arrêt du module : aucun micro n'est rendu. Les joueurs en jeu n'ont jamais été coupés ; ceux hors du jeu le restent,
-- sans quoi les joueurs en sélection s'entendraient pendant un `restart`. Un arrêt sans redémarrage les laisse donc
-- muets jusqu'à leur reconnexion (ou au retour du module, à leur apparition).

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaVoice.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
