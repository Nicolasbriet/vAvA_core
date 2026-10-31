--[[
    vava_combat/client/targeting.lua
    Rôle : verrouillage d'un adversaire pour les techniques (règles de vava_magic/client/targeting.lua, réglages
           `lock`). Appui court sur la touche du verrou : le joueur le plus proche du centre de l'écran, à `lock.range`,
           dans `lock.coneDeg` et en vue ; nouvel appui : le suivant ; appui maintenu `lock.holdMs` : relâché. Perdu
           hors de portée (+ `rangeMargin`), hors de vue `lostChecks` relevés de suite, mort, ou quand le mode combat
           s'endort. AUCUNE boucle propre : l'anneau (à chaque image) et les relevés (toutes les `checkMs`) sont faits par
           la boucle du mode combat, qui tourne déjà ; la liste des candidats n'est faite qu'à l'appui
           (GetActivePlayers, jamais à chaque image). Vu du seul joueur : rien ne passe par le réseau avant un coup. Le
           serveur ne s'en sert que pour l'ordre des candidats d'un coup : le verrou n'allonge ni la portée ni l'angle.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local ipairs, sort = ipairs, table.sort
local rad, sin, cos, abs, acos, deg, sqrt, max, min = math.rad, math.sin, math.cos, math.abs, math.acos, math.deg,
    math.sqrt, math.max, math.min
local GetGameTimer = GetGameTimer
local PlayerId, PlayerPedId, GetActivePlayers, GetPlayerPed, GetPlayerServerId, GetEntityCoords =
    PlayerId, PlayerPedId, GetActivePlayers, GetPlayerPed, GetPlayerServerId, GetEntityCoords
local GetGameplayCamCoord, GetGameplayCamRot = GetGameplayCamCoord, GetGameplayCamRot
local DoesEntityExist, IsEntityDead, HasEntityClearLosToEntity = DoesEntityExist, IsEntityDead, HasEntityClearLosToEntity
local DrawMarker = DrawMarker

local cfg = VavaCombat.config
local lock = cfg.lock
local ring = cfg.lock.ring
-- vue dégagée : décor et objets (pas les peds ni les véhicules)
local LOS_FLAGS = 17
local ROTATION_ORDER = 2
local MS_PER_SECOND = 1000

local targeting = {}
VavaCombat.targeting = targeting

---@type { player: integer, serverId: integer, ped: integer, unseen: integer }|nil
local locked = nil
local pressedAt = nil

---@param a table
---@param b table
---@return number
local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return sqrt(dx * dx + dy * dy + dz * dz)
end

--- Direction de la caméra (vecteur unitaire).
---@return table
local function cameraDirection()
    local rotation = GetGameplayCamRot(ROTATION_ORDER)
    local pitch, yaw = rad(rotation.x), rad(rotation.z)
    local flat = abs(cos(pitch))
    return { x = -sin(yaw) * flat, y = cos(yaw) * flat, z = sin(pitch) }
end

--- Angle (degrés) entre la direction de la caméra et la direction de la caméra vers un point.
---@param direction table
---@param camera table
---@param point table
---@return number
local function angleTo(direction, camera, point)
    local dx, dy, dz = point.x - camera.x, point.y - camera.y, point.z - camera.z
    local length = sqrt(dx * dx + dy * dy + dz * dz)
    if length == 0 then return 0 end
    local dot = (direction.x * dx + direction.y * dy + direction.z * dz) / length
    return deg(acos(max(-1, min(1, dot))))
end

--- Joueurs verrouillables, du plus proche du centre de l'écran au plus excentré (à l'appui seulement).
---@return table[]
local function candidates()
    local me = PlayerId()
    local myPed = PlayerPedId()
    local origin = GetEntityCoords(myPed)
    local camera = GetGameplayCamCoord()
    local direction = cameraDirection()
    local list = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = player ~= me and GetPlayerPed(player)
        if ped and ped ~= 0 and not IsEntityDead(ped) then
            local position = GetEntityCoords(ped)
            local far = distance(origin, position)
            local angle = far <= lock.range and angleTo(direction, camera, position)
            if angle and angle <= lock.coneDeg and HasEntityClearLosToEntity(myPed, ped, LOS_FLAGS) then
                list[#list + 1] = { player = player, ped = ped, angle = angle, distance = far }
            end
        end
    end
    sort(list, function(a, b)
        if a.angle ~= b.angle then return a.angle < b.angle end
        return a.distance < b.distance
    end)
    return list
end

--- Appui court : verrouiller, ou passer à l'adversaire suivant. Rend vrai si une cible est verrouillée.
---@return boolean
function targeting.cycle()
    local list = candidates()
    if #list == 0 then return false end
    local index = 1
    if locked then
        for i, candidate in ipairs(list) do
            if candidate.player == locked.player then
                index = i % #list + 1
                break
            end
        end
    end
    local choice = list[index]
    locked = { player = choice.player, serverId = GetPlayerServerId(choice.player), ped = choice.ped, unseen = 0 }
    return true
end

function targeting.release()
    locked = nil
end

--- Numéro serveur de la cible verrouillée, ou nil.
---@return integer|nil
function targeting.current()
    return locked and locked.serverId or nil
end

--- Ped de la cible verrouillée, ou nil.
---@return integer|nil
function targeting.ped()
    return locked and locked.ped or nil
end

--- Relevé du verrou (boucle du mode, toutes les `lock.checkMs`) : portée, vue, cible morte.
function targeting.check()
    if not locked then return end
    local ped = locked.ped
    local myPed = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped)
        or distance(GetEntityCoords(myPed), GetEntityCoords(ped)) > lock.range + lock.rangeMargin then
        locked = nil
        return
    end
    locked.unseen = HasEntityClearLosToEntity(myPed, ped, LOS_FLAGS) and 0 or locked.unseen + 1
    if locked.unseen >= lock.lostChecks then locked = nil end
end

--- Anneau sous la cible (boucle du mode, à chaque image, seulement s'il y a une cible).
---@param now integer
function targeting.draw(now)
    if not locked then return end
    local feet = GetEntityCoords(locked.ped)
    DrawMarker(ring.marker, feet.x, feet.y, feet.z - ring.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0,
        (now / MS_PER_SECOND * ring.spin) % 360.0, ring.size, ring.size, 1.0, ring.r, ring.g, ring.b, ring.alpha,
        false, false, 2, false, nil, nil, false)
end

--- Touche du verrou enfoncée.
function targeting.pressed()
    pressedAt = GetGameTimer()
end

--- Touche du verrou relâchée : maintenue `holdMs` → relâcher ; sinon verrouiller ou passer au suivant.
function targeting.released()
    if not pressedAt then return end
    local held = GetGameTimer() - pressedAt
    pressedAt = nil
    if held >= lock.holdMs then targeting.release() else targeting.cycle() end
end
