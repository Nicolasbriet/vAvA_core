--[[
    vava_magic/client/spells/boule_de_feu.lua
    Rôle : sort Boule de feu côté client.
      - Lancer : incantation (le lanceur peut marcher lentement), direction de la caméra envoyée à la fin, geste de
        jet. Le serveur décide de l'échec (la boule s'éteint) et annonce le lancer aux joueurs proches.
      - Vol (vu de tous les joueurs proches) : chaque client simule la trajectoire en ligne droite et la dessine
        (petit objet local invisible portant les flammes, lumière, souffle). Seul le client du lanceur lance un rayon
        le long de la trajectoire et signale l'impact au serveur, qui le valide avant tout dégât.
      - Impact validé : flammes et lueur à l'endroit annoncé par le serveur, chez tous. Aucune explosion GTA.
    La boucle par image ne vit que le temps d'un vol (deux secondes au plus).
    Dépendances : shared/, config.lua, client/ (noyau)
]]

local pairs, type, min, max = pairs, type, math.min, math.max
local CreateThread, Wait, GetGameTimer, GetFrameTime, RegisterNetEvent = CreateThread, Wait, GetGameTimer, GetFrameTime, RegisterNetEvent
local PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed = PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed
local GetEntityCoords, GetPedBoneCoords, IsEntityAPed, IsPedAPlayer, NetworkGetPlayerIndexFromPed =
    GetEntityCoords, GetPedBoneCoords, IsEntityAPed, IsPedAPlayer, NetworkGetPlayerIndexFromPed
local GetHashKey, RequestModel, HasModelLoaded, CreateObject, DeleteObject, DoesEntityExist, SetEntityCoordsNoOffset, SetEntityAlpha, SetEntityCollision =
    GetHashKey, RequestModel, HasModelLoaded, CreateObject, DeleteObject, DoesEntityExist, SetEntityCoordsNoOffset, SetEntityAlpha, SetEntityCollision
local UseParticleFxAsset, StartParticleFxLoopedOnEntity, StartParticleFxNonLoopedAtCoord, StopParticleFxLooped =
    UseParticleFxAsset, StartParticleFxLoopedOnEntity, StartParticleFxNonLoopedAtCoord, StopParticleFxLooped
local StartShapeTestCapsule, GetShapeTestResult, DrawLightWithRange = StartShapeTestCapsule, GetShapeTestResult, DrawLightWithRange

local core = VavaMagic.core
local nui = VavaMagic.nui
local casting = VavaMagic.casting
local ambient = VavaMagic.ambient
local keys = VavaMagic.keys
local aim = VavaMagic.aim
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.boule_de_feu
local fx = spellCfg.fx
local lightCfg = spellCfg.light
local projectileCfg = spellCfg.projectile
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local NAME = 'boule_de_feu'
local MODEL = GetHashKey(projectileCfg.model)
-- rayon : décor, véhicules, peds, objets
local SHAPE_TEST_FLAGS = 1 + 2 + 4 + 8 + 16
local SHAPE_TEST_OPTIONS = 7
local SHAPE_TEST_DONE = 2
local FLASH_MS = 300           -- lueur d'un impact
local ENDED_MEMORY_MS = 10000  -- un impact déjà montré n'est pas montré deux fois
local HEARING_DISTANCE = 60.0  -- au-delà, plus aucun son
local LIGHT_SIZE_SHARE = 0.8   -- la lumière du projectile suit sa taille

local fireball = {}
VavaMagic.fireball = fireball

---@type table<integer, table>  vols en cours
local projectiles = {}
---@type table<integer, integer>  lancer → instant où son impact a été montré
local ended = {}
local flashes = {}
local flying = false

-- modèle et particules préchargés : le premier lancer ne doit pas attendre
RequestModel(MODEL)
ambient.ptfxReady(fx.asset)

---@return integer
local function myServerId()
    return GetPlayerServerId(PlayerId())
end

---@param x number
---@param y number
---@param z number
---@return number volume  0 à 1 selon la distance au joueur
local function volumeAt(x, y, z)
    local distance = geometry.distance(GetEntityCoords(PlayerPedId()), { x = x, y = y, z = z })
    return max(0, 1 - distance / HEARING_DISTANCE)
end

local function sound(name, x, y, z)
    local volume = volumeAt(x, y, z)
    if volume > 0 then nui.send('sound', { name = name, volume = volume }) end
end

--- Flammes et lueur d'un impact.
local function impactAt(x, y, z, size)
    if ambient.ptfxReady(fx.asset) then
        UseParticleFxAsset(fx.asset)
        StartParticleFxNonLoopedAtCoord(fx.impact, x, y, z, 0.0, 0.0, 0.0, fx.impactScale * size, false, false, false)
    end
    flashes[#flashes + 1] = { x = x, y = y, z = z, untilMs = GetGameTimer() + FLASH_MS, size = size }
    sound('impact', x, y, z)
end

---@param projectile table
---@param point table|nil  point d'impact (nil : la boule s'est dissipée en bout de course)
local function land(projectile, point)
    projectiles[projectile.id] = nil
    if projectile.flame then StopParticleFxLooped(projectile.flame, false) end
    if projectile.object and DoesEntityExist(projectile.object) then DeleteObject(projectile.object) end
    if point then
        ended[projectile.id] = GetGameTimer()
        impactAt(point.x, point.y, point.z, projectile.size)
    end
end

--- Le client du lanceur a touché quelque chose : impact signalé au serveur, montré tout de suite chez lui.
local function report(projectile, coords, entity)
    local target = 0
    if entity and entity ~= 0 and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
    end
    core.rpc.emit(RPC.FIREBALL_IMPACT, projectile.id, target, coords.x, coords.y, coords.z)
    land(projectile, { x = coords.x, y = coords.y, z = coords.z })
