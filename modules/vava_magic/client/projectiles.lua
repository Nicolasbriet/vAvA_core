--[[
    vava_magic/client/projectiles.lua
    Rôle : noyau commun des projectiles côté client (boule de feu, trait de glace, projectile de roche).
      - Lancer (clic gauche en mode magie, ou /lancer) : incantation brève (le lanceur peut marcher), cible
        verrouillée annoncée au début ; sinon, à la fin, la direction visée (des mains vers le point sous le
        réticule) ou, sans visée, droit devant le personnage. Le lanceur se tourne vers sa cible ou son point. Le
        serveur décide de l'échec, de la direction vers une cible verrouillée, et annonce le lancer.
      - Vol (vu de tous les joueurs proches) : chaque client simule la trajectoire et la dessine d'après la config du
        sort (`projectile`, `fx`, `light`, `sounds`) : objet local porteur (caché, ou visible et qui tournoie),
        traînée, marqueur, lumière ; il s'incurve vers la cible verrouillée si le serveur le permet (virage borné par
        seconde). Seul le client du lanceur lance un rayon le long de la trajectoire (un rempart l'arrête aussi) et
        signale l'impact au serveur, qui le valide avant tout effet. Un projectile qui traverse une zone au sol dont
        une combinaison le charge (roche dans un mur de flammes) change d'aspect en vol, d'après `config.combos` :
        prédiction locale, le serveur décide de l'effet à l'impact.
      - Impact validé : particules, lueur, son, caméra qui tremble près d'un impact lourd, à l'endroit annoncé par le
        serveur, chez tous.
    Effets selon le niveau (taille, lumière) et la distance (rien au-delà de `effects.maxDistance`), dans les plafonds
    de lumières et de particules. La boucle par image ne vit que le temps d'un vol (quelques secondes au plus).
    Dépendances : shared/, config_client.lua, client/ (noyau, fx, controls, targeting)
]]

local pairs, ipairs, next, type, min, max, sqrt, acos, deg = pairs, ipairs, next, type, math.min, math.max, math.sqrt, math.acos, math.deg
local GetHeadingFromVector_2d, SetEntityHeading, GetEntityForwardVector = GetHeadingFromVector_2d, SetEntityHeading, GetEntityForwardVector
local CreateThread, Wait, GetGameTimer, GetFrameTime, RegisterNetEvent = CreateThread, Wait, GetGameTimer, GetFrameTime, RegisterNetEvent
local PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed = PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed
local GetEntityCoords, GetPedBoneCoords, IsEntityAPed, IsPedAPlayer, NetworkGetPlayerIndexFromPed =
    GetEntityCoords, GetPedBoneCoords, IsEntityAPed, IsPedAPlayer, NetworkGetPlayerIndexFromPed
local GetHashKey, RequestModel, HasModelLoaded, CreateObject, DeleteObject, DoesEntityExist, SetEntityCoordsNoOffset, SetEntityAlpha, SetEntityCollision, SetEntityRotation =
    GetHashKey, RequestModel, HasModelLoaded, CreateObject, DeleteObject, DoesEntityExist, SetEntityCoordsNoOffset, SetEntityAlpha, SetEntityCollision, SetEntityRotation
local StartParticleFxLoopedOnEntity, StartParticleFxNonLoopedAtCoord, DrawMarker, ShakeGameplayCam =
    StartParticleFxLoopedOnEntity, StartParticleFxNonLoopedAtCoord, DrawMarker, ShakeGameplayCam
local StartShapeTestCapsule, GetShapeTestResult = StartShapeTestCapsule, GetShapeTestResult

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local fx = VavaMagic.fx
local zoneRender = VavaMagic.zoneRender
local bursts = VavaMagic.bursts
local targeting = VavaMagic.targeting
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local common = cfg.projectiles
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
-- rayon : décor, véhicules, peds, objets (un rempart compris)
local SHAPE_TEST_FLAGS = 1 + 2 + 4 + 8 + 16
local SHAPE_TEST_OPTIONS = 7
local SHAPE_TEST_DONE = 2
local FLASH_MS = 300           -- lueur d'un impact
local ENDED_MEMORY_MS = 10000  -- un impact déjà montré n'est pas montré deux fois
local LIGHT_SIZE_SHARE = 0.8   -- la lumière du projectile suit sa taille
local CHEST_BONE = 24818       -- SKEL_Spine3 : un projectile qui s'incurve vise le torse
local MARKER_SPHERE = 28

local projectiles = {}
VavaMagic.projectiles = projectiles

---@type table<string, { config: table, model: integer|nil, carries: table[] }>  sorts déclarés par leur fichier client
local defs = {}
---@type table<integer, table>  vols en cours
local flights = {}
---@type table<integer, integer>  lancer → instant où son impact a été montré
local ended = {}
local flashes = {}
local flying = false

