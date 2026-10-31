--[[
    vava_voice/client/mumble.lua
    Rôle : la voix intégrée à FiveM (Mumble de FXServer). En jeu, chaque joueur écoute son propre salon
           (base + son numéro de joueur) ; sa parole part vers une cible Mumble qui contient les salons des seuls
           joueurs à portée, recalculée à intervalle régulier (et envoyée à Mumble seulement si elle change). La
           distance d'écoute du son 3D suit la portée. Hors du jeu, le joueur revient au salon racine sans cible :
           personne ne l'entend et il n'entend personne (le serveur coupe aussi son micro).
    Dépendances : config_client.lua, client/core.lua
]]

local pairs, ipairs, next = pairs, ipairs, next
local CreateThread, Wait = CreateThread, Wait
local PlayerId, PlayerPedId, GetPlayerPed, GetPlayerServerId, GetActivePlayers, GetEntityCoords =
    PlayerId, PlayerPedId, GetPlayerPed, GetPlayerServerId, GetActivePlayers, GetEntityCoords
local MumbleIsConnected, MumbleSetVoiceChannel, MumbleGetVoiceChannelFromServerId = MumbleIsConnected, MumbleSetVoiceChannel, MumbleGetVoiceChannelFromServerId
local MumbleSetVoiceTarget, MumbleClearVoiceTarget, MumbleClearVoiceTargetChannels, MumbleAddVoiceTargetChannel =
    MumbleSetVoiceTarget, MumbleClearVoiceTarget, MumbleClearVoiceTargetChannels, MumbleAddVoiceTargetChannel
local MumbleSetTalkerProximity = MumbleSetTalkerProximity

local cfg = VavaVoice.config.client
local TARGET = cfg.voiceTarget

local mumble = {}
VavaVoice.mumble = mumble

local enabled = false
-- vrai une fois le joueur entré dans son salon
local joined = false
-- numéro de la demande d'entrée : une demande plus ancienne s'arrête d'elle-même
local generation = 0
local distance = 0.0
---@type table<integer, true>
local targets = {}

---@param serverId integer
---@return integer
function mumble.channelOf(serverId)
    return cfg.channelBase + serverId
end

local function clearTargets()
    if next(targets) then MumbleClearVoiceTargetChannels(TARGET) end
    targets = {}
end

--- Attend la connexion vocale, entre dans son salon et y reste (nouvelle demande de temps en temps).
---@param run integer
local function join(run)
    local myId = GetPlayerServerId(PlayerId())
    local channel = mumble.channelOf(myId)
    -- essai de la dernière demande d'entrée : la première part dès que la connexion vocale est là
    local requestedAt = nil
    for try = 1, cfg.connectTries do
        if run ~= generation or not enabled then return end
        if MumbleIsConnected() then
            if MumbleGetVoiceChannelFromServerId(myId) == channel then
                MumbleClearVoiceTarget(TARGET)
                MumbleSetVoiceTarget(TARGET)
                targets = {}
                joined = true
                return
            end
            if not requestedAt or try - requestedAt >= cfg.rejoinEvery then
                MumbleSetVoiceChannel(channel)
                requestedAt = try
            end
        end
        Wait(cfg.connectPollMs)
    end
    VavaVoice.log.warn('salon vocal %d non rejoint : la voix de proximité reste coupée', channel)
end

--- En jeu : rejoint son salon (la connexion vocale peut arriver après).
function mumble.enable()
    if enabled then return end
    enabled, joined = true, false
    generation = generation + 1
    local run = generation
    CreateThread(function() join(run) end)
end

--- Hors du jeu : plus de cible, retour au salon racine.
function mumble.disable()
    if not enabled then return end
    enabled, joined = false, false
    generation = generation + 1
    clearTargets()
    MumbleSetVoiceChannel(cfg.idleChannel)
end

---@param meters number
function mumble.setDistance(meters)
    distance = meters
    MumbleSetTalkerProximity(meters + 0.0)
end

---@return boolean
function mumble.isJoined()
    return joined
end

--- Recalcule les joueurs à portée ; Mumble n'est sollicité que si la liste change.
function mumble.refresh()
    if not joined then return end
    local me = PlayerId()
    local origin = GetEntityCoords(PlayerPedId())
    local reach = distance + cfg.targetMargin
    local reachSquared = reach * reach
    local wanted, changed, size = {}, false, 0
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local ped = GetPlayerPed(player)
            if ped ~= 0 then
                local coords = GetEntityCoords(ped)
                local dx, dy, dz = coords.x - origin.x, coords.y - origin.y, coords.z - origin.z
                if dx * dx + dy * dy + dz * dz <= reachSquared then
                    local channel = mumble.channelOf(GetPlayerServerId(player))
                    wanted[channel] = true
                    size = size + 1
                    if not targets[channel] then changed = true end
                end
            end
        end
    end
    if not changed then
        local previous = 0
        for _ in pairs(targets) do previous = previous + 1 end
        if previous == size then return end
    end
    MumbleClearVoiceTargetChannels(TARGET)
    for channel in pairs(wanted) do MumbleAddVoiceTargetChannel(TARGET, channel) end
    targets = wanted
end