end

--- Une image de vol pour un projectile.
local function advance(projectile, dt)
    if projectile.test then
        local status, hit, coords, _, entity = GetShapeTestResult(projectile.test)
        if status == SHAPE_TEST_DONE then
            projectile.test = nil
            if hit == 1 or hit == true then
                report(projectile, coords, entity)
                return
            end
        end
    end
    local step = min(projectile.speed * dt, projectile.range - projectile.travelled)
    local from = projectile.position
    local to = { x = from.x + projectile.dx * step, y = from.y + projectile.dy * step, z = from.z + projectile.dz * step }
    if projectile.own and not projectile.test then
        projectile.test = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, projectileCfg.radius * projectile.size,
            SHAPE_TEST_FLAGS, PlayerPedId(), SHAPE_TEST_OPTIONS)
    end
    projectile.position = to
    projectile.travelled = projectile.travelled + step
    if projectile.object then SetEntityCoordsNoOffset(projectile.object, to.x, to.y, to.z, false, false, false) end
    DrawLightWithRange(to.x, to.y, to.z, lightCfg.r, lightCfg.g, lightCfg.b, lightCfg.range * projectile.size * LIGHT_SIZE_SHARE, lightCfg.intensity)
    if projectile.travelled >= projectile.range and not projectile.test then land(projectile, nil) end
end

local function fly()
    if flying then return end
    flying = true
    CreateThread(function()
        -- boucle par image justifiée : seulement pendant un vol ou la lueur d'un impact
        while next(projectiles) or #flashes > 0 do
            local dt = GetFrameTime()
            for _, projectile in pairs(projectiles) do advance(projectile, dt) end
            local now = GetGameTimer()
            for i = #flashes, 1, -1 do
                local flash = flashes[i]
                if now > flash.untilMs then
                    table.remove(flashes, i)
                else
                    DrawLightWithRange(flash.x, flash.y, flash.z, lightCfg.r, lightCfg.g, lightCfg.b, lightCfg.range * flash.size, lightCfg.intensity * 2)
                end
            end
            Wait(0)
        end
        for id, at in pairs(ended) do
            if GetGameTimer() - at > ENDED_MEMORY_MS then ended[id] = nil end
        end
        flying = false
    end)
end

-- lancer annoncé par le serveur (ou boule éteinte entre les mains)
RegisterNetEvent(EVENTS.FIREBALL, function(payload)
    if type(payload) ~= 'table' or type(payload.caster) ~= 'number' then return end
    local player = GetPlayerFromServerId(payload.caster)
    if not player or player == -1 then return end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return end
    local hand = GetPedBoneCoords(ped, projectileCfg.handBone, 0.0, 0.0, 0.0)
    local levelCfg = spellCfg.levels[payload.level] or spellCfg.levels[1]
    if payload.fizzle then
        if ambient.ptfxReady(fx.asset) then
            UseParticleFxAsset(fx.asset)
            StartParticleFxNonLoopedAtCoord(fx.fizzle, hand.x, hand.y, hand.z, 0.0, 0.0, 0.0, fx.fizzleScale, false, false, false)
        end
        sound('fizzle', hand.x, hand.y, hand.z)
        return
    end
    if type(payload.id) ~= 'number' or type(payload.dx) ~= 'number' or type(payload.speed) ~= 'number' then return end
    local own = payload.caster == myServerId()
    if not own and geometry.distance(GetEntityCoords(PlayerPedId()), hand) > projectileCfg.renderDistance then return end
    local projectile = {
        id = payload.id, own = own, position = { x = hand.x, y = hand.y, z = hand.z },
        dx = payload.dx, dy = payload.dy, dz = payload.dz, speed = payload.speed, range = payload.range,
        travelled = 0, size = levelCfg.size,
    }
    if HasModelLoaded(MODEL) then
        local object = CreateObject(MODEL, hand.x, hand.y, hand.z, false, false, false)
        if object ~= 0 then
            SetEntityAlpha(object, 0, false)
            SetEntityCollision(object, false, false)
            projectile.object = object
            if ambient.ptfxReady(fx.asset) then
                UseParticleFxAsset(fx.asset)
                projectile.flame = StartParticleFxLoopedOnEntity(fx.trail, object, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, levelCfg.size, false, false, false)
            end
        end
    end
    projectiles[projectile.id] = projectile
    sound('whoosh', hand.x, hand.y, hand.z)
    fly()
end)

-- impact validé par le serveur : là où il l'a annoncé, chez tous les joueurs proches
RegisterNetEvent(EVENTS.FIREBALL_END, function(id, x, y, z)
    if type(id) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end
    local projectile = projectiles[id]
    if projectile then
        land(projectile, { x = x, y = y, z = z })
    elseif not ended[id] then
        ended[id] = GetGameTimer()
        impactAt(x, y, z, 1.0)
        fly()
    end
end)

--- Touche : lancer une boule de feu dans la direction de la caméra.
function fireball.cast()
    casting.start(NAME, {
        finishArgs = function()
            local direction = aim.direction()
            return { direction.x, direction.y, direction.z }
        end,
        onFinish = function(info)
            if info.success then casting.playAnim(spellCfg.throwAnim) end
        end,
    })
end

--- Arrêt du module : vols en cours effacés.
function fireball.stop()
    for _, projectile in pairs(projectiles) do land(projectile, nil) end
end

keys.bind('feu', fireball.cast)
keys.command(cfg.commands.feu, cfg.texts.suggestions.feu, fireball.cast)