---@return integer
local function myServerId()
    return GetPlayerServerId(PlayerId())
end

---@param name string|nil
---@param x number
---@param y number
---@param z number
local function sound(name, x, y, z)
    bursts.sound(name, { x = x, y = y, z = z })
end

--- Particules, lueur, son et tremblement d'un impact (rien au-delà de la distance des effets). `carry` : effet
--- emporté par une combinaison (flammes d'une roche ardente), qui s'ajoute.
---@param def table
---@param x number
---@param y number
---@param z number
---@param size number
---@param carry? table
local function impactAt(def, x, y, z, size, carry)
    local spellCfg = def.config
    local fxCfg = spellCfg.fx
    if not fx.detail({ x = x, y = y, z = z }) then return end
    if fxCfg.impact then
        fx.oneShot(fxCfg.asset, function()
            StartParticleFxNonLoopedAtCoord(fxCfg.impact, x, y, z, 0.0, 0.0, 0.0, (fxCfg.impactScale or 1.0) * size, false, false, false)
        end)
    end
    if carry and carry.impact then
        fx.oneShot(carry.asset, function()
            StartParticleFxNonLoopedAtCoord(carry.impact, x, y, z, 0.0, 0.0, 0.0, (carry.impactScale or 1.0) * size, false, false, false)
        end)
    end
    local light = (carry and carry.light) or spellCfg.light
    if light then flashes[#flashes + 1] = { light = light, x = x, y = y, z = z, untilMs = GetGameTimer() + FLASH_MS, size = size } end
    local shake = fxCfg.shake
    if shake and geometry.distance(GetEntityCoords(PlayerPedId()), { x = x, y = y, z = z }) <= shake.radius then
        ShakeGameplayCam(shake.name, shake.amplitude)
    end
    sound(spellCfg.sounds and spellCfg.sounds.impact, x, y, z)
end

---@param flight table
---@param point table|nil  point d'impact (nil : le projectile s'est dissipé en bout de course)
local function land(flight, point)
    flights[flight.id] = nil
    fx.stopLooped(flight.trail)
    if flight.object and DoesEntityExist(flight.object) then DeleteObject(flight.object) end
    if point then
        ended[flight.id] = GetGameTimer()
        impactAt(flight.def, point.x, point.y, point.z, flight.size, flight.carry)
    end
end

--- Le client du lanceur a touché quelque chose : impact signalé au serveur, montré tout de suite chez lui.
local function report(flight, coords, entity)
    local target = 0
    if entity and entity ~= 0 and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        target = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
    end
    core.rpc.emit(RPC.PROJECTILE_IMPACT, flight.id, target, coords.x, coords.y, coords.z)
    land(flight, { x = coords.x, y = coords.y, z = coords.z })
end

--- S'incurve vers la cible verrouillée, d'au plus `homing` degrés par seconde.
local function steer(flight, dt)
    local player = GetPlayerFromServerId(flight.target)
    local ped = player and player ~= -1 and GetPlayerPed(player)
    if not ped or ped == 0 then return end
    local chest = GetPedBoneCoords(ped, CHEST_BONE, 0.0, 0.0, 0.0)
    local from = flight.position
    local wanted = geometry.normalize(chest.x - from.x, chest.y - from.y, chest.z - from.z)
    if not wanted then return end
    local dot = flight.dx * wanted.x + flight.dy * wanted.y + flight.dz * wanted.z
    local angle = deg(acos(max(-1, min(1, dot))))
    if angle < 1e-3 then return end
    local share = min(1, flight.homing * dt / angle)
    local x = flight.dx + (wanted.x - flight.dx) * share
    local y = flight.dy + (wanted.y - flight.dy) * share
    local z = flight.dz + (wanted.z - flight.dz) * share
    local length = sqrt(x * x + y * y + z * z)
    if length < 1e-6 then return end
    flight.dx, flight.dy, flight.dz = x / length, y / length, z / length
end

--- Le projectile entre dans une zone qui le charge (combinaison) : il change d'aspect pour le reste du vol.
---@param flight table
---@param carry table
local function ignite(flight, carry)
    flight.carry = carry
    fx.stopLooped(flight.trail)
    flight.trail = nil
    if flight.object and carry.trail then
        flight.trail = fx.startLooped(carry.asset, function()
            return StartParticleFxLoopedOnEntity(carry.trail, flight.object, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, (carry.trailScale or 1.0) * flight.size, false, false, false)
        end)
    end
    local at = flight.position
    sound(carry.sound, at.x, at.y, at.z)
end

--- Une image de vol pour un projectile.
local function advance(flight, dt)
    if flight.test then
        local status, hit, coords, _, entity = GetShapeTestResult(flight.test)
        if status == SHAPE_TEST_DONE then
            flight.test = nil
            if hit == 1 or hit == true then
                report(flight, coords, entity)
                return
            end
        end
    end
    local spellCfg = flight.def.config
    local projectileCfg = spellCfg.projectile
    -- en bout de course : plus de déplacement ni de rayon, le projectile tombe dès que le dernier rayon est lu
    local step = min(flight.speed * dt, flight.range - flight.travelled)
    if step > 0 then
        if flight.homing > 0 and flight.target then steer(flight, dt) end
        local from = flight.position
        local to = { x = from.x + flight.dx * step, y = from.y + flight.dy * step, z = from.z + flight.dz * step }
        if flight.own and not flight.test then
            flight.test = StartShapeTestCapsule(from.x, from.y, from.z, to.x, to.y, to.z, projectileCfg.radius * flight.size,
                SHAPE_TEST_FLAGS, PlayerPedId(), SHAPE_TEST_OPTIONS)
        end
        flight.position = to
        flight.travelled = flight.travelled + step
        if not flight.carry then
            for _, entry in ipairs(flight.def.carries) do
                if zoneRender.at(to, entry.zone) then
                    ignite(flight, entry.carry)
                    break
                end
            end
        end
        if flight.object then
            SetEntityCoordsNoOffset(flight.object, to.x, to.y, to.z, false, false, false)
            if projectileCfg.spin then
                flight.spin = (flight.spin + projectileCfg.spin * dt) % 360.0
                SetEntityRotation(flight.object, flight.spin, flight.spin * 0.6, 0.0, 2, false)
            end
        end
    end
    local at = flight.position
    local marker = projectileCfg.marker
    if marker then
        local size = marker.size * flight.size
        DrawMarker(MARKER_SPHERE, at.x, at.y, at.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size,
            marker.r, marker.g, marker.b, marker.alpha, false, false, 2, false, nil, nil, false)
    end
    local light = (flight.carry and flight.carry.light) or spellCfg.light
    if light then
        fx.light(at.x, at.y, at.z, light.r, light.g, light.b, light.range * flight.size * LIGHT_SIZE_SHARE, light.intensity * flight.glow)
    end
    if flight.travelled >= flight.range and not flight.test then land(flight, nil) end
end

local function fly()
    if flying then return end
    flying = true
    CreateThread(function()
        -- boucle par image justifiée : seulement pendant un vol ou la lueur d'un impact
        while next(flights) or #flashes > 0 do
            local dt = GetFrameTime()
            for _, flight in pairs(flights) do advance(flight, dt) end
            local now = GetGameTimer()
            for i = #flashes, 1, -1 do
                local flash = flashes[i]
                if now > flash.untilMs then
                    table.remove(flashes, i)
                else
                    local light = flash.light
                    fx.light(flash.x, flash.y, flash.z, light.r, light.g, light.b, light.range * flash.size, light.intensity * 2)
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

--- Objet porteur du vol (local, sans collision) et sa traînée.
---@param flight table
---@param hand table
local function carrier(flight, hand)
    local def = flight.def
    local spellCfg = def.config
    if not def.model or not HasModelLoaded(def.model) then return end
    local object = CreateObject(def.model, hand.x, hand.y, hand.z, false, false, false)
    if object == 0 then return end
    if not spellCfg.projectile.visible then SetEntityAlpha(object, 0, false) end
    SetEntityCollision(object, false, false)
    flight.object = object
    local fxCfg = spellCfg.fx
    if fxCfg.trail then
        flight.trail = fx.startLooped(fxCfg.asset, function()
            return StartParticleFxLoopedOnEntity(fxCfg.trail, object, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, (fxCfg.trailScale or 1.0) * flight.size, false, false, false)
        end)
    end
end

-- lancer annoncé par le serveur (ou projectile éteint entre les mains)
RegisterNetEvent(EVENTS.PROJECTILE, function(payload)
    if type(payload) ~= 'table' or type(payload.caster) ~= 'number' or type(payload.spell) ~= 'string' then return end
    local def = defs[payload.spell]
    if not def then return end
    local spellCfg = def.config
    local player = GetPlayerFromServerId(payload.caster)
    if not player or player == -1 then return end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 then return end
    local hand = GetPedBoneCoords(ped, common.handBone, 0.0, 0.0, 0.0)
    local level = spellCfg.levels[payload.level] and payload.level or 1
    local levelCfg = spellCfg.levels[level]
    local scale = spellCfg.levelScale[level] or 1.0
    local fxCfg = spellCfg.fx
    if payload.fizzle then
        if fxCfg.fizzle then
            fx.oneShot(fxCfg.asset, function()
                StartParticleFxNonLoopedAtCoord(fxCfg.fizzle, hand.x, hand.y, hand.z, 0.0, 0.0, 0.0, (fxCfg.fizzleScale or 1.0) * scale, false, false, false)
            end)
        end
        sound(spellCfg.sounds and spellCfg.sounds.fizzle, hand.x, hand.y, hand.z)
        return
    end
    if type(payload.id) ~= 'number' or type(payload.dx) ~= 'number' or type(payload.speed) ~= 'number' then return end
    local own = payload.caster == myServerId()
    -- trop loin pour être vu : seul le lanceur simule le vol (il doit signaler l'impact)
    if not own and not fx.detail(hand) then return end
    local flight = {
        id = payload.id, def = def, own = own, position = { x = hand.x, y = hand.y, z = hand.z },
        dx = payload.dx, dy = payload.dy, dz = payload.dz, speed = payload.speed, range = payload.range,
        travelled = 0, size = (levelCfg.size or 1.0) * scale, glow = scale, spin = 0.0,
        target = type(payload.target) == 'number' and payload.target > 0 and payload.target or nil,
        homing = type(payload.homing) == 'number' and payload.homing or 0,
    }
    carrier(flight, hand)
    flights[flight.id] = flight
    sound(spellCfg.sounds and spellCfg.sounds.launch, hand.x, hand.y, hand.z)
    fly()
end)

-- impact validé par le serveur : là où il l'a annoncé, chez tous les joueurs proches
RegisterNetEvent(EVENTS.PROJECTILE_END, function(id, x, y, z, spell)
    if type(id) ~= 'number' or type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then return end
    local flight = flights[id]
    if flight then
        land(flight, { x = x, y = y, z = z })
        return
    end
    -- vol jamais vu (trop loin au lancer) : l'impact se montre quand même, à la taille du niveau 1
    local def = type(spell) == 'string' and defs[spell]
    if def and not ended[id] then
        ended[id] = GetGameTimer()
        impactAt(def, x, y, z, 1.0)
        fly()
    end
end)

--- Se tourne vers la cible verrouillée, ou vers la direction du jet.
---@param direction table|nil
local function face(direction)
    local me = PlayerPedId()
    local ped = targeting.ped()
    if ped then
        local from, to = GetEntityCoords(me), GetEntityCoords(ped)
        SetEntityHeading(me, GetHeadingFromVector_2d(to.x - from.x, to.y - from.y))
    elseif direction then
        SetEntityHeading(me, GetHeadingFromVector_2d(direction.x, direction.y))
    end
end

--- Direction du jet à la fin de l'incantation : vers le point visé (depuis les mains), la caméra si l'on vise sans
--- rien toucher, droit devant le personnage sans visée.
---@return table
local function throwDirection()
    local info = controls.aimInfo()
    if info.aiming and info.point then
        local body = GetEntityCoords(PlayerPedId())
        local direction = geometry.normalize(info.point.x - body.x, info.point.y - body.y, info.point.z - body.z - common.originHeight)
        if direction then return direction end
    end
    if info.aiming then return info.direction end
    local forward = GetEntityForwardVector(PlayerPedId())
    return { x = forward.x, y = forward.y, z = 0.0 }
end

--- Déclare un projectile du module : son geste au clic gauche (sur la cible verrouillée, ou là où l'on vise) et son
--- rendu (modèle et particules préchargés : le premier lancer ne doit pas attendre).
---@param name string
function projectiles.define(name)
    local spellCfg = cfg.spells[name]
    local def = { config = spellCfg, model = spellCfg.projectile.model and GetHashKey(spellCfg.projectile.model) or nil, carries = {} }
    -- combinaisons qui chargent ce projectile sur son trajet (zone au sol → effet emporté)
    for _, combo in pairs(cfg.combos) do
        local t = combo.trigger
        if t.on == 'zone' and t.projectile and (t.spell == name or (t.spell == nil and t.element == spellCfg.element)) and combo.result.carry then
            def.carries[#def.carries + 1] = { zone = t.zone, carry = combo.result.carry }
            fx.ptfxReady(combo.result.carry.asset)
        end
    end
    defs[name] = def
    if def.model then RequestModel(def.model) end
    fx.ptfxReady(spellCfg.fx.asset)
    controls.register(name, {
        cast = function(info)
            local target = info.target or bridge.GetLockedTarget()
            local direction = nil
            casting.start(name, {
                args = { target }, count = target and 1 or 0,
                finishArgs = function()
                    direction = throwDirection()
                    return { direction.x, direction.y, direction.z }
                end,
                beforeRelease = function() face(direction) end,
                onFinish = function(result)
                    if result.success ~= false then targeting.used() end
                end,
            })
        end,
    })
end

--- Arrêt du module : vols en cours effacés.
function projectiles.stop()
    for _, flight in pairs(flights) do land(flight, nil) end
end
